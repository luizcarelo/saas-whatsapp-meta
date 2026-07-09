#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_10.log"

echo "== Etapa 10: Documentacao de deploy =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

if [ -f "${DOCS_DIR}/DEPLOY.md" ]; then
  cp "${DOCS_DIR}/DEPLOY.md" "${BACKUPS_DIR}/DEPLOY_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/00_CONTROLE.md" ]; then
  cp "${BASE_DIR}/00_CONTROLE.md" "${BACKUPS_DIR}/00_CONTROLE_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/MANIFESTO.md" ]; then
  cp "${BASE_DIR}/MANIFESTO.md" "${BACKUPS_DIR}/MANIFESTO_${STAMP}.md"
fi

echo "Gerando docs/DEPLOY.md..."

cat > "${DOCS_DIR}/DEPLOY.md" <<'DOC'
# Deploy

## Visao geral

Este documento define a estrategia inicial de deploy do SaaS de Chatbot WhatsApp com API Oficial da Meta.

O deploy inicial sera baseado em Docker e Docker Compose.

O objetivo e permitir um ambiente padronizado para desenvolvimento, homologacao e producao inicial, mantendo separacao entre frontend, backend, workers, PostgreSQL, Redis e proxy reverso.

## Objetivos do deploy

O deploy deve permitir:

- Subir ambiente local com poucos comandos
- Separar frontend, backend e workers
- Usar PostgreSQL como banco principal
- Usar Redis para filas e cache
- Expor backend com HTTPS em producao
- Expor frontend com proxy reverso
- Receber webhooks da Meta em endpoint publico HTTPS
- Executar backups
- Separar configuracoes por ambiente
- Facilitar manutencao e evolucao

## Estrategia inicial

Estrategia definida:

- Docker para empacotar servicos
- Docker Compose para orquestracao inicial
- Nginx ou Traefik como proxy reverso
- PostgreSQL em container para desenvolvimento
- Redis em container para desenvolvimento
- PostgreSQL gerenciado recomendado para producao futura
- Redis gerenciado recomendado para producao futura

## Ambientes

Ambientes previstos:

    development
    staging
    production

## Development

Ambiente de desenvolvimento local.

Objetivo:

- Permitir desenvolvimento rapido
- Usar containers locais
- Facilitar testes de integracao
- Permitir logs detalhados

Servicos esperados:

    frontend
    backend
    worker
    postgres
    redis

## Staging

Ambiente de homologacao.

Objetivo:

- Testar fluxo proximo da producao
- Usar HTTPS
- Usar tokens de teste ou ambiente controlado
- Validar webhook publico
- Validar migracoes
- Validar build do frontend

Servicos esperados:

    frontend
    backend
    worker
    postgres
    redis
    proxy

## Production

Ambiente de producao.

Objetivo:

- Rodar sistema com seguranca
- Usar HTTPS obrigatorio
- Usar secrets protegidos
- Ter backup automatico
- Ter logs e monitoramento
- Ter estrategia de atualizacao

Servicos esperados:

    frontend
    backend
    worker
    postgres ou banco gerenciado
    redis ou redis gerenciado
    proxy

## Servicos do Docker Compose

Servicos iniciais:

    frontend
    backend
    worker
    postgres
    redis
    proxy

## frontend

Responsavel por servir a interface React.

Responsabilidades:

- Build da aplicacao React
- Servir arquivos estaticos
- Consumir API interna
- Conectar no Socket.IO

Variaveis esperadas:

    VITE_API_URL
    VITE_SOCKET_URL
    VITE_APP_NAME

## backend

Responsavel pela API principal.

Responsabilidades:

- Subir API REST
- Receber webhooks
- Autenticar usuarios
- Validar tenant
- Validar permissoes
- Enfileirar jobs
- Emitir eventos via Socket.IO

Variaveis esperadas:

    NODE_ENV
    APP_PORT
    APP_URL
    FRONTEND_URL
    DATABASE_URL
    REDIS_HOST
    REDIS_PORT
    JWT_SECRET
    JWT_REFRESH_SECRET
    ENCRYPTION_KEY
    META_GRAPH_BASE_URL
    META_API_VERSION
    META_WEBHOOK_VERIFY_TOKEN
    META_APP_SECRET

## worker

Responsavel por tarefas assincronas.

Responsabilidades:

- Processar webhooks
- Enviar mensagens para Meta
- Atualizar status de mensagens
- Executar chatbot
- Processar notificacoes
- Reprocessar falhas controladas

