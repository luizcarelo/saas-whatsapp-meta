#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
BACKEND_DIR="${BASE_DIR}/apps/backend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_23.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_23_prisma_schema_relations.log"
PRISMA_GENERATE_LOG="${LOGS_DIR}/setup_23_prisma_generate.log"
PRISMA_MIGRATE_LOG="${LOGS_DIR}/setup_23_prisma_migrate.log"
TYPECHECK_LOG="${LOGS_DIR}/setup_23_backend_typecheck.log"
BUILD_LOG="${LOGS_DIR}/setup_23_backend_build.log"
TABLES_LOG="${LOGS_DIR}/setup_23_database_tables.log"
LOCAL_HEALTH_LOG="${LOGS_DIR}/setup_23_health_local.log"
DOMAIN_HEALTH_LOG="${LOGS_DIR}/setup_23_health_domain.log"
DOC_FILE="${DOCS_DIR}/PRISMA_SCHEMA_INICIAL.md"

LOCAL_HEALTH_URL="http://127.0.0.1:3300/api/v1/health"
DOMAIN_HEALTH_URL="https://bot.lhsolucao.com.br/api/v1/health"
LOCAL_DATABASE_URL="postgresql://saas_user:saas_password@localhost:55432/saas_whatsapp"

echo "== Correcao Etapa 23: relacoes reversas do Tenant =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${BACKEND_DIR}/prisma/schema.prisma" \
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

echo "Regravando schema.prisma com relacoes reversas corrigidas..."

cat > "${BACKEND_DIR}/prisma/schema.prisma" <<'DOC'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

enum TenantStatus {
  active
  inactive
  suspended
  trial
  canceled
}

enum UserStatus {
  active
  inactive
  blocked
  invited
}

enum WhatsappAccountStatus {
  active
  inactive
  pending
  disconnected
  error
}

enum ConversationStatus {
  open
  pending
  bot
  human
  resolved
  closed
}

enum MessageDirection {
  inbound
  outbound
}

enum MessageType {
  text
  image
  audio
  video
  document
  location
  contact
  interactive
  template
  unknown
}

enum MessageStatus {
  pending
  sent
  delivered
  read
  failed
  received
}

enum WebhookEventStatus {
  received
  queued
  processed
  failed
  ignored
}

enum ChatbotFlowStatus {
  active
  inactive
  draft
}

enum ChatbotTriggerType {
  welcome
  keyword
  schedule
  fallback
  manual
}

enum ChatbotStepType {
  message
  question
  menu
  action
  transfer
  end
}

enum PlanStatus {
  active
  inactive
  archived
}

enum SubscriptionStatus {
  trial
  active
  past_due
  canceled
  expired
}

model Tenant {
  id            String          @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  name          String
  document      String?
  email         String?
  phone         String?
  status        TenantStatus    @default(trial)
  planId        String?         @map("plan_id") @db.Uuid
  createdAt     DateTime        @default(now()) @map("created_at") @db.Timestamptz
  updatedAt     DateTime        @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt     DateTime?       @map("deleted_at") @db.Timestamptz

  users         User[]
  roles         Role[]
  userRoles     UserRole[]
  contacts      Contact[]
  departments   Department[]
  conversations Conversation[]
  conversationAssignments ConversationAssignment[]
  messages      Message[]
  messageStatuses MessageStatusHistory[]
  whatsappAccounts WhatsappAccount[]
  webhookEvents WebhookEvent[]
  chatbotFlows  ChatbotFlow[]
  chatbotSteps  ChatbotStep[]
  auditLogs     AuditLog[]
  settings      Setting[]
  subscriptions Subscription[]

  @@index([status])
  @@index([document])
  @@map("tenants")
}

