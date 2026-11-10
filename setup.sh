#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "::error::$*" >&2
  exit 1
}

[[ -r /etc/os-release ]] || fail 'setup-cpp requires Ubuntu.'
# shellcheck source=/dev/null
source /etc/os-release
[[ "$ID" == ubuntu && -n "${VERSION_CODENAME:-}" ]] || fail 'setup-cpp requires Ubuntu with VERSION_CODENAME.'

mirror="${SETUP_CPP_MIRROR:-}"
mirror="${mirror%/}"
if [[ -n "$mirror" && ! "$mirror" =~ ^https?://[a-zA-Z0-9.-]+(:[0-9]+)?(/[a-zA-Z0-9._~/-]+)?$ ]]; then
  fail 'mirror must be an HTTP(S) archive URL without credentials, whitespace, query or fragment.'
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
# APT's unprivileged download user needs to read the temporary source file.
chmod 755 "$work_dir"

if [[ "$(dpkg-query -W -f='${Status}' build-essential 2>/dev/null || true)" != 'install ok installed' ]]; then
  root=()
  if (( EUID != 0 )); then
    command -v sudo >/dev/null || fail 'Installing packages requires root or passwordless sudo.'
    root=(sudo -n)
  fi

  apt_options=(
    -o Acquire::Retries=2
    -o Acquire::http::Timeout=30
    -o Acquire::https::Timeout=30
    -o APT::Update::Error-Mode=any
    -o DPkg::Lock::Timeout=60
  )
  if [[ -n "$mirror" ]]; then
    [[ -r /usr/share/keyrings/ubuntu-archive-keyring.gpg ]] || fail 'Ubuntu archive signing keyring is missing.'
    cat > "$work_dir/ubuntu.sources" <<EOF
Types: deb
URIs: $mirror
Suites: $VERSION_CODENAME $VERSION_CODENAME-updates $VERSION_CODENAME-security
Components: main
Architectures: $(dpkg --print-architecture)
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
    chmod 644 "$work_dir/ubuntu.sources"
    apt_options+=(
      -o "Dir::Etc::sourcelist=$work_dir/ubuntu.sources"
      -o Dir::Etc::sourceparts=-
      -o APT::Get::List-Cleanup=0
    )
    echo "Installing build-essential from $mirror ($VERSION_CODENAME)."
  else
    echo 'Installing build-essential using the runner APT sources.'
  fi
  "${root[@]}" apt-get "${apt_options[@]}" update
  "${root[@]}" env DEBIAN_FRONTEND=noninteractive apt-get "${apt_options[@]}" install --yes --no-install-recommends build-essential
else
  echo 'build-essential is already installed; skipping APT downloads.'
fi

gcc --version
g++ --version
make --version
printf '#include <stdio.h>\nint main(void) { return puts("C toolchain OK") < 0; }\n' > "$work_dir/check.c"
printf '#include <iostream>\nint main() { std::cout << "C++ toolchain OK\\n"; }\n' > "$work_dir/check.cpp"
gcc "$work_dir/check.c" -o "$work_dir/check-c"
g++ "$work_dir/check.cpp" -o "$work_dir/check-cpp"
"$work_dir/check-c"
"$work_dir/check-cpp"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'CC=gcc\nCXX=g++\n' >> "$GITHUB_ENV"
fi
