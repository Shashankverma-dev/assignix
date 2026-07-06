import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import {
  Ripple,
  AuthTabs,
  TechOrbitDisplay,
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

export default function Login() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { login, loginWithGoogle } = useAuth()
  const navigate = useNavigate()

  const handleSubmit = async (e) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      if (email && password) {
        const result = await login(email.trim().toLowerCase(), password)
        if (result.success) {
          const destination = result.user?.role === 'admin' ? '/admin' : '/dashboard'
          navigate(destination, { replace: true })
        } else {
          setError(result.message)
        }
      } else {
        setError('Please enter both email and password')
      }
    } catch (_err) {
      setError('Connection failed. Server might be offline.')
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
      setError('Google sign-in failed. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  const formFields = {
    header: 'Welcome back',
    subHeader: 'Sign in to your account',
    fields: [
      {
        label: 'Email',
        id: 'login-email',
        required: true,
        type: 'email',
        placeholder: 'Enter your email address',
        value: email,
        onChange: (e) => setEmail(e.target.value),
      },
      {
        label: 'Password',
        id: 'login-password',
        required: true,
        type: 'password',
        placeholder: 'Enter your password',
        value: password,
        onChange: (e) => setPassword(e.target.value),
      },
    ],
    submitButton: 'Sign in',
    textVariantButton: "Don't have an account? Sign up",
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
        <AuthTabs
          formFields={formFields}
          goTo={() => navigate('/signup', { replace: true })}
          handleSubmit={handleSubmit}
          onGoogleLogin={handleGoogleLogin}
          loading={loading}
        />
      </div>
    </section>
  )
}
