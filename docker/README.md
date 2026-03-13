# Claude Docker

Dockerized Claude Code with a non-root runtime user and a host-side wrapper installer.

## Files

- `Dockerfile`: builds the Claude image
- `install-claude-wrapper.sh`: installs a `claude` wrapper into `/usr/local/bin/claude`
- `.env.example`: example environment values

## Image behavior

- Base image: Ubuntu 24.04
- Runtime user: `claude` (`uid=1000`, non-root)
- Default entrypoint: `claude`
- Working directory: `/workspace`

The image includes:

- Node.js 22
- native-installed Claude Code
- common CLI tools such as `git`, `rg`, `jq`, `zsh`
- optional AWS CLI v2
- optional OpenJDK 17 or 21
- optional Maven

## Build manually

```bash
docker build -t claude-dev -f docker/Dockerfile docker
```

Run it directly:

```bash
docker run --rm -it \
  -v "$PWD:/workspace" \
  --workdir /workspace \
  claude-dev --help
```

## Install local `claude`

The installer writes a self-contained wrapper to `/usr/local/bin/claude`.

```bash
sudo /Users/alexander.vivas.ext/git/alexandervivas/my-configs/docker/install-claude-wrapper.sh
```

After that, calling `claude` on the host will:

- build the Docker image on first use if missing
- mount the current directory to `/workspace`
- persist `~/.claude`, `~/.cache/claude-docker`, and `~/.config/claude-docker`
- forward Claude-related environment variables into the container
- forward all CLI arguments to the Dockerized `claude`

Example:

```bash
claude --version
claude
claude -p "summarize this repository"
```

## Installer variables

You can override these when generating the wrapper:

```bash
IMAGE_NAME=claude-dev-test INSTALL_PATH=/tmp/claude bash docker/install-claude-wrapper.sh
```

Supported variables:

- `INSTALL_PATH`: target path for the generated wrapper
- `IMAGE_NAME`: Docker image tag used by the generated wrapper

## Runtime parameterization

The generated wrapper is driven by environment variables so you can keep one
installed `claude` command and vary the image features per project.

Build-related variables:

- `CLAUDE_DOCKER_IMAGE_REPO`: image repository prefix, default `claude-dev`
- `CLAUDE_DOCKER_IMAGE_NAME`: full image name override
- `CLAUDE_DOCKER_FORCE_BUILD`: rebuild even if the computed image already exists
- `CLAUDE_DOCKER_INSTALL_AWSCLI`: `1` or `0`, default `1`
- `CLAUDE_DOCKER_INSTALL_NODE`: `1` or `0`, default `1`
- `CLAUDE_DOCKER_INSTALL_CLAUDE`: `1` or `0`, default `1`
- `CLAUDE_DOCKER_CLAUDE_VERSION`: native Claude version, default `latest`
- `CLAUDE_DOCKER_NODE_MAJOR`: Node major version, default `22`
- `CLAUDE_DOCKER_INSTALL_JAVA`: `1` or `0`, default `0`
- `CLAUDE_DOCKER_JAVA_VERSION`: `17` or `21`, default `21`
- `CLAUDE_DOCKER_INSTALL_MAVEN`: `1` or `0`, default `0`

Runtime/auth variables:

- `CLAUDE_DOCKER_AUTH_MODE`: `anthropic` or `bedrock`, default `anthropic`
- `AWS_PROFILE`, `AWS_REGION`, `AWS_DEFAULT_REGION`, `BEDROCK_MODEL_ID`
- `ANTHROPIC_API_KEY`, `ANTHROPIC_BASE_URL`

Examples:

```bash
CLAUDE_DOCKER_INSTALL_JAVA=1 CLAUDE_DOCKER_JAVA_VERSION=21 claude --version
CLAUDE_DOCKER_INSTALL_JAVA=1 CLAUDE_DOCKER_INSTALL_MAVEN=1 claude --version
CLAUDE_DOCKER_AUTH_MODE=bedrock AWS_PROFILE=default AWS_REGION=us-east-1 claude
CLAUDE_DOCKER_FORCE_BUILD=1 CLAUDE_DOCKER_CLAUDE_VERSION=latest claude --version
```

## Runtime mounts

The generated wrapper always mounts:

- `"$PWD"` to `/workspace`
- `~/.claude` to `/home/claude/.claude`
- `~/.cache/claude-docker` to `/home/claude/.cache`
- `~/.config/claude-docker` to `/home/claude/.config`

If present, it also mounts read-only:

- `~/.aws`
- `~/.ssh`
- `~/.gitconfig`

If present, it also mounts read-write:

- `~/.m2`

## Verification

Verified locally with:

```bash
docker build -t claude-dev-test -f docker/Dockerfile docker
docker run --rm --entrypoint sh claude-dev-test -lc 'id && which claude && claude --version'
docker run --rm claude-dev-test --help
```
