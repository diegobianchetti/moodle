FROM debian:trixie-slim

# Argumentos para criação da imagem
ARG DEBIAN_FRONTEND=noninteractive \
    REGISTRY="registry.example.com/moodle" \
    SO_VERSION="trixie-slim" \
    POSTGRES_VERSION="17.9-1.pgdg13+1" \
    PG_MAJOR_MINOR=${POSTGRES_VERSION%%-*}

# Informações de maintainer
LABEL maintainer="diego@oogway.com.br"
LABEL description="PostgreSQL ${POSTGRES_VERSION} em Debian Linux ${SO_VERSION}"

# Configuração do sistema
ENV EDITOR=vim \
    VISUAL=vim \
    LANG="pt_BR.UTF-8" \
    LC_ALL="pt_BR.UTF-8" \
    LANGUAGE="pt_BR:en" \
    TZ="America/Sao_Paulo" \
    POSTGRES_USER="postgres" \
    POSTGRES_GROUP="postgres" \
    PG_VERSION=${POSTGRES_VERSION} \
    POSTGRES_MAJOR_VERSION="17" \
    POSTGRES_HOME="/var/lib/postgresql" \
    PGDATA="/var/lib/postgresql/data" \
    POSTGRES_PORT="5432" \
    IMAGE_APP_NAME="moodle-db" \
    IMAGE_APP_VERSION="postgres-${PG_MAJOR_MINOR}-debian-${SO_VERSION}"

ENV PATH="$PATH:/usr/lib/postgresql/$POSTGRES_MAJOR_VERSION/bin"

# Usuário e grupo postgres
RUN set -eux; \
    groupadd -r ${POSTGRES_GROUP} --gid=999; \
    useradd -r -g ${POSTGRES_GROUP} --uid=999 --home-dir=${POSTGRES_HOME} --shell=/bin/bash ${POSTGRES_USER}; \
    install --verbose --directory --owner ${POSTGRES_USER} --group ${POSTGRES_GROUP} --mode 1777 ${POSTGRES_HOME}

