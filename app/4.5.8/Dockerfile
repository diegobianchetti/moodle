FROM alpine:3.22.1

# Argumentos para criação da imagem
ARG USER_WWW="www-data" \
    GROUP_WWW="www-data" \
    REGISTRY="registry.example.com/moodle" \
    ALPINE_VERSION="3.22.1" \
    PHP_VERSION="php83" \
    MOODLE_APP_VERSION="4.5.8"

# Informações de maintainer
LABEL maintainer="diego@oogway.com.br"
LABEL description="Moodle ${MOODLE_APP_VERSION} em Alpine Linux ${ALPINE_VERSION}"

# Configuração do sistema
ENV PAGER=less \
    EDITOR=vim \
    VISUAL=vim \
    LANG="pt_BR.UTF-8" \
    LC_ALL="pt_BR.UTF-8" \
    LANGUAGE="pt_BR:en" \
    TZ="America/Sao_Paulo" \
    PHP_INI_DIR="/etc/${PHP_VERSION}" \
    MOODLE_WWWROOT="/var/www/html" \
    MOODLEDATA_DIR="/var/www/moodledata" \
    MOODLE_VERSION="${MOODLE_APP_VERSION}" \
    MOODLE_LANG_PKG_VERSION="4.5" \
    IMAGE_APP_NAME="moodle-app" \
    IMAGE_APP_VERSION="${MOODLE_APP_VERSION}-alpine-${ALPINE_VERSION}"

# Instalação de pacotes base
RUN apk update
# bash e utilitários de shell
RUN apk add --no-cache bash bash-completion shadow
# Locales e timezone
RUN apk add --no-cache tzdata musl-locales musl-locales-lang
# Ferramentas de build
RUN apk add --no-cache build-base make gcc
# Servidor web e utilitários
RUN apk add --no-cache apache2 apache2-ssl apache2-ctl curl vim less poppler-utils git postgresql17-client bc dpkg \
                       htop unzip zip openssl libcrypto3 libssl3 rsync graphviz

# Shell padrão: bash
RUN chsh -s /bin/bash root

# Locale e timezone
RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
    echo "${TZ}" > /etc/timezone

# Usuário e permissões (uid/gid 33 — compatível com www-data do Debian/Ubuntu no host)
RUN groupmod -g 33 www-data && \
    adduser -u 33 -S -D -G ${USER_WWW} ${GROUP_WWW}
# Diretórios da aplicação
RUN mkdir -p ${MOODLE_WWWROOT} && \
    chown ${USER_WWW}:${GROUP_WWW} ${MOODLE_WWWROOT} -R && \
    chown ${USER_WWW}:${GROUP_WWW} /var/log/apache2 -R

# Symlinks de compatibilidade OpenSSL
RUN ln -sf /usr/lib/libcrypto.so.1.1 /usr/lib/libcrypto.so && \
    ln -sf /usr/lib/libssl.so.1.1 /usr/lib/libssl.so

# Configuração do Apache
RUN sed -i "s/User apache/User ${USER_WWW}/" /etc/apache2/httpd.conf && \
    sed -i "s/Group apache/Group ${GROUP_WWW}/" /etc/apache2/httpd.conf && \
    sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/' /etc/apache2/httpd.conf && \
    sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/httpd.conf && \
    sed -i 's/^ServerTokens .*/ServerTokens Prod/' /etc/apache2/httpd.conf && \
    sed -i "s|\(DocumentRoot\s\+\).*|\1\"${MOODLE_WWWROOT}\"|" /etc/apache2/httpd.conf && \
    sed -i "s|<Directory \"/var/www/localhost/htdocs\">|<Directory \"${MOODLE_WWWROOT}\">|" /etc/apache2/httpd.conf && \
    sed -i "s|\(DocumentRoot\s\+\).*|\1\"${MOODLE_WWWROOT}\"|" /etc/apache2/conf.d/ssl.conf && \
    sed -i 's/^#ServerName www\.example\.com:80/ServerName $MOODLE_HOST/' /etc/apache2/httpd.conf && \
    sed -i 's/^ServerName www\.example\.com:443/ServerName $MOODLE_HOST/' /etc/apache2/conf.d/ssl.conf && \
    sed -i 's/^ServerAdmin you\@example\.com/ServerAdmin $MOODLE_ADMIN_EMAIL/' /etc/apache2/httpd.conf && \
    sed -i 's/^ServerAdmin you\@example\.com/ServerAdmin $MOODLE_ADMIN_EMAIL/' /etc/apache2/conf.d/ssl.conf

# Configurações adicionais do Apache (root/etc/apache2/conf.d/)
ADD root/etc /etc

# Scripts e binários customizados
ADD root/usr /usr

# PHP base e PECL/PEAR
RUN apk add --no-cache ${PHP_VERSION} ${PHP_VERSION}-common ${PHP_VERSION}-pear
# Extensões PHP (instalação via script — baixa libiconv da fonte)
ADD root/tmp/setup/php-extensions.sh /tmp/setup/php-extensions.sh
RUN /tmp/setup/php-extensions.sh
ENV LD_PRELOAD=/usr/local/lib/preloadable_libiconv.so

# Oracle Instant Client + extensão OCI8
ADD root/tmp/setup/oci8-extension.sh /tmp/setup/oci8-extension.sh
RUN /tmp/setup/oci8-extension.sh
ENV LD_LIBRARY_PATH=/usr/local/instantclient \
    ORACLE_HOME=/usr/local/instantclient \
    PATH="${PATH}:/usr/local/instantclient"

# Download e extração do Moodle
ADD root/tmp/setup/moodle-packages-download.sh /tmp/setup/moodle-packages-download.sh
RUN /tmp/setup/moodle-packages-download.sh

# Configurações finais do SO (permissões, editor, aliases)
ADD root/tmp/setup/so-configs.sh /tmp/setup/so-configs.sh
RUN /tmp/setup/so-configs.sh

# Limpeza de cache e artefatos temporários
RUN rm -rf /var/cache/apk/* /tmp/*

# Arquivo de versão da imagem
RUN echo -e "${IMAGE_APP_NAME}:${IMAGE_APP_VERSION}" > /VERSION && \
    echo -e "Build date: $(date +%F\ %H:%M:%S)" >> /VERSION

# Bash como shell padrão
SHELL ["/bin/bash", "-c"]

WORKDIR ${MOODLE_WWWROOT}

EXPOSE 80 443

CMD ["/usr/local/bin/start-moodle.sh"]
