<script setup lang="ts">
import { computed, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { CalendarDays, ClipboardCheck, Leaf, ShieldCheck, ShoppingBag, UserRound, WalletCards } from 'lucide-vue-next'
import { useAuthStore } from './stores/authStore'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const showPasswordForm = ref(false)
const currentPassword = ref('')
const confirmPassword = ref('')
const passwordError = ref('')
const passwordMessage = ref('')
const updatingPassword = ref(false)
const navItems = [
  { to: '/', label: '課表', icon: CalendarDays },
  { to: '/my-bookings', label: '我的預約', icon: UserRound },
  { to: '/store', label: '購課', icon: ShoppingBag },
  { to: '/my-passes', label: '我的票券', icon: WalletCards },
  { to: '/check-in', label: '簽到', icon: ClipboardCheck },
  { to: '/admin', label: '管理', icon: ShieldCheck },
]
const visibleNavItems = computed(() => navItems.filter((item) => {
  if (item.to === '/') return true
  if (!auth.isAuthenticated) return false
  if (item.to === '/admin') return auth.isAdmin
  return true
}))
const pageTitle = computed(() => route.meta.title ?? '微光空中瑜珈')
async function signOut() {
  await auth.signOut()
  await router.replace('/login')
}
async function changePassword() {
  passwordError.value = ''
  passwordMessage.value = ''
  if (currentPassword.value.length < 6 || confirmPassword.value.length < 6) {
    passwordError.value = '密碼至少需要 6 碼。'
    return
  }
  if (currentPassword.value !== confirmPassword.value) {
    passwordError.value = '兩次輸入的新密碼不一致。'
    return
  }
  updatingPassword.value = true
  const result = await auth.updatePassword(currentPassword.value)
  updatingPassword.value = false
  if (result.error) {
    passwordError.value = result.error.message
    return
  }
  passwordMessage.value = '密碼已更新。'
  currentPassword.value = ''
  confirmPassword.value = ''
}
</script>

<template>
  <div class="min-h-screen bg-[#e9e8e2]">
    <div class="mx-auto flex min-h-screen w-full max-w-[430px] flex-col bg-cream shadow-soft">
      <header class="flex items-center justify-between px-5 pb-4 pt-7">
        <button class="flex items-center gap-2 text-left" @click="router.push('/')">
          <span class="grid h-9 w-9 place-items-center rounded-2xl bg-sage text-white"><Leaf :size="18" /></span>
          <span><span class="block whitespace-nowrap font-display text-[15px] font-semibold tracking-wide">宜蘭縣瑜珈學會（教育中心）</span><span class="text-[10px] tracking-[.12em] text-sage">微光空中瑜珈&nbsp;&nbsp;SHIMMER YOGA</span></span>
        </button>
        <div v-if="auth.isAuthenticated || !auth.initialized" class="text-right"><p class="text-xs text-sage">你好，</p><p class="text-sm font-semibold">{{ auth.profile?.full_name ?? '學員' }} <span class="ml-1 inline-block h-2 w-2 rounded-full bg-emerald-400"></span></p><div v-if="auth.isAuthenticated" class="mt-1 flex justify-end gap-2 text-[11px] text-stone-500"><button class="underline" @click="showPasswordForm = true">修改密碼</button><button class="underline" @click="signOut">登出</button></div></div>
        <RouterLink v-else to="/login" class="rounded-xl bg-sage px-3 py-2 text-xs font-semibold text-white">登入</RouterLink>
      </header>
      <main class="flex-1 px-5 pb-24"><div class="mb-5 pt-1"><p class="text-xs font-medium tracking-[.2em] text-clay">{{ pageTitle }}</p></div><RouterView /></main>
      <nav class="safe-bottom fixed bottom-0 z-20 mx-auto flex w-full max-w-[430px] justify-around border-t border-sand bg-cream/95 px-2 pt-2 backdrop-blur">
        <RouterLink v-for="item in visibleNavItems" :key="item.to" :to="item.to" class="flex w-20 flex-col items-center gap-1 py-1 text-[11px] text-stone-400 transition" :class="{ 'font-semibold !text-sage': route.path === item.to }">
          <component :is="item.icon" :size="20" :stroke-width="route.path === item.to ? 2.3 : 1.7" /><span>{{ item.label }}</span>
        </RouterLink>
      </nav>
      <div v-if="showPasswordForm" class="fixed inset-0 z-40 flex items-center justify-center bg-ink/40 p-4">
        <section class="w-full max-w-[430px] rounded-[28px] bg-cream p-6 shadow-2xl">
          <h2 class="font-display text-xl">修改我的密碼</h2>
          <p class="mt-2 text-sm text-stone-500">輸入新密碼後即可用新密碼登入。</p>
          <div class="mt-5 space-y-3">
            <input v-model="currentPassword" type="password" minlength="6" placeholder="新密碼（至少 6 碼）" class="w-full rounded-xl border border-sand bg-white px-4 py-3" />
            <input v-model="confirmPassword" type="password" minlength="6" placeholder="再次輸入新密碼" class="w-full rounded-xl border border-sand bg-white px-4 py-3" />
          </div>
          <p v-if="passwordError" class="mt-3 rounded-xl bg-[#f8ece8] px-3 py-2 text-sm text-clay">{{ passwordError }}</p>
          <p v-if="passwordMessage" class="mt-3 rounded-xl bg-[#e8f3e9] px-3 py-2 text-sm text-sage">{{ passwordMessage }}</p>
          <div class="mt-5 flex gap-2"><button class="flex-1 rounded-xl border border-sand py-3 text-sm" @click="showPasswordForm = false">關閉</button><button class="flex-1 rounded-xl bg-sage py-3 text-sm font-semibold text-white disabled:opacity-50" :disabled="updatingPassword" @click="changePassword">{{ updatingPassword ? '更新中…' : '更新密碼' }}</button></div>
        </section>
      </div>
    </div>
  </div>
</template>
