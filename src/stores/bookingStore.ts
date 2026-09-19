import { computed, ref } from 'vue'
import { defineStore } from 'pinia'
import { supabase } from '../services/supabase'
import { useAuthStore } from './authStore'
import type { AttendanceRecord, Booking, CheckInResult, PaymentMethod, PurchaseOrder, PurchasePlan, UserPackage, YogaClass } from '../types/database'

const today = new Date()
const dateAt = (offset: number, hour: number, minute = 0) => {
  const value = new Date(today); value.setDate(today.getDate() + offset); value.setHours(hour, minute, 0, 0); return value.toISOString()
}
const demoClasses: YogaClass[] = [
  { id: 'class-1', title: '晨光流動瑜伽', instructor_id: 'instructor-1', instructor_name: '林安老師', instructor_bio: 'RYT 500 認證，專注呼吸與身體覺察。', course_type: '常態課', room: 'A 教室', start_time: dateAt(0, 7, 30), end_time: dateAt(0, 8, 30), capacity: 12, booked_count: 8, level: '初階', description: '用呼吸喚醒身體，溫柔地開始一天。' },
  { id: 'class-2', title: '深層伸展與修復', instructor_id: 'instructor-2', instructor_name: '蘇米老師', instructor_bio: '運動傷害防護背景，帶領安全伸展。', course_type: '預約團體課', room: 'B 教室', start_time: dateAt(0, 19), end_time: dateAt(0, 20), capacity: 10, booked_count: 10, level: '初階', description: '釋放緊繃，找回身體的空間。' },
  { id: 'class-3', title: '核心力量瑜伽', instructor_id: 'instructor-1', instructor_name: '林安老師', instructor_bio: 'RYT 500 認證，專注呼吸與身體覺察。', course_type: '常態課', room: 'A 教室', start_time: dateAt(1, 18, 30), end_time: dateAt(1, 19, 45), capacity: 12, booked_count: 5, level: '中階', description: '穩定核心，建立身體的力量感。' },
  { id: 'class-4', title: '空中瑜珈私人指導', instructor_id: 'instructor-3', instructor_name: '若晴老師', instructor_bio: '空中瑜珈專任講師，客製每個人的練習。', course_type: '一對一私人課', room: '陽光教室', start_time: dateAt(2, 10), end_time: dateAt(2, 11, 15), capacity: 1, booked_count: 0, level: '初階', description: '依身體狀態調整吊床高度與動作。' },
  { id: 'class-5', title: '肩頸放鬆工作坊', instructor_id: 'instructor-2', instructor_name: '蘇米老師', instructor_bio: '運動傷害防護背景，帶領安全伸展。', course_type: '單堂工作坊', room: 'B 教室', start_time: dateAt(3, 19), end_time: dateAt(3, 20), capacity: 10, booked_count: 4, level: '初階', description: '為久坐生活設計的深度放鬆。' },
]
export const purchasePlans: PurchasePlan[] = [
  { id: 'trial', name: '單堂體驗票', type: 'single', description: '第一次來微光，從一堂舒服的空中瑜珈開始。', price: 650, credits: 1, validDays: 30, shareable: false, badge: '初次體驗' },
  { id: 'ten-class', name: '10 堂計次包', type: 'credits', description: '彈性安排練習，適合穩定累積身體的力量。', price: 4800, credits: 10, validDays: 120, shareable: true, badge: '最受歡迎' },
  { id: 'monthly', name: '月費吃到飽', type: 'unlimited', description: '一個月內不限堂數，讓練習成為生活日常。', price: 3200, credits: 999, validDays: 30, shareable: false },
  { id: 'stored-value', name: '儲值金 3,000', type: 'stored_value', description: '儲值後依單堂課價格彈性扣款。', price: 3000, credits: null, validDays: 365, shareable: true },
]

