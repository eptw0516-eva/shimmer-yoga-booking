<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { Mail, LockKeyhole, UserRound, CalendarDays, Phone, Link2 } from 'lucide-vue-next'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/authStore'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()
const register = computed(() => route.path === '/register')
const email = ref('')
const password = ref('')
const fullName = ref('')
const birthDate = ref('')
const phone = ref('')
const lineUserId = ref('')
const error = ref('')
const message = ref('')

async function submit() {
  error.value = ''; message.value = ''
  const result = register.value
    ? await auth.signUp({ email: email.value, password: password.value, fullName: fullName.value, birthDate: birthDate.value, phone: phone.value, lineUserId: lineUserId.value })
    : await auth.signIn(email.value, password.value)
  if (result.error) { error.value = result.error.message; return }
  if (register.value) {
    if (auth.isAuthenticated) await router.push(typeof route.query.redirect === 'string' ? route.query.redirect : '/')
    else message.value = '註冊成功！請確認 Supabase 已關閉 Email 驗證後再登入。'
  } else await router.push(typeof route.query.redirect === 'string' ? route.query.redirect : '/')
}
async function google() {
  const result = await auth.signInWithGoogle()
  if (result.error) error.value = result.error.message
}
onMounted(() => { if (auth.isAuthenticated) void router.push('/') })
</script>

<template>
  <div class="mx-auto flex min-h-[70vh] max-w-[390px] items-center">
    <section class="w-full rounded-[28px] border border-sand bg-white p-6 shadow-sm">
      <p class="mb-1 text-xs tracking-[.18em] text-clay">SHIMMER YOGA MEMBER</p>
      <h1 class="mb-2 font-display text-2xl">{{ register ? '建立學員帳號' : '歡迎回到微光' }}</h1>
      <p class="mb-5 text-xs leading-relaxed text-stone-500">{{ register ? '填寫基本資料，之後可使用 Email 或 Google 快速登入。' : '登入後即可預約、簽到與管理您的票券。' }}</p>
      <div v-if="register" class="space-y-3">
        <label class="relative block"><UserRound :size="16" class="absolute left-3 top-3 text-stone-400" /><input v-model="fullName" required placeholder="姓名" class="w-full rounded-xl border border-sand py-2.5 pl-9 pr-3 text-sm" /></label>
        <label class="relative block"><CalendarDays :size="16" class="absolute left-3 top-3 text-stone-400" /><input v-model="birthDate" required type="date" class="w-full rounded-xl border border-sand py-2.5 pl-9 pr-3 text-sm" /></label>
        <label class="relative block"><Phone :size="16" class="absolute left-3 top-3 text-stone-400" /><input v-model="phone" required placeholder="手機號碼" class="w-full rounded-xl border border-sand py-2.5 pl-9 pr-3 text-sm" /></label>
        <label class="relative block"><Link2 :size="16" class="absolute left-3 top-3 text-stone-400" /><input v-model="lineUserId" placeholder="LINE ID（選填）" class="w-full rounded-xl border border-sand py-2.5 pl-9 pr-3 text-sm" /></label>
      </div>
      <div class="mt-3 space-y-3"><label class="relative block"><Mail :size="16" class="absolute left-3 top-3 text-stone-400" /><input v-model="email" required type="email" placeholder="Email" class="w-full rounded-xl border border-sand py-2.5 pl-9 pr-3 text-sm" /></label><label class="relative block"><LockKeyhole :size="16" class="absolute left-3 top-3 text-stone-400" /><input v-model="password" required type="password" minlength="6" placeholder="密碼（至少 6 碼）" class="w-full rounded-xl border border-sand py-2.5 pl-9 pr-3 text-sm" /></label></div>
      <p v-if="error" class="mt-3 rounded-xl bg-[#f8ece8] px-3 py-2 text-xs text-clay">{{ error }}</p><p v-if="message" class="mt-3 rounded-xl bg-[#e8f3e9] px-3 py-2 text-xs text-sage">{{ message }}</p>
      <button class="mt-5 w-full rounded-2xl bg-sage py-3 text-sm font-semibold text-white" :disabled="auth.loading" @click="submit">{{ auth.loading ? '處理中…' : register ? '註冊帳號' : '登入' }}</button>
      <button class="mt-2 w-full rounded-2xl border border-sand bg-white py-3 text-sm font-semibold text-sage" @click="google">使用 Google 快速登入</button>
      <RouterLink :to="register ? '/login' : '/register'" class="mt-4 block text-center text-xs text-stone-500 underline">{{ register ? '已有帳號？前往登入' : '還沒有帳號？立即註冊' }}</RouterLink>
    </section>
  </div>
</template>
