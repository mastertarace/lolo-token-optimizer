#!/usr/bin/env python3
"""
Synthetic, deterministic token-savings estimator for lolo-token-optimizer.

No live API calls. Every number is either a real measurement (file size on
disk, real `grep` output size) or an explicitly-labeled assumption (baseline
retry count). Token counts use the plugin's own approximation, ~4 bytes per
token, so the estimate is apples-to-apples with what the hooks themselves
compute at runtime -- not a claim about a real tokenizer's exact count.

Two scenarios, matching the plugin's two token-saving hooks:

1. file-size guard (check-file-size.sh): for each fixture over
   maxFileTokenLimit, compares "read the whole file" against "grep for a
   representative pattern" (the alternative the plugin's deny message
   suggests).

2. loop guard (guard-loop.sh, sticky): compares an assumed baseline number
   of retries a model might blindly attempt against maxToolRetriesBeforeAbort
   + cheap denials, using a real sample "failed attempt" transcript to price
   one wasted turn.

Usage:
    python3 bench/estimate_savings.py [--baseline-retries N]
"""
import argparse
import json
import os
import subprocess
import sys

BENCH_DIR = os.path.dirname(os.path.abspath(__file__))
PLUGIN_ROOT = os.path.dirname(BENCH_DIR)
MANIFEST_PATH = os.path.join(BENCH_DIR, "fixtures", "files", "manifest.json")
FAILED_ATTEMPT_PATH = os.path.join(BENCH_DIR, "fixtures", "failed_attempt.txt")
PLUGIN_MANIFEST_PATH = os.path.join(PLUGIN_ROOT, ".claude-plugin", "plugin.json")

BYTES_PER_TOKEN = 4  # same rough approximation hooks/scripts/lib.sh uses


def tokens(byte_count):
    return byte_count / BYTES_PER_TOKEN


def load_settings():
    with open(PLUGIN_MANIFEST_PATH) as f:
        manifest = json.load(f)
    return manifest.get("settings", {})


def deny_message_bytes(estimated_tokens, limit):
    # Mirrors the exact string check-file-size.sh emits.
    msg = (
        f"File too large (~{int(estimated_tokens)} estimated tokens, limit {limit}). "
        "Use grep/sed/awk or a ranged read (offset/limit) instead of loading the whole file."
    )
    return len(msg.encode("utf-8"))


def loop_deny_message_bytes(count, limit):
    msg = (
        f"Error loop detected ({count} consecutive failures, limit {limit}). "
        "Task handed back: stop this approach and report a condensed error to the main model instead of retrying."
    )
    return len(msg.encode("utf-8"))


def run_file_scenario(max_file_token_limit):
    print("=" * 72)
    print("SCENARIO 1: raw file read blocked -> targeted grep instead")
    print(f"(maxFileTokenLimit = {max_file_token_limit} tokens, ~{max_file_token_limit * BYTES_PER_TOKEN} bytes)")
    print("=" * 72)

    with open(MANIFEST_PATH) as f:
        manifest = json.load(f)

    total_baseline = 0.0
    total_with_plugin = 0.0
    rows = []

    for entry in manifest:
        file_path = os.path.join(BENCH_DIR, "fixtures", "files", entry["file"])
        size_bytes = os.path.getsize(file_path)
        full_read_tokens = tokens(size_bytes)
        over_limit = full_read_tokens > max_file_token_limit

        if not over_limit:
            rows.append({
                "file": entry["file"],
                "full_read_tokens": round(full_read_tokens),
                "over_limit": False,
                "with_plugin_tokens": round(full_read_tokens),
                "saved_tokens": 0,
            })
            total_baseline += full_read_tokens
            total_with_plugin += full_read_tokens
            continue

        cmd = ["grep"] + entry.get("grep_flags", []) + [entry["grep_pattern"], file_path]
        result = subprocess.run(cmd, capture_output=True, text=True)
        grep_output_bytes = len(result.stdout.encode("utf-8"))
        grep_tokens = tokens(grep_output_bytes)

        deny_tokens = tokens(deny_message_bytes(full_read_tokens, max_file_token_limit))
        with_plugin_tokens = deny_tokens + grep_tokens
        saved = full_read_tokens - with_plugin_tokens

        rows.append({
            "file": entry["file"],
            "full_read_tokens": round(full_read_tokens),
            "over_limit": True,
            "grep_pattern": entry["grep_pattern"],
            "grep_output_tokens": round(grep_tokens),
            "deny_message_tokens": round(deny_tokens),
            "with_plugin_tokens": round(with_plugin_tokens),
            "saved_tokens": round(saved),
        })
        total_baseline += full_read_tokens
        total_with_plugin += with_plugin_tokens

    for r in rows:
        print(f"\n- {r['file']}")
        print(f"    full read (baseline):        ~{r['full_read_tokens']} tokens")
        if r["over_limit"]:
            print(f"    hook fires (over limit)")
            print(f"    deny message:                 ~{r['deny_message_tokens']} tokens")
            print(f"    grep '{r['grep_pattern']}' output:  ~{r['grep_output_tokens']} tokens")
            print(f"    with plugin (deny + grep):    ~{r['with_plugin_tokens']} tokens")
            print(f"    saved:                        ~{r['saved_tokens']} tokens")
        else:
            print(f"    under limit, hook does not fire -> no change (control case)")

    print(f"\n  Scenario 1 totals: baseline ~{round(total_baseline)} tokens, "
          f"with plugin ~{round(total_with_plugin)} tokens, "
          f"saved ~{round(total_baseline - total_with_plugin)} tokens "
          f"({(1 - total_with_plugin / total_baseline) * 100:.1f}% reduction)")

    return total_baseline, total_with_plugin


