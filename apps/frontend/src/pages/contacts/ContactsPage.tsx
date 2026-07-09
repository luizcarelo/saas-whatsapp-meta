import { FormEvent, useEffect, useState } from 'react';
import {
  createContactRequest,
  deleteContactRequest,
  listContactsRequest
} from '../../services/contacts.service';
import { useAuthStore } from '../../stores/auth.store';
import type { ContactFormData, ContactItem } from '../../types/contacts.types';

const initialForm: ContactFormData = {
  name: '',
  phone: '',
  email: '',
  document: ''
};

export function ContactsPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);

  const [contacts, setContacts] = useState<ContactItem[]>([]);
  const [total, setTotal] = useState(0);
  const [search, setSearch] = useState('');
  const [form, setForm] = useState<ContactFormData>(initialForm);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState('');

  function getToken() {
    return accessToken || loadToken();
  }

  async function loadContacts(currentSearch = search) {
    const token = getToken();

    if (!token) {
      setLoading(false);
      return;
    }

    setLoading(true);

    try {
      const response = await listContactsRequest(token, currentSearch);

      if (response.success) {
        setContacts(response.data.contacts);
        setTotal(response.data.total);
      }
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadContacts('');
  }, []);

  async function handleSearch(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    void loadContacts(search);
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
      const response = await createContactRequest(token, form);

      if (!response.success) {
        setMessage(response.error.message || 'Nao foi possivel criar o contato');
        return;
      }

      setForm(initialForm);
      setMessage('Contato criado com sucesso');
      await loadContacts(search);
    } catch (_error) {
      setMessage('Nao foi possivel conectar ao servidor');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(contactId: string) {
    const token = getToken();

    if (!token) {
      return;
    }

    setMessage('');

    const response = await deleteContactRequest(token, contactId);

    if (!response.success) {
      setMessage(response.error.message || 'Nao foi possivel remover o contato');
      return;
    }

    setMessage('Contato removido com sucesso');
    await loadContacts(search);
  }

  return (
    <section>
      <div className="page-heading">
        <span>Contatos</span>
        <h1>Agenda de contatos</h1>
        <p>Gerencie contatos vinculados ao tenant autenticado.</p>
      </div>

      <div className="contacts-layout">
        <section className="contacts-panel">
          <div className="panel-heading">
            <div>
              <h2>Novo contato</h2>
              <p>Cadastre contatos para futuras conversas pelo WhatsApp.</p>
            </div>
          </div>

          <form className="contacts-form" onSubmit={handleCreate}>
            <label>
              Nome
              <input
                onChange={(event) => setForm({ ...form, name: event.target.value })}
                placeholder="Nome do contato"
                value={form.name}
              />
            </label>

            <label>
              Telefone
              <input
                onChange={(event) => setForm({ ...form, phone: event.target.value })}
                placeholder="5521999999999"
                required
                value={form.phone}
              />
            </label>

            <label>
              Email
              <input
                onChange={(event) => setForm({ ...form, email: event.target.value })}
                placeholder="email@exemplo.com"
                type="email"
                value={form.email}
              />
            </label>

            <label>
              Documento
              <input
                onChange={(event) => setForm({ ...form, document: event.target.value })}
                placeholder="CPF ou CNPJ"
                value={form.document}
              />
            </label>

            <button disabled={saving} type="submit">
              {saving ? 'Salvando...' : 'Criar contato'}
            </button>
          </form>

          {message ? <div className="form-message">{message}</div> : null}
        </section>

        <section className="contacts-panel contacts-list-panel">
          <div className="panel-heading">
            <div>
              <h2>Contatos</h2>
              <p>Total encontrado: {total}</p>
            </div>
          </div>

          <form className="contacts-search" onSubmit={handleSearch}>
            <input
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Buscar por nome, telefone ou email"
              value={search}
            />

            <button type="submit">
              Buscar
            </button>
          </form>

          {loading ? (
            <div className="empty-panel">
              <strong>Carregando contatos...</strong>
              <p>Aguarde enquanto os dados sao carregados.</p>
            </div>
          ) : null}

          {!loading && contacts.length === 0 ? (
            <div className="empty-panel">
              <strong>Nenhum contato encontrado</strong>
              <p>Crie um novo contato ou ajuste a busca.</p>
            </div>
          ) : null}

          <div className="contacts-list">
            {contacts.map((contact) => (
              <article className="contact-card" key={contact.id}>
                <div>
                  <strong>{contact.name || 'Sem nome'}</strong>
                  <span>{contact.phone}</span>
                  {contact.email ? <small>{contact.email}</small> : null}
                </div>

                <button onClick={() => void handleDelete(contact.id)} type="button">
                  Remover
                </button>
              </article>
            ))}
          </div>
        </section>
      </div>
    </section>
  );
}
