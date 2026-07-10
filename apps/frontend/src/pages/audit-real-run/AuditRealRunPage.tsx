import { useEffect, useState } from 'react';
import {
  getAuditRetentionPolicyRequest,
  previewAuditHygieneRequest,
  runAuditRealHygieneRequest
} from '../../services/operational-audit.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
  AuditHygieneResult,
  AuditRetentionPolicy
} from '../../types/operational-audit.types';

const confirmationPhrase = 'EXECUTAR_HIGIENIZACAO_REAL';

export function AuditRealRunPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [policy, setPolicy] = useState<AuditRetentionPolicy | null>(null);
  const [retentionDays, setRetentionDays] = useState(180);
  const [typedPhrase, setTypedPhrase] = useState('');
  const [preview, setPreview] = useState<AuditHygieneResult | null>(null);
  const [result, setResult] = useState<AuditHygieneResult | null>(null);
  const [notice, setNotice] = useState('');
  const [running, setRunning] = useState(false);

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadPolicy() {
    const token = getToken();

    if (!token) {
      return;
    }

    const response = await getAuditRetentionPolicyRequest(token);

    if (response.success) {
      setPolicy(response.data);
      setRetentionDays(response.data.auditRetentionDays);
    }
  }

  useEffect(() => {
    void loadPolicy();
  }, []);

  async function handlePreview() {
    const token = getToken();

    if (!token) {
      return;
    }

    const response = await previewAuditHygieneRequest(token, retentionDays);

    if (response.success) {
      setPreview(response.data);
      setNotice('Preview carregado. Revise os candidatos antes de executar.');
      return;
    }

    setNotice(response.error.message || 'Nao foi possivel carregar preview.');
  }

  async function handleRealRun() {
    const token = getToken();

    if (!token) {
      return;
    }

    if (typedPhrase !== confirmationPhrase) {
      setNotice('Frase de confirmacao invalida.');
      return;
    }

    setRunning(true);
    setNotice('');

    try {
      const response = await runAuditRealHygieneRequest(token, retentionDays, typedPhrase);

      if (response.success) {
        setResult(response.data);
        setNotice('Higienizacao real controlada executada.');
        return;
      }

      setNotice(response.error.message || 'Nao foi possivel executar higienizacao real.');
    } finally {
      setRunning(false);
    }
  }

  return (
    <section>
      <div className="page-heading">
        <span>Auditoria</span>
        <h1>Execucao real controlada</h1>
        <p>Execute higienizacao real somente apos revisar preview, backup e frase de confirmacao.</p>
      </div>

      {notice ? <div className="form-message">{notice}</div> : null}

      <section className="real-hygiene-warning">
        <strong>Acao sensivel</strong>
        <p>
          Esta tela executa higienizacao real. Use apenas depois de validar backup SQL,
          politica de retencao e preview.
        </p>
      </section>

      <section className="real-hygiene-panel">
        <div>
          <strong>Politica de retencao</strong>
          <p>Fonte: {policy?.source || 'nao carregada'}</p>
        </div>

        <label>
          Dias
          <input
            min="1"
            onChange={(event) => setRetentionDays(Number(event.target.value))}
            type="number"
            value={retentionDays}
          />
        </label>

        <button onClick={() => void handlePreview()} type="button">
          Gerar preview
        </button>
      </section>

      {preview ? (
        <section className="real-hygiene-result">
          <h2>Preview</h2>
          <span>Cutoff: {preview.cutoff}</span>
          <span>Mensagens antigas: {preview.candidates.oldMessages}</span>
          <span>Falhas com metadata: {preview.candidates.oldFailedMessagesWithMetadata}</span>
          <span>Webhooks antigos: {preview.candidates.oldWebhookEvents}</span>
        </section>
      ) : null}

      <section className="real-hygiene-confirmation">
        <div>
          <strong>Confirmacao obrigatoria</strong>
          <p>Digite exatamente: {confirmationPhrase}</p>
        </div>

        <input
          onChange={(event) => setTypedPhrase(event.target.value)}
          placeholder="Digite a frase de confirmacao"
          value={typedPhrase}
        />

        <button
          disabled={running || typedPhrase !== confirmationPhrase}
          onClick={() => void handleRealRun()}
          type="button"
        >
          {running ? 'Executando...' : 'Executar higienizacao real'}
        </button>
      </section>

      {result ? (
        <section className="real-hygiene-result">
          <h2>Resultado</h2>
          <span>Dry-run: {result.dryRun ? 'sim' : 'nao'}</span>
          <span>Mensagens redigidas: {result.changed.messagesRedacted}</span>
          <span>Webhooks redigidos: {result.changed.webhookEventsRedacted}</span>
        </section>
      ) : null}
    </section>
  );
}
