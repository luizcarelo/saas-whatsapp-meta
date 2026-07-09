#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_06.log"

echo "== Etapa 06: Documentacao de seguranca =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

if [ -f "${DOCS_DIR}/SEGURANCA.md" ]; then
  cp "${DOCS_DIR}/SEGURANCA.md" "${BACKUPS_DIR}/SEGURANCA_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/00_CONTROLE.md" ]; then
  cp "${BASE_DIR}/00_CONTROLE.md" "${BACKUPS_DIR}/00_CONTROLE_${STAMP}.md"
fi

if [ -f "${BASE_DIR}/MANIFESTO.md" ]; then
  cp "${BASE_DIR}/MANIFESTO.md" "${BACKUPS_DIR}/MANIFESTO_${STAMP}.md"
fi

echo "Gerando docs/SEGURANCA.md..."

cat > "${DOCS_DIR}/SEGURANCA.md" <<'DOC'
# Seguranca do Sistema

## Visao geral

Este documento define as regras iniciais de seguranca do SaaS de Chatbot WhatsApp com API Oficial da Meta.

A seguranca deve ser considerada parte central da arquitetura, pois o sistema ira armazenar dados de empresas, usuarios, contatos, conversas, mensagens, tokens de integracao e logs de atendimento.

O sistema sera multi-tenant. Por isso, uma das regras mais importantes e impedir acesso indevido entre tenants.

## Objetivos de seguranca

A seguranca do sistema deve garantir:

- Isolamento de dados por tenant
- Autenticacao segura de usuarios
- Autorizacao por papeis e permissoes
- Protecao de tokens da Meta
- Protecao contra acesso indevido
- Protecao contra abuso de rotas publicas
- Registro de auditoria em acoes sensiveis
- Uso obrigatorio de HTTPS em producao
- Validacao de payloads recebidos
- Backup protegido
- Controle de erros sem vazamento de dados sensiveis

## Principios obrigatorios

Principios adotados:

- Nunca confiar em dados enviados pelo frontend
- Validar usuario em toda rota protegida
- Validar tenant em toda rota protegida
- Validar permissao em toda acao sensivel
- Nao expor tokens em respostas da API
- Nao registrar senhas ou tokens em logs
- Criptografar dados sensiveis
- Aplicar rate limit em rotas publicas
- Responder webhooks rapidamente
- Processar tarefas demoradas em filas
- Registrar auditoria em eventos importantes

## Autenticacao

A autenticacao inicial sera baseada em JWT.

Fluxo:

1. Usuario envia email e senha
2. Backend valida credenciais
3. Backend retorna access_token e refresh_token
4. Frontend usa access_token nas chamadas protegidas
5. Frontend usa refresh_token para renovar sessao
6. Logout invalida a sessao quando aplicavel

Regras:

- access_token deve ter expiracao curta
- refresh_token deve ter expiracao maior
- refresh_token deve ser armazenado com seguranca
- senha nunca deve ser salva em texto puro
- senha nunca deve ser registrada em log
- usuario inativo nao pode autenticar
- usuario bloqueado nao pode autenticar

## Senhas

Regras para senhas:

- Armazenar somente hash
- Usar bcrypt ou Argon2
- Nunca retornar password_hash na API
- Nunca registrar senha em log
- Aplicar politica minima de senha
- Permitir troca de senha
- Permitir recuperacao de senha com token temporario

Politica inicial sugerida:

- Minimo de 8 caracteres
- Exigir letras e numeros
- Bloquear senhas muito comuns
- Expirar token de recuperacao

## Autorizacao

A autorizacao sera baseada em RBAC.

RBAC significa controle de acesso por papeis.

Papeis iniciais:

- owner
- admin
- manager
- agent
- viewer

Formato de permissao:

    modulo.acao

Exemplos:

    conversations.read
    conversations.reply
    conversations.assign
    conversations.close
    contacts.create
    contacts.update
    users.manage
    settings.update
    reports.view
    audit_logs.read

Regras:

- Toda acao sensivel deve validar permissao
- Permissoes devem ser verificadas no backend
- O frontend pode ocultar botoes, mas nao substitui a validacao do backend
- Usuario sem permissao deve receber erro 403
- Atribuicoes de papeis devem gerar log de auditoria

## Multi-tenant

A seguranca multi-tenant e obrigatoria.

Regras:

- Toda entidade de negocio deve possuir tenant_id quando aplicavel
- Toda consulta deve filtrar pelo tenant atual
- Toda criacao deve gravar tenant_id
- Toda atualizacao deve validar tenant_id
- Toda exclusao deve validar tenant_id
- Workers devem resolver tenant antes de processar dados
- Eventos em tempo real devem ser enviados apenas ao tenant correto
- Logs de auditoria devem registrar tenant_id

Risco principal:

- Vazamento de dados entre tenants

Medidas obrigatorias:

- Guard de tenant no backend
- Repositorios ou services com filtro obrigatorio de tenant
- Testes para impedir acesso cruzado
- Validacao de tenant em workers
- Validacao de tenant no Socket.IO

