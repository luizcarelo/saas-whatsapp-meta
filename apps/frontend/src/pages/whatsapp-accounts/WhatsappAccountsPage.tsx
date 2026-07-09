import { FormEvent, useEffect, useState } from 'react';
import {
  createWhatsappAccountRequest,
  deleteWhatsappAccountRequest,
  listWhatsappAccountsRequest
} from '../../services/whatsapp-accounts.service';
import { useAuthStore } from '../../stores/auth.store';
import type {
  WhatsappAccountFormData,
  WhatsappAccountItem
} from '../../types/whatsapp-accounts.types';

const initialForm: WhatsappAccountFormData = {
  wabaId: '',
  phoneNumberId: '',
  displayPhoneNumber: '',
  verifiedName: '',
  accessToken: '',
  status: 'pending'
};

const statusLabel: Record<string, string> = {
  active: 'Ativa',
  inactive: 'Inativa',
  pending: 'Pendente',
  disconnected: 'Desconectada',
  error: 'Erro'
};

export function WhatsappAccountsPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [accounts, setAccounts] = useState<WhatsappAccountItem[]>([]);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [form, setForm] = useState<WhatsappAccountFormData>(initialForm);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadAccounts(currentSearch = search) {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);

    try {
      const response = await listWhatsappAccountsRequest(token, currentSearch);

      if (response.success) {
        setAccounts(response.data.accounts);
        setTotal(response.data.total);
      }
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadAccounts('');
  }, []);

  async function handleSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    await loadAccounts(search);
  }

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();

    const token = getToken();

    if (!token) {
      return;
    }

    setSaving(true);
    setMessage('');

    try {
      const response = await createWhatsappAccountRequest(token, form);

      if (!response.success) {
        setMessage(response.error.message || 'Nao foi possivel criar a conta');
        return;
      }

      setForm(initialForm);
      setMessage('Conta WhatsApp criada com sucesso');
      await loadAccounts(search);
    } catch (_error) {
      setMessage('Nao foi possivel conectar ao servidor');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(accountId: string) {
    const token = getToken();

    if (!token) {
      return;
    }

    setMessage('');

    const response = await deleteWhatsappAccountRequest(token, accountId);

    if (!response.success) {
      setMessage(response.error.message || 'Nao foi possivel remover a conta');
      return;
    }

    setMessage('Conta WhatsApp removida com sucesso');
    await loadAccounts(search);
  }

  return (
    <section>
      <div className="page-heading">
        <span>WhatsApp</span>
        <h1>Contas WhatsApp</h1>
        <p>Gerencie contas WhatsApp vinculadas ao tenant autenticado.</p>
      </div>

      <div className="whatsapp-layout">
        <section className="whatsapp-panel">
          <div className="panel-heading">
            <div>
              <h2>Nova conta</h2>
              <p>Cadastre uma conta para futura integracao com a API oficial da Meta.</p>
            </div>
          </div>

          <form className="whatsapp-form" onSubmit={handleCreate}>
            <label>
              WABA ID
              <input
                onChange={(event) => setForm({ ...form, wabaId: event.target.value })}
                placeholder="WABA ID"
                required
                value={form.wabaId}
              />
            </label>

            <label>
              Phone Number ID
              <input
                onChange={(event) => setForm({ ...form, phoneNumberId: event.target.value })}
                placeholder="Phone Number ID"
                required
                value={form.phoneNumberId}
              />
            </label>

            <label>
              Telefone de exibicao
              <input
                onChange={(event) => setForm({ ...form, displayPhoneNumber: event.target.value })}
                placeholder="+55 21 99999 9999"
                required
                value={form.displayPhoneNumber}
              />
            </label>

            <label>
              Nome verificado
              <input
                onChange={(event) => setForm({ ...form, verifiedName: event.target.value })}
                placeholder="Nome da empresa"
                value={form.verifiedName}
              />
            </label>

            <label>
              Access Token
              <input
                onChange={(event) => setForm({ ...form, accessToken: event.target.value })}
                placeholder="Token temporario ou definitivo"
                type="password"
                value={form.accessToken}
              />
            </label>

            <label>
              Status
              <select
                onChange={(event) => setForm({ ...form, status: event.target.value })}
                value={form.status}
              >
                <option value="pending">Pendente</option>
                <option value="active">Ativa</option>
                <option value="inactive">Inativa</option>
                <option value="disconnected">Desconectada</option>
                <option value="error">Erro</option>
              </select>
            </label>

            <button disabled={saving} type="submit">
              {saving ? 'Salvando...' : 'Criar conta'}
            </button>
          </form>

          {message ? <div className="form-message">{message}</div> : null}
        </section>

        <section className="whatsapp-panel whatsapp-list-panel">
          <div className="panel-heading">
            <div>
              <h2>Contas cadastradas</h2>
              <p>Total encontrado: {total}</p>
            </div>
          </div>

          <form className="whatsapp-search" onSubmit={handleSearch}>
            <input
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Buscar por WABA, telefone ou nome"
              value={search}
            />

            <button type="submit">
              Buscar
            </button>
          </form>

          {loading ? (
            <div className="empty-panel">
              <strong>Carregando contas...</strong>
              <p>Aguarde enquanto os dados sao carregados.</p>
            </div>
          ) : null}

          {!loading && accounts.length === 0 ? (
            <div className="empty-panel">
              <strong>Nenhuma conta encontrada</strong>
              <p>Crie uma conta WhatsApp para iniciar a configuracao.</p>
            </div>
          ) : null}

          <div className="whatsapp-list">
            {accounts.map((account) => (
              <article className="whatsapp-card" key={account.id}>
                <div>
                  <strong>{account.verifiedName || account.displayPhoneNumber}</strong>
                  <span>{account.displayPhoneNumber}</span>
                  <small>WABA: {account.wabaId}</small>
                  <small>Phone ID: {account.phoneNumberId}</small>
                </div>

                <div className="whatsapp-card-actions">
                  <em>{statusLabel[account.status] || account.status}</em>
                  <button onClick={() => void handleDelete(account.id)} type="button">
                    Remover
                  </button>
                </div>
              </article>
            ))}
          </div>
        </section>
      </div>
    </section>
  );
}
