#!/bin/bash

_install_moodle() {
    echo "Instalando o Moodle..."

    eval "/usr/bin/php /var/www/html/admin/cli/install.php \
    --chmod=2775 \
    --lang=${MOODLE_LANG} \
    --wwwroot="https://${MOODLE_HOST}" \
    --dataroot=/var/www/moodledata \
    --dbtype=${MOODLE_DATABASE_TYPE} \
    --dbhost=${MOODLE_DATABASE_HOST} \
    --dbname=${MOODLE_DATABASE_NAME} \
    --dbuser=${MOODLE_DATABASE_USER} \
    --dbpass="${MOODLE_DATABASE_PASSWORD}" \
    --dbport=${MOODLE_DATABASE_PORT_NUMBER} \
    --prefix=${MOODLE_DATABASE_PREFIX} \
    --fullname="${MOODLE_SITE_NAME}" \
    --shortname=${MOODLE_SORT_NAME} \
    --adminuser=${MOODLE_ADMIN_USERNAME} \
    --adminpass="${MOODLE_ADMIN_PASSWORD}" \
    --adminemail="${MOODLE_ADMIN_EMAIL}" \
    --non-interactive \
    --agree-license"

    if [ -f "/var/www/html/config.php" ]; then
        local custom_config="//Configuração para habilitar sslProxy\n\
\$CFG->sslproxy = true;\n\n\
//Adiciona a configuração personalizada ao config.php\n\
\$custom = '/var/www/html/config-custom.php';\n\
if (file_exists(\$custom)) {\n\
require_once(\$custom);\n\
}\n"
        local target_line="require_once(__DIR__ . '/lib/setup.php');"
        sed -i "/$(echo "$target_line" | sed 's/\//\\\//g')/i $custom_config" "/var/www/html/config.php"
        echo "Configuração personalizada adicionada com sucesso!"
    else
        echo "Arquivo de configuração (/var/www/html/config.php) não encontrado!"
        exit 1
    fi

    chown www-data:www-data /var/www/moodledata /var/www/html -R
    cp -a /var/www/html/config.php /custom/
}

/usr/local/bin/moodle-docker-php-entrypoint

if [ -f "/var/www/html/config.php" ]; then
    echo "Moodle já está instalado. Iniciando o container!"
elif [ -f "/custom/config.php" ]; then
    echo "Moodle já está instalado, porém o container foi recriado... sincronizando customizações!"
    if command -v rsync &> /dev/null; then
        rsync -av --chown=www-data:www-data /custom/* /var/www/html/
    else
        cp -av /custom/* /var/www/html/ && chown -R www-data:www-data /var/www/html/
    fi
    su -s /bin/bash www-data -c 'php /var/www/html/admin/cli/purge_caches.php'
else
    echo "Moodle não está instalado. Iniciando a instalação..."
    _install_moodle
    echo "Copiando configuração para o volume permanente montado em '/custom'"
    cp -av /var/www/html/config.php /custom/
fi

echo "Servidor Web iniciado!"
exec httpd -D FOREGROUND
