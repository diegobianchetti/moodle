#!/usr/bin/env bash

set -e

echo "Instalando Oracle Instant Client e extensão OCI8"

IC_BASE_URL="https://download.oracle.com/otn_software/linux/instantclient/2112000"
IC_VERSION="21.12.0.0.0dbru"

curl -fsSL "${IC_BASE_URL}/instantclient-basiclite-linux.x64-${IC_VERSION}.zip" \
    -o /tmp/instantclient-basiclite.zip
curl -fsSL "${IC_BASE_URL}/instantclient-sdk-linux.x64-${IC_VERSION}.zip" \
    -o /tmp/instantclient-sdk.zip

unzip /tmp/instantclient-basiclite.zip -d /usr/local/
unzip /tmp/instantclient-sdk.zip       -d /usr/local/
rm /tmp/instantclient-basiclite.zip /tmp/instantclient-sdk.zip

ln -s /usr/local/instantclient_21_12 /usr/local/instantclient
ln -s /usr/local/instantclient/lib*  /usr/lib

# OCI8 3.2.1 — última versão compatível com Instant Client 21.x no PHP 8.x
echo 'instantclient,/usr/local/instantclient' | pecl install oci8-3.2.1
echo "extension=oci8.so"              > ${PHP_INI_DIR}/conf.d/oci8.ini
echo 'oci8.statement_cache_size = 0' >> ${PHP_INI_DIR}/conf.d/oci8.ini
