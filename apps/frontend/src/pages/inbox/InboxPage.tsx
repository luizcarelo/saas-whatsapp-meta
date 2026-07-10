import { FormEvent, useEffect, useMemo, useState } from 'react';
import {
  createAttendanceDepartmentRequest,
  getAttendanceStatusOptionsRequest,
  listAttendanceConversationsRequest,
  listAttendanceDepartmentsRequest,
  updateAttendanceConversationStatusRequest
} from '../../services/attendance.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
  AttendanceConversationItem,
  AttendanceDepartmentItem
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

const quickReplies = [
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
  const [statusOptions, setStatusOptions] = useState<Array<{ value: string; label: string }>>([]);
  const [priorityOptions, setPriorityOptions] = useState<Array<{ value: string; label: string }>>([]);
  const [newDepartmentName, setNewDepartmentName] = useState('');
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

    const [listResponse, optionsResponse, departmentsResponse] = await Promise.all([
      listAttendanceConversationsRequest(token),
      getAttendanceStatusOptionsRequest(token),
      listAttendanceDepartmentsRequest(token)
    ]);

    if (departmentsResponse.success && departmentsResponse.data.departments.length > 0) {
      setDepartments(departmentsResponse.data.departments.filter((item) => item.isActive));
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

  return (
    <section className="inbox-shell">
      <section className="inbox-hero">
        <div>
          <span>Central de atendimento</span>
          <h1>Departamentos e filas</h1>
          <p>Distribua conversas por departamentos, acompanhe filas e altere o setor responsavel pelo atendimento.</p>
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
          <span>Departamentos</span>
          <strong>{departments.length}</strong>
          <p>Filas ativas</p>
        </article>

        <article>
          <span>Abertas</span>
          <strong>{conversations.filter((item) => item.status !== 'encerrado' && item.status !== 'arquivado').length}</strong>
          <p>Conversas em andamento</p>
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
              <p>Departamentos e filas agora sao persistidos no backend e usados na central de atendimento.</p>
            </article>

            <article className="message-bubble outbound">
              <span>Atendente</span>
              <p>Ola. Vou direcionar seu atendimento ao departamento responsavel.</p>
            </article>
          </section>

          <section className="inbox-quick-replies">
            {quickReplies.map((reply) => (
              <button key={reply} type="button">
                {reply}
              </button>
            ))}
          </section>

          <footer className="inbox-composer">
            <textarea placeholder="Digite uma mensagem para o cliente" />
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
