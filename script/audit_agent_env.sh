#!/usr/bin/env bash
# Inspect which AI coding agents set which env vars on the current shell.
# Run this INSIDE each agent's shell session and compare outputs to keep
# PortPirate's detection rules honest.
#
# Usage:
#   script/audit_agent_env.sh            # show env + installed agents (default)
#   script/audit_agent_env.sh --list     # just list installed agent CLIs
#   script/audit_agent_env.sh --help

set -euo pipefail

mode="audit"
case "${1:-}" in
  --list) mode="list" ;;
  --help|-h)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
    exit 0 ;;
  "") ;;
  *) echo "unknown flag: $1" >&2; exit 2 ;;
esac

agent_clis=(
  "claude:Claude Code (Anthropic)"
  "cursor-agent:Cursor agent CLI"
  "codex:OpenAI Codex CLI"
  "aider:Aider"
  "opencode:opencode"
  "gemini:Google Gemini CLI"
  "gemini-cli:Google Gemini CLI (alt name)"
  "copilot:GitHub Copilot CLI"
  "auggie:Augment Code (auggie)"
  "windsurf:Windsurf"
  "qwen:Qwen Code"
  "qwen-code:Qwen Code (alt name)"
)

env_prefixes=(
  "CLAUDE_" "CLAUDECODE" "ANTHROPIC_"
  "CURSOR_"
  "CODEX_"
  "OPENCODE_"
  "AIDER_"
  "GEMINI_CLI_"
  "COPILOT_"
  "AUGMENT_" "AUGMENT_AGENT"
  "QWEN_CODE_"
  "OPENAI_"
  "AI_AGENT"
  "VSCODE_" "TERM_PROGRAM"
)

list_installed() {
  echo "Installed agent CLIs in PATH:"
  for entry in "${agent_clis[@]}"; do
    bin="${entry%%:*}"
    desc="${entry#*:}"
    if path=$(command -v "$bin" 2>/dev/null); then
      printf "  [x] %-14s %s  (%s)\n" "$bin" "$path" "$desc"
    else
      printf "  [ ] %-14s (not found)  (%s)\n" "$bin" "$desc"
    fi
  done
}

dump_env() {
  echo "Matching env vars in this shell:"
  local found=0
  while IFS= read -r line; do
    key="${line%%=*}"
    for prefix in "${env_prefixes[@]}"; do
      case "$key" in
        "$prefix"*) printf "  %s\n" "$line"; found=1; break ;;
      esac
    done
  done < <(env | sort)
  if [ "$found" -eq 0 ]; then
    echo "  (none — this shell does not appear to be inside an agent session)"
  fi
}

shell_context() {
  echo "Shell context:"
  printf "  pid               %s\n" "$$"
  printf "  ppid              %s\n" "$PPID"
  printf "  parent comm       %s\n" "$(ps -o comm= -p "$PPID" 2>/dev/null || echo unknown)"
  printf "  user              %s\n" "$(id -un)"
  printf "  date              %s\n" "$(date -Iseconds 2>/dev/null || date)"
  printf "  uname             %s %s\n" "$(uname -s)" "$(uname -r)"
}

case "$mode" in
  list)
    list_installed
    ;;
  audit)
    echo "PortPirate agent-env audit"
    echo "=========================="
    shell_context
    echo
    dump_env
    echo
    list_installed
    echo
    echo "Notes:"
    echo "  * Run this script from a shell spawned BY each agent to see which env"
    echo "    vars that agent actually exports. Then compare with the rules in"
    echo "    Sources/PortPirateCore/Services/AgentDetector.swift."
    echo "  * Empty output under 'Matching env vars' from an agent's terminal"
    echo "    means env-based detection will not fire for that agent — only the"
    echo "    parent-chain and argv signals remain."
    ;;
esac
