#!/bin/bash
# Compara os valores do custom-postgresql.conf com os parâmetros ativos no PostgreSQL
# e exibe se cada configuração foi aplicada com sucesso.

SQLIN=""
for i in $(grep '=' /var/lib/postgresql/data/conf.d/custom.conf | cut -d' ' -f1); do
    if [ -z "$SQLIN" ]; then
        SQLIN="'$i'"
    else
        SQLIN="$SQLIN,'$i'"
    fi
done

export PGPASSWORD=$POSTGRES_PASSWORD
psql -U"$POSTGRES_USER" "$POSTGRES_DB" -A -F '|' -t -c "
WITH custom AS (
    SELECT name, setting AS custom_value
    FROM pg_file_settings
    WHERE sourcefile LIKE '%custom.conf' AND name IN ($SQLIN)
),
current AS (
    SELECT name, setting AS current_value
    FROM pg_file_settings
    WHERE name IN ($SQLIN) AND applied = 't'
)
SELECT
    c.name,
    c.custom_value AS custom,
    curr.current_value AS current,
    CASE WHEN c.custom_value = curr.current_value THEN 't' ELSE 'f' END AS applied
FROM custom c
LEFT JOIN current curr ON c.name = curr.name
ORDER BY c.name;" | {
    printf "\033[1m%-30s | %-10s | %-10s | %-7s\033[0m\n" "name" "custom" "current" "applied"
    printf "%-30s | %-10s | %-10s | %-7s\n" "------------------------------" "----------" "----------" "-------"
    while IFS='|' read -r name custom current applied; do
        if [ "$applied" = "t" ]; then
            printf "\033[0;37m%-30s | %-10s | %-10s | %-7s\033[0m\n" "$name" "$custom" "$current" "$applied"
        else
            printf "\033[1;33m%-30s | %-10s | %-10s | %-7s\033[0m\n" "$name" "$custom" "$current" "$applied"
        fi
    done
}
