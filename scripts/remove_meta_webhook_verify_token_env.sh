#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
ENV_FILE="${BASE_DIR}/.env"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/remove_meta_webhook_verify_token_env.log"

echo "== Remover META_WEBHOOK_VERIFY_TOKEN do .env =="

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

if [ ! -f "${ENV_FILE}" ]; then
  echo "ERRO: .env nao encontrado em ${ENV_FILE}"
  exit 1
fi

cp "${ENV_FILE}" "${BACKUPS_DIR}/env_${STAMP}.bak"

python3 <<'PY'
from pathlib import Path

path = Path(".env")
text = path.read_text()

lines = text.splitlines()
new_lines = []

removed = 0

for line in lines:
    stripped = line.strip()

    if stripped.startswith("META_WEBHOOK_VERIFY_TOKEN="):
        removed += 1
        continue

    new_lines.append(line)

path.write_text("\n".join(new_lines) + "\n")

if removed == 0:
    print("Aviso: META_WEBHOOK_VERIFY_TOKEN nao estava presente no .env.")
else:
    print(f"Removidas {removed} linha(s) META_WEBHOOK_VERIFY_TOKEN do .env.")
PY

if grep -q '^META_WEBHOOK_VERIFY_TOKEN=' "${ENV_FILE}"; then
  echo "ERRO: META_WEBHOOK_VERIFY_TOKEN ainda existe no .env"
  exit 1
fi

if ! grep -q '^WHATSAPP_VERIFY_TOKEN=' "${ENV_FILE}"; then
  echo "ERRO: WHATSAPP_VERIFY_TOKEN nao encontrado no .env"
  exit 1
fi

echo "Atualizando documentos auxiliares..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cp "${BASE_DIR}/${doc_file}" "${BACKUPS_DIR}/${doc_file}_${STAMP}.bak"

    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Ajuste operacional - Remocao de META_WEBHOOK_VERIFY_TOKEN
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Removida a variavel META_WEBHOOK_VERIFY_TOKEN do .env para evitar conflito operacional. O backend de webhook Meta valida o token usando WHATSAPP_VERIFY_TOKEN.
DOC
  fi
done

cat > "${LOG_FILE}" <<DOC
Acao: Remover META_WEBHOOK_VERIFY_TOKEN do .env
Data: $(date '+%Y-%m-%d %H:%M:%S')
Arquivo alterado: .env
Backup: backups/env_${STAMP}.bak
Token mantido: WHATSAPP_VERIFY_TOKEN
Documentos auxiliares atualizados: CONTEXTO_PROJETO.md, CHANGELOG.md, DECISOES_TECNICAS.md, PENDENCIAS.md quando existentes
Status: Concluido
DOC

echo ""
echo "== Remocao concluida com sucesso =="
cat "${LOG_FILE}"
