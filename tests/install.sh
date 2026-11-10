#!/usr/bin/env bash
set -euo pipefail

action_dir="$(cd "$(dirname "$0")/.." && pwd)"
ubuntu_version="${1:-24.04}"
mirror="${2:-https://archive.ubuntu.com/ubuntu}"
make_only="${3:-false}"
ca_bundle="${SSL_CERT_FILE:-/etc/ssl/certs/ca-certificates.crt}"
container="$(docker run -d \
  -e "SETUP_CPP_MAKE_ONLY=$make_only" \
  --mount "type=bind,src=$action_dir,dst=/action,readonly" \
  --mount "type=bind,src=$ca_bundle,dst=/etc/ssl/certs/ca-certificates.crt,readonly" \
  "ubuntu:$ubuntu_version" sleep infinity)"
trap 'docker rm -f "$container" >/dev/null' EXIT

if docker exec -e SETUP_CPP_MAKE_ONLY=invalid "$container" bash /action/setup.sh; then
  echo 'Invalid make-only input was accepted.' >&2
  exit 1
fi

if docker exec -e SETUP_CPP_MIRROR='https://example.com/ubuntu extra' "$container" bash /action/setup.sh; then
  echo 'Invalid mirror input was accepted.' >&2
  exit 1
fi

status=0
docker exec -e SETUP_CPP_MIRROR=http://127.0.0.1:9/ubuntu "$container" bash /action/setup.sh || status=$?
[[ "$status" -eq 100 ]]

# An unreachable PPA must not affect installation through the chosen mirror.
docker exec "$container" sh -c 'echo "deb http://127.0.0.1:9/ppa noble main" > /etc/apt/sources.list.d/unreachable.list'
sources_before="$(docker exec "$container" sh -c 'find /etc/apt -type f -exec sha256sum {} + | sort')"
docker exec -e SETUP_CPP_MIRROR="$mirror" "$container" bash /action/setup.sh
sources_after="$(docker exec "$container" sh -c 'find /etc/apt -type f -exec sha256sum {} + | sort')"
[[ "$sources_before" == "$sources_after" ]]

if [[ "$make_only" == true ]]; then
  docker exec "$container" sh -c '! command -v gcc && ! command -v g++ && ! test -f /usr/include/stdio.h'
fi

# Installed toolchains must work without sudo or a reachable mirror.
docker exec --user 1000:1000 "$container" sh -c 'echo KEEP=1 > /tmp/toolchain-env'
docker exec --user 1000:1000 \
  -e SETUP_CPP_MIRROR=http://127.0.0.1:9/ubuntu \
  -e GITHUB_ENV=/tmp/toolchain-env \
  "$container" bash /action/setup.sh
expected_env='KEEP=1'
if [[ "$make_only" == false ]]; then
  expected_env+=$'\nCC=gcc\nCXX=g++'
fi
[[ "$(docker exec "$container" cat /tmp/toolchain-env)" == "$expected_env" ]]
echo 'Installation checks passed.'
