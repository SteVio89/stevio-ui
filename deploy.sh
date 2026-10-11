#!/usr/bin/env bash
# Copies the addon from this repo into the WoW AddOns folder.
# The repo must not live inside the WoW folder: the Battle.net updater runs a
# recursive chmod 777 there that follows symlinks (e.g. .direnv -> /nix/store).
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="${1:-/Applications/World of Warcraft/_classic_beta_/Interface/AddOns/stevio-ui}"
dest="${dest%/}"

case "$src/" in
  "$dest/"*) echo "error: repo lies inside the target ($dest)" >&2; exit 1 ;;
esac
# --delete would otherwise wipe a repo that still sits at the target.
if [ -e "$dest/.git" ]; then
  echo "error: $dest is a git repo, refusing to overwrite it" >&2
  exit 1
fi

# Same file set as the CurseForge package: .pkgmeta's ignore list plus dev-only files.
excludes=(--exclude=.git --exclude=.gitignore --exclude=.pkgmeta --exclude=.release
  --exclude=.DS_Store --exclude=.claude --exclude=deploy.sh)
while IFS= read -r path; do
  excludes+=("--exclude=/$path")
done < <(awk '/^ignore:/ { inside = 1; next } /^[^ ]/ { inside = 0 } inside && /^ *- / { sub(/^ *- */, ""); print }' "$src/.pkgmeta")

mkdir -p "$dest"
rsync -rlt --delete --delete-excluded "${excludes[@]}" "$src/" "$dest/"
echo "deployed to $dest"
