#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_27.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_27_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_27_frontend_build.log"
DOCKER_BUILD_LOG="${LOGS_DIR}/setup_27_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_27_frontend_docker_up.log"
DOMAIN_HOME_LOG="${LOGS_DIR}/setup_27_domain_home.log"
DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_27_domain_login.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_27_domain_dashboard.log"
DOMAIN_CONVERSATIONS_LOG="${LOGS_DIR}/setup_27_domain_conversations.log"
DOC_FILE="${DOCS_DIR}/FRONTEND_LAYOUT_PROTECAO_ROTAS.md"

DOMAIN_HOME_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="https://bot.lhsolucao.com.br/login"
DOMAIN_DASHBOARD_URL="https://bot.lhsolucao.com.br/app/dashboard"
DOMAIN_CONVERSATIONS_URL="https://bot.lhsolucao.com.br/app/conversations"

echo "== Etapa 27: Protecao visual de rotas e layout base =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${FRONTEND_DIR}/src/app"
mkdir -p "${FRONTEND_DIR}/src/components/layout"
mkdir -p "${FRONTEND_DIR}/src/components/feedback"
mkdir -p "${FRONTEND_DIR}/src/pages/dashboard"
mkdir -p "${FRONTEND_DIR}/src/pages/conversations"

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/src/app/ProtectedRoute.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/components/layout/AppLayout.tsx" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/components/layout/Topbar.tsx" \
  "${FRONTEND_DIR}/src/components/feedback/LoadingState.tsx" \
  "${FRONTEND_DIR}/src/components/feedback/UnauthorizedState.tsx" \
  "${FRONTEND_DIR}/src/pages/dashboard/DashboardPage.tsx" \
  "${FRONTEND_DIR}/src/pages/conversations/ConversationsPage.tsx" \
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

echo "Criando LoadingState..."

cat > "${FRONTEND_DIR}/src/components/feedback/LoadingState.tsx" <<'DOC'
type LoadingStateProps = {
  message?: string;
};

export function LoadingState({ message = 'Carregando...' }: LoadingStateProps) {
  return (
    <div className="state-screen">
      <div className="state-card">
        <div className="loader" />
        <p>{message}</p>
      </div>
    </div>
  );
}
DOC

echo "Criando UnauthorizedState..."

cat > "${FRONTEND_DIR}/src/components/feedback/UnauthorizedState.tsx" <<'DOC'
import { Link } from 'react-router-dom';

export function UnauthorizedState() {
  return (
    <main className="state-screen">
      <section className="state-card">
        <h1>Sessao expirada</h1>
        <p>Entre novamente para continuar usando o painel.</p>
        <Link className="primary-link" to="/login">
          Voltar ao login
        </Link>
      </section>
    </main>
  );
}
DOC

echo "Criando ProtectedRoute..."

cat > "${FRONTEND_DIR}/src/app/ProtectedRoute.tsx" <<'DOC'
import { ReactNode, useEffect, useState } from 'react';
import { Navigate } from 'react-router-dom';
import { LoadingState } from '../components/feedback/LoadingState';
import { UnauthorizedState } from '../components/feedback/UnauthorizedState';
import { meRequest } from '../services/auth.service';
import { useAuthStore } from '../stores/auth.store';

type ProtectedRouteProps = {
  children: ReactNode;
};

type RouteState = 'loading' | 'authorized' | 'unauthorized';

export function ProtectedRoute({ children }: ProtectedRouteProps) {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);
  const setSession = useAuthStore((state) => state.setSession);
  const clearSession = useAuthStore((state) => state.clearSession);
  const [routeState, setRouteState] = useState<RouteState>('loading');

  useEffect(() => {
    async function validateSession() {
      const token = accessToken || loadToken();

      if (!token) {
        setRouteState('unauthorized');
        return;
      }

      try {
        const response = await meRequest(token);

        if (!response.success) {
          clearSession();
          setRouteState('unauthorized');
          return;
        }

        setSession(response.data.user, token);
        setRouteState('authorized');
      } catch (_error) {
        clearSession();
        setRouteState('unauthorized');
      }
    }

    void validateSession();
  }, [accessToken, clearSession, loadToken, setSession]);

  if (routeState === 'loading') {
    return <LoadingState message="Validando sessao..." />;
  }

  if (routeState === 'unauthorized') {
    if (!accessToken && !loadToken()) {
      return <Navigate to="/login" replace />;
    }

    return <UnauthorizedState />;
  }

  return <>{children}</>;
}
DOC

echo "Criando Sidebar..."

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

        <NavLink to="/app/conversations">
          Conversas
        </NavLink>
      </nav>
    </aside>
  );
}
DOC

echo "Criando Topbar..."

cat > "${FRONTEND_DIR}/src/components/layout/Topbar.tsx" <<'DOC'
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../stores/auth.store';

