<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { CalendarDays, ClipboardCheck, Leaf, ShieldCheck, ShoppingBag, UserRound } from 'lucide-vue-next'

const route = useRoute()
const router = useRouter()
const navItems = [
  { to: '/', label: '課表', icon: CalendarDays },
  { to: '/my-bookings', label: '我的預約', icon: UserRound },
  { to: '/store', label: '購課', icon: ShoppingBag },
  { to: '/check-in', label: '簽到', icon: ClipboardCheck },
  { to: '/admin', label: '管理', icon: ShieldCheck },
]
const pageTitle = computed(() => route.meta.title ?? '微光空中瑜珈')
</script>

<template>
  <div class="min-h-screen bg-[#e9e8e2]">
    <div class="mx-auto flex min-h-screen w-full max-w-[430px] flex-col bg-cream shadow-soft">
      <header class="flex items-center justify-between px-5 pb-4 pt-7">
        <button class="flex items-center gap-2 text-left" @click="router.push('/')">
          <span class="grid h-9 w-9 place-items-center rounded-2xl bg-sage text-white"><Leaf :size="18" /></span>
          <span><span class="block whitespace-nowrap font-display text-[15px] font-semibold tracking-wide">宜蘭縣瑜珈學會（教育中心）</span><span class="text-[10px] tracking-[.12em] text-sage">微光空中瑜珈&nbsp;&nbsp;SHIMMER YOGA</span></span>
        </button>
        <div class="text-right"><p class="text-xs text-sage">你好，</p><p class="text-sm font-semibold">林小瑜 <span class="ml-1 inline-block h-2 w-2 rounded-full bg-emerald-400"></span></p></div>
      </header>
      <main class="flex-1 px-5 pb-24"><div class="mb-5 pt-1"><p class="text-xs font-medium tracking-[.2em] text-clay">{{ pageTitle }}</p></div><RouterView /></main>
      <nav class="safe-bottom fixed bottom-0 z-20 mx-auto flex w-full max-w-[430px] justify-around border-t border-sand bg-cream/95 px-2 pt-2 backdrop-blur">
        <RouterLink v-for="item in navItems" :key="item.to" :to="item.to" class="flex w-20 flex-col items-center gap-1 py-1 text-[11px] text-stone-400 transition" :class="{ 'font-semibold !text-sage': route.path === item.to }">
          <component :is="item.icon" :size="20" :stroke-width="route.path === item.to ? 2.3 : 1.7" /><span>{{ item.label }}</span>
        </RouterLink>
      </nav>
    </div>
  </div>
</template>
