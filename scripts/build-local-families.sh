#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="$root/local-families"
revision="$(cat "$source_dir/upstream-revision")"
cli="$(realpath -- "${1:-${INIR_CLI:-${XDG_DATA_HOME:-$HOME/.local/share}/inir/cli/inir}}")"
if [[ ! -x "$cli" ]]; then
    printf 'Pass the path to the inir-cli binary (with hub build support).\n' >&2
    exit 1
fi

build="$(mktemp -d "$source_dir/.build.XXXXXXXX")"
trap 'rm -rf -- "$build"' EXIT

git -C "$build" init -q
git -C "$build" fetch --depth=1 --no-tags https://github.com/snowarch/inir-hub.git "$revision"
git -C "$build" restore --source=FETCH_HEAD --worktree -- schema families/ii families/iris families/waffle
git -C "$build" apply "$source_dir"/{ii,iris,waffle}.patch
(cd "$build" && "$cli" hub build --out "$build/dist")

dest="$source_dir/dist"
mkdir -p -- "$dest"
cp -a -- "$build/dist/packages" "$build/dist/previews" "$dest/"
mv -f -- "$build/dist/index.json" "$dest/index.json"
printf 'Local family catalogue built in %s\n' "$dest"
