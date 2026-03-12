import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ticketsApi } from '../api/tickets';
import { Spinner } from '../components/ui/Badge';

export default function CreateTicketPage() {
  const navigate = useNavigate();
  const [form, setForm] = useState({ title:'', description:'', priority:'MEDIUM', category:'OTHER' });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const set = (k,v) => setForm(f => ({...f,[k]:v}));
  const submit = async (e) => {
    e.preventDefault(); setLoading(true); setError('');
    try { const { data } = await ticketsApi.create(form); navigate('/tickets/' + data.data.ticket.id); }
    catch (err) { setError(err.response?.data?.message || 'Failed to create ticket'); }
    finally { setLoading(false); }
  };
  return (
    <div className="p-8 max-w-2xl animate-fade-in">
      <button onClick={() => navigate('/tickets')} className="text-sm text-surface-100/40 hover:text-surface-50 mb-6 flex items-center gap-1 transition-colors">â† Back</button>
      <h1 className="text-2xl font-semibold text-surface-50 mb-1">New Ticket</h1>
      <p className="text-sm text-surface-100/50 mb-8">Describe your issue and we'll assign someone to help.</p>
      <div className="card p-6">
        <form onSubmit={submit} className="space-y-5">
          <div><label className="label">Title *</label><input className="input" placeholder="Brief summary of the issue" required value={form.title} onChange={e => set('title', e.target.value)} /></div>
          <div><label className="label">Description *</label><textarea className="input resize-none" rows={5} required placeholder="Describe the issue in detail..." value={form.description} onChange={e => set('description', e.target.value)} /></div>
          <div className="grid grid-cols-2 gap-4">
            <div><label className="label">Category</label><select className="input font-mono text-xs" value={form.category} onChange={e => set('category',e.target.value)}>{['HARDWARE','SOFTWARE','NETWORK','ACCESS','OTHER'].map(c => <option key={c}>{c}</option>)}</select></div>
            <div><label className="label">Priority</label><select className="input font-mono text-xs" value={form.priority} onChange={e => set('priority',e.target.value)}>{['LOW','MEDIUM','HIGH','CRITICAL'].map(p => <option key={p}>{p}</option>)}</select></div>
          </div>
          {error && <div className="bg-red-500/10 border border-red-500/20 text-red-400 text-sm px-3 py-2 rounded-lg">{error}</div>}
          <div className="flex justify-end gap-3 pt-2">
            <button type="button" onClick={() => navigate(-1)} className="btn-ghost">Cancel</button>
            <button type="submit" disabled={loading} className="btn-primary flex items-center gap-2">{loading && <Spinner size="sm" />}{loading ? 'Submitting...' : 'Submit Ticket'}</button>
          </div>
        </form>
      </div>
    </div>
  );
}