# Estrutura Real do Projeto

## Visao geral

Este documento registra a estrutura inicial real do monorepo do SaaS de Chatbot WhatsApp com API Oficial da Meta.

A estrutura foi criada para separar frontend, backend, worker, pacotes compartilhados e infraestrutura.

## Objetivo

A Etapa 12 prepara o projeto para receber codigo real nas proximas etapas.

Nesta etapa nao foi implementada regra de negocio.

Foram criadas apenas pastas, marcadores e documentacao da estrutura.

## Estrutura criada

Estrutura principal:

    apps
    packages
    infra
    docs
    scripts
    logs
    backups

## Apps

A pasta apps concentra as aplicacoes principais.

## apps/backend

Responsavel pela API principal.

Conteudo inicial:

    apps/backend/src
    apps/backend/test

Responsabilidades futuras:

- API REST
- Autenticacao
- Tenants
- Usuarios
- Permissoes
- Webhooks
- WhatsApp
- Contatos
- Conversas
- Mensagens
- Socket.IO
- Filas

## apps/frontend

Responsavel pelo painel web.

Conteudo inicial:

    apps/frontend/src
    apps/frontend/public

Responsabilidades futuras:

- React
- TypeScript
- Vite
- Login
- Dashboard
- Chat
- Contatos
- Usuarios
- Configuracoes
- Relatorios

## apps/worker

Responsavel por processos assincronos.

Conteudo inicial:

    apps/worker/src
    apps/worker/test

Responsabilidades futuras:

- Processar webhooks
- Enviar mensagens
- Atualizar status
- Executar chatbot
- Processar notificacoes
- Reprocessar falhas

## Packages

A pasta packages concentra codigo compartilhado.

## packages/shared

Responsavel por utilitarios compartilhados.

Uso futuro:

- constantes
- helpers
- validacoes comuns
- funcoes compartilhadas

## packages/types

Responsavel por tipos compartilhados.

Uso futuro:

- tipos de API
- tipos de mensagens
- tipos de tenant
- tipos de usuario
- contratos comuns

## packages/config

Responsavel por configuracoes compartilhadas.

Uso futuro:

- nomes de filas
- constantes de ambiente
- mapas de status
- configuracoes comuns

## Infra

A pasta infra concentra arquivos de infraestrutura.

## infra/docker

Uso futuro:

- Dockerfile do backend
- Dockerfile do frontend
- Dockerfile do worker

## infra/nginx

Uso futuro:

- configuracao do proxy reverso
- configuracao de rotas
- headers basicos
- SSL em producao quando aplicavel

## infra/postgres

Uso futuro:

- scripts de inicializacao
- configuracoes auxiliares
- scripts de banco quando necessario

## infra/redis

Uso futuro:

- configuracoes auxiliares do Redis

## infra/scripts

Uso futuro:

- backup do PostgreSQL
- restore do PostgreSQL
- validacoes de deploy
- scripts auxiliares

## Marcadores

Foram criados arquivos .gitkeep nas pastas vazias.

O objetivo e permitir que a estrutura seja preservada quando o projeto for versionado.

## Proximas etapas sugeridas

Etapa 13:

    Criar arquivos base do backend

Etapa 14:

    Criar arquivos base do frontend

Etapa 15:

    Criar Docker Compose inicial

Etapa 16:

    Criar arquivo .env.example

Etapa 17:

    Validar ambiente inicial

## Decisao final desta etapa

A estrutura real inicial do projeto foi criada como monorepo, separando:

- apps
- packages
- infra
- docs
- scripts
- logs
- backups
