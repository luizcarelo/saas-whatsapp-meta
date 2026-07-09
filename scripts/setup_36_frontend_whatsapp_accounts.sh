#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_36.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_36_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_36_frontend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_36_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_36_frontend_docker_up.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_36_auth_login_domain.log"
DOMAIN_ACCOUNTS_LIST_API_LOG="${LOGS_DIR}/setup_36_whatsapp_accounts_list_domain.log"
DOMAIN_ACCOUNTS_CREATE_API_LOG="${LOGS_DIR}/setup_36_whatsapp_accounts_create_domain.log"
DOMAIN_ACCOUNTS_PAGE_LOG="${LOGS_DIR}/setup_36_domain_whatsapp_accounts_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_36_domain_dashboard.log"
DOC_FILE="${DOCS_DIR}/FRONTEND_WHATSAPP_ACCOUNTS.md"

DOMAIN_HOST="bot.lhsolucao.com.br"
DOMAIN_BASE_URL="https://${DOMAIN_HOST}"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ACCOUNTS_API_URL="${DOMAIN_BASE_URL}/api/v1/whatsapp-accounts"
DOMAIN_ACCOUNTS_PAGE_URL="${DOMAIN_BASE_URL}/app/whatsapp-accounts"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"

echo "== Etapa 36: Frontend de WhatsApp Accounts integrado =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${FRONTEND_DIR}/src/pages/whatsapp-accounts"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/types"
mkdir -p "${FRONTEND_DIR}/src/components/layout"

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/src/types/whatsapp-accounts.types.ts" \
  "${FRONTEND_DIR}/src/services/whatsapp-accounts.service.ts" \
  "${FRONTEND_DIR}/src/pages/whatsapp-accounts/WhatsappAccountsPage.tsx" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/styles.css" \
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

if ! command -v curl >/dev/null 2>&1; then
  echo "ERRO: curl nao encontrado."
  exit 1
fi

echo "Validando credenciais da Etapa 24..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: arquivo de credenciais da Etapa 24 nao encontrado."
  exit 1
fi

ADMIN_EMAIL="$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"
ADMIN_PASSWORD="$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"

if [ -z "${ADMIN_EMAIL}" ]; then
  echo "ERRO: email admin nao encontrado."
  exit 1
fi

if [ -z "${ADMIN_PASSWORD}" ]; then
  echo "ERRO: senha admin nao encontrada."
  exit 1
fi

echo "Validando API WhatsApp Accounts via dominio antes do frontend..."

LOGIN_PAYLOAD="$(node -e "console.log(JSON.stringify({email: process.argv[1], password: process.argv[2]}))" "${ADMIN_EMAIL}" "${ADMIN_PASSWORD}")"

DOMAIN_LOGIN_STATUS="$(curl -L -s -o "${DOMAIN_LOGIN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}" \
  "${DOMAIN_LOGIN_URL}" || true)"

if [ "${DOMAIN_LOGIN_STATUS}" != "200" ] && [ "${DOMAIN_LOGIN_STATUS}" != "201" ]; then
  echo "ERRO: login dominio falhou. Status ${DOMAIN_LOGIN_STATUS}"
  cat "${DOMAIN_LOGIN_LOG}"
  exit 1
fi

if ! grep -q "access_token" "${DOMAIN_LOGIN_LOG}"; then
  echo "ERRO: login dominio nao retornou access_token."
  cat "${DOMAIN_LOGIN_LOG}"
  exit 1
fi

DOMAIN_ACCESS_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.access_token)" "${DOMAIN_LOGIN_LOG}")"

DOMAIN_ACCOUNTS_LIST_API_STATUS="$(curl -L -s -o "${DOMAIN_ACCOUNTS_LIST_API_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ACCOUNTS_API_URL}" || true)"

if [ "${DOMAIN_ACCOUNTS_LIST_API_STATUS}" != "200" ]; then
  echo "ERRO: listagem de WhatsApp Accounts via dominio falhou. Status ${DOMAIN_ACCOUNTS_LIST_API_STATUS}"
  cat "${DOMAIN_ACCOUNTS_LIST_API_LOG}"
  exit 1
