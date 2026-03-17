# Opencode Docker

Dockerized `opencode` with a non-root runtime user and an interactive host-side wrapper installer.

## Files

- `Dockerfile`: builds the opencode image
- `install-opencode-wrapper.sh`: interactive installer for `/usr/local/bin/opencode`

## Image behavior

- Base image: Ubuntu 24.04
- Runtime user: `opencode` (`uid=1000`, non-root)
- Default entrypoint: `opencode`
- Working directory: `/workspace`

The image includes:

- standalone `opencode` Linux binary
- common CLI tools such as `git`, `rg`, `jq`, `zsh`
- optional AWS CLI v2
- optional OpenJDK 17 or 21
- optional Maven

## Build manually

```bash
docker build -t opencode-dev -f docker/opencode/Dockerfile docker
```

Run it directly:

```bash
docker run --rm -it \
  -v "$PWD:/workspace" \
  --workdir /workspace \
  opencode-dev --help
```

## Install local `opencode`

The installer is interactive and writes a self-contained wrapper to
`/usr/local/bin/opencode`.

```bash
sudo /Users/alexander.vivas.ext/git/alexandervivas/my-configs/docker/install-wrapper.sh
```

If you want to skip the agent prompt:

```bash
sudo /Users/alexander.vivas.ext/git/alexandervivas/my-configs/docker/install-wrapper.sh opencode
```

The installer asks for a few grouped defaults such as:

- auth mode: `bedrock` or `other`
- image extras in one prompt: `java`, `all`, `none`
- host mounts in one prompt: `aws`, `ssh`, `opencode`, `all`, `none`
- selecting `java` also enables Maven and `~/.m2` mounting automatically
- `~/.gitconfig` mounting is always enabled by default
- pressing Enter on the multi-select prompts means `none`
- if auth mode is `bedrock`, AWS CLI and AWS mounting defaults are implied automatically
- follow-up specifics only when needed, for example Java version if `java` is selected
- default opencode version

Those answers are baked into the generated wrapper as defaults, but you can
still override them later with environment variables.

After that, calling `opencode` on the host will:

- build the Docker image on first use if missing
- mount the current directory to `/workspace`
- persist `~/.cache/opencode`, `~/.config/opencode`, `~/.local/share/opencode`, and `~/.local/state/opencode`
- forward AWS environment variables into the container
- forward all CLI arguments to the Dockerized `opencode`

Example:

```bash
opencode --version
AWS_PROFILE=claude AWS_REGION=eu-west-1 opencode
opencode run "summarize this repository"
```

## Installer variables

You can override these when generating the wrapper:

```bash
IMAGE_NAME=opencode-dev-test INSTALL_PATH=/tmp/opencode bash docker/install-wrapper.sh opencode
```

Supported variables:

- `INSTALL_PATH`: target path for the generated wrapper
- `IMAGE_NAME`: Docker image tag used by the generated wrapper
- `INTERACTIVE=0`: skip prompts and use env/default values

## Runtime parameterization

The generated wrapper stores installer-selected defaults, and is also driven by
environment variables so you can keep one installed `opencode` command and vary
the image features per project.

Build-related variables:

- `OPENCODE_DOCKER_IMAGE_REPO`: image repository prefix, default `opencode-dev`
- `OPENCODE_DOCKER_IMAGE_NAME`: full image name override
- `OPENCODE_DOCKER_FORCE_BUILD`: rebuild even if the computed image already exists
- `OPENCODE_DOCKER_INSTALL_AWSCLI`: `1` or `0`, default `1`
- `OPENCODE_DOCKER_INSTALL_OPENCODE`: `1` or `0`, default `1`
- `OPENCODE_DOCKER_OPENCODE_VERSION`: opencode version, default `1.2.27`
- `OPENCODE_DOCKER_INSTALL_JAVA`: `1` or `0`, default `0`
- `OPENCODE_DOCKER_JAVA_VERSION`: `17` or `21`, default `21`
- `OPENCODE_DOCKER_INSTALL_MAVEN`: `1` or `0`, default `0`

Runtime/auth variables:

- `OPENCODE_DOCKER_AUTH_MODE`: `bedrock` or `other`, default `bedrock`
- `OPENCODE_DOCKER_MOUNT_AWS`: `auto`, `on`, or `off`
- `OPENCODE_DOCKER_MOUNT_SSH`: `1` or `0`
- `OPENCODE_DOCKER_MOUNT_GITCONFIG`: `1` or `0`
- `OPENCODE_DOCKER_MOUNT_M2`: `1` or `0`
- `OPENCODE_DOCKER_MOUNT_OPENCODE_CONFIG`: `1` or `0`
- `AWS_PROFILE`, `AWS_REGION`, `AWS_DEFAULT_REGION`

Examples:

```bash
AWS_PROFILE=claude AWS_REGION=eu-west-1 opencode
OPENCODE_DOCKER_INSTALL_JAVA=1 OPENCODE_DOCKER_JAVA_VERSION=21 opencode --version
OPENCODE_DOCKER_FORCE_BUILD=1 OPENCODE_DOCKER_OPENCODE_VERSION=1.2.27 opencode --version
```

## Runtime mounts

The generated wrapper always mounts:

- `"$PWD"` to `/workspace`
- `~/.cache/opencode` to `/home/opencode/.cache/opencode`
- `~/.local/share/opencode` to `/home/opencode/.local/share/opencode`
- `~/.local/state/opencode` to `/home/opencode/.local/state/opencode`

If enabled, it also mounts:

- `~/.config/opencode` to `/home/opencode/.config/opencode`
- `~/.ssh` read-only
- `~/.gitconfig` read-only
- `~/.m2` read-write
- `~/.aws` read-write in Bedrock mode so AWS SSO can refresh tokens in `~/.aws/sso/cache`

## Notes

- Your current host config at `~/.config/opencode/opencode.json` can continue to define the Bedrock provider, profile, and region.
- Runtime `AWS_PROFILE` and `AWS_REGION` are still forwarded so you can keep using the same launch pattern inside the wrapper.
- `opencode` writes a local database under `~/.local/share/opencode`, so mounting only config and cache is not sufficient.
