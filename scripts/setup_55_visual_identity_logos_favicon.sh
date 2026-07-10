#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_55.log"
FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_55_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_55_frontend_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_55_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_55_docker_up.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_55_auth_login_domain.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_55_domain_dashboard.log"
DOMAIN_LOGIN_PAGE_LOG="${LOGS_DIR}/setup_55_domain_login_page.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_55_domain_audit_page.log"
DOMAIN_AUDIT_HISTORY_PAGE_LOG="${LOGS_DIR}/setup_55_domain_audit_real_history_page.log"
DOMAIN_FAVICON_LOG="${LOGS_DIR}/setup_55_domain_favicon.log"

DOC_FILE="${DOCS_DIR}/VISUAL_IDENTITY_LOGOS_FAVICON.md"

LOGO_MAIN="${BASE_DIR}/chatbot_logo.png"
LOGO_COMPANY="${BASE_DIR}/favicon.png"
LOGO_ICON="${BASE_DIR}/lh_chatbot_favicon.png"

PUBLIC_DIR="${FRONTEND_DIR}/public"
PUBLIC_ASSETS_DIR="${PUBLIC_DIR}/assets"

DOMAIN_HOST="bot.lhsolucao.com.br"
DOMAIN_BASE_URL="https://${DOMAIN_HOST}"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_LOGIN_PAGE_URL="${DOMAIN_BASE_URL}/login"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"
DOMAIN_AUDIT_HISTORY_PAGE_URL="${DOMAIN_BASE_URL}/app/audit-real-history"
DOMAIN_FAVICON_URL="${DOMAIN_BASE_URL}/favicon.png"

echo "== Etapa 55: Aplicar identidade visual com logos e favicon =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${PUBLIC_ASSETS_DIR}"

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/index.html" \
  "${FRONTEND_DIR}/src/styles.css" \
  "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" \
  "${FRONTEND_DIR}/src/app/routes.tsx" \
  "${FRONTEND_DIR}/src/pages/login/LoginPage.tsx" \
  "${PUBLIC_DIR}/favicon.png" \
  "${PUBLIC_ASSETS_DIR}/chatbot_logo.png" \
  "${PUBLIC_ASSETS_DIR}/favicon.png" \
  "${PUBLIC_ASSETS_DIR}/lh_chatbot_favicon.png" \
  "${DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md" \
  "${BASE_DIR}/CONTEXTO_PROJETO.md" \
  "${BASE_DIR}/CHANGELOG.md" \
  "${BASE_DIR}/DECISOES_TECNICAS.md" \
  "${BASE_DIR}/PENDENCIAS.md"
do
  if [ -f "${file}" ]; then
    base_name="$(basename "${file}")"
    cp "${file}" "${BACKUPS_DIR}/${base_name}_${STAMP}.bak"
  fi
done

echo "Validando ferramentas..."

for tool in node npm docker curl python3; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "ERRO: ferramenta nao encontrada: ${tool}"
    exit 1
  fi
done

if ! docker compose version >/dev/null 2>&1; then
  echo "ERRO: docker compose nao esta disponivel."
  exit 1
fi

echo "Validando logos na raiz do projeto..."

if [ ! -f "${LOGO_MAIN}" ]; then
  echo "ERRO: logo principal ausente: chatbot_logo.png"
  exit 1
fi

if [ ! -f "${LOGO_COMPANY}" ]; then
  echo "ERRO: logo compacto da empresa ausente: favicon.png"
  exit 1
fi

if [ ! -f "${LOGO_ICON}" ]; then
  echo "ERRO: favicon do aplicativo ausente: lh_chatbot_favicon.png"
  exit 1
fi

echo "Copiando logos para o frontend..."

cp "${LOGO_MAIN}" "${PUBLIC_ASSETS_DIR}/chatbot_logo.png"
cp "${LOGO_COMPANY}" "${PUBLIC_ASSETS_DIR}/favicon.png"
cp "${LOGO_ICON}" "${PUBLIC_ASSETS_DIR}/lh_chatbot_favicon.png"
cp "${LOGO_ICON}" "${PUBLIC_DIR}/favicon.png"

if [ ! -s "${PUBLIC_ASSETS_DIR}/chatbot_logo.png" ]; then
  echo "ERRO: copia do logo principal falhou."
  exit 1
fi

if [ ! -s "${PUBLIC_DIR}/favicon.png" ]; then
  echo "ERRO: copia do favicon falhou."
  exit 1
fi

echo "Atualizando index.html com favicon e titulo..."

python3 <<'PY'
from pathlib import Path
import re

path = Path("apps/frontend/index.html")

if not path.exists():
    raise SystemExit("apps/frontend/index.html nao encontrado")

text = path.read_text()

text = re.sub(
    r"<title>.*?</title>",
    "<title>LH Solucao Chat Bot</title>",
    text,
    flags=re.S
)

if 'rel="icon"' in text:
    text = re.sub(
        r'<link[^>]*rel="icon"[^>]*>',
        '/favicon.png',
        text,
        count=1
    )
else:
    text = text.replace(
        "<head>",
        '<head>\n    /favicon.png',
        1
    )

if 'name="theme-color"' not in text:
    text = text.replace(
        "</head>",
        '    <meta name="theme-color" content="#0757c8" />\n  </head>',
        1
    )

path.write_text(text)
PY

echo "Regravando Sidebar com identidade visual..."

cat > "${FRONTEND_DIR}/src/components/layout/Sidebar.tsx" <<'DOC'
import { NavLink } from 'react-router-dom';

export function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        /assets/lh_chatbot_favicon.png
        <div>
          <strong>LH Solucao</strong>
          <span>Chat Bot Meta</span>
        </div>
      </div>

      <nav className="sidebar-nav">
        <NavLink to="/app/dashboard">Dashboard</NavLink>
        <NavLink to="/app/contacts">Contatos</NavLink>
        <NavLink to="/app/conversations">Conversas</NavLink>
        <NavLink to="/app/whatsapp-accounts">WhatsApp</NavLink>
        <NavLink to="/app/meta-settings">Meta</NavLink>
        <NavLink to="/app/audit">Auditoria</NavLink>
        <NavLink to="/app/audit-real-run">Higienizacao real</NavLink>
        <NavLink to="/app/audit-real-history">Historico higiene</NavLink>
        <NavLink to="/app/profile">Perfil</NavLink>
      </nav>
    </aside>
  );
}
DOC

