#!/usr/bin/env bash
#
# Builds the Composer images on a workstation the way the GitHub workflow
# .github/workflows/docker.build.yaml does, and optionally pushes them.
# Meant for the case that GitHub Actions is not available.
#
# Runs with the Bash 3.2 that ships with macOS.

set -euo pipefail

BASE_IMAGE="harbor.flownative.io/docker/php"
PLATFORMS="linux/amd64,linux/arm64"
SOURCE_URL="https://github.com/flownative/docker-composer"
WORKFLOW_FILE=".github/workflows/docker.build.yaml"
# Like on GitHub, the matrix comes from the workflow on main, while the
# code is the one of the latest release tag.
WORKFLOW_REF="origin/main"

# The images of a variant: "composer" runs as the composer user, "root" as root
images_for() {
    case "$1" in
        root) echo "flownative/composer2-root harbor.flownative.io/docker/composer2-root" ;;
        *) echo "flownative/composer2 harbor.flownative.io/docker/composer2" ;;
    esac
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Builds the Composer images from the latest release tag, with the same
tags, labels and platforms as the GitHub workflow, for the users
"composer" and "root". Each image is based on the newest
harbor.flownative.io/docker/php image of its PHP branch, so build
docker-php first if it needs to be rebuilt as well.

Without --build or --push only the plan is shown.

Options:
  --php <branch>      Only build this PHP branch, e.g. 8.4
  --user <user>       Only build this variant: composer or root
  --ref <tag>         Build this Git tag instead of the latest release tag
  --build             Build all platforms, but do not push (e.g. to measure)
  --push              Build and push to Docker Hub and Harbor
  --builder <name>    Buildx builder to use (default: flownative, created if missing)
  --no-cache          Build from scratch
  --yes               Do not ask before pushing
  -h, --help          Show this help

Log in first:
  docker login
  docker login harbor.flownative.io
EOF
}

info() { printf '\033[1m%s\033[0m\n' "$*"; }
warn() { printf '\033[33mWarning: %s\033[0m\n' "$*" >&2; }
fail() { printf '\033[31mError: %s\033[0m\n' "$*" >&2; exit 1; }

php_filter=""
user_filter=""
ref=""
mode="plan"
builder="flownative"
assume_yes=false
use_cache=true

while [ $# -gt 0 ]; do
    case "$1" in
        --php) php_filter="${2:?--php needs a PHP branch}"; shift 2 ;;
        --user) user_filter="${2:?--user needs composer or root}"; shift 2 ;;
        --ref) ref="${2:?--ref needs a tag}"; shift 2 ;;
        --build) mode="build"; shift ;;
        --push) mode="push"; shift ;;
        --builder) builder="${2:?--builder needs a name}"; shift 2 ;;
        --yes) assume_yes=true; shift ;;
        --no-cache) use_cache=false; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; echo >&2; fail "Unknown option: $1" ;;
    esac
done

command -v docker >/dev/null || fail "docker is not installed"
docker buildx version >/dev/null 2>&1 || fail "docker buildx is not available"

repository_root="$(cd "$(dirname "$0")/.." && git rev-parse --show-toplevel)"

# --- Source -------------------------------------------------------------------

# GitHub may be the very thing that is down, so local tags have to do then.
if ! git -C "${repository_root}" fetch --quiet --tags --force origin 2>/dev/null; then
    warn "Could not fetch tags from origin, using the tags known locally"
fi

if [ -z "${ref}" ]; then
    ref="$(git -C "${repository_root}" tag --list 'v*.*.*' --sort=-v:refname | head -n 1)"
    [ -n "${ref}" ] || fail "No release tag found"
fi
git -C "${repository_root}" rev-parse --verify --quiet "${ref}^{commit}" >/dev/null \
    || fail "Unknown ref: ${ref}"

work_directory="$(mktemp -d)"
worktree="${work_directory}/source"
cleanup() {
    git -C "${repository_root}" worktree remove --force "${worktree}" 2>/dev/null || true
    rm -rf "${work_directory}"
}
trap cleanup EXIT

