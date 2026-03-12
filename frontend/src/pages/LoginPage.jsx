import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../api/client';
import { useAuthStore } from '../store/authStore';
import { Spinner } from '../components/ui/Badge';

export default function LoginPage() {
  const [form, setForm] = useState({ email: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const { setAuth } = useAuthStore();
  const navigate = useNavigate();

  const handle = async (e) => {
    e.preventDefault(); setLoading(true); setError('');
    try { const { data } = await api.post('/auth/login', form); setAuth(data.data.user, data.data.accessToken); navigate('/dashboard'); }
    catch (err) { setError(err.response?.data?.message || 'Login failed'); }
    finally { setLoading(false); }
  };

  return (
    <div className="min-h-screen bg-surface-950 flex items-center justify-center px-4">
      <div className="absolute inset-0 bg-[linear-gradient(rgba(249,115,22,0.03)_1px,transparent_1px),linear-gradient(90deg,rgba(249,115,22,0.03)_1px,transparent_1px)] bg-[size:60px_60px]" />
      <div className="relative w-full max-w-sm animate-fade-in">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-12 h-12 bg-accent rounded-xl mb-4"><span className="text-white text-xl font-bold">H</span></div>
          <h1 className="text-2xl font-semibold text-surface-50">IT Help Desk</h1>
          <p className="text-surface-100/50 text-sm mt-1">Sign in to your account</p>
        </div>
        <div className="card p-3 mb-4 text-xs font-mono text-surface-100/40 space-y-1">
          <p className="text-surface-100/60 font-sans font-medium text-xs mb-2">Demo accounts</p>
          <p>admin@company.com / Admin1234!</p>
          <p>agent@company.com / Agent1234!</p>
          <p>user@company.com  / User1234!</p>
        </div>
        <div className="card p-6">
          <form onSubmit={handle} className="space-y-4">
            <div><label className="label">Email</label><input className="input" type="email" placeholder="you@company.com" required value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} /></div>
            <div><label className="label">Password</label><input className="input" type="password" placeholder="â€¢â€¢â€¢â€¢â€¢â€¢â€¢â€¢" required value={form.password} onChange={e => setForm(f => ({ ...f, password: e.target.value }))} /></div>
            {error && <div className="bg-red-500/10 border border-red-500/20 text-red-400 text-sm px-3 py-2 rounded-lg">{error}</div>}
            <button type="submit" className="btn-primary w-full flex items-center justify-center gap-2" disabled={loading}>{loading && <Spinner size="sm" />}{loading ? 'Signing in...' : 'Sign in'}</button>
          </form>
        </div>
      </div>
    </div>
  );
}