echo "Aplicando CSS da identidade visual..."

cat >> "${FRONTEND_DIR}/src/styles.css" <<'DOC'

/* Etapa 55 - Identidade visual LH Solucao Chat Bot */

:root {
  --lh-blue-950: #04204f;
  --lh-blue-900: #06347d;
  --lh-blue-800: #0757c8;
  --lh-blue-700: #0a6de8;
  --lh-orange-700: #f97316;
  --lh-orange-600: #ff7a00;
  --lh-orange-500: #ff9f1c;
  --lh-green-700: #15803d;
  --lh-green-600: #16a34a;
  --lh-green-500: #22c55e;
  --lh-red-700: #b91c1c;
  --lh-red-600: #dc2626;
  --lh-surface: #ffffff;
  --lh-surface-soft: #f8fafc;
  --lh-border: #e5e7eb;
  --lh-text: #111827;
  --lh-muted: #6b7280;
  --lh-shadow: 0 18px 50px rgba(4, 32, 79, 0.12);
}

html {
  background: var(--lh-surface-soft);
}

body {
  background:
    radial-gradient(circle at top left, rgba(10, 109, 232, 0.12), transparent 34%),
    radial-gradient(circle at bottom right, rgba(34, 197, 94, 0.10), transparent 30%),
    var(--lh-surface-soft);
  color: var(--lh-text);
}

button,
input,
select,
textarea {
  font-family: inherit;
}

button {
  transition: transform 0.15s ease, box-shadow 0.15s ease, opacity 0.15s ease;
}

button:hover:not(:disabled) {
  transform: translateY(-1px);
}

a {
  transition: color 0.15s ease, background 0.15s ease, border-color 0.15s ease;
}

.sidebar {
  background:
    linear-gradient(180deg, rgba(4, 32, 79, 0.98), rgba(6, 52, 125, 0.96)),
    var(--lh-blue-950) !important;
  border-right: 0 !important;
  box-shadow: 12px 0 35px rgba(4, 32, 79, 0.18);
}

.sidebar-header {
  border-bottom: 1px solid rgba(255, 255, 255, 0.14);
  gap: 12px;
  padding-bottom: 20px;
}

.sidebar-brand-icon {
  background: #ffffff;
  border-radius: 18px;
  box-shadow: 0 12px 30px rgba(0, 0, 0, 0.20);
  height: 48px;
  object-fit: contain;
  padding: 6px;
  width: 48px;
}

.sidebar-logo {
  background: #ffffff !important;
  color: var(--lh-blue-900) !important;
}

.sidebar-header strong {
  color: #ffffff !important;
  display: block;
  font-size: 16px;
  letter-spacing: -0.02em;
}

