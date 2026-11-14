import { Navigate, Outlet } from 'react-router-dom'
import { useAuth } from '../context/AuthContext.jsx'
import { Loader } from './UI.jsx'
export default function ProtectedRoute() {
  const { user, loading, configured } = useAuth()
  if (!configured) return <Navigate to="/setup" replace />
  if (loading) return <Loader />
  return user ? <Outlet /> : <Navigate to="/login" replace />
}
