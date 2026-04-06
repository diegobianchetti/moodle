#!/usr/bin/env bash

set -e

echo "Configurações finais do SO"

# Permissões do /tmp (diretório padrão de upload do PHP)
chmod 777 /tmp && chmod +t /tmp

# Configuração do vim
printf "syntax on\n\
set mouse=\n\
set tabstop=4\n\
set shiftwidth=4\n\
set expandtab\n\
set autoindent\n\
set smartindent\n\
set encoding=utf-8\n\
filetype plugin indent on\n" > "${HOME}/.vimrc"

# Editor padrão
update-alternatives --install /usr/bin/editor editor /usr/bin/vim 100 && \
update-alternatives --set editor /usr/bin/vim

# Alias para acesso rápido ao banco pelo container da aplicação
echo -e '\n# Alias para acesso ao banco do Moodle' >> /etc/bash.bashrc
echo 'alias psql_moodle="export PGPASSWORD=${MOODLE_DATABASE_PASSWORD}; psql -U${MOODLE_DATABASE_USER} -h${MOODLE_DATABASE_HOST} ${MOODLE_DATABASE_NAME}"' >> /etc/bash.bashrc

# Garante carregamento do bash.bashrc para o usuário root
echo 'test -f /etc/bash.bashrc && . /etc/bash.bashrc' >> "${HOME}/.bashrc"
