#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_26.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_26_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_26_frontend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_26_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_26_frontend_docker_up.log"
DOMAIN_HOME_LOG="${LOGS_DIR}/setup_26_domain_home.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_26_domain_login.log"
BACKEND_LOGIN_LOG="${LOGS_DIR}/setup_26_backend_login.log"
DOC_FILE="${DOCS_DIR}/FRONTEND_LOGIN_INTEGRADO.md"

DOMAIN_HOME_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="https://bot.lhsolucao.com.br/login"
BACKEND_LOGIN_URL="https://bot.lhsolucao.com.br/api/v1/auth/login"

echo "== Etapa 26: Frontend login integrado ao backend =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${FRONTEND_DIR}/src/app"
mkdir -p "${FRONTEND_DIR}/src/pages/login"
mkdir -p "${FRONTEND_DIR}/src/pages/dashboard"
mkdir -p "${FRONTEND_DIR}/src/pages/conversations"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/stores"
mkdir -p "${FRONTEND_DIR}/src/types"

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/src/App.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/app/providers.tsx" \
  "${FRONTEND_DIR}/src/pages/login/LoginPage.tsx" \
  "${FRONTEND_DIR}/src/pages/dashboard/DashboardPage.tsx" \
  "${FRONTEND_DIR}/src/pages/conversations/ConversationsPage.tsx" \
  "${FRONTEND_DIR}/src/services/api.ts" \
  "${FRONTEND_DIR}/src/services/auth.service.ts" \
  "${FRONTEND_DIR}/src/stores/auth.store.ts" \
  "${FRONTEND_DIR}/src/types/api.types.ts" \
  "${FRONTEND_DIR}/src/types/auth.types.ts" \
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

echo "Validando backend login antes do frontend..."

LOGIN_PAYLOAD="$(node -e "console.log(JSON.stringify({email: process.argv[1], password: process.argv[2]}))" "${ADMIN_EMAIL}" "${ADMIN_PASSWORD}")"

BACKEND_LOGIN_STATUS="$(curl -L -s -o "${BACKEND_LOGIN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}" \
  "${BACKEND_LOGIN_URL}" || true)"

if [ "${BACKEND_LOGIN_STATUS}" != "200" ] && [ "${BACKEND_LOGIN_STATUS}" != "201" ]; then
  echo "ERRO: backend login nao respondeu com sucesso."
  cat "${BACKEND_LOGIN_LOG}"
  exit 1
fi

if ! grep -q "access_token" "${BACKEND_LOGIN_LOG}"; then
  echo "ERRO: backend login nao retornou access_token."
  cat "${BACKEND_LOGIN_LOG}"
  exit 1
fi

echo "Criando tipos de API..."

cat > "${FRONTEND_DIR}/src/types/api.types.ts" <<'DOC'
export type ApiSuccessResponse<T> = {
  success: true;
  data: T;
  meta?: Record<string, unknown>;
};

export type ApiErrorResponse = {
  success: false;
  error: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
};

export type ApiResponse<T> = ApiSuccessResponse<T> | ApiErrorResponse;
DOC

echo "Criando tipos de Auth..."

cat > "${FRONTEND_DIR}/src/types/auth.types.ts" <<'DOC'
export type AuthenticatedUser = {
  id: string;
  tenantId: string;
  name: string;
  email: string;
  roles: string[];
  permissions: string[];
};

export type LoginData = {
  access_token: string;
  token_type: string;
  user: AuthenticatedUser;
};

export type MeData = {
  user: AuthenticatedUser;
};
DOC

echo "Criando cliente API..."

cat > "${FRONTEND_DIR}/src/services/api.ts" <<'DOC'
import type { ApiResponse } from '../types/api.types';

function getApiBaseUrl(): string {
  const configuredUrl = import.meta.env.VITE_API_URL as string | undefined;

  if (configuredUrl && configuredUrl.length > 0) {
    return configuredUrl;
  }

  if (typeof window !== 'undefined') {
    return `${window.location.origin}/api/v1`;
  }

  return 'http://127.0.0.1:3300/api/v1';
}

