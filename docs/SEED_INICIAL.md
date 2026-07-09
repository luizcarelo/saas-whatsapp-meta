# Seed Inicial

## Visao geral

Este documento registra a criacao do seed inicial do sistema.

## Resultado

Status:

    concluido

## Dados criados

Dados:

- tenant inicial
- usuario admin inicial
- roles iniciais
- permissoes iniciais
- vinculos entre roles e permissoes
- vinculo entre usuario admin e role owner
- audit log inicial

## Tenant inicial

Tenant:

- LH Solucao

## Usuario admin inicial

Usuario:

- admin@lhsolucao.com.br

## Roles iniciais

Roles:

- owner
- admin
- manager
- agent
- viewer

## Validacoes executadas

Validacoes:

- execucao de prisma seed
- contagem de tenants
- contagem de users
- contagem de roles
- contagem de permissions
- contagem de role_permissions
- contagem de user_roles
- npm run typecheck
- npm run build
- docker compose build backend
- docker compose up backend
- health local com database ok
- health dominio com database ok

## Arquivos criados ou alterados

Arquivos:

- apps/backend/prisma/seed.js
- .env.example
- .env
- docs/SEED_INICIAL.md
- 00_CONTROLE.md
- MANIFESTO.md

## Logs gerados

Logs:

- logs/setup_24_prisma_seed.log
- logs/setup_24_seed_validation.log
- logs/setup_24_backend_typecheck.log
- logs/setup_24_backend_build.log
- logs/setup_24_backend_docker_build.log
- logs/setup_24_backend_docker_up.log
- logs/setup_24_health_local.log
- logs/setup_24_health_domain.log
- logs/setup_24_seed_credentials.log
- logs/fix_24_seed_env_safe_v2.log
- logs/setup_24.log

## Observacoes de seguranca

A senha inicial foi gravada apenas no arquivo local de log de credenciais.

Quando o modulo de autenticacao estiver pronto, a senha deve ser alterada.

## Proxima etapa sugerida

Etapa 25:

    Criar modulo Auth inicial com login real
