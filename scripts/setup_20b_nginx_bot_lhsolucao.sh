#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
LOGS_DIR="${BASE_DIR}/logs"
DOCS_DIR="${BASE_DIR}/docs"
BACKUPS_DIR="${BASE_DIR}/backups"
SCRIPTS_DIR="${BASE_DIR}/scripts"
STAMP="$(date '+%Y%m%d_%H%M%S')"

NGINX_AVAILABLE="/etc/nginx/sites-available/bot.lhsolucao.com.br"
NGINX_ENABLED="/etc/nginx/sites-enabled/bot.lhsolucao.com.br"
BACKUP_FILE="${BACKUPS_DIR}/nginx_bot_lhsolucao_${STAMP}.conf.bak"
ROLLBACK_SCRIPT="${SCRIPTS_DIR}/rollback_nginx_bot_lhsolucao_${STAMP}.sh"
REPORT_FILE="${DOCS_DIR}/NGINX_BOT_LHSOLUCAO.md"
LOG_FILE="${LOGS_DIR}/setup_20b_nginx_bot_lhsolucao.log"

echo "== Etapa 20B: Configurar Nginx para bot.lhsolucao.com.br =="

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"
mkdir -p "${DOCS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${SCRIPTS_DIR}"

echo "Validando Nginx..."

if ! command -v nginx >/dev/null 2>&1; then
  echo "ERRO: nginx nao encontrado."
  exit 1
fi

echo "Validando arquivo existente do bot..."

if [ ! -f "${NGINX_AVAILABLE}" ]; then
  echo "ERRO: arquivo nao encontrado: ${NGINX_AVAILABLE}"
  echo "A auditoria indicou que ele existia. Confira manualmente antes de continuar."
  exit 1
fi

echo "Criando backup do arquivo atual..."

sudo cp "${NGINX_AVAILABLE}" "${BACKUP_FILE}"

echo "Criando script de rollback..."

cat > "${ROLLBACK_SCRIPT}" <<DOC
#!/usr/bin/env bash
set -euo pipefail

echo "== Rollback Nginx bot.lhsolucao.com.br =="

sudo cp "${BACKUP_FILE}" "${NGINX_AVAILABLE}"

if [ ! -L "${NGINX_ENABLED}" ]; then
  sudo ln -s "${NGINX_AVAILABLE}" "${NGINX_ENABLED}"
fi

sudo nginx -t
sudo systemctl reload nginx

echo "Rollback concluido."
DOC

chmod +x "${ROLLBACK_SCRIPT}"

echo "Regravando configuracao isolada do dominio bot.lhsolucao.com.br..."

sudo tee "${NGINX_AVAILABLE}" > /dev/null <<'DOC'
server {
    listen 80;
    server_name bot.lhsolucao.com.br;

    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name bot.lhsolucao.com.br;

    ssl_certificate /etc/letsencrypt/live/bot.lhsolucao.com.br/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/bot.lhsolucao.com.br/privkey.pem;

    client_max_body_size 50m;

    access_log /var/log/nginx/bot_lhsolucao_access.log;
    error_log /var/log/nginx/bot_lhsolucao_error.log;

    location / {
        proxy_pass http://127.0.0.1:8180;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}
DOC

echo "Garantindo link em sites-enabled..."

if [ ! -L "${NGINX_ENABLED}" ]; then
  sudo ln -s "${NGINX_AVAILABLE}" "${NGINX_ENABLED}"
fi

echo "Validando configuracao do Nginx..."

sudo nginx -t 2>&1 | tee "${LOGS_DIR}/setup_20b_nginx_test.log"

echo "Recarregando Nginx..."

sudo systemctl reload nginx

echo "Gerando documentacao da etapa..."

cat > "${REPORT_FILE}" <<DOC
# Nginx bot.lhsolucao.com.br

## Visao geral

Este documento registra a configuracao do Nginx para o dominio bot.lhsolucao.com.br.

## Resultado

Status:

    concluido

## Dominio configurado

Dominio:

    bot.lhsolucao.com.br

## Arquivo alterado

Arquivo:

    /etc/nginx/sites-available/bot.lhsolucao.com.br

## Link ativo

Link:

    /etc/nginx/sites-enabled/bot.lhsolucao.com.br

## Backup criado

Backup:

    ${BACKUP_FILE}

## Rollback

Script:

    ${ROLLBACK_SCRIPT}

## Destino do proxy

Destino:

    http://127.0.0.1:8180

## SSL

Certificados mantidos:

    /etc/letsencrypt/live/bot.lhsolucao.com.br/fullchain.pem
    /etc/letsencrypt/live/bot.lhsolucao.com.br/privkey.pem

## Configuracoes preservadas

A etapa nao alterou os demais arquivos do Nginx.

Nao foram alterados:

- rh_lhsolucao.conf
- lhsolucao.com.br.conf
- gestao
- mobile-dev.conf

## Validacoes executadas

Validacoes:

- backup criado
- nginx -t executado com sucesso
- nginx recarregado apos validacao

## Proxima etapa sugerida

Etapa 20C:

    Subir containers e testar acesso pelo dominio
DOC

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 20B
Acao: Configurar Nginx para bot.lhsolucao.com.br
Data: $(date '+%Y-%m-%d %H:%M:%S')
Arquivo alterado: ${NGINX_AVAILABLE}
Backup: ${BACKUP_FILE}
Rollback: ${ROLLBACK_SCRIPT}
Destino: http://127.0.0.1:8180
Status: Concluido
DOC

echo ""
echo "== Etapa 20B concluida com sucesso =="
echo ""
echo "Backup:"
echo "${BACKUP_FILE}"
echo ""
echo "Rollback:"
echo "${ROLLBACK_SCRIPT}"
echo ""
echo "Relatorio:"
echo "${REPORT_FILE}"
