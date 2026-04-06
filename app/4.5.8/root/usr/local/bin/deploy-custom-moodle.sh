#!/bin/bash

#========================================================================
#- Deploy de configurações customizadas do Moodle                       #
#-                                                                      #
#-    script          /usr/local/bin/deploy-custom-moodle.sh            #
#-    version         1.0                                               #
#-    author          Diego Bianchetti (diego@oogway.dev)               #
#-    license         GNU General Public License v3                     #
#-                                                                      #
#========================================================================

if [[ -t 1 ]]; then
    RED='\033[31m'
    YELLOW='\033[33m'
    GREEN='\033[32m'
    BLUE='\033[34m'
    CYAN='\033[36m'
    RESET='\033[0m'
else
    RED='' YELLOW='' GREEN='' BLUE='' CYAN='' RESET=''
fi

if [ -f "/var/www/html/config.php" ]; then
    echo -e "${GREEN}Moodle em execução corretamente... sincronizando customizações do ambiente!${RESET}"
    if command -v rsync &> /dev/null; then
        rsync -av --chown=www-data:www-data /custom/* /var/www/html/
    else
        cp -av /custom/* /var/www/html/ && chown -R www-data:www-data /var/www/html/
    fi
    su -s /bin/bash www-data -c 'php /var/www/html/admin/cli/purge_caches.php' && \
    echo -e "${GREEN}[OK] Deploy custom executado com sucesso!${RESET}"
else
    echo -e "${RED}Arquivo de configuração do Moodle não encontrado. Verifique a instalação antes de continuar!${RESET}"
fi