const apiBaseUrl = getApiBaseUrl();

type RequestOptions = {
  token?: string | null;
  method?: string;
  body?: unknown;
};

export async function apiRequest<T>(
  path: string,
  options: RequestOptions = {}
): Promise<ApiResponse<T>> {
  const headers: Record<string, string> = {
    Accept: 'application/json',
    'Content-Type': 'application/json'
  };

  if (options.token) {
    headers.Authorization = `Bearer ${options.token}`;
  }

  const response = await fetch(`${apiBaseUrl}${path}`, {
    method: options.method || 'GET',
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined
  });

  const data = await response.json();

  return data as ApiResponse<T>;
}
DOC

echo "Criando auth.service.ts..."

cat > "${FRONTEND_DIR}/src/services/auth.service.ts" <<'DOC'
import { apiRequest } from './api';
import type { LoginData, MeData } from '../types/auth.types';

export async function loginRequest(email: string, password: string) {
  return apiRequest<LoginData>('/auth/login', {
    method: 'POST',
    body: {
      email,
      password
    }
  });
}

export async function meRequest(token: string) {
  return apiRequest<MeData>('/auth/me', {
    method: 'GET',
    token
  });
}
DOC

echo "Criando auth.store.ts..."

cat > "${FRONTEND_DIR}/src/stores/auth.store.ts" <<'DOC'
import { create } from 'zustand';
import type { AuthenticatedUser } from '../types/auth.types';

const storageTokenKey = 'saas_whatsapp_access_token';

type AuthState = {
  user: AuthenticatedUser | null;
  accessToken: string | null;
  setSession: (user: AuthenticatedUser, accessToken: string) => void;
  clearSession: () => void;
  loadToken: () => string | null;
};

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  accessToken: typeof window === 'undefined' ? null : window.localStorage.getItem(storageTokenKey),
  setSession: (user, accessToken) => {
    window.localStorage.setItem(storageTokenKey, accessToken);

    set({
      user,
      accessToken
    });
  },
  clearSession: () => {
    window.localStorage.removeItem(storageTokenKey);

    set({
      user: null,
      accessToken: null
    });
  },
  loadToken: () => {
    if (typeof window === 'undefined') {
      return null;
    }

    return window.localStorage.getItem(storageTokenKey);
  }
}));
DOC

echo "Criando LoginPage..."

