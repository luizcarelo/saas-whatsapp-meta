#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
SCRIPTS_DIR="${BASE_DIR}/scripts"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${LOGS_DIR}/setup_14.log"
FRONTEND_BASE_DOC="${DOCS_DIR}/FRONTEND_BASE.md"

echo "== Etapa 14: Arquivos base do frontend =="

cd "${BASE_DIR}"

mkdir -p "${FRONTEND_DIR}/src"
mkdir -p "${FRONTEND_DIR}/src/app"
mkdir -p "${FRONTEND_DIR}/src/components"
mkdir -p "${FRONTEND_DIR}/src/components/layout"
mkdir -p "${FRONTEND_DIR}/src/components/ui"
mkdir -p "${FRONTEND_DIR}/src/pages"
mkdir -p "${FRONTEND_DIR}/src/pages/login"
mkdir -p "${FRONTEND_DIR}/src/pages/dashboard"
mkdir -p "${FRONTEND_DIR}/src/pages/conversations"
mkdir -p "${FRONTEND_DIR}/src/services"
mkdir -p "${FRONTEND_DIR}/src/stores"
mkdir -p "${FRONTEND_DIR}/src/hooks"
mkdir -p "${FRONTEND_DIR}/src/schemas"
mkdir -p "${FRONTEND_DIR}/src/types"
mkdir -p "${FRONTEND_DIR}/src/utils"
mkdir -p "${FRONTEND_DIR}/public"
mkdir -p "${DOCS_DIR}"
mkdir -p "${SCRIPTS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/package.json" \
  "${FRONTEND_DIR}/tsconfig.json" \
  "${FRONTEND_DIR}/tsconfig.node.json" \
  "${FRONTEND_DIR}/index.html" \
  "${FRONTEND_DIR}/vite.config.ts" \
  "${FRONTEND_DIR}/src/main.tsx" \
  "${FRONTEND_DIR}/src/App.tsx" \
  "${FRONTEND_DIR}/src/styles.css" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/app/providers.tsx" \
  "${FRONTEND_DIR}/src/services/api.ts" \
  "${FRONTEND_DIR}/src/stores/auth.store.ts" \
  "${FRONTEND_DIR}/src/types/api.types.ts" \
  "${FRONTEND_BASE_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Gerando apps/frontend/package.json..."

cat > "${FRONTEND_DIR}/package.json" <<'DOC'
{
  "name": "saas-whatsapp-meta-frontend",
  "version": "0.1.0",
  "private": true,
  "description": "Frontend do SaaS de Chatbot WhatsApp com API Oficial da Meta",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "lint": "eslint .",
    "typecheck": "tsc -b"
  },
  "dependencies": {
    "@vitejs/plugin-react": "latest",
    "vite": "latest",
    "typescript": "latest",
    "react": "latest",
    "react-dom": "latest",
    "react-router-dom": "latest",
    "@tanstack/react-query": "latest",
    "zustand": "latest",
    "zod": "latest",
    "react-hook-form": "latest",
    "@hookform/resolvers": "latest",
    "socket.io-client": "latest"
  },
  "devDependencies": {
    "@types/react": "latest",
    "@types/react-dom": "latest",
    "eslint": "latest"
  }
}
DOC

echo "Gerando apps/frontend/tsconfig.json..."

cat > "${FRONTEND_DIR}/tsconfig.json" <<'DOC'
{
  "compilerOptions": {
    "target": "ES2021",
    "useDefineForClassFields": true,
    "lib": [
      "ES2021",
      "DOM",
      "DOM.Iterable"
    ],
    "allowJs": false,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "module": "ESNext",
    "moduleResolution": "Node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx"
  },
  "include": [
    "src"
  ],
  "references": [
    {
      "path": "./tsconfig.node.json"
    }
  ]
}
DOC

echo "Gerando apps/frontend/tsconfig.node.json..."

cat > "${FRONTEND_DIR}/tsconfig.node.json" <<'DOC'
{
  "compilerOptions": {
    "composite": true,
    "module": "ESNext",
    "moduleResolution": "Node",
    "allowSyntheticDefaultImports": true
  },
  "include": [
    "vite.config.ts"
  ]
}
DOC

echo "Gerando apps/frontend/index.html..."

cat > "${FRONTEND_DIR}/index.html" <<'DOC'
<!doctype html>
<html lang="pt-BR">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>SaaS WhatsApp Meta</title>
  </head>
  <body>
    <div id="root"></div>
    /src/main.tsxscript>
  </body>
</html>
DOC

echo "Gerando apps/frontend/vite.config.ts..."

