#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_08.log"

echo "== Etapa 08: Documentacao do frontend =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

if [ -f "${DOCS_DIR}/FRONTEND.md" ]; then
  cp "${DOCS_DIR}/FRONTEND.md" "${BACKUPS_DIR}/FRONTEND_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/00_CONTROLE.md" ]; then
  cp "${BASE_DIR}/00_CONTROLE.md" "${BACKUPS_DIR}/00_CONTROLE_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/MANIFESTO.md" ]; then
  cp "${BASE_DIR}/MANIFESTO.md" "${BACKUPS_DIR}/MANIFESTO_${STAMP}.md"
fi

echo "Gerando docs/FRONTEND.md..."

cat > "${DOCS_DIR}/FRONTEND.md" <<'DOC'
# Frontend

## Visao geral

Este documento define a arquitetura inicial do frontend do SaaS de Chatbot WhatsApp com API Oficial da Meta.

O frontend sera responsavel pelo painel web usado por administradores, gestores e atendentes.

A stack definida para o frontend sera:

- React
- TypeScript
- Vite
- Tailwind CSS
- shadcn/ui
- React Router
- TanStack Query
- Zustand
- React Hook Form
- Zod
- Socket.IO Client

## Objetivos do frontend

O frontend deve permitir:

- Login de usuarios
- Visualizacao de dashboard
- Atendimento em tempo real
- Listagem de conversas
- Chat com contatos
- Cadastro e edicao de contatos
- Gestao de usuarios
- Gestao de permissoes
- Configuracao de contas WhatsApp
- Configuracao de chatbot
- Consulta de relatorios
- Consulta de auditoria quando permitido
- Administracao do tenant

## Decisao tecnica

O frontend sera criado com React, TypeScript e Vite.

Motivos:

- React atende bem interfaces ricas
- TypeScript reduz erros de tipagem
- Vite oferece ambiente moderno de desenvolvimento
- Vite possui template react-ts
- Vite possui servidor de desenvolvimento com HMR
- Vite gera build de producao otimizado

## Estrutura sugerida

Estrutura inicial:

    apps/
      frontend/
        src/
          main.tsx
          App.tsx
          app/
          pages/
          components/
          services/
          stores/
          hooks/
          schemas/
          types/
          utils/
          assets/

Estrutura detalhada:

    src/
      app/
        routes.tsx
        providers.tsx
        query-client.ts
        socket-provider.tsx

      pages/
        login/
        dashboard/
        conversations/
        contacts/
        users/
        settings/
        chatbot/
        reports/
        billing/

      components/
        layout/
        ui/
        chat/
        forms/
        tables/
        feedback/
        navigation/

      services/
        api.ts
        auth.service.ts
        tenant.service.ts
        user.service.ts
        contact.service.ts
        conversation.service.ts
        message.service.ts
        whatsapp.service.ts
        chatbot.service.ts
        report.service.ts

      stores/
        auth.store.ts
        tenant.store.ts
        chat.store.ts
        ui.store.ts

      hooks/
        useAuth.ts
        useTenant.ts
        useSocket.ts
        usePermissions.ts
        useDebounce.ts

      schemas/
        auth.schema.ts
        user.schema.ts
        contact.schema.ts
        message.schema.ts
        whatsapp.schema.ts

      types/
        auth.types.ts
        tenant.types.ts
        user.types.ts
        contact.types.ts
        conversation.types.ts
        message.types.ts
        whatsapp.types.ts
        api.types.ts

      utils/
        format-date.ts
        format-phone.ts
        permissions.ts
        errors.ts

## Paginas principais

## Login

Responsabilidades:

- Capturar email e senha
- Validar formulario
- Chamar API de login
- Armazenar sessao com seguranca
- Redirecionar usuario autenticado

Regras:

- Nao exibir detalhes tecnicos de erro
- Nao salvar senha
- Mostrar estado de carregamento
- Bloquear multiplos envios simultaneos

## Dashboard

Responsabilidades:

- Exibir resumo operacional
- Exibir conversas abertas
- Exibir mensagens recentes
- Exibir indicadores basicos
- Exibir alertas importantes

Indicadores iniciais:

- Conversas abertas
- Conversas em atendimento humano
- Conversas no bot
- Mensagens recebidas
- Mensagens enviadas
- Falhas recentes de envio

## Conversas

Responsabilidades:

- Listar conversas
- Filtrar por status
- Filtrar por atendente
- Filtrar por departamento
- Pesquisar contato
- Abrir conversa
- Atualizar em tempo real

Estados da conversa:

- open
- pending
- bot
- human
- resolved
- closed

## Chat

Responsabilidades:

- Exibir mensagens da conversa
- Enviar mensagem de texto
- Exibir status de mensagem
- Exibir mensagens recebidas em tempo real
- Permitir atribuicao de atendente
- Permitir fechamento de conversa
- Exibir dados do contato

Regras:

- Envio deve ser bloqueado sem permissao
- Mensagem pendente deve aparecer imediatamente
- Falhas devem ser exibidas de forma clara
- Chat deve manter rolagem adequada
- Eventos em tempo real devem respeitar tenant e permissao

