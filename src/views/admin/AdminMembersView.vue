<script setup lang="ts">
import { nextTick, onMounted, ref, watch } from 'vue'
import { Save, UserRound } from 'lucide-vue-next'
import { supabase } from '../../services/supabase'
import { useBookingStore } from '../../stores/bookingStore'
import { formatTaiwanDateTime } from '../../utils/date'
import type { Profile } from '../../types/database'

const store = useBookingStore()
const profiles = ref<Profile[]>([])
const memberPackages = ref<Record<string, Array<{ package_name?: string; remaining_credits: number; total_credits: number; valid_until: string; status: string }>>>({})
const editing = ref<Profile | null>(null)
const showTeacherForm = ref(false)
const creatingTeacher = ref(false)
const teacherForm = ref({ full_name: '', email: '', phone: '', password: '', role: 'member' as 'member' | 'instructor', is_active: true })
const resetPassword = ref('')
const resettingPassword = ref(false)
const firstAccountInput = ref<HTMLInputElement | null>(null)
watch(showTeacherForm, async (visible) => {
  if (visible) {
    await nextTick()
    firstAccountInput.value?.focus()
  }
})

async function loadProfiles() {
  if (!supabase) { profiles.value = []; store.notify('Supabase 尚未設定，無法載入真實會員資料。', 'error'); return }
  const { error: syncError } = await supabase.rpc('sync_auth_profiles' as never)
  if (syncError) store.notify(`會員同步失敗：${syncError.message}；將先載入既有會員資料。`, 'error')
  const [profileResult, packageResult] = await Promise.all([
    supabase.from('profiles').select('*').order('created_at'),
    supabase.from('user_packages').select('user_id,package_name,remaining_credits,total_credits,valid_until,status').order('valid_until', { ascending: true }) as unknown as Promise<{ data: Array<{ user_id: string; package_name?: string; remaining_credits: number; total_credits: number; valid_until: string; status: string }> | null; error: { message: string } | null }>,
  ])
  if (profileResult.error) { store.notify(profileResult.error.message ?? '無法載入會員資料。', 'error'); return }
  profiles.value = profileResult.data ?? []
  if (packageResult.error) { store.notify(`會員票券載入失敗：${packageResult.error.message}`, 'error'); return }
  memberPackages.value = (packageResult.data ?? []).reduce<Record<string, Array<{ package_name?: string; remaining_credits: number; total_credits: number; valid_until: string; status: string }>>>((result, item) => {
    const packages = result[item.user_id] ?? []
    packages.push(item)
    result[item.user_id] = packages
    return result
  }, {})
}
function edit(profile: Profile) { editing.value = { ...profile }; resetPassword.value = '' }
async function resetMemberPassword() {
  if (!editing.value || !supabase) return
  if (resetPassword.value.length < 6) { store.notify('新密碼至少需要 6 碼。', 'error'); return }
  resettingPassword.value = true
  try {
    const { data, error } = await supabase.functions.invoke('create-instructor', { body: { action: 'reset-password', user_id: editing.value.id, password: resetPassword.value } })
    if (error || data?.error) { store.notify(data?.error ?? error?.message ?? '重設密碼失敗。', 'error'); return }
    resetPassword.value = ''
    store.notify('學員密碼已重設。')
  } finally {
    resettingPassword.value = false
  }
}
async function save() {
  if (!editing.value) return
  if (supabase) {
    const { data, error } = await supabase.rpc('update_member_access', {
      p_user_id: editing.value.id, p_role: editing.value.role, p_is_instructor: Boolean(editing.value.is_instructor),
      p_is_active: Boolean(editing.value.is_active), p_full_name: editing.value.full_name, p_phone: editing.value.phone,
      p_birth_date: editing.value.birth_date || null, p_line_user_id: editing.value.line_user_id,
    } as never) as unknown as { data: Profile | null; error: { message: string } | null }
    if (error) { store.notify(error.message, 'error'); return }
    if (data) Object.assign(editing.value, data)
  }
  const index = profiles.value.findIndex((item) => item.id === editing.value?.id)
  if (index >= 0) profiles.value[index] = { ...editing.value }
  editing.value = null
  store.notify('會員權限與資料已更新。')
}
async function createTeacher() {
  if (!supabase) { store.notify('Supabase 尚未設定，無法建立老師帳號。', 'error'); return }
  if (!teacherForm.value.full_name.trim() || !teacherForm.value.email.trim() || !teacherForm.value.phone.trim() || teacherForm.value.password.length < 6) {
    store.notify('請完整填寫姓名、Email、電話，密碼至少 6 碼。', 'error')
    return
  }
  creatingTeacher.value = true
  try {
    const { data, error } = await supabase.functions.invoke('create-instructor', { body: teacherForm.value })
    if (error || data?.error) {
      let detail = data?.error ?? error?.message ?? '建立老師失敗，請確認 Edge Function 已部署。'
      if (error && 'context' in error && error.context instanceof Response) {
        try {
          const body = await error.context.json() as { error?: string }
          detail = body.error ?? detail
        } catch { /* Supabase may return a non-JSON edge error. */ }
      }
      store.notify(detail, 'error')
      return
    }
    store.notify(data?.existing ? '既有帳號資料已更新，請使用該 Email 登入。' : '帳號已建立，可以直接登入。')
    teacherForm.value = { full_name: '', email: '', phone: '', password: '', role: 'member', is_active: true }
    showTeacherForm.value = false
    await new Promise((resolve) => window.setTimeout(resolve, 300))
    await loadProfiles()
  } catch (error) {
    store.notify(error instanceof Error ? error.message : '建立老師失敗，請稍後再試。', 'error')
  } finally {
    creatingTeacher.value = false
  }
}
onMounted(() => void loadProfiles())
</script>