export const useBookingStore = defineStore('booking', () => {
  const classes = ref<YogaClass[]>([...demoClasses])
  const bookings = ref<Booking[]>([{ id: 'booking-demo', user_id: 'demo-user', class_id: 'class-3', status: 'confirmed', created_at: today.toISOString(), class: demoClasses[2] }])
  const packages = ref<UserPackage[]>([{ id: 'package-demo', user_id: 'demo-user', total_credits: 20, remaining_credits: 8, valid_until: '2026-12-31', status: 'active', created_at: '2026-01-01', plan_name: '晨光 20 堂方案', plan_type: 'credits', shared_with_phones: [] }])
  const orders = ref<PurchaseOrder[]>([])
  const loading = ref(false)
  const toast = ref<{ message: string; type: 'success' | 'error' } | null>(null)
  const waitlistedClassIds = ref<string[]>([])
  const attendance = ref<AttendanceRecord[]>([])
  const pendingOrders = computed(() => orders.value.filter((order) => order.status === 'pending_review'))
  const availableCredits = computed(() => packages.value.reduce((sum, item) => sum + (item.status === 'active' ? item.remaining_credits : 0), 0))
  const activeBookings = computed(() => bookings.value.filter((booking) => booking.status === 'confirmed'))
  const pastBookings = computed(() => bookings.value.filter((booking) => booking.status !== 'confirmed'))
  const notify = (message: string, type: 'success' | 'error' = 'success') => { toast.value = { message, type }; window.setTimeout(() => { toast.value = null }, 3000) }
  async function loadSchedule() {
    if (!supabase) return
    loading.value = true
    const { data, error } = await supabase.from('classes').select('*').order('start_time')
    if (!error && data) classes.value = data
    loading.value = false
  }
  async function bookClass(item: YogaClass) {
    const auth = useAuthStore()
    if (!auth.isAuthenticated || !auth.user) { notify('請先登入後再預約。', 'error'); return false }
    if (new Date(item.start_time).getTime() - Date.now() <= 3 * 60 * 60 * 1000) { notify('此課程已於開課前 3 小時截止預約。', 'error'); return false }
    if (item.booked_count >= item.capacity) { notify('這堂課已額滿，請加入候補名單。', 'error'); return false }
    if (availableCredits.value <= 0) { notify('目前沒有可用堂數，請先購買方案。', 'error'); return false }
    loading.value = true
    if (supabase) {
      const { data, error } = await supabase.rpc('book_class', { p_class_id: item.id, p_user_id: auth.user.id } as never) as unknown as { data: Booking | null; error: { message: string } | null }
      if (error) { notify(error.message, 'error'); loading.value = false; return false }
      if (data) bookings.value.push({ ...data, class: item })
    } else {
      item.booked_count += 1
      packages.value[0].remaining_credits -= 1
      bookings.value.push({ id: `booking-${Date.now()}`, user_id: 'demo-user', class_id: item.id, status: 'confirmed', created_at: new Date().toISOString(), class: item })
    }
    loading.value = false; notify(`已成功預約「${item.title}」！`); return true
  }
  function joinWaitlist(item: YogaClass) {
    const auth = useAuthStore()
    if (!auth.isAuthenticated) { notify('請先登入後再加入候補名單。', 'error'); return false }
    if (!waitlistedClassIds.value.includes(item.id)) waitlistedClassIds.value.push(item.id)
    notify(`已加入「${item.title}」候補名單，釋出名額時會通知您。`)
    return true
  }
  function markAttendance(bookingId: string, status: AttendanceRecord['status']) {
    const auth = useAuthStore()
    if (!auth.isInstructor) { notify('只有老師或管理員可以點名。', 'error'); return false }
    const current = attendance.value.find((item) => item.booking_id === bookingId)
    if (current) current.status = status
    else attendance.value.push({ booking_id: bookingId, status })
    notify(status === 'attended' ? '已標記出席。' : '已標記缺席。')
    return true
  }
  async function submitPurchase(plan: PurchasePlan, paymentMethod: PaymentMethod, transferLastFive: string | null) {
    const auth = useAuthStore()
    if (!auth.isAuthenticated || !auth.user) { notify('請先登入後再送出購課申請。', 'error'); return false }
    if (paymentMethod === 'bank_transfer' && (!transferLastFive || !/^\d{5}$/.test(transferLastFive))) {
      notify('請輸入正確的匯款帳號末五碼。', 'error')
      return false
    }
    const order: PurchaseOrder = {
      id: `order-${Date.now()}`, user_id: auth.user.id, plan_id: plan.id, plan_name: plan.name,
      amount: plan.price, payment_method: paymentMethod, transfer_last_five: transferLastFive,
      status: 'pending_review', created_at: new Date().toISOString(),
    }
    if (supabase) {
      const { error } = await supabase.from('purchase_orders').insert(order as never)
      if (error) { notify(error.message, 'error'); return false }
    }
    orders.value.unshift(order)
    notify('購課申請已送出，管理員核款後會更新票券。')
    return true
  }
  async function createClass(input: Omit<YogaClass, 'id' | 'booked_count'>) {
    const auth = useAuthStore()
    if (!auth.isAdmin) { notify('只有管理員可以新增課程。', 'error'); return false }
    if (supabase) {
      const { data, error } = await supabase.from('classes').insert({ ...input, booked_count: 0 } as never).select().single()
      if (error) { notify(error.message, 'error'); return false }
      if (data) classes.value.push(data as YogaClass)
    } else {
      classes.value.push({ ...input, id: `class-${Date.now()}`, booked_count: 0 })
    }
    notify(`已新增課程「${input.title}」。`)
    return true
  }
  async function approveOrder(order: PurchaseOrder) {
    if (supabase) {
      const { data, error } = await supabase.rpc('approve_purchase_order', { p_order_id: order.id } as never) as unknown as { data: UserPackage | null; error: { message: string } | null }
      if (error) { notify(error.message, 'error'); return false }
      if (data) packages.value.unshift(data)
    } else {
      const plan = purchasePlans.find((item) => item.id === order.plan_id)
      if (!plan) { notify('找不到方案資料。', 'error'); return false }
      const validUntil = new Date(); validUntil.setDate(validUntil.getDate() + plan.validDays)
      const created: UserPackage = {
        id: `package-${Date.now()}`, user_id: order.user_id, total_credits: plan.credits ?? 0,
        remaining_credits: plan.credits ?? 0, valid_until: validUntil.toISOString().slice(0, 10),
        status: 'active', created_at: new Date().toISOString(), plan_name: plan.name, plan_type: plan.type,
        shared_with_phones: plan.shareable ? [] : undefined,
      }
      packages.value.unshift(created)
      order.package_id = created.id
    }
    order.status = 'approved'
    notify(`已確認「${order.plan_name}」入帳，票券已建立。`)
    return true
  }
  function sharePackage(packageId: string, phone: string) {
    const normalized = phone.replace(/\s/g, '')
    if (!/^09\d{8}$/.test(normalized)) { notify('請輸入有效的台灣手機號碼。', 'error'); return false }
    const target = packages.value.find((item) => item.id === packageId)
    if (!target) { notify('找不到這個票券。', 'error'); return false }
    target.shared_with_phones = [...new Set([...(target.shared_with_phones ?? []), normalized])]
    notify(`已新增共享親友 ${normalized}。`)
    return true
  }
  async function cancelBooking(booking: Booking, late = false) {
    const auth = useAuthStore()
    if (!auth.isAuthenticated) { notify('請先登入後再管理預約。', 'error'); return false }
    const hoursUntilClass = (new Date(booking.class?.start_time ?? 0).getTime() - Date.now()) / 3600000
    if (!late && hoursUntilClass < 3) {
      notify('已逾可取消時限，請使用逾期請假。', 'error')
      return false
    }
    if (supabase) {
      const rpc = late ? 'late_cancel_booking' : 'cancel_booking'
      const { error } = await supabase.rpc(rpc, { p_booking_id: booking.id } as never) as unknown as { error: { message: string } | null }
      if (error) { notify(error.message, 'error'); return false }
    } else {
      if (!late) {
        const target = classes.value.find((item) => item.id === booking.class_id)
        if (target) target.booked_count -= 1
        packages.value[0].remaining_credits += 1
      }
    }
    booking.status = late ? 'late_cancelled' : 'cancelled'
    notify(late ? '已通知老師請假，本堂點數依規章扣除。' : '預約已取消，堂數已退回。')
    return true
  }
  async function checkInBooking(token: string): Promise<CheckInResult | null> {
    const auth = useAuthStore()
    if (!auth.isAuthenticated) { notify('請先登入後再簽到。', 'error'); return null }
    const validToken = token === 'SHIMMER_CHECKIN_SECRET'
    if (!validToken) { notify('QR Code 不符合微光空中瑜珈簽到規格。', 'error'); return null }
    const booking = bookings.value.find((item) => item.status === 'confirmed' && item.class)
    if (!booking?.class) { notify('找不到今日有效預約。', 'error'); return null }
    const start = new Date(booking.class.start_time).getTime()
    const end = new Date(booking.class.end_time).getTime()
    if (Date.now() < start - 30 * 60 * 1000 || Date.now() > end + 15 * 60 * 1000) {
      notify('目前不在簽到時段（課前 30 分鐘至下課後 15 分鐘）。', 'error')
      return null
    }
    if (supabase) {
      const { data, error } = await supabase.rpc('checkin_class', { p_booking_id: booking.id, p_token: token } as never) as unknown as { data: Booking | null; error: { message: string } | null }
      if (error || !data) { notify(error?.message ?? '簽到失敗。', 'error'); return null }
      booking.status = 'attended'
      booking.checked_in_at = new Date().toISOString()
    } else {
      booking.status = 'attended'
      booking.checked_in_at = new Date().toISOString()
    }
    return { booking, class: booking.class }
  }
  function clearToast() { toast.value = null }
  return { classes, bookings, packages, orders, pendingOrders, loading, toast, availableCredits, activeBookings, pastBookings, waitlistedClassIds, attendance, loadSchedule, bookClass, joinWaitlist, cancelBooking, checkInBooking, markAttendance, submitPurchase, createClass, approveOrder, sharePackage, notify, clearToast }
})