.sidebar-header span {
  color: rgba(255, 255, 255, 0.72) !important;
  display: block;
  font-size: 12px;
  font-weight: 700;
}

.sidebar-nav a {
  border: 1px solid transparent;
  border-radius: 16px;
  color: rgba(255, 255, 255, 0.78) !important;
  font-weight: 850;
  letter-spacing: -0.01em;
}

.sidebar-nav a:hover {
  background: rgba(255, 255, 255, 0.10) !important;
  border-color: rgba(255, 255, 255, 0.16);
  color: #ffffff !important;
}

.sidebar-nav a.active {
  background:
    linear-gradient(135deg, var(--lh-orange-600), var(--lh-orange-500)) !important;
  box-shadow: 0 14px 30px rgba(249, 115, 22, 0.28);
  color: #ffffff !important;
}

.page-heading {
  background:
    linear-gradient(135deg, rgba(7, 87, 200, 0.10), rgba(34, 197, 94, 0.08)),
    #ffffff;
  border: 1px solid var(--lh-border);
  border-radius: 26px;
  box-shadow: var(--lh-shadow);
  padding: 24px;
}

.page-heading span {
  color: var(--lh-orange-700) !important;
  font-weight: 950;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.page-heading h1 {
  color: var(--lh-blue-950);
  letter-spacing: -0.04em;
}

.page-heading p {
  color: var(--lh-muted);
  max-width: 860px;
}

.form-message {
  border-left: 5px solid var(--lh-orange-600);
  box-shadow: var(--lh-shadow);
}

.audit-summary-grid article,
.audit-panel,
.audit-export-toolbar,
.audit-hygiene-panel,
.retention-policy-panel,
.real-hygiene-warning,
.real-hygiene-panel,
.real-hygiene-confirmation,
.real-hygiene-result,
.hygiene-history-summary article,
.hygiene-history-table article,
.hygiene-history-toolbar {
  box-shadow: var(--lh-shadow) !important;
}

.audit-summary-grid article:hover,
.audit-panel:hover,
.hygiene-history-table article:hover {
  transform: translateY(-1px);
}

.audit-filter-form button,
.audit-export-toolbar button,
.hygiene-history-toolbar button,
.retention-policy-panel button,
.audit-hygiene-panel button,
.real-hygiene-panel button,
.real-hygiene-confirmation button {
  background:
    linear-gradient(135deg, var(--lh-blue-800), var(--lh-blue-700)) !important;
  box-shadow: 0 12px 28px rgba(7, 87, 200, 0.22);
}

.audit-export-toolbar button:nth-of-type(1),
.audit-export-toolbar button:nth-of-type(2),
.hygiene-history-toolbar button {
  background:
    linear-gradient(135deg, var(--lh-orange-700), var(--lh-orange-500)) !important;
  box-shadow: 0 12px 28px rgba(249, 115, 22, 0.24);
}

.audit-status-good {
  background: #dcfce7 !important;
  color: #166534 !important;
}

.audit-status-warning {
  background: #fef3c7 !important;
  color: #92400e !important;
}

.audit-status-danger {
  background: #fee2e2 !important;
  color: #991b1b !important;
}

.audit-table article {
  border-left: 4px solid rgba(7, 87, 200, 0.22);
}

.audit-table article:hover {
  border-left-color: var(--lh-orange-600);
}

.login-page,
.auth-page,
.login-screen {
  background:
    radial-gradient(circle at 20% 20%, rgba(255, 122, 0, 0.20), transparent 28%),
    radial-gradient(circle at 80% 15%, rgba(34, 197, 94, 0.14), transparent 26%),
    linear-gradient(135deg, var(--lh-blue-950), var(--lh-blue-800)) !important;
}

.login-card,
.auth-card,
.login-form-card {
  border: 1px solid rgba(255, 255, 255, 0.22) !important;
  box-shadow: 0 24px 70px rgba(4, 32, 79, 0.30) !important;
}

.login-card::before,
.auth-card::before,
.login-form-card::before {
  background-image: url("/assets/chatbot_logo.png");
  background-position: center;
  background-repeat: no-repeat;
  background-size: contain;
  content: "";
  display: block;
  height: 92px;
  margin: 0 auto 18px;
  max-width: 360px;
  width: 100%;
}

.empty-state,
.conversation-empty {
  background:
    linear-gradient(135deg, rgba(7, 87, 200, 0.06), rgba(34, 197, 94, 0.05)),
    #ffffff;
  border: 1px dashed rgba(7, 87, 200, 0.25);
  border-radius: 22px;
}

.empty-state::before,
.conversation-empty::before {
  background-image: url("/assets/lh_chatbot_favicon.png");
  background-position: center;
  background-repeat: no-repeat;
  background-size: contain;
  content: "";
  display: block;
  height: 52px;
  margin: 0 auto 12px;
  width: 52px;
}

@media (max-width: 1100px) {
  .page-heading {
    border-radius: 22px;
    padding: 20px;
  }

  .sidebar-brand-icon {
    height: 42px;
    width: 42px;
  }
}

@media (max-width: 760px) {
  body {
    background: #f8fafc;
  }

  .page-heading {
    padding: 18px;
  }

  .page-heading h1 {
    font-size: clamp(24px, 8vw, 34px);
  }

  .sidebar {
    box-shadow: none;
  }

  .sidebar-nav a {
    min-height: 44px;
  }

  .audit-table article,
  .hygiene-history-table article {
    border-left-width: 3px;
  }
}

@media (prefers-reduced-motion: reduce) {
  button,
  a,
  .audit-summary-grid article,
  .audit-panel,
  .hygiene-history-table article {
    transition: none !important;
  }

  button:hover:not(:disabled),
  .audit-summary-grid article:hover,
  .audit-panel:hover,
  .hygiene-history-table article:hover {
    transform: none !important;
  }
}
DOC

echo "Validando arquivos sem HTML indevido..."

if grep -R "&1 | tee "${FRONTEND_TYPECHECK_LOG}"

echo "Rodando build do frontend..."

npm run build 2>&1 | tee "${FRONTEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando frontend..."

docker compose build frontend 2>&1 | tee "${DOCKER_FRONTEND_BUILD_LOG}"

echo "Subindo frontend e proxy..."

docker compose up -d frontend proxy 2>&1 | tee "${DOCKER_UP_LOG}"

sleep 8

echo "Validando dominio..."

LOGIN_PAYLOAD="$(node -e "console.log(JSON.stringify({email: process.argv[1], password: process.argv[2]}))" "$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)" "$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)")"

