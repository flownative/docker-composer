FROM registry.gitlab.com/flownative/docker/php:7.2
MAINTAINER Robert Lemke <robert@flownative.com>

COPY --from=composer:1.8 /usr/bin/composer /usr/bin/composer
COPY docker-entrypoint.sh /docker-entrypoint.sh

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_HOME /tmp

WORKDIR /app
ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]
CMD ["composer"]