model User {
  id           String      @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId     String      @map("tenant_id") @db.Uuid
  name         String
  email        String
  passwordHash String?     @map("password_hash")
  status       UserStatus  @default(invited)
  lastLoginAt  DateTime?   @map("last_login_at") @db.Timestamptz
  createdAt    DateTime    @default(now()) @map("created_at") @db.Timestamptz
  updatedAt    DateTime    @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt    DateTime?   @map("deleted_at") @db.Timestamptz

  tenant       Tenant      @relation(fields: [tenantId], references: [id])
  userRoles    UserRole[]
  assignedConversations Conversation[] @relation("ConversationAssignedUser")
  assignmentTargets ConversationAssignment[] @relation("AssignmentToUser")
  assignmentSources ConversationAssignment[] @relation("AssignmentFromUser")
  assignmentCreators ConversationAssignment[] @relation("AssignmentCreatedBy")
  auditLogs    AuditLog[]

  @@unique([tenantId, email])
  @@index([tenantId])
  @@index([email])
  @@map("users")
}

model Role {
  id          String    @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId    String    @map("tenant_id") @db.Uuid
  name        String
  description String?
  isSystem    Boolean   @default(false) @map("is_system")
  createdAt   DateTime  @default(now()) @map("created_at") @db.Timestamptz
  updatedAt   DateTime  @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt   DateTime? @map("deleted_at") @db.Timestamptz

  tenant      Tenant    @relation(fields: [tenantId], references: [id])
  rolePermissions RolePermission[]
  userRoles   UserRole[]

  @@unique([tenantId, name])
  @@index([tenantId])
  @@map("roles")
}

model Permission {
  id          String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  key         String   @unique
  description String?
  module      String
  createdAt   DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt   DateTime @updatedAt @map("updated_at") @db.Timestamptz

  rolePermissions RolePermission[]

  @@index([module])
  @@map("permissions")
}

model RolePermission {
  id           String     @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  roleId       String     @map("role_id") @db.Uuid
  permissionId String     @map("permission_id") @db.Uuid
  createdAt    DateTime   @default(now()) @map("created_at") @db.Timestamptz

  role         Role       @relation(fields: [roleId], references: [id])
  permission   Permission @relation(fields: [permissionId], references: [id])

  @@unique([roleId, permissionId])
  @@index([roleId])
  @@index([permissionId])
  @@map("role_permissions")
}

model UserRole {
  id        String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId  String   @map("tenant_id") @db.Uuid
  userId    String   @map("user_id") @db.Uuid
  roleId    String   @map("role_id") @db.Uuid
  createdAt DateTime @default(now()) @map("created_at") @db.Timestamptz

  tenant    Tenant   @relation(fields: [tenantId], references: [id])
  user      User     @relation(fields: [userId], references: [id])
  role      Role     @relation(fields: [roleId], references: [id])

  @@unique([userId, roleId])
  @@index([tenantId])
  @@index([userId])
  @@index([roleId])
  @@map("user_roles")
}

model WhatsappAccount {
  id                 String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId           String   @map("tenant_id") @db.Uuid
  wabaId             String   @map("waba_id")
  phoneNumberId      String   @map("phone_number_id")
  displayPhoneNumber String   @map("display_phone_number")
  verifiedName       String?  @map("verified_name")
  accessTokenEncrypted String @map("access_token_encrypted")
  tokenExpiresAt     DateTime? @map("token_expires_at") @db.Timestamptz
  status             WhatsappAccountStatus @default(pending)
  createdAt          DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt          DateTime @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt          DateTime? @map("deleted_at") @db.Timestamptz

  tenant             Tenant   @relation(fields: [tenantId], references: [id])
  conversations      Conversation[]
  messages           Message[]
  webhookEvents      WebhookEvent[]

  @@unique([tenantId, phoneNumberId])
  @@index([tenantId])
  @@index([phoneNumberId])
  @@index([wabaId])
  @@map("whatsapp_accounts")
}

