**[English](README.md) · Français**

# LoLo Token Optimizer v2

Un plugin Claude Code qui réduit le coût en tokens en imposant des règles de
compression avant toute délégation à un sous-agent, en bloquant la lecture
brute de gros fichiers, et en coupant les sous-agents qui bouclent sur des
échecs répétés d'outil.

> **Mesuré : ~91% de tokens en moins sur le jeu de fixtures du bench**
> (~30 926 → ~2 806 tokens ; ~28 120 économisés) en bloquant la lecture brute
> de gros fichiers au profit d'un `grep` ciblé, et en coupant court à une
> boucle de réessais après échec répété. Gratuit, déterministe, reproductible
> en une commande :
> ```bash
> python3 bench/estimate_savings.py
> ```
> Chiffres complets et méthodologie (ce qui est mesuré vs supposé, et comment
> obtenir un chiffre exact à partir de vraies sessions) :
> [`bench/README.md`](bench/README.md) · [`bench/report.html`](bench/report.html).

## Installation (depuis GitHub)

Dans une session Claude Code, exécute :

```
/plugin marketplace add mastertarace/lolo-token-optimizer
/plugin install lolo-token-optimizer
```

C'est tout — rien à télécharger, aucune dépendance à installer, aucun
réglage à toucher. Détails complets et méthodes d'installation alternatives
(clone local, test rapide via `--plugin-dir`) dans
[Installation](#installation) ci-dessous.

## Prérequis

- Claude Code avec support des plugins (hooks + skills).
- `bash`.

Rien d'autre à installer, rien à configurer : chaque script de hook choisit
automatiquement son backend JSON, dans cet ordre :

1. `jq`, si présent (le plus rapide).
2. `python3`, si `jq` est absent — présent sur quasiment toute machine de
   développement, c'est donc le vrai comportement par défaut sans configuration.
3. Un repli `grep`/`sed` pour les champs simples, seulement si aucun des deux
   n'existe.

Les trois chemins implémentent le même comportement (lire les réglages, lire
les champs du hook, émettre le JSON de refus/contexte), donc le plugin est
pleinement fonctionnel juste après `install.sh`, sans paquet à installer ni
réglage à toucher.

## Ce qu'il fait réellement

Ce plugin fonctionne entièrement via des **hooks** (`hooks/hooks.json`) plus
un **skill** invocable manuellement (`skills/token-optimizer/`). Pas de
commande slash, pas de démon en arrière-plan — tout tourne comme des scripts
shell de courte durée déclenchés par les événements de hook de Claude Code.

| Événement | Script | Effet |
|---|---|---|
| `InstructionsLoaded` | `inject-compression-rules.sh` | Injecte un rappel court des règles de compression (mission <= 15 mots, contexte <= 120 tokens, préférer un modèle léger) dans le contexte de la conversation. |
| `SubagentStart` | `subagent-start-context.sh` | Injecte une instruction de réponse compacte dans le contexte propre du sous-agent à son démarrage. |
| `PreToolUse` (matcher `Read`) | `check-file-size.sh` | Estime la taille du fichier ciblé en tokens (~4 octets/token) par rapport à `maxFileTokenLimit` ; refuse la lecture avec un message suggérant `grep`/`sed`/`awk` ou une lecture par plage si la limite est dépassée. |
| `PreToolUse` (matcher `*`) | `guard-loop.sh` | Avant tout appel d'outil, vérifie le compteur d'échecs consécutifs pour la session+agent en cours ; si `maxToolRetriesBeforeAbort` est atteint, refuse l'appel. C'est sticky : le compteur n'est effacé que par un succès ou par la fin de la session/du sous-agent, donc tout appel d'outil suivant est aussi refusé, pas seulement celui qui a déclenché le seuil. |
| `PostToolUseFailure` (matcher `*`) | `track-tool-failure.sh` | Incrémente le compteur d'échecs consécutifs. |
| `PostToolUse` (matcher `*`) | `reset-failure-counter.sh` | Efface le compteur dès qu'un appel d'outil réussit. |
| `SubagentStop` / `Stop` | `reset-failure-counter.sh` | Efface tout compteur restant quand un sous-agent ou la session se termine. |

L'état (compteurs d'échecs) est conservé sous forme de petits fichiers dans
`$CLAUDE_PLUGIN_DATA` (ou `/tmp/lolo-token-optimizer` si cette variable n'est
pas définie), un fichier par paire `session_id` + `agent_id`.

### Limite importante : pas de vraie action "tuer le sous-agent"

