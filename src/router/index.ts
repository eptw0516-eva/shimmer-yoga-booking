import { createRouter, createWebHistory } from 'vue-router'
import ScheduleView from '../views/ScheduleView.vue'
import MyPassesView from '../views/MyPassesView.vue'
import CheckInView from '../views/CheckInView.vue'
import AdminView from '../views/AdminView.vue'
import StoreView from '../views/StoreView.vue'
import AdminOrdersView from '../views/AdminOrdersView.vue'
import MyBookingsView from '../views/MyBookingsView.vue'
import QrCodeDisplayView from '../views/admin/QrCodeDisplayView.vue'
import { isSupabaseConfigured, supabase } from '../services/supabase'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/', component: ScheduleView, meta: { title: '預約課表' } },
    { path: '/my-passes', component: MyPassesView, meta: { title: '我的旅程' } },
    { path: '/my-bookings', component: MyBookingsView, meta: { title: '我的預約' } },
    { path: '/store', component: StoreView, meta: { title: '購課商城' } },
    { path: '/check-in', component: CheckInView, meta: { title: '今日簽到' } },
    { path: '/admin', component: AdminView, meta: { title: '教室管理' } },
    { path: '/admin/orders', component: AdminOrdersView, meta: { title: '購課核帳' } },
    { path: '/admin/check-in-qr', component: QrCodeDisplayView, meta: { title: '教室簽到 QR Code', staff: true } },
  ],
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach(async (to) => {
  const memberRoute = to.path === '/check-in' || to.path === '/my-bookings'
  if (memberRoute && isSupabaseConfigured && supabase) {
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) return '/'
    return true
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
  const { data } = await supabase.from('profiles').select('role').eq('id', user.id).single()
  const role = (data as unknown as { role?: string } | null)?.role
  if (to.meta.staff ? !['admin', 'instructor'].includes(role ?? '') : role !== 'admin') return '/'
  return true
})

export default router
