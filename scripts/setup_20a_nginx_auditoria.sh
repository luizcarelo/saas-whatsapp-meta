#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
LOGS_DIR="${BASE_DIR}/logs"
DOCS_DIR="${BASE_DIR}/docs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
REPORT_FILE="${DOCS_DIR}/NGINX_AUDITORIA_${STAMP}.md"
LOG_FILE="${LOGS_DIR}/setup_20a_nginx_auditoria.log"
NGINX_BACKUP="${BACKUPS_DIR}/nginx_backup_${STAMP}.tar.gz"

echo "== Etapa 20A: Auditoria e backup do Nginx =="

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"
mkdir -p "${DOCS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Validando Nginx..."

if ! command -v nginx >/dev/null 2>&1; then
  echo "ERRO: nginx nao encontrado no servidor."
  exit 1
fi

echo "Criando backup de /etc/nginx..."

sudo tar -czf "${NGINX_BACKUP}" /etc/nginx

echo "Testando configuracao atual do Nginx..."

sudo nginx -t 2>&1 | tee "${LOGS_DIR}/setup_20a_nginx_test.log"

echo "Listando arquivos de configuracao..."

{
  echo "# Auditoria do Nginx"
  echo ""
  echo "## Data"
  echo ""
  date '+%Y-%m-%d %H:%M:%S'
  echo ""
  echo "## Backup criado"
  echo ""
  echo "${NGINX_BACKUP}"
  echo ""
  echo "## Arquivos principais em /etc/nginx"
  echo ""
  find /etc/nginx -maxdepth 3 -type f | sort
  echo ""
  echo "## Ocorrencias de bot.lhsolucao.com.br"
  echo ""
  sudo grep -R "bot.lhsolucao.com.br" /etc/nginx || true
  echo ""
  echo "## Server names encontrados"
  echo ""
  sudo grep -R "server_name" /etc/nginx || true
  echo ""
  echo "## Portas listen encontradas"
  echo ""
  sudo grep -R "listen " /etc/nginx || true
} > "${REPORT_FILE}"

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" "${REPORT_FILE}"; then
  echo "ERRO: caractere proibido encontrado no relatorio."
  exit 1
fi

cat > "${LOG_FILE}" <<DOC
Etapa: 20A
Acao: Auditoria e backup do Nginx
Data: $(date '+%Y-%m-%d %H:%M:%S')
Backup: ${NGINX_BACKUP}
Relatorio: ${REPORT_FILE}
Status: Concluido
DOC

echo ""
echo "== Auditoria concluida com sucesso =="
echo ""
echo "Relatorio:"
echo "${REPORT_FILE}"
echo ""
echo "Backup:"
echo "${NGINX_BACKUP}"
