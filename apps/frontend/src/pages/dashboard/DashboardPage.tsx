import { useEffect, useMemo, useState } from 'react';
import { getMyProfileRequest } from '../../services/users.service';
import { useAuthStore } from '../../stores/auth.store';
import type { UserProfile } from '../../types/users.types';

export function DashboardPage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);
  const [profile, setProfile] = useState<UserProfile | null>(null);

  useEffect(() => {
    async function loadProfile() {
      const token = accessToken || loadToken();

      if (!token) {
        return;
      }

      const response = await getMyProfileRequest(token);

      if (response.success) {
        setProfile(response.data.user);
      }
    }

    void loadProfile();
  }, [accessToken, loadToken]);

  const modules = useMemo(() => {
    if (!profile) {
      return [];
    }

    return Array.from(new Set(profile.permissions.map((permission) => permission.module))).sort();
  }, [profile]);

  return (
    <section>
      <div className="page-heading">
        <span>Visao geral</span>
        <h1>Dashboard</h1>
        <p>Resumo da sessao autenticada e do tenant atual.</p>
      </div>

      <div className="dashboard-grid">
        <article className="metric-card">
          <span>Status do sistema</span>
          <strong>Online</strong>
          <p>Dominio, backend e banco respondendo corretamente.</p>
        </article>

        <article className="metric-card">
          <span>Tenant</span>
          <strong>{profile?.tenant.name || 'Carregando'}</strong>
          <p>Status: {profile?.tenant.status || 'validando'}</p>
        </article>

        <article className="metric-card">
          <span>Usuario</span>
          <strong>{profile?.name || 'Admin'}</strong>
          <p>{profile?.email || 'Sessao autenticada'}</p>
        </article>

        <article className="metric-card">
          <span>Roles</span>
          <strong>{profile?.roles.map((role) => role.name).join(', ') || 'owner'}</strong>
          <p>Perfis carregados pelo endpoint users me.</p>
        </article>

        <article className="metric-card">
          <span>Permissoes</span>
          <strong>{profile?.permissions.length || 0}</strong>
          <p>Total de permissoes detalhadas do usuario.</p>
        </article>

        <article className="metric-card">
          <span>Modulos</span>
          <strong>{modules.length}</strong>
          <p>{modules.slice(0, 5).join(', ') || 'Carregando modulos'}</p>
        </article>
      </div>
    </section>
  );
}
