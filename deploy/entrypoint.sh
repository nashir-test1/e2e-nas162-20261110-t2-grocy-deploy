#!/bin/sh
set -eu

storage_dir="${GROCY_DATAPATH:-/var/www/html/data}"
mkdir -p "$storage_dir"
if [ ! -f "$storage_dir/config.php" ]; then
    cp /var/www/html/config-dist.php "$storage_dir/config.php"
fi

exec docker-php-entrypoint "$@"
