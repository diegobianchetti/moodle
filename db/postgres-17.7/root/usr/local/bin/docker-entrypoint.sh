#!/bin/bash
set -Eeuo pipefail

# Preparação de diretórios
install --verbose --directory --owner postgres --group postgres --mode 0700 /var/run/postgresql
install --verbose --directory --owner postgres --group postgres --mode 0750 "$PGDATA"

# Executa comando como usuário postgres, independente do usuário atual
run_as_postgres() {
    if [ "$(id -u)" = '0' ]; then
        su -p postgres -c "$1"
    else
        eval "$1"
    fi
}

# Parada graciosa ao receber sinal
stop_postgres() {
    echo "Sinal de desligamento recebido. Parando PostgreSQL..."
    run_as_postgres "pg_ctl -D '$PGDATA' -m fast stop"
    exit 0
}

export PATH="/usr/lib/postgresql/$POSTGRES_MAJOR_VERSION/bin:$PATH"
export PGDATA="${PGDATA:-/var/lib/postgresql/data}"

# Inicialização do banco — executada apenas uma vez
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "Inicializando banco de dados..."

    run_as_postgres "initdb --username=postgres"

    # Acesso local irrestrito para postgres; acesso remoto via md5
    run_as_postgres "echo \"local all postgres trust\"    >> '$PGDATA/pg_hba.conf'"
    run_as_postgres "echo \"host  all all 0.0.0.0/0 md5\" >> '$PGDATA/pg_hba.conf'"
    run_as_postgres "echo \"listen_addresses = '*'\"      >> '$PGDATA/postgresql.conf'"
    run_as_postgres "echo \"port = $POSTGRES_PORT\"       >> '$PGDATA/postgresql.conf'"
    # pg_stat_statements — monitoramento de consultas SQL
    run_as_postgres "echo \"shared_preload_libraries = 'pg_stat_statements'\" >> '$PGDATA/postgresql.conf'"

    # Inicia servidor temporariamente para criar usuário e banco
    run_as_postgres "pg_ctl -D '$PGDATA' -o '-c listen_addresses=localhost' -w start"

    if [ -n "${POSTGRES_USER:-}" ] && [ "$POSTGRES_USER" != "postgres" ]; then
        echo "Criando usuário: $POSTGRES_USER"
        run_as_postgres "createuser --username=postgres --superuser --createrole --createdb \"$POSTGRES_USER\""

        if [ -n "${POSTGRES_PASSWORD:-}" ]; then
            echo "Definindo senha para: $POSTGRES_USER"
            run_as_postgres "psql -U postgres -c \"ALTER USER \\\"$POSTGRES_USER\\\" WITH PASSWORD '$POSTGRES_PASSWORD';\""
        fi

        if [ -n "${POSTGRES_DB:-}" ]; then
            echo "Criando banco: $POSTGRES_DB"
            run_as_postgres "createdb --username=postgres --owner=\"$POSTGRES_USER\" \"$POSTGRES_DB\""
        fi
    fi

    # Extensão de monitoramento de consultas
    run_as_postgres "psql -U postgres -c \"CREATE EXTENSION IF NOT EXISTS pg_stat_statements;\""

    run_as_postgres "pg_ctl -D '$PGDATA' -m fast -w stop"
fi

# Configuração do diretório conf.d e aplicação do custom.conf
run_as_postgres "install --verbose --directory --mode 700 '$PGDATA/conf.d'"

if [ -f "$PGDATA/postgresql.conf" ]; then
    run_as_postgres "grep -vE '^[[:space:]]*#?[[:space:]]*include_dir[[:space:]]*=' '$PGDATA/postgresql.conf' > '$PGDATA/postgresql.conf.tmp'"
    run_as_postgres "mv '$PGDATA/postgresql.conf.tmp' '$PGDATA/postgresql.conf'"
fi

run_as_postgres "echo \"include_dir = 'conf.d'\" >> '$PGDATA/postgresql.conf'"

if [ -f "/custom/custom-postgresql.conf" ]; then
    run_as_postgres "install --verbose --compare /custom/custom-postgresql.conf '$PGDATA/conf.d/custom.conf'"
else
    run_as_postgres "touch '$PGDATA/conf.d/custom.conf'"
    run_as_postgres "chmod 600 '$PGDATA/conf.d/custom.conf'"
fi

trap stop_postgres SIGTERM SIGINT

if [ "$1" = 'postgres' ]; then
    run_as_postgres "postgres -D '$PGDATA'" &
    POSTGRES_PID=$!
    wait $POSTGRES_PID
else
    if [ "$(id -u)" = '0' ]; then
        exec su -p postgres -c "$*"
    else
        exec "$@"
    fi
fi
