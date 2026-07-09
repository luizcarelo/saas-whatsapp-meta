# Arquitetura do Sistema

## Visao geral

Este documento define a arquitetura inicial do SaaS de Chatbot WhatsApp com API Oficial da Meta.

O sistema sera construido como uma plataforma multi-tenant, onde cada empresa cliente tera dados, usuarios, permissoes, contatos, conversas e configuracoes isoladas logicamente.

A arquitetura inicial seguira o modelo de modular monolith com workers separados.

Essa decisao permite iniciar com menor complexidade, sem perder organizacao interna, mantendo o caminho aberto para evoluir partes do sistema para servicos independentes no futuro.

## Objetivos da arquitetura

A arquitetura deve permitir:

- Receber eventos de webhook da Meta com seguranca
- Processar mensagens sem travar a requisicao principal
- Salvar historico completo de atendimento
- Atualizar o painel em tempo real
- Isolar dados por tenant
- Controlar usuarios, papeis e permissoes
- Processar filas de envio e recebimento
- Suportar chatbot e atendimento humano
- Manter logs de auditoria
- Facilitar deploy com Docker
- Permitir crescimento gradual do SaaS

## Decisao arquitetural inicial

O projeto sera iniciado como modular monolith com workers separados.

Nesse modelo, o backend principal contem os modulos de negocio em uma unica aplicacao, mas com separacao clara entre responsabilidades.

Os workers rodam como processos separados para executar tarefas assincronas, como processamento de webhook, envio de mensagens e execucao de fluxos de chatbot.

## Componentes principais

### Frontend

Responsavel pela interface do usuario.

Stack definida:

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

Responsabilidades:

- Login
- Dashboard
- Tela de conversas
- Chat em tempo real
- Cadastro de contatos
- Gestao de usuarios
- Gestao de permissoes
- Configuracoes do WhatsApp
- Relatorios
- Administracao do tenant

### Backend principal

Responsavel pelas APIs, regras de negocio e seguranca.

Stack definida:

- NestJS
- Fastify
- TypeScript
- JWT
- RBAC
- Prisma ou TypeORM
- Socket.IO
- Cliente HTTP para Meta

Responsabilidades:

- Autenticacao
- Controle de tenants
- Usuarios e permissoes
- Validacao de entrada
- APIs REST
- Recebimento de webhooks
- Comunicacao com workers
- Publicacao de eventos em tempo real
- Registro de auditoria

### Worker

Responsavel por tarefas assincronas.

Responsabilidades:

- Processar eventos recebidos da Meta
- Criar ou atualizar contatos
- Criar ou atualizar conversas
- Salvar mensagens
- Enviar mensagens para a Cloud API da Meta
- Atualizar status de mensagens
- Executar regras de chatbot
- Reprocessar falhas com tentativa controlada

### PostgreSQL

Banco principal do sistema.

Responsabilidades:

- Tenants
- Usuarios
- Permissoes
- Contatos
- Conversas
- Mensagens
- Contas WhatsApp
- Eventos de webhook
- Logs de auditoria
- Planos e cobranca futura

### Redis

Componente de alta velocidade para cache, filas e coordenacao.

Responsabilidades:

- Filas com BullMQ
- Cache temporario
- Rate limit
- Estado temporario
- Controle de jobs
- Publicacao interna de eventos

### BullMQ

Camada de filas baseada em Redis.

Filas iniciais:

- webhook-events
- process-incoming-message
- send-whatsapp-message
- update-message-status
- chatbot-flow
- notifications

### Socket.IO

Responsavel por comunicacao em tempo real entre backend e frontend.

Eventos iniciais:

- message.created
- message.updated
- conversation.created
- conversation.updated
- conversation.assigned
- contact.updated
- notification.created

### Nginx ou Traefik

Responsavel por proxy reverso, SSL e roteamento externo.

Responsabilidades:

- Terminar HTTPS
- Encaminhar trafego para backend
- Encaminhar frontend
- Permitir webhook publico seguro
- Aplicar regras basicas de proxy

## Desenho logico

Fluxo geral:

    Usuario WhatsApp
        |
        v
    WhatsApp Cloud API da Meta
        |
        v
    Webhook HTTPS
        |
        v
    Backend NestJS
        |
        +-- PostgreSQL
        |
        +-- Redis
        |
        +-- BullMQ
        |
        +-- Workers
        |
        +-- Socket.IO
        |
        v
    Frontend React

## Fluxo de mensagem recebida