cat > "${FRONTEND_DIR}/src/pages/login/LoginPage.tsx" <<'DOC'
import { FormEvent, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { loginRequest } from '../../services/auth.service';
import { useAuthStore } from '../../stores/auth.store';

export function LoginPage() {
  const navigate = useNavigate();
  const setSession = useAuthStore((state) => state.setSession);

  const [email, setEmail] = useState('admin@lhsolucao.com.br');
  const [password, setPassword] = useState('');
  const [errorMessage, setErrorMessage] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setErrorMessage('');
    setLoading(true);

    try {
      const response = await loginRequest(email, password);

      if (!response.success) {
        setErrorMessage(response.error.message || 'Login invalido');
        return;
      }

      setSession(response.data.user, response.data.access_token);
      navigate('/app/dashboard');
    } catch (_error) {
      setErrorMessage('Nao foi possivel conectar ao servidor');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="page page-login">
      <section className="login-card">
        <div className="brand-mark">LH</div>

        <div className="login-header">
          <h1>SaaS WhatsApp Meta</h1>
          <p>Acesse o painel do bot integrado a API oficial da Meta.</p>
        </div>

        <form className="login-form" onSubmit={handleSubmit}>
          <label>
            Email
            <input
              autoComplete="email"
              name="email"
              onChange={(event) => setEmail(event.target.value)}
              placeholder="admin@lhsolucao.com.br"
              type="email"
              value={email}
            />
          </label>

          <label>
            Senha
            <input
              autoComplete="current-password"
              name="password"
              onChange={(event) => setPassword(event.target.value)}
              placeholder="Digite a senha inicial"
              type="password"
              value={password}
            />
          </label>

          {errorMessage ? (
            <div className="form-error">{errorMessage}</div>
          ) : null}

          <button disabled={loading} type="submit">
            {loading ? 'Entrando...' : 'Entrar'}
          </button>
        </form>

        <p className="login-help">
          Use a senha gravada no log local da Etapa 24.
        </p>
      </section>
    </main>
  );
}
DOC

echo "Criando DashboardPage..."

cat > "${FRONTEND_DIR}/src/pages/dashboard/DashboardPage.tsx" <<'DOC'
import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { meRequest } from '../../services/auth.service';
import { useAuthStore } from '../../stores/auth.store';
import type { AuthenticatedUser } from '../../types/auth.types';

export function DashboardPage() {
  const navigate = useNavigate();
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);
  const clearSession = useAuthStore((state) => state.clearSession);
  const setSession = useAuthStore((state) => state.setSession);
  const storedUser = useAuthStore((state) => state.user);

  const [user, setUser] = useState<AuthenticatedUser | null>(storedUser);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadMe() {
      const token = accessToken || loadToken();

      if (!token) {
        navigate('/login');
        return;
      }

      const response = await meRequest(token);

      if (!response.success) {
        clearSession();
        navigate('/login');
        return;
      }

      setSession(response.data.user, token);
      setUser(response.data.user);
      setLoading(false);
    }

    void loadMe();
  }, [accessToken, clearSession, loadToken, navigate, setSession]);

  function handleLogout() {
    clearSession();
    navigate('/login');
  }

  if (loading) {
    return (
      <main className="app-shell">
        <section className="panel">
          <p>Carregando sessao...</p>
        </section>
      </main>
    );
  }

  return (
    <main className="app-shell">
      <aside className="sidebar">
        <div className="sidebar-brand">LH Bot</div>

        <nav>
          <Link to="/app/dashboard">Dashboard</Link>
          <Link to="/app/conversations">Conversas</Link>
        </nav>

        <button className="logout-button" onClick={handleLogout} type="button">
          Sair
        </button>
      </aside>

      <section className="content">
        <div className="page-title">
          <span>Dashboard</span>
          <h1>Bem-vindo, {user?.name}</h1>
          <p>{user?.email}</p>
        </div>

        <div className="grid">
          <article className="metric-card">
            <span>Status</span>
            <strong>Online</strong>
            <p>Backend, banco e dominio respondendo.</p>
          </article>

          <article className="metric-card">
            <span>Perfil</span>
            <strong>{user?.roles.join(', ')}</strong>
            <p>Permissoes carregadas via token.</p>
          </article>

          <article className="metric-card">
            <span>Permissoes</span>
            <strong>{user?.permissions.length || 0}</strong>
            <p>Total de permissoes ativas para este usuario.</p>
          </article>
        </div>
      </section>
    </main>
  );
}
DOC

echo "Criando ConversationsPage..."

cat > "${FRONTEND_DIR}/src/pages/conversations/ConversationsPage.tsx" <<'DOC'
import { Link } from 'react-router-dom';

export function ConversationsPage() {
  return (
    <main className="app-shell">
      <section className="content full-width">
        <div className="page-title">
          <span>Conversas</span>
          <h1>Modulo de conversas</h1>
          <p>Esta tela sera implementada em etapa futura.</p>
        </div>

        <Link className="back-link" to="/app/dashboard">
          Voltar ao dashboard
        </Link>
      </section>
    </main>
  );
}
DOC

echo "Criando routes.tsx..."

cat > "${FRONTEND_DIR}/src/app/routes.tsx" <<'DOC'
import {
  BrowserRouter,
  Navigate,
  Route,
  Routes
} from 'react-router-dom';
import { DashboardPage } from '../pages/dashboard/DashboardPage';
import { ConversationsPage } from '../pages/conversations/ConversationsPage';
import { LoginPage } from '../pages/login/LoginPage';

