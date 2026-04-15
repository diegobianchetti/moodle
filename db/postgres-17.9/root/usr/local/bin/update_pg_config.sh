#!/bin/bash
# Aplica o custom-postgresql.conf ao conf.d/custom.conf do PostgreSQL em execução.
# Verifica se o arquivo mudou, faz backup, recarrega com pg_reload_conf()
# e avisa se algum parâmetro requer reinício do servidor.

export PATH="/usr/lib/postgresql/$POSTGRES_MAJOR_VERSION/bin:$PATH"
export PGDATA="${PGDATA:-/var/lib/postgresql/data}"

run_as_postgres() {
    if [ "$(id -u)" = '0' ]; then
        su -p postgres -c "$1"
    else
        eval "$1"
    fi
}

check_pending_restart() {
    echo "Verificando parâmetros que requerem reinício..."
    local pending
    pending=$(run_as_postgres "psql -t -c \"SELECT name FROM pg_settings WHERE pending_restart = true;\"")
    if [ -n "$pending" ]; then
        echo "AVISO: parâmetros pendentes de reinício:"
        echo "$pending" | while read -r param; do echo "  - $param"; done
        return 0
    else
        echo "Nenhum parâmetro requer reinício."
        return 1
    fi
}

apply_configuration() {
    local custom_file="$1"
    local target_file="$2"
    local backup_file="${target_file}.backup.$(date +%Y%m%d_%H%M%S)"

    cp "$target_file" "$backup_file"
    echo "Backup criado: $backup_file"

    cp "$custom_file" "$target_file"
    chown postgres:postgres "$target_file"

    echo "Recarregando configurações..."
    if run_as_postgres "psql -c 'SELECT pg_reload_conf();'"; then
        echo "Configurações recarregadas com sucesso."
        sleep 2
        if check_pending_restart; then
            echo "AVISO: reinicialize o container para aplicar todas as alterações."
            return 2
        else
            echo "Todas as configurações foram aplicadas sem reinício."
            return 0
        fi
    else
        echo "ERRO ao recarregar. Restaurando backup..."
        cp "$backup_file" "$target_file"
        chown postgres:postgres "$target_file"
        run_as_postgres "psql -c 'SELECT pg_reload_conf();'"
        return 1
    fi
}

compare_and_update_config() {
    local custom_file="/custom/custom-postgresql.conf"
    local target_file="$PGDATA/conf.d/custom.conf"

    [ -f "$custom_file" ] || { echo "Erro: $custom_file não encontrado."; return 1; }
    [ -f "$target_file" ] || { echo "Erro: $target_file não encontrado."; return 1; }

    if ! cmp -s "$custom_file" "$target_file"; then
        echo "Arquivos diferentes."
        if [ "$custom_file" -nt "$target_file" ]; then
            echo "Aplicando configurações mais recentes..."
            apply_configuration "$custom_file" "$target_file"
            return $?
        else
            echo "Arquivo custom não é mais recente. Nenhuma ação."
            return 2
        fi
    else
        echo "Arquivos idênticos. Nenhuma ação."
        return 3
    fi
}

main() {
    echo "Verificando configurações do PostgreSQL..."
    compare_and_update_config
    local result=$?
    case $result in
        0) echo "Configuração atualizada com sucesso." ;;
        1) echo "Erro: arquivo não encontrado." ;;
        2) echo "Arquivo custom não é mais recente ou reinício necessário." ;;
        3) echo "Arquivos idênticos." ;;
        *) echo "Resultado desconhecido: $result" ;;
    esac
    return $result
}

main
