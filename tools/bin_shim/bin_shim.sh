set -efu
# set -x
FLAKE=${FLAKE:-.}
echo "$FLAKE"

pkg=$1
shift

flake=$(nix flake prefetch "$FLAKE" --json 2>/dev/null | jq -r .storePath)
hash=$(echo "$flake" | md5sum | cut -d' ' -f1)

# Use XDG_RUNTIME_DIR if available, otherwise /tmp
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
  cache_dir="$XDG_RUNTIME_DIR/bin_shim/$hash"
else
  cache_dir="/tmp/bin_shim-$(id -u)/$hash"
fi
mkdir -p "$cache_dir"
if ! [ -e "$cache_dir"/"$pkg" ]; then
  out=$(nix build "$flake"#"$pkg" --no-link --print-out-paths)
  mainProgram=$(nix eval --raw "$flake"#"$pkg".meta.mainProgram)
  echo "$out"/bin/"$mainProgram" > "$cache_dir"/"$pkg"
fi
 exec "$(cat "$cache_dir"/"$pkg")" "$@"
