#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
SCRIPTS_DIR="${BASE_DIR}/scripts"
STAMP="$(date '+%Y%m%d_%H%M%S')"

REPORT_FILE="${DOCS_DIR}/EXECUCAO_INICIAL_DOMINIO.md"
LOG_FILE="${LOGS_DIR}/setup_20c_subir_testar_dominio.log"
COMPOSE_UP_LOG="${LOGS_DIR}/setup_20c_docker_compose_up.log"
COMPOSE_PS_LOG="${LOGS_DIR}/setup_20c_docker_compose_ps.log"
BACKEND_TEST_LOG="${LOGS_DIR}/setup_20c_backend_health.log"
FRONTEND_TEST_LOG="${LOGS_DIR}/setup_20c_frontend_local.log"
PROXY_TEST_LOG="${LOGS_DIR}/setup_20c_proxy_local.log"
DOMAIN_TEST_LOG="${LOGS_DIR}/setup_20c_domain_test.log"

echo "== Etapa 20C: Subir containers e testar dominio bot.lhsolucao.com.br =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${SCRIPTS_DIR}"

echo "Criando backups..."

for file in \
  "${REPORT_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Validando ferramentas..."

if ! command -v docker >/dev/null 2>&1; then
  echo "ERRO: docker nao encontrado."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "ERRO: curl nao encontrado."
  exit 1
fi

DOCKER_VERSION="$(docker --version)"
COMPOSE_VERSION="$(docker compose version)"

echo "Docker: ${DOCKER_VERSION}"
echo "Docker Compose: ${COMPOSE_VERSION}"

echo "Validando arquivos obrigatorios..."

test -f "${BASE_DIR}/docker-compose.yml"
test -f "${BASE_DIR}/.env"
test -f "${BASE_DIR}/.env.example"
test -f "${BASE_DIR}/infra/nginx/nginx.conf"
test -f "${BASE_DIR}/infra/docker/backend.Dockerfile"
test -f "${BASE_DIR}/infra/docker/frontend.Dockerfile"
test -f "${BASE_DIR}/infra/docker/worker.Dockerfile"

echo "Validando Nginx externo do servidor..."

if command -v nginx >/dev/null 2>&1; then
  sudo nginx -t 2>&1 | tee "${LOGS_DIR}/setup_20c_nginx_test.log"
else
  echo "Aviso: nginx nao encontrado no host. Pulando nginx -t." | tee "${LOGS_DIR}/setup_20c_nginx_test.log"
fi

echo "Validando docker compose config..."

docker compose config > "${LOGS_DIR}/setup_20c_docker_config.log"

echo "Subindo postgres e redis..."

docker compose up -d postgres redis 2>&1 | tee "${COMPOSE_UP_LOG}"

echo "Aguardando postgres e redis ficarem saudaveis..."

wait_for_health() {
  container_name="$1"
  max_attempts="$2"
  attempt="1"

  while [ "${attempt}" -le "${max_attempts}" ]; do
    status="$(docker inspect -f '{{.State.Health.Status}}' "${container_name}" 2>/dev/null || echo "unknown")"

    echo "${container_name}: ${status}"

    if [ "${status}" = "healthy" ]; then
      return 0
    fi

    sleep 3
    attempt="$((attempt + 1))"
  done

  echo "ERRO: ${container_name} nao ficou healthy."
  return 1
}

wait_for_health "saas_whatsapp_postgres" "40"
wait_for_health "saas_whatsapp_redis" "40"

echo "Subindo backend..."

docker compose up -d backend 2>&1 | tee -a "${COMPOSE_UP_LOG}"

echo "Aguardando backend iniciar..."

sleep 8

echo "Testando backend local..."

BACKEND_STATUS="$(curl -s -o "${BACKEND_TEST_LOG}" -w "%{http_code}" --max-time 20 http://127.0.0.1:3300/api/v1/health || true)"

echo "Backend HTTP status: ${BACKEND_STATUS}"

if [ "${BACKEND_STATUS}" != "200" ]; then
  echo "ERRO: backend nao respondeu 200 em /api/v1/health."
  echo "Log do backend:"
  docker compose logs --tail=120 backend
  exit 1
