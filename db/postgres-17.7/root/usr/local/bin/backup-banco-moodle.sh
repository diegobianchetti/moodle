#!/bin/bash
#=============================================================================
# Gerenciamento de backups do banco de dados Moodle via pg_dump
#
#   script    backup-banco-moodle.sh
#   version   2.0
#   license   GNU General Public License v3
#=============================================================================

BACKUP_DIR="/var/backups"
BACKUP_FILE_PREFIX="moodle"
BACKUP_FILE_SUFFIX="$(date +%Y-%m-%d-%H-%M-%S).dump"
BACKUP_LOG_FILENAME="backup.log"
RETENCAO="${BKP_RETENTION_DAYS:-3}"   # dias de retenção (env BKP_RETENTION_DAYS ou default=3)
CLEANUP_LOG_FILE="$BACKUP_DIR/backup-cleanup.log"
START_TIME=$(date +%s)
BACKUP_FILE=""
BACKUP_LOG_FILE="$BACKUP_DIR/$BACKUP_LOG_FILENAME"
BACKUP_TYPE=""

show_help() {
    echo "Uso: backup-banco-moodle.sh [OPÇÃO]"
    echo "Opções:"
    echo "  -c, --backup-completo            Backup completo do banco"
    echo "  -a, --backup-apenas-aplicacao    Backup sem a tabela mdl_logstore_standard_log"
    echo "  -s, --backup-apenas-logs         Backup apenas da tabela mdl_logstore_standard_log"
    echo "  -b, --backup-separados           Backup da aplicação e dos logs em arquivos separados"
    echo "  -r, --cleanup                    Remove backups com mais de $RETENCAO dias"
    echo "  -l, --backup-list                Lista os backups disponíveis"
    echo "  logs                             Exibe o log de backups"
    echo "  --help                           Exibe esta ajuda"
}

_backup_gera_filename() {
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE_PREFIX-$BACKUP_TYPE-$BACKUP_FILE_SUFFIX"
}

_bkp_cleanup() {
    echo "Removendo backups com mais de $RETENCAO dias..."
    echo "==============================================================" >> "$CLEANUP_LOG_FILE"
    echo "Limpeza iniciada em: $(date '+%Y-%m-%d %H:%M:%S')" >> "$CLEANUP_LOG_FILE"
    find "$BACKUP_DIR" -name "$BACKUP_FILE_PREFIX-*.dump" -type f -mtime +$RETENCAO -print -delete >> "$CLEANUP_LOG_FILE" 2>&1
    echo "Limpeza concluída em: $(date '+%Y-%m-%d %H:%M:%S')" >> "$CLEANUP_LOG_FILE"
    echo "==============================================================" >> "$CLEANUP_LOG_FILE"
    echo "Limpeza concluída. Log em: $CLEANUP_LOG_FILE"
}

_pg_dump() {
    local opcoes_adicionais=$1
    PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
        -U "$POSTGRES_USER" \
        -h 127.0.0.1 \
        -d "$POSTGRES_DB" \
        -p "$POSTGRES_PORT" \
        --file="$BACKUP_FILE" \
        --format=custom \
        $opcoes_adicionais
}

backup_full() {
    _backup_init
    echo "Iniciando backup completo: $BACKUP_FILE"
    _pg_dump ""
    _backup_concluido
}

backup_app() {
    _backup_init
    echo "Iniciando backup da aplicação: $BACKUP_FILE"
    _pg_dump "--exclude-table-data=public.mdl_logstore_standard_log"
    _backup_concluido
}

backup_logs() {
    _backup_init
    echo "Iniciando backup dos logs: $BACKUP_FILE"
    _pg_dump "--table=public.mdl_logstore_standard_log"
    _backup_concluido
}

backup_list() {
    echo "Backups disponíveis:"
    echo "-------------------------------------------------------------------------------------------------"
    printf "%-25s | %-55s | %-10s\n" "Tipo" "Arquivo" "Tamanho"
    echo "-------------------------------------------------------------------------------------------------"

    for file in $(ls -1t "$BACKUP_DIR" | grep "full"); do
        size=$(stat -c %s "$BACKUP_DIR/$file" 2>/dev/null)
        printf "%-25s | %-55s | %-10s\n" "Completo" "$file" "$(numfmt --to=iec --suffix=B $size 2>/dev/null || echo N/A)"
    done
    for file in $(ls -1t "$BACKUP_DIR" | grep "app"); do
        size=$(stat -c %s "$BACKUP_DIR/$file" 2>/dev/null)
        printf "%-25s | %-55s | %-10s\n" "Aplicação" "$file" "$(numfmt --to=iec --suffix=B $size 2>/dev/null || echo N/A)"
    done
    for file in $(ls -1t "$BACKUP_DIR" | grep "logs"); do
        size=$(stat -c %s "$BACKUP_DIR/$file" 2>/dev/null)
        printf "%-25s | %-55s | %-10s\n" "Logs" "$file" "$(numfmt --to=iec --suffix=B $size 2>/dev/null || echo N/A)"
    done
    echo "-------------------------------------------------------------------------------------------------"
}

show_backup_logs() {
    if [ ! -f "$BACKUP_LOG_FILE" ]; then
        echo "Arquivo de log não encontrado."
        return
    fi
    echo "---------------------------------------------------------------------------------------------------------------"
    printf "%-20s | %-55s | %-10s | %-20s\n" "Data/Hora" "Arquivo" "Tamanho" "Duração"
    echo "---------------------------------------------------------------------------------------------------------------"
    while IFS='|' read -r data arquivo tamanho tempo; do
        printf "%-20s | %-55s | %-10s | %-20s\n" "$data" "$arquivo" "$tamanho" "$tempo"
    done < "$BACKUP_LOG_FILE"
    echo "---------------------------------------------------------------------------------------------------------------"
}

_backup_init() {
    [ ! -f "$BACKUP_LOG_FILE" ] && touch "$BACKUP_LOG_FILE"
    _backup_gera_filename
}

_backup_concluido() {
    local end_time duration duration_fmt
    end_time=$(date +%s)
    duration=$((end_time - START_TIME))
    duration_fmt=$(printf '%02d:%02d:%02d' $((duration/3600)) $(( (duration%3600)/60 )) $((duration%60)))
    _backup_registra_log
    echo "Backup concluído: $BACKUP_FILE (Duração: ${duration_fmt})"
}

_backup_registra_log() {
    local log_date file_name file_size file_size_fmt
    log_date=$(date '+%Y-%m-%d %H:%M:%S')
    file_name=$(basename "$BACKUP_FILE")
    file_size=$(stat -c %s "$BACKUP_FILE" 2>/dev/null)
    file_size_fmt=$(numfmt --to=iec --suffix=B $file_size 2>/dev/null || echo N/A)
    echo "$log_date | $file_name | ${file_size_fmt} | ${duration_fmt:-N/A}" >> "$BACKUP_LOG_FILE"
}

case "${1:-}" in
    -c|--backup-completo)
        BACKUP_TYPE="full"  ; backup_full  ;;
    -a|--backup-apenas-aplicacao)
        BACKUP_TYPE="app"   ; backup_app   ;;
    -s|--backup-apenas-logs)
        BACKUP_TYPE="logs"  ; backup_logs  ;;
    -b|--backup-separados)
        BACKUP_TYPE="app"   ; backup_app
        BACKUP_TYPE="logs"  ; backup_logs  ;;
    -l|--backup-list)
        backup_list ;;
    -r|--cleanup)
        _bkp_cleanup ;;
    logs)
        show_backup_logs ;;
    --help|help|*)
        show_help ;;
esac
