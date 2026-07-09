#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/fix_13.log"

echo "== Correcao Etapa 13: remover caractere proibido do tsconfig =="

cd "${BASE_DIR}"

mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backup do tsconfig..."

if [ -f "${BACKEND_DIR}/tsconfig.json" ]; then
  cp "${BACKEND_DIR}/tsconfig.json" "${BACKUPS_DIR}/tsconfig_${STAMP}.json.bak"
fi

echo "Regravando apps/backend/tsconfig.json sem caractere proibido..."

cat > "${BACKEND_DIR}/tsconfig.json" <<'DOC'
{
  "compilerOptions": {
    "module": "commonjs",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2021",
    "sourceMap": true,
    "outDir": "./dist",
    "baseUrl": "./",
    "incremental": true,
    "strict": true,
    "skipLibCheck": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": [
    "src"
  ],
  "exclude": [
    "node_modules",
    "dist"
  ]
}
DOC

echo "Validando arquivos esperados da Etapa 13..."

test -f "${BACKEND_DIR}/package.json"
test -f "${BACKEND_DIR}/tsconfig.json"
test -f "${BACKEND_DIR}/src/main.ts"
test -f "${BACKEND_DIR}/src/app.module.ts"
test -f "${BACKEND_DIR}/src/health.controller.ts"
test -f "${BACKEND_DIR}/src/config/app.config.ts"
test -f "${BACKEND_DIR}/src/config/env.example.ts"
test -f "${BACKEND_DIR}/src/common/README.md"
test -f "${DOCS_DIR}/BACKEND_BASE.md"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"

echo "Validando ausencia de caractere proibido..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${BACKEND_DIR}/package.json" \
  "${BACKEND_DIR}/tsconfig.json" \
  "${BACKEND_DIR}/src/main.ts" \
  "${BACKEND_DIR}/src/app.module.ts" \
  "${BACKEND_DIR}/src/health.controller.ts" \
  "${BACKEND_DIR}/src/config/app.config.ts" \
  "${BACKEND_DIR}/src/config/env.example.ts" \
  "${BACKEND_DIR}/src/common/README.md" \
  "${DOCS_DIR}/BACKEND_BASE.md" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado apos correcao."
  exit 1
fi

echo "Gravando log de correcao..."

cat > "${LOG_FILE}" <<DOC
Correcao: Etapa 13
Acao: Remocao de caractere proibido do tsconfig
Data: $(date '+%Y-%m-%d %H:%M:%S')
Arquivo corrigido:
- apps/backend/tsconfig.json
Backup:
- backups/tsconfig_${STAMP}.json.bak
Status: Concluido
DOC

echo ""
echo "== Correcao concluida com sucesso =="
echo ""
echo "tsconfig atual:"
cat "${BACKEND_DIR}/tsconfig.json"
echo ""
echo "Etapa 13 agora esta valida."
