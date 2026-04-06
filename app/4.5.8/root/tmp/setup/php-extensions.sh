#!/usr/bin/env bash

set -e

echo "Instalando dependências de build e runtime"

# Pacotes de build (removidos ao final)
BUILD_PACKAGES="autoconf automake libtool curl-dev libxml2-dev openssl-dev"

# Dependências de runtime
RUNTIME_PACKAGES="ghostscript libaio krb5 icu-data-full libxslt sassc mariadb-connector-c-dev libmemcached openldap aspell libc6-compat"

apk update
apk add --no-cache $RUNTIME_PACKAGES
apk add --no-cache --virtual .build-deps $BUILD_PACKAGES

echo "Instalando extensões PHP via apk"

apk add --no-cache \
    ${PHP_VERSION}-dev ${PHP_VERSION}-apache2 ${PHP_VERSION}-curl ${PHP_VERSION}-mbstring \
    ${PHP_VERSION}-xml ${PHP_VERSION}-zip ${PHP_VERSION}-gd ${PHP_VERSION}-exif \
    ${PHP_VERSION}-opcache ${PHP_VERSION}-pgsql ${PHP_VERSION}-xsl ${PHP_VERSION}-mysqli \
    ${PHP_VERSION}-apcu ${PHP_VERSION}-dom ${PHP_VERSION}-sodium ${PHP_VERSION}-ctype \
    ${PHP_VERSION}-iconv ${PHP_VERSION}-tokenizer ${PHP_VERSION}-simplexml \
    ${PHP_VERSION}-xmlreader ${PHP_VERSION}-fileinfo ${PHP_VERSION}-pdo \
    ${PHP_VERSION}-pdo_pgsql ${PHP_VERSION}-intl ${PHP_VERSION}-bcmath \
    ${PHP_VERSION}-ldap ${PHP_VERSION}-soap ${PHP_VERSION}-pecl-igbinary \
    ${PHP_VERSION}-pecl-memcached ${PHP_VERSION}-pecl-redis ${PHP_VERSION}-pecl-pcov \
    ${PHP_VERSION}-pecl-timezonedb ${PHP_VERSION}-pecl-uuid ${PHP_VERSION}-xmlwriter

# APCu para CLI
echo 'apc.enable_cli = On' >> ${PHP_INI_DIR}/conf.d/apcu.ini

echo "Instalando extensões via PECL"

pecl channel-update pecl.php.net
pecl install solr excimer
echo "extension=solr.so"    > ${PHP_INI_DIR}/conf.d/solr.ini
echo "extension=excimer.so" > ${PHP_INI_DIR}/conf.d/excimer.ini

# Microsoft SQL Server
apk add --no-cache unixodbc-dev
pecl install sqlsrv
pecl install pdo_sqlsrv
echo "extension=pdo_sqlsrv.so" > ${PHP_INI_DIR}/conf.d/10_pdo_sqlsrv.ini
echo "extension=sqlsrv.so"     > ${PHP_INI_DIR}/conf.d/20_sqlsrv.ini

# gnu-libiconv 1.15 — corrige edição de perfis de usuário no Moodle em Alpine.
# Alpine usa musl-libc, que tem iconv limitado; esta versão compila a biblioteca
# GNU e expõe /usr/local/lib/preloadable_libiconv.so para uso via LD_PRELOAD.
# Fonte: https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.15.tar.gz
LIBICONV_VERSION="1.15"
LIBICONV_URL="https://ftp.gnu.org/pub/gnu/libiconv/libiconv-${LIBICONV_VERSION}.tar.gz"

curl -fsSL "${LIBICONV_URL}" -o /tmp/libiconv-${LIBICONV_VERSION}.tar.gz
tar -xzf /tmp/libiconv-${LIBICONV_VERSION}.tar.gz -C /tmp
cd /tmp/libiconv-${LIBICONV_VERSION}
./configure --prefix=/usr/local
make
make install
libtool --finish /usr/local/lib

# Limpeza
pecl clear-cache
apk del .build-deps
rm -rf /var/cache/apk/* /tmp/pear /tmp/libiconv-${LIBICONV_VERSION}*
