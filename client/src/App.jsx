import { Routes, Route, Navigate } from 'react-router-dom'
import { ToastProvider } from './context/ToastContext'
import { useAuth } from './context/AuthContext'

// Layout
import AppLayout from './components/layout/AppLayout'
import AdminLayout from './components/layout/AdminLayout'
import ProtectedRoute from './components/auth/ProtectedRoute'

// Pages
import Landing          from './pages/Landing'
import Login            from './pages/auth/Login'
import Signup           from './pages/auth/Signup'
import RoleSelection    from './pages/auth/RoleSelection'
import Dashboard        from './pages/dashboard/Dashboard'
import Classrooms       from './pages/classrooms/Classrooms'
import ClassroomDetail  from './pages/classrooms/ClassroomDetail'
import Prepare          from './pages/problems/Problems'
import PrepareDetail    from './pages/problems/ProblemDetail'
import Assignments      from './pages/assignments/Assignments'
import Practice         from './pages/practice/Practice'
import TopicDetail      from './pages/practice/TopicDetail'
import Friends          from './pages/friends/Friends'
import Challenge        from './pages/challenge/Challenge'
import Room             from './pages/challenge/Room'
import Progress         from './pages/progress/Progress'
import Settings         from './pages/settings/Settings'

// Admin Pages
import AdminDashboard   from './pages/admin/AdminDashboard'
import AdminUsers       from './pages/admin/AdminUsers'
import AdminClassrooms   from './pages/admin/AdminClassrooms'
import AdminAssignments from './pages/admin/AdminAssignments'
import AdminPrepare     from './pages/admin/AdminProblems'
import AdminChallenges  from './pages/admin/AdminChallenges'
import AdminPractice    from './pages/admin/AdminPractice'
import AdminSettings    from './pages/admin/AdminSettings'

import { Settings as SettingsIcon } from 'lucide-react'



export default function App() {
  const { user, loading } = useAuth()

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-slate-900">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 border-4 border-brand-500/20 border-t-brand-500 rounded-full animate-spin" />
          <p className="text-[10px] font-black text-brand-500 uppercase tracking-[0.3em] animate-pulse">Synchronizing Identity...</p>
        </div>
      </div>
    )
  }

  return (
    <ToastProvider>
      <Routes>
      {/* Public route — no sidebar/navbar */}
      <Route
        path="/"
        element={<Landing />}
      />

      <Route
        path="/login"
        element={
          user ? (
            !user.role ? <Navigate to="/role-selection" replace /> :
            user.role === 'admin' ? <Navigate to="/admin" replace /> : <Navigate to="/dashboard" replace />
          ) : (
            <Login />
          )
        }
      />
      <Route
        path="/signup"
        element={
          user ? (
            !user.role ? <Navigate to="/role-selection" replace /> : <Navigate to="/dashboard" replace />
          ) : (
            <Signup />
          )
        }
      />
      <Route
        path="/role-selection"
        element={
          user ? (
            user.role ? <Navigate to="/dashboard" replace /> : <RoleSelection />
          ) : (
            <Navigate to="/login" replace />
          )
        }
      />

      {/* Authenticated shell */}
      <Route
        element={
          <ProtectedRoute>
            <AppLayout />
          </ProtectedRoute>
        }
      >
        <Route path="/dashboard"      element={<Dashboard />} />
        <Route path="/classrooms"     element={<Classrooms />} />
        <Route path="/classroom/:id"  element={<ClassroomDetail />} />
        <Route path="/prepare"       element={<Prepare />} />
        <Route path="/prepare/:id"    element={<PrepareDetail />} />
        <Route path="/assignments"    element={<Assignments />} />
        <Route path="/practice"       element={<Practice />} />
        <Route path="/practice/topic/:topic" element={<TopicDetail />} />
        <Route path="/friends"        element={<Friends />} />
        <Route path="/challenge"      element={<Challenge />} />
        <Route path="/room/:id"       element={<Room />} />
        <Route path="/progress"       element={<Progress />} />
        <Route path="/settings"       element={<Settings />} />
      </Route>

      {/* Admin Panel (White Theme) */}
      <Route
        path="/admin"
        element={
          <ProtectedRoute roles={['admin']}>
            <AdminLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<AdminDashboard />} />
        <Route path="users" element={<AdminUsers />} />
        <Route path="classrooms" element={<AdminClassrooms />} />
        <Route path="assignments" element={<AdminAssignments />} />
        <Route path="prepare" element={<AdminPrepare />} />
        <Route path="challenges" element={<AdminChallenges />} />
        <Route path="practice" element={<AdminPractice />} />
        <Route path="settings" element={<AdminSettings />} />
      </Route>

      {/* Catch-all */}
      <Route
        path="*"
        element={<Navigate to={user ? "/dashboard" : "/login"} replace />}
      />
      </Routes>
    </ToastProvider>
  )
}

