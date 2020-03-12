FROM docker.pkg.github.com/flownative/docker-beach-php/beach-php:7.1.33
MAINTAINER Robert Lemke <robert@flownative.com>

COPY --from=composer:1.10 /usr/bin/composer /usr/bin/composer
COPY docker-entrypoint.sh /docker-entrypoint.sh

ENV COMPOSER_HOME /tmp
ENV BEACH_PHP_MEMORY_LIMIT 512M

USER 1000
WORKDIR /app

ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]
CMD ["composer"]