fi

if ! grep -q "accounts" "${DOMAIN_ACCOUNTS_LIST_API_LOG}"; then
  echo "ERRO: listagem de WhatsApp Accounts nao retornou accounts."
  cat "${DOMAIN_ACCOUNTS_LIST_API_LOG}"
  exit 1
fi

ACCOUNT_PHONE_ID="frontend_phone_36_${STAMP}"
ACCOUNT_PAYLOAD="$(node -e "console.log(JSON.stringify({wabaId:'frontend_waba_36', phoneNumberId:process.argv[1], displayPhoneNumber:'+55 21 97777 3636', verifiedName:'Conta Frontend Etapa 36', accessToken:'token_frontend_36', status:'pending'}))" "${ACCOUNT_PHONE_ID}")"

DOMAIN_ACCOUNTS_CREATE_API_STATUS="$(curl -L -s -o "${DOMAIN_ACCOUNTS_CREATE_API_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${ACCOUNT_PAYLOAD}" \
  "${DOMAIN_ACCOUNTS_API_URL}" || true)"

if [ "${DOMAIN_ACCOUNTS_CREATE_API_STATUS}" != "200" ] && [ "${DOMAIN_ACCOUNTS_CREATE_API_STATUS}" != "201" ]; then
  echo "ERRO: criacao de WhatsApp Account via dominio falhou. Status ${DOMAIN_ACCOUNTS_CREATE_API_STATUS}"
  cat "${DOMAIN_ACCOUNTS_CREATE_API_LOG}"
  exit 1
fi

if ! grep -q "Conta Frontend Etapa 36" "${DOMAIN_ACCOUNTS_CREATE_API_LOG}"; then
  echo "ERRO: criacao de WhatsApp Account nao retornou nome esperado."
  cat "${DOMAIN_ACCOUNTS_CREATE_API_LOG}"
  exit 1
fi

echo "Criando whatsapp-accounts.types.ts..."

cat > "${FRONTEND_DIR}/src/types/whatsapp-accounts.types.ts" <<'DOC'
export type WhatsappAccountItem = {
  id: string;
  tenantId: string;
  wabaId: string;
  phoneNumberId: string;
  displayPhoneNumber: string;
  verifiedName: string | null;
  status: string;
  createdAt: string;
  updatedAt: string;
};

export type WhatsappAccountListData = {
  accounts: WhatsappAccountItem[];
  total: number;
};

export type WhatsappAccountData = {
  account: WhatsappAccountItem;
};

export type WhatsappAccountDeleteData = {
  deleted: true;
  id: string;
};

export type WhatsappAccountFormData = {
  wabaId: string;
  phoneNumberId: string;
  displayPhoneNumber: string;
  verifiedName: string;
  accessToken: string;
  status: string;
};
DOC

echo "Criando whatsapp-accounts.service.ts..."

cat > "${FRONTEND_DIR}/src/services/whatsapp-accounts.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  WhatsappAccountData,
  WhatsappAccountDeleteData,
  WhatsappAccountFormData,
  WhatsappAccountListData
} from '../types/whatsapp-accounts.types';

export async function listWhatsappAccountsRequest(token: string, search = '') {
  const query = search ? `?search=${encodeURIComponent(search)}` : '';

  return apiRequest<WhatsappAccountListData>(`/whatsapp-accounts${query}`, {
    method: 'GET',
    token
  });
}

export async function createWhatsappAccountRequest(
  token: string,
  data: WhatsappAccountFormData
) {
  return apiRequest<WhatsappAccountData>('/whatsapp-accounts', {
    method: 'POST',
    token,
    body: {
      wabaId: data.wabaId,
      phoneNumberId: data.phoneNumberId,
      displayPhoneNumber: data.displayPhoneNumber,
      verifiedName: data.verifiedName,
      accessToken: data.accessToken,
      status: data.status
    }
  });
}

export async function deleteWhatsappAccountRequest(token: string, accountId: string) {
  return apiRequest<WhatsappAccountDeleteData>(`/whatsapp-accounts/${accountId}`, {
    method: 'DELETE',
    token
  });
}
DOC

