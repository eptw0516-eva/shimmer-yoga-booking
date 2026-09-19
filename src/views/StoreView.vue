<script setup lang="ts">
import { ref } from 'vue'
import { ArrowLeft, Banknote, Check, ChevronRight, Landmark, ShoppingBag } from 'lucide-vue-next'
import { purchasePlans, useBookingStore } from '../stores/bookingStore'
import type { PaymentMethod, PurchasePlan } from '../types/database'

const store = useBookingStore()
const selected = ref<PurchasePlan | null>(null)
const paymentMethod = ref<PaymentMethod>('bank_transfer')
const transferLastFive = ref('')
const submitted = ref(false)
const formatPrice = (value: number) => new Intl.NumberFormat('zh-TW').format(value)

async function submit() {
  if (!selected.value) return
  const success = await store.submitPurchase(selected.value, paymentMethod.value, paymentMethod.value === 'bank_transfer' ? transferLastFive.value : null)
  if (success) { submitted.value = true; selected.value = null; transferLastFive.value = '' }
}
</script>

<template>
  <div class="animate-rise">
    <section class="mb-5 rounded-[28px] bg-sage p-5 text-white">
      <div class="mb-3 flex items-center gap-2"><ShoppingBag :size="20" class="text-rose" /><span class="text-xs tracking-[.12em] text-white/70">SHIMMER YOGA STORE</span></div>
      <h1 class="font-display text-2xl">選一份適合你的練習</h1>
      <p class="mt-2 text-xs leading-relaxed text-white/70">沒有第三方金流，申請後由微光空中瑜珈人工核款。</p>
    </section>
    <div v-if="submitted" class="mb-5 flex items-start gap-3 rounded-2xl bg-[#edf3ed] p-4 text-sm text-sage"><Check :size="18" class="mt-0.5 shrink-0" /><span>購課申請已送出，管理員確認入帳後，票券會出現在「我的堂數」。</span></div>
    <div class="space-y-3">
      <article v-for="plan in purchasePlans" :key="plan.id" class="rounded-3xl border border-sand bg-white p-4 shadow-sm">
        <div class="flex items-start gap-3"><span class="grid h-11 w-11 shrink-0 place-items-center rounded-2xl bg-[#f5ede9] text-clay"><Banknote :size="20" /></span><div class="flex-1"><div class="flex items-center gap-2"><h2 class="font-semibold">{{ plan.name }}</h2><span v-if="plan.badge" class="rounded-full bg-[#efeff7] px-2 py-0.5 text-[10px] text-sage">{{ plan.badge }}</span></div><p class="mt-1 text-xs leading-relaxed text-stone-500">{{ plan.description }}</p><p class="mt-2 text-xs text-stone-400">有效 {{ plan.validDays }} 天 · {{ plan.shareable ? '可共享給親友' : '限本人使用' }}</p></div></div>
        <div class="mt-4 flex items-center justify-between border-t border-sand pt-3"><strong class="text-lg text-sage">NT$ {{ formatPrice(plan.price) }}</strong><button class="rounded-xl bg-clay px-4 py-2 text-xs font-semibold text-white" @click="selected = plan">申請購買 <ChevronRight :size="14" class="ml-1 inline" /></button></div>
      </article>
    </div>
    <div v-if="selected" class="fixed inset-0 z-30 flex items-end justify-center bg-ink/30 p-4 sm:items-center">
      <section class="w-full max-w-[398px] rounded-[28px] bg-cream p-5 shadow-xl">
        <div class="mb-4 flex items-center justify-between"><div><p class="text-xs text-clay">PURCHASE REQUEST</p><h2 class="font-display text-xl">{{ selected.name }}</h2></div><button class="text-stone-400" @click="selected = null"><ArrowLeft :size="19" /></button></div>
        <div class="mb-4 rounded-2xl bg-white p-4 text-sm"><div class="flex justify-between"><span class="text-stone-500">應付金額</span><strong class="text-sage">NT$ {{ formatPrice(selected.price) }}</strong></div><p class="mt-2 text-xs text-stone-400">請選擇付款方式，送出後等待管理員核款。</p></div>
        <div class="mb-4 grid grid-cols-2 gap-2"><button class="rounded-xl border px-3 py-3 text-xs" :class="paymentMethod === 'bank_transfer' ? 'border-sage bg-[#efeff7] text-sage' : 'border-sand bg-white text-stone-500'" @click="paymentMethod = 'bank_transfer'"><Landmark :size="16" class="mb-1 inline" /><br />銀行匯款</button><button class="rounded-xl border px-3 py-3 text-xs" :class="paymentMethod === 'cash' ? 'border-sage bg-[#efeff7] text-sage' : 'border-sand bg-white text-stone-500'" @click="paymentMethod = 'cash'"><Banknote :size="16" class="mb-1 inline" /><br />教室現金付款</button></div>
        <div v-if="paymentMethod === 'bank_transfer'" class="mb-4 rounded-2xl bg-[#f5ede9] p-4 text-xs"><p class="font-semibold text-ink">匯款資訊</p><p class="mt-2 leading-relaxed text-stone-600">宜蘭縣瑜珈學會（教育中心）<br />請洽官方 LINE 取得最新帳號資訊：<a class="text-sage underline" href="https://lin.ee/1i8HE5u" target="_blank" rel="noreferrer">微光空中瑜珈 LINE</a></p><input v-model="transferLastFive" inputmode="numeric" maxlength="5" placeholder="請輸入匯款帳號末五碼" class="mt-3 w-full rounded-xl border border-sand bg-white px-3 py-2.5 outline-none focus:border-sage" /></div>
        <button class="w-full rounded-2xl bg-sage py-3 text-sm font-semibold text-white" @click="submit">送出購課申請</button>
      </section>
    </div>
    <div v-if="store.toast" class="fixed left-1/2 top-5 z-40 w-[calc(100%-2rem)] max-w-[398px] -translate-x-1/2 rounded-2xl bg-ink px-4 py-3 text-sm text-white shadow-lg">{{ store.toast.message }}</div>
  </div>
</template>