git -C "${repository_root}" worktree add --quiet --detach "${worktree}" "${ref}"
revision="$(git -C "${worktree}" rev-parse HEAD)"
created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
workflow="${work_directory}/workflow.yaml"
git -C "${repository_root}" show "${WORKFLOW_REF}:${WORKFLOW_FILE}" > "${workflow}" \
    || fail "Could not read ${WORKFLOW_FILE} from ${WORKFLOW_REF}"

# --- Matrix -------------------------------------------------------------------

# Reads a matrix line such as: php: [ "8.2", "8.3", "8.4", "8.5" ]
matrix_values() {
    sed -n "s/^[[:space:]]*$1:[[:space:]]*\[\(.*\)\].*\$/\1/p" "${workflow}" \
        | head -n 1 | tr -d '"'"'" | tr ',' ' ' | tr -s ' ' | sed 's/^ //; s/ $//'
}

php_matrix="$(matrix_values php)"
[ -n "${php_matrix}" ] || fail "No PHP branches found in ${WORKFLOW_FILE} of ${WORKFLOW_REF}"
user_matrix="$(matrix_values user)"
[ -n "${user_matrix}" ] || fail "No users found in ${WORKFLOW_FILE} of ${WORKFLOW_REF}"

branches=""
for branch in ${php_matrix}; do
    echo "${branch}" | grep -Eq '^[0-9]+\.[0-9]+$' \
        || fail "Unexpected PHP branch '${branch}' in ${WORKFLOW_FILE}"
    if [ -z "${php_filter}" ] || [ "${php_filter}" = "${branch}" ]; then
        branches="${branches} ${branch}"
    fi
done
[ -n "${branches}" ] || fail "PHP ${php_filter} is not built according to ${WORKFLOW_REF} (available: ${php_matrix})"

users=""
for user in ${user_matrix}; do
    case "${user}" in
        composer|root) ;;
        *) fail "Unexpected user '${user}' in ${WORKFLOW_FILE}" ;;
    esac
    if [ -z "${user_filter}" ] || [ "${user_filter}" = "${user}" ]; then
        users="${users} ${user}"
    fi
done
[ -n "${users}" ] || fail "User ${user_filter} is not built according to ${WORKFLOW_REF} (available: ${user_matrix})"

# Like flownative/action-docker-get-label: the PHP version is the one of the
# newest PHP image of that branch.
latest_php_version() {
    docker buildx imagetools inspect "${BASE_IMAGE}:$1" \
        --format '{{ index (index .Image "linux/amd64").Config.Labels "org.opencontainers.image.version" }}' 2>/dev/null
}

versions=""
for branch in ${branches}; do
    version="$(latest_php_version "${branch}")" \
        || fail "Could not read ${BASE_IMAGE}:${branch}; are you logged in (docker login harbor.flownative.io)?"
    echo "${version}" | grep -Eq "^${branch//./\\.}\.[0-9]+$" \
        || fail "${BASE_IMAGE}:${branch} has an unexpected version label: '${version}'"
    versions="${versions} ${version}"
done

tags_for() {
    local version="$1" user="$2" image
    for image in $(images_for "${user}"); do
        echo "${image}:${version%.*}"
        echo "${image}:${version}"
    done
}

# --- Plan ---------------------------------------------------------------------

info "Source:    ${ref} (${revision})"
info "Matrix:    ${WORKFLOW_FILE} on ${WORKFLOW_REF}"
info "Platforms: ${PLATFORMS}"
info "Mode:      ${mode}"
info "Cache:     ${use_cache}"
for version in ${versions}; do
    for user in ${users}; do
        echo
        info "PHP ${version}, user ${user} (from ${BASE_IMAGE}:${version})"
        tags_for "${version}" "${user}" | sed 's/^/  /'
    done
done
echo

