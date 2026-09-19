import { createRouter, createWebHistory } from 'vue-router'
import ScheduleView from '../views/ScheduleView.vue'
import MyPassesView from '../views/MyPassesView.vue'
import CheckInView from '../views/CheckInView.vue'
import AdminView from '../views/AdminView.vue'
import StoreView from '../views/StoreView.vue'
import AdminOrdersView from '../views/AdminOrdersView.vue'
import MyBookingsView from '../views/MyBookingsView.vue'
import QrCodeDisplayView from '../views/admin/QrCodeDisplayView.vue'
import AdminMembersView from '../views/admin/AdminMembersView.vue'
import AuthView from '../views/AuthView.vue'
import { useAuthStore } from '../stores/authStore'
import { isSupabaseConfigured, supabase } from '../services/supabase'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', component: AuthView, meta: { title: '會員登入' } },
    { path: '/register', component: AuthView, meta: { title: '會員註冊' } },
    { path: '/', component: ScheduleView, meta: { title: '預約課表' } },
    { path: '/my-passes', component: MyPassesView, meta: { title: '我的旅程' } },
    { path: '/my-bookings', component: MyBookingsView, meta: { title: '我的預約' } },
    { path: '/store', component: StoreView, meta: { title: '購課商城' } },
    { path: '/check-in', component: CheckInView, meta: { title: '今日簽到' } },
    { path: '/admin', component: AdminView, meta: { title: '教室管理' } },
    { path: '/admin/orders', component: AdminOrdersView, meta: { title: '購課核帳' } },
    { path: '/admin/check-in-qr', component: QrCodeDisplayView, meta: { title: '教室簽到 QR Code', staff: true } },
    { path: '/admin/members', component: AdminMembersView, meta: { title: '會員與角色管理' } },
  ],
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  if (!auth.initialized) await auth.load()
  if (to.path === '/login' || to.path === '/register') return auth.isAuthenticated ? '/' : true
  const memberRoute = to.path === '/check-in' || to.path === '/my-bookings'
  if (memberRoute && isSupabaseConfigured && supabase) {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return '/'
    return true
  }
  if (isSupabaseConfigured && supabase && ['/store', '/my-passes'].includes(to.path)) {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return `/login?redirect=${encodeURIComponent(to.fullPath)}`
  }
  if (!to.path.startsWith('/admin')) return true
  // The local demo intentionally previews the staff screen. In production the
  // role is read from the RLS-protected profile row, never trusted from UI state.
  if (!isSupabaseConfigured) {
    const role = import.meta.env.VITE_DEMO_ROLE ?? 'admin'
    return to.meta.staff ? (role === 'admin' || role === 'instructor' ? true : '/') : role === 'admin' ? true : '/'
  }
  if (!supabase) return '/'
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return '/'
  const { data } = await supabase.from('profiles').select('role, is_instructor, is_active').eq('id', user.id).single()
  const profile = data as unknown as { role?: string; is_instructor?: boolean; is_active?: boolean } | null
  if (!profile?.is_active) return '/'
  if (to.meta.staff ? !(profile.role === 'admin' || profile.role === 'instructor' || profile.is_instructor) : profile.role !== 'admin') return '/'
  return true
})

export default router
