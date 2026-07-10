#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="saas-whatsapp-meta"
BASE_DIR="${HOME}/${PROJECT_NAME}"
FRONTEND_DIR="${BASE_DIR}/apps/frontend"
DOCS_DIR="${BASE_DIR}/docs"
LOGS_DIR="${BASE_DIR}/logs"
BACKUPS_DIR="${BASE_DIR}/backups"
STAMP="$(date '+%Y%m%d_%H%M%S')"

LOG_FILE="${LOGS_DIR}/setup_60.log"
FIX_LOG_FILE="${LOGS_DIR}/fix_60_inbox_quick_replies_frontend.log"

FRONTEND_TYPECHECK_LOG="${LOGS_DIR}/setup_60_frontend_typecheck.log"
FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_60_frontend_build.log"
DOCKER_BACKEND_BUILD_LOG="${LOGS_DIR}/setup_60_backend_docker_build.log"
DOCKER_FRONTEND_BUILD_LOG="${LOGS_DIR}/setup_60_frontend_docker_build.log"
DOCKER_UP_LOG="${LOGS_DIR}/setup_60_docker_up.log"
BACKEND_WAIT_LOG="${LOGS_DIR}/setup_60_backend_wait.log"
BACKEND_CRASH_LOG="${LOGS_DIR}/setup_60_backend_crash.log"

DOMAIN_LOGIN_LOG="${LOGS_DIR}/setup_60_auth_login_domain.log"
DOMAIN_QUICK_REPLIES_LOG="${LOGS_DIR}/setup_60_quick_replies_domain.log"
DOMAIN_QUICK_REPLY_CREATE_LOG="${LOGS_DIR}/setup_60_quick_reply_create_domain.log"
DOMAIN_INBOX_PAGE_LOG="${LOGS_DIR}/setup_60_domain_inbox_page.log"
DOMAIN_DASHBOARD_LOG="${LOGS_DIR}/setup_60_domain_dashboard.log"
DOMAIN_AUDIT_PAGE_LOG="${LOGS_DIR}/setup_60_domain_audit_page.log"

DOC_FILE="${DOCS_DIR}/ATTENDANCE_QUICK_REPLIES.md"

DOMAIN_BASE_URL="https://bot.lhsolucao.com.br"
DOMAIN_LOGIN_URL="${DOMAIN_BASE_URL}/api/v1/auth/login"
DOMAIN_ATTENDANCE_URL="${DOMAIN_BASE_URL}/api/v1/attendance"
DOMAIN_INBOX_PAGE_URL="${DOMAIN_BASE_URL}/app/inbox"
DOMAIN_DASHBOARD_URL="${DOMAIN_BASE_URL}/app/dashboard"
DOMAIN_AUDIT_PAGE_URL="${DOMAIN_BASE_URL}/app/audit"

echo "== Fix final Etapa 60: Inbox respostas rapidas =="

cd "${BASE_DIR}"

mkdir -p "${DOCS_DIR}"
mkdir -p "${LOGS_DIR}"
mkdir -p "${BACKUPS_DIR}"
mkdir -p "${FRONTEND_DIR}/src/pages/inbox"

echo "Criando backups..."

for file in \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/services/attendance.service.ts" \
  "${FRONTEND_DIR}/src/types/attendance.types.ts" \
  "${FRONTEND_DIR}/src/styles.css" \
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

echo "Regravando InboxPage.tsx completo e seguro..."

cat > "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" <<'TSX'
import { FormEvent, useEffect, useMemo, useState } from 'react';
import {
  assignAttendanceConversationRequest,
  createAttendanceDepartmentRequest,
  createAttendanceQuickReplyRequest,
  getAttendanceStatusOptionsRequest,
  listAttendanceConversationsRequest,
  listAttendanceDepartmentsRequest,
  listAttendanceQuickRepliesRequest,
  updateAttendanceConversationStatusRequest
} from '../../services/attendance.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
  AttendanceConversationItem,
  AttendanceDepartmentItem,
  AttendanceQuickReplyItem
} from '../../types/attendance.types';

const fallbackConversations: AttendanceConversationItem[] = [
  {
    id: 'demo-001',
    contactName: 'Cliente Comercial',
    contactPhone: '5521999990001',
    departmentName: 'Comercial',
    status: 'novo',
    assignedUserId: null,
    assignedUserName: 'Sem responsavel',
    priority: 'alta',
    unreadCount: 3,
    lastMessage: 'Gostaria de receber uma proposta.',
    lastMessageAt: null,
    updatedAt: new Date().toISOString()
  }
];

