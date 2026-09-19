import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '../services/supabase'
import type { Profile } from '../types/database'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<{ id: string; email?: string } | null>(null)
  const profile = ref<Profile | null>(null)
  const loading = ref(false)
  const initialized = ref(false)
  const isAuthenticated = computed(() => Boolean(user.value))
  const isAdmin = computed(() => profile.value?.role === 'admin')
  const isInstructor = computed(() => Boolean(profile.value?.is_instructor || profile.value?.role === 'instructor' || profile.value?.role === 'admin'))

  async function load() {
    if (!supabase) {
      initialized.value = true
      return
    }
    const { data: { user: currentUser } } = await supabase.auth.getUser()
    user.value = currentUser ? { id: currentUser.id, email: currentUser.email } : null
    if (currentUser) await loadProfile(currentUser.id)
    supabase.auth.onAuthStateChange((_event, session) => {
      user.value = session?.user ? { id: session.user.id, email: session.user.email } : null
      if (session?.user) void loadProfile(session.user.id)
      else profile.value = null
    })
    initialized.value = true
  }

  async function loadProfile(id: string) {
    if (!supabase) return
    const { data, error } = await supabase.from('profiles').select('*').eq('id', id).single()
    if (!error && data) profile.value = data
  }

  async function signIn(email: string, password: string) {
    if (!supabase) return { error: new Error('目前為展示模式，請先設定 Supabase。') }
    loading.value = true
    const result = await supabase.auth.signInWithPassword({ email, password })
    loading.value = false
    if (!result.error && result.data.user) {
      user.value = { id: result.data.user.id, email: result.data.user.email }
      await loadProfile(result.data.user.id)
    }
    return result
  }

  async function signUp(payload: { email: string; password: string; fullName: string; birthDate: string; phone: string; lineUserId: string }) {
    if (!supabase) return { error: new Error('目前為展示模式，請先設定 Supabase。') }
    loading.value = true
    const result = await supabase.auth.signUp({
      email: payload.email,
      password: payload.password,
      options: { data: { full_name: payload.fullName, birth_date: payload.birthDate, phone: payload.phone, line_user_id: payload.lineUserId } },
    })
    loading.value = false
    if (!result.error && result.data.user && result.data.session) {
      user.value = { id: result.data.user.id, email: result.data.user.email }
      await loadProfile(result.data.user.id)
    }
    return result
  }

  async function signInWithGoogle() {
    if (!supabase) return { error: new Error('目前為展示模式，請先設定 Supabase。') }
    return supabase.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: window.location.origin } })
  }

  async function signOut() {
    if (supabase) await supabase.auth.signOut()
    user.value = null
    profile.value = null
  }

  return { user, profile, loading, initialized, isAuthenticated, isAdmin, isInstructor, load, loadProfile, signIn, signUp, signInWithGoogle, signOut }
})
