#!/usr/bin/env bash
# scripts/deploy-all.sh
#
# Sync NightForge HTML to every doc root in one pass so environments
# never drift. Substitutes per-environment <title>, og:title, and og:url
# so each deploy advertises the right network.
#
# Targets:
#   apex     nightforge.jp           /var/www/explorer-main      root-owned (sudo)
#   mainnet  mainnet.nightforge.jp   /var/www/explorer-mainnet   midnight-owned
#   preview  preview.nightforge.jp   /var/www/explorer-lite      root-owned (sudo)
#   preprod  preprod.nightforge.jp   /var/www/explorer-preprod   midnight-owned
#
# Usage:
#   ./scripts/deploy-all.sh                  # deploy index + credential-gate
#   ./scripts/deploy-all.sh --dry-run        # show what would happen, don't write
#
# Exits non-zero if any target failed. Never silently skips.

set -uo pipefail

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_INDEX="$REPO_ROOT/website/nightforge-main.html"
SRC_CG="$REPO_ROOT/website/credential-gate.html"

if [[ ! -f "$SRC_INDEX" ]]; then
  echo "ERROR: source index not found at $SRC_INDEX" >&2
  exit 2
fi

# name | docroot | label | og_url
TARGETS=(
  "apex     | /var/www/explorer-main     | Mainnet | https://nightforge.jp"
  "mainnet  | /var/www/explorer-mainnet  | Mainnet | https://mainnet.nightforge.jp"
  "preview  | /var/www/explorer-lite     | Preview | https://preview.nightforge.jp"
  "preprod  | /var/www/explorer-preprod  | Preprod | https://preprod.nightforge.jp"
)

STAMP="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

bold()    { printf '\033[1m%s\033[0m' "$*"; }
green()   { printf '\033[32m%s\033[0m' "$*"; }
red()     { printf '\033[31m%s\033[0m' "$*"; }
yellow()  { printf '\033[33m%s\033[0m' "$*"; }
dim()     { printf '\033[2m%s\033[0m' "$*"; }

# Render an environment-specific index.html into $TMP_DIR/<name>-index.html
# then copy to the doc root, prompting for sudo if the root is not writable.
render_index() {
  local name="$1" label="$2" og_url="$3" out="$TMP_DIR/${name}-index.html"
  sed \
    -e "s|<title>NightForge Explorer - Mainnet</title>|<title>NightForge Explorer - ${label}</title>|" \
    -e "s|content=\"NightForge Explorer - Midnight Mainnet\"|content=\"NightForge Explorer - Midnight ${label}\"|" \
    -e "s|content=\"https://mainnet.nightforge.jp\"|content=\"${og_url}\"|" \
    "$SRC_INDEX" > "$out"
  echo "$out"
}

# deploy_file <src> <dest> -> 0 on success, non-zero on failure
deploy_file() {
  local src="$1" dest="$2"
  local dest_dir; dest_dir="$(dirname "$dest")"
  local needs_sudo=0
  if [[ ! -w "$dest_dir" ]] || { [[ -e "$dest" ]] && [[ ! -w "$dest" ]]; }; then
    needs_sudo=1
  fi
  if (( DRY_RUN )); then
    if (( needs_sudo )); then
      echo "  $(yellow '[dry]') would: sudo cp $src $dest"
    else
      echo "  $(dim '[dry]') would: cp $src $dest"
    fi
    return 0
  fi
  if (( needs_sudo )); then
    echo "  $(yellow 'sudo') cp $src $dest"
    sudo cp "$src" "$dest"
  else
    cp "$src" "$dest"
  fi
}

format_size() {
  local bytes="$1"
  if (( bytes >= 1048576 )); then
    awk -v b="$bytes" 'BEGIN{printf "%.1fMB", b/1048576}'
  elif (( bytes >= 1024 )); then
    awk -v b="$bytes" 'BEGIN{printf "%.1fKB", b/1024}'
  else
    echo "${bytes}B"
  fi
}

echo
echo "$(bold 'NightForge deploy-all') · $STAMP"
echo "  source index:           $SRC_INDEX ($(format_size "$(stat -c '%s' "$SRC_INDEX")"))"
[[ -f "$SRC_CG" ]] && echo "  source credential-gate: $SRC_CG ($(format_size "$(stat -c '%s' "$SRC_CG")"))"
(( DRY_RUN )) && echo "  $(yellow 'DRY RUN') — no files will be written"
echo

declare -i ok=0 fail=0
declare -a results=()

for row in "${TARGETS[@]}"; do
  name="$(   echo "$row" | awk -F'|' '{gsub(/ /,"",$1); print $1}')"
  docroot="$(echo "$row" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2}')"
  label="$(  echo "$row" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$3); print $3}')"
  og_url="$( echo "$row" | awk -F'|' '{gsub(/^[ \t]+|[ \t]+$/,"",$4); print $4}')"

  echo "$(bold "[$name]") $docroot ($label · $og_url)"

  if [[ ! -d "$docroot" ]]; then
    echo "  $(red '✗') doc root does not exist: $docroot"
    results+=("$name:MISSING")
    fail+=1
    continue
  fi

  rendered="$(render_index "$name" "$label" "$og_url")"

  step_ok=1

  if ! deploy_file "$rendered" "$docroot/index.html"; then
    echo "  $(red '✗') index.html failed"
    step_ok=0
  fi

  if [[ -f "$SRC_CG" ]]; then
    if ! deploy_file "$SRC_CG" "$docroot/credential-gate.html"; then
      echo "  $(red '✗') credential-gate.html failed"
      step_ok=0
    fi
  fi

  if (( DRY_RUN )); then
    results+=("$name:DRY")
    ok+=1
    echo
    continue
  fi

  if (( step_ok )); then
    if [[ -f "$docroot/index.html" ]]; then
      idx_size="$(stat -c '%s' "$docroot/index.html")"
      idx_mtime="$(stat -c '%y' "$docroot/index.html")"
      echo "  $(green '✓') index.html         $(format_size "$idx_size")  $idx_mtime"
    fi
    if [[ -f "$docroot/credential-gate.html" ]]; then
      cg_size="$(stat -c '%s' "$docroot/credential-gate.html")"
      echo "  $(green '✓') credential-gate    $(format_size "$cg_size")"
    fi
    results+=("$name:OK")
    ok+=1
  else
    results+=("$name:FAIL")
    fail+=1
  fi
  echo
done

echo "$(bold 'Summary')"
for r in "${results[@]}"; do
  case "${r##*:}" in
    OK)      echo "  $(green '✓') ${r%%:*}" ;;
    DRY)     echo "  $(yellow '·') ${r%%:*} (dry)" ;;
    FAIL)    echo "  $(red '✗') ${r%%:*}" ;;
    MISSING) echo "  $(red '✗') ${r%%:*} (doc root missing)" ;;
  esac
done
echo "  ok=$ok fail=$fail at $STAMP"

(( fail == 0 )) || exit 1
exit 0