model Contact {
  id        String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId  String   @map("tenant_id") @db.Uuid
  name      String?
  phone     String
  waId      String?  @map("wa_id")
  email     String?
  document  String?
  metadata  Json?
  createdAt DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt DateTime @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt DateTime? @map("deleted_at") @db.Timestamptz

  tenant    Tenant   @relation(fields: [tenantId], references: [id])
  conversations Conversation[]
  messages  Message[]

  @@unique([tenantId, phone])
  @@index([tenantId])
  @@index([phone])
  @@index([waId])
  @@map("contacts")
}

model Department {
  id          String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId    String   @map("tenant_id") @db.Uuid
  name        String
  description String?
  status      String   @default("active")
  createdAt   DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt   DateTime @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt   DateTime? @map("deleted_at") @db.Timestamptz

  tenant      Tenant   @relation(fields: [tenantId], references: [id])
  conversations Conversation[]

  @@unique([tenantId, name])
  @@index([tenantId])
  @@map("departments")
}

model Conversation {
  id                String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId          String   @map("tenant_id") @db.Uuid
  contactId         String   @map("contact_id") @db.Uuid
  whatsappAccountId String   @map("whatsapp_account_id") @db.Uuid
  assignedUserId    String?  @map("assigned_user_id") @db.Uuid
  departmentId      String?  @map("department_id") @db.Uuid
  status            ConversationStatus @default(open)
  channel           String   @default("whatsapp")
  lastMessageAt     DateTime? @map("last_message_at") @db.Timestamptz
  closedAt          DateTime? @map("closed_at") @db.Timestamptz
  createdAt         DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt         DateTime @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt         DateTime? @map("deleted_at") @db.Timestamptz

  tenant            Tenant   @relation(fields: [tenantId], references: [id])
  contact           Contact  @relation(fields: [contactId], references: [id])
  whatsappAccount   WhatsappAccount @relation(fields: [whatsappAccountId], references: [id])
  assignedUser      User?    @relation("ConversationAssignedUser", fields: [assignedUserId], references: [id])
  department        Department? @relation(fields: [departmentId], references: [id])
  messages          Message[]
  assignments       ConversationAssignment[]

  @@index([tenantId])
  @@index([contactId])
  @@index([assignedUserId])
  @@index([status])
  @@index([lastMessageAt])
  @@map("conversations")
}

model ConversationAssignment {
  id               String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId          String   @map("tenant_id") @db.Uuid
  conversationId    String   @map("conversation_id") @db.Uuid
  fromUserId        String?  @map("from_user_id") @db.Uuid
  toUserId          String?  @map("to_user_id") @db.Uuid
  assignedByUserId  String?  @map("assigned_by_user_id") @db.Uuid
  reason            String?
  createdAt         DateTime @default(now()) @map("created_at") @db.Timestamptz

  tenant            Tenant   @relation(fields: [tenantId], references: [id])
  conversation      Conversation @relation(fields: [conversationId], references: [id])
  fromUser          User?    @relation("AssignmentFromUser", fields: [fromUserId], references: [id])
  toUser            User?    @relation("AssignmentToUser", fields: [toUserId], references: [id])
  assignedByUser    User?    @relation("AssignmentCreatedBy", fields: [assignedByUserId], references: [id])

  @@index([tenantId])
  @@index([conversationId])
  @@index([toUserId])
  @@map("conversation_assignments")
}

