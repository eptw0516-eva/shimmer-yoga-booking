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
import AdminPlansView from '../views/admin/AdminPlansView.vue'
import AuthView from '../views/AuthView.vue'
import { useAuthStore } from '../stores/authStore'
import { isSupabaseConfigured, supabase } from '../services/supabase'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    { path: '/login', component: AuthView, meta: { title: '會員登入' } },
    { path: '/', component: ScheduleView, meta: { title: '預約課表', public: true } },
    { path: '/my-passes', component: MyPassesView, meta: { title: '我的旅程', requiresAuth: true } },
    { path: '/my-bookings', component: MyBookingsView, meta: { title: '我的預約', requiresAuth: true } },
    { path: '/store', component: StoreView, meta: { title: '購課商城', requiresAuth: true } },
    { path: '/check-in', component: CheckInView, meta: { title: '今日簽到', requiresAuth: true } },
    { path: '/admin', component: AdminView, meta: { title: '教室管理', requiresAuth: true, adminOnly: true } },
    { path: '/admin/orders', component: AdminOrdersView, meta: { title: '購課核帳', requiresAuth: true, adminOnly: true } },
    { path: '/admin/check-in-qr', component: QrCodeDisplayView, meta: { title: '教室簽到 QR Code', staff: true, requiresAuth: true } },
    { path: '/admin/members', component: AdminMembersView, meta: { title: '會員與角色管理', requiresAuth: true, adminOnly: true } },
    { path: '/admin/plans', component: AdminPlansView, meta: { title: '購課方案管理', requiresAuth: true, adminOnly: true } },
  ],
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()
  if (!auth.initialized) await auth.load()
  if (to.path === '/register') return '/login'
  if (to.path === '/login') return auth.isAuthenticated && to.query.reset !== '1' ? '/' : true
  if (to.meta.requiresAuth && !auth.isAuthenticated) return `/login?redirect=${encodeURIComponent(to.fullPath)}`
  if (to.meta.adminOnly && !auth.isAdmin) return '/'
  if (to.meta.staff && !auth.isInstructor) return '/'
  if (!to.meta.requiresAuth && !to.meta.public) return '/'
  if (!isSupabaseConfigured || !supabase) return true
  if (!auth.isAuthenticated) return true
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return true
  if (!auth.profile) await auth.loadProfile(user.id)
  const profile = auth.profile
  if (!profile?.is_active) return '/'
  if (to.meta.adminOnly && profile.role !== 'admin') return '/'
  if (to.meta.staff && !(profile.role === 'admin' || profile.role === 'instructor' || profile.is_instructor)) return '/'
  return true
})

export default router
