import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import { GraduationCap, ShieldCheck } from 'lucide-react'
import {
  Ripple,
  TechOrbitDisplay,
  AnimatedForm,
  BoxReveal,
} from '../../components/ui/modern-animated-sign-in'

const iconsArray = [
  {
    component: () => (
      <img width={100} height={100} src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/python/python-original.svg" alt="Python" />
    ),
    className: 'size-[50px] border-none bg-transparent',
    duration: 25, delay: 0, radius: 100, path: true, reverse: false,
  },
  {
    component: () => (
      <img width={100} height={100} src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/javascript/javascript-original.svg" alt="JavaScript" />
    ),
    className: 'size-[50px] border-none bg-transparent',
    duration: 25, delay: 10, radius: 210, path: true, reverse: true,
  },
  {
    component: () => (
      <img width={100} height={100} src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/c/c-original.svg" alt="C" />
    ),
    className: 'size-[50px] border-none bg-transparent',
    duration: 30, delay: 5, radius: 300, path: true, reverse: false,
  },
  {
    component: () => (
      <img width={100} height={100} src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/html5/html5-original.svg" alt="HTML5" />
    ),
    className: 'size-[50px] border-none bg-transparent',
    duration: 30, delay: 15, radius: 380, path: true, reverse: true,
  },
  {
    component: () => (
      <img width={100} height={100} src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/figma/figma-original.svg" alt="Figma" />
    ),
    className: 'size-[40px] border-none bg-transparent',
    duration: 35, delay: 20, radius: 450, path: true, reverse: false,
  },
  {
    component: () => (
      <img width={100} height={100} src="https://cdn.jsdelivr.net/gh/devicons/devicon@latest/icons/css3/css3-original.svg" alt="CSS3" />
    ),
    className: 'size-[40px] border-none bg-transparent',
    duration: 35, delay: 10, radius: 520, path: true, reverse: true,
  },
]

export default function Signup() {
  const [formData, setFormData] = useState({
    name: '',
    username: '',
    email: '',
    password: '',
    role: 'student'
  })
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { register, loginWithGoogle } = useAuth()
  const navigate = useNavigate()

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')

    if (formData.username.length < 3) {
      return setError('Username must be at least 3 characters')
    }
    if (formData.password.length < 6) {
      return setError('Password must be at least 6 characters')
    }

    setLoading(true)
    try {
      const result = await register(
        formData.name,
        formData.username,
        formData.email.trim().toLowerCase(),
        formData.password,
        formData.role
      )
      if (result.success) {
        navigate('/dashboard', { replace: true })
      } else {
        setError(result.message)
      }
    } catch (_err) {
      setError('Connection refused. Is the network operational?')
    } finally {
      setLoading(false)
    }
  }

  const handleGoogleLogin = async () => {
    setError('')
    setLoading(true)
    try {
      const result = await loginWithGoogle()
      if (!result.success) {
        setError(result.message)
      }
    } catch (_err) {
      setError('Google sign-up failed. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  const roleSelector = (
    <div className="grid grid-cols-2 gap-4 mb-4">
      <button
        type="button"
        onClick={() => setFormData({ ...formData, role: 'student' })}
        className={`flex flex-col items-center gap-3 p-4 rounded-2xl border transition-all duration-300 cursor-pointer ${
          formData.role === 'student'
            ? 'border-brand-600 bg-brand-50 text-brand-700 shadow-lg shadow-brand-500/10'
            : 'border-slate-200 bg-white text-slate-400 hover:border-slate-300'
        }`}
      >
        <div className={`p-3 rounded-xl ${formData.role === 'student' ? 'bg-brand-600 text-white shadow-brand-500/20' : 'bg-slate-100'}`}>
           <GraduationCap size={20} strokeWidth={2.5} />
        </div>
        <span className="text-[10px] font-black uppercase tracking-widest">Student</span>
      </button>
      <button
        type="button"
        onClick={() => setFormData({ ...formData, role: 'teacher' })}
        className={`flex flex-col items-center gap-3 p-4 rounded-2xl border transition-all duration-300 cursor-pointer ${
          formData.role === 'teacher'
            ? 'border-brand-600 bg-brand-50 text-brand-700 shadow-lg shadow-brand-500/10'
            : 'border-slate-200 bg-white text-slate-400 hover:border-slate-300'
        }`}
      >
        <div className={`p-3 rounded-xl ${formData.role === 'teacher' ? 'bg-brand-600 text-white shadow-brand-500/20' : 'bg-slate-100'}`}>
           <ShieldCheck size={20} strokeWidth={2.5} />
        </div>
        <span className="text-[10px] font-black uppercase tracking-widest">Teacher</span>
      </button>
    </div>
  )

  const formFields = {
    header: 'Create Account',
    subHeader: 'Join Assignix and start your coding journey',
    fields: [
      {
        label: 'Full Name',
        id: 'signup-name',
        required: true,
        type: 'text',
        placeholder: 'Enter your full name',
        value: formData.name,
        onChange: (e) => setFormData({ ...formData, name: e.target.value }),
      },
      {
        label: 'Username',
        id: 'signup-username',
        required: true,
        type: 'text',
        placeholder: 'Choose a username',
        value: formData.username,
        onChange: (e) => setFormData({ ...formData, username: e.target.value }),
      },
      {
        label: 'Email',
        id: 'signup-email',
        required: true,
        type: 'email',
        placeholder: 'Enter your email address',
        value: formData.email,
        onChange: (e) => setFormData({ ...formData, email: e.target.value }),
      },
      {
        label: 'Password',
        id: 'signup-password',
        required: true,
        type: 'password',
        placeholder: 'Create a password',
        value: formData.password,
        onChange: (e) => setFormData({ ...formData, password: e.target.value }),
      },
    ],
    submitButton: 'Create account',
    textVariantButton: 'Already have an account? Sign in',
    errorField: error,
  }

  return (
    <section className="flex max-lg:justify-center bg-white min-h-screen font-sans selection:bg-brand-600 selection:text-white overflow-hidden">
      {/* Left Side: Tech Showcase */}
      <div className="flex flex-col justify-center w-1/2 max-lg:hidden relative overflow-hidden bg-white">
        <div className="absolute inset-0 bg-blue-50/50" />
        <div className="absolute top-0 right-0 w-full h-full bg-gradient-to-br from-brand-600/10 via-transparent to-transparent pointer-events-none" />
        <Ripple mainCircleSize={120} />
        <TechOrbitDisplay iconsArray={iconsArray} text="Assignix" className="relative z-10" />
        <div className="absolute bottom-12 left-1/2 -translate-x-1/2 text-center space-y-2 opacity-30">
          <p className="text-[10px] font-black text-slate-900 uppercase tracking-[0.4em]">Engineered Excellence</p>
          <div className="h-0.5 w-12 bg-brand-600 mx-auto rounded-full" />
        </div>
      </div>

      {/* Right Side: Form */}
      <div className="w-1/2 h-[100dvh] flex flex-col justify-center items-center max-lg:w-full max-lg:px-[10%] p-8 overflow-y-auto animate-entry bg-white relative">
        <div className="absolute inset-y-0 left-0 w-px bg-slate-100 max-lg:hidden" />
        <AnimatedForm
          {...formFields}
          fieldPerRow={1}
          onSubmit={handleSubmit}
          goTo={() => navigate('/login', { replace: true })}
          googleLogin="Sign up with Google"
          onGoogleLogin={handleGoogleLogin}
          extraContent={roleSelector}
          loading={loading}
        />
      </div>
    </section>
  )
}