const fallbackDepartments: AttendanceDepartmentItem[] = [
  {
    id: 'fallback-geral',
    name: 'Fila geral',
    slug: 'fila-geral',
    color: '#0757c8',
    isActive: true,
    sortOrder: 1,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  }
];

const fallbackQuickReplies = [
  'Ola. Como posso ajudar?',
  'Pode me informar seu nome completo?',
  'Vou encaminhar seu atendimento para o departamento responsavel.',
  'Seu atendimento foi finalizado. Avalie de 1 a 5.'
];

const statusLabels: Record<string, string> = {
  novo: 'Novo',
  em_atendimento: 'Em atendimento',
  aguardando_cliente: 'Aguardando cliente',
  aguardando_interno: 'Aguardando interno',
  resolvido: 'Resolvido',
  encerrado: 'Encerrado',
  arquivado: 'Arquivado'
};

const priorityLabels: Record<string, string> = {
  baixa: 'Baixa',
  normal: 'Normal',
  media: 'Media',
  alta: 'Alta',
  urgente: 'Urgente'
};

export function InboxPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [selectedQueue, setSelectedQueue] = useState('Fila geral');
  const [selectedConversationId, setSelectedConversationId] = useState('');
  const [conversations, setConversations] = useState<AttendanceConversationItem[]>(fallbackConversations);
  const [departments, setDepartments] = useState<AttendanceDepartmentItem[]>(fallbackDepartments);
  const [quickReplies, setQuickReplies] = useState<AttendanceQuickReplyItem[]>([]);
  const [statusOptions, setStatusOptions] = useState<Array<{ value: string; label: string }>>([]);
  const [priorityOptions, setPriorityOptions] = useState<Array<{ value: string; label: string }>>([]);
  const [newDepartmentName, setNewDepartmentName] = useState('');
  const [newQuickReplyTitle, setNewQuickReplyTitle] = useState('');
  const [newQuickReplyMessage, setNewQuickReplyMessage] = useState('');
  const [assigneeName, setAssigneeName] = useState('');
  const [composerText, setComposerText] = useState('');
  const [notice, setNotice] = useState('');
  const [loading, setLoading] = useState(true);

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadInbox() {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setNotice('');

    const [
      listResponse,
      optionsResponse,
      departmentsResponse,
      quickRepliesResponse
    ] = await Promise.all([
      listAttendanceConversationsRequest(token),
      getAttendanceStatusOptionsRequest(token),
      listAttendanceDepartmentsRequest(token),
      listAttendanceQuickRepliesRequest(token)
    ]);

    if (departmentsResponse.success && departmentsResponse.data.departments.length > 0) {
      setDepartments(departmentsResponse.data.departments.filter((item) => item.isActive));
    }

    if (quickRepliesResponse.success) {
      setQuickReplies(quickRepliesResponse.data.quickReplies);
    }

    if (listResponse.success && listResponse.data.conversations.length > 0) {
      setConversations(listResponse.data.conversations);
      setSelectedConversationId((current) => current || listResponse.data.conversations[0].id);
    } else if (listResponse.success) {
      setConversations(fallbackConversations);
      setSelectedConversationId((current) => current || fallbackConversations[0].id);
      setNotice('Nenhuma conversa real encontrada. Exibindo estrutura visual de exemplo.');
    } else {
      setNotice(listResponse.error.message || 'Nao foi possivel carregar conversas reais.');
    }

    if (optionsResponse.success) {
      setStatusOptions(optionsResponse.data.statuses);
      setPriorityOptions(optionsResponse.data.priorities);
    }

    setLoading(false);
  }

  useEffect(() => {
    void loadInbox();
  }, []);

  const selectedConversation = useMemo(() => {
    return conversations.find((item) => item.id === selectedConversationId) || conversations[0] || fallbackConversations[0];
  }, [conversations, selectedConversationId]);

  const queueTabs = useMemo(() => {
    return [
      'Fila geral',
      'Sem responsavel',
      ...departments.filter((item) => item.name !== 'Fila geral').map((item) => item.name),
      'Aguardando cliente',
      'Em atraso'
    ];
  }, [departments]);

  const visibleQuickReplies = useMemo(() => {
    const departmentReplies = quickReplies.filter((item) => item.departmentName === selectedConversation.departmentName);
    const generalReplies = quickReplies.filter((item) => item.departmentName === 'Fila geral');

    return [...departmentReplies, ...generalReplies].filter((item, index, array) => {
      return array.findIndex((candidate) => candidate.id === item.id) === index;
    });
  }, [quickReplies, selectedConversation.departmentName]);

  const visibleConversations = useMemo(() => {
    if (selectedQueue === 'Fila geral') {
      return conversations;
    }

    if (selectedQueue === 'Sem responsavel') {
      return conversations.filter((item) => !item.assignedUserName || item.assignedUserName === 'Sem responsavel');
    }

    if (selectedQueue === 'Em atraso') {
      return conversations.filter((item) => item.priority === 'alta' || item.priority === 'urgente');
    }

    if (selectedQueue === 'Aguardando cliente') {
      return conversations.filter((item) => item.status === 'aguardando_cliente');
    }

    return conversations.filter((item) => item.departmentName === selectedQueue);
  }, [conversations, selectedQueue]);

  async function updateConversation(payload: {
    status?: string;
    priority?: string;
    departmentName?: string;
  }) {
    const token = getToken();

    const nextStatus = payload.status || selectedConversation.status;
    const nextPriority = payload.priority || selectedConversation.priority;
    const nextDepartment = payload.departmentName || selectedConversation.departmentName;

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setConversations((current) => current.map((item) => item.id === selectedConversation.id ? {
        ...item,
        status: nextStatus,
        priority: nextPriority,
        departmentName: nextDepartment
      } : item));
      return;
    }

    const response = await updateAttendanceConversationStatusRequest(token, selectedConversation.id, {
      status: nextStatus,
      priority: nextPriority,
      departmentName: nextDepartment,
      assignedUserId: selectedConversation.assignedUserId,
      assignedUserName: selectedConversation.assignedUserName
    });

    if (response.success) {
      await loadInbox();
      setNotice('Conversa atualizada.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel atualizar conversa.');
    }
  }

  async function handleAssignConversation(action: string) {
    const token = getToken();
    const name = assigneeName.trim() || 'Atendente atual';

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setConversations((current) => current.map((item) => item.id === selectedConversation.id ? {
        ...item,
        assignedUserName: name,
        status: item.status === 'novo' ? 'em_atendimento' : item.status
      } : item));
      setNotice('Responsavel atribuido localmente para demonstracao.');
      return;
    }

    const response = await assignAttendanceConversationRequest(token, selectedConversation.id, {
      assignedUserId: null,
      assignedUserName: name,
      departmentName: selectedConversation.departmentName,
      action
    });

    if (response.success) {
      await loadInbox();
      setAssigneeName('');
      setNotice('Responsavel atribuido com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel atribuir responsavel.');
    }
  }

  async function handleCreateDepartment(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token || !newDepartmentName.trim()) {
      return;
    }

    const response = await createAttendanceDepartmentRequest(token, {
      name: newDepartmentName.trim(),
      color: '#0757c8',
      sortOrder: departments.length + 1
    });

    if (response.success) {
      setNewDepartmentName('');
      await loadInbox();
      setNotice('Departamento criado com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel criar departamento.');
    }
  }

  async function handleCreateQuickReply(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token || !newQuickReplyTitle.trim() || !newQuickReplyMessage.trim()) {
      return;
    }

    const response = await createAttendanceQuickReplyRequest(token, {
      departmentName: selectedConversation.departmentName,
      title: newQuickReplyTitle.trim(),
      message: newQuickReplyMessage.trim(),
      sortOrder: quickReplies.length + 1
    });

    if (response.success) {
      setNewQuickReplyTitle('');
      setNewQuickReplyMessage('');

      const listResponse = await listAttendanceQuickRepliesRequest(token);

      if (listResponse.success) {
        setQuickReplies(listResponse.data.quickReplies);
      }

      setNotice('Resposta rapida criada com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel criar resposta rapida.');
    }
  }

  return (
    <section className="inbox-shell">
      <section className="inbox-hero">
        <div>
          <span>Central de atendimento</span>
          <h1>Respostas rapidas por departamento</h1>
          <p>Use mensagens prontas por fila operacional e aplique o texto diretamente no campo de envio.</p>
        </div>

        <div className="inbox-hero-brand">
          /assets/lh_chatbot_favicon.png
          <strong>LH Solucao</strong>
          <small>Chat Bot Meta</small>
        </div>
      </section>

      {notice ? <div className="form-message">{notice}</div> : null}

      <section className="department-manager">
        <div>
          <strong>Departamentos</strong>
          <p>Crie filas operacionais para organizar o atendimento.</p>
        </div>

        <form onSubmit={handleCreateDepartment}>
          <input
            onChange={(event) => setNewDepartmentName(event.target.value)}
            placeholder="Novo departamento"
            value={newDepartmentName}
          />
          <button type="submit">Criar</button>
        </form>
      </section>

      <section className="inbox-metrics">
        <article>
          <span>Respostas rapidas</span>
          <strong>{quickReplies.length}</strong>
          <p>Ativas no atendimento</p>
        </article>

        <article>
          <span>Departamentos</span>
          <strong>{departments.length}</strong>
          <p>Filas ativas</p>
        </article>

        <article>
          <span>Sem responsavel</span>
          <strong>{conversations.filter((item) => !item.assignedUserName || item.assignedUserName === 'Sem responsavel').length}</strong>
          <p>Aguardando distribuicao</p>
        </article>

        <article>
          <span>Fila atual</span>
          <strong>{visibleConversations.length}</strong>
          <p>{selectedQueue}</p>
        </article>
      </section>

      <section className="inbox-workspace">
        <aside className="inbox-queues">
          <div className="inbox-panel-title">
            <strong>Filas</strong>
            <span>Departamentos e status</span>
          </div>

          <div className="inbox-queue-list">
            {queueTabs.map((queue) => (
              <button
                className={queue === selectedQueue ? 'active' : ''}
                key={queue}
                onClick={() => setSelectedQueue(queue)}
                type="button"
              >
                {queue}
              </button>
            ))}
          </div>
        </aside>

        <aside className="inbox-conversation-list">
          <div className="inbox-panel-title">
            <strong>Conversas</strong>
            <span>{visibleConversations.length} itens nesta fila</span>
          </div>

          <div className="inbox-search">
            <input placeholder="Buscar por nome ou telefone" />
          </div>

          {loading ? <div className="conversation-empty">Carregando central...</div> : null}

          <div className="inbox-conversation-items">
            {visibleConversations.map((conversation) => (
              <button
                className={conversation.id === selectedConversation.id ? 'active' : ''}
                key={conversation.id}
                onClick={() => setSelectedConversationId(conversation.id)}
                type="button"
              >
                <div>
                  <strong>{conversation.contactName || conversation.contactPhone || 'Contato sem nome'}</strong>
                  <span>{conversation.lastMessage || 'Sem mensagem recente'}</span>
                  <small>{conversation.departmentName} - {conversation.assignedUserName || 'Sem responsavel'}</small>
                </div>

                <em>{conversation.lastMessageAt || conversation.updatedAt}</em>

                {conversation.unreadCount ? (
                  <b>{conversation.unreadCount}</b>
                ) : null}
              </button>
            ))}
          </div>
        </aside>

        <main className="inbox-chat">
          <header className="inbox-chat-header">
            <div>
              <strong>{selectedConversation.contactName || selectedConversation.contactPhone || 'Contato sem nome'}</strong>
              <span>{selectedConversation.contactPhone || 'Telefone nao informado'}</span>
            </div>

            <div className="inbox-chat-badges">
              <span>{selectedConversation.departmentName}</span>
              <span>{statusLabels[selectedConversation.status] || selectedConversation.status}</span>
              <span>{priorityLabels[selectedConversation.priority] || selectedConversation.priority}</span>
            </div>
          </header>

          <section className="inbox-status-editor">
            <label>
              Departamento
              <select onChange={(event) => void updateConversation({ departmentName: event.target.value })} value={selectedConversation.departmentName}>
                {departments.map((item) => (
                  <option key={item.id} value={item.name}>{item.name}</option>
                ))}
              </select>
            </label>

            <label>
              Status
              <select onChange={(event) => void updateConversation({ status: event.target.value })} value={selectedConversation.status}>
                {(statusOptions.length ? statusOptions : Object.entries(statusLabels).map(([value, label]) => ({ value, label }))).map((item) => (
                  <option key={item.value} value={item.value}>{item.label}</option>
                ))}
              </select>
            </label>

            <label>
              Prioridade
              <select onChange={(event) => void updateConversation({ priority: event.target.value })} value={selectedConversation.priority}>
                {(priorityOptions.length ? priorityOptions : Object.entries(priorityLabels).map(([value, label]) => ({ value, label }))).map((item) => (
                  <option key={item.value} value={item.value}>{item.label}</option>
                ))}
              </select>
            </label>
          </section>

          <section className="inbox-message-area">
            <article className="message-bubble inbound">
              <span>Cliente</span>
              <p>{selectedConversation.lastMessage || 'Mensagem recebida do cliente.'}</p>
            </article>

            <article className="message-bubble internal">
              <span>Nota interna</span>
              <p>Respostas rapidas por departamento estao disponiveis abaixo e podem preencher o campo de mensagem.</p>
            </article>

            <article className="message-bubble outbound">
              <span>Atendente</span>
              <p>{composerText || 'Selecione uma resposta rapida ou digite uma mensagem.'}</p>
            </article>
          </section>

          <section className="inbox-quick-replies">
            {visibleQuickReplies.length ? visibleQuickReplies.map((reply) => (
              <button key={reply.id} onClick={() => setComposerText(reply.message)} type="button">
                {reply.title}
              </button>
            )) : fallbackQuickReplies.map((reply) => (
              <button key={reply} onClick={() => setComposerText(reply)} type="button">
                {reply}
              </button>
            ))}
          </section>

          <form className="quick-reply-manager" onSubmit={handleCreateQuickReply}>
            <strong>Nova resposta rapida para {selectedConversation.departmentName}</strong>
            <input
              onChange={(event) => setNewQuickReplyTitle(event.target.value)}
              placeholder="Titulo"
              value={newQuickReplyTitle}
            />
            <textarea
              onChange={(event) => setNewQuickReplyMessage(event.target.value)}
              placeholder="Mensagem da resposta rapida"
              value={newQuickReplyMessage}
            />
            <button type="submit">Salvar resposta rapida</button>
          </form>

          <footer className="inbox-composer">
            <textarea
              onChange={(event) => setComposerText(event.target.value)}
              placeholder="Digite uma mensagem para o cliente"
              value={composerText}
            />
            <button type="button">Enviar</button>
          </footer>
        </main>

        <aside className="inbox-contact-panel">
          <div className="inbox-panel-title">
            <strong>Contato</strong>
            <span>Historico e operacao</span>
          </div>

          <div className="contact-card">
            <img alt="LH Solucao Chat Bot" src="/assets/lh_chatbot_favicon.png" />
            <strong>{selectedConversation.contactName || 'Contato sem nome'}</strong>
            <span>{selectedConversation.contactPhone || 'Telefone nao informado'}</span>
          </div>

          <div className="contact-details">
            <span>Departamento: {selectedConversation.departmentName}</span>
            <span>Responsavel: {selectedConversation.assignedUserName || 'Sem responsavel'}</span>
            <span>Prioridade: {priorityLabels[selectedConversation.priority] || selectedConversation.priority}</span>
            <span>Status: {statusLabels[selectedConversation.status] || selectedConversation.status}</span>
          </div>

          <section className="assignment-card">
            <strong>Atribuicao de responsavel</strong>
            <p>Informe o nome do atendente que esta assumindo ou respondendo esta conversa.</p>

            <input
              onChange={(event) => setAssigneeName(event.target.value)}
              placeholder="Nome do atendente"
              value={assigneeName}
            />

            <div>
              <button onClick={() => void handleAssignConversation('assigned')} type="button">
                Salvar responsavel
              </button>

              <button onClick={() => void handleAssignConversation('assumed')} type="button">
                Assumir atendimento
              </button>
            </div>
          </section>

          <section className="closing-card">
            <strong>Encerramento com avaliacao</strong>
            <p>Mensagem padrao pronta para finalizar o atendimento e solicitar nota de 1 a 5.</p>
            <button type="button">Preparar encerramento</button>
          </section>
        </aside>
      </section>
    </section>
  );
}
TSX