export function Topbar() {
  const navigate = useNavigate();
  const user = useAuthStore((state) => state.user);
  const clearSession = useAuthStore((state) => state.clearSession);

  function handleLogout() {
    clearSession();
    navigate('/login');
  }

  return (
    <header className="topbar">
      <div>
        <span className="topbar-label">Painel</span>
        <strong>{user?.name || 'Usuario'}</strong>
      </div>

      <div className="topbar-actions">
        <span>{user?.email}</span>
        <button onClick={handleLogout} type="button">
          Sair
        </button>
      </div>
    </header>
  );
}
DOC

echo "Criando AppLayout..."

cat > "${FRONTEND_DIR}/src/components/layout/AppLayout.tsx" <<'DOC'
import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';

export function AppLayout() {
  return (
    <main className="app-layout">
      <Sidebar />

      <section className="main-panel">
        <Topbar />
        <div className="main-content">
          <Outlet />
        </div>
      </section>
    </main>
  );
}
DOC

echo "Atualizando DashboardPage..."

cat > "${FRONTEND_DIR}/src/pages/dashboard/DashboardPage.tsx" <<'DOC'
import { useAuthStore } from '../../stores/auth.store';

export function DashboardPage() {
  const user = useAuthStore((state) => state.user);

  return (
    <section>
      <div className="page-heading">
        <span>Visao geral</span>
        <h1>Dashboard</h1>
        <p>Bem-vindo ao painel inicial do SaaS WhatsApp Meta.</p>
      </div>

      <div className="dashboard-grid">
        <article className="metric-card">
          <span>Status do sistema</span>
          <strong>Online</strong>
          <p>Dominio, backend e banco respondendo corretamente.</p>
        </article>

        <article className="metric-card">
          <span>Usuario</span>
          <strong>{user?.name || 'Admin'}</strong>
          <p>{user?.email || 'Sessao autenticada'}</p>
        </article>

        <article className="metric-card">
          <span>Perfis</span>
          <strong>{user?.roles.join(', ') || 'owner'}</strong>
          <p>Controle de acesso carregado pelo token.</p>
        </article>

        <article className="metric-card">
          <span>Permissoes</span>
          <strong>{user?.permissions.length || 0}</strong>
          <p>Total de permissoes disponiveis para a sessao atual.</p>
        </article>
      </div>
    </section>
  );
}
DOC

echo "Atualizando ConversationsPage..."

