import { FormEvent, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { loginRequest } from '../../services/auth.service';
import { useAuthStore } from '../../stores/auth.store';

export function LoginPage() {
  const navigate = useNavigate();
  const setSession = useAuthStore((state) => state.setSession);

  const [email, setEmail] = useState('admin@lhsolucao.com.br');
  const [password, setPassword] = useState('');
  const [errorMessage, setErrorMessage] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setErrorMessage('');
    setLoading(true);

    try {
      const response = await loginRequest(email, password);

      if (!response.success) {
        setErrorMessage(response.error.message || 'Login invalido');
        return;
      }

      setSession(response.data.user, response.data.access_token);
      navigate('/app/dashboard');
    } catch (_error) {
      setErrorMessage('Nao foi possivel conectar ao servidor');
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="page page-login">
      <section className="login-card">
        <div className="brand-mark">LH</div>

        <div className="login-header">
          <h1>SaaS WhatsApp Meta</h1>
          <p>Acesse o painel do bot integrado a API oficial da Meta.</p>
        </div>

        <form className="login-form" onSubmit={handleSubmit}>
          <label>
            Email
            <input
              autoComplete="email"
              name="email"
              onChange={(event) => setEmail(event.target.value)}
              placeholder="admin@lhsolucao.com.br"
              type="email"
              value={email}
            />
          </label>

          <label>
            Senha
            <input
              autoComplete="current-password"
              name="password"
              onChange={(event) => setPassword(event.target.value)}
              placeholder="Digite a senha inicial"
              type="password"
              value={password}
            />
          </label>

          {errorMessage ? (
            <div className="form-error">{errorMessage}</div>
          ) : null}

          <button disabled={loading} type="submit">
            {loading ? 'Entrando...' : 'Entrar'}
          </button>
        </form>

        <p className="login-help">
          Use a senha gravada no log local da Etapa 24.
        </p>
      </section>
    </main>
  );
}
