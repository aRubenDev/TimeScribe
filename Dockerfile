# Dockerfile
# TimeScribe — web (self-hosted) image.
# Build from the repository root:  docker compose -f docker/compose.yaml build

ARG PHP_VERSION=8.4
ARG NODE_VERSION=22

# ---------- PHP base with the extensions required by composer.lock ----------
FROM php:${PHP_VERSION}-cli-bookworm AS php-base
COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/
RUN install-php-extensions intl zip bcmath pcntl
WORKDIR /app

# ---------- Composer dependencies (no dev) ----------
FROM php-base AS vendor
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --no-interaction --prefer-dist
COPY . .
RUN composer dump-autoload --optimize --no-dev --no-interaction

# ---------- Frontend assets (Vite needs vendor/ for ziggy and inertia-modal) ----------
FROM node:${NODE_VERSION}-bookworm-slim AS assets
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
COPY --from=vendor /app/vendor ./vendor
RUN npm run build

# ---------- Test suite (docker build --target test ...) ----------
FROM php-base AS test
# git: cweagans/composer-patches (dev) applies patches with `git apply`.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*
# pest-plugin-browser (dev dependency) requires ext-sockets; the web image doesn't need it.
RUN install-php-extensions sockets
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY composer.json composer.lock patches.lock.json ./
# composer-patches applies these during install, so they must exist first.
COPY tests/patches ./tests/patches
RUN composer install --no-scripts --no-autoloader --no-interaction --prefer-dist
COPY . .
COPY --from=assets /app/public/build ./public/build
RUN composer dump-autoload --no-interaction
# Throwaway key generated per run: tests need one for sessions/cookies.
CMD ["sh", "-c", "APP_KEY=base64:$(head -c 32 /dev/urandom | base64) php artisan test"]

# ---------- Runtime ----------
FROM php-base AS runtime
ENV APP_ENV=production \
    APP_DEBUG=false \
    APP_RUNTIME=web \
    LOG_CHANNEL=stderr \
    DB_CONNECTION=sqlite \
    DB_DATABASE=/data/database.sqlite

COPY --from=vendor /app /app
COPY --from=assets /app/public/build /app/public/build
COPY docker/entrypoint.sh /usr/local/bin/timescribe-entrypoint

RUN chmod +x /usr/local/bin/timescribe-entrypoint \
    && rm -rf /app/tests \
    && mkdir -p /data \
    && chown -R www-data:www-data /data /app/storage /app/bootstrap/cache

USER www-data
EXPOSE 8000
VOLUME ["/data"]

ENTRYPOINT ["timescribe-entrypoint"]
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=8000"]