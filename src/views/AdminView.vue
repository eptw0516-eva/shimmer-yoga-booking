<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { CalendarPlus, ChevronRight, Minus, Plus, Search, Settings2, UserRound, ReceiptText, X } from 'lucide-vue-next'
import { useRouter } from 'vue-router'
import { supabase } from '../services/supabase'
import { useBookingStore } from '../stores/bookingStore'
import { formatTaiwanDate, formatTaiwanDateTime, formatTaiwanTime, isoToTaiwanInput, taiwanDateAndTimeToIso, taiwanInputToIso } from '../utils/date'
import type { CourseType, Profile, YogaClass } from '../types/database'

const store = useBookingStore()
const router = useRouter()
const search = ref('')
const activeTab = ref<'students' | 'classes'>('students')
const students = ref<Array<{ id: string; name: string; phone: string; credits: number }>>([])
const classParticipants = ref<Record<string, { bookings: Array<{ name: string; phone: string }>; waitlist: Array<{ name: string; phone: string; position: number }> }>>({})
const instructors = ref<Profile[]>([])
const showClassForm = ref(false)
const editingClass = ref<YogaClass | null>(null)
const classForm = ref({ title: '', instructor_id: '', course_type: '常態課' as CourseType, room: 'A 教室', start_time: '', end_time: '', capacity: 12, level: '初階' as YogaClass['level'], description: '', instructor_bio: '', weekday: 1, start_date: '', end_date: '' })
const timeOptions = Array.from({ length: 48 }, (_, index) => `${String(Math.floor(index / 2)).padStart(2, '0')}:${index % 2 ? '30' : '00'}`)
const selectedInstructor = computed(() => instructors.value.find((item) => item.id === classForm.value.instructor_id))
const formatClassDate = formatTaiwanDate
const formatClassTime = formatTaiwanTime
const adjust = (index: number, amount: number) => { students.value[index].credits = Math.max(0, students.value[index].credits + amount); store.notify(amount > 0 ? '已贈送 1 堂課給學員。' : '已扣除 1 堂課。') }
function localDateTime(date: string, time: string) { return taiwanDateAndTimeToIso(date, time) }
async function addClass() {
  const form = classForm.value
  if (!form.title || !form.instructor_id || !form.start_date || !form.end_date || !form.start_time || !form.end_time) { store.notify('請完整填寫課程、老師、日期與時間。', 'error'); return }
  if (form.start_time >= form.end_time) { store.notify('結束時間必須晚於開始時間。', 'error'); return }
  const instructor = selectedInstructor.value
  if (!instructor) { store.notify('請選擇有效的授課老師。', 'error'); return }
  const success = await store.createRecurringClasses({
    title: form.title, instructor_id: instructor.id, instructor_name: instructor.full_name,
    instructor_bio: form.instructor_bio || '', course_type: form.course_type, room: form.room,
    start_time: localDateTime(form.start_date, form.start_time), end_time: localDateTime(form.start_date, form.end_time),
    capacity: form.capacity, level: form.level, description: form.description,
  }, form.weekday, form.start_date, form.end_date)
  if (success) { showClassForm.value = false; await store.loadSchedule(); form.title = ''; form.instructor_id = ''; form.start_date = ''; form.end_date = ''; form.start_time = ''; form.end_time = ''; form.description = '' }
}
async function loadInstructors() {
  if (!supabase) return
  const { data, error } = await supabase.from('profiles').select('*').eq('is_instructor', true).eq('is_active', true).order('full_name')
  if (error) store.notify(`老師載入失敗：${error.message}`, 'error')
  else instructors.value = (data ?? []) as Profile[]
}
async function loadStudents() {
  if (!supabase) return
  const { data: profiles, error } = await supabase.from('profiles').select('id,full_name,phone') as unknown as { data: Array<{ id: string; full_name: string | null; phone: string | null }> | null; error: { message: string } | null }
  if (error) { store.notify(`會員載入失敗：${error.message}`, 'error'); return }
  const { data: packages, error: packageError } = await supabase.from('user_packages').select('user_id,remaining_credits') as unknown as { data: Array<{ user_id: string; remaining_credits: number }> | null; error: { message: string } | null }
  if (packageError) { store.notify(`票券載入失敗：${packageError.message}`, 'error'); return }
  const totals = (packages ?? []).reduce<Record<string, number>>((result, item) => { result[item.user_id] = (result[item.user_id] ?? 0) + item.remaining_credits; return result }, {})
  students.value = (profiles ?? []).map((profile) => ({ id: profile.id, name: profile.full_name || '未設定姓名', phone: profile.phone || '未設定電話', credits: totals[profile.id] ?? 0 }))
}
async function loadClassParticipants() {
  if (!supabase) return
  const [bookingResult, waitlistResult] = await Promise.all([
    supabase.from('bookings').select('class_id,user_id,status,profile:profiles(full_name,phone)').eq('status', 'confirmed'),
    supabase.from('class_waitlists').select('class_id,user_id,position,status,profile:profiles(full_name,phone)').eq('status', 'pending').order('position'),
  ])
  if (bookingResult.error) { store.notify(`預約名單載入失敗：${bookingResult.error.message}`, 'error'); return }
  if (waitlistResult.error) { store.notify(`候補名單載入失敗：${waitlistResult.error.message}`, 'error'); return }
  const result: Record<string, { bookings: Array<{ name: string; phone: string }>; waitlist: Array<{ name: string; phone: string; position: number }> }> = {}
  for (const item of (bookingResult.data ?? []) as Array<{ class_id: string; profile?: { full_name?: string | null; phone?: string | null } | null }>) {
    const group = result[item.class_id] ?? { bookings: [], waitlist: [] }
    group.bookings.push({ name: item.profile?.full_name || '未設定姓名', phone: item.profile?.phone || '未設定電話' })
    result[item.class_id] = group
  }
  for (const item of (waitlistResult.data ?? []) as Array<{ class_id: string; position: number; profile?: { full_name?: string | null; phone?: string | null } | null }>) {
    const group = result[item.class_id] ?? { bookings: [], waitlist: [] }
    group.waitlist.push({ name: item.profile?.full_name || '未設定姓名', phone: item.profile?.phone || '未設定電話', position: item.position })
    result[item.class_id] = group
  }
  classParticipants.value = result
}
function editClass(item: YogaClass) { editingClass.value = { ...item, start_time: isoToTaiwanInput(item.start_time), end_time: isoToTaiwanInput(item.end_time) } }
async function saveClass() {
  if (!editingClass.value) return
  if (new Date(editingClass.value.end_time) <= new Date(editingClass.value.start_time)) { store.notify('結束時間必須晚於開始時間。', 'error'); return }
  if (editingClass.value.capacity < editingClass.value.booked_count) { store.notify('人數上限不可低於目前已預約人數。', 'error'); return }
  if (await store.updateClass(editingClass.value.id, { title: editingClass.value.title, instructor_id: editingClass.value.instructor_id, instructor_name: editingClass.value.instructor_name, instructor_bio: editingClass.value.instructor_bio, course_type: editingClass.value.course_type, room: editingClass.value.room, level: editingClass.value.level, description: editingClass.value.description, start_time: taiwanInputToIso(editingClass.value.start_time), end_time: taiwanInputToIso(editingClass.value.end_time), capacity: editingClass.value.capacity })) editingClass.value = null
}
onMounted(async () => { await loadInstructors(); await store.loadSchedule(); await loadStudents(); await loadClassParticipants() })
</script>