Variaveis esperadas:

    NODE_ENV
    DATABASE_URL
    REDIS_HOST
    REDIS_PORT
    ENCRYPTION_KEY
    META_GRAPH_BASE_URL
    META_API_VERSION

## postgres

Banco principal do sistema.

Uso inicial:

- Desenvolvimento
- Homologacao simples
- Producao inicial apenas quando bem protegido

Regras:

- Dados devem persistir em volume
- Nao expor porta publicamente em producao
- Usar senha forte
- Fazer backup automatico
- Rodar migracoes de forma controlada

## redis

Usado para cache, filas e rate limit.

Regras:

- Nao usar como banco principal
- Nao expor porta publicamente em producao
- Usar senha quando aplicavel
- Monitorar consumo de memoria
- Separar ambientes

## proxy

Nginx ou Traefik.

Responsabilidades:

- Terminar HTTPS
- Roteamento para frontend
- Roteamento para backend
- Encaminhar webhook da Meta
- Aplicar headers basicos de seguranca
- Redirecionar HTTP para HTTPS

## Estrutura sugerida de infraestrutura

Pastas sugeridas:

    infra/
      docker/
        backend.Dockerfile
        frontend.Dockerfile
        worker.Dockerfile
      nginx/
        nginx.conf
      traefik/
        dynamic.yml
      postgres/
        init/
      scripts/
        backup-postgres.sh
        restore-postgres.sh

Arquivos na raiz:

    docker-compose.yml
    docker-compose.dev.yml
    docker-compose.prod.yml
    .env.example

## Dockerfile do backend

Responsabilidades:

- Instalar dependencias
- Compilar TypeScript
- Gerar build
- Rodar aplicacao em modo producao

Regras:

- Nao copiar .env real para imagem
- Usar usuario nao root quando possivel
- Separar build e runtime quando possivel
- Instalar apenas dependencias necessarias em producao

## Dockerfile do frontend

Responsabilidades:

- Instalar dependencias
- Gerar build do Vite
- Servir arquivos estaticos com Nginx ou outro servidor

Regras:

- Variaveis VITE devem ser definidas no build quando necessario
- Nao incluir secrets no frontend
- Nao expor tokens da Meta
- Build deve ser reproduzivel

## Dockerfile do worker

Responsabilidades:

- Instalar dependencias
- Compilar TypeScript
- Executar processo de worker

Regras:

- Worker deve usar mesma base de codigo do backend quando aplicavel
- Worker nao deve expor porta publica
- Worker deve ter logs claros
- Worker deve ter restart policy

## Variaveis de ambiente

Arquivo exemplo:

    .env.example

Variaveis backend:

    NODE_ENV=development
    APP_PORT=3000
    APP_URL=http://localhost:3000
    FRONTEND_URL=http://localhost:5173
    DATABASE_URL=postgresql://user:password@postgres:5432/saas_whatsapp
    REDIS_HOST=redis
    REDIS_PORT=6379
    JWT_SECRET=change_me
    JWT_REFRESH_SECRET=change_me
    ENCRYPTION_KEY=change_me
    META_GRAPH_BASE_URL=https://graph.facebook.com
    META_API_VERSION=v20.0
    META_WEBHOOK_VERIFY_TOKEN=change_me
    META_APP_SECRET=change_me

Variaveis frontend:

    VITE_API_URL=http://localhost:3000/api/v1
    VITE_SOCKET_URL=http://localhost:3000/realtime
    VITE_APP_NAME=SaaS WhatsApp Meta

Regras:

- Nao versionar .env real
- Versionar apenas .env.example
- Usar secrets fortes em producao
- Separar secrets por ambiente
- Rotacionar secrets quando necessario

## Rede interna

Regras:

- Backend acessa postgres pela rede interna
- Backend acessa redis pela rede interna
- Worker acessa postgres pela rede interna
- Worker acessa redis pela rede interna
- Frontend acessa backend pelo proxy ou URL publica
- Postgres nao deve ser exposto publicamente em producao
- Redis nao deve ser exposto publicamente em producao

## Volumes

Volumes esperados:

    postgres_data
    redis_data quando necessario
    proxy_certs quando aplicavel
    logs quando aplicavel
    backups quando aplicavel

Regras:

- Dados do PostgreSQL devem persistir
- Backups devem ficar fora do container
- Certificados devem persistir
- Logs podem ser coletados por solucao externa futura

## Portas

Portas comuns em desenvolvimento:

    frontend 5173
    backend 3000
    postgres 5432
    redis 6379

Portas em producao:

    80
    443

