<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import { Html5Qrcode } from 'html5-qrcode'
import { Check, ClipboardCheck, QrCode, UserCheck, Users, X } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
import { useBookingStore } from '../stores/bookingStore'
import { formatTaiwanDateTime } from '../utils/date'
import { useAuthStore } from '../stores/authStore'
import { supabase } from '../services/supabase'
import type { AttendanceRecord } from '../types/database'

const store = useBookingStore()
const auth = useAuthStore()
const router = useRouter()
const mode = ref<'member' | 'instructor'>('member')
const scanning = ref(false)
const scannerError = ref('')
const success = ref<{ title: string; instructor?: string } | null>(null)
let scanner: Html5Qrcode | null = null
const todayKey = () => formatTaiwanDateTime(new Date().toISOString()).slice(0, 10)
const todayClasses = computed(() => store.classes.filter((item) => formatTaiwanDateTime(item.start_time).slice(0, 10) === todayKey()))
const classStudents = ref<Record<string, Array<{ bookingId: string; name: string }>>>({})
const attendanceFor = (id: string) => store.attendance.find((item) => item.booking_id === id)?.status

async function loadTodayBookings() {
  if (!supabase || !auth.isInstructor) return
  const { data, error } = await supabase
    .from('bookings')
    .select('id,class_id,user_id,status,profile:profiles(full_name)')
    .in('status', ['confirmed', 'attended', 'no_show'])
  if (error) {
    store.notify(`今日預約名單載入失敗：${error.message}`, 'error')
    return
  }
  const result: Record<string, Array<{ bookingId: string; name: string }>> = {}
  for (const item of (data ?? []) as Array<{ id: string; class_id: string; profile?: { full_name?: string | null } | null }>) {
    const list = result[item.class_id] ?? []
    list.push({ bookingId: item.id, name: item.profile?.full_name || '未設定姓名' })
    result[item.class_id] = list
  }
  classStudents.value = result
}

function markStudent(bookingId: string, status: AttendanceRecord['status']) {
  store.markAttendance(bookingId, status)
}

function openClassQr(classId: string) {
  router.push(`/admin/check-in-qr?class_id=${encodeURIComponent(classId)}`)
}

function parseToken(value: string): { token: string; classId?: string } | null {
  try {
    const payload = JSON.parse(value) as { studio?: string; action?: string; code?: string; token?: string }
    if (payload.studio === 'shimmer_yoga' && payload.action === 'checkin' && (payload.code ?? payload.token)) return { token: payload.code ?? payload.token ?? '', classId: (payload as { class_id?: string }).class_id }
  } catch {
    try {
      const url = new URL(value)
      const token = url.searchParams.get('token')
      return token ? { token, classId: url.searchParams.get('class_id') ?? undefined } : null
    } catch {
      return null
    }
  }
  return null
}

async function stopScanner() {
  if (!scanner) return
  if (scanning.value) await scanner.stop().catch(() => undefined)
  scanner.clear()
  scanner = null
  scanning.value = false
}

async function handleScan(decodedText: string) {
  await stopScanner()
  const payload = parseToken(decodedText)
  if (!payload) {
    scannerError.value = 'QR Code 格式不正確，請掃描櫃檯或白板上的微光簽到 QR Code。'
    return
  }
  const result = await store.checkInBooking(payload.token, payload.classId)
  if (result) {
    success.value = { title: result.class.title, instructor: result.class.instructor_name }
    window.setTimeout(() => router.push('/'), 3000)
  }
}

async function startScanner() {
  scannerError.value = ''
  success.value = null
  await stopScanner()
  scanner = new Html5Qrcode('qr-reader')
  try {
    await scanner.start({ facingMode: 'environment' }, { fps: 10, qrbox: { width: 240, height: 240 } }, handleScan, () => undefined)
    scanning.value = true
  } catch {
    scannerError.value = '無法開啟相機，請確認瀏覽器已允許相機權限，並使用 HTTPS 或 localhost。'
    await stopScanner()
  }
}

onMounted(async () => {
  await store.loadSchedule()
  await loadTodayBookings()
})
onUnmounted(() => { void stopScanner() })
</script>