def run_loop_scenario(max_retries, baseline_retries):
    print()
    print("=" * 72)
    print("SCENARIO 2: retry loop cut off (sticky guard-loop.sh)")
    print(f"(maxToolRetriesBeforeAbort = {max_retries}, "
          f"assumed baseline retries = {baseline_retries} [labeled assumption, not measured])")
    print("=" * 72)

    with open(FAILED_ATTEMPT_PATH, "rb") as f:
        attempt_bytes = len(f.read())
    attempt_tokens = tokens(attempt_bytes)

    baseline_tokens = attempt_tokens * baseline_retries

    # With the plugin: the first `max_retries` failed attempts still happen
    # (the hook only trips once the threshold is reached), then every further
    # attempt is a cheap sticky denial instead of a full retry.
    denied_attempts = max(0, baseline_retries - max_retries)
    deny_tokens_each = tokens(loop_deny_message_bytes(max_retries, max_retries))
    with_plugin_tokens = (attempt_tokens * max_retries) + (deny_tokens_each * denied_attempts)

    saved = baseline_tokens - with_plugin_tokens

    print(f"\n  one wasted attempt (measured from fixtures/failed_attempt.txt): ~{round(attempt_tokens)} tokens")
    print(f"  baseline: {baseline_retries} attempts x ~{round(attempt_tokens)} tokens "
          f"= ~{round(baseline_tokens)} tokens")
    print(f"  with plugin: {max_retries} real attempts + {denied_attempts} sticky denials "
          f"(~{round(deny_tokens_each)} tokens each) = ~{round(with_plugin_tokens)} tokens")
    print(f"  saved: ~{round(saved)} tokens "
          f"({(1 - with_plugin_tokens / baseline_tokens) * 100:.1f}% reduction, "
          f"for this one subagent loop)")

    return baseline_tokens, with_plugin_tokens


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--baseline-retries", type=int, default=6,
                         help="Assumed number of retries a subagent would blindly attempt "
                              "without the loop guard (default: 6). This is a stated "
                              "assumption, not a measurement.")
    args = parser.parse_args()

    settings = load_settings()
    max_file_token_limit = int(settings.get("maxFileTokenLimit", 10000))
    max_retries = int(settings.get("maxToolRetriesBeforeAbort", 2))

    if args.baseline_retries <= max_retries:
        print(f"--baseline-retries ({args.baseline_retries}) must be greater than "
              f"maxToolRetriesBeforeAbort ({max_retries}) for scenario 2 to mean anything.",
              file=sys.stderr)
        sys.exit(1)

    b1_base, b1_plugin = run_file_scenario(max_file_token_limit)
    b2_base, b2_plugin = run_loop_scenario(max_retries, args.baseline_retries)

    total_base = b1_base + b2_base
    total_plugin = b1_plugin + b2_plugin

    print()
    print("=" * 72)
    print("COMBINED (both scenarios, this fixture set only -- not a general %)")
    print("=" * 72)
    print(f"  baseline:    ~{round(total_base)} tokens")
    print(f"  with plugin: ~{round(total_plugin)} tokens")
    print(f"  saved:       ~{round(total_base - total_plugin)} tokens "
          f"({(1 - total_plugin / total_base) * 100:.1f}% reduction)")
    print()
    print("Caveats: bytes/4 is the plugin's own approximation, not a real tokenizer.")
    print("Scenario 2's baseline retry count is an assumption you can override with")
    print("--baseline-retries. These numbers describe this fixture set, not a general")
    print("claim about all sessions. See bench/README.md for the real-session method.")


if __name__ == "__main__":
    main()
