ARG PHP_BASE_IMAGE

FROM ${PHP_BASE_IMAGE}

ENV APPLICATION_PATH="/application" \
    COMPOSER_HOME=/home/composer \
    PHP_MEMORY_LIMIT=-1

COPY root-files /

USER root
RUN /build.sh

WORKDIR /application
CMD ["composer"]

# This will be added by the Github workflow:
# COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
# USER composer
