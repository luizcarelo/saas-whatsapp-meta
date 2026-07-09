import { Link } from 'react-router-dom';

export function UnauthorizedState() {
  return (
    <main className="state-screen">
      <section className="state-card">
        <h1>Sessao expirada</h1>
        <p>Entre novamente para continuar usando o painel.</p>
        <Link className="primary-link" to="/login">
          Voltar ao login
        </Link>
      </section>
    </main>
  );
}