## Contatos

Responsabilidades:

- Listar contatos
- Criar contato
- Editar contato
- Consultar historico
- Pesquisar por nome ou telefone

Campos iniciais:

- nome
- telefone
- email
- documento
- observacoes

## Usuarios

Responsabilidades:

- Listar usuarios
- Criar usuario
- Editar usuario
- Desativar usuario
- Associar papeis

Regras:

- Somente usuarios com permissao podem gerenciar usuarios
- Usuario nao pode elevar permissao indevidamente
- Alteracoes devem ser registradas no backend

## Configuracoes

Responsabilidades:

- Configurar dados do tenant
- Configurar horario de atendimento
- Configurar chatbot ativo ou inativo
- Configurar departamento padrao
- Configurar fechamento automatico

## WhatsApp Accounts

Responsabilidades:

- Listar contas WhatsApp
- Cadastrar conta
- Editar dados da conta
- Ver status
- Ocultar tokens sensiveis

Regras:

- Token da Meta nunca deve ser exibido apos salvo
- Campos sensiveis devem usar input protegido
- Apenas usuarios autorizados podem acessar

## Chatbot

Responsabilidades:

- Listar fluxos
- Criar fluxo
- Editar fluxo
- Ativar fluxo
- Desativar fluxo
- Definir gatilhos

Fluxos iniciais:

- boas-vindas
- palavra-chave
- fora de horario
- fallback
- transferencia para humano

## Relatorios

Responsabilidades:

- Exibir dados consolidados
- Filtrar por periodo
- Filtrar por atendente
- Filtrar por status
- Exportacao futura

## Autenticacao no frontend

O frontend deve consumir a API usando access_token.

Regras:

- Enviar Authorization Bearer em rotas protegidas
- Renovar sessao com refresh_token
- Redirecionar para login quando sessao expirar
- Limpar estado local no logout
- Nao armazenar dados sensiveis desnecessarios
- Validar permissao antes de exibir acoes

## Controle de permissoes

O frontend deve usar permissoes para melhorar a experiencia, mas a seguranca real fica no backend.

Regras:

- Ocultar botoes sem permissao
- Ocultar menus sem permissao
- Bloquear telas sem permissao
- Tratar erro 403 vindo do backend
- Nunca confiar apenas no frontend para seguranca

Exemplos de permissoes:

    conversations.read
    conversations.reply
    conversations.assign
    contacts.create
    contacts.update
    users.manage
    settings.update
    reports.view

## Estado global

Ferramenta definida:

- Zustand

Estados globais sugeridos:

- auth
- tenant
- chat
- ui
- notifications

O estado global deve guardar apenas o necessario.

Evitar guardar:

- tokens sensiveis sem necessidade
- payloads grandes
- mensagens antigas demais
- dados duplicados da API

## Dados remotos

Ferramenta definida:

- TanStack Query

Responsabilidades:

- Buscar dados da API
- Cachear listagens
- Invalidar consultas apos mutacoes
- Controlar loading
- Controlar erro
- Refazer consultas quando necessario

Usos principais:

- contatos
- conversas
- mensagens
- usuarios
- configuracoes
- relatorios

## Formularios

Ferramentas definidas:

- React Hook Form
- Zod

Regras:

- Todo formulario deve ter schema de validacao
- Mensagens de erro devem ser claras
- Campos obrigatorios devem ser indicados
- Estados de loading devem bloquear duplo envio
- Erros da API devem ser exibidos com seguranca

## Cliente HTTP

Arquivo sugerido:

    src/services/api.ts

Responsabilidades:

- Configurar baseURL
- Anexar Authorization
- Tratar erro 401
- Tratar erro 403
- Tratar erro 422
- Tratar erro 500
- Padronizar leitura de resposta

Variaveis esperadas:

    VITE_API_URL
    VITE_SOCKET_URL

## Tempo real

Ferramenta definida:

- Socket.IO Client

Eventos recebidos:

    message.created
    message.updated
    conversation.created
    conversation.updated
    conversation.assigned
    contact.updated
    notification.created

Regras:

- Conectar somente usuario autenticado
- Enviar token no handshake
- Recriar conexao apos renovacao de sessao quando necessario
- Escutar apenas eventos autorizados
- Atualizar cache do TanStack Query quando evento chegar
- Evitar duplicar mensagem no estado local

## Layout

Estrutura visual sugerida:

- Sidebar lateral
- Topbar
- Area principal
- Painel de notificacoes
- Modal padronizado
- Toasts para feedback
- Tema claro inicialmente
- Tema escuro futuro

Telas de atendimento devem priorizar:

- Velocidade
- Clareza
- Mensagens em tempo real
- Filtros rapidos
- Visibilidade do status da conversa

## Componentes principais

Componentes sugeridos:

    AppLayout
    AuthLayout
    Sidebar
    Topbar
    PageHeader
    DataTable
    EmptyState
    LoadingState
    ErrorState
    ConfirmDialog
    ChatList
    ChatWindow
    MessageBubble
    MessageComposer
    ContactPanel
    StatusBadge
    PermissionGuard

## Tratamento de erros

