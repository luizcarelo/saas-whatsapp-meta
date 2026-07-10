import { NavLink } from 'react-router-dom';

export function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        /assets/lh_chatbot_favicon.png
        <div>
          <strong>LH Solucao</strong>
          <span>Chat Bot Meta</span>
        </div>
      </div>

      <nav className="sidebar-nav">
        <NavLink to="/app/dashboard">Dashboard</NavLink>
        <NavLink to="/app/contacts">Contatos</NavLink>
        <NavLink to="/app/conversations">Conversas</NavLink>
        <NavLink to="/app/whatsapp-accounts">WhatsApp</NavLink>
        <NavLink to="/app/meta-settings">Meta</NavLink>
        <NavLink to="/app/audit">Auditoria</NavLink>
        <NavLink to="/app/audit-real-run">Higienizacao real</NavLink>
        <NavLink to="/app/audit-real-history">Historico higiene</NavLink>
        <NavLink to="/app/profile">Perfil</NavLink>
      </nav>
    </aside>
  );
}