model Message {
  id                String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId          String   @map("tenant_id") @db.Uuid
  conversationId    String   @map("conversation_id") @db.Uuid
  contactId         String   @map("contact_id") @db.Uuid
  whatsappAccountId String   @map("whatsapp_account_id") @db.Uuid
  providerMessageId String?  @map("provider_message_id")
  direction         MessageDirection
  type              MessageType @default(text)
  body              String?
  mediaUrl          String?  @map("media_url")
  mediaMimeType     String?  @map("media_mime_type")
  mediaFileName     String?  @map("media_file_name")
  status            MessageStatus @default(pending)
  errorMessage      String?  @map("error_message")
  metadata          Json?
  sentAt            DateTime? @map("sent_at") @db.Timestamptz
  deliveredAt       DateTime? @map("delivered_at") @db.Timestamptz
  readAt            DateTime? @map("read_at") @db.Timestamptz
  createdAt         DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt         DateTime @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt         DateTime? @map("deleted_at") @db.Timestamptz

  tenant            Tenant   @relation(fields: [tenantId], references: [id])
  conversation      Conversation @relation(fields: [conversationId], references: [id])
  contact           Contact  @relation(fields: [contactId], references: [id])
  whatsappAccount   WhatsappAccount @relation(fields: [whatsappAccountId], references: [id])
  statuses          MessageStatusHistory[]

  @@index([tenantId])
  @@index([conversationId])
  @@index([contactId])
  @@index([providerMessageId])
  @@index([createdAt])
  @@index([tenantId, conversationId, createdAt])
  @@map("messages")
}

model MessageStatusHistory {
  id                String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId          String   @map("tenant_id") @db.Uuid
  messageId         String   @map("message_id") @db.Uuid
  providerMessageId String?  @map("provider_message_id")
  status            MessageStatus
  payload           Json?
  createdAt         DateTime @default(now()) @map("created_at") @db.Timestamptz

  tenant            Tenant   @relation(fields: [tenantId], references: [id])
  message           Message  @relation(fields: [messageId], references: [id])

  @@index([tenantId])
  @@index([messageId])
  @@index([providerMessageId])
  @@map("message_statuses")
}

model WebhookEvent {
  id                String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId          String?  @map("tenant_id") @db.Uuid
  whatsappAccountId String?  @map("whatsapp_account_id") @db.Uuid
  provider          String   @default("meta_whatsapp")
  eventType         String?  @map("event_type")
  eventId           String?  @map("event_id")
  payload           Json
  status            WebhookEventStatus @default(received)
  processedAt       DateTime? @map("processed_at") @db.Timestamptz
  errorMessage      String?  @map("error_message")
  createdAt         DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt         DateTime @updatedAt @map("updated_at") @db.Timestamptz

  tenant            Tenant?  @relation(fields: [tenantId], references: [id])
  whatsappAccount   WhatsappAccount? @relation(fields: [whatsappAccountId], references: [id])

  @@index([tenantId])
  @@index([eventId])
  @@index([status])
  @@index([createdAt])
  @@map("webhook_events")
}

model ChatbotFlow {
  id           String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId     String   @map("tenant_id") @db.Uuid
  name         String
  description  String?
  status       ChatbotFlowStatus @default(draft)
  triggerType  ChatbotTriggerType @map("trigger_type")
  triggerValue String?  @map("trigger_value")
  createdAt    DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt    DateTime @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt    DateTime? @map("deleted_at") @db.Timestamptz

  tenant       Tenant   @relation(fields: [tenantId], references: [id])
  steps        ChatbotStep[]

  @@index([tenantId])
  @@index([status])
  @@index([triggerType, triggerValue])
  @@map("chatbot_flows")
}

model ChatbotStep {
  id           String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId     String   @map("tenant_id") @db.Uuid
  flowId       String   @map("flow_id") @db.Uuid
  parentStepId String?  @map("parent_step_id") @db.Uuid
  stepOrder    Int      @default(0) @map("step_order")
  type         ChatbotStepType
  content      Json?
  conditions   Json?
  nextStepId   String?  @map("next_step_id") @db.Uuid
  createdAt    DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt    DateTime @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt    DateTime? @map("deleted_at") @db.Timestamptz

  tenant       Tenant   @relation(fields: [tenantId], references: [id])
  flow         ChatbotFlow @relation(fields: [flowId], references: [id])

  @@index([tenantId])
  @@index([flowId])
  @@index([parentStepId])
  @@map("chatbot_steps")
}

