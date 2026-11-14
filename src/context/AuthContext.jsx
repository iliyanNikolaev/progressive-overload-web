import { createContext, useContext, useEffect, useState } from 'react'
import { isSupabaseConfigured, supabase } from '../lib/supabase'

const AuthContext = createContext(null)
export function AuthProvider({ children }) {
  const [session, setSession] = useState(null)
  const [loading, setLoading] = useState(isSupabaseConfigured)
  useEffect(() => {
    if (!supabase) return
    supabase.auth.getSession().then(({ data }) => { setSession(data.session); setLoading(false) })
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, next) => { setSession(next); setLoading(false) })
    return () => subscription.unsubscribe()
  }, [])
  return <AuthContext.Provider value={{ session, user: session?.user ?? null, loading, configured: isSupabaseConfigured }}>{children}</AuthContext.Provider>
}
export const useAuth = () => useContext(AuthContext)
