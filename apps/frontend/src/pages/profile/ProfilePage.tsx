import { useEffect, useMemo, useState } from 'react';
import { getMyProfileRequest } from '../../services/users.service';
import { useAuthStore } from '../../stores/auth.store';
import type { UserProfile } from '../../types/users.types';

export function ProfilePage() {
  const accessToken = useAuthStore((state) => state.accessToken);
  const loadToken = useAuthStore((state) => state.loadToken);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadProfile() {
      const token = accessToken || loadToken();

      if (!token) {
        setLoading(false);
        return;
      }

      const response = await getMyProfileRequest(token);

      if (response.success) {
        setProfile(response.data.user);
      }

      setLoading(false);
    }

    void loadProfile();
  }, [accessToken, loadToken]);

  const permissionsByModule = useMemo(() => {
    const grouped = new Map<string, string[]>();

    if (!profile) {
      return [];
    }

    for (const permission of profile.permissions) {
      const current = grouped.get(permission.module) || [];
      current.push(permission.key);
      grouped.set(permission.module, current);
    }

    return Array.from(grouped.entries()).sort((left, right) => left[0].localeCompare(right[0]));
  }, [profile]);

  if (loading) {
    return (
      <section>
        <div className="page-heading">
          <span>Perfil</span>
          <h1>Carregando perfil...</h1>
          <p>Buscando dados detalhados do usuario.</p>
        </div>
      </section>
    );
  }

  if (!profile) {
    return (
      <section>
        <div className="page-heading">
          <span>Perfil</span>
          <h1>Perfil indisponivel</h1>
          <p>Nao foi possivel carregar os dados do usuario.</p>
        </div>
      </section>
    );
  }

  return (
    <section>
      <div className="page-heading">
        <span>Perfil detalhado</span>
        <h1>{profile.name}</h1>
        <p>{profile.email}</p>
      </div>

      <div className="profile-grid">
        <article className="profile-card">
          <span>Tenant</span>
          <strong>{profile.tenant.name}</strong>
          <p>Status: {profile.tenant.status}</p>
        </article>

        <article className="profile-card">
          <span>Status do usuario</span>
          <strong>{profile.status}</strong>
          <p>ID: {profile.id}</p>
        </article>

        <article className="profile-card">
          <span>Roles</span>
          <strong>{profile.roles.map((role) => role.name).join(', ')}</strong>
          <p>Total: {profile.roles.length}</p>
        </article>

        <article className="profile-card">
          <span>Permissoes</span>
          <strong>{profile.permissions.length}</strong>
          <p>Permissoes agrupadas por modulo abaixo.</p>
        </article>
      </div>

      <div className="permissions-panel">
        <h2>Permissoes por modulo</h2>

        <div className="permissions-list">
          {permissionsByModule.map(([moduleName, permissions]) => (
            <article className="permission-group" key={moduleName}>
              <h3>{moduleName}</h3>
              <ul>
                {permissions.map((permission) => (
                  <li key={permission}>{permission}</li>
                ))}
              </ul>
            </article>
          ))}
        </div>
      </div>
    </section>
  );
}
