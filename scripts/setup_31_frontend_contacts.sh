#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_31.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_31_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_31_frontend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_31_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_31_frontend_docker_up.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_31_auth_login_domain.log"
DOMAIN_CONTACTS_LIST_API_LOG="${LOGS_DIR}/setup_31_contacts_list_domain.log"
DOMAIN_CONTACTS_CREATE_API_LOG="${LOGS_DIR}/setup_31_contacts_create_domain.log"
DOMAIN_CONTACTS_PAGE_LOG="${LOGS_DIR}/setup_31_domain_contacts_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_31_domain_dashboard.log"
DOC_FILE="${DOCS_DIR}/FRONTEND_CONTACTS.md"

DOMAIN_HOST="bot.lhsolucao.com.br"
DOMAIN_BASE_URL="https://${DOMAIN_HOST}"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_CONTACTS_API_URL="${DOMAIN_BASE_URL}/api/v1/contacts"
DOMAIN_CONTACTS_PAGE_URL="${DOMAIN_BASE_URL}/app/contacts"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"

echo "== Etapa 31: Frontend de contatos integrado ao backend =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${FRONTEND_DIR}/src/pages/contacts"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/types"
mkdir -p "${FRONTEND_DIR}/src/components/layout"

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/src/types/contacts.types.ts" \
  "${FRONTEND_DIR}/src/services/contacts.service.ts" \
  "${FRONTEND_DIR}/src/pages/contacts/ContactsPage.tsx" \
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

echo "Validando API de contatos via dominio antes do frontend..."

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

DOMAIN_CONTACTS_LIST_API_STATUS="$(curl -L -s -o "${DOMAIN_CONTACTS_LIST_API_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_CONTACTS_API_URL}" || true)"

if [ "${DOMAIN_CONTACTS_LIST_API_STATUS}" != "200" ]; then
  echo "ERRO: listagem de contatos dominio falhou. Status ${DOMAIN_CONTACTS_LIST_API_STATUS}"
  cat "${DOMAIN_CONTACTS_LIST_API_LOG}"
  exit 1
fi

if ! grep -q "contacts" "${DOMAIN_CONTACTS_LIST_API_LOG}"; then
  echo "ERRO: listagem de contatos nao retornou contacts."
  cat "${DOMAIN_CONTACTS_LIST_API_LOG}"
  exit 1
fi

CONTACT_PHONE="5521777${STAMP}"
CONTACT_PAYLOAD="$(node -e "console.log(JSON.stringify({name:'Contato Frontend Etapa 31', phone:process.argv[1], email:'contato31@lhsolucao.com.br'}))" "${CONTACT_PHONE}")"

