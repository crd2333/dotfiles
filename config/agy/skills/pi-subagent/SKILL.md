---
name: pi-subagent
description: Delegate coding, code review, refactoring, research, or codebase exploration tasks to the local Pi coding agent (pi) using its headless profile (~/.pi/agent-headless) and non-Gemini models to save Antigravity quota. Use when the user asks to offload work to Pi or run a Pi subagent.
---

# Pi Headless Subagent

Delegate bounded tasks to the locally installed `pi` CLI using the dedicated headless profile (`~/.pi/agent-headless`). This profile strips user-interactive extensions (`ask-user`, `permission-system`, `yolo`, `computer-use`, `pi-agy-acp`, etc.), keeps essential adapters (`pi-client-fingerprint`, `pi-codex-adapter`, `pi-vcc`, and non-interactive `pi-crd233` tools), and stores headless sessions separately from interactive `pi --continue`.

## How to Invoke

Always `cd` into the target workspace first, feed the prompt over stdin to avoid shell-quoting issues, and pass `-p -na` (`--print --no-approve`) with `PI_CODING_AGENT_DIR`, `PI_OFFLINE=1`, and `PI_SKIP_VERSION_CHECK=1`.

### Linux / macOS (bash)

```bash
cd /path/to/repo
command -v pi >/dev/null || export PATH="$HOME/.config/nvm/versions/node/$(ls -1 "$HOME/.config/nvm/versions/node" 2>/dev/null | sort -V | tail -n 1)/bin:$PATH"
PI_CODING_AGENT_DIR="$HOME/.pi/agent-headless" PI_OFFLINE=1 PI_SKIP_VERSION_CHECK=1 \
  pi -p -na --no-session <<'EOF'
<clear, self-contained task prompt>
EOF
```

### Windows (PowerShell)

```powershell
Set-Location C:\path\to\repo
$env:PI_CODING_AGENT_DIR = "$HOME\.pi\agent-headless"
$env:PI_OFFLINE = "1"
$env:PI_SKIP_VERSION_CHECK = "1"
@'
<clear, self-contained task prompt>
'@ | pi -p -na --no-session
```

## Task Modes & Options

- **Read-only exploration / review / research**: add `--tools read,grep,find,ls,fffind,ffgrep,tool_search` so `pi` cannot modify files or run shell commands while retaining fast search and web/docs tools.
- **Implementation / edits / running tests**: omit `--tools` to use the profile defaults (`read`, `bash`, `edit`, `write`, `codemode`, `tool_search`).
- **One-shot task**: pass `--no-session`.
- **Multi-turn (stop-and-interact)**: replace `--no-session` with `--session-id <slug>` (alphanumeric plus `-`, `_`, `.`; must start and end with alphanumeric). Re-run in the same working directory with the same `--session-id` to continue the conversation with preserved context.
- **Model selection**: omit `--model` to use the headless default (non-Gemini, configured in `~/.pi/agent-headless/settings.json`). Pass `--model <provider/id[:thinking]>` when a specific model is requested. Do not route to Gemini/Antigravity models unless the user explicitly asks. List available models with `PI_CODING_AGENT_DIR="$HOME/.pi/agent-headless" PI_OFFLINE=1 pi --list-models`.

## Execution & Handoff Hygiene

1. **Avoid polling**: for tasks expected to take more than a few seconds, launch `run_command` asynchronously (`WaitMsBeforeAsync: 500`, `NotificationTimeoutSeconds: 300`) so completion triggers automatic wakeup without burning extra coordinator turns.
2. **Scope the prompt tightly**: specify target file paths, constraints, and ask for a concise final summary (key findings, modified files, and verification commands run).
3. **Verify write runs**: after `pi` edits code, inspect `git status --short` / `git diff --stat` or run targeted checks before reporting completion.
