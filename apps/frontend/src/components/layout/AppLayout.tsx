import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';

export function AppLayout() {
  return (
    <main className="app-layout">
      <Sidebar />

      <section className="main-panel">
        <Topbar />
        <div className="main-content">
          <Outlet />
        </div>
      </section>
    </main>
  );
}