DOMAIN_LOGIN_STATUS="$(curl -L -s -o "${DOMAIN_LOGIN_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Content-Type: application/json" \
  -d "${LOGIN_PAYLOAD}" \
  "${DOMAIN_LOGIN_URL}" || true)"

if [ "${DOMAIN_LOGIN_STATUS}" != "200" ] && [ "${DOMAIN_LOGIN_STATUS}" != "201" ]; then
  echo "ERRO: login dominio falhou. Status ${DOMAIN_LOGIN_STATUS}"
  cat "${DOMAIN_LOGIN_LOG}"
  exit 1
fi

DOMAIN_LOGIN_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_LOGIN_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_LOGIN_PAGE_URL}" || true)"

if [ "${DOMAIN_LOGIN_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina login nao respondeu 200."
  exit 1
fi

DOMAIN_FAVICON_STATUS="$(curl -L -s -o "${DOMAIN_FAVICON_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_FAVICON_URL}" || true)"

if [ "${DOMAIN_FAVICON_STATUS}" != "200" ]; then
  echo "ERRO: favicon nao respondeu 200."
  exit 1
fi

if [ ! -s "${DOMAIN_FAVICON_LOG}" ]; then
  echo "ERRO: favicon retornou arquivo vazio."
  exit 1
fi

DOMAIN_DASHBOARD_STATUS="$(curl -L -s -o "${DOMAIN_DASHBOARD_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_DASHBOARD_URL}" || true)"

if [ "${DOMAIN_DASHBOARD_STATUS}" != "200" ]; then
  echo "ERRO: dashboard nao respondeu 200."
  exit 1
fi

DOMAIN_AUDIT_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_PAGE_URL}" || true)"

if [ "${DOMAIN_AUDIT_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: auditoria nao respondeu 200."
  exit 1
fi

DOMAIN_AUDIT_HISTORY_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_AUDIT_HISTORY_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_AUDIT_HISTORY_PAGE_URL}" || true)"