Erros devem ser exibidos de forma amigavel.

Regras:

- Erro 401 redireciona para login
- Erro 403 exibe mensagem de falta de permissao
- Erro 422 exibe erros de validacao
- Erro 500 exibe mensagem generica
- Detalhes tecnicos nao devem aparecer ao usuario final
- Logs tecnicos devem ficar no backend

## Padrao de rotas

Rotas sugeridas:

    /login
    /app
    /app/dashboard
    /app/conversations
    /app/contacts
    /app/users
    /app/settings
    /app/whatsapp
    /app/chatbot
    /app/reports
    /app/billing

Rotas protegidas:

- Todas dentro de /app

Rotas publicas:

- /login
- recuperacao de senha futura

## Variaveis de ambiente

Arquivo exemplo:

    .env.example

Variaveis sugeridas:

    VITE_API_URL=http://localhost:3000/api/v1
    VITE_SOCKET_URL=http://localhost:3000/realtime
    VITE_APP_NAME=SaaS WhatsApp Meta

Regras:

- Variaveis do Vite usadas no frontend devem iniciar com VITE_
- Nao colocar secrets reais no frontend
- Nao colocar token da Meta no frontend
- Nao colocar JWT fixo em arquivo de ambiente

## Build

Comandos esperados futuramente:

    npm run dev
    npm run build
    npm run preview
    npm run lint
    npm run typecheck

Observacao:

Os comandos reais serao definidos quando a estrutura do frontend for criada.

## Qualidade

Regras recomendadas:

- Usar TypeScript estrito quando possivel
- Evitar any sem justificativa
- Separar componentes grandes
- Criar componentes reutilizaveis
- Usar nomes claros
- Evitar regra de negocio complexa no frontend
- Centralizar acesso a API
- Centralizar tipos compartilhados quando possivel

## Acessibilidade

Boas praticas:

- Usar labels em formularios
- Permitir navegacao por teclado
- Usar contraste adequado
- Informar estados de erro
- Usar textos claros em botoes
- Evitar depender apenas de cor para status

## Responsividade

O frontend deve funcionar bem em:

- Desktop
- Notebook
- Tablet quando possivel

A tela de chat deve priorizar desktop inicialmente.

Versao mobile pode ser evolucao futura.

## Integracao com backend

O frontend nao deve acessar diretamente a API da Meta.

Fluxo correto:

    Frontend
      |
      v
    Backend
      |
      v
    Meta Cloud API

Regras:

- Token da Meta fica apenas no backend
- Frontend chama API interna
- Backend valida tenant e permissao
- Backend enfileira processamento quando necessario

## Checklist da etapa frontend

Itens definidos:

- Stack frontend
- Estrutura de pastas
- Paginas principais
- Autenticacao
- Controle de permissoes
- Estado global
- Dados remotos
- Formularios
- Cliente HTTP
- Tempo real
- Layout
- Rotas
- Variaveis de ambiente
- Build
- Qualidade
- Acessibilidade
- Responsividade

## Decisao final desta etapa

O frontend sera implementado com:

- React
- TypeScript
- Vite
- Tailwind CSS
- shadcn/ui
- React Router
- TanStack Query
- Zustand
- React Hook Form
- Zod
- Socket.IO Client

O frontend sera responsavel pela experiencia do usuario, mas toda seguranca critica sera validada no backend.
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
- [ ] Etapa 09 - Documentacao do backend
- [ ] Etapa 10 - Documentacao de deploy
- [ ] Etapa 11 - Manifesto final e validacao

## Ultima etapa executada

Etapa 08 - Documentacao do frontend.

## Proxima etapa sugerida

Etapa 09 - Criar docs/BACKEND.md com a documentacao do backend.
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

## Proxima etapa

- Etapa 09 - Documentacao do backend

## Arquivos atualizados na Etapa 08

- docs/FRONTEND.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_08.log
DOC

echo "Validando arquivos obrigatorios..."

test -f "${DOCS_DIR}/FRONTEND.md"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"
test -d "${DOCS_DIR}"
test -d "${SCRIPTS_DIR}"
test -d "${LOGS_DIR}"
test -d "${BACKUPS_DIR}"

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" "${DOCS_DIR}/FRONTEND.md" "${BASE_DIR}/00_CONTROLE.md" "${BASE_DIR}/MANIFESTO.md"; then
  echo "ERRO: caractere proibido encontrado nos arquivos gerados."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 08
Acao: Documentacao do frontend
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos alterados:
- docs/FRONTEND.md
- 00_CONTROLE.md
- MANIFESTO.md
Backups:
- backups/FRONTEND_${STAMP}.md
- backups/00_CONTROLE_${STAMP}.md
- backups/MANIFESTO_${STAMP}.md
Status: Concluido
DOC

echo ""
echo "== Etapa 08 concluida com sucesso =="
echo ""
echo "Arquivos principais:"
find "${BASE_DIR}" -maxdepth 2 -type f | sort
echo ""
echo "Resumo de docs/FRONTEND.md:"
sed -n '1,180p' "${DOCS_DIR}/FRONTEND.md"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 09 - Criar docs/BACKEND.md"
