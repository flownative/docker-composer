[![MIT license](http://img.shields.io/badge/license-MIT-brightgreen.svg)](http://opensource.org/licenses/MIT)
[![Maintenance level: Love](https://img.shields.io/badge/maintenance-%E2%99%A1%E2%99%A1%E2%99%A1-ff69b4.svg)](https://www.flownative.com/en/products/open-source.html)

# Composer Docker Image

This Docker image provides [Composer](https://getcomposer.org/) based on
the Flownative Beach PHP images. By configuring your shell you can use
this image as a replacement for a regular locally installed Composer.

You may want to use this solution if you need to maintain projects using
Composer and Local Beach or Flownative Beach, because the PHP images
used for the development and hosting environment will be exactly the
same like the one used as a base for this image.

## Shell Configuration

To simplify the `docker run` calls, you may want to configure your shell
to do the heavy lifting for you. The easiest way is to declare functions
in your `.bashrc`, `.zshrc` or other shell profile.

For example, in order to use Composer based on PHP 7.4 with ZSH, add the
following to your `.zshrc` or the like:

```
composer85 () {
    tty=
    tty -s && tty=--tty
    docker run \
        $tty \
        --interactive \
        --rm \
        --user $(id -u):$(id -g) \
        --volume /etc/passwd:/etc/passwd:ro \
        --volume /etc/group:/etc/group:ro \
        --volume $(pwd):/application:delegated \
        --volume $HOME/.composer/cache:/home/composer/cache:delegated \
        --volume $HOME/.composer/auth.json:/home/composer/auth.json \
        flownative/composer:8.5 "$@"
}
```

Now you can run Composer simply by running something like the following:

```
composer85 -v update
```

## Private Packagist

If dependencies are located in Private Packagist, you need to provide
the HTTP Basic Auth credentials to the Composer container via the
`COMPOSER_AUTH` environment variable. Credentials are provided as a JSON
string ( [see Composer documentation](https://getcomposer.org/doc/articles/http-basic-authentication.md)).

```
composer85 () {
    tty=
    tty -s && tty=--tty
    docker run \
        $tty \
        --interactive \
        --rm \
        --user $(id -u):$(id -g) \
        -e COMPOSER_AUTH="{"http-basic":{"repo.packagist.com":{"username":"token","password":"a524b…8ace"}}" \
        --volume /etc/passwd:/etc/passwd:ro \
        --volume /etc/group:/etc/group:ro \
        --volume $(pwd):/application:delegated \
        --volume $HOME/.composer/cache:/home/composer/cache:delegated \
        --volume $HOME/.composer/auth.json:/home/composer/auth.json \
        flownative/composer:8.5 "$@"
}
```

## Building without GitHub Actions

If GitHub Actions is not available, `bin/build-and-push.sh` builds the
images on a workstation the way the build workflow does: from the latest
release tag, for `linux/amd64` and `linux/arm64`, for the users
`composer` and `root`, with the same tags and labels. The PHP branches
come from `.github/workflows/docker.build.yaml` of that tag, and each
image is based on the newest `harbor.flownative.io/docker/php` image of
its branch, so rebuild [docker-php](https://github.com/flownative/docker-php)
first if needed.

```bash
docker login
docker login harbor.flownative.io

bin/build-and-push.sh                                # show what would be built
bin/build-and-push.sh --push                         # build and push everything
bin/build-and-push.sh --push --php 8.4 --user root   # only one variant
```

`--build` builds without pushing, `--ref <tag>` builds another tag, and
`--no-cache` builds from scratch. See `bin/build-and-push.sh --help`.
