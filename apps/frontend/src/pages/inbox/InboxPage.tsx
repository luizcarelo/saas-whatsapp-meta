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
import {
  attachConversationTagRequest,
  createConversationNoteRequest,
  listAttendanceTagsRequest,
  listConversationNotesRequest,
  listConversationTagsRequest
} from '../../services/attendance-metadata.service';
import {
  closeAttendanceConversationRequest,
  createAttendanceRatingRequest,
  listAttendanceClosuresRequest,
  listAttendanceRatingsRequest
} from '../../services/attendance-closure.service';
import {
  listAttendanceSendHistoryRequest,
  sendAttendanceManualMessageRequest
} from '../../services/attendance-send.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
  AttendanceConversationItem,
  AttendanceDepartmentItem,
  AttendanceQuickReplyItem
} from '../../types/attendance.types';
import type {
  AttendanceInternalNoteItem,
  AttendanceTagItem
} from '../../types/attendance-metadata.types';
import type {
  AttendanceClosureItem,
  AttendanceRatingItem
} from '../../types/attendance-closure.types';
import type { AttendanceSendItem } from '../../types/attendance-send.types';

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
  const [internalNotes, setInternalNotes] = useState<AttendanceInternalNoteItem[]>([]);
  const [availableTags, setAvailableTags] = useState<AttendanceTagItem[]>([]);
  const [conversationTags, setConversationTags] = useState<AttendanceTagItem[]>([]);
  const [newInternalNote, setNewInternalNote] = useState('');
  const [newTagName, setNewTagName] = useState('');
  const [closures, setClosures] = useState<AttendanceClosureItem[]>([]);
  const [ratings, setRatings] = useState<AttendanceRatingItem[]>([]);
  const [closingMessage, setClosingMessage] = useState('Atendimento finalizado.\n\nComo voce avalia nosso atendimento de 1 a 5?\n\n1 - Muito ruim\n2 - Ruim\n3 - Regular\n4 - Bom\n5 - Excelente\n\nObrigado por falar com a LH Solucao.');
  const [ratingValue, setRatingValue] = useState('5');
  const [ratingComment, setRatingComment] = useState('');
  const [sendHistory, setSendHistory] = useState<AttendanceSendItem[]>([]);
  const [sendDryRun, setSendDryRun] = useState(true);
  const [sendingMessage, setSendingMessage] = useState(false);
  const [selectedQuickReplyId, setSelectedQuickReplyId] = useState<string | null>(null);
  const [selectedQuickReplyTitle, setSelectedQuickReplyTitle] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadMetadata(conversationId: string) {
    const token = getToken();

    if (!token || !conversationId || conversationId.startsWith('demo-')) {
      setInternalNotes([]);
      setConversationTags([]);
      return;
    }

    const [notesResponse, tagsResponse, conversationTagsResponse, closuresResponse, ratingsResponse] = await Promise.all([
      listConversationNotesRequest(token, conversationId),
      listAttendanceTagsRequest(token),
      listConversationTagsRequest(token, conversationId),
      listAttendanceClosuresRequest(token, conversationId),
      listAttendanceRatingsRequest(token, conversationId)
    ]);

    if (notesResponse.success) {
      setInternalNotes(notesResponse.data.notes);
    }

    if (tagsResponse.success) {
      setAvailableTags(tagsResponse.data.tags);
    }

    if (conversationTagsResponse.success) {
      setConversationTags(conversationTagsResponse.data.tags);
    }

    if (closuresResponse.success) {
      setClosures(closuresResponse.data.closures);
    }

    if (ratingsResponse.success) {
      setRatings(ratingsResponse.data.ratings);
    }
  }

  async function loadSendHistory(conversationId: string) {
    const token = getToken();

    if (!token || !conversationId || conversationId.startsWith('demo-')) {
      setSendHistory([]);
      return;
    }

    const response = await listAttendanceSendHistoryRequest(token, conversationId);

    if (response.success) {
      setSendHistory(response.data.sends);
    }
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

  useEffect(() => {
    if (selectedConversation.id) {
      void loadMetadata(selectedConversation.id);
    }
  }, [selectedConversation.id]);

  useEffect(() => {
    if (selectedConversation.id) {
      void loadSendHistory(selectedConversation.id);
    }
  }, [selectedConversation.id]);

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

  function applyQuickReply(reply: AttendanceQuickReplyItem) {
    setComposerText(reply.message);
    setSelectedQuickReplyId(reply.id);
    setSelectedQuickReplyTitle(reply.title);
    setNotice('Resposta rapida selecionada: ' + reply.title);
  }

  function clearQuickReplySelection() {
    setSelectedQuickReplyId(null);
    setSelectedQuickReplyTitle(null);
  }

  async function handleSendComposerMessage() {
    const token = getToken();
    const messageBody = composerText.trim();

    if (!messageBody) {
      setNotice('Digite uma mensagem antes de enviar.');
      return;
    }

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setNotice('Mensagem validada localmente para demonstracao.');
      return;
    }

    setSendingMessage(true);

    const response = await sendAttendanceManualMessageRequest(token, selectedConversation.id, {
      messageBody,
      sentByUserId: null,
      sentByName: assigneeName.trim() || selectedConversation.assignedUserName || 'Atendente',
      departmentName: selectedConversation.departmentName,
      messageOrigin: selectedQuickReplyId ? 'quick_reply' : 'manual',
      quickReplyId: selectedQuickReplyId,
      quickReplyTitle: selectedQuickReplyTitle,
      dryRun: sendDryRun
    });

    if (response.success) {
      await loadSendHistory(selectedConversation.id);

      if (sendDryRun) {
        setNotice(selectedQuickReplyId ? 'Resposta rapida validada em modo dryRun.' : 'Envio validado em modo dryRun. Nenhuma mensagem real foi enviada.');
      } else if (response.data.send.status === 'sent') {
        setComposerText('');
        clearQuickReplySelection();
        setNotice(selectedQuickReplyId ? 'Resposta rapida enviada com sucesso.' : 'Mensagem enviada com sucesso.');
      } else {
        setNotice(response.data.send.errorMessage || 'Envio registrado com falha.');
      }
    } else {
      setNotice(response.error.message || 'Nao foi possivel enviar a mensagem.');
    }

    setSendingMessage(false);
  }

  async function handleCloseConversation() {
    const token = getToken();

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setComposerText(closingMessage);
      setNotice('Mensagem de encerramento preparada para demonstracao.');
      return;
    }

    const response = await closeAttendanceConversationRequest(token, selectedConversation.id, {
      closingMessage,
      closedByUserId: null,
      closedByName: assigneeName.trim() || selectedConversation.assignedUserName || 'Atendente',
      departmentName: selectedConversation.departmentName,
      ratingRequested: true
    });

    if (!response.success) {
      setNotice(response.error.message || 'Nao foi possivel encerrar atendimento.');
      return;
    }

    const preparedMessage = response.data.closure.closingMessage;

    setComposerText(preparedMessage);

    const sendResponse = await sendAttendanceManualMessageRequest(token, selectedConversation.id, {
      messageBody: preparedMessage,
      sentByUserId: null,
      sentByName: assigneeName.trim() || selectedConversation.assignedUserName || 'Atendente',
      departmentName: selectedConversation.departmentName,
      messageOrigin: 'closing_rating',
      quickReplyId: null,
      quickReplyTitle: null,
      dryRun: sendDryRun
    });

    await loadInbox();
    await loadMetadata(selectedConversation.id);
    await loadSendHistory(selectedConversation.id);

    if (sendResponse.success) {
      if (sendDryRun) {
        setNotice('Encerramento registrado e mensagem de avaliacao validada em dryRun.');
      } else if (sendResponse.data.send.status === 'sent') {
        setNotice('Encerramento registrado e mensagem de avaliacao enviada.');
      } else {
        setNotice(sendResponse.data.send.errorMessage || 'Encerramento registrado, mas o envio retornou falha.');
      }
    } else {
      setNotice(sendResponse.error.message || 'Encerramento registrado, mas nao foi possivel enviar a mensagem.');
    }
  }

  async function handleCreateRating(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token || selectedConversation.id.startsWith('demo-')) {
      setNotice('Avaliacao registrada localmente para demonstracao.');
      return;
    }

    const response = await createAttendanceRatingRequest(token, selectedConversation.id, {
      rating: Number(ratingValue),
      comment: ratingComment.trim() || null
    });

    if (response.success) {
      setRatingComment('');
      await loadMetadata(selectedConversation.id);
      setNotice('Avaliacao registrada com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel registrar avaliacao.');
    }
  }

  async function handleCreateInternalNote(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token || !newInternalNote.trim() || selectedConversation.id.startsWith('demo-')) {
      return;
    }

    const response = await createConversationNoteRequest(token, selectedConversation.id, {
      note: newInternalNote.trim(),
      createdByUserId: null,
      createdByName: assigneeName.trim() || selectedConversation.assignedUserName || 'Atendente'
    });

    if (response.success) {
      setNewInternalNote('');
      await loadMetadata(selectedConversation.id);
      setNotice('Nota interna criada com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel criar nota interna.');
    }
  }

  async function handleAttachTag(tagId: string) {
    const token = getToken();

    if (!token || !tagId || selectedConversation.id.startsWith('demo-')) {
      return;
    }

    const response = await attachConversationTagRequest(token, selectedConversation.id, tagId);

    if (response.success) {
      setConversationTags(response.data.tags);
      setNotice('Tag vinculada com sucesso.');
    } else {
      setNotice(response.error.message || 'Nao foi possivel vincular tag.');
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

      <section className="inbox-visual-guide" aria-label="Etapa 76 - layout refinado">
        <span>Conversas e filtros</span>
        <span>Mensagens e envio</span>
        <span>Dados operacionais</span>
      </section>

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

          {selectedQuickReplyTitle ? (
            <div className="quick-reply-selected-box">
              <span>Resposta rapida selecionada: {selectedQuickReplyTitle}</span>
              <button onClick={clearQuickReplySelection} type="button">Limpar</button>
            </div>
          ) : null}

          <section className="inbox-quick-replies">
            {visibleQuickReplies.length ? visibleQuickReplies.map((reply) => (
              <button
                className={selectedQuickReplyId === reply.id ? 'active' : ''}
                key={reply.id}
                onClick={() => applyQuickReply(reply)}
                type="button"
              >
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
            <button disabled={sendingMessage} onClick={() => void handleSendComposerMessage()} type="button">
              {sendingMessage ? 'Enviando...' : sendDryRun ? 'Validar envio' : 'Enviar'}
            </button>
          </footer>

          <section className="send-history-panel">
            <label className="send-dry-run-toggle">
              <input
                checked={sendDryRun}
                onChange={(event) => setSendDryRun(event.target.checked)}
                type="checkbox"
              />
              Modo dryRun ativo para validar sem envio real
            </label>

            <div className="inbox-panel-title">
              <strong>Historico de envios da central</strong>
              <span>Mensagens enviadas ou validadas pelo backend de atendimento</span>
            </div>

            <div className="send-history-list">
              {sendHistory.length ? sendHistory.map((send) => (
                <article key={send.id}>
                  <div>
                    <strong>Atendente: {send.sentByName}</strong>
                    <span>{send.status}{send.dryRun ? ' - dryRun' : ''}{send.messageOrigin === 'quick_reply' ? ' - resposta rapida' : ''}{send.messageOrigin === 'closing_rating' ? ' - encerramento' : ''}</span>
                  </div>
                  {send.assignedUserNameAtSend ? <small>Responsavel no momento do envio: {send.assignedUserNameAtSend}</small> : null}
                  {send.attendantSource ? <small>Origem do atendente: {send.attendantSource}</small> : null}
                  {send.quickReplyTitle ? <small>Resposta rapida: {send.quickReplyTitle}</small> : null}
                  <p>{send.messageBody}</p>
                  <small>{send.createdAt}</small>
                  {send.errorMessage ? <em>{send.errorMessage}</em> : null}
                </article>
              )) : <small>Nenhum envio registrado para esta conversa.</small>}
            </div>
          </section>
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

          <section className="metadata-card">
            <strong>Tags da conversa</strong>
            <div className="tag-list">
              {conversationTags.length ? conversationTags.map((tag) => (
                <span key={tag.id} style={{ backgroundColor: tag.color }}>{tag.name}</span>
              )) : <small>Nenhuma tag vinculada.</small>}
            </div>

            <select onChange={(event) => void handleAttachTag(event.target.value)} value="">
              <option value="">Adicionar tag</option>
              {availableTags.map((tag) => (
                <option key={tag.id} value={tag.id}>{tag.name}</option>
              ))}
            </select>
          </section>

          <form className="metadata-card" onSubmit={handleCreateInternalNote}>
            <strong>Notas internas</strong>
            <textarea
              onChange={(event) => setNewInternalNote(event.target.value)}
              placeholder="Escreva uma nota interna para a equipe"
              value={newInternalNote}
            />
            <button type="submit">Salvar nota interna</button>

            <div className="note-list">
              {internalNotes.length ? internalNotes.map((note) => (
                <article key={note.id}>
                  <span>{note.createdByName}</span>
                  <p>{note.note}</p>
                  <small>{note.createdAt}</small>
                </article>
              )) : <small>Nenhuma nota interna registrada.</small>}
            </div>
          </form>

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

          <section className="closing-card closure-card">
            <strong>Encerramento com avaliacao</strong>
            <p>Prepare a mensagem de encerramento, envie pela central com origem closing_rating e registre a avaliacao quando o cliente responder.</p>

            <textarea
              onChange={(event) => setClosingMessage(event.target.value)}
              value={closingMessage}
            />

            <button onClick={() => void handleCloseConversation()} type="button">
              Encerrar e preparar mensagem
            </button>

            <form className="rating-form" onSubmit={handleCreateRating}>
              <label>
                Nota
                <select onChange={(event) => setRatingValue(event.target.value)} value={ratingValue}>
                  <option value="1">1 - Muito ruim</option>
                  <option value="2">2 - Ruim</option>
                  <option value="3">3 - Regular</option>
                  <option value="4">4 - Bom</option>
                  <option value="5">5 - Excelente</option>
                </select>
              </label>

              <textarea
                onChange={(event) => setRatingComment(event.target.value)}
                placeholder="Comentario opcional da avaliacao"
                value={ratingComment}
              />

              <button type="submit">Registrar avaliacao</button>
            </form>

            <div className="closure-history">
              <strong>Historico</strong>
              {closures.length ? closures.map((closure) => (
                <article key={closure.id}>
                  <span>{closure.closedByName}</span>
                  <p>{closure.closingMessage}</p>
                  <small>{closure.createdAt}</small>
                </article>
              )) : <small>Nenhum encerramento registrado.</small>}

              {ratings.length ? ratings.map((rating) => (
                <article key={rating.id}>
                  <span>Avaliacao {rating.rating}</span>
                  <p>{rating.comment || 'Sem comentario.'}</p>
                  <small>{rating.createdAt}</small>
                </article>
              )) : <small>Nenhuma avaliacao registrada.</small>}
            </div>
          </section>
        </aside>
      </section>
    </section>
  );
}