echo "Criando WhatsappAccountsPage..."

cat > "${FRONTEND_DIR}/src/pages/whatsapp-accounts/WhatsappAccountsPage.tsx" <<'DOC'
import { FormEvent, useEffect, useState } from 'react';
import {
  createWhatsappAccountRequest,
  deleteWhatsappAccountRequest,
  listWhatsappAccountsRequest
} from '../../services/whatsapp-accounts.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
  WhatsappAccountFormData,
  WhatsappAccountItem
} from '../../types/whatsapp-accounts.types';

const initialForm: WhatsappAccountFormData = {
  wabaId: '',
  phoneNumberId: '',
  displayPhoneNumber: '',
  verifiedName: '',
  accessToken: '',
  status: 'pending'
};

const statusLabel: Record<string, string> = {
  active: 'Ativa',
  inactive: 'Inativa',
  pending: 'Pendente',
  disconnected: 'Desconectada',
  error: 'Erro'
};

export function WhatsappAccountsPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [accounts, setAccounts] = useState<WhatsappAccountItem[]>([]);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [form, setForm] = useState<WhatsappAccountFormData>(initialForm);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadAccounts(currentSearch = search) {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);

    try {
      const response = await listWhatsappAccountsRequest(token, currentSearch);

      if (response.success) {
        setAccounts(response.data.accounts);
        setTotal(response.data.total);
      }
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadAccounts('');
  }, []);

  async function handleSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await loadAccounts(search);
  }

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token) {
      return;
    }

    setSaving(true);
    setMessage('');

    try {
      const response = await createWhatsappAccountRequest(token, form);

      if (!response.success) {
        setMessage(response.error.message || 'Nao foi possivel criar a conta');
        return;
      }

      setForm(initialForm);
      setMessage('Conta WhatsApp criada com sucesso');
      await loadAccounts(search);
    } catch (_error) {
      setMessage('Nao foi possivel conectar ao servidor');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(accountId: string) {
    const token = getToken();

    if (!token) {
      return;
    }

    setMessage('');

    const response = await deleteWhatsappAccountRequest(token, accountId);

    if (!response.success) {
      setMessage(response.error.message || 'Nao foi possivel remover a conta');
      return;
    }

    setMessage('Conta WhatsApp removida com sucesso');
    await loadAccounts(search);
  }

  return (
    <section>
      <div className="page-heading">
        <span>WhatsApp</span>
        <h1>Contas WhatsApp</h1>
        <p>Gerencie contas WhatsApp vinculadas ao tenant autenticado.</p>
      </div>

      <div className="whatsapp-layout">
        <section className="whatsapp-panel">
          <div className="panel-heading">
            <div>
              <h2>Nova conta</h2>
              <p>Cadastre uma conta para futura integracao com a API oficial da Meta.</p>
            </div>
          </div>

          <form className="whatsapp-form" onSubmit={handleCreate}>
            <label>
              WABA ID
              <input
                onChange={(event) => setForm({ ...form, wabaId: event.target.value })}
                placeholder="WABA ID"
                required
                value={form.wabaId}
              />
            </label>

            <label>
              Phone Number ID
              <input
                onChange={(event) => setForm({ ...form, phoneNumberId: event.target.value })}
                placeholder="Phone Number ID"
                required
                value={form.phoneNumberId}
              />
            </label>

            <label>
              Telefone de exibicao
              <input
                onChange={(event) => setForm({ ...form, displayPhoneNumber: event.target.value })}
                placeholder="+55 21 99999 9999"
                required
                value={form.displayPhoneNumber}
              />
            </label>

            <label>
              Nome verificado
              <input
                onChange={(event) => setForm({ ...form, verifiedName: event.target.value })}
                placeholder="Nome da empresa"
                value={form.verifiedName}
              />
            </label>

            <label>
              Access Token
              <input
                onChange={(event) => setForm({ ...form, accessToken: event.target.value })}
                placeholder="Token temporario ou definitivo"
                type="password"
                value={form.accessToken}
              />
            </label>

            <label>
              Status
              <select
                onChange={(event) => setForm({ ...form, status: event.target.value })}
                value={form.status}
              >
                <option value="pending">Pendente</option>
                <option value="active">Ativa</option>
                <option value="inactive">Inativa</option>
                <option value="disconnected">Desconectada</option>
                <option value="error">Erro</option>
              </select>
            </label>

            <button disabled={saving} type="submit">
              {saving ? 'Salvando...' : 'Criar conta'}
            </button>
          </form>

          {message ? <div className="form-message">{message}</div> : null}
        </section>

        <section className="whatsapp-panel whatsapp-list-panel">
          <div className="panel-heading">
            <div>
              <h2>Contas cadastradas</h2>
              <p>Total encontrado: {total}</p>
            </div>
          </div>

          <form className="whatsapp-search" onSubmit={handleSearch}>
            <input
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Buscar por WABA, telefone ou nome"
              value={search}
            />

            <button type="submit">
              Buscar
            </button>
          </form>

          {loading ? (
            <div className="empty-panel">
              <strong>Carregando contas...</strong>
              <p>Aguarde enquanto os dados sao carregados.</p>
            </div>
          ) : null}

          {!loading && accounts.length === 0 ? (
            <div className="empty-panel">
              <strong>Nenhuma conta encontrada</strong>
              <p>Crie uma conta WhatsApp para iniciar a configuracao.</p>
            </div>
          ) : null}

          <div className="whatsapp-list">
            {accounts.map((account) => (
              <article className="whatsapp-card" key={account.id}>
                <div>
                  <strong>{account.verifiedName || account.displayPhoneNumber}</strong>
                  <span>{account.displayPhoneNumber}</span>
                  <small>WABA: {account.wabaId}</small>
                  <small>Phone ID: {account.phoneNumberId}</small>
                </div>

                <div className="whatsapp-card-actions">
                  <em>{statusLabel[account.status] || account.status}</em>
                  <button onClick={() => void handleDelete(account.id)} type="button">
                    Remover
                  </button>
                </div>
              </article>
            ))}
          </div>
        </section>
      </div>
    </section>
  );
}
DOC

