import { Navigate } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'

export default function ProtectedRoute({ children, roles }) {
  const { user, loading } = useAuth()

  if (loading) {
    return <div className="min-h-screen bg-surface-950 flex items-center justify-center">
      <div className="animate-spin rounded-full h-12 w-12 border-t-2 border-b-2 border-brand-500 shadow-lg glow-brand"></div>
    </div>
  }

  if (!user) {
    return <Navigate to="/login" />
  }

  if (!user.role) {
    return <Navigate to="/role-selection" />
  }

  if (roles && !roles.includes(user.role)) {
    return <Navigate to="/dashboard" />
  }

  return children
}