<template>
  <div class="animate-rise">
    <section class="mb-5 rounded-3xl bg-ink p-5 text-white"><p class="mb-1 text-[11px] tracking-[.18em] text-white/60">MEMBER ACCESS</p><h1 class="font-display text-xl">會員與角色管理</h1><p class="mt-2 text-xs text-white/70">管理姓名、Email、電話、角色、老師權限與帳號狀態。</p></section>
    <div class="mb-3 flex justify-end"><button class="rounded-xl bg-sage px-4 py-3 text-sm font-semibold text-white" @click="showTeacherForm = true">新增帳號</button></div><div class="space-y-3"><article v-for="profile in profiles" :key="profile.id" class="rounded-3xl border border-sand bg-white p-4"><div class="flex items-center gap-3"><span class="grid h-10 w-10 place-items-center rounded-full bg-[#e3e3ef] text-sage"><UserRound :size="18" /></span><div class="flex-1"><p class="text-sm font-semibold">{{ profile.full_name || '未設定姓名' }}</p><p class="mt-1 text-[11px] text-stone-400">{{ profile.email || '未同步 Email' }}</p><p class="mt-1 text-[11px] text-stone-400">{{ profile.phone || '未設定電話' }}</p><div class="mt-2 flex flex-wrap gap-1"><span class="rounded-full bg-[#efeff7] px-2 py-1 text-[10px] text-sage">{{ profile.role }}</span><span v-if="profile.is_instructor" class="rounded-full bg-[#f5ede9] px-2 py-1 text-[10px] text-clay">老師</span><span class="rounded-full px-2 py-1 text-[10px]" :class="profile.is_active ? 'bg-[#e8f3e9] text-sage' : 'bg-stone-100 text-stone-400'">{{ profile.is_active ? '啟用中' : '已停用' }}</span></div></div><button class="rounded-xl bg-sage px-3 py-2 text-xs font-semibold text-white" @click="edit(profile)">編輯</button></div><div class="mt-4 border-t border-sand pt-3"><p class="mb-2 text-xs font-semibold text-stone-600">購買票券</p><div v-if="memberPackages[profile.id]?.length" class="space-y-2"><div v-for="item in memberPackages[profile.id]" :key="`${profile.id}-${item.package_name}-${item.valid_until}`" class="rounded-xl bg-[#faf8f5] p-3 text-xs text-stone-500"><div class="flex justify-between gap-2"><strong class="text-sage">{{ item.package_name || '未命名票券' }}</strong><span>{{ item.status === 'active' ? '使用中' : item.status }}</span></div><p class="mt-1">剩餘 {{ item.remaining_credits }} / {{ item.total_credits }} 堂 · 有效至 {{ formatTaiwanDateTime(item.valid_until) }}</p></div></div><p v-else class="text-xs text-stone-400">尚無已核款票券</p></div></article></div>
    <div v-if="editing" class="fixed inset-0 z-30 flex items-end justify-center bg-ink/30 p-4 sm:items-center"><section class="w-full max-w-[398px] rounded-[28px] bg-cream p-5 shadow-xl"><h2 class="mb-4 font-display text-xl">編輯會員權限</h2><div class="space-y-3"><input v-model="editing.full_name" placeholder="姓名" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><input v-model="editing.phone" placeholder="電話" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><input v-model="editing.birth_date" type="date" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><input v-model="editing.line_user_id" placeholder="LINE ID" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><label class="block text-xs text-stone-500">會員角色<select v-model="editing.role" class="mt-1 w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"><option value="member">member 學員</option><option value="admin">admin 管理員</option><option value="instructor">instructor 老師</option></select></label><label class="flex items-center gap-2 rounded-xl bg-white p-3 text-sm"><input v-model="editing.is_instructor" type="checkbox" /> 同時具備老師權限</label><label class="flex items-center gap-2 rounded-xl bg-white p-3 text-sm"><input v-model="editing.is_active" type="checkbox" /> 帳號啟用</label><div class="border-t border-sand pt-3"><p class="mb-2 text-xs font-semibold text-stone-600">管理員重設密碼</p><input v-model="resetPassword" type="password" minlength="6" placeholder="新密碼（至少 6 碼）" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><button class="mt-2 w-full rounded-xl border border-clay py-2.5 text-sm text-clay disabled:opacity-50" :disabled="resettingPassword" @click="resetMemberPassword">{{ resettingPassword ? '重設中…' : '重設此帳號密碼' }}</button></div></div><div class="mt-5 flex gap-2"><button class="flex-1 rounded-xl border border-sand py-3 text-sm" @click="editing = null">取消</button><button class="flex-1 rounded-xl bg-sage py-3 text-sm font-semibold text-white" @click="save"><Save :size="15" class="mr-1 inline" />儲存</button></div></section></div>
    <div v-if="store.toast" class="fixed left-1/2 top-5 z-40 w-[calc(100%-2rem)] max-w-[398px] -translate-x-1/2 rounded-2xl bg-ink px-4 py-3 text-sm text-white shadow-lg">{{ store.toast.message }}</div>
  </div>
  <div v-if="showTeacherForm" class="fixed inset-0 z-40 flex items-center justify-center overflow-y-auto bg-ink/40 p-4 sm:p-8">
    <section class="my-auto w-full max-w-[620px] rounded-[32px] bg-cream p-6 shadow-2xl sm:p-8">
      <div class="mb-6 flex items-start justify-between gap-4">
        <div><p class="mb-1 text-xs tracking-[.16em] text-clay">ACCOUNT ACCESS</p><h2 class="font-display text-2xl">新增帳號</h2><p class="mt-2 text-sm text-stone-500">會員與老師帳號皆由管理者建立，建立後可直接登入。</p></div>
        <button class="rounded-xl px-3 py-2 text-sm text-stone-500 hover:bg-white" @click="showTeacherForm = false">關閉</button>
      </div>
      <div class="grid gap-4 sm:grid-cols-2">
        <label class="block text-sm font-medium text-stone-600 sm:col-span-2">姓名<input ref="firstAccountInput" v-model="teacherForm.full_name" placeholder="請輸入姓名" class="mt-2 w-full rounded-2xl border border-sand bg-white px-4 py-3.5 text-base" /></label>
        <label class="block text-sm font-medium text-stone-600">Email<input v-model="teacherForm.email" type="email" placeholder="name@example.com" class="mt-2 w-full rounded-2xl border border-sand bg-white px-4 py-3.5 text-base" /></label>
        <label class="block text-sm font-medium text-stone-600">電話<input v-model="teacherForm.phone" placeholder="手機號碼" class="mt-2 w-full rounded-2xl border border-sand bg-white px-4 py-3.5 text-base" /></label>
        <label class="block text-sm font-medium text-stone-600">初始密碼<input v-model="teacherForm.password" type="password" minlength="6" placeholder="至少 6 碼" class="mt-2 w-full rounded-2xl border border-sand bg-white px-4 py-3.5 text-base" /></label>
        <label class="block text-sm font-medium text-stone-600">帳號角色<select v-model="teacherForm.role" class="mt-2 w-full rounded-2xl border border-sand bg-white px-4 py-3.5 text-base"><option value="member">會員</option><option value="instructor">老師</option></select></label>
        <label class="flex items-center gap-3 rounded-2xl border border-sand bg-white px-4 py-3.5 text-sm text-stone-600 sm:col-span-2"><input v-model="teacherForm.is_active" type="checkbox" class="h-5 w-5 accent-[#718b79]" /> 建立後立即啟用帳號<span v-if="!teacherForm.is_active" class="text-clay">（停用）</span></label>
      </div>
      <p class="mt-5 rounded-2xl bg-white/70 p-4 text-sm leading-relaxed text-stone-500">管理者建立的帳號不需要自行註冊或 Email 驗證，建立完成後即可使用 Email 與初始密碼登入。</p>
      <div class="mt-6 flex gap-3"><button class="flex-1 rounded-2xl border border-sand py-3.5 text-sm" @click="showTeacherForm = false">取消</button><button class="flex-1 rounded-2xl bg-sage py-3.5 text-sm font-semibold text-white disabled:opacity-50" :disabled="creatingTeacher" @click="createTeacher">{{ creatingTeacher ? '建立中…' : '建立帳號' }}</button></div>
    </section>
  </div>
</template>
