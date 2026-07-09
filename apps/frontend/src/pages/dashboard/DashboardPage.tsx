import { useAuthStore } from '../../stores/auth.store';

export function DashboardPage() {
  const user = useAuthStore((state) => state.user);

  return (
    <section>
      <div className="page-heading">
        <span>Visao geral</span>
        <h1>Dashboard</h1>
        <p>Bem-vindo ao painel inicial do SaaS WhatsApp Meta.</p>
      </div>

      <div className="dashboard-grid">
        <article className="metric-card">
          <span>Status do sistema</span>
          <strong>Online</strong>
          <p>Dominio, backend e banco respondendo corretamente.</p>
        </article>

        <article className="metric-card">
          <span>Usuario</span>
          <strong>{user?.name || 'Admin'}</strong>
          <p>{user?.email || 'Sessao autenticada'}</p>
        </article>

        <article className="metric-card">
          <span>Perfis</span>
          <strong>{user?.roles.join(', ') || 'owner'}</strong>
          <p>Controle de acesso carregado pelo token.</p>
        </article>

        <article className="metric-card">
          <span>Permissoes</span>
          <strong>{user?.permissions.length || 0}</strong>
          <p>Total de permissoes disponiveis para a sessao atual.</p>
        </article>
      </div>
    </section>
  );
}
