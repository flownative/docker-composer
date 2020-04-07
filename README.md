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

## Configuration

To simplify the `docker run` calls, you may want to configure your shell
to do the heavy lifting for you. The easiest way is to declare functions
in your `.bashrc`, `.zshrc` or other shell profile.

For example, in order to use Composer based on PHP 7.4 with ZSH, add the
following to your `.zshrc` or the like:

```
composer74 () {
    tty=
    tty -s && tty=--tty
    docker run \
        $tty \
        --interactive \
        --rm \
        --user $(id -u):$(id -g) \
        --volume /etc/passwd:/etc/passwd:ro \
        --volume /etc/group:/etc/group:ro \
        --volume $(pwd):/app \
        flownative/composer:7.4 "$@"
}
```

Now you can run Composer simply by running something like the following:

```
composer72 -v update
```

## Authentication

tbd.
