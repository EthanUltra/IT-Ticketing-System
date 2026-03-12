import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { ticketsApi } from '../api/tickets';
import { useAuthStore } from '../store/authStore';
import { StatusBadge, PriorityBadge, Spinner, EmptyState } from '../components/ui/Badge';
import { formatDistanceToNow } from 'date-fns';

export default function TicketsPage() {
  const { user } = useAuthStore();
  const [tickets, setTickets] = useState([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [filters, setFilters] = useState({ status:'', priority:'', category:'' });
  const isAgent = user?.role !== 'USER';

  useEffect(() => {
    setLoading(true);
    const params = Object.fromEntries(Object.entries(filters).filter(([,v]) => v));
    ticketsApi.list(params).then(({ data }) => { setTickets(data.data.tickets); setTotal(data.data.total); }).catch(console.error).finally(() => setLoading(false));
  }, [filters]);

  return (
    <div className="p-8 animate-fade-in">
      <div className="flex items-center justify-between mb-6">
        <div><h1 className="text-2xl font-semibold text-surface-50">Tickets</h1><p className="text-surface-100/50 text-sm mt-0.5">{loading ? 'â€”' : total + ' ticket' + (total !== 1 ? 's' : '')}</p></div>
        <Link to="/new" className="btn-primary">+ New Ticket</Link>
      </div>
      <div className="flex gap-3 mb-6 flex-wrap">
        {[['status',['OPEN','IN_PROGRESS','RESOLVED','CLOSED']],['priority',['CRITICAL','HIGH','MEDIUM','LOW']],['category',['HARDWARE','SOFTWARE','NETWORK','ACCESS','OTHER']]].map(([key,opts]) => (
          <select key={key} value={filters[key]} onChange={e => setFilters(f => ({...f,[key]:e.target.value}))} className="input !w-auto text-xs font-mono">
            <option value="">{key.charAt(0).toUpperCase()+key.slice(1)}</option>
            {opts.map(o => <option key={o} value={o}>{o.replace('_',' ')}</option>)}
          </select>
        ))}
        {Object.values(filters).some(Boolean) && <button onClick={() => setFilters({status:'',priority:'',category:''})} className="btn-ghost text-xs text-surface-100/40">Clear</button>}
      </div>
      <div className="card overflow-hidden">
        {loading ? <div className="flex justify-center py-16"><Spinner size="lg" /></div>
        : tickets.length === 0 ? <EmptyState icon="âŠ¡" title="No tickets found" description="Try adjusting your filters." action={<Link to="/new" className="btn-primary">Create a ticket</Link>} />
        : <table className="w-full text-sm">
            <thead><tr className="border-b border-surface-800 text-xs font-mono text-surface-100/40 uppercase tracking-wider">
              <th className="text-left px-6 py-3 font-medium">Ticket</th>
              <th className="text-left px-4 py-3 font-medium">Category</th>
              <th className="text-left px-4 py-3 font-medium">Priority</th>
              <th className="text-left px-4 py-3 font-medium">Status</th>
              {isAgent && <th className="text-left px-4 py-3 font-medium">Assigned</th>}
              <th className="text-left px-4 py-3 font-medium">Created</th>
            </tr></thead>
            <tbody className="divide-y divide-surface-800">
              {tickets.map(t => (
                <tr key={t.id} className="hover:bg-surface-800/30 transition-colors">
                  <td className="px-6 py-4"><Link to={'/tickets/'+t.id} className="hover:text-accent transition-colors"><p className="font-medium text-surface-50 truncate max-w-xs">{t.title}</p><p className="text-xs text-surface-100/40 font-mono mt-0.5">#{t.id.slice(0,8)}</p></Link></td>
                  <td className="px-4 py-4"><span className="text-xs font-mono text-surface-100/50">{t.category}</span></td>
                  <td className="px-4 py-4"><PriorityBadge priority={t.priority} /></td>
                  <td className="px-4 py-4"><StatusBadge status={t.status} /></td>
                  {isAgent && <td className="px-4 py-4"><span className="text-xs text-surface-100/50">{t.assignedTo?.name ?? 'â€”'}</span></td>}
                  <td className="px-4 py-4 text-xs text-surface-100/40 font-mono">{formatDistanceToNow(new Date(t.createdAt), { addSuffix:true })}</td>
                </tr>
              ))}
            </tbody>
          </table>}
      </div>
    </div>
  );
}