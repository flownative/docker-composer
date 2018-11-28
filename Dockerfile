FROM registry.gitlab.com/flownative/docker/php:7.2
MAINTAINER Robert Lemke <robert@flownative.com>

COPY --from=composer:1.7 /usr/bin/composer /usr/bin/composer
