#!/usr/bin/env bash
#
# Build BOTH stack images as multi-arch (linux/amd64 + linux/arm64) manifests and
# push them to the private GitHub Container Registry (GHCR) under CCTC-team.
#
#   Image A (REDCap all-in-one):  ghcr.io/cctc-team/redcap-aio:<REDCAP_VERSION>
#   Image B (Cypress runner):     ghcr.io/cctc-team/redcap-cypress:<CYPRESS_TAG>
#
# Multi-arch manifests can only live in a registry (you can't `--load` two
# platforms into the local Docker), so each image is built and `--push`ed in one
# step by a docker-container buildx builder.
#
# PREREQUISITES
#   1. Logged in to GHCR with a PAT that has write:packages:
#        echo "$CCTC_TEAM_PAT" | docker login ghcr.io -u <github-user> --password-stdin
#   2. ssh-agent holds a key with access to the private CCTC-team/rctf and
#      CCTC-team/redcap_rsvc repos (the runner's `npm ci` clones them):  ssh-add -l
#   3. QEMU emulation for cross-arch builds. Docker Desktop ships it; if a foreign
#      arch fails with "exec format error", install it once:
#        docker run --privileged --rm tonistiigi/binfmt --install all
#
# NOTE: the amd64 halves build under QEMU emulation on an arm64 Mac (Go compile,
# npm ci, pecl imagick) and are SLOW — expect tens of minutes. Building on native
# amd64 hardware / CI is much faster if this becomes a bottleneck.
#
# USAGE
#   scripts/build-and-push-ghcr.sh              # build+push both, both arches
#   AIO_ONLY=1     scripts/build-and-push-ghcr.sh
#   RUNNER_ONLY=1  scripts/build-and-push-ghcr.sh
#   PLATFORMS=linux/arm64 scripts/build-and-push-ghcr.sh   # single arch (faster)
set -euo pipefail

# --- config (override via env) ------------------------------------------------
ORG="${ORG:-ghcr.io/cctc-team}"
REDCAP_VERSION="${REDCAP_VERSION:-15.5.36}"
CYPRESS_TAG="${CYPRESS_TAG:-15.10.0}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
BUILDER="${BUILDER:-cctc-multiarch}"

AIO_IMAGE="${ORG}/redcap-aio:${REDCAP_VERSION}"
RUNNER_IMAGE="${ORG}/redcap-cypress:${CYPRESS_TAG}"

# Repo root = parent of this script's dir.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> Repo root:   $ROOT"
echo "==> Platforms:   $PLATFORMS"
echo "==> AIO image:   $AIO_IMAGE"
echo "==> Runner image:$RUNNER_IMAGE"

# --- ensure a docker-container builder exists (needed for multi-arch push) -----
if ! docker buildx inspect "$BUILDER" >/dev/null 2>&1; then
  echo "==> Creating buildx builder '$BUILDER' (docker-container driver)"
  docker buildx create --name "$BUILDER" --driver docker-container --bootstrap
fi
docker buildx use "$BUILDER"

# --- Image A: REDCap all-in-one ------------------------------------------------
if [ -z "${RUNNER_ONLY:-}" ]; then
  echo "==> Building + pushing $AIO_IMAGE ($PLATFORMS)"
  docker buildx build \
    --platform "$PLATFORMS" \
    --build-arg "REDCAP_VERSION=${REDCAP_VERSION}" \
    -f redcap_docker_aio/Dockerfile \
    -t "$AIO_IMAGE" \
    --push \
    .
fi

# --- Image B: Cypress runner (private deps cloned over forwarded SSH) -----------
if [ -z "${AIO_ONLY:-}" ]; then
  echo "==> Building + pushing $RUNNER_IMAGE ($PLATFORMS)"
  docker buildx build \
    --platform "$PLATFORMS" \
    --ssh default \
    -f redcap_cypress/cypress_runner/Dockerfile \
    -t "$RUNNER_IMAGE" \
    --push \
    redcap_cypress
fi

echo "==> Done. Verify manifests:"
[ -z "${RUNNER_ONLY:-}" ] && echo "    docker buildx imagetools inspect $AIO_IMAGE"
[ -z "${AIO_ONLY:-}" ]    && echo "    docker buildx imagetools inspect $RUNNER_IMAGE"
echo "==> Then set package visibility to PRIVATE in GitHub > CCTC-team > Packages."
