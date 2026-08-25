#!/usr/bin/env python3
"""Extract per-turn token usage from a Claude Code session transcript (.jsonl)."""
import json
import sys

def main():
    if len(sys.argv) < 2:
        print("usage: extract_usage.py <session.jsonl> [...]", file=sys.stderr)
        sys.exit(1)

    for path in sys.argv[1:]:
        total = {"input_tokens": 0, "output_tokens": 0, "cache_read_input_tokens": 0, "cache_creation_input_tokens": 0}
        turns = 0
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue
                usage = obj.get("message", {}).get("usage")
                if not usage:
                    continue
                turns += 1
                for k in total:
                    total[k] += usage.get(k, 0)
        print(f"{path}\tturns={turns}\tinput={total['input_tokens']}\toutput={total['output_tokens']}\tcache_read={total['cache_read_input_tokens']}\tcache_creation={total['cache_creation_input_tokens']}")

if __name__ == "__main__":
    main()