DOMAIN_CONTACTS_CREATE_API_STATUS="$(curl -L -s -o "${DOMAIN_CONTACTS_CREATE_API_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${CONTACT_PAYLOAD}" \
  "${DOMAIN_CONTACTS_API_URL}" || true)"

if [ "${DOMAIN_CONTACTS_CREATE_API_STATUS}" != "200" ] && [ "${DOMAIN_CONTACTS_CREATE_API_STATUS}" != "201" ]; then
  echo "ERRO: criacao de contato dominio falhou. Status ${DOMAIN_CONTACTS_CREATE_API_STATUS}"
  cat "${DOMAIN_CONTACTS_CREATE_API_LOG}"
  exit 1
fi

if ! grep -q "Contato Frontend Etapa 31" "${DOMAIN_CONTACTS_CREATE_API_LOG}"; then
  echo "ERRO: criacao de contato nao retornou nome esperado."
  cat "${DOMAIN_CONTACTS_CREATE_API_LOG}"
  exit 1
fi

echo "Criando contacts.types.ts..."

cat > "${FRONTEND_DIR}/src/types/contacts.types.ts" <<'DOC'
export type ContactItem = {
  id: string;
  tenantId: string;
  name: string | null;
  phone: string;
  waId: string | null;
  email: string | null;
  document: string | null;
  createdAt: string;
  updatedAt: string;
};

export type ContactListData = {
  contacts: ContactItem[];
  total: number;
};

export type ContactData = {
  contact: ContactItem;
};

export type ContactDeleteData = {
  deleted: true;
  id: string;
};

export type ContactFormData = {
  name: string;
  phone: string;
  email: string;
  document: string;
};
DOC

echo "Criando contacts.service.ts..."

cat > "${FRONTEND_DIR}/src/services/contacts.service.ts" <<'DOC'
import { apiRequest } from './api';
import type {
  ContactData,
  ContactDeleteData,
  ContactFormData,
  ContactListData
} from '../types/contacts.types';

export async function listContactsRequest(token: string, search = '') {
  const query = search ? `?search=${encodeURIComponent(search)}` : '';

  return apiRequest<ContactListData>(`/contacts${query}`, {
    method: 'GET',
    token
  });
}

export async function createContactRequest(token: string, data: ContactFormData) {
  return apiRequest<ContactData>('/contacts', {
    method: 'POST',
    token,
    body: {
      name: data.name,
      phone: data.phone,
      email: data.email,
      document: data.document
    }
  });
}

export async function deleteContactRequest(token: string, contactId: string) {
  return apiRequest<ContactDeleteData>(`/contacts/${contactId}`, {
    method: 'DELETE',
    token
  });
}
DOC

echo "Criando ContactsPage..."

cat > "${FRONTEND_DIR}/src/pages/contacts/ContactsPage.tsx" <<'DOC'
import { FormEvent, useEffect, useState } from 'react';
import {
  createContactRequest,
  deleteContactRequest,
  listContactsRequest
} from '../../services/contacts.service';
import { useAuthStore } from '../../stores/auth.store';
import type { ContactFormData, ContactItem } from '../../types/contacts.types';

const initialForm: ContactFormData = {
  name: '',
  phone: '',
  email: '',
  document: ''
};

export function ContactsPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [contacts, setContacts] = useState<ContactItem[]>([]);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [form, setForm] = useState<ContactFormData>(initialForm);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadContacts(currentSearch = search) {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);

    try {
      const response = await listContactsRequest(token, currentSearch);

      if (response.success) {
        setContacts(response.data.contacts);
        setTotal(response.data.total);
      }
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadContacts('');
  }, []);

  async function handleSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    void loadContacts(search);
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
      const response = await createContactRequest(token, form);

      if (!response.success) {
        setMessage(response.error.message || 'Nao foi possivel criar o contato');
        return;
      }

      setForm(initialForm);
      setMessage('Contato criado com sucesso');
      await loadContacts(search);
    } catch (_error) {
      setMessage('Nao foi possivel conectar ao servidor');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(contactId: string) {
    const token = getToken();

    if (!token) {
      return;
    }

    setMessage('');

    const response = await deleteContactRequest(token, contactId);

    if (!response.success) {
      setMessage(response.error.message || 'Nao foi possivel remover o contato');
      return;
    }

    setMessage('Contato removido com sucesso');
    await loadContacts(search);
  }

  return (
    <section>
      <div className="page-heading">
        <span>Contatos</span>
        <h1>Agenda de contatos</h1>
        <p>Gerencie contatos vinculados ao tenant autenticado.</p>
      </div>

      <div className="contacts-layout">
        <section className="contacts-panel">
          <div className="panel-heading">
            <div>
              <h2>Novo contato</h2>
              <p>Cadastre contatos para futuras conversas pelo WhatsApp.</p>
            </div>
          </div>

          <form className="contacts-form" onSubmit={handleCreate}>
            <label>
              Nome
              <input
                onChange={(event) => setForm({ ...form, name: event.target.value })}
                placeholder="Nome do contato"
                value={form.name}
              />
            </label>

            <label>
              Telefone
              <input
                onChange={(event) => setForm({ ...form, phone: event.target.value })}
                placeholder="5521999999999"
                required
                value={form.phone}
              />
            </label>

            <label>
              Email
              <input
                onChange={(event) => setForm({ ...form, email: event.target.value })}
                placeholder="email@exemplo.com"
                type="email"
                value={form.email}
              />
            </label>

            <label>
              Documento
              <input
                onChange={(event) => setForm({ ...form, document: event.target.value })}
                placeholder="CPF ou CNPJ"
                value={form.document}
              />
            </label>

            <button disabled={saving} type="submit">
              {saving ? 'Salvando...' : 'Criar contato'}
            </button>
          </form>

          {message ? <div className="form-message">{message}</div> : null}
        </section>

        <section className="contacts-panel contacts-list-panel">
          <div className="panel-heading">
            <div>
              <h2>Contatos</h2>
              <p>Total encontrado: {total}</p>
            </div>
          </div>

          <form className="contacts-search" onSubmit={handleSearch}>
            <input
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Buscar por nome, telefone ou email"
              value={search}
            />

            <button type="submit">
              Buscar
            </button>
          </form>

          {loading ? (
            <div className="empty-panel">
              <strong>Carregando contatos...</strong>
              <p>Aguarde enquanto os dados sao carregados.</p>
            </div>
          ) : null}

          {!loading && contacts.length === 0 ? (
            <div className="empty-panel">
              <strong>Nenhum contato encontrado</strong>
              <p>Crie um novo contato ou ajuste a busca.</p>
            </div>
          ) : null}

          <div className="contacts-list">
            {contacts.map((contact) => (
              <article className="contact-card" key={contact.id}>
                <div>
                  <strong>{contact.name || 'Sem nome'}</strong>
                  <span>{contact.phone}</span>
                  {contact.email ? <small>{contact.email}</small> : null}
                </div>

                <button onClick={() => void handleDelete(contact.id)} type="button">
                  Remover
                </button>
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
          <Route path="profile" element={<ProfilePage />} />
        </Route>

        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
DOC

echo "Adicionando estilos de contatos..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

.contacts-layout {
  display: grid;
  gap: 24px;
  grid-template-columns: 380px minmax(0, 1fr);
  margin-top: 28px;
}

.contacts-panel {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.08);
  padding: 24px;
}

.panel-heading {
  align-items: flex-start;
  display: flex;
  justify-content: space-between;
  margin-bottom: 18px;
}

.panel-heading h2 {
  margin: 0 0 6px;
}

.panel-heading p {
  color: #6b7280;
  margin: 0;
}

.contacts-form {
  display: grid;
  gap: 14px;
}

.contacts-form label {
  color: #374151;
  display: grid;
  font-size: 14px;
  font-weight: 700;
  gap: 8px;
}

.contacts-form input,
.contacts-search input {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  padding: 12px 14px;
}

.contacts-form input:focus,
.contacts-search input:focus {
  border-color: #b91c1c;
  box-shadow: 0 0 0 4px rgba(185, 28, 28, 0.12);
  outline: none;
}

.contacts-form button,
.contacts-search button,
.contact-card button {
  background: #b91c1c;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 800;
  padding: 12px 16px;
}

.form-message {
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 14px;
  color: #374151;
  margin-top: 16px;
  padding: 12px;
}

.contacts-search {
  display: grid;
  gap: 12px;
  grid-template-columns: minmax(0, 1fr) auto;
  margin-bottom: 18px;
}

.contacts-list {
  display: grid;
  gap: 12px;
}

.contact-card {
  align-items: center;
  background: #f9fafb;
  border: 1px solid #e5e7eb;
  border-radius: 18px;
  display: flex;
  justify-content: space-between;
  padding: 16px;
}

.contact-card strong {
  display: block;
}

.contact-card span {
  color: #374151;
  display: block;
  margin-top: 4px;
}

.contact-card small {
  color: #6b7280;
  display: block;
  margin-top: 4px;
}

@media (max-width: 1100px) {
  .contacts-layout {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .contacts-search {
    grid-template-columns: 1fr;
  }

  .contact-card {
    align-items: flex-start;
    flex-direction: column;
    gap: 12px;
  }
}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/pages/contacts" \
  "${FRONTEND_DIR}/src/services/contacts.service.ts" \
  "${FRONTEND_DIR}/src/types/contacts.types.ts" \
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

echo "Testando rota contatos..."

DOMAIN_CONTACTS_PAGE_STATUS="$(curl -L -s -o "${LOGS_DIR}/setup_31_domain_contacts_page.log" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_CONTACTS_PAGE_URL}" || true)"

if [ "${DOMAIN_CONTACTS_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: rota contatos nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Testando rota dashboard..."

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${LOGS_DIR}/setup_31_domain_dashboard.log" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: rota dashboard nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Gerando documentacao da Etapa 31..."

cat > "${DOC_FILE}" <<'DOC'
# Frontend Contacts

## Visao geral

Este documento registra a criacao do frontend de contatos integrado ao backend.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tela Contatos
- listagem de contatos
- busca simples
- criacao de contato
- remocao de contato
- servico frontend de contatos
- tipos frontend de contatos
- link Contatos na Sidebar
- rota protegida app contacts

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/types/contacts.types.ts
- apps/frontend/src/services/contacts.service.ts
- apps/frontend/src/pages/contacts/ContactsPage.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/styles.css
- docs/FRONTEND_CONTACTS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- login via dominio
- listagem de contatos via dominio
- criacao de contato via dominio
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- teste da rota contatos
- teste da rota dashboard

## Rotas

Rotas:

- app contacts
- app dashboard

## Proxima etapa sugerida

Etapa 32:

    Criar frontend de conversas com layout inicial
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

- [ ] Etapa 32 - Frontend de conversas com layout inicial

## Ultima etapa executada

Etapa 31 - Frontend de contatos integrado.

## Proxima etapa sugerida

Etapa 32 - Criar frontend de conversas com layout inicial.
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

## Etapas concluidas

- Etapa 01 ate Etapa 31 concluidas

## Proxima etapa

- Etapa 32 - Frontend de conversas com layout inicial
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
Etapa: 31
Acao: Frontend de contatos integrado ao backend
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Contacts list api status: ${DOMAIN_CONTACTS_LIST_API_STATUS}
Contacts create api status: ${DOMAIN_CONTACTS_CREATE_API_STATUS}
Contacts page status: ${DOMAIN_CONTACTS_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 31 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br/app/contacts"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 32 - Criar frontend de conversas com layout inicial"
