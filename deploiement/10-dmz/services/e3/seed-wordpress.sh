#!/usr/bin/env bash
# Idempotently initialize WordPress and add MaisonVerte shop content.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck source=../../../lib/common.sh
. "$SCRIPT_DIR/../../../lib/common.sh"

COMPOSE_FILE="$SCRIPT_DIR/compose.yaml"
PROJECT="mv-e3"
: "${MV_E3_DB_PASSWORD:?MV_E3_DB_PASSWORD is required}"
: "${MV_E3_ADMIN_PASSWORD:?MV_E3_ADMIN_PASSWORD is required}"
: "${MV_E3_FLAG:?MV_E3_FLAG is required}"
export MV_E3_DB_PASSWORD

table_exists="$(mv_compose "$PROJECT" "$COMPOSE_FILE" exec -T mysql \
  mysql -N -s -uroot -p"$MV_E3_DB_PASSWORD" wordpress \
  -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='wordpress' AND table_name='wp_options';")"

if [[ "$table_exists" != "1" ]]; then
  mv_log "initializing WordPress database"
  mv_compose "$PROJECT" "$COMPOSE_FILE" exec -T wordpress curl -fsS \
    --data-urlencode "weblog_title=MaisonVerte Boutique" \
    --data-urlencode "user_name=admin" \
    --data-urlencode "admin_password=$MV_E3_ADMIN_PASSWORD" \
    --data-urlencode "admin_password2=$MV_E3_ADMIN_PASSWORD" \
    --data-urlencode "admin_email=admin@maisonverte.fr" \
    --data-urlencode "Submit=Installer WordPress" \
    'http://127.0.0.1/wp-admin/install.php?step=2' >/dev/null
fi

mv_compose "$PROJECT" "$COMPOSE_FILE" exec -T mysql \
  mysql -uroot -p"$MV_E3_DB_PASSWORD" wordpress <<SQL
INSERT INTO wp_posts
  (post_author, post_date, post_date_gmt, post_content, post_title, post_excerpt,
   post_status, comment_status, ping_status, post_name, to_ping, pinged,
   post_modified, post_modified_gmt, post_content_filtered, post_type)
SELECT 1, NOW(), UTC_TIMESTAMP(),
       'Le back-office logistique communique avec backoffice-srv01 sur le segment prive.',
       'Operations boutique MaisonVerte', '', 'publish', 'closed', 'closed',
       'operations-maisonverte', '', '', NOW(), UTC_TIMESTAMP(), '', 'post'
WHERE NOT EXISTS (SELECT 1 FROM wp_posts WHERE post_name='operations-maisonverte');

INSERT INTO wp_options (option_name, option_value, autoload)
VALUES ('mv_service_flag', '${MV_E3_FLAG}', 'no')
ON DUPLICATE KEY UPDATE option_value=VALUES(option_value);

UPDATE wp_options
SET option_value='https://shop.maisonverte.fr'
WHERE option_name IN ('home', 'siteurl');
SQL

mv_log "WordPress seed is present"
