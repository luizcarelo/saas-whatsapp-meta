import {
  BrowserRouter,
  Link,
  Navigate,
  Route,
  Routes
} from 'react-router-dom';

function LoginPage() {
  return (
    <main className="page">
      <section className="card">
        <h1>SaaS WhatsApp Meta</h1>
        <p>Login do sistema sera implementado em etapa futura.</p>
        <Link to="/app/dashboard">Entrar no painel demonstrativo</Link>
      </section>
    </main>
  );
}

function DashboardPage() {
  return (
    <main className="page">
      <section className="card">
        <h1>Dashboard</h1>
        <p>Frontend base criado com React, TypeScript e Vite.</p>
        <nav className="nav">
          <Link to="/app/conversations">Conversas</Link>
          <Link to="/login">Sair</Link>
        </nav>
      </section>
    </main>
  );
}

function ConversationsPage() {
  return (
    <main className="page">
      <section className="card">
        <h1>Conversas</h1>
        <p>Tela de conversas sera implementada em etapa futura.</p>
        <Link to="/app/dashboard">Voltar ao dashboard</Link>
      </section>
    </main>
  );
}

export function AppRoutes() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/login" replace />} />
        <Route path="/login" element={<LoginPage />} />
        <Route path="/app/dashboard" element={<DashboardPage />} />
        <Route path="/app/conversations" element={<ConversationsPage />} />
      </Routes>
    </BrowserRouter>
  );
}
