FROM registry.gitlab.com/flownative/docker/php:7.2.21-1
MAINTAINER Robert Lemke <robert@flownative.com>

COPY --from=composer:1.9 /usr/bin/composer /usr/bin/composer
COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY runas.sh /usr/bin/runas

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_HOME /tmp
ENV BEACH_PHP_MEMORY_LIMIT 512M

RUN groupadd -r -g 501 composer && useradd -s /bin/bash -r -g composer -G composer -p "*" -u 501 composer

WORKDIR /app
ENTRYPOINT ["/bin/sh", "/docker-entrypoint.sh"]
CMD ["composer"]
