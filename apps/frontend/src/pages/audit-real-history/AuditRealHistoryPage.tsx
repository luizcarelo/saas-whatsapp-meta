import { useEffect, useState } from 'react';
import {
  downloadAuditRealHygieneRunsCsvRequest,
  listAuditRealHygieneRunsRequest
} from '../../services/operational-audit.service';
import { useAuthStore } from '../../stores/auth.store';
import type { AuditHygieneRunItem } from '../../types/operational-audit.types';

export function AuditRealHistoryPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [runs, setRuns] = useState<AuditHygieneRunItem[]>([]);
  const [total, setTotal] = useState(0);
  const [notice, setNotice] = useState('');
  const [loading, setLoading] = useState(true);
  const [exporting, setExporting] = useState(false);

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadHistory() {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setNotice('');

    const response = await listAuditRealHygieneRunsRequest(token);

    if (response.success) {
      setRuns(response.data.runs);
      setTotal(response.data.total);
    } else {
      setNotice(response.error.message || 'Nao foi possivel carregar historico.');
    }

    setLoading(false);
  }

  async function handleExportCsv() {
    const token = getToken();

    if (!token) {
      return;
    }

    setExporting(true);
    setNotice('');

    try {
      await downloadAuditRealHygieneRunsCsvRequest(token);
      setNotice('Historico exportado em CSV com sucesso.');
    } catch (_error) {
      setNotice('Nao foi possivel exportar o historico.');
    } finally {
      setExporting(false);
    }
  }

  useEffect(() => {
    void loadHistory();
  }, []);

  return (
    <section>
      <div className="page-heading">
        <span>Auditoria</span>
        <h1>Historico de higienizacoes reais</h1>
        <p>Consulte e exporte as execucoes reais registradas.</p>
      </div>

      {notice ? <div className="form-message">{notice}</div> : null}

      <section className="hygiene-history-toolbar">
        <div>
          <strong>Exportacao CSV</strong>
          <p>Baixe o historico das ultimas 100 execucoes reais registradas.</p>
        </div>

        <button disabled={exporting} onClick={() => void handleExportCsv()} type="button">
          Exportar CSV
        </button>
      </section>

      <section className="hygiene-history-summary">
        <article>
          <span>Total de execucoes</span>
          <strong>{total}</strong>
          <p>Ultimas 100 execucoes registradas.</p>
        </article>
      </section>

      {loading ? (
        <div className="conversation-empty">
          Carregando historico...
        </div>
      ) : null}

      {!loading && runs.length === 0 ? (
        <div className="conversation-empty">
          Nenhuma execucao real registrada.
        </div>
      ) : null}

      <section className="hygiene-history-table">
        {runs.map((run) => (
          <article key={run.id}>
            <div>
              <strong>{run.createdAt}</strong>
              <span>ID: {run.id}</span>
              <span>Retencao: {run.retentionDays} dias</span>
            </div>

            <div>
              <span>Dry-run: {run.dryRun ? 'sim' : 'nao'}</span>
              <span>Mensagens antigas: {run.oldMessages}</span>
              <span>Falhas com metadata: {run.oldFailedMessagesWithMetadata}</span>
              <span>Webhooks antigos: {run.oldWebhookEvents}</span>
            </div>

            <div>
              <span>Mensagens redigidas: {run.messagesRedacted}</span>
              <span>Webhooks redigidos: {run.webhookEventsRedacted}</span>
            </div>
          </article>
        ))}
      </section>
    </section>
  );
}
