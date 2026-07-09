#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_24.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_24_seed_env_safe.log"
SEED_LOG="${LOGS_DIR}/setup_24_prisma_seed.log"
VALIDATION_LOG="${LOGS_DIR}/setup_24_seed_validation.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_24_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_24_backend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_24_backend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_24_backend_docker_up.log"
LOCAL_HEALTH_LOG="${LOGS_DIR}/setup_24_health_local.log"
DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_24_health_domain.log"
CREDENTIALS_LOG="${LOGS_DIR}/setup_24_seed_credentials.log"
DOC_FILE="${DOCS_DIR}/SEED_INICIAL.md"

LOCAL_HEALTH_URL="http://127.0.0.1:3300/api/v1/health"
DOMAIN_HEALTH_URL="https://bot.lhsolucao.com.br/api/v1/health"
LOCAL_DATABASE_URL="postgresql://saas_user:saas_password@localhost:55432/saas_whatsapp"

echo "== Correcao Etapa 24: seed sem source do env =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/prisma/seed.js" \
  "${BASE_DIR}/.env" \
  "${BASE_DIR}/.env.example" \
  "${DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Validando ferramentas..."

if ! command -v node >/dev/null 2>&1; then
  echo "ERRO: node nao encontrado."
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "ERRO: npm nao encontrado."
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERRO: docker nao encontrado."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Validando Postgres..."

docker compose up -d postgres redis

sleep 5

POSTGRES_STATUS="$(docker inspect -f '{{.State.Health.Status}}' saas_whatsapp_postgres 2>/dev/null || echo unknown)"

if [ "${POSTGRES_STATUS}" != "healthy" ]; then
  echo "ERRO: postgres nao esta healthy."
  docker compose logs --tail=120 postgres
  exit 1
fi

echo "Garantindo variaveis de seed no .env e .env.example..."

if [ ! -f "${BASE_DIR}/.env" ]; then
  cp "${BASE_DIR}/.env.example" "${BASE_DIR}/.env"
fi

set_env_value() {
  key="$1"
  value="$2"
  file="$3"

  if grep -q "^${key}=" "${file}"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "${file}"
  els*
    printf "%s=%s\n" "${key}" "${*alue}" >> "${file}"
  fi
}

get_en*_value() {
  key="$1"
  file="$2"
*  grep "^${key}=" "${file}" | head*-n 1 | cut -d '=' -f 2- || true
}
*set_env_value "SEED_TENANT_NAME" "*H Solucao" "${BASE_DIR}/.env.examp*e"
set_env_value "SEED_TENANT_DOCU*ENT" "" "${BASE_DIR}/.env.example"*set_env_value "SEED_ADMIN_NAME" "A*ministrador" "${BASE_DIR}/.env.exa*ple"
set_env_value "SEED_ADMIN_EMA*L" "admin@lhsolucao.com.br" "${BAS*_DIR}/.env.example"
set_env_value *SEED_ADMIN_PASSWORD" "change_me_ad*in_password" "${BASE_DIR}/.env.exa*ple"

CURRENT_PASSWORD="$(get_env_*alue "SEED_ADMIN_PASSWORD" "${BASE*DIR}/.env")"

if [ -z "${CURRENT_PASSWORD}" ] || [ "${CURRENT_PASSWORD}" = "change_me_admin_password" ];*then
  GENERATED_PASSWORD="$(node *e "console.log(require('crypto').r*ndomBytes(12).toString('hex'))")"
*lse
  GENERATED_PASSWORD="${CURREN*_PASSWORD}"
fi

set_env_value "SEE*_TENANT_NAME" "LH Solucao" "${BASE*DIR}/.env"
set_env_value "SEED_TEN*NT_DOCUMENT" "" "${BASE_DIR}/.env"*set_env_value "SEED_ADMIN_NAME" "A*ministrador" "${BASE_DIR}/.env"
se*_env_value "SEED_ADMIN_EMAIL" "adm*n@lhsolucao.com.br" "${BASE_DIR}/.*nv"
set_env_value "SEED_ADMIN_PASS*ORD" "${GENERATED_PASSWORD}" "${BA*E_DIR}/.env"

cat > "${CREDENTIALS*LOG}" <<DOC
Etapa: 24
Usuario admi* inicial
Email: admin@lhsolucao.co*.br
Senha: ${GENERATED_PASSWORD}
O*servacao: altere esta senha quando*o modulo de autenticacao estiver i*plementado.
DOC