echo "Garantindo CSS das respostas rapidas..."

if ! grep -q "Etapa 60 - Respostas rapidas por departamento" "${FRONTEND_DIR}/src/styles.css"; then
cat >> "${FRONTEND_DIR}/src/styles.css" <<'CSS'

/* Etapa 60 - Respostas rapidas por departamento */

.quick-reply-manager {
  background: #f8fafc;
  border-top: 1px solid #e5e7eb;
  display: grid;
  gap: 10px;
  padding: 14px 16px;
}

.quick-reply-manager strong {
  color: var(--lh-blue-950, #04204f);
}

.quick-reply-manager input,
.quick-reply-manager textarea {
  border: 1px solid #d1d5db;
  border-radius: 14px;
  padding: 11px 13px;
  width: 100%;
}

.quick-reply-manager textarea {
  min-height: 70px;
  resize: vertical;
}

.quick-reply-manager button {
  background: linear-gradient(135deg, var(--lh-blue-800, #0757c8), var(--lh-blue-700, #0a6de8));
  border: 0;
  border-radius: 14px;
  color: #ffffff;
  cursor: pointer;
  font-weight: 950;
  padding: 11px 13px;
}
CSS
fi

echo "Validando arquivos sem HTML injetado..."

if grep -R "fai-ChatInputEntity" \
  "${FRONTEND_DIR}/src/pages/inbox/InboxPage.tsx" \
  "${FRONTEND_DIR}/src/services/attendance.service.ts" \
  "${FRONTEND_DIR}/src/types/attendance.types.ts" \
  "${FRONTEND_DIR}/src/styles.css"
then
  echo "ERRO: HTML injetado encontrado."
  exit 1
fi

echo "Rodando typecheck do frontend..."

cd "${FRONTEND_DIR}"
npm run typecheck 2>&1 | tee "${FRONTEND_TYPECHECK_LOG}"

echo "Rodando build do frontend..."

npm run build 2>&1 | tee "${FRONTEND_BUILD_LOG}"

cd "${BASE_DIR}"

echo "Rebuildando backend e frontend..."

docker compose build backend 2>&1 | tee "${DOCKER_BACKEND_BUILD_LOG}"
docker compose build frontend 2>&1 | tee "${DOCKER_FRONTEND_BUILD_LOG}"

echo "Subindo backend, frontend e proxy..."

docker compose up -d backend frontend proxy 2>&1 | tee "${DOCKER_UP_LOG}"

echo "Aguardando backend estabilizar..."

: > "${BACKEND_WAIT_LOG}"

BACKEND_READY="false"

for i in $(seq 1 30); do
  STATUS="$(docker inspect -f '{{.State.Status}}' saas_whatsapp_backend 2>/dev/null || echo unknown)"
  RESTARTING="$(docker inspect -f '{{.State.Restarting}}' saas_whatsapp_backend 2>/dev/null || echo unknown)"

  echo "tentativa=${i} status=${STATUS} restarting=${RESTARTING}" | tee -a "${BACKEND_WAIT_LOG}"

  if [ "${STATUS}" = "running" ] && [ "${RESTARTING}" = "false" ]; then
    if curl -s --max-time 5 "http://127.0.0.1:3300/api/v1/health" >/dev/null 2>&1; then
      BACKEND_READY="true"
      break
    fi
  fi

  sleep 3
done

if [ "${BACKEND_READY}" != "true" ]; then
  echo "ERRO: backend nao estabilizou."
  docker compose logs --tail=220 backend 2>&1 | tee "${BACKEND_CRASH_LOG}"
  exit 1
fi

sleep 8

echo "Validando credenciais e dominio..."

if [ ! -f "${LOGS_DIR}/setup_24_seed_credentials.log" ]; then
  echo "ERRO: credenciais da Etapa 24 ausentes."
  exit 1
fi

ADMIN_EMAIL="$(grep '^Email:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"
ADMIN_PASSWORD="$(grep '^Senha:' "${LOGS_DIR}/setup_24_seed_credentials.log" | head -n 1 | cut -d ':' -f 2- | xargs)"

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

DOMAIN_ACCESS_TOKEN="$(node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync(process.argv[1],'utf8')); console.log(data.data.access_token)" "${DOMAIN_LOGIN_LOG}")"

DOMAIN_QUICK_REPLIES_STATUS="$(curl -L -s -o "${DOMAIN_QUICK_REPLIES_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  "${DOMAIN_ATTENDANCE_URL}/quick-replies?departmentName=Comercial" || true)"

if [ "${DOMAIN_QUICK_REPLIES_STATUS}" != "200" ]; then
  echo "ERRO: quick replies falhou. Status ${DOMAIN_QUICK_REPLIES_STATUS}"
  cat "${DOMAIN_QUICK_REPLIES_LOG}"
  exit 1
fi

if ! grep -q "quickReplies" "${DOMAIN_QUICK_REPLIES_LOG}"; then
  echo "ERRO: quick replies nao retornou lista esperada."
  cat "${DOMAIN_QUICK_REPLIES_LOG}"
  exit 1
fi

CREATE_PAYLOAD="$(node -e "console.log(JSON.stringify({departmentName:'Comercial', title:'Validacao Etapa 60 Final', message:'Resposta rapida criada na validacao final da Etapa 60.', sortOrder:100}))")"

DOMAIN_QUICK_REPLY_CREATE_STATUS="$(curl -L -s -o "${DOMAIN_QUICK_REPLY_CREATE_LOG}" -w "%{http_code}" --max-time 30 \
  -H "Authorization: Bearer ${DOMAIN_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "${CREATE_PAYLOAD}" \
  "${DOMAIN_ATTENDANCE_URL}/quick-replies" || true)"

if [ "${DOMAIN_QUICK_REPLY_CREATE_STATUS}" != "200" ] && [ "${DOMAIN_QUICK_REPLY_CREATE_STATUS}" != "201" ]; then
  echo "ERRO: create quick reply falhou. Status ${DOMAIN_QUICK_REPLY_CREATE_STATUS}"
  cat "${DOMAIN_QUICK_REPLY_CREATE_LOG}"
  exit 1
fi

if ! grep -q "Validacao Etapa 60 Final" "${DOMAIN_QUICK_REPLY_CREATE_LOG}"; then
  echo "ERRO: create quick reply nao retornou titulo esperado."
  cat "${DOMAIN_QUICK_REPLY_CREATE_LOG}"
  exit 1
fi

DOMAIN_INBOX_PAGE_STATUS="$(curl -L -s -o "${DOMAIN_INBOX_PAGE_LOG}" -w "%{http_code}" --max-time 30 \
  "${DOMAIN_INBOX_PAGE_URL}" || true)"

if [ "${DOMAIN_INBOX_PAGE_STATUS}" != "200" ]; then
  echo "ERRO: pagina inbox nao respondeu 200."
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

echo "Gerando documentacao da Etapa 60..."

cat > "${DOC_FILE}" <<'DOC'
# Attendance Quick Replies

## Visao geral

Este documento registra a criacao de respostas rapidas por departamento.

## Resultado

Status:

    concluido

## Correcao aplicada

A Etapa 60 foi concluida com fix final da tela app inbox, corrigindo erro TypeScript na importacao de tipos da pagina.

## Funcionalidades criadas

Funcionalidades:

- tabela attendance quick replies
- respostas rapidas por tenant
- respostas rapidas por departamento
- seed inicial de respostas
- endpoint para listar respostas rapidas
- endpoint para criar resposta rapida
- endpoint para atualizar resposta rapida
- integracao da central app inbox com respostas rapidas reais
- botao para aplicar resposta rapida ao campo de mensagem
- formulario visual para criar nova resposta rapida por departamento

## Respostas iniciais

Respostas:

- Saudacao inicial
- Pedido de dados
- Solicitar interesse
- Solicitar detalhes
- Comprovante
- Encerramento com avaliacao

## Endpoints criados

Endpoints:

- GET api v1 attendance quick replies
- POST api v1 attendance quick replies
- PATCH api v1 attendance quick replies quick reply id

## Tabela criada

Tabela:

- attendance quick replies

Campos:

- id
- tenant id
- department name
- title
- message
- is active
- sort order
- created at
- updated at

## Arquivos criados ou alterados

Arquivos:

- apps/backend/src/modules/attendance/attendance.types.ts
- apps/backend/src/modules/attendance/attendance.service.ts
- apps/backend/src/modules/attendance/attendance.controller.ts
- apps/frontend/src/types/attendance.types.ts
- apps/frontend/src/services/attendance.service.ts
- apps/frontend/src/pages/inbox/InboxPage.tsx
- apps/frontend/src/styles.css
- docs/ATTENDANCE_QUICK_REPLIES.md
- 00_CONTROLE.md
- MANIFESTO.md

## Validacoes executadas

Validacoes:

- criacao idempotente da tabela attendance quick replies
- npm run typecheck no frontend
- npm run build no frontend
- docker compose build backend
- docker compose build frontend
- docker compose up backend frontend proxy
- login dominio
- endpoint quick replies dominio
- criacao de resposta rapida dominio
- rota app inbox
- rota app dashboard
- rota app audit

## Logs gerados

Logs:

- logs/setup_60_frontend_typecheck.log
- logs/setup_60_frontend_build.log
- logs/setup_60_backend_docker_build.log
- logs/setup_60_frontend_docker_build.log
- logs/setup_60_docker_up.log
- logs/setup_60_backend_wait.log
- logs/setup_60_auth_login_domain.log
- logs/setup_60_quick_replies_domain.log
- logs/setup_60_quick_reply_create_domain.log
- logs/setup_60_domain_inbox_page.log
- logs/setup_60_domain_dashboard.log
- logs/setup_60_domain_audit_page.log
- logs/setup_60.log
- logs/fix_60_inbox_quick_replies_frontend.log

## Proxima etapa sugerida

Etapa 61:

    Criar notas internas e tags
DOC

echo "Atualizando 00_CONTROLE.md..."

python3 <<'PY'
from pathlib import Path

path = Path("00_CONTROLE.md")
text = path.read_text()

text = text.replace(
    "- [ ] Etapa 60 - Criar respostas rapidas por departamento",
    "- [x] Etapa 60 - Criar respostas rapidas por departamento\n- [ ] Etapa 61 - Criar notas internas e tags"
)

text = text.replace(
    "Etapa 60 - Criar respostas rapidas por departamento.",
    "Etapa 61 - Criar notas internas e tags."
)

text = text.replace(
    "Etapa 59 - Criar atribuicao de responsavel e nome do atendente.",
    "Etapa 60 - Criar respostas rapidas por departamento."
)

path.write_text(text)
PY

echo "Atualizando MANIFESTO.md..."

python3 <<'PY'
from pathlib import Path

path = Path("MANIFESTO.md")
text = path.read_text()

if "Respostas rapidas por departamento criadas." not in text:
    text = text.replace(
        "Atribuicao de responsavel e nome do atendente criada.",
        "Atribuicao de responsavel e nome do atendente criada.\n\nRespostas rapidas por departamento criadas."
    )

if "- docs/ATTENDANCE_QUICK_REPLIES.md" not in text:
    text = text.replace(
        "- docs/ATTENDANCE_RESPONSIBLE_ASSIGNMENT.md",
        "- docs/ATTENDANCE_QUICK_REPLIES.md\n- docs/ATTENDANCE_RESPONSIBLE_ASSIGNMENT.md"
    )

text = text.replace(
    "- Etapa 01 ate Etapa 59 concluidas",
    "- Etapa 01 ate Etapa 60 concluidas"
)

text = text.replace(
    "- Etapa 60 - Criar respostas rapidas por departamento",
    "- Etapa 61 - Criar notas internas e tags"
)

path.write_text(text)
PY

echo "Atualizando documentos auxiliares se existirem..."

for doc_file in CONTEXTO_PROJETO.md CHANGELOG.md DECISOES_TECNICAS.md PENDENCIAS.md; do
  if [ -f "${BASE_DIR}/${doc_file}" ]; then
    cat >> "${BASE_DIR}/${doc_file}" <<DOC

Etapa 60 - Criar respostas rapidas por departamento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Resumo: Criada persistencia de respostas rapidas por departamento, endpoints de listagem e criacao, e integracao da central app inbox com aplicacao da resposta no campo de mensagem.
DOC
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
Etapa: 60
Acao: Criar respostas rapidas por departamento
Data: $(date '+%Y-%m-%d %H:%M:%S')
Login dominio status: ${DOMAIN_LOGIN_STATUS}
Quick replies status: ${DOMAIN_QUICK_REPLIES_STATUS}
Quick reply create status: ${DOMAIN_QUICK_REPLY_CREATE_STATUS}
Inbox page status: ${DOMAIN_INBOX_PAGE_STATUS}
Dashboard status: ${DOMAIN_DASHBOARD_STATUS}
Audit page status: ${DOMAIN_AUDIT_PAGE_STATUS}
Status: Concluido
DOC

cat > "${FIX_LOG_FILE}" <<DOC
Etapa: 60
Acao: Fix final frontend respostas rapidas
Data: $(date '+%Y-%m-%d %H:%M:%S')
Status: Concluido
DOC

echo ""
echo "== Etapa 60 concluida com sucesso =="
echo ""
echo "Resumo:"
sed -n '1,220p' "${DOC_FILE}"
echo ""
echo "Proxima etapa sugerida:"
echo "Etapa 61 - Criar notas internas e tags"
