#!/usr/bin/env bash
# Run from any directory. The sibling nim-libp2p checkout provides the source
# and its pinned Nix dependencies.
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
workspace_dir="$(cd -- "$script_dir/../.." && pwd)"
libp2p_dir="$workspace_dir/nim-libp2p"

if [[ ! -d "$libp2p_dir" ]]; then
  printf 'nim-libp2p checkout not found at %s\n' "$libp2p_dir" >&2
  exit 1
fi

swarm_result="$(nix build --impure --no-link --print-out-paths --file "$script_dir/ui-swarm.nix")"
exec "$swarm_result/bin/ui-swarm" "$@"
