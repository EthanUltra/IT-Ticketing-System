import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ticketsApi } from '../api/tickets';
import { useAuthStore } from '../store/authStore';
import { StatusBadge, PriorityBadge, Spinner } from '../components/ui/Badge';
import { formatDistanceToNow } from 'date-fns';

export default function DashboardPage() {
  const { user } = useAuthStore();
  const [stats, setStats] = useState(null);
  const [recent, setRecent] = useState([]);
  const [loading, setLoading] = useState(true);
  const isAgent = user?.role !== 'USER';

  useEffect(() => {
    (async () => {
      try {
        if (isAgent) { const { data } = await ticketsApi.stats(); setStats(data.data.byStatus); setRecent(data.data.recentTickets); }
        else { const { data } = await ticketsApi.list({ limit: 5 }); setRecent(data.data.tickets); }
      } catch(e) { console.error(e); } finally { setLoading(false); }
    })();
  }, []);

  if (loading) return <div className="flex items-center justify-center h-64"><Spinner size="lg" /></div>;

  const statMap = {};
  if (stats) stats.forEach(s => { statMap[s.status] = s._count; });
  const h = new Date().getHours();
  const greet = h < 12 ? 'morning' : h < 17 ? 'afternoon' : 'evening';

  return (
    <div className="p-8 animate-fade-in">
      <div className="mb-8">
        <h1 className="text-2xl font-semibold text-surface-50">Good {greet}, {user?.name?.split(' ')[0]}</h1>
        <p className="text-surface-100/50 text-sm mt-1">{new Date().toLocaleDateString('en-GB', { weekday:'long', day:'numeric', month:'long' })}</p>
      </div>
      {isAgent && (
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
          {['OPEN','IN_PROGRESS','RESOLVED','CLOSED'].map(s => (
            <div key={s} className="card p-5">
              <p className="text-xs font-mono text-surface-100/40 uppercase tracking-wider mb-2">{s.replace('_',' ')}</p>
              <p className={'text-3xl font-semibold ' + {OPEN:'text-blue-400',IN_PROGRESS:'text-amber-400',RESOLVED:'text-emerald-400',CLOSED:'text-zinc-400'}[s]}>{statMap[s] ?? 0}</p>
            </div>
          ))}
        </div>
      )}
      <div className="card">
        <div className="flex items-center justify-between px-6 py-4 border-b border-surface-800">
          <h2 className="text-sm font-medium text-surface-50">{isAgent ? 'Recent Tickets' : 'Your Tickets'}</h2>
          <Link to="/tickets" className="text-xs text-accent hover:underline">View all â†’</Link>
        </div>
        {recent.length === 0 ? <div className="px-6 py-10 text-center text-surface-100/40 text-sm">No tickets yet.</div> : (
          <div className="divide-y divide-surface-800">
            {recent.map(t => (
              <Link key={t.id} to={'/tickets/' + t.id} className="flex items-center gap-4 px-6 py-4 hover:bg-surface-800/40 transition-colors">
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-surface-50 truncate">{t.title}</p>
                  <p className="text-xs text-surface-100/40 mt-0.5 font-mono">#{t.id.slice(0,8)} Â· {formatDistanceToNow(new Date(t.createdAt), { addSuffix:true })}</p>
                </div>
                <div className="flex items-center gap-2 flex-shrink-0"><PriorityBadge priority={t.priority} /><StatusBadge status={t.status} /></div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}