<template>
  <div class="animate-rise">
    <div class="mb-5 flex rounded-2xl bg-sand p-1">
      <button class="flex-1 rounded-xl py-2 text-xs" :class="mode === 'member' ? 'bg-white font-semibold text-sage shadow-sm' : 'text-stone-500'" @click="mode = 'member'"><UserCheck :size="15" class="mr-1 inline" />學員掃碼簽到</button>
      <button v-if="auth.isInstructor" class="flex-1 rounded-xl py-2 text-xs" :class="mode === 'instructor' ? 'bg-white font-semibold text-sage' : 'text-stone-500'" @click="mode = 'instructor'"><Users :size="15" class="mr-1 inline" />老師點名</button>
    </div>
    <template v-if="mode === 'member'">
      <section class="mb-4 rounded-[28px] bg-sage p-5 text-center text-white">
        <QrCode class="mx-auto mb-3 text-rose" :size="34" /><h2 class="font-display text-2xl">現場自助簽到</h2><p class="mt-2 text-xs leading-relaxed text-white/70">請對準櫃檯或白板張貼的 QR Code<br />系統會在掃描成功後自動驗證課程時段</p>
        <div id="qr-reader" class="mt-5 min-h-[100px] overflow-hidden rounded-2xl bg-black/20" />
        <button v-if="!scanning" class="mt-4 w-full rounded-2xl bg-rose py-3 text-sm font-semibold text-white" @click="startScanner">開啟鏡頭掃描</button>
        <button v-else class="mt-4 w-full rounded-2xl bg-white/15 py-3 text-sm font-semibold text-white" @click="stopScanner"><X :size="16" class="mr-1 inline" />停止掃描</button>
      </section>
      <p class="mb-3 rounded-2xl bg-white px-4 py-3 text-xs leading-relaxed text-stone-500">簽到開放時間：課前 30 分鐘至下課後 15 分鐘。請確認您已完成該堂課預約。</p>
      <p v-if="scannerError" class="rounded-2xl bg-[#f8ece8] px-4 py-3 text-xs text-clay">{{ scannerError }}</p>
      <div v-if="success" class="mt-3 rounded-2xl bg-[#e8f3e9] p-4 text-sm text-sage"><Check :size="18" class="mr-1 inline" /><strong>簽到成功！</strong><p class="mt-2 text-xs">課程名稱：{{ success.title }}<br />任課老師：{{ success.instructor ?? '微光瑜珈老師' }}<br /><span class="text-stone-500">3 秒後返回首頁</span></p></div>
    </template>
    <template v-else>
      <div class="mb-4 flex items-center justify-between"><div><h2 class="font-display text-xl">今日課程</h2><p class="mt-1 text-xs text-stone-400">即時更新出席與缺席狀態</p></div><span class="rounded-full bg-[#efeff7] px-3 py-1 text-xs text-sage">{{ store.attendance.filter((item) => item.status === 'attended').length }} 人已到</span></div>
      <div class="space-y-4"><article v-for="item in todayClasses" :key="item.id" class="rounded-3xl border border-sand bg-white p-4"><div class="mb-4 flex items-center justify-between"><div><h3 class="font-semibold">{{ item.title }}</h3><p class="mt-1 text-xs text-stone-400">{{ formatTaiwanDateTime(item.start_time) }} · {{ item.room }}</p></div><div class="flex items-center gap-2"><button class="rounded-xl bg-[#efeff7] px-3 py-2 text-[11px] font-semibold text-sage" @click="openClassQr(item.id)"><QrCode :size="14" class="mr-1 inline" />課程 QR</button><ClipboardCheck :size="20" class="text-sage" /></div></div><div class="space-y-2"><div v-for="student in (classStudents[item.id] ?? [])" :key="student.bookingId" class="flex items-center justify-between rounded-2xl bg-[#faf9f5] px-3 py-2.5"><span class="text-sm">{{ student.name }}</span><span class="flex gap-1"><button class="rounded-lg px-2 py-1 text-[11px]" :class="attendanceFor(student.bookingId) === 'attended' ? 'bg-sage text-white' : 'bg-[#e8f0e9] text-sage'" @click="markStudent(student.bookingId, 'attended')">出席</button><button class="rounded-lg px-2 py-1 text-[11px]" :class="attendanceFor(student.bookingId) === 'no_show' ? 'bg-clay text-white' : 'bg-[#f8ece8] text-clay'" @click="markStudent(student.bookingId, 'no_show')">缺席</button></span></div><p v-if="!(classStudents[item.id] ?? []).length" class="rounded-2xl bg-[#faf9f5] px-3 py-3 text-xs text-stone-400">目前沒有已確認預約的學員。</p></div></article></div>
      <div v-if="!todayClasses.length" class="rounded-3xl border border-dashed border-sand py-10 text-center text-sm text-stone-400">今天沒有您的帶課。</div>
    </template>
    <div v-if="store.toast" class="fixed left-1/2 top-5 z-40 w-[calc(100%-2rem)] max-w-[398px] -translate-x-1/2 rounded-2xl bg-ink px-4 py-3 text-sm text-white shadow-lg">{{ store.toast.message }}</div>
  </div>
</template>