cat > "${FRONTEND_DIR}/vite.config.ts" <<'DOC'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [
    react()
  ],
  server: {
    host: '0.0.0.0',
    port: 5173
  }
});
DOC

echo "Gerando apps/frontend/src/main.tsx..."

cat > "${FRONTEND_DIR}/src/main.tsx" <<'DOC'
import React from 'react';
import ReactDOM from 'react-dom/client';
import { AppProviders } from './app/providers';
import { App } from './App';
import './styles.css';

const rootElement = document.getElementById('root');

if (!rootElement) {
  throw new Error('Elemento root nao encontrado');
}

ReactDOM.createRoot(rootElement).render(
  <React.StrictMode>
    <AppProviders>
      <App />
    </AppProviders>
  </React.StrictMode>
);
DOC

echo "Gerando apps/frontend/src/App.tsx..."

cat > "${FRONTEND_DIR}/src/App.tsx" <<'DOC'
import { AppRoutes } from './app/routes';

export function App() {
  return <AppRoutes />;
}
DOC

echo "Gerando apps/frontend/src/app/providers.tsx..."

cat > "${FRONTEND_DIR}/src/app/providers.tsx" <<'DOC'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import type { ReactNode } from 'react';

const queryClient = new QueryClient();

type AppProvidersProps = {
  children: ReactNode;
};

export function AppProviders({ children }: AppProvidersProps) {
  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
}
DOC

echo "Gerando apps/frontend/src/app/routes.tsx..."

cat > "${FRONTEND_DIR}/src/app/routes.tsx" <<'DOC'
import {
  BrowserRouter,
  Link,
  Navigate,
  Route,
  Routes
} from 'react-router-dom';

function LoginPage() {
  return (
    <main className="page">
      <section className="card">
        <h1>SaaS WhatsApp Meta</h1>
        <p>Login do sistema sera implementado em etapa futura.</p>
        <Link to="/app/dashboard">Entrar no painel demonstrativo</Link>
      </section>
    </main>
  );
}

function DashboardPage() {
  return (
    <main className="page">
      <section className="card">
        <h1>Dashboard</h1>
        <p>Frontend base criado com React, TypeScript e Vite.</p>
        <nav className="nav">
          <Link to="/app/conversations">Conversas</Link>
          <Link to="/login">Sair</Link>
        </nav>
      </section>
    </main>
  );
}

function ConversationsPage() {
  return (
    <main className="page">
      <section className="card">
        <h1>Conversas</h1>
        <p>Tela de conversas sera implementada em etapa futura.</p>
        <Link to="/app/dashboard">Voltar ao dashboard</Link>
      </section>
    </main>
  );
}

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

echo "Gerando apps/frontend/src/services/api.ts..."

cat > "${FRONTEND_DIR}/src/services/api.ts" <<'DOC'
import type { ApiResponse } from '../types/api.types';

const apiBaseUrl = import.meta.env.VITE_API_URL || 'http://localhost:3000/api/v1';

type RequestOptions = {
  token?: string;
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

echo "Gerando apps/frontend/src/stores/auth.store.ts..."

cat > "${FRONTEND_DIR}/src/stores/auth.store.ts" <<'DOC'
import { create } from 'zustand';

type AuthUser = {
  id: string;
  name: string;
  email: string;
};

type AuthState = {
  user: AuthUser | null;
  accessToken: string | null;
  setSession: (user: AuthUser, accessToken: string) => void;
  clearSession: () => void;
};

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  accessToken: null,
  setSession: (user, accessToken) => set({
    user,
    accessToken
  }),
  clearSession: () => set({
    user: null,
    accessToken: null
  })
}));
DOC

echo "Gerando apps/frontend/src/types/api.types.ts..."

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

echo "Gerando apps/frontend/src/styles.css..."

cat > "${FRONTEND_DIR}/src/styles.css" <<'DOC'
:root {
  color: #111827;
  background: #f3f4f6;
  font-family: Arial, Helvetica, sans-serif;
}

body {
  margin: 0;
}

a {
  color: #b91c1c;
  font-weight: 600;
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

.card {
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 16px;
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.08);
  max-width: 520px;
  padding: 32px;
  width: 100%;
}

.card h1 {
  margin-top: 0;
}

.nav {
  display: flex;
  gap: 16px;
  margin-top: 24px;
}
DOC

echo "Criando marcadores .gitkeep..."