## Tokens da Meta

Tokens da Meta sao dados sensiveis.

Regras:

- access_token da Meta deve ser criptografado
- access_token da Meta nao deve ser retornado em consultas comuns
- access_token da Meta nao deve aparecer em logs
- access_token da Meta deve ser lido apenas pelo servico responsavel
- Rotacao de token deve ser prevista
- Falhas de token devem ser registradas sem expor o token

Campos sensiveis:

    access_token_encrypted
    webhook_verify_token
    app_secret
    integration_secret

## Webhooks da Meta

O endpoint de webhook e publico e deve ser protegido.

Regras:

- Usar HTTPS em producao
- Validar token de verificacao no endpoint GET
- Validar payload recebido no endpoint POST
- Salvar payload bruto antes do processamento
- Nao executar processamento pesado na requisicao
- Enfileirar evento para worker
- Aplicar idempotencia
- Registrar falhas
- Retornar resposta rapida

Cuidados:

- Nao confiar em phone_number_id sem validar no banco
- Resolver tenant pela conta WhatsApp cadastrada
- Ignorar eventos desconhecidos com seguranca
- Evitar duplicidade por event_id ou provider_message_id

## API publica e API protegida

Rotas publicas iniciais:

- login
- refresh
- webhook GET da Meta
- webhook POST da Meta
- recuperacao de senha quando existir

Rotas protegidas:

- users
- tenants
- contacts
- conversations
- messages
- whatsapp accounts
- chatbot
- reports
- audit logs
- settings

Regras:

- Rotas protegidas exigem JWT
- Rotas protegidas exigem tenant valido
- Rotas protegidas exigem permissao quando aplicavel
- Rotas publicas devem ter rate limit
- Rotas publicas devem validar payload

## Rate limit

Rate limit deve proteger o sistema contra abuso.

Aplicar rate limit em:

- login
- refresh token
- recuperacao de senha
- webhook publico
- envio de mensagens
- rotas sensiveis de configuracao

Chaves sugeridas:

- IP
- usuario
- tenant
- rota
- phone_number_id quando aplicavel

Acoes ao exceder limite:

- Retornar 429
- Registrar evento de seguranca quando relevante
- Bloquear temporariamente origem suspeita quando necessario

## Validacao de entrada

Toda entrada deve ser validada.

Validar:

- body
- query params
- route params
- headers relevantes
- payload de webhook
- dados de Socket.IO

Ferramentas sugeridas:

- DTOs do NestJS
- class-validator
- Zod quando aplicavel
- Pipes de validacao

Regras:

- Rejeitar campos inesperados quando possivel
- Validar tipos
- Validar tamanhos maximos
- Validar formatos de email e telefone
- Normalizar telefone antes de salvar
- Sanitizar textos quando exibidos no frontend

## CORS

CORS deve ser restrito em producao.

Regras:

- Permitir somente dominios oficiais do frontend
- Nao permitir origem aberta em producao
- Separar configuracao por ambiente
- Registrar tentativa indevida quando necessario

## HTTPS

HTTPS e obrigatorio em producao.

Regras:

- Proxy reverso deve terminar SSL
- Webhook da Meta deve usar HTTPS
- Cookies seguros devem usar secure quando aplicavel
- Redirecionar HTTP para HTTPS
- Certificados devem ser renovados automaticamente

## Logs

Logs sao importantes, mas nao podem vazar dados sensiveis.

Nao registrar:

- senhas
- refresh tokens
- access tokens
- tokens da Meta
- segredos de webhook
- headers de autorizacao completos

Registrar:

- usuario
- tenant
- rota
- acao
- status
- tempo de resposta
- ip
- user agent
- erro resumido

## Auditoria

Acoes sensiveis devem gerar audit_logs.

Eventos auditaveis:

- login
- logout
- falha de login
- criacao de usuario
- alteracao de usuario
- desativacao de usuario
- alteracao de papel
- envio de mensagem
- fechamento de conversa
- atribuicao de conversa
- cadastro de conta WhatsApp
- alteracao de configuracao
- acesso a relatorios sensiveis

Auditoria deve responder:

- Quem fez
- Em qual tenant
- Qual acao
- Qual entidade
- Quando
- De qual IP
- Com quais metadados

## Socket.IO

Conexoes em tempo real devem ser autenticadas.

Regras:

- Validar JWT no handshake
- Associar conexao ao usuario
- Associar conexao ao tenant
- Enviar eventos apenas do tenant correto
- Validar permissao antes de emitir eventos sensiveis
- Desconectar usuario com token invalido
- Controlar reconexao

Eventos sensiveis:

- message.created
- conversation.updated
- conversation.assigned
- notification.created

## Filas e workers

Workers tambem precisam aplicar seguranca.

Regras:

- Jobs devem conter tenant_id quando possivel
- Workers devem validar tenant no banco
- Workers devem validar conta WhatsApp
- Workers nao devem registrar tokens
- Jobs devem ser idempotentes
- Falhas devem ser registradas com mensagem segura
- Tentativas devem ter limite
- Reprocessamento nao pode duplicar mensagens

## Banco de dados

Regras de seguranca do banco:

- Usuario do banco com permissao minima necessaria
- Senha forte para banco
- Banco nao exposto publicamente
- Backups protegidos
- Conexao segura em producao quando aplicavel
- Migracoes versionadas
- Proibir alteracao manual em producao
- Indices para tenant_id
- Integridade referencial quando possivel

## Backups

Backups devem ser tratados como dados sensiveis.

Regras:

- Backup automatico do PostgreSQL
- Retencao minima definida por ambiente
- Backup antes de migracoes importantes
- Teste periodico de restauracao
- Armazenamento protegido
- Acesso restrito
- Log de execucao de backup

## Ambientes

Ambientes previstos:

- development
- staging
- production

Regras:

- Nunca usar secrets de producao em desenvolvimento
- Bancos devem ser separados por ambiente
- Tokens devem ser separados por ambiente
- Logs de producao devem ser controlados
- Debug detalhado deve ficar desativado em producao
- CORS de producao deve ser restrito

## Variaveis de ambiente

Secrets devem ficar fora do codigo.

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
    META_APP_SECRET
    META_WEBHOOK_VERIFY_TOKEN

Regras:

- Nao versionar arquivo .env real
- Criar apenas .env.example sem secrets reais
- Rotacionar secrets quando houver suspeita de vazamento
- Usar secrets manager em producao quando possivel

## Respostas de erro

Erros devem ser seguros.

Regras:

- Nao retornar stack trace em producao
- Nao retornar SQL bruto
- Nao retornar token
- Nao informar detalhes excessivos em login
- Usar codigos padronizados
- Registrar erro tecnico no log interno

Exemplo seguro:

    {
      "success": false,
      "error": {
        "code": "UNAUTHORIZED",
        "message": "Credenciais invalidas"
      }
    }

## Checklist inicial de seguranca

Itens obrigatorios antes de producao:

- HTTPS configurado
- JWT configurado
- Refresh token configurado
- Hash de senha configurado
- RBAC ativo
- tenant_id validado
- CORS restrito
- Rate limit ativo
- Tokens da Meta criptografados
- Logs sem dados sensiveis
- Auditoria ativa
- Backup automatico ativo
- Webhook validado
- Socket.IO autenticado
- Variaveis de ambiente protegidas

## Decisao final desta etapa

A seguranca inicial do sistema sera baseada em:

- JWT para autenticacao
- Refresh token para renovacao de sessao
- RBAC para autorizacao
- tenant_id para isolamento multi-tenant
- Criptografia para tokens sensiveis
- HTTPS obrigatorio em producao
- Rate limit em rotas publicas e sensiveis
- Auditoria para acoes relevantes
- Validacao de entrada em todas as rotas
- Logs sem dados sensiveis
- Workers com validacao de tenant
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
- [ ] Etapa 07 - Documentacao de webhooks da Meta
- [ ] Etapa 08 - Documentacao do frontend
- [ ] Etapa 09 - Documentacao do backend
- [ ] Etapa 10 - Documentacao de deploy
- [ ] Etapa 11 - Manifesto final e validacao

## Ultima etapa executada

Etapa 06 - Documentacao de seguranca.

## Proxima etapa sugerida

Etapa 07 - Criar docs/WEBHOOKS_META.md com a documentacao dos webhooks da Meta.
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

## Proxima etapa

- Etapa 07 - Documentacao de webhooks da Meta

## Arquivos atualizados na Etapa 06

- docs/SEGURANCA.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_06.log
DOC

echo "Validando arquivos obrigatorios..."

test -f "${DOCS_DIR}/SEGURANCA.md"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"
test -d "${DOCS_DIR}"
test -d "${SCRIPTS_DIR}"
test -d "${LOGS_DIR}"
test -d "${BACKUPS_DIR}"

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" "${DOCS_DIR}/SEGURANCA.md" "${BASE_DIR}/00_CONTROLE.md" "${BASE_DIR}/MANIFESTO.md"; then
  echo "ERRO: caractere proibido encontrado nos arquivos gerados."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 06
Acao: Documentacao de seguranca
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos alterados:
- docs/SEGURANCA.md
- 00_CONTROLE.md
- MANIFESTO.md
Backups:
- backups/SEGURANCA_${STAMP}.md
- backups/00_CONTROLE_${STAMP}.md
- backups/MANIFESTO_${STAMP}.md
Status: Concluido
DOC

echo ""
echo "== Etapa 06 concluida com sucesso =="
echo ""
echo "Arquivos principais:"
find "${BASE_DIR}" -maxdepth 2 -type f | sort
echo ""
echo "Resumo de docs/SEGURANCA.md:"
sed -n '1,160p' "${DOCS_DIR}/SEGURANCA.md"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 07 - Criar docs/WEBHOOKS_META.md"