<template>
  <div class="animate-rise">
    <section class="mb-5 flex items-center justify-between rounded-3xl bg-ink p-5 text-white"><div><p class="mb-1 text-[11px] tracking-[.18em] text-white/60">STUDIO OVERVIEW</p><p class="font-display text-xl">今天，教室平安運轉。</p></div><Settings2 :size="22" class="text-[#d9c8a9]" /></section>
    <div class="mb-5 grid grid-cols-2 gap-1 rounded-2xl bg-sand p-1"><button class="rounded-xl py-2.5 text-xs" :class="activeTab === 'students' ? 'bg-white font-semibold text-sage shadow-sm' : 'text-stone-500'" @click="activeTab = 'students'"><UserRound :size="15" class="mr-1 inline" />學員管理</button><button class="rounded-xl py-2.5 text-xs" :class="activeTab === 'classes' ? 'bg-white font-semibold text-sage shadow-sm' : 'text-stone-500'" @click="activeTab = 'classes'"><CalendarPlus :size="15" class="mr-1 inline" />排課管理</button></div>
    <div class="mb-5 grid grid-cols-3 gap-2"><button class="rounded-xl border border-sand bg-white py-2.5 text-[11px] text-sage" @click="router.push('/admin/members')"><UserRound :size="14" class="mr-1 inline" />會員</button><button class="rounded-xl border border-sand bg-white py-2.5 text-[11px] text-sage" @click="router.push('/admin/orders')"><ReceiptText :size="14" class="mr-1 inline" />核帳</button><button class="rounded-xl border border-sand bg-white py-2.5 text-[11px] text-sage" @click="router.push('/admin/plans')">方案</button></div>
    <template v-if="activeTab === 'students'"><div class="relative mb-4"><Search :size="16" class="absolute left-3 top-3 text-stone-400" /><input v-model="search" placeholder="搜尋學員姓名或電話" class="w-full rounded-2xl border border-sand bg-white py-2.5 pl-9 pr-3 text-sm" /></div><div class="space-y-3"><article v-for="(student, index) in students.filter(item => !search || item.name.includes(search) || item.phone.includes(search))"     :key="student.id" class="rounded-3xl border border-sand bg-white p-4"><div class="flex items-center gap-3"><span class="grid h-10 w-10 place-items-center rounded-full bg-[#e3ece3] font-semibold text-sage">{{ student.name.slice(0, 1) }}</span><div class="flex-1"><p class="text-sm font-semibold">{{ student.name }}</p><p class="mt-1 text-[11px] text-stone-400">{{ student.phone }}</p></div><div class="text-right"><strong class="text-lg text-sage">{{ student.credits }}</strong><p class="text-[10px] text-stone-400">剩餘堂數</p></div></div><div class="mt-3 flex gap-2 border-t border-sand pt-3"><button class="flex-1 rounded-xl bg-[#eef3ee] py-2 text-xs font-semibold text-sage" @click="adjust(index, 1)"><Plus :size="14" class="mr-1 inline" />贈送一堂</button><button class="flex-1 rounded-xl bg-[#f8eeeb] py-2 text-xs font-semibold text-clay" @click="adjust(index, -1)"><Minus :size="14" class="mr-1 inline" />扣除一堂</button></div></article></div></template>
    <template v-else><div class="mb-3 flex items-center justify-between"><h2 class="font-display text-xl">課程列表</h2><button class="rounded-xl bg-sage px-3 py-2 text-xs font-semibold text-white" @click="showClassForm = true; void loadInstructors()"><Plus :size="14" class="mr-1 inline" />新增課程</button></div><div class="space-y-3"><article v-for="item in store.classes" :key="item.id" class="rounded-3xl border border-sand bg-white p-4" @click="editClass(item)"><div class="flex items-center gap-3"><div class="grid h-10 w-10 place-items-center rounded-2xl bg-[#f4ede7] text-clay"><CalendarPlus :size="19" /></div><div class="flex-1"><p class="text-sm font-semibold">{{ item.title }}</p><p class="mt-1 text-[11px] text-stone-500">{{ formatTaiwanDateTime(item.start_time) }} ～ {{ formatTaiwanDateTime(item.end_time) }}</p><p class="mt-1 text-[11px] text-stone-400">{{ item.instructor_name || '未指定老師' }} · 預約 {{ item.booked_count }} / {{ item.capacity }} 人</p></div><ChevronRight :size="17" class="text-stone-300" /></div><div v-if="classParticipants[item.id]" class="mt-3 space-y-2 border-t border-sand pt-3 text-[11px]"><p class="font-semibold text-sage">預約學員（{{ item.booked_count }}）</p><p v-if="!classParticipants[item.id].bookings.length" class="text-stone-400">目前沒有載入到預約姓名</p><p v-for="person in classParticipants[item.id].bookings" :key="`booked-${item.id}-${person.phone}`" class="text-stone-500">{{ person.name }} · {{ person.phone }}</p><p class="mt-2 font-semibold text-clay">候補名單（{{ classParticipants[item.id].waitlist.length }}）</p><p v-if="!classParticipants[item.id].waitlist.length" class="text-stone-400">目前沒有候補學員</p><p v-for="person in classParticipants[item.id].waitlist" :key="`wait-${item.id}-${person.position}`" class="text-stone-500">{{ person.position }}. {{ person.name }} · {{ person.phone }}</p></div></article></div></template>
    <div v-if="showClassForm" class="fixed inset-0 z-[100] flex items-end justify-center bg-ink/30 p-4 pb-24 sm:items-center sm:pb-4"><section class="max-h-[calc(100vh-7rem)] w-full max-w-[398px] overflow-y-auto rounded-[28px] bg-cream p-5 pb-8 shadow-xl"><h2 class="mb-4 font-display text-xl">新增週期課程</h2><div class="space-y-3"><input v-model="classForm.title" placeholder="課程名稱" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><select v-model="classForm.instructor_id" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"><option value="">選擇授課老師</option><option v-for="teacher in instructors" :key="teacher.id" :value="teacher.id">{{ teacher.full_name }}{{ teacher.email ? ` · ${teacher.email}` : '' }}</option></select><select v-model="classForm.course_type" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"><option>常態課</option><option>預約團體課</option><option>一對一私人課</option><option>單堂工作坊</option></select><select v-model.number="classForm.weekday" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"><option v-for="(day, index) in ['星期日','星期一','星期二','星期三','星期四','星期五','星期六']" :key="day" :value="index">{{ day }}</option></select><div class="grid grid-cols-2 gap-2"><label class="text-[11px] text-stone-500">開始日期<input v-model="classForm.start_date" type="date" class="mt-1 w-full rounded-xl border border-sand bg-white px-2 py-2.5 text-xs" /></label><label class="text-[11px] text-stone-500">結束日期<input v-model="classForm.end_date" type="date" class="mt-1 w-full rounded-xl border border-sand bg-white px-2 py-2.5 text-xs" /></label></div><div class="grid grid-cols-2 gap-2"><label class="text-[11px] text-stone-500">開始時間<select v-model="classForm.start_time" class="mt-1 w-full rounded-xl border border-sand bg-white px-2 py-2.5 text-xs"><option value="">選擇時間</option><option v-for="time in timeOptions" :key="time">{{ time }}</option></select></label><label class="text-[11px] text-stone-500">結束時間<select v-model="classForm.end_time" class="mt-1 w-full rounded-xl border border-sand bg-white px-2 py-2.5 text-xs"><option value="">選擇時間</option><option v-for="time in timeOptions" :key="time">{{ time }}</option></select></label></div><div class="grid grid-cols-2 gap-2"><input v-model.number="classForm.capacity" type="number" min="1" placeholder="名額" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><input v-model="classForm.room" placeholder="教室" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /></div><select v-model="classForm.level" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"><option>初階</option><option>中階</option><option>高階</option></select><input v-model="classForm.instructor_bio" placeholder="老師介紹（選填）" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><textarea v-model="classForm.description" placeholder="課程說明" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"></textarea></div><div class="mt-5 flex gap-2"><button class="flex-1 rounded-xl border border-sand py-3 text-sm" @click="showClassForm = false">取消</button><button class="flex-1 rounded-xl bg-sage py-3 text-sm font-semibold text-white" @click="addClass">儲存課程</button></div></section></div>
    <div v-if="editingClass" class="fixed inset-0 z-[100] flex items-end justify-center bg-ink/30 p-4 pb-24 sm:items-center sm:pb-4"><section class="max-h-[calc(100vh-7rem)] w-full max-w-[398px] overflow-y-auto rounded-[28px] bg-cream p-5 shadow-xl"><div class="mb-4 flex items-center justify-between"><h2 class="font-display text-xl">修改單堂課程</h2><button @click="editingClass = null"><X :size="18" /></button></div><div class="space-y-3"><input v-model="editingClass.title" placeholder="課程名稱" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><select v-model="editingClass.instructor_id" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"><option v-for="teacher in instructors" :key="teacher.id" :value="teacher.id">{{ teacher.full_name }}</option></select><select v-model="editingClass.course_type" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"><option>常態課</option><option>預約團體課</option><option>一對一私人課</option><option>單堂工作坊</option></select><label class="block text-xs text-stone-500">上課開始時間<input v-model="editingClass.start_time" type="datetime-local" class="mt-1 w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /></label><label class="block text-xs text-stone-500">上課結束時間<input v-model="editingClass.end_time" type="datetime-local" class="mt-1 w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /></label><div class="grid grid-cols-2 gap-2"><label class="text-xs text-stone-500">人數上限<input v-model.number="editingClass.capacity" type="number" min="1" class="mt-1 w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /></label><label class="text-xs text-stone-500">教室<input v-model="editingClass.room" class="mt-1 w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /></label></div><select v-model="editingClass.level" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"><option>初階</option><option>中階</option><option>高階</option></select><input v-model="editingClass.instructor_bio" placeholder="老師介紹" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm" /><textarea v-model="editingClass.description" placeholder="課程說明" class="w-full rounded-xl border border-sand bg-white px-3 py-2.5 text-sm"></textarea></div><div class="mt-5 flex gap-2"><button class="flex-1 rounded-xl border border-sand py-3 text-sm" @click="editingClass = null">取消</button><button class="flex-1 rounded-xl bg-sage py-3 text-sm font-semibold text-white" @click="saveClass">儲存修改</button></div></section></div>
    <div v-if="store.toast" class="fixed left-1/2 top-5 z-[120] w-[calc(100%-2rem)] max-w-[398px] -translate-x-1/2 rounded-2xl bg-ink px-4 py-3 text-sm text-white shadow-lg">{{ store.toast.message }}</div>
  </div>
</template>
