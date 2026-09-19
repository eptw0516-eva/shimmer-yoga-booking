<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { Clock3, MapPin, Sparkles, Users, X, UserRound } from 'lucide-vue-next'
import { useBookingStore } from '../stores/bookingStore'
import type { YogaClass } from '../types/database'

const store = useBookingStore()
const selectedDate = ref(0)
const pending = ref<YogaClass | null>(null)
const dates = Array.from({ length: 7 }, (_, index) => {
  const date = new Date(); date.setDate(date.getDate() + index)
  return { offset: index, weekday: index === 0 ? '今天' : new Intl.DateTimeFormat('zh-TW', { weekday: 'short' }).format(date), day: date.getDate(), month: date.getMonth() + 1 }
})
const visibleClasses = computed(() => store.classes.filter((item) => {
  const date = new Date(item.start_time); const target = new Date(); target.setDate(target.getDate() + selectedDate.value)
  return date.getDate() === target.getDate() && date.getMonth() === target.getMonth()
}))
const formatTime = (value: string) => new Intl.DateTimeFormat('zh-TW', { hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date(value))
const isBooked = (item: YogaClass) => store.activeBookings.some((booking) => booking.class_id === item.id)
const isClosed = (item: YogaClass) => new Date(item.start_time).getTime() - Date.now() <= 3 * 60 * 60 * 1000
const isWaitlisted = (item: YogaClass) => store.waitlistedClassIds.includes(item.id)
async function confirmBooking() { if (pending.value) await store.bookClass(pending.value); pending.value = null }
onMounted(() => store.loadSchedule())
</script>

<template>
  <div class="animate-rise">
    <section class="mb-6 rounded-[28px] bg-sage p-5 text-white">
      <div class="mb-5 flex items-start justify-between"><div><p class="mb-1 text-xs tracking-[.2em] text-white/70">FIND YOUR FLOW</p><h1 class="font-display text-2xl">今天，給自己一小時。</h1></div><Sparkles :size="24" class="text-[#e8d99d]" /></div>
      <div class="flex items-center justify-between rounded-2xl bg-white/10 px-4 py-3"><span class="text-sm text-white/80">我的可用堂數</span><span class="text-2xl font-semibold">{{ store.availableCredits }} <small class="text-sm font-normal">堂</small></span></div>
    </section>
    <div class="scrollbar-hide -mx-5 mb-6 flex gap-2 overflow-x-auto px-5">
      <button v-for="date in dates" :key="date.offset" class="min-w-[55px] rounded-2xl border px-2 py-3 text-center transition" :class="selectedDate === date.offset ? 'border-sage bg-sage text-white' : 'border-sand bg-white text-stone-500'" @click="selectedDate = date.offset">
        <span class="block text-[11px]">{{ date.weekday }}</span><strong class="mt-1 block text-lg">{{ date.day }}</strong><span class="text-[10px] opacity-70">{{ date.month }}月</span>
      </button>
    </div>
    <div class="mb-4 flex items-center justify-between"><h2 class="font-display text-xl">推薦課程</h2><span class="text-xs text-stone-400">{{ visibleClasses.length }} 堂課</span></div>
    <div v-if="visibleClasses.length" class="space-y-3">
      <article v-for="item in visibleClasses" :key="item.id" class="rounded-3xl border border-sand bg-white p-4 shadow-sm">
        <div class="mb-3 flex items-start justify-between"><div><span class="mb-2 mr-1 inline-block rounded-full bg-[#f4ede7] px-2.5 py-1 text-[10px] font-semibold text-clay">{{ item.course_type }}</span><span class="mb-2 inline-block rounded-full bg-[#efeff7] px-2.5 py-1 text-[10px] font-semibold text-sage">{{ item.level }}</span><h3 class="font-semibold">{{ item.title }}</h3></div><span class="text-xs font-medium text-sage">{{ item.instructor_name }}</span></div>
        <p class="mb-1 flex items-center gap-1 text-xs font-medium text-ink"><UserRound :size="13" />{{ item.instructor_bio }}</p><p class="mb-3 text-xs leading-relaxed text-stone-500">{{ item.description }}</p>
        <div class="mb-4 flex gap-3 text-[11px] text-stone-500"><span class="flex items-center gap-1"><Clock3 :size="13" />{{ formatTime(item.start_time) }} – {{ formatTime(item.end_time) }}</span><span class="flex items-center gap-1"><MapPin :size="13" />{{ item.room }}</span></div>
        <div class="flex items-center justify-between border-t border-sand pt-3"><span class="flex items-center gap-1 text-xs" :class="item.booked_count >= item.capacity ? 'text-clay' : 'text-stone-500'"><Users :size="14" />{{ item.booked_count >= item.capacity ? '額滿' : `剩餘 ${item.capacity - item.booked_count} 個名額` }}</span>
          <button v-if="isBooked(item)" class="rounded-xl bg-[#eef3ee] px-4 py-2 text-xs font-semibold text-sage" disabled>已預約</button>
          <button v-else-if="isWaitlisted(item)" class="rounded-xl bg-[#f5ede9] px-4 py-2 text-xs font-semibold text-clay" disabled>已加入候補</button>
          <button v-else-if="item.booked_count >= item.capacity" class="rounded-xl border border-clay px-4 py-2 text-xs font-semibold text-clay" @click="store.joinWaitlist(item)">加入候補名單</button>
          <button v-else-if="isClosed(item)" class="rounded-xl bg-stone-300 px-4 py-2 text-xs font-semibold text-white" disabled>預約已截止</button>
          <button v-else class="rounded-xl bg-clay px-4 py-2 text-xs font-semibold text-white transition hover:bg-[#a66d61]" @click="pending = item">立即預約</button>
        </div>
        <p v-if="isClosed(item) && !isBooked(item)" class="mt-3 border-t border-sand pt-2 text-[11px] text-clay">開課前 3 小時截止預約</p>
      </article>
    </div>
    <div v-else class="rounded-3xl border border-dashed border-sand py-12 text-center text-sm text-stone-400">這天還沒有排課，換一天看看吧。</div>
    <Teleport to="body"><div v-if="pending" class="fixed inset-0 z-30 flex items-end justify-center bg-ink/30 p-4 sm:items-center"><div class="w-full max-w-[398px] rounded-[28px] bg-cream p-6 shadow-xl">
      <div class="mb-5 flex items-center justify-between"><h3 class="font-display text-xl">確認預約</h3><button class="rounded-full bg-sand p-2" @click="pending = null"><X :size="16" /></button></div><p class="mb-1 text-sm font-semibold">{{ pending.title }}</p><p class="mb-5 text-xs text-stone-500">{{ formatTime(pending.start_time) }} · {{ pending.instructor_name }} · {{ pending.room }}</p>
      <div class="mb-5 flex items-center justify-between rounded-2xl bg-[#eef3ee] p-4"><span class="text-xs text-stone-500">預約後可用堂數</span><strong class="text-xl text-sage">{{ store.availableCredits - 1 }} <small class="text-xs font-normal">堂</small></strong></div><button class="w-full rounded-2xl bg-sage py-3 text-sm font-semibold text-white" :disabled="store.loading" @click="confirmBooking">{{ store.loading ? '處理中…' : '確認預約' }}</button>
    </div></div></Teleport>
    <div v-if="store.toast" class="fixed left-1/2 top-5 z-40 w-[calc(100%-2rem)] max-w-[398px] -translate-x-1/2 rounded-2xl bg-ink px-4 py-3 text-sm text-white shadow-lg">{{ store.toast.message }}</div>
  </div>
</template>
