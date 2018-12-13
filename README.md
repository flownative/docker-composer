# Composer Docker Image

This docker images allows for convenient use of Composer based on a PHP version
required by the respective project.

For example, in order to use Composer based on PHP 7.2, add the following to
your `.zshrc` or the like:

```
composer72 () {
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
        composer:7.2 "$@"
}
```

Now you can run Composer simply by running something like the following:

```
composer72 -v update
```