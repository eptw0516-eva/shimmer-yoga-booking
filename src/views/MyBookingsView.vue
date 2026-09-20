<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { CalendarDays, Clock3, MapPin } from 'lucide-vue-next'
import { useBookingStore } from '../stores/bookingStore'
import type { Booking } from '../types/database'
import { formatTaiwanDateTime } from '../utils/date'

const store = useBookingStore()
onMounted(() => void store.loadUserData())
const tab = ref<'upcoming' | 'past'>('upcoming')
const now = () => Date.now()
const upcoming = computed(() => store.bookings.filter((item) => item.class && ['confirmed'].includes(item.status) && new Date(item.class.start_time).getTime() >= now()))
const past = computed(() => store.bookings.filter((item) => !upcoming.value.includes(item)))
const list = computed(() => tab.value === 'upcoming' ? upcoming.value : past.value)
const hoursLeft = (booking: Booking) => Math.max(0, (new Date(booking.class?.start_time ?? 0).getTime() - now()) / 3600000)
const statusText = (booking: Booking) => ({ confirmed: '已預約', attended: '已簽到', cancelled: '已取消', late_cancelled: '逾時請假（已扣點）', no_show: '逾期未到' }[booking.status])

async function cancel(booking: Booking) {
  const remaining = hoursLeft(booking)
  if (remaining >= 0.5) {
    if (window.confirm(`確定取消此預約？距開課尚有 ${remaining.toFixed(1)} 小時，取消後堂數將立即全額退還回您的點數包。`)) await store.cancelBooking(booking)
  } else if (window.confirm('此操作僅通知授課老師您無法出席，但該堂課點數將正常扣除，無法退還。確定要逾期請假嗎？')) {
    await store.cancelBooking(booking, true)
  }
}
</script>

<template>
  <div class="animate-rise">
    <div class="mb-5 flex rounded-2xl bg-sand p-1"><button class="flex-1 rounded-xl py-2.5 text-xs" :class="tab === 'upcoming' ? 'bg-white font-semibold text-sage shadow-sm' : 'text-stone-500'" @click="tab = 'upcoming'">即將到來 Upcoming</button><button class="flex-1 rounded-xl py-2.5 text-xs" :class="tab === 'past' ? 'bg-white font-semibold text-sage shadow-sm' : 'text-stone-500'" @click="tab = 'past'">歷史紀錄 Past</button></div>
    <div v-if="list.length" class="space-y-3">
      <article v-for="booking in list" :key="booking.id" class="rounded-3xl border border-sand bg-white p-4">
        <div class="flex items-start justify-between"><div><p class="mb-1 text-[11px] text-clay">{{ formatTaiwanDateTime(booking.class!.start_time) }}</p><h2 class="font-semibold">{{ booking.class!.title }}</h2></div><span class="rounded-full bg-[#efeff7] px-2.5 py-1 text-[10px] text-sage">{{ statusText(booking) }}</span></div>
        <div class="mt-3 grid grid-cols-2 gap-2 text-[11px] text-stone-500"><span><Clock3 :size="13" class="mr-1 inline" />{{ formatTaiwanDateTime(booking.class!.end_time) }} 結束</span><span><MapPin :size="13" class="mr-1 inline" />{{ booking.class!.room }}</span><span><CalendarDays :size="13" class="mr-1 inline" />{{ booking.class!.instructor_name }}</span></div>
        <template v-if="tab === 'upcoming' && booking.status === 'confirmed'"><p v-if="hoursLeft(booking) < 0.5" class="mt-3 rounded-xl bg-[#f8ece8] px-3 py-2 text-[11px] leading-relaxed text-clay">已逾可取消時限（課前 30 分鐘內）。未提前 30 分鐘取消或未出席，將扣除該堂課點數，不予歸還。</p><button class="mt-3 w-full rounded-xl border border-sand py-2.5 text-xs" :class="hoursLeft(booking) < 0.5 ? 'border-clay text-clay' : 'text-stone-500'" @click="cancel(booking)">{{ hoursLeft(booking) < 0.5 ? '逾期請假（不退點）' : '取消預約（全額退點）' }}</button></template>
      </article>
    </div>
    <div v-else class="rounded-3xl border border-dashed border-sand py-12 text-center text-sm text-stone-400">{{ tab === 'upcoming' ? '目前沒有即將到來的預約。' : '目前沒有歷史紀錄。' }}</div>
    <div v-if="store.toast" class="fixed left-1/2 top-5 z-[60] w-[calc(100%-2rem)] max-w-[398px] -translate-x-1/2 rounded-2xl bg-ink px-4 py-3 text-sm text-white shadow-lg">{{ store.toast.message }}</div>
  </div>
</template>
