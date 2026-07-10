import { useEffect, useMemo, useState } from 'react';
import {
  getAttendanceSettingsStatusModel,
  listAttendanceSettingsAutomationRules,
  listAttendanceSettingsDepartments,
  listAttendanceSettingsQuickReplies,
  type AttendanceSettingsAutomationRule,
  type AttendanceSettingsDepartment,
  type AttendanceSettingsQuickReply,
  type AttendanceSettingsStatusModel
} from '../../services/attendance-settings.service';
import { useAuthStore } from '../../stores/auth.store';

export function AttendanceSettingsPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [departments, setDepartments] = useState<AttendanceSettingsDepartment[]>([]);
  const [quickReplies, setQuickReplies] = useState<AttendanceSettingsQuickReply[]>([]);
  const [automationRules, setAutomationRules] = useState<AttendanceSettingsAutomationRule[]>([]);
  const [statusModel, setStatusModel] = useState<AttendanceSettingsStatusModel | null>(null);
  const [loading, setLoading] = useState(true);
  const [notice, setNotice] = useState('');

  const stats = useMemo(() => {
    const activeDepartments = departments.filter((item) => item.isActive !== false).length;
    const activeQuickReplies = quickReplies.filter((item) => item.isActive !== false).length;
    const activeAutomations = automationRules.filter((item) => item.isActive).length;
    const dryRunAutomations = automationRules.filter((item) => item.sendDryRun).length;

    return {
      activeDepartments,
      activeQuickReplies,
      activeAutomations,
      dryRunAutomations
    };
  }, [departments, quickReplies, automationRules]);

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadSettings() {
    const token = getToken();

    if (!token) {
      setNotice('Token de acesso nao encontrado.');
      setLoading(false);
      return;
    }

    setLoading(true);
    setNotice('');

    const [
      departmentsResponse,
      quickRepliesResponse,
      automationRulesResponse,
      statusModelResponse
    ] = await Promise.all([
      listAttendanceSettingsDepartments(token),
      listAttendanceSettingsQuickReplies(token),
      listAttendanceSettingsAutomationRules(token),
      getAttendanceSettingsStatusModel(token)
    ]);

    if (departmentsResponse.success) {
      setDepartments(departmentsResponse.data.departments || []);
    } else {
      setNotice(departmentsResponse.error.message || 'Nao foi possivel carregar departamentos.');
    }

    if (quickRepliesResponse.success) {
      setQuickReplies(quickRepliesResponse.data.quickReplies || []);
    }

    if (automationRulesResponse.success) {
      setAutomationRules(automationRulesResponse.data.rules || []);
    }

    if (statusModelResponse.success) {
      setStatusModel(statusModelResponse.data);
    }

    setLoading(false);
  }

  useEffect(() => {
    void loadSettings();
  }, []);

  return (
    <section className="attendance-settings-shell">
      <section className="inbox-hero">
        <div>
          <span>Configuracoes de atendimento</span>
          <h1>Attendance Settings</h1>
          <p>Centralize departamentos, respostas rapidas, automacoes e status padronizados fora do fluxo principal do inbox.</p>
        </div>

        <div className="inbox-hero-brand">
          /assets/lh_chatbot_favicon.png
          <strong>LH Solucao</strong>
          <small>Chat Bot Meta</small>
        </div>
      </section>

      {notice ? <div className="form-message">{notice}</div> : null}

      <section className="attendance-settings-actions">
        <button onClick={() => void loadSettings()} type="button">
          Atualizar configuracoes
        </button>

        <a href="/app/inbox">Voltar para atendimento</a>
      </section>

      {loading ? <div className="conversation-empty">Carregando configuracoes...</div> : null}

      <section className="attendance-settings-summary">
        <article>
          <strong>{stats.activeDepartments}</strong>
          <span>Departamentos ativos</span>
        </article>

        <article>
          <strong>{stats.activeQuickReplies}</strong>
          <span>Respostas rapidas ativas</span>
        </article>

        <article>
          <strong>{stats.activeAutomations}</strong>
          <span>Automacoes ativas</span>
        </article>

        <article>
          <strong>{stats.dryRunAutomations}</strong>
          <span>Automacoes em dryRun</span>
        </article>
      </section>

      <section className="attendance-settings-grid">
        <article className="attendance-settings-card">
          <header>
            <div>
              <strong>Departamentos</strong>
              <span>Filas e setores usados na central</span>
            </div>
          </header>

          <div className="attendance-settings-list">
            {departments.length ? departments.map((department) => (
              <div key={department.id}>
                <strong>{department.name}</strong>
                <span>{department.description || 'Sem descricao'}</span>
                <em>{department.isActive === false ? 'Inativo' : 'Ativo'}</em>
              </div>
            )) : <p>Nenhum departamento encontrado.</p>}
          </div>
        </article>

        <article className="attendance-settings-card">
          <header>
            <div>
              <strong>Respostas rapidas</strong>
              <span>Textos prontos por departamento</span>
            </div>
          </header>

          <div className="attendance-settings-list">
            {quickReplies.length ? quickReplies.slice(0, 12).map((reply) => (
              <div key={reply.id}>
                <strong>{reply.title}</strong>
                <span>{reply.departmentName || 'Sem departamento'}</span>
                <em>{reply.isActive === false ? 'Inativa' : 'Ativa'}</em>
              </div>
            )) : <p>Nenhuma resposta rapida encontrada.</p>}
          </div>
        </article>

        <article className="attendance-settings-card">
          <header>
            <div>
              <strong>Automacoes</strong>
              <span>Regras por status e departamento</span>
            </div>
          </header>

          <div className="attendance-settings-list">
            {automationRules.length ? automationRules.map((rule) => (
              <div key={rule.id}>
                <strong>{rule.name}</strong>
                <span>{rule.departmentName} / {rule.triggerStatus}</span>
                <em>{rule.isActive ? 'Ativa' : 'Inativa'} {rule.sendDryRun ? '- dryRun' : ''}</em>
              </div>
            )) : <p>Nenhuma automacao encontrada.</p>}
          </div>
        </article>

        <article className="attendance-settings-card">
          <header>
            <div>
              <strong>Status padronizados</strong>
              <span>Modelo operacional do atendimento</span>
            </div>
          </header>

          <div className="attendance-settings-status">
            {statusModel ? (
              <>
                <StatusGroup title="Conversation" items={statusModel.groups.conversation} />
                <StatusGroup title="Attendance" items={statusModel.groups.attendance} />
                <StatusGroup title="Send" items={statusModel.groups.send} />
                <StatusGroup title="Closure" items={statusModel.groups.closure} />
              </>
            ) : <p>Modelo de status nao carregado.</p>}
          </div>
        </article>

        <article className="attendance-settings-card attendance-settings-wide">
          <header>
            <div>
              <strong>Pendencias e proximos refinamentos</strong>
              <span>Itens que ainda devem sair do inbox principal</span>
            </div>
          </header>

          <div className="attendance-settings-roadmap">
            <span>Separar envio, encerramento e historico visual</span>
            <span>Isolar configuracoes avancadas de automacao</span>
            <span>Limpar dados sinteticos em etapa propria</span>
            <span>Retomar recebimento Meta quando houver retorno</span>
          </div>
        </article>
      </section>
    </section>
  );
}

function StatusGroup(props: {
  title: string;
  items: Array<{
    id: string;
    code: string;
    label: string;
    isTerminal: boolean;
  }>;
}) {
  return (
    <div>
      <strong>{props.title}</strong>

      <div>
        {props.items.map((item) => (
          <span key={item.id}>
            {item.label}
            {item.isTerminal ? ' terminal' : ''}
          </span>
        ))}
      </div>
    </div>
  );
}
