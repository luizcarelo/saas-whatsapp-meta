#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_02.log"

echo "== Etapa 02: README principal =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

if [ -f "${BASE_DIR}/README.md" ]; then
  cp "${BASE_DIR}/README.md" "${BACKUPS_DIR}/README_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/00_CONTROLE.md" ]; then
  cp "${BASE_DIR}/00_CONTROLE.md" "${BACKUPS_DIR}/00_CONTROLE_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/MANIFESTO.md" ]; then
  cp "${BASE_DIR}/MANIFESTO.md" "${BACKUPS_DIR}/MANIFESTO_${STAMP}.md"
fi

echo "Gerando README.md..."

cat > "${BASE_DIR}/README.md" <<'DOC'
# SaaS de Chatbot WhatsApp com API Oficial da Meta

## Visao geral

Este projeto tem como objetivo criar uma plataforma SaaS multi-tenant para atendimento, automacao e chatbot usando a API oficial da Meta para WhatsApp Business Platform.

A plataforma sera usada por empresas clientes, chamadas de tenants, que terao seus proprios usuarios, contatos, conversas, configuracoes, contas WhatsApp e historico de atendimento.

## Objetivo principal

Criar um sistema seguro, modular e escalavel para:

- Receber mensagens do WhatsApp via webhook da Meta
- Enviar mensagens pela Cloud API da Meta
- Gerenciar conversas em tempo real
- Permitir atendimento humano
- Permitir chatbot e fluxos automaticos
- Controlar usuarios e permissoes
- Manter historico completo de contatos, conversas e mensagens
- Operar como SaaS multiempresa
- Permitir evolucao futura para cobranca, relatorios e integracoes

## Stack tecnica definida

### Frontend

- React
- TypeScript
- Vite
- Tailwind CSS
- shadcn/ui
- TanStack Query
- Zustand
- React Hook Form
- Zod
- Socket.IO Client

### Backend

- NestJS
- Fastify
- TypeScript
- Prisma ou TypeORM
- JWT
- RBAC
- BullMQ
- Socket.IO
- Cliente HTTP para integracao com a Meta

### Banco de dados

- PostgreSQL como banco principal

### Cache e filas

- Redis
- BullMQ

### Infraestrutura

- Docker
- Docker Compose no inicio
- Nginx ou Traefik para proxy e SSL em producao

## Modelo de arquitetura

O projeto seguira inicialmente o modelo de modular monolith com workers separados.

Esse modelo permite iniciar com menor complexidade, mantendo separacao clara entre os modulos internos e preparando o sistema para futura separacao em servicos independentes, caso necessario.

## Fluxo resumido de mensagem recebida

1. Cliente envia mensagem pelo WhatsApp
2. Meta envia evento para o webhook HTTPS do backend
3. Backend valida e registra o payload bruto
4. Backend coloca o evento em uma fila
5. Worker processa o evento
6. Sistema identifica o tenant pelo numero WhatsApp
7. Sistema cria ou atualiza contato
8. Sistema cria ou atualiza conversa
9. Sistema salva a mensagem
10. Sistema executa regras de chatbot quando aplicavel
11. Frontend recebe atualizacao via Socket.IO

## Fluxo resumido de mensagem enviada

1. Atendente envia mensagem pelo painel
2. Frontend chama a API do backend
3. Backend valida usuario, tenant e permissao
4. Backend salva mensagem como pendente
5. Backend coloca envio na fila
6. Worker envia mensagem para a API da Meta
7. Backend atualiza status da mensagem
8. Frontend recebe atualizacao em tempo real

## Modulos principais

- Auth
- Tenants
- Users
- Roles
- Permissions
- WhatsApp Accounts
- Webhooks Meta
- Contacts
- Conversations
- Messages
- Chatbot
- Human Attendance
- Templates WhatsApp
- Queues
- Billing
- Audit Logs
- Reports
- Settings

## Documentacao tecnica

A documentacao do projeto sera organizada na pasta docs.

Arquivos planejados:

- docs/ARQUITETURA.md
- docs/BANCO_DADOS.md
- docs/API.md
- docs/SEGURANCA.md
- docs/WEBHOOKS_META.md
- docs/FRONTEND.md
- docs/BACKEND.md
- docs/DEPLOY.md

## Estrutura atual

saas-whatsapp-meta/
  README.md
  MANIFESTO.md
  00_CONTROLE.md
  docs/
  scripts/
  logs/
  backups/