1. Cliente envia mensagem pelo WhatsApp
2. Meta envia evento para o webhook HTTPS do backend
3. Backend valida a requisicao
4. Backend registra o payload bruto em webhook_events
5. Backend responde rapidamente para a Meta
6. Backend adiciona job na fila webhook-events
7. Worker processa o evento
8. Worker identifica tenant pelo phone_number_id
9. Worker localiza a conta WhatsApp do tenant
10. Worker localiza ou cria contato
11. Worker localiza ou cria conversa
12. Worker salva a mensagem
13. Worker executa regra de chatbot, se aplicavel
14. Backend publica evento via Socket.IO
15. Frontend atualiza a tela do chat

## Fluxo de mensagem enviada

1. Atendente escreve mensagem no frontend
2. Frontend envia requisicao para o backend
3. Backend valida autenticacao
4. Backend valida tenant
5. Backend valida permissao
6. Backend salva mensagem com status pendente
7. Backend cria job na fila send-whatsapp-message
8. Worker processa o job
9. Worker envia mensagem para a API da Meta
10. Worker salva o identificador retornado pela Meta
11. Worker atualiza status da mensagem
12. Backend publica evento via Socket.IO
13. Frontend atualiza a conversa em tempo real

## Multi-tenant

A estrategia inicial sera usar tenant_id nas tabelas principais.

Toda entidade de negocio deve possuir relacionamento com tenant.

Entidades com tenant_id:

- users
- roles
- permissions
- contacts
- conversations
- messages
- whatsapp_accounts
- webhook_events
- audit_logs
- settings
- plans vinculados ao tenant

Regras obrigatorias:

- Toda consulta deve filtrar pelo tenant atual
- Toda criacao deve gravar tenant_id
- Toda atualizacao deve validar tenant_id
- Toda exclusao deve validar tenant_id
- Nenhum usuario pode acessar dados de outro tenant
- Logs devem registrar tenant_id
- Workers devem resolver tenant antes de processar dados

## Modulos do backend

Modulos iniciais:

- auth
- tenants
- users
- roles
- permissions
- whatsapp
- webhooks
- contacts
- conversations
- messages
- chatbot
- queues
- billing
- audit
- reports
- settings

## Separacao de responsabilidades

### Auth

Responsavel por login, refresh token, recuperacao de senha e controle de sessao.

### Tenants

Responsavel por empresas clientes, status, plano e configuracoes globais.

### Users

Responsavel por usuarios internos de cada tenant.

### Roles e Permissions

Responsavel por papeis e permissoes.

### WhatsApp

Responsavel por contas WhatsApp, tokens, WABA, phone_number_id e envio de mensagens.

### Webhooks

Responsavel por receber eventos da Meta e registrar payload bruto.

### Contacts

Responsavel por contatos finais.

### Conversations

Responsavel por atendimentos e estado da conversa.

### Messages

Responsavel pelo historico de mensagens.

### Chatbot

Responsavel por automacoes e fluxos.

### Queues

Responsavel pela integracao com BullMQ e Redis.

### Audit

Responsavel por logs de auditoria.

## Seguranca arquitetural

Medidas obrigatorias:

- HTTPS em producao
- Validacao de payload no backend
- JWT com expiracao curta
- Refresh token seguro
- Senhas com hash forte
- RBAC no backend
- tenant_id obrigatorio
- Rate limit por IP, usuario e tenant
- CORS restrito
- Tokens da Meta criptografados
- Secrets fora do codigo
- Logs de auditoria
- Backup automatico do banco
- Validacao de permissoes em toda acao sensivel

## Estrategia de processamento assincrono

O webhook nao deve executar processamento pesado.

O endpoint de webhook deve:

1. Receber a requisicao
2. Validar assinatura ou token de verificacao conforme configuracao
3. Salvar payload bruto
4. Responder rapidamente
5. Enviar job para fila

O worker deve:

1. Ler job da fila
2. Identificar tenant
3. Processar evento
4. Salvar dados finais
5. Emitir eventos para frontend
6. Registrar falhas
7. Reprocessar quando permitido

## Estrategia de resiliencia

O sistema deve prever:

- Retry com limite
- Backoff em falhas externas
- Registro de erro em jobs
- Idempotencia para webhooks repetidos
- Controle de duplicidade por provider_message_id
- Monitoramento de filas
- Logs estruturados
- Backups automaticos
- Separacao de ambientes

## Evolucao futura

A arquitetura deve permitir separar componentes em servicos independentes no futuro.

Possiveis separacoes futuras:

- servico de autenticacao
- servico de mensagens
- servico de chatbot
- servico de billing
- servico de relatorios
- servico de notificacoes

A separacao so deve ocorrer quando houver necessidade real de escala, isolamento ou manutencao.

## Decisao final desta etapa

A arquitetura oficial inicial do projeto sera:

- Modular monolith
- Workers separados
- PostgreSQL como banco principal
- Redis com BullMQ para filas
- Socket.IO para tempo real
- React com Vite no frontend
- NestJS com Fastify no backend
- Docker Compose no inicio
- tenant_id como estrategia multi-tenant inicial
