#!/bin/bash
# shellcheck disable=SC1090
# shellcheck disable=SC2086
# shellcheck disable=SC2046

# Load helper libraries

. "${FLOWNATIVE_LIB_PATH}/banner.sh"
. "${FLOWNATIVE_LIB_PATH}/log.sh"
. "${FLOWNATIVE_LIB_PATH}/packages.sh"

set -o errexit
set -o nounset
set -o pipefail

# ---------------------------------------------------------------------------------------
# build_create_user() - Create the "composer" user and group
#
# @global APPLICATION_PATH
# @return void
#
build_create_user() {
    info "🛠 Creating user and group 'composer' (1000)"
    groupadd --gid 1000 composer
    useradd --home-dir /home/composer --shell /bin/bash --gid composer --uid 1000 composer 1>$(debug_device)

    chown -R composer:composer /home/composer
    chmod -R 775 /home/composer
}

# ---------------------------------------------------------------------------------------
# build_create_directories() - Create directories and set access rights accordingly
#
# @global BEACH_APPLICATION_PATH
# @return void
#
build_create_directories() {
    mkdir -p "${APPLICATION_PATH}" /home/composer/cache
    chown composer:composer "${APPLICATION_PATH}" /home/composer/cache
    chmod 775 "${APPLICATION_PATH}" /home/composer/cache
}

# ---------------------------------------------------------------------------------------
# build_install_packages() - Install additional packages
#
# @return void
#
build_install_packages() {
    packages_install git ssh patch unzip
    packages_remove_docs_and_caches
}

# ---------------------------------------------------------------------------------------
# Main routine

banner_flownative 'Composer'
build_create_user
build_create_directories
build_install_packages
