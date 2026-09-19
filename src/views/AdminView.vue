<script setup lang="ts">
import { ref } from 'vue'
import { CalendarPlus, ChevronRight, Minus, Plus, Search, Settings2, UserRound, ReceiptText } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
import { useBookingStore } from '../stores/bookingStore'
const store = useBookingStore()
const router = useRouter()
const search = ref('')
const activeTab = ref<'students' | 'classes'>('students')
const students = ref([{ name: '林小瑜', phone: '0912 345 678', credits: 8 }, { name: '陳怡君', phone: '0988 123 456', credits: 14 }, { name: '王品涵', phone: '0922 888 111', credits: 3 }])
const adjust = (index: number, amount: number) => { students.value[index].credits = Math.max(0, students.value[index].credits + amount); store.notify(amount > 0 ? '已贈送 1 堂課給學員。' : '已扣除 1 堂課。') }
</script>

<template>
  <div class="animate-rise">
    <section class="mb-5 flex items-center justify-between rounded-3xl bg-ink p-5 text-white"><div><p class="mb-1 text-[11px] tracking-[.18em] text-white/60">STUDIO OVERVIEW</p><p class="font-display text-xl">今天，教室平安運轉。</p></div><Settings2 :size="22" class="text-[#d9c8a9]" /></section>
    <div class="mb-5 grid grid-cols-2 gap-1 rounded-2xl bg-sand p-1"><button class="rounded-xl py-2.5 text-xs transition" :class="activeTab === 'students' ? 'bg-white font-semibold text-sage shadow-sm' : 'text-stone-500'" @click="activeTab = 'students'"><UserRound :size="15" class="mr-1 inline" />學員管理</button><button class="rounded-xl py-2.5 text-xs transition" :class="activeTab === 'classes' ? 'bg-white font-semibold text-sage shadow-sm' : 'text-stone-500'" @click="activeTab = 'classes'"><CalendarPlus :size="15" class="mr-1 inline" />排課管理</button></div>
    <div class="mb-5 flex gap-2"><button class="flex-1 rounded-xl border border-sand bg-white py-2.5 text-xs text-sage" @click="router.push('/admin/members')"><UserRound :size="14" class="mr-1 inline" />角色與會員設定</button><button class="flex-1 rounded-xl border border-sand bg-white py-2.5 text-xs text-sage" @click="router.push('/admin/orders')"><ReceiptText :size="14" class="mr-1 inline" />購課核帳</button></div>
    <template v-if="activeTab === 'students'"><div class="relative mb-4"><Search :size="16" class="absolute left-3 top-3 text-stone-400" /><input v-model="search" placeholder="搜尋學員姓名或電話" class="w-full rounded-2xl border border-sand bg-white py-2.5 pl-9 pr-3 text-sm outline-none focus:border-sage" /></div><div class="space-y-3"><article v-for="(student, index) in students.filter(item => !search || item.name.includes(search) || item.phone.includes(search))" :key="student.name" class="rounded-3xl border border-sand bg-white p-4"><div class="flex items-center gap-3"><span class="grid h-10 w-10 place-items-center rounded-full bg-[#e3ece3] font-semibold text-sage">{{ student.name.slice(0, 1) }}</span><div class="flex-1"><p class="text-sm font-semibold">{{ student.name }}</p><p class="mt-1 text-[11px] text-stone-400">{{ student.phone }}</p></div><div class="text-right"><strong class="text-lg text-sage">{{ student.credits }}</strong><p class="text-[10px] text-stone-400">剩餘堂數</p></div></div><div class="mt-3 flex gap-2 border-t border-sand pt-3"><button class="flex flex-1 items-center justify-center gap-1 rounded-xl bg-[#eef3ee] py-2 text-xs font-semibold text-sage" @click="adjust(index, 1)"><Plus :size="14" />贈送一堂</button><button class="flex flex-1 items-center justify-center gap-1 rounded-xl bg-[#f8eeeb] py-2 text-xs font-semibold text-clay" @click="adjust(index, -1)"><Minus :size="14" />扣除一堂</button></div></article></div></template>
    <template v-else><div class="mb-3 flex items-center justify-between"><h2 class="font-display text-xl">課程列表</h2><button class="rounded-xl bg-sage px-3 py-2 text-xs font-semibold text-white" @click="store.notify('新增課程表單即將開放。')"><Plus :size="14" class="mr-1 inline" />新增課程</button></div><div class="space-y-3"><article v-for="item in store.classes" :key="item.id" class="flex items-center gap-3 rounded-3xl border border-sand bg-white p-4"><div class="grid h-10 w-10 place-items-center rounded-2xl bg-[#f4ede7] text-clay"><CalendarPlus :size="19" /></div><div class="flex-1"><p class="text-sm font-semibold">{{ item.title }}</p><p class="mt-1 text-[11px] text-stone-400">{{ item.instructor_name }} · {{ item.capacity }} 人上限</p></div><ChevronRight :size="17" class="text-stone-300" /></article></div></template>
    <div v-if="store.toast" class="fixed left-1/2 top-5 z-40 w-[calc(100%-2rem)] max-w-[398px] -translate-x-1/2 rounded-2xl bg-ink px-4 py-3 text-sm text-white shadow-lg">{{ store.toast.message }}</div>
  </div>
</template>
