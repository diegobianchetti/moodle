#!/usr/bin/env bash
# build.sh — build das imagens Docker/Podman do Moodle
# Compatível com Docker e Podman (agnóstico de runtime)
#
# Uso:
#   ./build.sh app              # builda a imagem da aplicação
#   ./build.sh db               # builda a imagem do banco de dados
#   ./build.sh app --push       # builda e faz push para o registry
#   ./build.sh db  --push       # builda e faz push para o registry
#   ./build.sh all              # builda app e db
#   ./build.sh all --push       # builda e faz push de ambas

set -euo pipefail

APP_VERSION="4.5.8"
DB_VERSION="17.7"
REGISTRY="${MOODLE_REGISTRY:-registry.example.com/moodle}"

# Detecta runtime disponível (Docker ou Podman)
_runtime() {
    if command -v docker &>/dev/null; then
        echo "docker"
    elif command -v podman &>/dev/null; then
        echo "podman"
    else
        echo "Erro: nenhum runtime encontrado (docker ou podman)." >&2
        exit 1
    fi
}

RUNTIME=$(_runtime)
echo "Runtime: $RUNTIME"

# ---------------------------------------------------------------------------
# Funções de leitura de metadados do Dockerfile
# ---------------------------------------------------------------------------
_read_arg() {
    local dockerfile="$1" key="$2"
    grep "^    ${key}=" "$dockerfile" | cut -d'"' -f2
}

# ---------------------------------------------------------------------------
# Build da imagem da aplicação Moodle
# ---------------------------------------------------------------------------
build_app() {
    local build_dir="app/${APP_VERSION}"
    local dockerfile="${build_dir}/Dockerfile"

    [ -f "$dockerfile" ] || { echo "Dockerfile não encontrado: $dockerfile"; exit 1; }

    local alpine_version image_app_name image_version
    alpine_version=$(_read_arg "$dockerfile" "ALPINE_VERSION")
    image_app_name="moodle-app"
    image_version="${APP_VERSION}-alpine-${alpine_version}"
    local full_tag="${REGISTRY}/${image_app_name}:${image_version}"

    echo "---"
    echo "Imagem : ${image_app_name}"
    echo "Tag    : ${image_version}"
    echo "Registry: ${REGISTRY}"
    echo "---"
    read -rp "Confirmar build? [s/N]: " confirm
    [[ "${confirm,,}" =~ ^(s|sim)$ ]] || { echo "Cancelado."; exit 0; }

    $RUNTIME build \
        --pull \
        --no-cache \
        -t "${full_tag}" \
        "${build_dir}"

    echo "Build concluído: ${full_tag}"
    echo "${full_tag}"
}

# ---------------------------------------------------------------------------
# Build da imagem do banco de dados (PostgreSQL)
# ---------------------------------------------------------------------------
build_db() {
    local build_dir="db/postgres-${DB_VERSION}"
    local dockerfile="${build_dir}/Dockerfile"

    [ -f "$dockerfile" ] || { echo "Dockerfile não encontrado: $dockerfile"; exit 1; }

    local pg_version so_version image_app_name pg_major_minor image_version
    pg_version=$(_read_arg "$dockerfile" "POSTGRES_VERSION")
    so_version=$(_read_arg "$dockerfile" "SO_VERSION")
    image_app_name="moodle-db"
    pg_major_minor="${pg_version%%-*}"
    image_version="postgres-${pg_major_minor}-debian-${so_version}"
    local full_tag="${REGISTRY}/${image_app_name}:${image_version}"

    echo "---"
    echo "Imagem  : ${image_app_name}"
    echo "Tag     : ${image_version}"
    echo "Registry: ${REGISTRY}"
    echo "---"
    read -rp "Confirmar build? [s/N]: " confirm
    [[ "${confirm,,}" =~ ^(s|sim)$ ]] || { echo "Cancelado."; exit 0; }

    $RUNTIME build \
        --pull \
        --no-cache \
        -t "${full_tag}" \
        "${build_dir}"

    echo "Build concluído: ${full_tag}"
    echo "${full_tag}"
}

# ---------------------------------------------------------------------------
# Push para o registry
# ---------------------------------------------------------------------------
_push() {
    local full_tag="$1"
    local name_only="${full_tag%:*}"

    $RUNTIME push "${full_tag}"
    $RUNTIME tag  "${full_tag}" "${name_only}:latest"
    $RUNTIME push "${name_only}:latest"
    echo "Push concluído: ${full_tag} + latest"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
TARGET="${1:-}"
PUSH=false
[[ "${2:-}" == "--push" ]] && PUSH=true

case "$TARGET" in
    app)
        tag=$(build_app)
        $PUSH && _push "$tag"
        ;;
    db)
        tag=$(build_db)
        $PUSH && _push "$tag"
        ;;
    all)
        tag_app=$(build_app)
        tag_db=$(build_db)
        if $PUSH; then
            _push "$tag_app"
            _push "$tag_db"
        fi
        ;;
    *)
        echo "Uso: $0 {app|db|all} [--push]"
        echo ""
        echo "  app          Build da imagem da aplicação Moodle"
        echo "  db           Build da imagem PostgreSQL"
        echo "  all          Build de ambas"
        echo "  --push       Faz push para \$MOODLE_REGISTRY (default: registry.example.com/moodle)"
        exit 1
        ;;
esac
