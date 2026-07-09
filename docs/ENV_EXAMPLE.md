# Env Example

## Visao geral

Este documento registra a criacao do arquivo .env.example do projeto.

A Etapa 16 criou um modelo de variaveis de ambiente usando portas alternativas para evitar conflito com outros containers Docker existentes no host.

## Objetivo

O arquivo .env.example serve como referencia para criar o arquivo .env real.

O arquivo .env real nao deve ser versionado.

## Portas alternativas definidas

Portas externas do host:

- APP_PORT 3300
- FRONTEND_PORT 5573
- PROXY_HTTP_PORT 8180
- POSTGRES_PORT 55432
- REDIS_PORT 56379

Portas internas dos containers continuam as portas padrao de cada servico.

## Motivo das portas alternativas

Foi identificado que outro container Docker ja usa a porta 6379 no host.

Para evitar conflito, o Redis deste projeto usara a porta externa 56379 apontando para a porta interna 6379 do container.

## Arquivo criado

Arquivo principal:

- .env.example

## Grupos de variaveis

Grupos definidos:

- Ambiente
- Aplicacao backend
- Aplicacao frontend
- Proxy
- PostgreSQL
- Redis
- Autenticacao
- Criptografia
- Meta WhatsApp

## Como usar futuramente

Copiar o modelo para .env:

    cp .env.example .env

Depois editar o arquivo .env com valores reais quando necessario.

## Regras de seguranca

Regras obrigatorias:

- Nao versionar .env real
- Nao usar valores change_me em producao
- Usar secrets fortes em producao
- Separar secrets por ambiente
- Nao colocar token real da Meta no frontend
- Nao expor JWT_SECRET no frontend
- Nao expor ENCRYPTION_KEY no frontend

## Observacoes

Nesta etapa apenas o arquivo .env.example foi criado.

Nenhum secret real foi inserido.

A validacao do ambiente sera feita na Etapa 17.

## Decisao final desta etapa

O projeto agora possui um arquivo .env.example inicial com portas alternativas, alinhado com Docker Compose, backend, frontend, PostgreSQL, Redis e integracao futura com Meta WhatsApp.