Regras:

- Em producao, expor apenas proxy
- Banco e Redis devem ficar internos
- Backend pode ficar interno atras do proxy
- Worker nao deve expor porta

## HTTPS

HTTPS e obrigatorio em producao.

Regras:

- Webhook da Meta deve ser HTTPS
- Login deve usar HTTPS
- API deve usar HTTPS
- Socket.IO deve usar WSS quando em producao
- HTTP deve redirecionar para HTTPS
- Certificado deve ser renovado automaticamente

## Proxy reverso

Opcoes:

- Nginx
- Traefik

Nginx e simples e conhecido.

Traefik facilita descoberta de servicos e certificados automaticos em alguns cenarios.

Decisao inicial:

- Usar Nginx no desenvolvimento documentado
- Permitir Traefik como alternativa futura

## Health checks

Servicos devem ter verificacoes de saude.

Health checks sugeridos:

    backend /health
    postgres pg_isready
    redis ping
    worker verificacao por log ou fila
    frontend resposta HTTP

Objetivos:

- Detectar falhas
- Facilitar restart
- Ajudar no deploy
- Apoiar monitoramento

## Logs

Logs devem ser enviados para stdout e stderr.

Regras:

- Nao gravar secrets
- Nao gravar tokens
- Nao gravar senhas
- Registrar erro resumido
- Registrar tenant quando aplicavel
- Registrar usuario quando aplicavel
- Registrar tempo de resposta

Logs importantes:

- login
- falha de login
- webhook recebido
- job processado
- job com erro
- mensagem enviada
- falha de envio
- migracao executada

## Backup

Backup inicial do PostgreSQL.

Politica sugerida:

- Backup diario
- Backup antes de migracoes
- Retencao minima de 7 dias no inicio
- Teste periodico de restauracao
- Logs de backup
- Armazenamento protegido

Arquivos sugeridos:

    infra/scripts/backup-postgres.sh
    infra/scripts/restore-postgres.sh

Regras:

- Backup deve sair do container
- Backup deve ser protegido
- Backup nao deve ser enviado para repositorio
- Restauracao deve ser testada

## Migracoes

Regras:

- Toda mudanca de schema deve usar migracao versionada
- Migracao deve rodar antes do novo backend quando necessario
- Backup deve ser feito antes de migracao em producao
- Migracao deve ser testada em staging
- Nao alterar banco manualmente em producao

## Atualizacao de versao

Fluxo sugerido:

1. Fazer backup
2. Baixar nova versao do codigo
3. Gerar imagens
4. Rodar migracoes
5. Subir backend
6. Subir workers
7. Subir frontend
8. Validar health checks
9. Validar webhook
10. Validar envio de mensagem

## Rollback

Rollback deve ser planejado.

Regras:

- Manter imagem anterior
- Manter backup antes da migracao
- Documentar versao implantada
- Reverter imagem quando necessario
- Restaurar backup apenas quando necessario
- Registrar incidente

## Monitoramento

Monitoramento inicial recomendado:

- Status dos containers
- Uso de CPU
- Uso de memoria
- Uso de disco
- Tamanho do banco
- Tamanho das filas
- Falhas de jobs
- Erros HTTP
- Falhas de webhook
- Falhas de envio Meta

## Alertas

Alertas iniciais:

- Backend fora do ar
- Worker parado
- Postgres indisponivel
- Redis indisponivel
- Fila acumulando
- Falha recorrente de webhook
- Falha recorrente de envio
- Disco quase cheio
- Backup falhou
- Certificado perto de expirar

## Segurança em producao

Regras obrigatorias:

- HTTPS ativo
- CORS restrito
- Secrets fortes
- .env protegido
- Banco sem acesso publico
- Redis sem acesso publico
- Tokens criptografados
- Logs sem dados sensiveis
- Backups protegidos
- Rate limit ativo
- Firewall configurado
- Acesso SSH protegido

## Checklist de desenvolvimento

Antes de iniciar desenvolvimento:

- Docker instalado
- Docker Compose disponivel
- .env criado a partir de .env.example
- Postgres subindo
- Redis subindo
- Backend conectando ao banco
- Backend conectando ao Redis
- Frontend conectando ao backend
- Worker conectando a fila

## Checklist de homologacao

Antes de validar em staging:

- Build do frontend gerado
- Backend em modo staging
- Worker em modo staging
- HTTPS ativo
- Webhook publico configurado
- Banco separado de producao
- Redis separado de producao
- Logs ativos
- Backup testado
- Variaveis revisadas