Le système de hooks de Claude Code n'expose aucune action qui termine
réellement un sous-agent en cours d'exécution — ni type d'action de hook, ni
commande CLI, ni prise de contrôle au niveau OS pour l'arrêter depuis
l'extérieur. `guard-loop.sh` approxime l'objectif du plugin ("couper les
sous-agents qui bouclent") en **refusant tout appel d'outil** une fois le
seuil d'échec atteint — pas seulement le suivant, mais tous, de façon
sticky, jusqu'à ce qu'un appel réussisse ou que le sous-agent/la session se
termine. En pratique, ça prive l'agent d'outils, donc il ne peut plus que
répondre en texte et termine naturellement son tour — mais ce n'est pas une
terminaison forcée, et rien ne l'empêche de produire encore du texte tant
qu'il est ainsi privé d'outils.

### Réglages (`.claude-plugin/plugin.json`)

```json
{
  "settings": {
    "defaultEffort": "low",
    "maxFileTokenLimit": 10000,
    "maxToolRetriesBeforeAbort": 2
  }
}
```

- `defaultEffort` : mentionné seulement dans le rappel `InstructionsLoaded` ;
  non appliqué de façon programmatique (Claude Code n'expose pas de hook
  pour forcer le niveau d'effort).
- `maxFileTokenLimit` : budget de tokens pour un `Read`, approximé par
  `taille_en_octets / 4`.
- `maxToolRetriesBeforeAbort` : nombre d'échecs consécutifs tolérés avant que
  `guard-loop.sh` ne refuse l'appel suivant.

## Le skill `token-optimizer`

`skills/token-optimizer/SKILL.md` permet de réappliquer manuellement les
mêmes règles de compression en cours de tâche (ex. "optimise les tokens
avant de déléguer ce lot"). C'est une checklist, pas une action automatique
— invoque-le avec `/token-optimizer` (ou laisse Claude l'invoquer quand
pertinent).

## `cli.sh` — diagnostics manuels

Non branché à Claude Code (les plugins n'exposent pas de point d'entrée CLI
arbitraire) ; à lancer directement depuis un shell pour du dépannage :

```bash
./cli.sh status   # affiche version, réglages et compteurs d'échecs actifs du plugin
./cli.sh reset    # efface tous les compteurs d'échecs
```

## Installation

Claude Code active les plugins via un enregistrement de marketplace — une
simple copie dans `~/.claude/plugins/` ne suffit pas seule. Le
`.claude-plugin/marketplace.json` à la racine de ce dépôt en fait une
marketplace autonome, à un seul plugin, donc aucun dépôt de liste séparé
n'est nécessaire.

**Depuis le dépôt publié**, dans une session Claude Code :

```
/plugin marketplace add mastertarace/lolo-token-optimizer
/plugin install lolo-token-optimizer
```

**Depuis un clone local**, dans une session Claude Code :

```
/plugin marketplace add /chemin/vers/lolo-token-optimizer
/plugin install lolo-token-optimizer
```

**Test local rapide** sans enregistrer de marketplace du tout :

```bash
claude --plugin-dir /chemin/vers/lolo-token-optimizer
```

`./install.sh` copie en plus le dépôt dans
`~/.claude/plugins/lolo-token-optimizer/` et rend les scripts de hook
exécutables — pratique pour lancer `cli.sh` ou inspecter la copie installée,
mais ça n'enregistre ni n'active le plugin par soi-même ; lance quand même
l'une des commandes `/plugin` ci-dessus ensuite.

## Vérifier que ça fonctionne

1. `./cli.sh status` — confirme que le manifeste est lisible et que les
   réglages se résolvent correctement.
2. Démarre une session Claude Code dans un projet et vérifie que le rappel
   `InstructionsLoaded` apparaît dans le contexte (visible via `/context` ou
   le transcript de session, selon la version de Claude Code).
3. Essaie de lire un fichier plus gros que `maxFileTokenLimit * 4` octets —
   l'appel `Read` devrait être refusé avec un message suggérant `grep`/une
   lecture par plage.
4. Force deux échecs d'outil consécutifs dans la même session/agent (par ex.
   deux commandes `Bash` qui échouent) — le troisième appel d'outil devrait
   être refusé par `guard-loop.sh`.

## Mesurer les économies de tokens

`bench/` contient un estimateur déterministe, sans appel API, ainsi que les
outils pour mesurer de vraies transcriptions de session quand tu veux un
chiffre exact plutôt qu'une estimation. Voir [`bench/README.md`](bench/README.md).

```bash
python3 bench/estimate_savings.py
```

## Arborescence

```
lolo-token-optimizer/
├── .claude-plugin/
│   └── plugin.json           # manifeste : nom, version, réglages
├── hooks/
│   ├── hooks.json            # câblage des hooks (vrai schéma Claude Code)
│   └── scripts/
│       ├── lib.sh                     # fonctions partagées (wrappers jq, chemins d'état)
│       ├── inject-compression-rules.sh
│       ├── subagent-start-context.sh
│       ├── check-file-size.sh
│       ├── guard-loop.sh
│       ├── track-tool-failure.sh
│       └── reset-failure-counter.sh
├── skills/
│   └── token-optimizer/
│       └── SKILL.md          # checklist de compression invocable manuellement
├── bench/
│   ├── README.md             # méthodologie : estimation synthétique vs diff de sessions réelles
│   ├── estimate_savings.py   # estimateur d'économies de tokens, synthétique et déterministe
│   ├── extract_usage.py      # parse les vraies transcriptions .jsonl de session Claude Code
│   └── fixtures/             # fichiers/log/tentative-échouée d'exemple utilisés par l'estimateur
├── cli.sh                    # diagnostics manuels (status/reset), pas une commande slash
├── install.sh                # copie le plugin dans ~/.claude/plugins/
└── README.md
```

## Limites connues / non-objectifs

- Les comptages de tokens sont des approximations basées sur les octets, pas
  un vrai tokenizer — attends-toi à un écart sur du contenu non-anglais ou
  riche en code.
- Le comportement des hooks (événements disponibles, champs
  `hookSpecificOutput`) dépend de la version de Claude Code installée ; à
  retester après une mise à jour.
- Pas de bascule automatique vers un modèle léger spécifique — le réglage
  `defaultEffort` et le skill sont des rappels/checklists pour le modèle, pas
  un mécanisme de routage imposé.