echo "Atualizando Sidebar..."

cat > "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" <<'DOC'
import { NavLink } from 'react-router-dom';

export function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <div className="sidebar-logo">LH</div>
        <div>
          <strong>LH Bot</strong>
          <span>WhatsApp Meta</span>
        </div>
      </div>

      <nav className="sidebar-nav">
        <NavLink to="/app/dashboard">
          Dashboard
        </NavLink>

        <NavLink to="/app/contacts">
          Contatos
        </NavLink>

        <NavLink to="/app/conversations">
          Conversas
        </NavLink>

        <NavLink to="/app/whatsapp-accounts">
          WhatsApp
        </NavLink>

        <NavLink to="/app/profile">
          Perfil
        </NavLink>
      </nav>
    </aside>
  );
}
DOC

echo "Atualizando routes.tsx..."

cat > "${FRONTEND_DIR}/src/app/routes.tsx" <<'DOC'
import {
  BrowserRouter,
  Navigate,
  Route,
  Routes
} from 'react-router-dom';
import { AppLayout } from '../components/layout/AppLayout';
import { DashboardPage } from '../pages/dashboard/DashboardPage';
import { ContactsPage } from '../pages/contacts/ContactsPage';
import { ConversationsPage } from '../pages/conversations/ConversationsPage';
import { LoginPage } from '../pages/login/LoginPage';
import { ProfilePage } from '../pages/profile/ProfilePage';
import { WhatsappAccountsPage } from '../pages/whatsapp-accounts/WhatsappAccountsPage';
import { ProtectedRoute } from './ProtectedRoute';

export function AppRoutes() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/login" replace />} />
        <Route path="/login" element={<LoginPage />} />

        <Route
          path="/app"
          element={
            <ProtectedRoute>
              <AppLayout />
            </ProtectedRoute>
          }
        >
          <Route path="dashboard" element={<DashboardPage />} />
          <Route path="contacts" element={<ContactsPage />} />
          <Route path="conversations" element={<ConversationsPage />} />
          <Route path="whatsapp-accounts" element={<WhatsappAccountsPage />} />
          <Route path="profile" element={<ProfilePage />} />
        </Route>

        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
