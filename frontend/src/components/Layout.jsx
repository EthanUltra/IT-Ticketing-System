import { NavLink, useNavigate } from 'react-router-dom';
import { useAuthStore } from '../store/authStore';
const NAV = [
  { to:'/dashboard', label:'Dashboard',  icon:'â¬¡', roles:['USER','AGENT','ADMIN'] },
  { to:'/tickets',   label:'Tickets',    icon:'âŠ¡', roles:['USER','AGENT','ADMIN'] },
  { to:'/new',       label:'New Ticket', icon:'+', roles:['USER','AGENT','ADMIN'] },
  { to:'/users',     label:'Users',      icon:'âŠ•', roles:['AGENT','ADMIN'] },
];
export default function Layout({ children }) {
  const { user, logout } = useAuthStore();
  const navigate = useNavigate();
  const handleLogout = async () => { await logout(); navigate('/login'); };
  const links = NAV.filter(n => n.roles.includes(user?.role));
  return (
    <div className="flex min-h-screen">
      <aside className="w-56 flex-shrink-0 bg-surface-900 border-r border-surface-800 flex flex-col">
        <div className="px-5 py-5 border-b border-surface-800">
          <div className="flex items-center gap-2.5">
            <div className="w-7 h-7 bg-accent rounded-lg flex items-center justify-center text-white text-sm font-bold">H</div>
            <div><p className="text-sm font-semibold text-surface-50 leading-none">HelpDesk</p><p className="text-xs text-surface-100/40 font-mono mt-0.5">IT SYSTEM</p></div>
          </div>
        </div>
        <nav className="flex-1 px-3 py-4 space-y-1">
          {links.map(({ to, label, icon }) => (
            <NavLink key={to} to={to} className={({ isActive }) => 'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm transition-colors ' + (isActive ? 'bg-accent/10 text-accent font-medium' : 'text-surface-100/60 hover:text-surface-50 hover:bg-surface-800')}>
              <span className="font-mono text-base w-5 text-center">{icon}</span>{label}
            </NavLink>
          ))}
        </nav>
        <div className="px-3 py-4 border-t border-surface-800">
          <div className="px-3 py-2.5 rounded-lg bg-surface-800/50 mb-2">
            <p className="text-xs font-medium text-surface-50 truncate">{user?.name}</p>
            <p className="text-xs text-surface-100/40 font-mono truncate">{user?.role}</p>
          </div>
          <button onClick={handleLogout} className="btn-ghost w-full text-left text-surface-100/50 hover:text-red-400 text-xs">Sign out â†’</button>
        </div>
      </aside>
      <main className="flex-1 overflow-auto">{children}</main>
    </div>
  );
}