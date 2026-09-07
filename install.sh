#!/usr/bin/env bash
#
# Install or update all mx-harness skills into Claude Code's global skill directory.
#
# Usage:
#   curl -fsSL --retry 3 https://github.com/maxence2997/mx-harness/archive/refs/heads/main.tar.gz | tar -xz -C /tmp && bash /tmp/mx-harness-main/install.sh
#   ./install.sh
#
# (The tarball URL is served by codeload.github.com — deliberately NOT
#  raw.githubusercontent.com, whose per-IP rate limit 429s on shared/corporate
#  IPs. -f makes curl fail cleanly on HTTP errors instead of feeding the
#  error page to tar.)
#
# Behavior:
#   - First run: installs all skills via npx, records file hashes in ~/.mx/.mx-harness.lock
#   - Subsequent runs: updates core files (SKILL.md, README.md) unconditionally;
#     references/* files are only overwritten if the user has not modified them
#
# Requires: Node.js (npx), curl, tar

set -euo pipefail

REPO="https://github.com/maxence2997/mx-harness"
LOCK="$HOME/.mx/.mx-harness.lock"
SKILLS=(mx-doctrine mx-flow mx-brainstorm mx-team-review mx-review-triage mx-commit mx-pr)
SEARCH_PATHS=(
  "$HOME/.claude/skills"         # Claude Code
  "$HOME/.config/claude/skills"  # Claude Code (XDG)
  "$HOME/.codex/skills"          # OpenAI Codex CLI
  "$HOME/.copilot/skills"        # GitHub Copilot
  "$HOME/.cursor/skills"         # Cursor
)

# --- helpers ---

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

lock_get() {
  grep -m1 "^${1}	${2}	" "$LOCK" 2>/dev/null | cut -f3- || true
}

lock_set() {
  touch "$LOCK"
  local tmp; tmp=$(mktemp)
  grep -v "^${1}	${2}	" "$LOCK" > "$tmp" || true
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$tmp"
  mv "$tmp" "$LOCK"
}

detect_dir() {
  local skill=$1
  local from_lock; from_lock=$(lock_get "$skill" "root")
  if [[ -n "$from_lock" && -d "$from_lock" ]]; then
    echo "$from_lock"; return
  fi
  for base in "${SEARCH_PATHS[@]}"; do
    [[ -d "$base/$skill" ]] && { echo "$base/$skill"; return; }
  done
  echo ""
}

# Returns all installed locations for a skill (one per line).
detect_all_dirs() {
  local skill=$1
  local seen=()
  # Check lock-recorded root first (may be a custom location outside SEARCH_PATHS)
  local from_lock; from_lock=$(lock_get "$skill" "root")
  if [[ -n "$from_lock" && -d "$from_lock" ]]; then
    seen+=("$from_lock")
    echo "$from_lock"
  fi
  for base in "${SEARCH_PATHS[@]}"; do
    local candidate="$base/$skill"
    if [[ -d "$candidate" ]]; then
      local dup=false
      for d in "${seen[@]+"${seen[@]}"}"; do [[ "$d" == "$candidate" ]] && dup=true; done
      if ! $dup; then
        seen+=("$candidate")
        echo "$candidate"
      fi
    fi
  done
}

# --- per-skill logic ---

do_fresh_install() {
  local skill=$1
  echo "  installing..."
  npx -y skills add "$REPO" --skill "$skill" -g -y

  local skill_dir; skill_dir=$(detect_dir "$skill")
  if [[ -z "$skill_dir" ]]; then
    echo "  error: cannot detect install path" >&2
    return 1
  fi

  lock_set "$skill" "root" "$skill_dir"
  while IFS= read -r -d '' f; do
    local rel="${f#$skill_dir/}"
    lock_set "$skill" "$rel" "$(sha256 "$f")"
  done < <(find "$skill_dir" -type f -print0)
  echo "  installed at $skill_dir"
}

do_update() {
  local skill=$1 src="$2/$skill" skill_dir=$3
  echo "  updating → $skill_dir"

  local skipped=()

  while IFS= read -r -d '' src_file; do
    local rel="${src_file#$src/}"
    local dst="$skill_dir/$rel"

    if [[ "$rel" == references/* && -f "$dst" ]]; then
      local locked; locked=$(lock_get "$skill" "$rel")
      if [[ -n "$locked" ]]; then
        local current; current=$(sha256 "$dst")
        if [[ "$current" != "$locked" ]]; then
          skipped+=("$rel")
          continue
        fi
      fi
    fi

    mkdir -p "$(dirname "$dst")"
    cp "$src_file" "$dst"
    lock_set "$skill" "$rel" "$(sha256 "$dst")"
    echo "  ✓ $rel"
  done < <(find "$src" -type f -print0)

  lock_set "$skill" "root" "$skill_dir"

  for f in "${skipped[@]+"${skipped[@]}"}"; do
    echo "  ~ $f (skipped — local changes preserved)"
  done
}

# --- main ---

if ! command -v npx >/dev/null 2>&1; then
  echo "error: npx not found. Install Node.js from https://nodejs.org/" >&2
  exit 1
fi

mkdir -p "$HOME/.mx"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Fetching latest from $REPO..."
# -f: fail on HTTP errors instead of piping an error page into tar;
# --retry: raw.githubusercontent.com intermittently returns 429
if ! curl -fsSL --retry 3 --retry-delay 2 "$REPO/archive/refs/heads/main.tar.gz" | tar -xz -C "$TMP"; then
  echo "error: failed to download $REPO (rate-limited or offline). Retry in a minute." >&2
  exit 1
fi
REPO_SRC="$TMP/mx-harness-main"
if [[ ! -d "$REPO_SRC" ]]; then
  echo "error: unexpected archive layout — $REPO_SRC not found" >&2
  exit 1
fi
echo

failed=()
for skill in "${SKILLS[@]}"; do
  echo "==> $skill"
  # mapfile requires bash 4+; macOS ships bash 3.2
  skill_dirs=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && skill_dirs+=("$line")
  done < <(detect_all_dirs "$skill")
  if [[ ${#skill_dirs[@]} -eq 0 ]]; then
    do_fresh_install "$skill" || failed+=("$skill")
  else
    for skill_dir in "${skill_dirs[@]}"; do
      do_update "$skill" "$REPO_SRC" "$skill_dir" || failed+=("$skill")
    done
  fi
  echo
done

if [[ ${#failed[@]} -eq 0 ]]; then
  echo "Done. All ${#SKILLS[@]} skills up to date."
else
  echo "Done with ${#failed[@]} failure(s): ${failed[*]}"
  exit 1
fi