model Plan {
  id                 String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  name               String
  description        String?
  price              Decimal  @default(0)
  currency           String   @default("BRL")
  maxUsers           Int?     @map("max_users")
  maxWhatsappAccounts Int?    @map("max_whatsapp_accounts")
  maxMonthlyMessages Int?     @map("max_monthly_messages")
  status             PlanStatus @default(active)
  createdAt          DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt          DateTime @updatedAt @map("updated_at") @db.Timestamptz
  deletedAt          DateTime? @map("deleted_at") @db.Timestamptz

  subscriptions      Subscription[]

  @@index([status])
  @@map("plans")
}

model Subscription {
  id         String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId   String   @map("tenant_id") @db.Uuid
  planId     String   @map("plan_id") @db.Uuid
  status     SubscriptionStatus @default(trial)
  startedAt  DateTime? @map("started_at") @db.Timestamptz
  expiresAt  DateTime? @map("expires_at") @db.Timestamptz
  canceledAt DateTime? @map("canceled_at") @db.Timestamptz
  createdAt  DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt  DateTime @updatedAt @map("updated_at") @db.Timestamptz

  tenant     Tenant   @relation(fields: [tenantId], references: [id])
  plan       Plan     @relation(fields: [planId], references: [id])

  @@index([tenantId])
  @@index([planId])
  @@index([status])
  @@map("subscriptions")
}

model Setting {
  id        String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId  String   @map("tenant_id") @db.Uuid
  key       String
  value     Json?
  createdAt DateTime @default(now()) @map("created_at") @db.Timestamptz
  updatedAt DateTime @updatedAt @map("updated_at") @db.Timestamptz

  tenant    Tenant   @relation(fields: [tenantId], references: [id])

  @@unique([tenantId, key])
  @@index([tenantId])
  @@map("settings")
}

model AuditLog {
  id        String   @id @default(dbgenerated("gen_random_uuid()")) @db.Uuid
  tenantId  String   @map("tenant_id") @db.Uuid
  userId    String?  @map("user_id") @db.Uuid
  action    String
  entity    String?
  entityId  String?  @map("entity_id")
  metadata  Json?
  ipAddress String?  @map("ip_address")
  userAgent String?  @map("user_agent")
  createdAt DateTime @default(now()) @map("created_at") @db.Timestamptz

  tenant    Tenant   @relation(fields: [tenantId], references: [id])
  user      User?    @relation(fields: [userId], references: [id])

  @@index([tenantId])
  @@index([userId])
  @@index([action])
  @@index([createdAt])
  @@map("audit_logs")
}
DOC

echo "Validando schema sem HTML indevido..."

if grep -n "<a href" "${BACKEND_DIR}/prisma/schema.prisma"; then
  echo "ERRO: HTML indevido encontrado no schema."
  exit 1
fi

echo "Gerando Prisma Client..."

cd "${BACKEND_DIR}"

DATABASE_URL="${LOCAL_DATABASE_URL}" npx prisma generate 2>&1 | tee "${PRISMA_GENERATE_LOG}"

echo "Criando e aplicando migration inicial..."

DATABASE_URL="${LOCAL_DATABASE_URL}" npx prisma migrate dev --name init_schema --skip-generate 2>&1 | tee "${PRISMA_MIGRATE_LOG}"

echo "Regenerando Prisma Client apos migration..."

DATABASE_URL="${LOCAL_DATABASE_URL}" npx prisma generate 2>&1 | tee -a "${PRISMA_GENERATE_LOG}"

echo "Rodando typecheck..."

npm run typecheck 2>&1 | tee "${TYPECHECK_LOG}"

echo "Rodando build..."

npm run build 2>&1 | tee "${BUILD_LOG}"

cd "${BASE_DIR}"

echo "Listando tabelas no PostgreSQL..."

docker compose exec -T postgres psql -U saas_user -d saas_whatsapp -c "\dt" 2>&1 | tee "${TABLES_LOG}"

