import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../../stores/auth.store';

export function Topbar() {
  const navigate = useNavigate();
  const user = useAuthStore((state) => state.user);
  const clearSession = useAuthStore((state) => state.clearSession);

  function handleLogout() {
    clearSession();
    navigate('/login');
  }

  return (
    <header className="topbar">
      <div>
        <span className="topbar-label">Painel</span>
        <strong>{user?.name || 'Usuario'}</strong>
      </div>

      <div className="topbar-actions">
        <span>{user?.email}</span>
        <button onClick={handleLogout} type="button">
          Sair
        </button>
      </div>
    </header>
  );
}