if [ "${DOMAIN_AUDIT_HISTORY_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: historico auditoria nao respondeu 200."
  exit 1
fi

echo "Gerando documentacao da Etapa 55..."

cat > "${DOC_FILE}" <<'DOC'
# Visual Identity Logos Favicon

## Visao geral

Este documento registra a aplicacao inicial da identidade visual com logos e favicon.

## Resultado

Status:

    concluido

## Funcionalidades aplicadas

Funcionalidades:

- copia dos logos para o frontend
- configuracao do favicon do navegador
- titulo do aplicativo como LH Solucao Chat Bot
- sidebar com icone visual do aplicativo
- paleta visual baseada nos logos
- botoes com destaque azul e laranja
- cards com sombra profissional
- melhorias responsivas base
- estados vazios com icone do chatbot
- melhoria visual da tela de login por CSS sem alterar logica de autenticacao

## Logos usados

Arquivos de origem:

- chatbot_logo.png
- favicon.png
- lh_chatbot_favicon.png

Arquivos publicados:

- apps/frontend/public/assets/chatbot_logo.png
- apps/frontend/public/assets/favicon.png
- apps/frontend/public/assets/lh_chatbot_favicon.png
- apps/frontend/public/favicon.png

## Cores principais

Cores:

- azul institucional
- laranja de destaque
- verde operacional
- branco para superficies
- cinza para textos
- vermelho para alertas e erros

## Arquivos criados ou alterados

Arquivos:

- apps/frontend/index.html
- apps/frontend/public/favicon.png
- apps/frontend/public/assets/chatbot_logo.png
- apps/frontend/public/assets/favicon.png
- apps/frontend/public/assets/lh_chatbot_favicon.png
- apps/frontend/src/components/layout/Sidebar.tsx
- apps/frontend/src/styles.css
- docs/VISUAL_IDENTITY_LOGOS_FAVICON.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- existencia dos logos na raiz
- copia dos logos para public assets
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build frontend
- docker compose up frontend proxy
- login dominio
- pagina login dominio
- favicon dominio
- dashboard dominio
- auditoria dominio
- historico auditoria dominio

## Logs gerados

Logs:

- logs/setup_55_frontend_typecheck.log
- logs/setup_55_frontend_build.log
- logs/setup_55_frontend_docker_build.log
- logs/setup_55_docker_up.log
- logs/setup_55_auth_login_domain.log
- logs/setup_55_domain_login_page.log
- logs/setup_55_domain_favicon.log
- logs/setup_55_domain_dashboard.log
- logs/setup_55_domain_audit_page.log
- logs/setup_55_domain_audit_real_history_page.log
- logs/setup_55.log

## Proxima etapa sugerida

Etapa 56:

    Criar layout responsivo profissional da central de atendimento
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 55 - Aplicar identidade visual com logos e favicon",
    "- [x] Etapa 55 - Aplicar identidade visual com logos e favicon\n- [ ] Etapa 56 - Criar layout responsivo profissional da central de atendimento"
)

text = text.replace(
    "Etapa 55 - Aplicar identidade visual com logos e favicon.",
    "Etapa 56 - Criar layout responsivo profissional da central de atendimento."
)

text = text.replace(
    "Etapa 54 - Planejamento da proxima fase funcional do produto.",
    "Etapa 55 - Aplicar identidade visual com logos e favicon."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Identidade visual com logos e favicon aplicada." not in text:
    text = text.replace(
        "Planejamento da proxima fase funcional do produto criado.",
        "Planejamento da proxima fase funcional do produto criado.\n\nIdentidade visual com logos e favicon aplicada."
    )

if "- docs/VISUAL_IDENTITY_LOGOS_FAVICON.md" not in text:
    text = text.replace(
        "- docs/NEXT_FUNCTIONAL_PHASE_PLAN.md",
        "- docs/VISUAL_IDENTITY_LOGOS_FAVICON.md\n- docs/NEXT_FUNCTIONAL_PHASE_PLAN.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 54 concluidas",
    "- Etapa 01 ate Etapa 55 concluidas"
)

text = text.replace(
    "- Etapa 55 - Aplicar identidade visual com logos e favicon",
    "- Etapa 56 - Criar layout responsivo profissional da central de atendimento"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 55 - Aplicar identidade visual com logos e favicon
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Aplicados logos do projeto ao frontend, configurado favicon, atualizada sidebar e adicionada paleta visual baseada na identidade LH Solucao Chat Bot.
DOC
  fi
done

echo "Validando documentos finais..."

for file in \
  "${DOC_FILE}" \
  "${BASE_DIR}/00_CONTROLE.md" \
  "${BASE_DIR}/MANIFESTO.md"
do
  if [ ! -f "${file}" ]; then
    echo "ERRO: arquivo final ausente: ${file}"
    exit 1
  fi
done

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
Etapa: 55
Acao: Aplicar identidade visual com logos e favicon
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Login page status: ${DOMAIN_LOGIN_PAGE_STATUS}
Favicon status: ${DOMAIN_FAVICON_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Audit history page status: ${DOMAIN_AUDIT_HISTORY_PAGE_STATUS}
Status: Concluido
DOC

echo ""
echo "== Etapa 55 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 56 - Criar layout responsivo profissional da central de atendimento"
