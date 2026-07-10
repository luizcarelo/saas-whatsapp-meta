import { NavLink } from 'react-router-dom';

export function Sidebar() {
  return (
    <aside className="sidebar">
      <div className="sidebar-header">
        <img
          alt="LH Solucao Chat Bot"
          className="sidebar-brand-icon"
          src="/assets/lh_chatbot_favicon.png"
        />

        <div>
          <strong>LH Solucao</strong>
          <span>Chat Bot Meta</span>
        </div>
      </div>

      <nav className="sidebar-nav">
        <NavLink to="/app/dashboard">Dashboard</NavLink>
        <NavLink to="/app/inbox">Atendimento</NavLink>
        <NavLink to="/app/attendance-dashboard">Dashboard atendimento</NavLink>
        <NavLink to="/app/send-failures">Falhas de envio</NavLink>
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