fi

echo "Subindo frontend, proxy e worker..."

docker compose up -d frontend proxy worker 2>&1 | tee -a "${COMPOSE_UP_LOG}"

echo "Aguardando servicos iniciarem..."

sleep 8

echo "Registrando docker compose ps..."

docker compose ps 2>&1 | tee "${COMPOSE_PS_LOG}"

echo "Testando frontend local..."

FRONTEND_STATUS="$(curl -s -o "${FRONTEND_TEST_LOG}" -w "%{http_code}" --max-time 20 http://127.0.0.1:5573 || true)"

echo "Frontend HTTP status: ${FRONTEND_STATUS}"

if [ "${FRONTEND_STATUS}" != "200" ]; then
  echo "ERRO: frontend local nao respondeu 200."
  docker compose logs --tail=120 frontend
  exit 1
fi

echo "Testando proxy local..."

PROXY_STATUS="$(curl -s -o "${PROXY_TEST_LOG}" -w "%{http_code}" --max-time 20 http://127.0.0.1:8180 || true)"

echo "Proxy HTTP status: ${PROXY_STATUS}"

if [ "${PROXY_STATUS}" != "200" ]; then
  echo "ERRO: proxy local nao respondeu 200."
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Testando dominio HTTPS..."

DOMAIN_STATUS="$(curl -L -s -o "${DOMAIN_TEST_LOG}" -w "%{http_code}" --max-time 30 https://bot.lhsolucao.com.br || true)"

echo "Dominio HTTP status: ${DOMAIN_STATUS}"

if [ "${DOMAIN_STATUS}" != "200" ]; then
  echo "ERRO: dominio bot.lhsolucao.com.br nao respondeu 200."
  echo "Verifique DNS, SSL, firewall e Nginx externo."
  echo "Ultimos logs do Nginx do projeto:"
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Gerando relatorio..."

cat > "${REPORT_FILE}" <<DOC
# Execucao Inicial e Teste do Dominio

## Visao geral

Este documento registra a subida inicial dos containers e o teste do dominio bot.lhsolucao.com.br.

## Resultado

Status:

    concluido

## Servicos iniciados

Servicos:

- postgres
- redis
- backend
- frontend
- proxy
- worker

## Portas externas

Portas:

- Backend 3300
- Frontend 5573
- Proxy 8180
- PostgreSQL 55432
- Redis 56379

## Testes executados

Testes:

- docker compose config
- postgres healthcheck
- redis healthcheck
- backend local em http://127.0.0.1:3300/api/v1/health
- frontend local em http://127.0.0.1:5573
- proxy local em http://127.0.0.1:8180
- dominio em https://bot.lhsolucao.com.br

## Resultado dos testes HTTP

Resultados:

- Backend ${BACKEND_STATUS}
- Frontend ${FRONTEND_STATUS}
- Proxy ${PROXY_STATUS}
- Dominio ${DOMAIN_STATUS}

## Logs gerados

Logs:

- logs/setup_20c_docker_config.log
- logs/setup_20c_docker_compose_up.log
- logs/setup_20c_docker_compose_ps.log
- logs/setup_20c_backend_health.log
- logs/setup_20c_frontend_local.log
- logs/setup_20c_proxy_local.log
- logs/setup_20c_domain_test.log
- logs/setup_20c_nginx_test.log
- logs/setup_20c_subir_testar_dominio.log

## Observacoes

O dominio bot.lhsolucao.com.br foi testado usando HTTPS.

O Nginx externo do servidor encaminha o dominio para o proxy Docker local na porta 8180.

## Comandos uteis

Ver containers:

    docker compose ps

Ver logs do backend:

    docker compose logs backend

Ver logs do frontend:

    docker compose logs frontend

Ver logs do proxy:

    docker compose logs proxy

Parar o ambiente:

    docker compose down

## Proxima etapa sugerida

Etapa 21:

    Criar modulo real de health, configuracao e base de banco no backend
DOC

echo "Atualizando 00_CONTROLE.md..."

cat > "${BASE_DIR}/00_CONTROLE.md" <<'DOC'
# Controle do Projeto