## Checklist de producao

Antes de colocar em producao:

- Dominio configurado
- HTTPS ativo
- Webhook HTTPS validado
- Secrets fortes
- Banco protegido
- Redis protegido
- Backup automatico ativo
- Restauracao testada
- CORS restrito
- Rate limit ativo
- Logs sem secrets
- Workers ativos
- Health checks ativos
- Monitoramento ativo
- Plano de rollback documentado

## Evolucao futura

Possiveis evolucoes:

- Docker Swarm
- Kubernetes
- AWS ECS
- Azure Container Apps
- Google Cloud Run
- Banco gerenciado
- Redis gerenciado
- Object storage para midias
- CDN para frontend
- Observabilidade centralizada
- Pipeline CI CD

## Decisao final desta etapa

A estrategia inicial de deploy sera:

- Docker para empacotamento
- Docker Compose para desenvolvimento e producao inicial controlada
- Frontend em container separado
- Backend em container separado
- Workers em containers separados
- PostgreSQL como banco principal
- Redis para filas e cache
- Nginx ou Traefik como proxy reverso
- HTTPS obrigatorio em producao
- Backup e rollback obrigatorios antes de mudancas sensiveis
DOC

echo "Atualizando 00_CONTROLE.md..."

cat > "${BASE_DIR}/00_CONTROLE.md" <<'DOC'
# Controle do Projeto

Projeto: SaaS de Chatbot WhatsApp com API Oficial da Meta

Este arquivo registra o controle das etapas de criacao da documentacao e estrutura inicial.

## Etapas

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
- [ ] Etapa 11 - Manifesto final e validacao

## Ultima etapa executada

Etapa 10 - Documentacao de deploy.

## Proxima etapa sugerida

Etapa 11 - Criar manifesto final e executar validacao geral da documentacao.
DOC

echo "Atualizando MANIFESTO.md..."

cat > "${BASE_DIR}/MANIFESTO.md" <<'DOC'
# Manifesto da Documentacao

Este manifesto lista os arquivos esperados da documentacao inicial do projeto.

## Pasta base

saas-whatsapp-meta/

## Arquivos principais

- README.md
- MANIFESTO.md
- 00_CONTROLE.md

## Documentos tecnicos

- docs/ARQUITETURA.md
- docs/BANCO_DADOS.md
- docs/API.md
- docs/SEGURANCA.md
- docs/WEBHOOKS_META.md
- docs/FRONTEND.md
- docs/BACKEND.md
- docs/DEPLOY.md

## Pastas de apoio

- scripts/
- logs/
- backups/

## Etapas concluidas

- Etapa 01 - Preparacao do ambiente de documentacao
- Etapa 02 - Criacao do README principal
- Etapa 03 - Documentacao de arquitetura
- Etapa 04 - Documentacao do banco de dados
- Etapa 05 - Documentacao da API
- Etapa 06 - Documentacao de seguranca
- Etapa 07 - Documentacao de webhooks da Meta
- Etapa 08 - Documentacao do frontend
- Etapa 09 - Documentacao do backend
- Etapa 10 - Documentacao de deploy

## Proxima etapa

- Etapa 11 - Manifesto final e validacao

## Arquivos atualizados na Etapa 10

- docs/DEPLOY.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_10.log
DOC

echo "Validando arquivos obrigatorios..."

test -f "${DOCS_DIR}/DEPLOY.md"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"
test -d "${DOCS_DIR}"
test -d "${SCRIPTS_DIR}"
test -d "${LOGS_DIR}"
test -d "${BACKUPS_DIR}"

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" "${DOCS_DIR}/DEPLOY.md" "${BASE_DIR}/00_CONTROLE.md" "${BASE_DIR}/MANIFESTO.md"; then
  echo "ERRO: caractere proibido encontrado nos arquivos gerados."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 10
Acao: Documentacao de deploy
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos alterados:
- docs/DEPLOY.md
- 00_CONTROLE.md
- MANIFESTO.md
Backups:
- backups/DEPLOY_${STAMP}.md
- backups/00_CONTROLE_${STAMP}.md
- backups/MANIFESTO_${STAMP}.md
Status: Concluido
DOC

echo ""
echo "== Etapa 10 concluida com sucesso =="
echo ""
echo "Arquivos principais:"
find "${BASE_DIR}" -maxdepth 2 -type f | sort
echo ""
echo "Resumo de docs/DEPLOY.md:"
sed -n '1,180p' "${DOCS_DIR}/DEPLOY.md"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 11 - Manifesto final e validacao geral"