DOC

echo "Adicionando estilos de WhatsApp Accounts..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.whatsapp-layout {
  display: grid;
  gap: 24px;
  grid-template-columns: 420px minmax(0, 1fr);
  margin-top: 28px;
}

.whatsapp-panel {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.08);
  padding: 24px;
}

.whatsapp-form {
  display: grid;
  gap: 14px;
}

.whatsapp-form label {
  color: #374151;
  display: grid;
  font-size: 14px;
  font-weight: 700;
  gap: 8px;
}

.whatsapp-form input,
.whatsapp-form select,
.whatsapp-search input {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  padding: 12px 14px;
}

.whatsapp-form input:focus,
.whatsapp-form select:focus,
.whatsapp-search input:focus {
  border-color: #b91c1c;
  box-shadow: 0 0 0 4px rgba(185, 28, 28, 0.12);
  outline: none;
}

.whatsapp-form button,
.whatsapp-search button,
.whatsapp-card button {
  background: #b91c1c;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 800;
  padding: 12px 16px;
}

.whatsapp-search {
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) auto;
  margin-bottom: 18px;
}

.whatsapp-list {
  display: grid;
  gap: 12px;
}

.whatsapp-card {
  align-items: center;
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 18px;
  display: flex;
  justify-content: space-between;
  padding: 16px;
}

.whatsapp-card strong {
  display: block;
}

.whatsapp-card span {
  color: #374151;
  display: block;
  margin-top: 4px;
}

.whatsapp-card small {
  color: #6b7280;
  display: block;
  margin-top: 4px;
  overflow-wrap: anywhere;
}