## Estrategia multi-tenant

A estrategia inicial sera usar tenant_id nas tabelas principais.

Cada registro de negocio devera pertencer a um tenant.

Regras obrigatorias:

- Toda consulta deve respeitar o tenant atual
- Nenhum usuario pode acessar dados de outro tenant
- Tokens sensiveis devem ser criptografados
- Acoes relevantes devem gerar logs de auditoria
- Permissoes devem ser verificadas no backend

## Seguranca inicial

Medidas obrigatorias:

- JWT com expiracao curta
- Refresh token seguro
- Hash de senha com bcrypt ou Argon2
- RBAC por perfil e permissao
- Rate limit por IP, usuario e tenant
- CORS restrito
- HTTPS obrigatorio em producao
- Segredos fora do codigo
- Tokens da Meta criptografados
- Logs de auditoria
- Backup automatico do banco

## Fases do projeto

### Fase 1

Base do SaaS:

- Estrutura Docker
- Backend base
- Frontend base
- Banco PostgreSQL
- Redis
- Autenticacao
- Tenants
- Usuarios
- Permissoes basicas

### Fase 2

Integracao WhatsApp:

- Cadastro de conta WhatsApp
- Webhook Meta
- Recebimento de mensagens
- Envio de mensagens
- Status de mensagens
- Historico de conversas

### Fase 3

Atendimento:

- Tela de conversas
- Chat em tempo real
- Atribuicao de atendente
- Transferencia
- Filtros
- Notas internas

### Fase 4

Chatbot:

- Mensagem de boas-vindas
- Menu inicial
- Fluxos simples
- Palavras-chave
- Horario de atendimento
- Transferencia para humano

### Fase 5

SaaS comercial:

- Planos
- Limites
- Cobranca
- Relatorios
- Auditoria avancada
- Painel administrativo

## Status atual

Ambiente de documentacao preparado.

README principal criado na Etapa 02.
DOC

echo "Atualizando 00_CONTROLE.md..."

cat > "${BASE_DIR}/00_CONTROLE.md" <<'DOC'
# Controle do Projeto

Projeto: SaaS de Chatbot WhatsApp com API Oficial da Meta

Este arquivo registra o controle das etapas de criacao da documentacao e estrutura inicial.

## Etapas

- [x] Etapa 01 - Preparacao do ambiente de documentacao
- [x] Etapa 02 - Criacao do README principal
- [ ] Etapa 03 - Documentacao de arquitetura
- [ ] Etapa 04 - Documentacao do banco de dados
- [ ] Etapa 05 - Documentacao da API
- [ ] Etapa 06 - Documentacao de seguranca
- [ ] Etapa 07 - Documentacao de webhooks da Meta
- [ ] Etapa 08 - Documentacao do frontend
- [ ] Etapa 09 - Documentacao do backend
- [ ] Etapa 10 - Documentacao de deploy
- [ ] Etapa 11 - Manifesto final e validacao

## Ultima etapa executada

Etapa 02 - Criacao do README principal.

## Proxima etapa sugerida

Etapa 03 - Criar docs/ARQUITETURA.md com a arquitetura oficial do SaaS.
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

## Proxima etapa

- Etapa 03 - Documentacao de arquitetura
DOC

echo "Validando arquivos obrigatorios..."

test -f "${BASE_DIR}/README.md"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"
test -d "${DOCS_DIR}"
test -d "${SCRIPTS_DIR}"
test -d "${LOGS_DIR}"
test -d "${BACKUPS_DIR}"

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

if grep -n "[*]" "${BASE_DIR}/README.md" "${BASE_DIR}/00_CONTROLE.md" "${BASE_DIR}/MANIFESTO.md"; then
  echo "ERRO: caractere proibido encontrado nos arquivos gerados."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 02
Acao: Criacao do README principal
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos alterados:
- README.md
- 00_CONTROLE.md
- MANIFESTO.md
Backups:
- backups/README_${STAMP}.md
- backups/00_CONTROLE_${STAMP}.md
- backups/MANIFESTO_${STAMP}.md
Status: Concluido
DOC

echo ""
echo "== Etapa 02 concluida com sucesso =="
echo ""
echo "Arquivos principais:"
find "${BASE_DIR}" -maxdepth 2 -type f | sort
echo ""
echo "Resumo do README:"
sed -n '1,80p' "${BASE_DIR}/README.md"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 03 - Criar docs/ARQUITETURA.md"
