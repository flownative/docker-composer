ARG PHP_BASE_IMAGE

FROM ${PHP_BASE_IMAGE}
MAINTAINER Robert Lemke <robert@flownative.com>

LABEL org.label-schema.name="Composer"
LABEL org.label-schema.description="Docker image providing Composer based on Beach PHP images"
LABEL org.label-schema.vendor="Flownative GmbH"

ENV APPLICATION_PATH="/application" \
    COMPOSER_HOME=/home/composer \
    PHP_MEMORY_LIMIT=750M

COPY root-files /
COPY --from=composer:1.10 /usr/bin/composer /usr/bin/composer

USER root
RUN /build.sh

USER composer
WORKDIR /application
CMD ["composer"]
