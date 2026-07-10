import { useEffect, useState } from 'react';
import { getAttendanceDashboardSummaryRequest } from '../../services/attendance-dashboard.service';
import { useAuthStore } from '../../stores/auth.store';
import type { AttendanceDashboardSummary } from '../../types/attendance-dashboard.types';

const emptySummary: AttendanceDashboardSummary = {
  conversations: {
    total: 0,
    open: 0,
    closed: 0,
    unassigned: 0,
    highPriority: 0
  },
  departments: [],
  ratings: {
    total: 0,
    average: 0
  },
  activity: {
    notes: 0,
    tags: 0,
    quickReplies: 0,
    closures: 0
  }
};

export function AttendanceDashboardPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [summary, setSummary] = useState<AttendanceDashboardSummary>(emptySummary);
  const [notice, setNotice] = useState('');
  const [loading, setLoading] = useState(true);

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadDashboard() {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setNotice('');

    const response = await getAttendanceDashboardSummaryRequest(token);

    if (response.success) {
      setSummary(response.data);
    } else {
      setNotice(response.error.message || 'Nao foi possivel carregar dashboard de atendimento.');
    }

    setLoading(false);
  }

  useEffect(() => {
    void loadDashboard();
  }, []);

  return (
    <section className="attendance-dashboard-shell">
      <section className="inbox-hero">
        <div>
          <span>Dashboard de atendimento</span>
          <h1>Visao operacional da central</h1>
          <p>Acompanhe conversas, filas, responsaveis, avaliacoes e atividades da central de atendimento.</p>
        </div>

        <div className="inbox-hero-brand">
          /assets/lh_chatbot_favicon.png
          <strong>LH Solucao</strong>
          <small>Chat Bot Meta</small>
        </div>
      </section>

      {notice ? <div className="form-message">{notice}</div> : null}
      {loading ? <div className="conversation-empty">Carregando dashboard...</div> : null}

      <section className="attendance-dashboard-grid">
        <article>
          <span>Total</span>
          <strong>{summary.conversations.total}</strong>
          <p>Conversas monitoradas</p>
        </article>

        <article>
          <span>Abertas</span>
          <strong>{summary.conversations.open}</strong>
          <p>Em atendimento ou aguardando</p>
        </article>

        <article>
          <span>Encerradas</span>
          <strong>{summary.conversations.closed}</strong>
          <p>Finalizadas ou arquivadas</p>
        </article>

        <article>
          <span>Sem responsavel</span>
          <strong>{summary.conversations.unassigned}</strong>
          <p>Precisam de atribuicao</p>
        </article>

        <article>
          <span>Alta prioridade</span>
          <strong>{summary.conversations.highPriority}</strong>
          <p>Alta ou urgente</p>
        </article>

        <article>
          <span>Avaliacao media</span>
          <strong>{summary.ratings.average}</strong>
          <p>{summary.ratings.total} avaliacoes</p>
        </article>
      </section>

      <section className="attendance-dashboard-panels">
        <article>
          <div className="inbox-panel-title">
            <strong>Filas por departamento</strong>
            <span>Volume aberto e encerrado por fila</span>
          </div>

          <div className="department-metric-list">
            {summary.departments.length ? summary.departments.map((department) => (
              <div key={department.name}>
                <span style={{ backgroundColor: department.color }} />
                <strong>{department.name}</strong>
                <em>Total {department.total}</em>
                <small>Abertas {department.open} - Encerradas {department.closed}</small>
              </div>
            )) : <p>Nenhum departamento encontrado.</p>}
          </div>
        </article>

        <article>
          <div className="inbox-panel-title">
            <strong>Atividades da central</strong>
            <span>Recursos utilizados no atendimento</span>
          </div>

          <div className="activity-metric-list">
            <div>
              <strong>{summary.activity.notes}</strong>
              <span>Notas internas</span>
            </div>

            <div>
              <strong>{summary.activity.tags}</strong>
              <span>Tags vinculadas</span>
            </div>

            <div>
              <strong>{summary.activity.quickReplies}</strong>
              <span>Respostas rapidas</span>
            </div>

            <div>
              <strong>{summary.activity.closures}</strong>
              <span>Encerramentos</span>
            </div>
          </div>
        </article>
      </section>
    </section>
  );
}
