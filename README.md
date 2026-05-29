# moodle — Imagens de container para Moodle

Dockerfiles e scripts de build para as imagens de container do Moodle.
Agnósticas de runtime: compatíveis com **Docker** e **Podman**.

## Imagens

| Imagem | Base | Versão |
|---|---|---|
| `moodle-app` | Alpine 3.22 + Apache + PHP 8.3 | Moodle 4.5.8 |
| `moodle-db`  | Debian trixie-slim | PostgreSQL 17.9 |

## Estrutura do repositório

```
moodle/
├── app/
│   └── 4.5.8/
│       ├── Dockerfile
│       └── root/tmp/setup/
│           ├── php-extensions.sh          # extensões PHP + libiconv
│           ├── moodle-packages-download.sh # download do Moodle + lang pt_br
│           ├── so-configs.sh              # permissões, vim, aliases
│           └── oci8-extension.sh          # Oracle Instant Client + OCI8
├── db/
│   └── postgres-17.9/
│       ├── Dockerfile
│       └── root/
│           ├── custom/
│           │   └── custom-postgresql.conf # tuning de performance
│           └── usr/local/bin/
│               ├── docker-entrypoint.sh   # init do cluster, criação de usuário/banco
│               ├── backup-banco-moodle.sh # backup via pg_dump com retenção
│               ├── check_pg_config.sh     # verifica parâmetros aplicados
│               └── update_pg_config.sh    # aplica custom.conf sem reinício
├── build.sh                               # script de build local (Docker/Podman)
├── .github/workflows/build.yml            # CI/CD via GitHub Actions → ghcr.io
└── README.md
```

## Pré-requisitos

- Docker ≥ 24 ou Podman ≥ 4
- Acesso à internet durante o build (download do Moodle, pacotes Alpine/Debian)

## Build local

```bash
# Apenas build
./build.sh app
./build.sh db
./build.sh all

# Build + push para o registry
export MOODLE_REGISTRY=ghcr.io/seu-usuario
./build.sh app --push
./build.sh db  --push
./build.sh all --push
```

O script detecta automaticamente se `docker` ou `podman` está disponível.

## Variáveis de ambiente — moodle-app

| Variável | Descrição | Exemplo |
|---|---|---|
| `MOODLE_HOST` | FQDN do servidor | `moodle.exemplo.com` |
| `MOODLE_LANG` | Idioma da instalação | `pt_br` |
| `MOODLE_SITE_NAME` | Nome do site | `Minha Plataforma` |
| `MOODLE_SORT_NAME` | Nome curto | `minha-plataforma` |
| `MOODLE_ADMIN_USERNAME` | Usuário admin | `admin` |
| `MOODLE_ADMIN_PASSWORD` | Senha admin | _(via secret)_ |
| `MOODLE_ADMIN_EMAIL` | E-mail admin | `admin@exemplo.com` |
| `MOODLE_DATABASE_TYPE` | Driver do banco | `pgsql` |
| `MOODLE_DATABASE_HOST` | Host do banco | `moodle-db` |
| `MOODLE_DATABASE_NAME` | Nome do banco | `moodle` |
| `MOODLE_DATABASE_USER` | Usuário do banco | `moodle` |
| `MOODLE_DATABASE_PASSWORD` | Senha do banco | _(via secret)_ |
| `MOODLE_DATABASE_PORT_NUMBER` | Porta do banco | `5432` |
| `MOODLE_DATABASE_PREFIX` | Prefixo das tabelas | `mdl_` |

## Variáveis de ambiente — moodle-db

| Variável | Descrição | Exemplo |
|---|---|---|
| `POSTGRES_USER` | Usuário do banco | `moodle` |
| `POSTGRES_PASSWORD` | Senha do usuário | _(via secret)_ |
| `POSTGRES_DB` | Nome do banco | `moodle` |
| `POSTGRES_PORT` | Porta de escuta | `5432` |
| `BKP_RETENTION_DAYS` | Retenção de backups | `7` |

