#!/usr/bin/env bash

set -e

echo "Baixando e extraindo o Moodle ${MOODLE_VERSION}"
curl -fsSL "https://github.com/moodle/moodle/archive/refs/tags/v${MOODLE_VERSION}.tar.gz" \
    | tar xz -C "${MOODLE_WWWROOT}" --strip-components=1

echo "Instalando pacote de idioma pt_br"
curl -fsSL -o /tmp/pt_br.zip \
    "https://download.moodle.org/download.php/direct/langpack/${MOODLE_LANG_PKG_VERSION}/pt_br.zip"
unzip /tmp/pt_br.zip -d /tmp/langpack
mv /tmp/langpack/pt_br "${MOODLE_WWWROOT}/lang/"
chown "${USER_WWW}" "${MOODLE_WWWROOT}" -R
rm -rf /tmp/pt_br.zip /tmp/langpack

echo "Criando diretórios do Moodle"
mkdir -p "${MOODLEDATA_DIR}" /var/www/.npm /var/www/.nvm
chown "${USER_WWW}:${GROUP_WWW}" "${MOODLEDATA_DIR}" /var/www/.npm /var/www/.nvm -R
