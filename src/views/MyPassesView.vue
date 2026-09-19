<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { ArrowUpRight, CalendarDays, ChevronRight, Clock3, Ticket, WalletCards, Users, X } from 'lucide-vue-next'
import { useBookingStore } from '../stores/bookingStore'
const store = useBookingStore()
onMounted(() => void store.loadUserData())
const formatDate = (value: string) => new Intl.DateTimeFormat('zh-TW', { month: 'numeric', day: 'numeric', weekday: 'short' }).format(new Date(value))
const formatTime = (value: string) => new Intl.DateTimeFormat('zh-TW', { hour: '2-digit', minute: '2-digit', hour12: false }).format(new Date(value))
const upcoming = computed(() => store.activeBookings.filter((booking) => booking.class))
const sharingPackage = ref<import('../types/database').UserPackage | null>(null)
const friendPhone = ref('')
function addFriend() {
  if (sharingPackage.value && store.sharePackage(sharingPackage.value.id, friendPhone.value)) {
    friendPhone.value = ''
    sharingPackage.value = null
  }
}
async function cancel(booking: Parameters<typeof store.cancelBooking>[0]) { if (window.confirm('確定要取消這堂課嗎？堂數會退回。')) await store.cancelBooking(booking) }
</script>

<template>
  <div class="animate-rise space-y-5">
    <section class="relative overflow-hidden rounded-[28px] bg-[#d9c8a9] p-5 text-ink"><WalletCards class="absolute -right-2 -top-2 h-28 w-28 rotate-12 text-white/25" /><p class="relative mb-1 text-xs tracking-[.16em] text-ink/60">ACTIVE PACKAGE</p><p class="relative font-display text-xl">晨光 20 堂方案</p><div class="relative mt-5 flex items-end justify-between"><div><strong class="font-display text-5xl">{{ store.availableCredits }}</strong><span class="ml-2 text-sm">堂可用</span></div><span class="rounded-full bg-white/50 px-3 py-1 text-[11px]">有效至 12/31/2026</span></div></section>
    <section><div class="mb-3 flex items-center justify-between"><h2 class="font-display text-xl">即將到來</h2><span class="rounded-full bg-[#eef3ee] px-2.5 py-1 text-[11px] text-sage">{{ upcoming.length }} 堂</span></div>
      <div v-if="upcoming.length" class="space-y-3"><article v-for="booking in upcoming" :key="booking.id" class="rounded-3xl border border-sand bg-white p-4"><div class="flex items-start justify-between"><div><p class="mb-1 text-[11px] text-clay">{{ formatDate(booking.class!.start_time) }}</p><h3 class="font-semibold">{{ booking.class!.title }}</h3></div><CalendarDays :size="19" class="text-sage" /></div><div class="mt-3 flex items-center gap-3 text-[11px] text-stone-500"><span class="flex items-center gap-1"><Clock3 :size="13" />{{ formatTime(booking.class!.start_time) }}</span><span>{{ booking.class!.instructor_name }} · {{ booking.class!.room }}</span></div><button class="mt-4 flex w-full items-center justify-center gap-1 border-t border-sand pt-3 text-xs text-stone-400" @click="cancel(booking)">取消預約 <ChevronRight :size="13" /></button></article></div>
      <div v-else class="rounded-3xl bg-white py-8 text-center text-sm text-stone-400">目前沒有即將到來的課程。</div>
    </section>
    <section><div class="mb-3 flex items-center justify-between"><h2 class="font-display text-xl">我的票券</h2><button class="flex items-center gap-1 text-xs text-sage">查看全部 <ArrowUpRight :size="14" /></button></div><div class="space-y-3"><article v-for="item in store.packages" :key="item.id" class="rounded-3xl border border-sand bg-white p-4"><div class="flex items-center gap-3"><span class="grid h-10 w-10 place-items-center rounded-2xl bg-[#f4ede7] text-clay"><Ticket :size="19" /></span><div class="flex-1"><p class="text-sm font-semibold">{{ item.plan_name ?? '瑜珈堂數方案' }}</p><p class="mt-1 text-[11px] text-stone-400">有效至 {{ item.valid_until }}</p></div><span class="text-xs font-medium text-sage">{{ item.status === 'active' ? '使用中' : item.status }}</span></div><div class="mt-4 flex items-end justify-between"><p class="text-sm text-stone-500"><strong class="text-2xl text-sage">{{ item.remaining_credits }}</strong> / {{ item.total_credits || '不限' }} 堂</p><button v-if="item.shared_with_phones !== undefined" class="flex items-center gap-1 rounded-xl bg-[#efeff7] px-3 py-2 text-xs font-semibold text-sage" @click="sharingPackage = item"><Users :size="14" />共享設定</button></div><div v-if="item.shared_with_phones?.length" class="mt-3 border-t border-sand pt-3 text-[11px] text-stone-400">共享親友：{{ item.shared_with_phones.join('、') }}</div></article></div></section>
    <div v-if="sharingPackage" class="fixed inset-0 z-30 flex items-end justify-center bg-ink/30 p-4 sm:items-center"><section class="w-full max-w-[398px] rounded-[28px] bg-cream p-5 shadow-xl"><div class="mb-4 flex items-center justify-between"><div><p class="text-xs text-clay">SHARED PACKAGE</p><h2 class="font-display text-xl">共享給親友</h2></div><button class="text-stone-400" @click="sharingPackage = null"><X :size="19" /></button></div><p class="mb-4 text-xs leading-relaxed text-stone-500">輸入親友手機號碼，對方登入後即可共用此堂數包預約課程。</p><input v-model="friendPhone" inputmode="tel" placeholder="例如 0912345678" class="mb-4 w-full rounded-xl border border-sand bg-white px-3 py-3 text-sm outline-none focus:border-sage" /><button class="w-full rounded-2xl bg-sage py-3 text-sm font-semibold text-white" @click="addFriend">綁定親友</button></section></div>
    <div v-if="store.toast" class="fixed left-1/2 top-5 z-40 w-[calc(100%-2rem)] max-w-[398px] -translate-x-1/2 rounded-2xl bg-ink px-4 py-3 text-sm text-white shadow-lg">{{ store.toast.message }}</div>
  </div>
</template>
