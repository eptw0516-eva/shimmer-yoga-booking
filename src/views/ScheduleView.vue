<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { ChevronLeft, ChevronRight, Clock3, MapPin, Sparkles, Users, X, UserRound } from 'lucide-vue-next'
import { useBookingStore } from '../stores/bookingStore'
import { useAuthStore } from '../stores/authStore'
import { useRouter } from 'vue-router'
import type { YogaClass } from '../types/database'

const store = useBookingStore()
const auth = useAuthStore()
const router = useRouter()
const monthCursor = ref(new Date(new Date().getFullYear(), new Date().getMonth(), 1))
const selectedDate = ref(new Date())
const pending = ref<YogaClass | null>(null)

const monthLabel = computed(() => new Intl.DateTimeFormat('zh-TW', { year: 'numeric', month: 'long' }).format(monthCursor.value))
const monthDays = computed(() => {
  const first = new Date(monthCursor.value)
  const start = new Date(first); start.setDate(1 - first.getDay())
  return Array.from({ length: 42 }, (_, index) => {
    const date = new Date(start); date.setDate(start.getDate() + index)
    return date
  })
})
const dateKey = (date: Date) => `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`
const dayClasses = (date: Date) => store.classes.filter((item) => {
  const value = new Date(item.start_time)
  return value.getFullYear() === date.getFullYear() && value.getMonth() === date.getMonth() && value.getDate() === date.getDate()
}).sort((a, b) => a.start_time.localeCompare(b.start_time))
const selectedClasses = computed(() => dayClasses(selectedDate.value))
const formatTime = (value: string) => new Intl.DateTimeFormat('zh-TW', { hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date(value))
const formatDate = (date: Date) => new Intl.DateTimeFormat('zh-TW', { month: 'long', day: 'numeric', weekday: 'short' }).format(date)
const isBooked = (item: YogaClass) => store.activeBookings.some((booking) => booking.class_id === item.id)
const isClosed = (item: YogaClass) => new Date(item.start_time).getTime() - Date.now() <= 10 * 60 * 1000
const isWaitlisted = (item: YogaClass) => store.waitlistedClassIds.includes(item.id)
const previousMonth = () => { monthCursor.value = new Date(monthCursor.value.getFullYear(), monthCursor.value.getMonth() - 1, 1) }
const nextMonth = () => { monthCursor.value = new Date(monthCursor.value.getFullYear(), monthCursor.value.getMonth() + 1, 1) }
const selectDate = (date: Date) => { selectedDate.value = date }
async function confirmBooking() {
  if (pending.value) await store.bookClass(pending.value)
  pending.value = null
}
function requireLogin() { router.push(`/login?redirect=${encodeURIComponent('/')}`) }
onMounted(async () => { await store.loadSchedule(); if (auth.isAuthenticated) await store.loadUserData() })
</script>

<template>
  <div class="animate-rise">
    <section class="mb-5 rounded-[28px] bg-sage p-5 text-white">
      <div class="mb-5 flex items-start justify-between"><div><p class="mb-1 text-xs tracking-[.2em] text-white/70">FIND YOUR FLOW</p><h1 class="font-display text-2xl">選一堂適合今天的練習。</h1></div><Sparkles :size="24" class="text-[#e8d99d]" /></div>
      <div class="flex items-center justify-between rounded-2xl bg-white/10 px-4 py-3"><span class="text-sm text-white/80">我的可用堂數</span><span class="text-2xl font-semibold">{{ store.availableCredits }} <small class="text-sm font-normal">堂</small></span></div>
    </section>
    <section class="rounded-3xl border border-sand bg-white p-4 shadow-sm">
      <div class="mb-4 flex items-center justify-between"><button class="rounded-xl p-2 text-sage" @click="previousMonth"><ChevronLeft :size="18" /></button><h2 class="font-display text-xl">{{ monthLabel }}</h2><button class="rounded-xl p-2 text-sage" @click="nextMonth"><ChevronRight :size="18" /></button></div>
      <div class="mb-2 grid grid-cols-7 text-center text-[10px] text-stone-400"><span v-for="label in ['日','一','二','三','四','五','六']" :key="label">{{ label }}</span></div>
      <div class="grid grid-cols-7 gap-1">
        <button v-for="date in monthDays" :key="dateKey(date)" class="min-h-[62px] rounded-xl p-1 text-left text-xs transition" :class="[date.getMonth() === monthCursor.getMonth() ? 'text-ink' : 'text-stone-300', dateKey(date) === dateKey(selectedDate) ? 'bg-sage text-white' : 'hover:bg-[#f4ede7]']" @click="selectDate(date)">
          <span class="block text-center font-semibold">{{ date.getDate() }}</span>
          <span v-for="item in dayClasses(date).slice(0, 2)" :key="item.id" class="mt-1 block truncate rounded bg-[#f4ede7] px-1 text-[9px] text-clay" :class="{ '!bg-white/20 !text-white': dateKey(date) === dateKey(selectedDate) }">{{ item.title }}</span>
          <span v-if="dayClasses(date).length > 2" class="block text-center text-[9px] opacity-70">+{{ dayClasses(date).length - 2 }} 堂</span>
        </button>
      </div>
    </section>
    <div class="mb-3 mt-6 flex items-center justify-between"><h2 class="font-display text-xl">{{ formatDate(selectedDate) }} 課程</h2><span class="text-xs text-stone-400">{{ selectedClasses.length }} 堂</span></div>
    <div v-if="selectedClasses.length" class="space-y-3">
      <article v-for="item in selectedClasses" :key="item.id" class="rounded-3xl border border-sand bg-white p-4 shadow-sm">
        <div class="mb-3 flex items-start justify-between"><div><span class="mb-2 mr-1 inline-block rounded-full bg-[#f4ede7] px-2.5 py-1 text-[10px] font-semibold text-clay">{{ item.course_type }}</span><span class="mb-2 inline-block rounded-full bg-[#efeff7] px-2.5 py-1 text-[10px] font-semibold text-sage">{{ item.level }}</span><h3 class="font-semibold">{{ item.title }}</h3></div><span class="text-xs font-medium text-sage">{{ item.instructor_name }}</span></div>
        <p class="mb-1 flex items-center gap-1 text-xs font-medium text-ink"><UserRound :size="13" />{{ item.instructor_bio || '微光空中瑜珈專任講師' }}</p><p class="mb-3 text-xs leading-relaxed text-stone-500">{{ item.description }}</p>
        <div class="mb-4 flex flex-wrap gap-3 text-[11px] text-stone-500"><span class="flex items-center gap-1"><Clock3 :size="13" />{{ formatTime(item.start_time) }} – {{ formatTime(item.end_time) }}</span><span class="flex items-center gap-1"><MapPin :size="13" />{{ item.room }}</span><span class="flex items-center gap-1"><Users :size="13" />{{ item.booked_count }} / {{ item.capacity }} 人</span></div>
        <div class="flex items-center justify-end border-t border-sand pt-3">
          <button v-if="isBooked(item)" class="rounded-xl bg-[#eef3ee] px-4 py-2 text-xs font-semibold text-sage" disabled>已預約</button>
          <button v-else-if="isWaitlisted(item)" class="rounded-xl bg-[#f5ede9] px-4 py-2 text-xs font-semibold text-clay" disabled>已加入候補</button>
          <button v-else-if="item.booked_count >= item.capacity" class="rounded-xl border border-clay px-4 py-2 text-xs font-semibold text-clay" @click="auth.isAuthenticated ? store.joinWaitlist(item) : requireLogin()">加入候補名單</button>
          <button v-else-if="isClosed(item)" class="rounded-xl bg-stone-300 px-4 py-2 text-xs font-semibold text-white" disabled>預約已截止</button>
          <button v-else class="rounded-xl bg-clay px-4 py-2 text-xs font-semibold text-white" @click="auth.isAuthenticated ? pending = item : requireLogin()">立即預約</button>
        </div>
        <p v-if="isClosed(item) && !isBooked(item)" class="mt-3 border-t border-sand pt-2 text-[11px] text-clay">開課前 10 分鐘截止預約</p>
      </article>
    </div>
    <div v-else class="rounded-3xl border border-dashed border-sand py-12 text-center text-sm text-stone-400">這天還沒有排課，換一天看看吧。</div>
    <Teleport to="body"><div v-if="pending" class="fixed inset-0 z-30 flex items-end justify-center bg-ink/30 p-4 sm:items-center"><div class="w-full max-w-[398px] rounded-[28px] bg-cream p-6 shadow-xl"><div class="mb-5 flex items-center justify-between"><h3 class="font-display text-xl">確認預約</h3><button class="rounded-full bg-sand p-2" @click="pending = null"><X :size="16" /></button></div><p class="mb-1 text-sm font-semibold">{{ pending.title }}</p><p class="mb-5 text-xs text-stone-500">{{ formatDate(new Date(pending.start_time)) }} · {{ formatTime(pending.start_time) }} · {{ pending.instructor_name }}</p><div class="mb-5 flex items-center justify-between rounded-2xl bg-[#eef3ee] p-4"><span class="text-xs text-stone-500">預約後可用堂數</span><strong class="text-xl text-sage">{{ Math.max(0, store.availableCredits - 1) }} <small class="text-xs font-normal">堂</small></strong></div><button class="w-full rounded-2xl bg-sage py-3 text-sm font-semibold text-white" :disabled="store.loading" @click="confirmBooking">{{ store.loading ? '處理中…' : '確認預約' }}</button></div></div></Teleport>
    <div v-if="store.toast" class="fixed left-1/2 top-5 z-40 w-[calc(100%-2rem)] max-w-[398px] -translate-x-1/2 rounded-2xl bg-ink px-4 py-3 text-sm text-white shadow-lg">{{ store.toast.message }}</div>
  </div>
</template>