# Dependências básicas
RUN set -ex; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libnss-wrapper \
        xz-utils \
        zstd \
        gnupg \
        less \
        procps \
        htop \
        vim \
    ; \
    rm -rf /var/lib/apt/lists/*

# Locale e timezone
RUN set -eux; \
    if [ -f /etc/dpkg/dpkg.cfg.d/docker ]; then \
        grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
        sed -ri '/\/usr\/share\/locale/d' /etc/dpkg/dpkg.cfg.d/docker; \
        ! grep -q '/usr/share/locale' /etc/dpkg/dpkg.cfg.d/docker; \
    fi; \
    apt-get update; apt-get install -y --no-install-recommends tzdata locales; rm -rf /var/lib/apt/lists/*; \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime; \
    echo $TZ > /etc/timezone; \
    printf "en_US.UTF-8 UTF-8\npt_BR.UTF-8 UTF-8\n" >> /etc/locale.gen; \
    locale-gen

# Chave GPG do repositório oficial PostgreSQL
RUN set -ex; \
    key='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8'; \
    export GNUPGHOME="$(mktemp -d)"; \
    mkdir -p /usr/local/share/keyrings/; \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key"; \
    gpg --batch --export --armor "$key" > /usr/local/share/keyrings/postgres.gpg.asc; \
    gpgconf --kill all; \
    rm -rf "$GNUPGHOME"

# Instalação do PostgreSQL via apt.postgresql.org
RUN set -ex; \
    export PYTHONDONTWRITEBYTECODE=1; \
    dpkgArch="$(dpkg --print-architecture)"; \
    aptRepo="[ signed-by=/usr/local/share/keyrings/postgres.gpg.asc ] http://apt.postgresql.org/pub/repos/apt/ trixie-pgdg main $POSTGRES_MAJOR_VERSION"; \
    case "$dpkgArch" in \
        amd64 | arm64 | ppc64el | s390x) \
            echo "deb $aptRepo" > /etc/apt/sources.list.d/pgdg.list; \
            apt-get update; \
            ;; \
        *) \
            echo "deb-src $aptRepo" > /etc/apt/sources.list.d/pgdg.list; \
            savedAptMark="$(apt-mark showmanual)"; \
            tempDir="$(mktemp -d)"; \
            cd "$tempDir"; \
            apt-get update; \
            apt-get install -y --no-install-recommends dpkg-dev; \
            echo "deb [ trusted=yes ] file://$tempDir ./" > /etc/apt/sources.list.d/temp.list; \
            _update_repo() { \
                dpkg-scanpackages . > Packages; \
                apt-get -o Acquire::GzipIndexes=false update; \
            }; \
            _update_repo; \
            nproc="$(nproc)"; \
            export DEB_BUILD_OPTIONS="nocheck parallel=$nproc"; \
            apt-get build-dep -y postgresql-common pgdg-keyring; \
            apt-get source --compile postgresql-common pgdg-keyring; \
            _update_repo; \
            apt-get build-dep -y "postgresql-$POSTGRES_MAJOR_VERSION=$PG_VERSION"; \
            apt-get source --compile "postgresql-$POSTGRES_MAJOR_VERSION=$PG_VERSION"; \
            apt-mark showmanual | xargs apt-mark auto > /dev/null; \
            apt-mark manual $savedAptMark; \
            ls -lAFh; \
            _update_repo; \
            grep '^Package: ' Packages; \
            cd /; \
            ;; \
    esac; \
    apt-get install -y --no-install-recommends postgresql-common; \
    sed -ri 's/#(create_main_cluster) .*$/\1 = false/' /etc/postgresql-common/createcluster.conf; \
    apt-get install -y --no-install-recommends \
        "postgresql-$POSTGRES_MAJOR_VERSION=$PG_VERSION" \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    if [ -n "$tempDir" ]; then \
        apt-get purge -y --auto-remove; \
        rm -rf "$tempDir" /etc/apt/sources.list.d/temp.list; \
    fi; \
    find /usr -name '*.pyc' -type f -exec bash -c 'for pyc; do dpkg -S "$pyc" &> /dev/null || rm -vf "$pyc"; done' -- '{}' +; \
    postgres --version

# Configuração do PostgreSQL: listen_addresses = '*' por padrão
RUN set -eux; \
    dpkg-divert --add --rename --divert "/usr/share/postgresql/postgresql.conf.sample.dpkg" "/usr/share/postgresql/$POSTGRES_MAJOR_VERSION/postgresql.conf.sample"; \
    cp -v /usr/share/postgresql/postgresql.conf.sample.dpkg /usr/share/postgresql/postgresql.conf.sample; \
    ln -sv ../postgresql.conf.sample "/usr/share/postgresql/$POSTGRES_MAJOR_VERSION/"; \
    sed -ri "s!^#?(listen_addresses)\s*=\s*\S+.*!\1 = '*'!" /usr/share/postgresql/postgresql.conf.sample; \
    grep -F "listen_addresses = '*'" /usr/share/postgresql/postgresql.conf.sample

# vim e alias de conveniência
RUN printf "syntax on\n\
set mouse=\n\
set tabstop=4\n\
set shiftwidth=4\n\
set expandtab\n\
set autoindent\n\
set smartindent\n\
set encoding=utf-8\n\
filetype plugin indent on\n" > /root/.vimrc

RUN echo '# alias para acesso ao banco do Moodle via variáveis de ambiente' >> /etc/bash.bashrc && \
    echo 'alias psql_moodle="export PGPASSWORD=\$POSTGRES_PASSWORD; psql -U\$POSTGRES_USER \$POSTGRES_DB"' >> /etc/bash.bashrc

# Scripts de runtime e configurações customizadas
ADD root/usr /usr
ADD root/custom /custom

# Arquivo de versão da imagem
RUN echo "${IMAGE_APP_NAME}:${IMAGE_APP_VERSION}" > /VERSION && \
    echo "Build date: $(date +%F\ %H:%M:%S)" >> /VERSION

ENTRYPOINT ["docker-entrypoint.sh"]

STOPSIGNAL SIGINT
EXPOSE 5432
CMD ["postgres"]
