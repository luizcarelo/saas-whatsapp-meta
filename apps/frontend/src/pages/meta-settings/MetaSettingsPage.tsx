import { useEffect, useMemo, useState } from 'react';
import {
  getWhatsappOperationalRequest,
  listWhatsappAccountsRequest
} from '../../services/whatsapp-accounts.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
  MetaPhoneInfo,
  MetaTemplateItem,
  WhatsappAccountItem
} from '../../types/whatsapp-accounts.types';

function statusClass(value?: string) {
  if (value === 'CONNECTED' || value === 'GREEN' || value === 'APPROVED') {
    return 'operational-good';
  }

  if (value === 'YELLOW' || value === 'PENDING_REVIEW') {
    return 'operational-warning';
  }

  if (value === 'RED' || value === 'DECLINED' || value === 'DISCONNECTED') {
    return 'operational-danger';
  }

  return 'operational-neutral';
}

function valueOrEmpty(value?: string) {
  return value && value.trim() ? value : 'Nao informado';
}

export function MetaSettingsPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [accounts, setAccounts] = useState<WhatsappAccountItem[]>([]);
  const [selectedAccountId, setSelectedAccountId] = useState('');
  const [phoneInfo, setPhoneInfo] = useState<MetaPhoneInfo | null>(null);
  const [templates, setTemplates] = useState<MetaTemplateItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState('');

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadAccounts() {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);

    const response = await listWhatsappAccountsRequest(token);

    if (!response.success) {
      setMessage(response.error.message || 'Nao foi possivel carregar contas');
      setLoading(false);
      return;
    }

    const activeAccounts = response.data.accounts.filter((account) => account.status === 'active');
    const ordered = activeAccounts.length > 0 ? activeAccounts : response.data.accounts;

    setAccounts(ordered);

    const preferred = ordered.find((account) => account.phoneNumberId === '1235882016268785')
      || ordered.find((account) => /^[0-9]+$/.test(account.phoneNumberId))
      || ordered[0];

    if (preferred) {
      setSelectedAccountId(preferred.id);
      await loadOperational(preferred.id);
    } else {
      setLoading(false);
    }
  }

  async function loadOperational(accountId: string) {
    const token = getToken();

    if (!token) {
      return;
    }

    setMessage('');

    const response = await getWhatsappOperationalRequest(token, accountId);

    if (!response.success) {
      setMessage(response.error.message || 'Nao foi possivel consultar a Meta');
      setLoading(false);
      return;
    }

    setPhoneInfo(response.data.phoneInfo);
    setTemplates(response.data.templates.data || []);
    setLoading(false);
  }

  useEffect(() => {
    void loadAccounts();
  }, []);

  const selectedAccount = useMemo(() => {
    return accounts.find((account) => account.id === selectedAccountId) || null;
  }, [accounts, selectedAccountId]);

  const templateSummary = useMemo(() => {
    return {
      total: templates.length,
      approved: templates.filter((template) => template.status === 'APPROVED').length,
      marketing: templates.filter((template) => template.category === 'MARKETING').length,
      utility: templates.filter((template) => template.category === 'UTILITY').length
    };
  }, [templates]);

  async function handleAccountChange(accountId: string) {
    setSelectedAccountId(accountId);
    setLoading(true);
    await loadOperational(accountId);
  }

  async function handleRefresh() {
    if (!selectedAccountId) {
      return;
    }

    setLoading(true);
    await loadOperational(selectedAccountId);
  }

  return (
    <section>
      <div className="page-heading">
        <span>Meta</span>
        <h1>Configuracao operacional</h1>
        <p>Acompanhe a conta WhatsApp ativa, status do numero e templates oficiais.</p>
      </div>

      <div className="meta-settings-toolbar">
        <label>
          Conta WhatsApp
          <select
            onChange={(event) => void handleAccountChange(event.target.value)}
            value={selectedAccountId}
          >
            {accounts.map((account) => (
              <option key={account.id} value={account.id}>
                {account.verifiedName || account.displayPhoneNumber} - {account.phoneNumberId}
              </option>
            ))}
          </select>
        </label>

        <button onClick={() => void handleRefresh()} type="button">
          Atualizar status
        </button>
      </div>

      {message ? <div className="form-message">{message}</div> : null}

      {loading ? (
        <div className="empty-panel">
          <strong>Carregando configuracao operacional...</strong>
          <p>Aguarde enquanto consultamos a Meta.</p>
        </div>
      ) : null}

      {!loading && selectedAccount ? (
        <>
          <div className="meta-operational-grid">
            <article className="meta-operational-card">
              <span>Conta no sistema</span>
              <strong>{selectedAccount.verifiedName || 'Sem nome verificado'}</strong>
              <p>{selectedAccount.displayPhoneNumber}</p>
              <small>Phone Number ID: {selectedAccount.phoneNumberId}</small>
            </article>

            <article className="meta-operational-card">
              <span>Status Meta</span>
              <strong className={statusClass(phoneInfo?.status)}>
                {valueOrEmpty(phoneInfo?.status)}
              </strong>
              <p>Estado atual do numero na Meta.</p>
            </article>

            <article className="meta-operational-card">
              <span>Qualidade</span>
              <strong className={statusClass(phoneInfo?.quality_rating)}>
                {valueOrEmpty(phoneInfo?.quality_rating)}
              </strong>
              <p>Indicador de qualidade reportado pela Meta.</p>
            </article>

            <article className="meta-operational-card">
              <span>Nome verificado</span>
              <strong>{valueOrEmpty(phoneInfo?.verified_name)}</strong>
              <p>Status do nome: {valueOrEmpty(phoneInfo?.name_status)}</p>
            </article>
          </div>

          <div className="meta-operational-grid small">
            <article className="meta-operational-card">
              <span>Templates</span>
              <strong>{templateSummary.total}</strong>
              <p>Total carregado da WABA.</p>
            </article>

            <article className="meta-operational-card">
              <span>Aprovados</span>
              <strong className="operational-good">{templateSummary.approved}</strong>
              <p>Templates prontos para envio.</p>
            </article>

            <article className="meta-operational-card">
              <span>Marketing</span>
              <strong>{templateSummary.marketing}</strong>
              <p>Templates de marketing.</p>
            </article>

            <article className="meta-operational-card">
              <span>Utility</span>
              <strong>{templateSummary.utility}</strong>
              <p>Templates utilitarios.</p>
            </article>
          </div>

          <section className="meta-details-panel">
            <div className="panel-heading">
              <div>
                <h2>Detalhes do numero</h2>
                <p>Dados retornados pela API da Meta.</p>
              </div>
            </div>

            <div className="meta-details-list">
              <div>
                <span>ID</span>
                <strong>{valueOrEmpty(phoneInfo?.id)}</strong>
              </div>

              <div>
                <span>Telefone exibido</span>
                <strong>{valueOrEmpty(phoneInfo?.display_phone_number)}</strong>
              </div>

              <div>
                <span>Verificacao de codigo</span>
                <strong>{valueOrEmpty(phoneInfo?.code_verification_status)}</strong>
              </div>

              <div>
                <span>Limite de mensagens</span>
                <strong>{valueOrEmpty(phoneInfo?.messaging_limit_tier)}</strong>
              </div>
            </div>
          </section>

          <section className="meta-details-panel">
            <div className="panel-heading">
              <div>
                <h2>Templates oficiais</h2>
                <p>Lista de templates retornados da WABA.</p>
              </div>
            </div>

            <div className="meta-template-table">
              {templates.map((template) => (
                <article key={template.id}>
                  <div>
                    <strong>{template.name}</strong>
                    <span>{template.language}</span>
                  </div>

                  <em className={statusClass(template.status)}>{template.status}</em>
                  <small>{template.category}</small>
                </article>
              ))}
            </div>
          </section>
        </>
      ) : null}
    </section>
  );
}