echo "Recriando p*isma/seed.js..."

cat > "${BACKEND*DIR}/prisma/seed.js" <<'DOC'
const*{ PrismaClient } = require('@prism*/client');
const bcrypt = require(*bcryptjs');

const prisma = new Pr*smaClient();

const tenantName = p*ocess.env.SEED_TENANT_NAME || 'LH *olucao';
const tenantDocument = pr*cess.env.SEED_TENANT_DOCUMENT || n*ll;
const adminName = process.env.*EED_ADMIN_NAME || 'Administrador';*const adminEmail = process.env.SEE*_ADMIN_EMAIL || 'admin@lhsolucao.c*m.br';
const adminPassword = proce*s.env.SEED_ADMIN_PASSWORD || '';

*onst permissions = [
  ['tenants.read', 'tenants'],
  ['tenants.update', 'tenants'],
  ['users.read', 'users'],
  ['users.create', 'users'],
  ['users.update', 'users'],
  ['users.delete', 'users'],
  ['roles.read', 'roles'],
  ['roles.create', 'roles'],
  ['roles.update', 'roles'],
  ['permissions.read', 'permissions'],
  ['contacts.read', 'contacts'],
  ['contacts.create', 'contacts'],
  ['contacts.update', 'contacts'],
  ['contacts.delete', 'contacts'],
  ['conversations.read', 'conversations'],
  ['conversations.reply', 'conversations'],
  ['conversations.assign', 'conversations'],
  ['conversations.close', 'conversations'],
  ['messages.read', 'messages'],
  ['messages.send', 'messages'],
  ['whatsapp_accounts.read', 'whatsapp_accounts'],
  ['whatsapp_accounts.create', 'whatsapp_accounts'],
  ['whatsapp_accounts.update', 'whatsapp_accounts'],
  ['whatsapp_accounts.delete', 'whatsapp_accounts'],
  ['chatbot.read', 'chatbot'],
  ['chatbot.create', 'chatbot'],
  ['chatbot.update', 'chatbot'],
  ['settings.read', 'settings'],
  ['settings.update', 'settings'],
  ['reports.view', 'reports'],
  ['audit_logs.read', 'audit_logs'],
  ['billing.view', 'billing']
];

const rol*Permissions = {
  owner: permissio*s.map((item) => item[0]),
  admin:*permissions.map((item) => item[0])*filter((key) => key !== 'billing.v*ew'),
  manager: [
    'contacts.read',
    'contacts.create',
    'contacts.update',
    'conversations.read',
    'conversations.reply',
    'conversations.assign',
    'conversations.close',
    'messages.read',
    'messages.send',
    'chatbot.read',
    'reports.view'
  ],*  agent: [
    'contacts.read',
    'contacts.update',
    'conversations.read',
    'conversations.reply',
    'messages.read',
    'messages.send'
  ],
  viewer: [
    'contacts.read',
    'conversations.read',
    'messages.read',
    'reports.view'
  ]
};

async function mai*() {
  if (!adminPassword || admin*assword.length < 8) {
    throw ne* Error('SEED_ADMIN_PASSWORD ausent* ou insegura');
  }

  const tenan* = await prisma.tenant.upsert({
  * where: {
      id: '00000000-0000*0000-0000-000000000001'
    },
   *update: {
      name: tenantName,
*     document: tenantDocument,
   *  status: 'active'
    },
    crea*e: {
      id: '00000000-0000-0000*0000-000000000001',
      name: te*antName,
      document: tenantDoc*ment,
      status: 'active'
    }*  });

  for (const item of permis*ions) {
    const key = item[0];
 *  const moduleName = item[1];

   *await prisma.permission.upsert({
 *    where: {
        key
      },
*     update: {
        module: mod*leName
      },
      create: {
  *     key,
        module: moduleNa*e,
        description: key
      *
    });
  }

  const createdRoles*= {};

  for (const roleName of Ob*ect.keys(rolePermissions)) {
    c*nst role = await prisma.role.upser*({
      where: {
        tenantId*name: {
          tenantId: tenant*id,
          name: roleName
     *  }
      },
      update: {
     *  isSystem: true
      },
      cr*ate: {
        tenantId: tenant.id*
        name: roleName,
        d*scription: roleName,
        isSys*em: true
      }
    });

    crea*edRoles[roleName] = role;

    for*(const permissionKey of rolePermis*ions[roleName]) {
      const perm*ssion = await prisma.permission.fi*dUnique({
        where: {
       *  key: permissionKey
        }
   *  });

      if (permission) {
   *    await prisma.rolePermission.up*ert({
          where: {
         *  roleId_permissionId: {
         *    roleId: role.id,
             *permissionId: permission.id
      *     }
          },
          upda*e: {},
          create: {
       *    roleId: role.id,
            p*rmissionId: permission.id
        * }
        });
      }
    }
  }

* const passwordHash = await bcrypt*hash(adminPassword, 12);

  const *dmin = await prisma.user.upsert({
*   where: {
      tenantId_email: *
        tenantId: tenant.id,
    *   email: adminEmail
      }
    }*
    update: {
      name: adminNa*e,
      passwordHash,
      statu*: 'active'
    },
    create: {
  *   tenantId: tenant.id,
      name* adminName,
      email: adminEmai*,
      passwordHash,
      status* 'active'
    }
  });

  await pri*ma.userRole.upsert({
    where: {
*     userId_roleId: {
        user*d: admin.id,
        roleId: creat*dRoles.owner.id
      }
    },
   *update: {},
    create: {
      te*antId: tenant.id,
      userId: ad*in.id,
      roleId: createdRoles.*wner.id
    }
  });

  await prism*.auditLog.create({
    data: {
   *  tenantId: tenant.id,
      userI*: admin.id,
      action: 'seed_in*tial_data',
      entity: 'system'*
      metadata: {
        tenantN*me,
        adminEmail
      }
   *}
  });

  const result = {
    te*antId: tenant.id,
    tenantName: *enant.name,
    adminId: admin.id,*    adminEmail: admin.email,
    r*les: Object.keys(createdRoles).len*th,
    permissions: permissions.l*ngth
  };

  console.log(JSON.stri*gify(result, null, 2));
}

main()
* .catch((error) => {
    console.e*ror(error);
    process.exit(1);
 *})
  .finally(async () => {
    aw*it prisma.$disconnect();
  });
DOC*
echo "Validando arquivos sem HTML*indevido..."

if grep -R "<a href"*\
  "${BACKEND_DIR}/prisma/seed.js* \
  "${BASE_DIR}/.env" \
  "${BAS*_DIR}/.env.example"
then
  echo "E*RO: HTML indevido encontrado."
  e*it 1
fi

echo "Executando seed ini*ial sem source do .env..."

SEED_TENANT_NAME="$(get_env_value "SEED_TENANT_NAME" "${BASE_DIR}/.env")" \
SEED_TENANT_DOCUMENT="$(get_env_value "SEED_TENANT_DOCUMENT" "${BASE_DIR}/.env")" \
SEED_ADMIN_NAME="$(get_env_value "SEED_ADMIN_NAME" "${BASE_DIR}/.env")" \
SEED_ADMIN_EMAIL="$(get_env_value "SEED_ADMIN_EMAIL" "${BASE_DIR}/.env")" \
SEED_ADMIN_PASSWORD="$(get_env_value "SEED_ADMIN_PASSWORD" "${BASE_DIR}/.env")" \
DATABASE_URL="${LOCAL_DATABASE_URL}" \
node "${BACKEND_DIR}/prisma/seed.js" 2>&1 | tee "${SEED_LOG}"

echo "Validando dados criados no banco..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -c "select count(*) as tenants from tenants;" 2>&1 | tee "${VALIDATION_LOG}"
docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -c "select count(*) as users from users;" 2>&1 | tee -a "${VALIDATION_LOG}"
docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -c "select count(*) as roles from roles;" 2>&1 | tee -a "${VALIDATION_LOG}"
docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -c "select count(*) as permissions from permissions;" 2>&1 | tee -a "${VALIDATION_LOG}"
docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -c "select count(*) as role_permissions from role_permissions;" 2>&1 | tee -a "${VALIDATION_LOG}"
docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -c "select count(*) as user_roles from user_roles;" 2>&1 | tee -a "${VALIDATION_LOG}"

echo "Rodando typecheck do backend..."

cd "${BACKEND_DIR}"
npm run typecheck 2>&1 | tee "${TYPECHECK_LOG}"

echo "Rodando build do backend..."

npm run build 2>&1 | tee "${BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando backend..."

docker compose build backend 2>&1 | tee "${DOCKER_BUILD_LOG}"

echo "Subindo backend..."

docker compose up -d backend 2>&1 | tee "${DOCKER_UP_LOG}"

sleep 10

echo "Testando health local..."

LOCAL_STATUS="$(curl -s -o "${LOCAL_HEALTH_LOG}" -w "%{http_code}" --max-time 20 "${LOCAL_HEALTH_URL}" || true)"

if [ "${LOCAL_STATUS}" != "200" ]; then
  echo "ERRO: health local nao respondeu 200."
  docker compose logs --tail=160 backend
  exit 1
fi

if ! grep -q '"database":"ok"' "${LOCAL_HEALTH_LOG}"; then
  echo "ERRO: health local nao indicou database ok."
  cat "${LOCAL_HEALTH_LOG}"
  exit 1
fi

echo "Testando health dominio..."

DOMAIN_STATUS="$(curl -L -s -o "${DOMAIN_HEALTH_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_HEALTH_URL}" || true)"

if [ "${DOMAIN_STATUS}" != "200" ]; then
  echo "ERRO: health dominio nao respondeu 200."
  docker compose logs --tail=160 backend
  docker compose logs --tail=120 proxy
  exit 1
fi

if ! grep -q '"database":"ok"' "${DOMAIN_HEALTH_LOG}"; then
  echo "ERRO: health dominio nao indicou database ok."
  cat "${DOMAIN_HEALTH_LOG}"
  exit 1
fi

echo "Gerando documentacao da Etapa 24..."

cat > "${DOC_FILE}" <<'DOC'
# Seed Inicial

## Visao geral

Este documento registra a criacao do seed inicial do sistema.

## Resultado

Status:

    concluido

## Correcao aplicada

A execucao do seed foi ajustada para nao usar source do arquivo .env.

Isso evita erro quando valores do .env possuem espacos.

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
- logs/fix_24_seed_env_safe.log
- logs/setup_24.log

## Observacoes de seguranca

A senha inicial foi gravada apenas no arquivo local de log de credenciais.

Quando o modulo de autenticacao estiver pronto, a senha deve ser alterada.

## Proxima etapa sugerida

Etapa 25:

    Criar modulo Auth inicial com login real
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

## Fase 04 - Backend real inicial

- [x] Etapa 21 - Health, configuracao e database base
- [x] Etapa 22 - ORM e conexao real com PostgreSQL
- [x] Etapa 23 - Schema inicial do banco com Prisma
- [x] Etapa 24 - Seed inicial de tenant, admin, roles e permissoes
- [ ] Etapa 25 - Auth inicial com login real

## Ultima etapa executada

Etapa 24 - Seed inicial de tenant, usuario admin, roles e permissoes.

## Proxima etapa sugerida

Etapa 25 - Criar modulo Auth inicial com login real.
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

Backend real inicial iniciado.

Prisma configurado com conexao real ao PostgreSQL.

Schema inicial do banco criado.

Seed inicial criado.

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
- docs/BACKEND_HEALTH_CONFIG_DATABASE.md
- docs/BACKEND_PRISMA_POSTGRES.md
- docs/PRISMA_SCHEMA_INICIAL.md
- docs/SEED_INICIAL.md

## Etapas concluidas

- Etapa 01 ate Etapa 24 concluidas

## Proxima etapa

- Etapa 25 - Auth inicial com login real
DOC

echo "Validando ausencia de caractere proibido nos arquivos finais..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos finais."
  exit 1
fi

cat > "${FIX_LOG_FILE}" <<DOC
Etapa: 24
Acao: Correcao seed sem source do env
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health local status: ${LOCAL_STATUS}
Health dominio status: ${DOMAIN_STATUS}
Status: Concluido
DOC

cat > "${LOG_FILE}" <<DOC
Etapa: 24
Acao: Seed inicial de tenant, admin, roles e permissoes
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health local status: ${LOCAL_STATUS}
Health dominio status: ${DOMAIN_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 24 corrigida e concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Credenciais iniciais em:"
echo "${CREDENTIALS_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 25 - Criar modulo Auth inicial com login real"
