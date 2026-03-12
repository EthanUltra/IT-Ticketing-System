import { useEffect, useState } from 'react';
import { usersApi } from '../api/tickets';
import { RoleBadge, Spinner } from '../components/ui/Badge';
import { formatDistanceToNow } from 'date-fns';
import { useAuthStore } from '../store/authStore';

export default function UsersPage() {
  const { user: me } = useAuthStore();
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => { usersApi.list().then(({ data }) => setUsers(data.data.users)).catch(console.error).finally(() => setLoading(false)); }, []);

  const updateRole = (id, role) => usersApi.updateRole(id, role).then(() => setUsers(us => us.map(u => u.id===id ? {...u,role} : u))).catch(console.error);
  const unlock = (id) => usersApi.unlock(id).then(() => setUsers(us => us.map(u => u.id===id ? {...u,isLocked:false} : u))).catch(console.error);

  if (loading) return <div className="flex justify-center py-32"><Spinner size="lg" /></div>;

  return (
    <div className="p-8 animate-fade-in">
      <div className="mb-6"><h1 className="text-2xl font-semibold text-surface-50">Users</h1><p className="text-surface-100/50 text-sm mt-0.5">{users.length} accounts</p></div>
      <div className="card overflow-hidden">
        <table className="w-full text-sm">
          <thead><tr className="border-b border-surface-800 text-xs font-mono text-surface-100/40 uppercase tracking-wider">
            <th className="text-left px-6 py-3">User</th><th className="text-left px-4 py-3">Role</th><th className="text-left px-4 py-3">Status</th><th className="text-left px-4 py-3">Joined</th>
            {me?.role==='ADMIN' && <th className="text-left px-4 py-3">Actions</th>}
          </tr></thead>
          <tbody className="divide-y divide-surface-800">
            {users.map(u => (
              <tr key={u.id} className="hover:bg-surface-800/30 transition-colors">
                <td className="px-6 py-4"><div className="flex items-center gap-3"><div className="w-8 h-8 rounded-full bg-surface-800 flex items-center justify-center text-xs font-medium">{u.name[0]}</div><div><p className="font-medium text-surface-50">{u.name}</p><p className="text-xs text-surface-100/40 font-mono">{u.email}</p></div></div></td>
                <td className="px-4 py-4"><RoleBadge role={u.role} /></td>
                <td className="px-4 py-4">{u.isLocked ? <span className="text-xs font-mono text-red-400 bg-red-500/10 border border-red-500/20 px-2 py-0.5 rounded-md">LOCKED</span> : <span className="text-xs font-mono text-emerald-400">Active</span>}</td>
                <td className="px-4 py-4 text-xs text-surface-100/40 font-mono">{formatDistanceToNow(new Date(u.createdAt),{addSuffix:true})}</td>
                {me?.role==='ADMIN' && <td className="px-4 py-4"><div className="flex items-center gap-2">{u.id!==me?.id && <select value={u.role} onChange={e => updateRole(u.id,e.target.value)} className="input !w-auto text-xs font-mono py-1">{['USER','AGENT','ADMIN'].map(r=><option key={r}>{r}</option>)}</select>}{u.isLocked && <button onClick={() => unlock(u.id)} className="text-xs text-emerald-400 hover:underline">Unlock</button>}</div></td>}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}