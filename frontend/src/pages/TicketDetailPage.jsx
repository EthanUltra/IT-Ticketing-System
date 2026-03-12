import { useEffect, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ticketsApi, usersApi } from '../api/tickets';
import { useAuthStore } from '../store/authStore';
import { StatusBadge, PriorityBadge, RoleBadge, Spinner } from '../components/ui/Badge';
import { formatDistanceToNow, format } from 'date-fns';

export default function TicketDetailPage() {
  const { id } = useParams(); const { user } = useAuthStore(); const navigate = useNavigate();
  const [ticket, setTicket] = useState(null); const [agents, setAgents] = useState([]); const [loading, setLoading] = useState(true);
  const [comment, setComment] = useState(''); const [isInternal, setIsInternal] = useState(false);
  const [submitting, setSubmitting] = useState(false); const [updating, setUpdating] = useState(false);
  const isAgent = user?.role !== 'USER';

  useEffect(() => {
    (async () => {
      try {
        const [tRes, uRes] = await Promise.all([ticketsApi.get(id), isAgent ? usersApi.list() : null]);
        setTicket(tRes.data.data.ticket);
        if (uRes) setAgents(uRes.data.data.users.filter(u => u.role !== 'USER'));
      } catch(e) { if (e.response?.status === 404) navigate('/tickets'); }
      finally { setLoading(false); }
    })();
  }, [id]);

  const updateField = async (field, value) => { setUpdating(true); try { const { data } = await ticketsApi.update(id, { [field]:value }); setTicket(data.data.ticket); } catch(e){console.error(e);} finally{setUpdating(false);} };

  const submitComment = async (e) => {
    e.preventDefault(); if (!comment.trim()) return; setSubmitting(true);
    try { const { data } = await ticketsApi.addComment(id, { content:comment, isInternal }); setTicket(t => ({...t, comments:[...t.comments, data.data.comment]})); setComment(''); }
    catch(e){console.error(e);} finally{setSubmitting(false);}
  };

  if (loading) return <div className="flex justify-center py-32"><Spinner size="lg" /></div>;
  if (!ticket) return null;

  return (
    <div className="p-8 max-w-5xl animate-fade-in">
      <button onClick={() => navigate('/tickets')} className="text-sm text-surface-100/40 hover:text-surface-50 mb-6 flex items-center gap-1 transition-colors">â† Back to tickets</button>
      <div className="flex gap-6">
        <div className="flex-1 min-w-0">
          <div className="card p-6 mb-4">
            <div className="flex items-start justify-between gap-4 mb-4">
              <div className="flex-1"><p className="text-xs font-mono text-surface-100/40 mb-1">#{ticket.id.slice(0,8)}</p><h1 className="text-xl font-semibold text-surface-50">{ticket.title}</h1></div>
              <div className="flex items-center gap-2 flex-shrink-0"><PriorityBadge priority={ticket.priority} /><StatusBadge status={ticket.status} /></div>
            </div>
            <p className="text-surface-100/70 text-sm leading-relaxed whitespace-pre-wrap">{ticket.description}</p>
            <div className="flex items-center gap-4 mt-4 pt-4 border-t border-surface-800 text-xs text-surface-100/40 font-mono">
              <span>By {ticket.createdBy?.name}</span><span>Â·</span><span>{format(new Date(ticket.createdAt),'dd MMM yyyy HH:mm')}</span><span>Â·</span><span>{ticket.category}</span>
            </div>
          </div>
          <div className="card overflow-hidden mb-4">
            <div className="px-6 py-4 border-b border-surface-800 flex items-center justify-between"><h2 className="text-sm font-medium">Activity</h2><span className="text-xs font-mono text-surface-100/40">{ticket.comments.length} comments</span></div>
            {ticket.comments.length === 0 ? <p className="px-6 py-8 text-center text-sm text-surface-100/30">No comments yet.</p> : (
              <div className="divide-y divide-surface-800">
                {ticket.comments.map(c => (
                  <div key={c.id} className={'px-6 py-4 ' + (c.isInternal ? 'bg-amber-500/5 border-l-2 border-amber-500/30' : '')}>
                    <div className="flex items-center gap-2 mb-2">
                      <div className="w-7 h-7 rounded-full bg-surface-800 flex items-center justify-center text-xs font-medium">{c.author.name[0]}</div>
                      <span className="text-sm font-medium text-surface-50">{c.author.name}</span>
                      <RoleBadge role={c.author.role} />
                      {c.isInternal && <span className="text-xs font-mono text-amber-500/60 bg-amber-500/10 px-1.5 py-0.5 rounded">internal</span>}
                      <span className="text-xs text-surface-100/30 font-mono ml-auto">{formatDistanceToNow(new Date(c.createdAt),{addSuffix:true})}</span>
                    </div>
                    <p className="text-sm text-surface-100/80 leading-relaxed pl-9">{c.content}</p>
                  </div>
                ))}
              </div>
            )}
            <form onSubmit={submitComment} className="px-6 py-4 border-t border-surface-800 space-y-3">
              <textarea className="input resize-none" rows={3} placeholder="Add a comment..." value={comment} onChange={e => setComment(e.target.value)} />
              <div className="flex items-center justify-between">
                {isAgent && <label className="flex items-center gap-2 text-xs text-surface-100/50 cursor-pointer"><input type="checkbox" checked={isInternal} onChange={e => setIsInternal(e.target.checked)} className="rounded border-surface-700 bg-surface-800" /> Internal note</label>}
                <div className="ml-auto"><button type="submit" className="btn-primary" disabled={submitting || !comment.trim()}>{submitting ? 'Posting...' : 'Post comment'}</button></div>
              </div>
            </form>
          </div>
        </div>
        <div className="w-64 flex-shrink-0 space-y-4">
          {isAgent && (
            <div className="card p-4 space-y-4">
              <p className="text-xs font-mono text-surface-100/40 uppercase tracking-wider">Manage</p>
              <div><label className="label">Status</label><select className="input text-xs font-mono" value={ticket.status} onChange={e => updateField('status',e.target.value)} disabled={updating}>{['OPEN','IN_PROGRESS','RESOLVED','CLOSED'].map(s => <option key={s} value={s}>{s.replace('_',' ')}</option>)}</select></div>
              <div><label className="label">Priority</label><select className="input text-xs font-mono" value={ticket.priority} onChange={e => updateField('priority',e.target.value)} disabled={updating}>{['LOW','MEDIUM','HIGH','CRITICAL'].map(p => <option key={p}>{p}</option>)}</select></div>
              <div><label className="label">Assigned to</label><select className="input text-xs font-mono" value={ticket.assignedToId ?? ''} onChange={e => updateField('assignedToId',e.target.value||null)} disabled={updating}><option value="">Unassigned</option>{agents.map(a => <option key={a.id} value={a.id}>{a.name}</option>)}</select></div>
              {updating && <div className="flex items-center gap-2 text-xs text-surface-100/40"><Spinner size="sm" /> Saving...</div>}
            </div>
          )}
          <div className="card p-4 space-y-3">
            <p className="text-xs font-mono text-surface-100/40 uppercase tracking-wider">Details</p>
            {[['Category',ticket.category],['Reporter',ticket.createdBy?.name],['Created',format(new Date(ticket.createdAt),'dd MMM yyyy')],['Updated',formatDistanceToNow(new Date(ticket.updatedAt),{addSuffix:true})]].map(([l,v]) => <div key={l}><p className="text-xs text-surface-100/30 font-mono">{l}</p><p className="text-sm text-surface-100/70 mt-0.5">{v}</p></div>)}
          </div>
          {user?.role === 'ADMIN' && (
            <div className="card p-4 border-red-500/10">
              <p className="text-xs font-mono text-red-400/60 uppercase tracking-wider mb-3">Danger</p>
              <button onClick={async () => { if (confirm('Delete this ticket?')) { await ticketsApi.delete(id); navigate('/tickets'); } }} className="text-xs text-red-400 hover:text-red-300 transition-colors">Delete ticket</button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}