echo "Rebuildando backend..."

docker compose build backend 2>&1 | tee "${LOGS_DIR}/setup_23_backend_docker_build.log"

echo "Subindo backend..."

docker compose up -d backend 2>&1 | tee "${LOGS_DIR}/setup_23_backend_docker_up.log"

sleep 10

echo "Testando health local..."

LOCAL_STATUS="$(curl -s -o "${LOCAL_HEALTH_LOG}" -w "%{http_code}" --max-time 20 "${LOCAL_HEALTH_URL}" || true)"
echo "Health local status: ${LOCAL_STATUS}"

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
echo "Health dominio status: ${DOMAIN_STATUS}"

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

echo "Gerando documentacao da Etapa 23..."

cat > "${DOC_FILE}" <<'DOC'
# Prisma Schema Inicial

## Visao geral

Este documento registra a criacao do schema inicial do banco de dados usando Prisma.

## Resultado

Status:

    concluido

## ORM

ORM:

- Prisma 6.19.0

## Banco

Banco:

- PostgreSQL

## Migration criada

Migration:

- init_schema

## Correcao aplicada

Foi corrigida a ausencia de relacoes reversas no model Tenant.

## Tabelas iniciais

Tabelas:

- tenants
- users
- roles
- permissions
- role_permissions
- user_roles
- whatsapp_accounts
- contacts
- departments
- conversations
- conversation_assignments
- messages
- message_statuses
- webhook_events
- chatbot_flows
- chatbot_steps
- plans
- subscriptions
- settings
- audit_logs

## Validacoes executadas

Validacoes:

- prisma generate
- prisma migrate dev init_schema
- prisma generate apos migration
- npm run typecheck
- npm run build
- listagem de tabelas no PostgreSQL
- docker compose build backend
- docker compose up backend
- health local com database ok
- health dominio com database ok

## Logs gerados

Logs:

- logs/setup_23_prisma_generate.log
- logs/setup_23_prisma_migrate.log
- logs/setup_23_backend_typecheck.log
- logs/setup_23_backend_build.log
- logs/setup_23_database_tables.log
- logs/setup_23_backend_docker_build.log
- logs/setup_23_backend_docker_up.log
- logs/setup_23_health_local.log
- logs/setup_23_health_domain.log
- logs/fix_23_prisma_schema_relations.log
- logs/setup_23.log

## Observacoes

Esta etapa cria a estrutura inicial do banco.

Ainda nao foram criados seeds de usuarios, permissoes ou tenants.

A proxima etapa deve criar seed inicial controlado.

## Proxima etapa sugerida

Etapa 24:

    Criar seed inicial de tenant, usuario admin, roles e permissoes
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
- [ ] Etapa 24 - Seed inicial de tenant, admin, roles e permissoes

## Ultima etapa executada

Etapa 23 - Schema inicial do banco com Prisma.

## Proxima etapa sugerida

Etapa 24 - Criar seed inicial de tenant, usuario admin, roles e permissoes.
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

## Etapas concluidas

- Etapa 01 ate Etapa 23 concluidas

## Proxima etapa

- Etapa 24 - Seed inicial de tenant, admin, roles e permissoes
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

echo "Gravando logs..."

cat > "${FIX_LOG_FILE}" <<DOC
Etapa: 23
Acao: Correcao relacoes reversas Tenant
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health local status: ${LOCAL_STATUS}
Health dominio status: ${DOMAIN_STATUS}
Status: Concluido
DOC

cat > "${LOG_FILE}" <<DOC
Etapa: 23
Acao: Schema inicial do banco com Prisma
Data: $(date '+%Y-%m-%d %H:%M:%S')
Health local status: ${LOCAL_STATUS}
Health dominio status: ${DOMAIN_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 23 corrigida e concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Tabelas:"
cat "${TABLES_LOG}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 24 - Criar seed inicial de tenant, usuario admin, roles e permissoes"
