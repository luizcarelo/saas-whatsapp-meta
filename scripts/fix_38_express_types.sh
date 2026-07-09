#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

FIX_LOG_FILE="${LOGS_DIR}/fix_38_express_types.log"
NPM_EXPRESS_LOG="${LOGS_DIR}/fix_38_install_express.log"
NPM_TYPES_LOG="${LOGS_DIR}/fix_38_install_types_express.log"
TYPECHECK_LOG="${LOGS_DIR}/fix_38_backend_typecheck_before_rerun.log"
BUILD_LOG="${LOGS_DIR}/fix_38_backend_build_before_rerun.log"

echo "== Correcao Etapa 38: dependencias express e tipos =="

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/package.json" \
  "${BACKEND_DIR}/package-lock.json" \
  "${BACKEND_DIR}/src/main.ts" \
  "${BACKEND_DIR}/src/common/middleware/raw-body.middleware.ts" \
  "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.controller.ts" \
  "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.service.ts" \
  "${BACKEND_DIR}/src/modules/webhooks/meta-webhooks.types.ts" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Validando ferramentas..."

if ! command -v node >/dev/null 2>&1; then
  echo "ERRO: node nao encontrado."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "ERRO: npm nao encontrado."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERRO: docker nao encontrado."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Instalando express no backend..."

cd "${BACKEND_DIR}"

npm install express 2>&1 | tee "${NPM_EXPRESS_LOG}"

echo "Instalando @types/express no backend..."

npm install --save-dev @types/express 2>&1 | tee "${NPM_TYPES_LOG}"

echo "Rodando typecheck antes de reexecutar a Etapa 38..."

npm run typecheck 2>&1 | tee "${TYPECHECK_LOG}"

echo "Rodando build antes de reexecutar a Etapa 38..."

npm run build 2>&1 | tee "${BUILD_LOG}"

cd "${BASE_DIR}"

echo "Validando script da Etapa 38..."

if [ ! -f "${BASE_DIR}/scripts/setup_38_meta_webhook_signature.sh" ]; then
  echo "ERRO: script da Etapa 38 nao encontrado."
  exit 1
fi

chmod +x "${BASE_DIR}/scripts/setup_38_meta_webhook_signature.sh"

echo "Reexecutando Etapa 38 completa..."

"${BASE_DIR}/scripts/setup_38_meta_webhook_signature.sh"

cat > "${FIX_LOG_FILE}" <<DOC
Etapa: 38
Acao: Correcao dependencias express e @types/express
Data: $(date '+%Y-%m-%d %H:%M:%S')
Status: Concluido
DOC

echo ""
echo "== Correcao da Etapa 38 concluida =="
echo ""
echo "Agora confira:"
echo "sed -n '1,220p' docs/BACKEND_META_WEBHOOK_SIGNATURE.md"
echo "cat logs/setup_38_webhook_signed_post_domain.log"
echo "cat logs/setup_38_webhook_bad_signature_domain.log"
echo "cat logs/setup_38_container_env.log"
echo "cat 00_CONTROLE.md"