export function AppRoutes() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/login" replace />} />
        <Route path="/login" element={<LoginPage />} />
        <Route path="/app/dashboard" element={<DashboardPage />} />
        <Route path="/app/conversations" element={<ConversationsPage />} />
      </Routes>
    </BrowserRouter>
  );
}
DOC

echo "Criando App.tsx..."

cat > "${FRONTEND_DIR}/src/App.tsx" <<'DOC'
import { AppRoutes } from './app/routes';

export function App() {
  return <AppRoutes />;
}
DOC

echo "Criando styles.css..."

cat > "${FRONTEND_DIR}/src/styles.css" <<'DOC'
:root {
  color: #111827;
  background: #f3f4f6;
  font-family: Arial, Helvetica, sans-serif;
}

body {
  margin: 0;
}

button,
input {
  font: inherit;
}

a {
  color: #b91c1c;
  font-weight: 700;
  text-decoration: none;
}

a:hover {
  text-decoration: underline;
}

.page {
  align-items: center;
  display: flex;
  justify-content: center;
  min-height: 100vh;
  padding: 24px;
}

.page-login {
  background:
    radial-gradient(circle at top left, rgba(185, 28, 28, 0.18), transparent 34%),
    linear-gradient(135deg, #f9fafb 0%, #f3f4f6 100%);
}

.login-card {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 24px;
  box-shadow: 0 24px 70px rgba(15, 23, 42, 0.14);
  max-width: 430px;
  padding: 36px;
  width: 100%;
}

.brand-mark {
  align-items: center;
  background: #b91c1c;
  border-radius: 18px;
  color: #ffffff;
  display: flex;
  font-size: 22px;
  font-weight: 800;
  height: 58px;
  justify-content: center;
  margin-bottom: 26px;
  width: 58px;
}

.login-header h1 {
  font-size: 30px;
  margin: 0 0 8px;
}

.login-header p {
  color: #6b7280;
  line-height: 1.5;
  margin: 0 0 28px;
}

.login-form {
  display: grid;
  gap: 18px;
}

.login-form label {
  color: #374151;
  display: grid;
  font-size: 14px;
  font-weight: 700;
  gap: 8px;
}

.login-form input {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  padding: 13px 14px;
}

.login-form input:focus {
  border-color: #b91c1c;
  box-shadow: 0 0 0 4px rgba(185, 28, 28, 0.12);
  outline: none;
}

.login-form button,
.logout-button {
  background: #b91c1c;
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 800;
  padding: 14px 18px;
}

.login-form button:disabled {
  cursor: not-allowed;
  opacity: 0.7;
}

.form-error {
  background: #fef2f2;
  border: 1px solid #fecaca;
  border-radius: 14px;
  color: #991b1b;
  padding: 12px;
}

.login-help {
  color: #6b7280;
  font-size: 13px;
  margin: 20px 0 0;
}

.app-shell {
  background: #f3f4f6;
  display: flex;
  min-height: 100vh;
}

.sidebar {
  background: #111827;
  color: #ffffff;
  display: flex;
  flex-direction: column;
  gap: 24px;
  padding: 28px;
  width: 260px;
}

.sidebar-brand {
  font-size: 22px;
  font-weight: 800;
}

.sidebar nav {
  display: grid;
  gap: 14px;
}

.sidebar a {
  color: #ffffff;
}

.logout-button {
  margin-top: auto;
}

.content {
  flex: 1;
  padding: 38px;
}

.full-width {
  width: 100%;
}

.page-title span {
  color: #b91c1c;
  font-weight: 800;
  text-transform: uppercase;
}

.page-title h1 {
  font-size: 34px;
  margin: 8px 0;
}

.page-title p {
  color: #6b7280;
}

.grid {
  display: grid;
  gap: 20px;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  margin-top: 28px;
}

.metric-card,
.panel {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 22px;
  box-shadow: 0 16px 45px rgba(15, 23, 42, 0.08);
  padding: 24px;
}

.metric-card span {
  color: #6b7280;
  font-weight: 700;
}

.metric-card strong {
  display: block;
  font-size: 28px;
  margin: 10px 0;
}

.metric-card p {
  color: #6b7280;
  line-height: 1.5;
}

.back-link {
  display: inline-block;
  margin-top: 28px;
}

@media (max-width: 900px) {
  .app-shell {
    display: block;
  }

  .sidebar {
    box-sizing: border-box;
    width: 100%;
  }

  .grid {
    grid-template-columns: 1fr;
  }
}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src" \
  "${FRONTEND_DIR}/index.html"
then
  echo "ERRO: HTML indevido encontrado no frontend."
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

echo "Subindo frontend..."

docker compose up -d frontend proxy 2>&1 | tee "${DOCKER_UP_LOG}"

sleep 8

echo "Testando dominio raiz..."

DOMAIN_HOME_STATUS="$(curl -L -s -o "${DOMAIN_HOME_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_HOME_URL}" || true)"

if [ "${DOMAIN_HOME_STATUS}" != "200" ]; then
  echo "ERRO: dominio raiz nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Testando dominio login..."

DOMAIN_LOGIN_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_LOGIN_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_LOGIN_URL}" || true)"