for dir in \
  "${FRONTEND_DIR}/src/components" \
  "${FRONTEND_DIR}/src/components/layout" \
  "${FRONTEND_DIR}/src/components/ui" \
  "${FRONTEND_DIR}/src/pages" \
  "${FRONTEND_DIR}/src/pages/login" \
  "${FRONTEND_DIR}/src/pages/dashboard" \
  "${FRONTEND_DIR}/src/pages/conversations" \
  "${FRONTEND_DIR}/src/hooks" \
  "${FRONTEND_DIR}/src/schemas" \
  "${FRONTEND_DIR}/src/utils" \
  "${FRONTEND_DIR}/public"
do
  touch "${dir}/.gitkeep"
done

echo "Gerando docs/FRONTEND_BASE.md..."

cat > "${FRONTEND_BASE_DOC}" <<'DOC'
# Frontend Base

## Visao geral

Este documento registra a criacao dos arquivos base do frontend.

A Etapa 14 preparou uma base inicial para o frontend React, TypeScript e Vite.

## Objetivo

Preparar os arquivos minimos para receber a implementacao real do painel web nas proximas etapas.

## Arquivos criados

Arquivos principais:

- apps/frontend/package.json
- apps/frontend/tsconfig.json
- apps/frontend/tsconfig.node.json
- apps/frontend/index.html
- apps/frontend/vite.config.ts
- apps/frontend/src/main.tsx
- apps/frontend/src/App.tsx
- apps/frontend/src/styles.css
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/app/providers.tsx
- apps/frontend/src/services/api.ts
- apps/frontend/src/stores/auth.store.ts
- apps/frontend/src/types/api.types.ts

## Pastas criadas

Pastas:

- apps/frontend/src/app
- apps/frontend/src/components
- apps/frontend/src/components/layout
- apps/frontend/src/components/ui
- apps/frontend/src/pages
- apps/frontend/src/pages/login
- apps/frontend/src/pages/dashboard
- apps/frontend/src/pages/conversations
- apps/frontend/src/services
- apps/frontend/src/stores
- apps/frontend/src/hooks
- apps/frontend/src/schemas
- apps/frontend/src/types
- apps/frontend/src/utils
- apps/frontend/public

## Rotas iniciais

Rotas criadas:

- /
- /login
- /app/dashboard
- /app/conversations

## Observacoes

Nesta etapa ainda nao foram instaladas dependencias.

Nesta etapa ainda nao foi executado npm install.

Nesta etapa ainda nao foi criado Dockerfile.

Nesta etapa ainda nao foi implementado login real.

Nesta etapa ainda nao foi implementado chat real.

## Proximas etapas sugeridas

Etapa 15:

    Criar Docker Compose inicial

Etapa 16:

    Criar arquivo env example

Etapa 17:

    Validar ambiente inicial

Etapa futura do frontend:

    Instalar dependencias e validar build do frontend

## Decisao final desta etapa

O frontend agora possui uma base inicial com React, TypeScript, Vite, rotas simples, provider de query, cliente HTTP base, store de autenticacao e tipos padronizados de API.
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
- [ ] Etapa 15 - Docker Compose inicial
- [ ] Etapa 16 - Arquivo env example
- [ ] Etapa 17 - Validacao do ambiente inicial

## Ultima etapa executada

Etapa 14 - Arquivos base do frontend.

## Proxima etapa sugerida

Etapa 15 - Criar Docker Compose inicial.
DOC

echo "Atualizando MANIFESTO.md..."

cat > "${BASE_DIR}/MANIFESTO.md" <<'DOC'
# Manifesto do Projeto

## Projeto

SaaS de Chatbot WhatsApp com API Oficial da Meta

## Status

Documentacao inicial concluida.

Estrutura real do monorepo iniciada.

Backend base criado.

Frontend base criado.

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
- docs/VALIDACAO_FINAL.md
- docs/ESTRUTURA_PROJETO.md
- docs/BACKEND_BASE.md
- docs/FRONTEND_BASE.md

## Estrutura real criada

- apps/backend
- apps/frontend
- apps/worker
- packages/shared
- packages/types
- packages/config
- infra/docker
- infra/nginx
- infra/postgres
- infra/redis
- infra/scripts

## Backend base

- apps/backend/package.json
- apps/backend/tsconfig.json
- apps/backend/src/main.ts
- apps/backend/src/app.module.ts
- apps/backend/src/health.controller.ts
- apps/backend/src/config/app.config.ts
- apps/backend/src/config/env.example.ts
- apps/backend/src/common/README.md

## Frontend base

