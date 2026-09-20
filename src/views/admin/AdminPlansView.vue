<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { supabase } from '../../services/supabase'
import { useBookingStore } from '../../stores/bookingStore'
import type { PurchasePlanType } from '../../types/database'

type PlanRow = { id: string; category: PurchasePlanType; name: string; badge: string | null; note: string | null; description: string; valid_days: number; shareable: boolean; credits: number | null; unit_price: number; total_price: number; is_active: boolean; sort_order: number }
const store = useBookingStore()
const plans = ref<PlanRow[]>([])
const editing = ref<PlanRow | null>(null)
const empty = (): PlanRow => ({ id: `plan-${Date.now()}`, category: 'credits', name: '', badge: null, note: null, description: '', valid_days: 30, shareable: false, credits: 1, unit_price: 0, total_price: 0, is_active: true, sort_order: plans.value.length + 1 })
const categoryLabel = (category: PurchasePlanType) => ({ single: '單堂', credits: '計次包', stored_value: '儲值金', unlimited: '月費吃到飽' })[category]
async function load() {
  if (!supabase) return
  const { data, error } = await supabase.from('purchase_plans').select('*').order('sort_order') as unknown as { data: PlanRow[] | null; error: { message: string } | null }
  if (error) store.notify(error.message, 'error')
  else plans.value = data ?? []
}
function edit(plan?: PlanRow) { editing.value = plan ? { ...plan } : empty() }
async function save() {
  if (!supabase || !editing.value) return
  const plan = { ...editing.value, total_price: editing.value.category === 'credits' ? (editing.value.credits ?? 0) * editing.value.unit_price : editing.value.total_price }
  const { error } = await supabase.from('purchase_plans').upsert(plan as never)
  if (error) { store.notify(error.message, 'error'); return }
  store.notify('商城方案已儲存。'); editing.value = null; await load()
}
async function toggle(plan: PlanRow) {
  if (!supabase) return
  const { error } = await supabase.from('purchase_plans').update({ is_active: !plan.is_active } as never).eq('id', plan.id)
  if (error) store.notify(error.message, 'error'); else await load()
}
onMounted(() => void load())
</script>

<template>
  <div class="animate-rise">
    <div class="mb-4 flex items-center justify-between"><div><p class="text-xs tracking-[.18em] text-clay">STORE SETTINGS</p><h1 class="font-display text-2xl">購課方案管理</h1></div><button class="rounded-xl bg-sage px-3 py-2 text-xs font-semibold text-white" @click="edit()">新增方案</button></div>
    <div class="space-y-3"><article v-for="plan in plans" :key="plan.id" class="rounded-3xl border border-sand bg-white p-4"><div class="flex items-start justify-between"><div><h2 class="font-semibold">{{ plan.name }}</h2><p class="mt-1 text-xs text-stone-500">{{ plan.description }}</p><p class="mt-2 text-[11px] text-stone-400">{{ categoryLabel(plan.category) }} · {{ plan.credits ?? '不限' }} 堂 · {{ plan.valid_days }} 天 · {{ plan.shareable ? '可共享' : '限本人' }}</p></div><strong class="text-sage">NT$ {{ plan.total_price }}</strong></div><div class="mt-3 flex gap-2 border-t border-sand pt-3"><button class="flex-1 rounded-xl bg-[#efeff7] py-2 text-xs text-sage" @click="edit(plan)">編輯</button><button class="flex-1 rounded-xl bg-[#f5ede9] py-2 text-xs text-clay" @click="toggle(plan)">{{ plan.is_active ? '停用' : '啟用' }}</button></div></article></div>
    <div v-if="editing" class="fixed inset-0 z-40 flex items-end justify-center bg-ink/30 p-4 sm:items-center"><section class="max-h-[90vh] w-full max-w-[398px] overflow-y-auto rounded-[28px] bg-cream p-5 shadow-xl"><h2 class="mb-4 font-display text-xl">設定購課方案</h2><div class="space-y-3"><input v-model="editing.id" placeholder="方案 ID" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><input v-model="editing.name" placeholder="方案名稱／課程主題" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><label class="block text-xs text-stone-500">課程類別<select v-model="editing.category" class="mt-1 w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"><option value="single">單堂</option><option value="credits">計次包</option><option value="stored_value">儲值金</option><option value="unlimited">月費吃到飽</option></select></label><label class="block text-xs text-stone-500">課程註記<select v-model="editing.badge" class="mt-1 w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"><option :value="null">不設定</option><option value="初次體驗">初次體驗</option><option value="最愛歡迎">最愛歡迎</option></select></label><textarea v-model="editing.description" placeholder="課程說明" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"></textarea><div class="grid grid-cols-2 gap-2"><label class="text-xs text-stone-500">有效天數<input v-model.number="editing.valid_days" type="number" min="1" class="mt-1 w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /></label><label class="text-xs text-stone-500">購買堂數<input v-model.number="editing.credits" type="number" min="0" class="mt-1 w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /></label></div><div class="grid grid-cols-2 gap-2"><label class="text-xs text-stone-500">單堂金額<input v-model.number="editing.unit_price" type="number" min="0" class="mt-1 w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /></label><label class="text-xs text-stone-500">總價<input v-model.number="editing.total_price" type="number" min="0" class="mt-1 w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /></label></div><p class="rounded-xl bg-[#efeff7] p-3 text-xs text-sage">目前設定：{{ editing.credits ?? 0 }} 堂 × NT$ {{ editing.unit_price }} = NT$ {{ editing.category === 'credits' ? (editing.credits ?? 0) * editing.unit_price : editing.total_price }}</p><label class="flex items-center gap-2 rounded-xl bg-white p-3 text-sm"><input v-model="editing.shareable" type="checkbox" /> 可共享給親友</label><label class="flex items-center gap-2 rounded-xl bg-white p-3 text-sm"><input v-model="editing.is_active" type="checkbox" /> 上架顯示</label></div><div class="mt-5 flex gap-2"><button class="flex-1 rounded-xl border border-sand py-3 text-sm" @click="editing = null">取消</button><button class="flex-1 rounded-xl bg-sage py-3 text-sm font-semibold text-white" @click="save">儲存方案</button></div></section></div>
    <div v-if="store.toast" class="fixed left-1/2 top-5 z-[60] w-[calc(100%-2rem)] max-w-[398px] -translate-x-1/2 rounded-2xl bg-ink px-4 py-3 text-sm text-white shadow-lg">{{ store.toast.message }}</div>
  </div>
</template>