if [ "${DOMAIN_LOGIN_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina de login nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

if ! grep -q "SaaS WhatsApp Meta" "${DOMAIN_LOGIN_LOG}"; then
  echo "ERRO: pagina de login nao contem titulo esperado."
  cat "${DOMAIN_LOGIN_LOG}"
  exit 1
fi

echo "Gerando documentacao da Etapa 26..."

cat > "${DOC_FILE}" <<'DOC'
# Frontend Login Integrado

## Visao geral

Este documento registra a criacao da tela de login integrada ao backend real.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- tela de login real
- chamada para auth login
- armazenamento local de access token
- chamada para auth me
- dashboard protegido simples
- logout
- tela placeholder de conversas

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/types/api.types.ts
- apps/frontend/src/types/auth.types.ts
- apps/frontend/src/services/api.ts
- apps/frontend/src/services/auth.service.ts
- apps/frontend/src/stores/auth.store.ts
- apps/frontend/src/pages/login/LoginPage.tsx
- apps/frontend/src/pages/dashboard/DashboardPage.tsx
- apps/frontend/src/pages/conversations/ConversationsPage.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/App.tsx
- apps/frontend/src/styles.css
- docs/FRONTEND_LOGIN_INTEGRADO.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- backend login antes da alteracao
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- teste do dominio raiz
- teste da pagina de login

## Acesso

Dominio:

    https bot lhsolucao com br

Rota de login:

    login

## Observacoes

O login usa o endpoint real do backend.

A senha inicial nao foi documentada aqui.

A senha inicial fica no log local da Etapa 24.

## Proxima etapa sugerida

Etapa 27:

    Criar protecao visual de rotas e layout base do painel
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
- [ ] Etapa 27 - Protecao visual de rotas e layout base

## Ultima etapa executada

Etapa 26 - Frontend login integrado.

## Proxima etapa sugerida

Etapa 27 - Criar protecao visual de rotas e layout base do painel.
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

## Etapas concluidas

- Etapa 01 ate Etapa 26 concluidas

## Proxima etapa

- Etapa 27 - Protecao visual de rotas e layout base
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
Etapa: 26
Acao: Frontend login integrado
Data: $(date '+%Y-%m-%d %H:%M:%S')
Backend login status: ${BACKEND_LOGIN_STATUS}
Dominio raiz status: ${DOMAIN_HOME_STATUS}
Dominio login status: ${DOMAIN_LOGIN_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 26 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br/login"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 27 - Criar protecao visual de rotas e layout base do painel"
