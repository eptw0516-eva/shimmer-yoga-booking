<script setup lang="ts">
import { onMounted } from 'vue'
import { Check, Clock3, Landmark, ReceiptText, UserRound } from 'lucide-vue-next'
import { useBookingStore } from '../stores/bookingStore'
const store = useBookingStore()
onMounted(() => void store.loadUserData())
const formatDate = (value: string) => new Intl.DateTimeFormat('zh-TW', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' }).format(new Date(value))
const formatPrice = (value: number) => new Intl.NumberFormat('zh-TW').format(value)
</script>

<template>
  <div class="animate-rise">
    <section class="mb-5 flex items-center justify-between rounded-3xl bg-ink p-5 text-white"><div><p class="mb-1 text-[11px] tracking-[.18em] text-white/60">PAYMENT REVIEW</p><h1 class="font-display text-xl">購課申請核帳</h1></div><ReceiptText :size="24" class="text-rose" /></section>
    <div class="mb-4 flex items-center justify-between"><h2 class="font-display text-xl">待審核訂單</h2><span class="rounded-full bg-[#f5ede9] px-3 py-1 text-xs text-clay">{{ store.pendingOrders.length }} 筆</span></div>
    <div v-if="store.pendingOrders.length" class="space-y-3">
      <article v-for="order in store.pendingOrders" :key="order.id" class="rounded-3xl border border-sand bg-white p-4">
        <div class="flex items-start justify-between"><div><span class="mb-2 inline-flex items-center gap-1 rounded-full bg-[#fff4dc] px-2 py-1 text-[10px] text-[#9c7428]"><Clock3 :size="12" />待管理員核款</span><h3 class="font-semibold">{{ order.plan_name }}</h3></div><strong class="text-sage">NT$ {{ formatPrice(order.amount) }}</strong></div>
        <div class="mt-3 space-y-1 text-xs text-stone-500"><p><UserRound :size="13" class="mr-1 inline" />學員：{{ order.user_id === 'demo-user' ? '林小瑜' : order.user_id }}</p><p><Landmark :size="13" class="mr-1 inline" />付款：{{ order.payment_method === 'cash' ? '教室現金付款' : `銀行匯款・末五碼 ${order.transfer_last_five}` }}</p><p>申請時間：{{ formatDate(order.created_at) }}</p></div>
        <button class="mt-4 flex w-full items-center justify-center gap-1 rounded-xl bg-sage py-2.5 text-xs font-semibold text-white" @click="store.approveOrder(order)"><Check :size="15" />確認入帳並建立票券</button>
      </article>
    </div>
    <div v-else class="rounded-3xl border border-dashed border-sand py-12 text-center text-sm text-stone-400">目前沒有待審核訂單。</div>
    <div v-if="store.toast" class="fixed left-1/2 top-5 z-40 w-[calc(100%-2rem)] max-w-[398px] -translate-x-1/2 rounded-2xl bg-ink px-4 py-3 text-sm text-white shadow-lg">{{ store.toast.message }}</div>
  </div>
</template>