.whatsapp-card-actions {
  align-items: flex-end;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.whatsapp-card-actions em {
  background: #f3f4f6;
  border-radius: 999px;
  color: #374151;
  font-size: 12px;
  font-style: normal;
  font-weight: 800;
  padding: 7px 10px;
}

@media (max-width: 1100px) {
  .whatsapp-layout {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .whatsapp-search {
    grid-template-columns: 1fr;
  }

  .whatsapp-card {
    align-items: flex-start;
    flex-direction: column;
    gap: 12px;
  }

  .whatsapp-card-actions {
    align-items: flex-start;
  }
}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/pages/whatsapp-accounts" \
  "${FRONTEND_DIR}/src/services/whatsapp-accounts.service.ts" \
  "${FRONTEND_DIR}/src/types/whatsapp-accounts.types.ts" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx"
then
  echo "ERRO: HTML indevido encontrado."
  exit 1
fi

echo "Rodando typecheck do frontend..."

cd "${FRONTEND_DIR}"
npm run typecheck 2>&1 | tee "${FRONTEND_TYPECHECK_LOG}"

echo "Rodando build do frontend..."

npm run build 2>&1 | tee "${FRONTEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando frontend..."

docker compose build frontend 2>&1 | tee "${DOCKER_BUILD_LOG}"

echo "Subindo frontend e proxy..."

docker compose up -d frontend proxy 2>&1 | tee "${DOCKER_UP_LOG}"

sleep 8

echo "Testando rota WhatsApp Accounts..."

DOMAIN_ACCOUNTS_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_ACCOUNTS_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_ACCOUNTS_PAGE_URL}" || true)"

if [ "${DOMAIN_ACCOUNTS_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: rota WhatsApp Accounts nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Testando rota dashboard..."

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: rota dashboard nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Gerando documentacao da Etapa 36..."

cat > "${DOC_FILE}" <<'DOC'
# Frontend WhatsApp Accounts

## Visao geral

Este documento registra a criacao do frontend de WhatsApp Accounts integrado ao backend.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tela WhatsApp Accounts
- listagem de contas WhatsApp
- busca simples
- criacao de conta WhatsApp
- remocao de conta WhatsApp
- servico frontend de WhatsApp Accounts
- tipos frontend de WhatsApp Accounts
- link WhatsApp na Sidebar
- rota protegida app whatsapp accounts

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/types/whatsapp-accounts.types.ts
- apps/frontend/src/services/whatsapp-accounts.service.ts
- apps/frontend/src/pages/whatsapp-accounts/WhatsappAccountsPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/FRONTEND_WHATSAPP_ACCOUNTS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- login via dominio
- listagem de WhatsApp Accounts via dominio
- criacao de WhatsApp Account via dominio
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- teste da rota WhatsApp Accounts
- teste da rota dashboard

## Rotas

Rotas:

- app whatsapp accounts
- app dashboard

## Observacoes

Esta etapa ainda nao valida credenciais reais junto a Meta.

A integracao real com a API oficial da Meta sera criada em etapa futura.

## Proxima etapa sugerida

Etapa 37:

    Criar modulo backend de webhooks da Meta
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
- [x] Etapa 25 - Auth inicial com login real

## Fase 05 - Frontend integrado inicial

- [x] Etapa 26 - Frontend login integrado
- [x] Etapa 27 - Protecao visual de rotas e layout base

## Fase 06 - Usuarios e perfil

- [x] Etapa 28 - Modulo backend de usuarios
- [x] Etapa 29 - Frontend com perfil detalhado

## Fase 07 - Contatos

- [x] Etapa 30 - Modulo backend de contatos
- [x] Etapa 31 - Frontend de contatos integrado

## Fase 08 - Conversas

- [x] Etapa 32 - Frontend de conversas com layout inicial
- [x] Etapa 33 - Modulo backend de conversas
- [x] Etapa 34 - Frontend de conversas integrado ao backend

## Fase 09 - WhatsApp

- [x] Etapa 35 - Modulo backend de WhatsApp Accounts
- [x] Etapa 36 - Frontend de WhatsApp Accounts integrado
- [ ] Etapa 37 - Modulo backend de webhooks da Meta

## Ultima etapa executada

Etapa 36 - Frontend de WhatsApp Accounts integrado.

## Proxima etapa sugerida

Etapa 37 - Criar modulo backend de webhooks da Meta.
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

Auth inicial com login real criado.

Frontend login integrado criado.

Layout base e protecao visual de rotas criados.

Modulo backend de usuarios criado.

Frontend com perfil detalhado criado.

Modulo backend de contatos criado.

Frontend de contatos integrado criado.

Frontend de conversas com layout inicial criado.

Modulo backend de conversas criado.

Frontend de conversas integrado ao backend criado.

Modulo backend de WhatsApp Accounts criado.

Frontend de WhatsApp Accounts integrado criado.

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
- docs/AUTH_LOGIN_REAL.md
- docs/FRONTEND_LOGIN_INTEGRADO.md
- docs/FRONTEND_LAYOUT_PROTECAO_ROTAS.md
- docs/BACKEND_USERS_PROFILE.md
- docs/FRONTEND_PROFILE_DETALHADO.md
- docs/BACKEND_CONTACTS.md
- docs/FRONTEND_CONTACTS.md
- docs/FRONTEND_CONVERSATIONS_LAYOUT.md
- docs/BACKEND_CONVERSATIONS.md
- docs/FRONTEND_CONVERSATIONS_INTEGRADO.md
- docs/BACKEND_WHATSAPP_ACCOUNTS.md
- docs/FRONTEND_WHATSAPP_ACCOUNTS.md

## Etapas concluidas

- Etapa 01 ate Etapa 36 concluidas

## Proxima etapa

- Etapa 37 - Modulo backend de webhooks da Meta
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

cat > "${LOG_FILE}" <<DOC
Etapa: 36
Acao: Frontend de WhatsApp Accounts integrado ao backend
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Accounts list api status: ${DOMAIN_ACCOUNTS_LIST_API_STATUS}
Accounts create api status: ${DOMAIN_ACCOUNTS_CREATE_API_STATUS}
Accounts page status: ${DOMAIN_ACCOUNTS_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 36 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br/app/whatsapp-accounts"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 37 - Criar modulo backend de webhooks da Meta"
