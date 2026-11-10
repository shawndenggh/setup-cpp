# setup-cpp

[![Test](https://github.com/shawndenggh/setup-cpp/actions/workflows/test.yml/badge.svg)](https://github.com/shawndenggh/setup-cpp/actions/workflows/test.yml)

Install Ubuntu's default GCC, G++, make and C/C++ development headers. Configure an APT mirror for self-hosted runners, including ARC runners in mainland China.

```yaml
- name: Set up C/C++
  uses: shawndenggh/setup-cpp@v1
  timeout-minutes: 8
  with:
    mirror: https://mirrors.aliyun.com/ubuntu
```

## Input

| Input | Default | Description |
| --- | --- | --- |
| `mirror` | empty | Full Ubuntu archive URL. Empty uses the runner's existing APT sources. |

For Aliyun, use `https://mirrors.aliyun.com/ubuntu` on x86_64 or `https://mirrors.aliyun.com/ubuntu-ports` on ARM64. An internal mirror is also supported. The archive must provide the runner's Ubuntu codename, updates and security suites. For non-Alibaba-Cloud hosts, use the public mirror domain, not the ECS-only internal endpoint.

Requires Ubuntu, Bash, and root or passwordless sudo for installation. HTTPS mirrors require CA certificates to be installed in the runner image. GCC versions follow the Ubuntu distribution; this action does not select arbitrary compiler versions or support macOS/Windows.

## Behavior

- Installs `build-essential` and required dependencies with `--no-install-recommends`.
- With `mirror`, uses a temporary Deb822 source file and excludes other repositories, including PPAs. Does not rewrite `/etc/apt` and retains Ubuntu archive signature verification.
- Skips APT when `build-essential` is already installed, while still compiling and running C/C++ smoke checks.
- Exports `CC=gcc` and `CXX=g++` to subsequent steps.
- Uses 30-second APT network timeouts, two retries, and fails on index download errors. Use the calling step's `timeout-minutes` to bound the entire operation.

This action does not change npm/Bun registries or caches. Mirror performance depends on the runner's network.

## Go race tests

```yaml
- uses: actions/checkout@v4
- uses: shawndenggh/setup-cpp@v1
  timeout-minutes: 8
  with:
    mirror: https://mirrors.aliyun.com/ubuntu
- uses: actions/setup-go@v5
  with:
    go-version-file: go.mod
- run: go test -race ./...
  env:
    CGO_ENABLED: '1'
```

## Development

Run `bash tests/install.sh 24.04 https://mirrors.aliyun.com/ubuntu` on an x86_64 Docker host. On ARM64, pass an `ubuntu-ports` mirror instead. Tests cover cold installation, failed mirror handling, input validation, system source preservation, and reuse without root or network access. The default test mirror is the official x86_64 Ubuntu archive.

Released versions use semantic version tags such as `v1.0.0`; `v1` is the major-version entry point. Pin a release commit SHA when immutable references are required.

## License

MIT
