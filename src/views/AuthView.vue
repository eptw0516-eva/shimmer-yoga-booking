<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { Mail, LockKeyhole } from 'lucide-vue-next'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/authStore'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()
const resetting = computed(() => route.query.reset === '1')
const email = ref('')
const password = ref('')
const newPassword = ref('')
const error = ref('')
const message = ref('')

async function submit() {
  error.value = ''; message.value = ''
  const result = await auth.signIn(email.value, password.value)
  if (result.error) { error.value = result.error.message; return }
  await router.replace(typeof route.query.redirect === 'string' ? route.query.redirect : '/')
}
async function forgotPassword() {
  error.value = ''; message.value = ''
  const result = await auth.resetPassword(email.value)
  if (result.error) error.value = result.error.message
  else message.value = '重設密碼信件已寄出，請查看信箱或垃圾郵件。'
}
async function saveNewPassword() {
  error.value = ''; message.value = ''
  if (newPassword.value.length < 6) { error.value = '新密碼至少需要 6 碼。'; return }
  const result = await auth.updatePassword(newPassword.value)
  if (result.error) error.value = result.error.message
  else { message.value = '密碼已更新，請重新登入。'; await auth.signOut(); await router.replace('/login') }
}
onMounted(() => { if (auth.isAuthenticated && !resetting.value) void router.push('/') })
</script>

<template>
  <div class="mx-auto flex min-h-[70vh] max-w-[390px] items-center">
    <section class="w-full rounded-[28px] border border-sand bg-white p-6 shadow-sm">
      <p class="mb-1 text-xs tracking-[.18em] text-clay">SHIMMER YOGA MEMBER</p>
      <h1 class="mb-2 font-display text-2xl">{{ resetting ? '設定新密碼' : '歡迎回到微光' }}</h1>
      <p class="mb-5 text-xs leading-relaxed text-stone-500">{{ resetting ? '請輸入新的登入密碼。' : '帳號由管理者建立，請使用管理者提供的 Email 與密碼登入。' }}</p>
      <div v-if="resetting" class="space-y-3">
        <label class="relative block"><LockKeyhole :size="16" class="absolute left-3 top-3 text-stone-400" /><input v-model="newPassword" required type="password" minlength="6" placeholder="新密碼（至少 6 碼）" class="w-full rounded-xl border border-sand py-2.5 pl-9 pr-3 text-sm" /></label>
      </div>
      <div v-if="!resetting" class="mt-3 space-y-3"><label class="relative block"><Mail :size="16" class="absolute left-3 top-3 text-stone-400" /><input v-model="email" required type="email" placeholder="Email" class="w-full rounded-xl border border-sand py-2.5 pl-9 pr-3 text-sm" /></label><label class="relative block"><LockKeyhole :size="16" class="absolute left-3 top-3 text-stone-400" /><input v-model="password" required type="password" minlength="6" placeholder="密碼（至少 6 碼）" class="w-full rounded-xl border border-sand py-2.5 pl-9 pr-3 text-sm" /></label></div>
      <p v-if="error" class="mt-3 rounded-xl bg-[#f8ece8] px-3 py-2 text-xs text-clay">{{ error }}</p><p v-if="message" class="mt-3 rounded-xl bg-[#e8f3e9] px-3 py-2 text-xs text-sage">{{ message }}</p>
      <button class="mt-5 w-full rounded-2xl bg-sage py-3 text-sm font-semibold text-white" :disabled="auth.loading" @click="resetting ? saveNewPassword() : submit()">{{ auth.loading ? '處理中…' : resetting ? '更新密碼' : '登入' }}</button>
      <button v-if="!resetting" class="mt-3 w-full text-xs text-stone-500 underline" @click="forgotPassword">忘記密碼？寄送重設信件</button>
      <p v-if="!resetting" class="mt-4 text-center text-xs text-stone-500">需要帳號請洽管理者建立</p>
    </section>
  </div>
</template>