cat > "${FRONTEND_DIR}/src/pages/conversations/ConversationsPage.tsx" <<'DOC'
export function ConversationsPage() {
  return (
    <section>
      <div className="page-heading">
        <span>Atendimento</span>
        <h1>Conversas</h1>
        <p>Modulo de conversas sera implementado nas proximas etapas.</p>
      </div>

      <div className="empty-panel">
        <strong>Nenhuma conversa carregada ainda</strong>
        <p>Em breve esta tela tera a caixa de entrada, filtros, mensagens e resposta pelo WhatsApp.</p>
      </div>
    </section>
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
import { ConversationsPage } from '../pages/conversations/ConversationsPage';
import { LoginPage } from '../pages/login/LoginPage';
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
          <Route path="conversations" element={<ConversationsPage />} />
        </Route>

        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
DOC

echo "Atualizando styles.css..."

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
.topbar button {
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

.app-layout {
  background: #f3f4f6;
  display: flex;
  min-height: 100vh;
}

.sidebar {
  background: #111827;
  color: #ffffff;
  display: flex;
  flex-direction: column;
  gap: 28px;
  padding: 28px;
  width: 270px;
}

.sidebar-header {
  align-items: center;
  display: flex;
  gap: 14px;
}

.sidebar-header strong {
  display: block;
  font-size: 18px;
}

.sidebar-header span {
  color: #d1d5db;
  font-size: 13px;
}

.sidebar-logo {
  align-items: center;
  background: #b91c1c;
  border-radius: 16px;
  color: #ffffff;
  display: flex;
  font-weight: 900;
  height: 48px;
  justify-content: center;
  width: 48px;
}

.sidebar-nav {
  display: grid;
  gap: 10px;
}

.sidebar-nav a {
  border-radius: 14px;
  color: #ffffff;
  padding: 13px 14px;
}

.sidebar-nav a.active {
  background: rgba(255, 255, 255, 0.12);
}

.main-panel {
  display: flex;
  flex: 1;
  flex-direction: column;
  min-width: 0;
}

.topbar {
  align-items: center;
  background: #ffffff;
  border-bottom: 1px solid #e5e7eb;
  display: flex;
  justify-content: space-between;
  padding: 20px 32px;
}

.topbar-label {
  color: #b91c1c;
  display: block;
  font-size: 12px;
  font-weight: 900;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.topbar-actions {
  align-items: center;
  display: flex;
  gap: 16px;
}

.topbar-actions span {
  color: #6b7280;
}

.main-content {
  padding: 34px;
}

.page-heading span {
  color: #b91c1c;
  font-size: 13px;
  font-weight: 900;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.page-heading h1 {
  font-size: 34px;
  margin: 8px 0;
}

.page-heading p {
  color: #6b7280;
}

.dashboard-grid {
  display: grid;
  gap: 20px;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  margin-top: 28px;
}

.metric-card,
.empty-panel,
.state-card {
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
  font-size: 24px;
  margin: 10px 0;
}

.metric-card p,
.empty-panel p,
.state-card p {
  color: #6b7280;
  line-height: 1.5;
}

.empty-panel {
  margin-top: 28px;
}

.state-screen {
  align-items: center;
  background: #f3f4f6;
  display: flex;
  justify-content: center;
  min-height: 100vh;
  padding: 24px;
}

.state-card {
  max-width: 420px;
  text-align: center;
  width: 100%;
}

.loader {
  animation: spin 1s linear infinite;
  border: 4px solid #e5e7eb;
  border-radius: 999px;
  border-top-color: #b91c1c;
  height: 38px;
  margin: 0 auto 16px;
  width: 38px;
}

.primary-link {
  display: inline-block;
  margin-top: 16px;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

@media (max-width: 1100px) {
  .dashboard-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 820px) {
  .app-layout {
    display: block;
  }

  .sidebar {
    box-sizing: border-box;
    width: 100%;
  }

  .topbar {
    align-items: flex-start;
    flex-direction: column;
    gap: 14px;
  }

  .topbar-actions {
    align-items: flex-start;
    flex-direction: column;
  }

  .dashboard-grid {
    grid-template-columns: 1fr;
  }
}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "<a href" \
  "${FRONTEND_DIR}/src/app" \
  "${FRONTEND_DIR}/src/components" \
  "${FRONTEND_DIR}/src/pages" \
  "${FRONTEND_DIR}/src/styles.css"
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

echo "Subindo frontend e proxy..."

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

echo "Testando rota login..."

DOMAIN_LOGIN_STATUS="$(curl -L -s -o "${DOMAIN_LOGIN_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_LOGIN_URL}" || true)"

if [ "${DOMAIN_LOGIN_STATUS}" != "200" ]; then
  echo "ERRO: rota login nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Testando rota dashboard..."

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: rota dashboard nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Testando rota conversations..."

DOMAIN_CONVERSATIONS_STATUS="$(curl -L -s -o "${DOMAIN_CONVERSATIONS_LOG}" -w "%{http_code}" --max-time 30 "${DOMAIN_CONVERSATIONS_URL}" || true)"

if [ "${DOMAIN_CONVERSATIONS_STATUS}" != "200" ]; then
  echo "ERRO: rota conversations nao respondeu 200."
  docker compose logs --tail=120 frontend
  docker compose logs --tail=120 proxy
  exit 1
fi

echo "Gerando documentacao da Etapa 27..."

cat > "${DOC_FILE}" <<'DOC'
# Frontend Layout e Protecao de Rotas

## Visao geral

Este documento registra a criacao da protecao visual de rotas e do layout base do painel.

## Resultado

Status:

    concluido

## Funcionalidades criadas

Funcionalidades:

- ProtectedRoute
- AppLayout
- Sidebar
- Topbar
- LoadingState
- UnauthorizedState
- Dashboard com cards
- Conversations dentro do layout
- Rotas protegidas em app
- Fallback visual para sessao invalida

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/src/app/ProtectedRoute.tsx
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/components/layout/AppLayout.tsx
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/components/layout/Topbar.tsx
- apps/frontend/src/components/feedback/LoadingState.tsx
- apps/frontend/src/components/feedback/UnauthorizedState.tsx
- apps/frontend/src/pages/dashboard/DashboardPage.tsx
- apps/frontend/src/pages/conversations/ConversationsPage.tsx
- apps/frontend/src/styles.css
- docs/FRONTEND_LAYOUT_PROTECAO_ROTAS.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- teste do dominio raiz
- teste da rota login
- teste da rota dashboard
- teste da rota conversations

## Acesso

Login:

    bot lhsolucao com br login

Dashboard:

    bot lhsolucao com br app dashboard

Conversas:

    bot lhsolucao com br app conversations

## Observacoes

A protecao visual valida o token usando auth me.

A proxima etapa pode melhorar a experiencia com refresh token ou iniciar o modulo de conversas.

## Proxima etapa sugerida

Etapa 28:

    Criar modulo backend de usuarios e endpoint de perfil detalhado
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
- [ ] Etapa 28 - Modulo backend de usuarios

## Ultima etapa executada

Etapa 27 - Protecao visual de rotas e layout base.

## Proxima etapa sugerida

Etapa 28 - Criar modulo backend de usuarios e endpoint de perfil detalhado.
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

## Etapas concluidas

- Etapa 01 ate Etapa 27 concluidas

## Proxima etapa

- Etapa 28 - Modulo backend de usuarios
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
Etapa: 27
Acao: Protecao visual de rotas e layout base
Data: $(date '+%Y-%m-%d %H:%M:%S')
Dominio raiz status: ${DOMAIN_HOME_STATUS}
Dominio login status: ${DOMAIN_LOGIN_STATUS}
Dominio dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Dominio conversations status: ${DOMAIN_CONVERSATIONS_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 27 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Acesso:"
echo "https://bot.lhsolucao.com.br/login"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 28 - Criar modulo backend de usuarios e endpoint de perfil detalhado"