if [ "${mode}" = "plan" ]; then
    echo "Nothing was built. Use --build to build or --push to build and push."
    exit 0
fi

# --- Preconditions ------------------------------------------------------------

if [ "${mode}" = "push" ]; then
    docker_config="${DOCKER_CONFIG:-${HOME}/.docker}/config.json"
    for registry in "https://index.docker.io/v1/" "harbor.flownative.io"; do
        grep -q "\"${registry}\"" "${docker_config}" 2>/dev/null \
            || fail "Not logged in to ${registry}, run: docker login ${registry#https://index.docker.io/v1/}"
    done

    if [ "${assume_yes}" != true ]; then
        [ -t 0 ] || fail "Refusing to push without confirmation, pass --yes"
        read -r -p "Push these images to Docker Hub and Harbor? [y/N] " answer
        case "${answer}" in
            y|Y|yes) ;;
            *) echo "Aborted."; exit 1 ;;
        esac
    fi
fi

if ! docker buildx inspect "${builder}" >/dev/null 2>&1; then
    info "Creating buildx builder ${builder}"
    docker buildx create --name "${builder}" --driver docker-container --bootstrap >/dev/null
fi

# The workflow appends the USER statement to the Dockerfile; here every
# variant gets a Dockerfile of its own.
for user in ${users}; do
    cp "${worktree}/Dockerfile" "${work_directory}/Dockerfile.${user}"
    echo "USER ${user}" >> "${work_directory}/Dockerfile.${user}"
done

# --- Build --------------------------------------------------------------------

summary=""
for version in ${versions}; do
    for user in ${users}; do
        metadata_file="${work_directory}/metadata-${version}-${user}.json"

        # --pull, because the nightly builds of docker-php replace the image
        # behind the same tag, and composer:2 moves with every release.
        arguments=(
            --builder "${builder}"
            --platform "${PLATFORMS}"
            --pull
            --file "${work_directory}/Dockerfile.${user}"
            --build-arg "PHP_BASE_IMAGE=${BASE_IMAGE}:${version}"
            --label "org.opencontainers.image.title=Composer"
            --label "org.opencontainers.image.description=Docker image providing Composer 2 for Beach and Local Beach"
            --label "org.opencontainers.image.licenses=MIT"
            --label "org.opencontainers.image.vendor=Flownative GmbH"
            --label "org.opencontainers.image.authors=Robert Lemke <robert@flownative.com>"
            --label "org.opencontainers.image.version=${version}"
            --label "org.opencontainers.image.created=${created}"
            --label "org.opencontainers.image.revision=${revision}"
            --label "org.opencontainers.image.source=${SOURCE_URL}"
            --label "org.opencontainers.image.url=${SOURCE_URL}"
            --metadata-file "${metadata_file}"
        )
        if [ "${use_cache}" != true ]; then
            arguments+=(--no-cache)
        fi
        for tag in $(tags_for "${version}" "${user}"); do
            arguments+=(--tag "${tag}")
        done
        if [ "${mode}" = "push" ]; then
            # Like docker/build-push-action does for public repositories
            arguments+=(--push --provenance "mode=max")
        fi

        info "Building PHP ${version}, user ${user}"
        started=${SECONDS}
        if ! docker buildx build "${arguments[@]}" "${worktree}"; then
            fail "Build of PHP ${version}, user ${user} failed after $(( (SECONDS - started) / 60 )) min"
        fi
        duration=$(( SECONDS - started ))

        digest="$(sed -n 's/.*"containerimage\.digest":[[:space:]]*"\([^"]*\)".*/\1/p' "${metadata_file}" | head -n 1)"
        summary="${summary}$(printf '  PHP %-8s %-9s %3d min %02d s  %s' "${version}" "${user}" $((duration / 60)) $((duration % 60)) "${digest}")
"
    done
done

# --- Summary ------------------------------------------------------------------

echo
info "Done (${mode})"
printf '%s' "${summary}"