- apps/frontend/package.json
- apps/frontend/tsconfig.json
- apps/frontend/tsconfig.node.json
- apps/frontend/index.html
- apps/frontend/vite.config.ts
- apps/frontend/src/main.tsx
- apps/frontend/src/App.tsx
- apps/frontend/src/styles.css
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/app/providers.tsx
- apps/frontend/src/services/api.ts
- apps/frontend/src/stores/auth.store.ts
- apps/frontend/src/types/api.types.ts

## Pastas de apoio

- scripts/
- logs/
- backups/

## Proxima etapa

- Etapa 15 - Docker Compose inicial

## Arquivos atualizados na Etapa 14

- apps/frontend/package.json
- apps/frontend/tsconfig.json
- apps/frontend/tsconfig.node.json
- apps/frontend/index.html
- apps/frontend/vite.config.ts
- apps/frontend/src/main.tsx
- apps/frontend/src/App.tsx
- apps/frontend/src/styles.css
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/app/providers.tsx
- apps/frontend/src/services/api.ts
- apps/frontend/src/stores/auth.store.ts
- apps/frontend/src/types/api.types.ts
- docs/FRONTEND_BASE.md
- 00_CONTROLE.md
- MANIFESTO.md
- logs/setup_14.log
DOC

echo "Validando arquivos criados..."

test -f "${FRONTEND_DIR}/package.json"
test -f "${FRONTEND_DIR}/tsconfig.json"
test -f "${FRONTEND_DIR}/tsconfig.node.json"
test -f "${FRONTEND_DIR}/index.html"
test -f "${FRONTEND_DIR}/vite.config.ts"
test -f "${FRONTEND_DIR}/src/main.tsx"
test -f "${FRONTEND_DIR}/src/App.tsx"
test -f "${FRONTEND_DIR}/src/styles.css"
test -f "${FRONTEND_DIR}/src/app/routes.tsx"
test -f "${FRONTEND_DIR}/src/app/providers.tsx"
test -f "${FRONTEND_DIR}/src/services/api.ts"
test -f "${FRONTEND_DIR}/src/stores/auth.store.ts"
test -f "${FRONTEND_DIR}/src/types/api.types.ts"
test -f "${FRONTEND_BASE_DOC}"
test -f "${BASE_DIR}/00_CONTROLE.md"
test -f "${BASE_DIR}/MANIFESTO.md"

echo "Validando ausencia de caractere proibido nos arquivos gerados..."

BAD_CHAR="$(printf '\052')"

if grep -n "${BAD_CHAR}" \
  "${FRONTEND_DIR}/package.json" \
  "${FRONTEND_DIR}/tsconfig.json" \
  "${FRONTEND_DIR}/tsconfig.node.json" \
  "${FRONTEND_DIR}/index.html" \
  "${FRONTEND_DIR}/vite.config.ts" \
  "${FRONTEND_DIR}/src/main.tsx" \
  "${FRONTEND_DIR}/src/App.tsx" \
  "${FRONTEND_DIR}/src/styles.css" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/app/providers.tsx" \
  "${FRONTEND_DIR}/src/services/api.ts" \
  "${FRONTEND_DIR}/src/stores/auth.store.ts" \
  "${FRONTEND_DIR}/src/types/api.types.ts" \
  "${FRONTEND_BASE_DOC}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
then
  echo "ERRO: caractere proibido encontrado nos arquivos gerados."
  exit 1
fi

echo "Gravando log..."

cat > "${LOG_FILE}" <<DOC
Etapa: 14
Acao: Arquivos base do frontend
Data: $(date '+%Y-%m-%d %H:%M:%S')
Pasta: ${BASE_DIR}
Arquivos criados ou atualizados:
- apps/frontend/package.json
- apps/frontend/tsconfig.json
- apps/frontend/tsconfig.node.json
- apps/frontend/index.html
- apps/frontend/vite.config.ts
- apps/frontend/src/main.tsx
- apps/frontend/src/App.tsx
- apps/frontend/src/styles.css
- apps/frontend/src/app/routes.tsx
- apps/frontend/src/app/providers.tsx
- apps/frontend/src/services/api.ts
- apps/frontend/src/stores/auth.store.ts
- apps/frontend/src/types/api.types.ts
- docs/FRONTEND_BASE.md
- 00_CONTROLE.md
- MANIFESTO.md
Status: Concluido
DOC

echo ""
echo "== Etapa 14 concluida com sucesso =="
echo ""
echo "Arquivos do frontend:"
find "${FRONTEND_DIR}" -maxdepth 4 -type f | sort
echo ""
echo "Resumo de docs/FRONTEND_BASE.md:"
sed -n '1,180p' "${FRONTEND_BASE_DOC}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 15 - Criar Docker Compose inicial"
