#!/usr/bin/env bash
# Cloud agent: PHP 8.5 + redis/mysqli extensions, deps, and phar for smoke tests.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

php_is_85() {
  php -r 'exit(version_compare(PHP_VERSION, "8.5.0", ">=") && version_compare(PHP_VERSION, "8.6.0", "<") ? 0 : 1);' 2>/dev/null
}

ensure_ondrej() {
  if apt-cache show php8.5-cli &>/dev/null 2>&1; then
    return 0
  fi
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends software-properties-common ca-certificates gnupg curl
  sudo add-apt-repository -y ppa:ondrej/php
  sudo apt-get update -qq
}

install_php85() {
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get install -y --no-install-recommends \
    php8.5-cli \
    php8.5-xml \
    php8.5-mbstring \
    php8.5-curl \
    php8.5-zip \
    php8.5-intl \
    php8.5-redis \
    php8.5-mysql
  if command -v update-alternatives >/dev/null 2>&1; then
    sudo update-alternatives --set php /usr/bin/php8.5 2>/dev/null || true
  fi
  if ! php_is_85; then
    sudo ln -sf /usr/bin/php8.5 /usr/local/bin/php
  fi
}

ensure_extension() {
  local ext="$1"
  if php -m 2>/dev/null | grep -qi "^${ext}$"; then
    return 0
  fi
  ensure_ondrej
  export DEBIAN_FRONTEND=noninteractive
  case "$ext" in
    redis) sudo apt-get install -y --no-install-recommends php8.5-redis ;;
    mysqli) sudo apt-get install -y --no-install-recommends php8.5-mysql ;;
    *) echo "Unknown extension: $ext" >&2; return 1 ;;
  esac
}

if ! php_is_85; then
  ensure_ondrej
  install_php85
fi

php_is_85
php -v

ensure_extension redis
ensure_extension mysqli
php -m | grep -Ei '^(redis|mysqli)$'

if ! command -v composer >/dev/null 2>&1; then
  ensure_ondrej
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get install -y --no-install-recommends composer || {
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
  }
fi

cd "$repo_root"
composer install --no-interaction

if [[ ! -f "$repo_root/php-cs-fixer.phar" ]]; then
  bash "$repo_root/dev-tools/build.sh"
fi

test -f "$repo_root/php-cs-fixer.phar"
