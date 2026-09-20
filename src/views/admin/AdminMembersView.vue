<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { Check, Save, UserRound } from 'lucide-vue-next'
import { supabase } from '../../services/supabase'
import { useBookingStore } from '../../stores/bookingStore'
import type { Profile, UserRole } from '../../types/database'

const store = useBookingStore()
const profiles = ref<Profile[]>([])
const demoProfiles = ref<Profile[]>([
  { id: 'demo-member', role: 'member', full_name: '林小瑜', phone: '0912345678', line_user_id: null, birth_date: '1992-04-18', is_instructor: false, is_active: true, created_at: '2026-01-01' },
  { id: 'demo-instructor', role: 'member', full_name: '林安老師', phone: '0922333444', line_user_id: null, birth_date: null, is_instructor: true, is_active: true, created_at: '2026-01-01' },
])
const editing = ref<Profile | null>(null)
const showTeacherForm = ref(false)
const creatingTeacher = ref(false)
const teacherForm = ref({ full_name: '', email: '', phone: '', password: '' })

async function loadProfiles() {
  if (!supabase) { profiles.value = demoProfiles.value; return }
  const { data, error } = await supabase.from('profiles').select('*').order('created_at')
  if (!error && data) profiles.value = data
  else store.notify(error?.message ?? '無法載入會員資料。', 'error')
}
function edit(profile: Profile) { editing.value = { ...profile } }
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
      store.notify(data?.error ?? error?.message ?? '建立老師失敗，請確認 Edge Function 已部署。', 'error')
      return
    }
    store.notify('老師帳號已建立，可以在新增課程時選擇。')
    teacherForm.value = { full_name: '', email: '', phone: '', password: '' }
    showTeacherForm.value = false
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
    <div class="mb-3 flex justify-end"><button class="rounded-xl bg-sage px-3 py-2 text-xs font-semibold text-white" @click="showTeacherForm = true">新增老師帳號</button></div><div class="space-y-3"><article v-for="profile in profiles" :key="profile.id" class="rounded-3xl border border-sand bg-white p-4"><div class="flex items-center gap-3"><span class="grid h-10 w-10 place-items-center rounded-full bg-[#e3e3ef] text-sage"><UserRound :size="18" /></span><div class="flex-1"><p class="text-sm font-semibold">{{ profile.full_name || '未設定姓名' }}</p><p class="mt-1 text-[11px] text-stone-400">{{ profile.email || '未同步 Email' }}</p><p class="mt-1 text-[11px] text-stone-400">{{ profile.phone || '未設定電話' }}</p><div class="mt-2 flex flex-wrap gap-1"><span class="rounded-full bg-[#efeff7] px-2 py-1 text-[10px] text-sage">{{ profile.role }}</span><span v-if="profile.is_instructor" class="rounded-full bg-[#f5ede9] px-2 py-1 text-[10px] text-clay">老師</span><span class="rounded-full px-2 py-1 text-[10px]" :class="profile.is_active ? 'bg-[#e8f3e9] text-sage' : 'bg-stone-100 text-stone-400'">{{ profile.is_active ? '啟用中' : '已停用' }}</span></div></div><button class="rounded-xl bg-sage px-3 py-2 text-xs font-semibold text-white" @click="edit(profile)">編輯</button></div></article></div>
    <div v-if="editing" class="fixed inset-0 z-30 flex items-end justify-center bg-ink/30 p-4 sm:items-center"><section class="w-full max-w-[398px] rounded-[28px] bg-cream p-5 shadow-xl"><h2 class="mb-4 font-display text-xl">編輯會員權限</h2><div class="space-y-3"><input v-model="editing.full_name" placeholder="姓名" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><input v-model="editing.phone" placeholder="電話" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><input v-model="editing.birth_date" type="date" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><input v-model="editing.line_user_id" placeholder="LINE ID" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><label class="block text-xs text-stone-500">會員角色<select v-model="editing.role" class="mt-1 w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"><option value="member">member 學員</option><option value="admin">admin 管理員</option><option value="instructor">instructor 老師</option></select></label><label class="flex items-center gap-2 rounded-xl bg-white p-3 text-sm"><input v-model="editing.is_instructor" type="checkbox" /> 同時具備老師權限</label><label class="flex items-center gap-2 rounded-xl bg-white p-3 text-sm"><input v-model="editing.is_active" type="checkbox" /> 帳號啟用</label></div><div class="mt-5 flex gap-2"><button class="flex-1 rounded-xl border border-sand py-3 text-sm" @click="editing = null">取消</button><button class="flex-1 rounded-xl bg-sage py-3 text-sm font-semibold text-white" @click="save"><Save :size="15" class="mr-1 inline" />儲存</button></div></section></div>
    <div v-if="store.toast" class="fixed left-1/2 top-5 z-40 w-[calc(100%-2rem)] max-w-[398px] -translate-x-1/2 rounded-2xl bg-ink px-4 py-3 text-sm text-white shadow-lg">{{ store.toast.message }}</div>
  </div>
  <div v-if="showTeacherForm" class="fixed inset-0 z-40 flex items-end justify-center bg-ink/30 p-4 sm:items-center"><section class="w-full max-w-[398px] rounded-[28px] bg-cream p-5 shadow-xl"><h2 class="mb-4 font-display text-xl">新增老師帳號</h2><div class="space-y-3"><input v-model="teacherForm.full_name" placeholder="老師姓名" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><input v-model="teacherForm.email" type="email" placeholder="Email" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><input v-model="teacherForm.phone" placeholder="電話" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><input v-model="teacherForm.password" type="password" minlength="6" placeholder="初始密碼（至少 6 碼）" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /></div><p class="mt-3 text-[11px] text-stone-500">建立後老師可直接使用 Email 與初始密碼登入。若仍無法建立，請確認 Supabase 已設定 SERVICE_ROLE_KEY 並重新部署 Edge Function。</p><div class="mt-5 flex gap-2"><button class="flex-1 rounded-xl border border-sand py-3 text-sm" @click="showTeacherForm = false">取消</button><button class="flex-1 rounded-xl bg-sage py-3 text-sm font-semibold text-white disabled:opacity-50" :disabled="creatingTeacher" @click="createTeacher">{{ creatingTeacher ? '建立中…' : '建立老師' }}</button></div></section></div>
</template>