## Backup do banco

O script `backup-banco-moodle.sh` está disponível dentro do container `moodle-db`:

```bash
# Backup completo
docker exec moodle-db backup-banco-moodle.sh --backup-completo

# Backup sem tabela de logs (mais rápido)
docker exec moodle-db backup-banco-moodle.sh --backup-apenas-aplicacao

# Listar backups disponíveis
docker exec moodle-db backup-banco-moodle.sh --backup-list

# Remover backups com mais de 7 dias
docker exec moodle-db backup-banco-moodle.sh --cleanup
```

## Tuning do PostgreSQL

O arquivo `db/postgres-17.9/root/custom/custom-postgresql.conf` contém
parâmetros de performance gerados com [pgtune](https://pgtune.leopard.in.ua/)
para perfil web com 1 GB de RAM. Ajuste conforme o ambiente de destino.

Para aplicar alterações no custom.conf sem reiniciar o container:

```bash
docker exec moodle-db update_pg_config.sh

# Verificar quais parâmetros foram aplicados
docker exec moodle-db check_pg_config.sh
```

## CI/CD

O workflow `.github/workflows/build.yml` é disparado automaticamente em push
para `main` (quando há alterações em `app/` ou `db/`) e publica as imagens
no **GitHub Container Registry** (`ghcr.io`).

Em pull requests, apenas o build é executado (sem push).

## Decisões técnicas

### Alpine para a imagem da aplicação, Debian para o banco

A imagem `moodle-app` usa Alpine: menor superfície de ataque, imagem final mais
compacta, sem daemons de sistema desnecessários. O custo são as extensões PHP
que precisam ser compiladas (sem wheels pré-compilados), o que é feito em tempo
de build via `php-extensions.sh` — não impacta o runtime.

A imagem `moodle-db` usa Debian (trixie-slim): o PostgreSQL tem suporte oficial
e tooling maduro no ecossistema Debian. Alpine com PostgreSQL exige compilação
de dependências C e tem histórico de incompatibilidades sutis com extensões de
banco. Para um banco de dados em produção, previsibilidade vale mais que tamanho
de imagem.

### `MOODLE_SSL` como variável de ambiente

O `start-moodle.sh` expõe `MOODLE_SSL` (padrão `true`) para controlar dois
comportamentos acoplados:

- O scheme do `--wwwroot` na instalação: `https://` ou `http://`
- A injeção de `sslproxy = true` no `config.php`

Sem essa variável, o container sempre gera `wwwroot` com `https://` e ativa
`sslproxy`. Em ambientes sem terminação TLS real (lab, homologação com proxy
HTTP puro), o browser tenta carregar assets via `https://` sem certificado
válido — resultado: página sem CSS. Separar esse comportamento numa variável
permite usar a mesma imagem em produção (SSL real) e em lab (`MOODLE_SSL=false`)
sem rebuild.

### `start-moodle.sh` detecta o estado da instalação

O entrypoint não executa `moosh` cegamente a cada start. Ele detecta três
estados distintos pelo conteúdo do volume persistente:

- **Fresh**: volume vazio → executa instalação completa
- **Recriado**: container recriado mas banco já existente → pula instalação,
  restaura `config.php` do volume
- **Instalado**: estado normal → inicia Apache diretamente

Isso evita que um simples `docker compose restart` dispare uma reinstalação
acidental, o que apagaria dados do banco.

### PostgreSQL customizado sem rebuild

O `custom-postgresql.conf` é montado como volume e carregado via
`include_if_exists` no `postgresql.conf` principal. Ajustes de performance
(shared_buffers, work_mem, etc.) são aplicados com `update_pg_config.sh` +
`SELECT pg_reload_conf()` — sem reiniciar o container, sem rebuild de imagem.
Isso separa a configuração operacional da imagem, que permanece genérica e
reutilizável em ambientes com recursos diferentes.

## Licença

MIT