Projeto: SaaS de Chatbot WhatsApp com API Oficial da Meta

Este arquivo registra o controle das etapas de criacao da documentacao e estrutura inicial.

## Fase 01 - Documentacao inicial

- [x] Etapa 01 - Preparacao do ambiente de documentacao
- [x] Etapa 02 - Criacao do README principal
- [x] Etapa 03 - Documentacao de arquitetura
- [x] Etapa 04 - Documentacao do banco de dados
- [x] Etapa 05 - Documentacao da API
- [x] Etapa 06 - Documentacao de seguranca
- [x] Etapa 07 - Documentacao de webhooks da Meta
- [x] Etapa 08 - Documentacao do frontend
- [x] Etapa 09 - Documentacao do backend
- [x] Etapa 10 - Documentacao de deploy
- [x] Etapa 11 - Manifesto final e validacao

## Fase 02 - Estrutura real do projeto

- [x] Etapa 12 - Estrutura de pastas do monorepo
- [x] Etapa 13 - Arquivos base do backend
- [x] Etapa 14 - Arquivos base do frontend
- [x] Etapa 15 - Docker Compose inicial
- [x] Etapa 16 - Arquivo env example
- [x] Etapa 17 - Validacao do ambiente inicial
- [x] Etapa 18 - Instalacao e validacao de dependencias

## Fase 03 - Build e execucao inicial com Docker

- [x] Etapa 19 - Ajustar Dockerfiles e validar build dos containers
- [x] Etapa 20A - Auditoria e backup do Nginx
- [x] Etapa 20B - Configurar Nginx para bot.lhsolucao.com.br
- [x] Etapa 20C - Subir containers e testar dominio

## Ultima etapa executada

Etapa 20C - Subir containers e testar dominio.

## Proxima etapa sugerida

Etapa 21 - Criar modulo real de health, configuracao e base de banco no backend.
DOC

echo "Atualizando MANIFESTO.md..."

cat > "${BASE_DIR}/MANIFESTO.md" <<'DOC'
# Manifesto do Projeto

## Projeto

SaaS de Chatbot WhatsApp com API Oficial da Meta

## Status

Documentacao inicial concluida.

Estrutura real do monorepo criada.

Backend base criado.

Frontend base criado.

Docker Compose inicial criado.

Env example criado.

Ambiente inicial validado.

Dependencias base instaladas e validadas.

Dockerfiles ajustados e builds validados.

Dominio bot.lhsolucao.com.br configurado e testado.

## Arquivos principais

- README.md
- MANIFESTO.md
- 00_CONTROLE.md
- docker-compose.yml
- .env.example
- .env
- .dockerignore

## Documentos tecnicos

- docs/ARQUITETURA.md
- docs/BANCO_DADOS.md
- docs/API.md
- docs/SEGURANCA.md
- docs/WEBHOOKS_META.md
- docs/FRONTEND.md
- docs/BACKEND.md
- docs/DEPLOY.md
- docs/VALIDACAO_FINAL.md
- docs/ESTRUTURA_PROJETO.md
- docs/BACKEND_BASE.md
- docs/FRONTEND_BASE.md
- docs/DOCKER_COMPOSE_BASE.md
- docs/ENV_EXAMPLE.md
- docs/VALIDACAO_AMBIENTE.md
- docs/DEPENDENCIAS_BASE.md
- docs/DOCKER_BUILD.md
- docs/NGINX_BOT_LHSOLUCAO.md
- docs/EXECUCAO_INICIAL_DOMINIO.md

## Etapas concluidas

- Etapa 01 ate Etapa 20C concluidas

## Proxima etapa

- Etapa 21 - Criar modulo real de health, configuracao e base de banco no backend
DOC

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${REPORT_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 20C
Acao: Subir containers e testar dominio
Data: $(date '+%Y-%m-%d %H:%M:%S')
Backend status: ${BACKEND_STATUS}
Frontend status: ${FRONTEND_STATUS}
Proxy status: ${PROXY_STATUS}
Dominio status: ${DOMAIN_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 20C concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${REPORT_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br"
