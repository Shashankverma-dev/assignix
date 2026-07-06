import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { GraduationCap, ShieldCheck, ArrowRight } from 'lucide-react'
import { Ripple } from '../../components/ui/modern-animated-sign-in'

export default function RoleSelection() {
  const [role, setRole] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const { updateProfile } = useAuth()
  const navigate = useNavigate()

  const handleSubmit = async (e) => {
    e.preventDefault()
    if (!role) {
      setError('Please select a role to continue.')
      return
    }

    setError('')
    setLoading(true)
    try {
      const result = await updateProfile({ role })
      if (result.success) {
        navigate('/dashboard', { replace: true })
      } else {
        setError(result.message || 'Failed to update profile. Please try again.')
      }
    } catch (_err) {
      setError('An error occurred. Please check your connection.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <section className="flex flex-col items-center justify-center min-h-screen bg-slate-50 font-sans selection:bg-brand-600 selection:text-white overflow-hidden relative px-4">
      {/* Background Ripple & Gradients */}
      <div className="absolute inset-0 bg-blue-50/20 pointer-events-none" />
      <div className="absolute top-0 right-0 w-full h-full bg-gradient-to-br from-brand-600/5 via-transparent to-transparent pointer-events-none" />
      <div className="absolute inset-0 pointer-events-none">
        <Ripple mainCircleSize={180} />
      </div>

      {/* Role Selection Container */}
      <div className="w-full max-w-lg bg-white/80 backdrop-blur-xl border border-slate-100 p-8 md:p-10 rounded-3xl shadow-2xl shadow-slate-200/50 relative z-10 animate-entry flex flex-col items-center">
        <div className="w-12 h-12 rounded-2xl bg-brand-600 flex items-center justify-center text-white mb-6 shadow-lg shadow-brand-500/20">
          <GraduationCap size={24} strokeWidth={2} />
        </div>
        
        <h1 className="text-2xl md:text-3xl font-black text-slate-900 tracking-tight mb-2 text-center">
          Choose Your Path
        </h1>
        <p className="text-sm text-slate-500 text-center mb-8 max-w-sm">
          To finalize your registration, please tell us how you plan to use Assignix.
        </p>

        {error && (
          <div className="w-full p-4 mb-6 bg-red-50 border border-red-100 rounded-2xl text-red-600 text-xs font-semibold animate-pulse text-center">
            {error}
          </div>
        )}

        <form onSubmit={handleSubmit} className="w-full flex flex-col gap-6">
          <div className="grid grid-cols-2 gap-4">
            {/* Student Option */}
            <button
              type="button"
              onClick={() => {
                setRole('student')
                setError('')
              }}
              className={`flex flex-col items-center gap-4 p-6 rounded-2xl border-2 transition-all duration-300 cursor-pointer ${
                role === 'student'
                  ? 'border-brand-600 bg-brand-50/50 text-brand-700 shadow-xl shadow-brand-500/5'
                  : 'border-slate-150 bg-slate-50/50 text-slate-550 hover:border-slate-200 hover:bg-slate-50'
              }`}
            >
              <div
                className={`p-4 rounded-2xl transition-all duration-300 ${
                  role === 'student'
                    ? 'bg-brand-600 text-white shadow-lg shadow-brand-500/30'
                    : 'bg-white border border-slate-150 text-slate-400 shadow-sm'
                }`}
              >
                <GraduationCap size={28} strokeWidth={2.2} />
              </div>
              <div className="text-center">
                <p className="text-xs font-black uppercase tracking-widest mb-1">Student</p>
                <p className="text-[10px] text-slate-400 leading-normal max-w-[120px]">Solve tasks, earn XP, play in the arena.</p>
              </div>
            </button>

            {/* Teacher Option */}
            <button
              type="button"
              onClick={() => {
                setRole('teacher')
                setError('')
              }}
              className={`flex flex-col items-center gap-4 p-6 rounded-2xl border-2 transition-all duration-300 cursor-pointer ${
                role === 'teacher'
                  ? 'border-brand-600 bg-brand-50/50 text-brand-700 shadow-xl shadow-brand-500/5'
                  : 'border-slate-150 bg-slate-50/50 text-slate-550 hover:border-slate-200 hover:bg-slate-50'
              }`}
            >
              <div
                className={`p-4 rounded-2xl transition-all duration-300 ${
                  role === 'teacher'
                    ? 'bg-brand-600 text-white shadow-lg shadow-brand-500/30'
                    : 'bg-white border border-slate-150 text-slate-400 shadow-sm'
                }`}
              >
                <ShieldCheck size={28} strokeWidth={2.2} />
              </div>
              <div className="text-center">
                <p className="text-xs font-black uppercase tracking-widest mb-1">Teacher</p>
                <p className="text-[10px] text-slate-400 leading-normal max-w-[120px]">Create classes, assign problems, trace stats.</p>
              </div>
            </button>
          </div>

          <button
            type="submit"
            disabled={loading}
            className="w-full bg-brand-600 hover:bg-brand-500 disabled:opacity-50 text-white font-black text-xs uppercase tracking-widest py-4 px-6 rounded-2xl transition-all duration-300 shadow-xl shadow-brand-500/10 hover:shadow-brand-500/20 active:scale-[0.98] cursor-pointer flex items-center justify-center gap-2 mt-4"
          >
            {loading ? (
              <div className="w-5 h-5 border-2 border-white/20 border-t-white rounded-full animate-spin" />
            ) : (
              <>
                Complete Onboarding
                <ArrowRight size={14} strokeWidth={2.5} />
              </>
            )}
          </button>
        </form>
      </div>
    </section>
  )
}
