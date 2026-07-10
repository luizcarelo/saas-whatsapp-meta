import { useEffect, useState } from 'react';
import {
  listAttendanceSendFailuresRequest,
  listAttendanceSendRetriesRequest,
  retryAttendanceSendFailureRequest
} from '../../services/attendance-send-failures.service';
import { useAuthStore } from '../../stores/auth.store';
import type { AttendanceSendFailureItem } from '../../types/attendance-send-failures.types';

export function SendFailuresPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [failures, setFailures] = useState<AttendanceSendFailureItem[]>([]);
  const [retries, setRetries] = useState<AttendanceSendFailureItem[]>([]);
  const [notice, setNotice] = useState('');
  const [loading, setLoading] = useState(true);
  const [retryingId, setRetryingId] = useState('');
  const [dryRun, setDryRun] = useState(true);

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadData() {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);
    setNotice('');

    const [failuresResponse, retriesResponse] = await Promise.all([
      listAttendanceSendFailuresRequest(token),
      listAttendanceSendRetriesRequest(token)
    ]);

    if (failuresResponse.success) {
      setFailures(failuresResponse.data.failures);
    } else {
      setNotice(failuresResponse.error.message || 'Nao foi possivel carregar falhas de envio.');
    }

    if (retriesResponse.success) {
      setRetries(retriesResponse.data.retries);
    }

    setLoading(false);
  }

  async function retryFailure(sendId: string) {
    const token = getToken();

    if (!token) {
      setNotice('Token de acesso nao encontrado.');
      return;
    }

    setRetryingId(sendId);

    const response = await retryAttendanceSendFailureRequest(token, sendId, {
      dryRun,
      sentByName: 'Retentativa painel'
    });

    if (response.success) {
      if (response.data.retry.dryRun) {
        setNotice('Retentativa validada em dryRun. Nenhuma mensagem real foi enviada.');
      } else if (response.data.retry.status === 'sent') {
        setNotice('Retentativa enviada com sucesso.');
      } else {
        setNotice(response.data.retry.errorMessage || 'Retentativa registrada.');
      }

      await loadData();
    } else {
      setNotice(response.error.message || 'Nao foi possivel retentar envio.');
    }

    setRetryingId('');
  }

  useEffect(() => {
    void loadData();
  }, []);

  return (
    <section className="send-failures-shell">
      <section className="inbox-hero">
        <div>
          <span>Falhas e retentativas</span>
          <h1>Painel de envios com falha</h1>
          <p>Analise falhas retornadas pela Meta ou pelo backend e execute retentativas controladas.</p>
        </div>

        <div className="inbox-hero-brand">
          /assets/lh_chatbot_favicon.png
          <strong>LH Solucao</strong>
          <small>Chat Bot Meta</small>
        </div>
      </section>

      {notice ? <div className="form-message">{notice}</div> : null}

      <section className="send-failures-toolbar">
        <label>
          <input
            checked={dryRun}
            onChange={(event) => setDryRun(event.target.checked)}
            type="checkbox"
          />
          Retentar em modo dryRun
        </label>

        <button onClick={() => void loadData()} type="button">
          Atualizar
        </button>
      </section>

      {loading ? <div className="conversation-empty">Carregando falhas...</div> : null}

      <section className="send-failures-grid">
        <article>
          <div className="inbox-panel-title">
            <strong>Envios com falha</strong>
            <span>{failures.length} registros encontrados</span>
          </div>

          <div className="send-failure-list">
            {failures.length ? failures.map((failure) => (
              <div key={failure.id}>
                <header>
                  <strong>{failure.sentByName}</strong>
                  <span>{failure.status}</span>
                </header>

                <p>{failure.messageBody}</p>

                <small>Origem: {failure.messageOrigin}</small>
                <small>Departamento: {failure.departmentName}</small>
                <small>Retentativas: {failure.retryCount}</small>
                <small>Criado em: {failure.createdAt}</small>

                {failure.errorMessage ? <em>{failure.errorMessage}</em> : null}

                <button
                  disabled={retryingId === failure.id}
                  onClick={() => void retryFailure(failure.id)}
                  type="button"
                >
                  {retryingId === failure.id ? 'Retentando...' : dryRun ? 'Validar retentativa' : 'Retentar envio'}
                </button>
              </div>
            )) : <p>Nenhum envio com falha encontrado.</p>}
          </div>
        </article>

        <article>
          <div className="inbox-panel-title">
            <strong>Retentativas recentes</strong>
            <span>{retries.length} registros encontrados</span>
          </div>

          <div className="send-failure-list">
            {retries.length ? retries.map((retry) => (
              <div key={retry.id}>
                <header>
                  <strong>{retry.sentByName}</strong>
                  <span>{retry.status}{retry.dryRun ? ' - dryRun' : ''}</span>
                </header>

                <p>{retry.messageBody}</p>

                <small>Origem original: {retry.retryOfSendId}</small>
                <small>Criado em: {retry.createdAt}</small>

                {retry.errorMessage ? <em>{retry.errorMessage}</em> : null}
              </div>
            )) : <p>Nenhuma retentativa registrada.</p>}
          </div>
        </article>
      </section>
    </section>
  );
}
