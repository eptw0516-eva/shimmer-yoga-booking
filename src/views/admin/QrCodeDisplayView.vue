<script setup lang="ts">
import { computed } from 'vue'
import QRCode from 'qrcode'
import { onMounted, ref } from 'vue'
import { formatTaiwanDateTime } from '../../utils/date'
import { useBookingStore } from '../../stores/bookingStore'
import type { YogaClass } from '../../types/database'
import { useRoute } from 'vue-router'
const qrData = JSON.stringify({ studio: 'shimmer_yoga', action: 'checkin', code: 'SHIMMER_CHECKIN_SECRET' })
const qrImage = ref('')
const store = useBookingStore()
const route = useRoute()
const selectedClassId = ref('')
const todayClasses = computed(() => store.classes.filter((item) => formatTaiwanDateTime(item.start_time).slice(0, 10) === formatTaiwanDateTime(new Date().toISOString()).slice(0, 10)))
const selectedClass = computed<YogaClass | undefined>(() => todayClasses.value.find((item) => item.id === selectedClassId.value))
const today = computed(() => formatTaiwanDateTime(new Date().toISOString()))
async function generateQr() {
  if (!selectedClass.value) { qrImage.value = ''; return }
  qrImage.value = await QRCode.toDataURL(JSON.stringify({ studio: 'shimmer_yoga', action: 'checkin', code: 'SHIMMER_CHECKIN_SECRET', class_id: selectedClass.value.id }), { width: 320, margin: 2 })
}
onMounted(async () => { await store.loadSchedule(); const requestedClassId = typeof route.query.class_id === 'string' ? route.query.class_id : ''; selectedClassId.value = todayClasses.value.some((item) => item.id === requestedClassId) ? requestedClassId : (todayClasses.value[0]?.id ?? ''); await generateQr() })
</script>

<template>
  <div class="animate-rise text-center">
    <section class="rounded-[28px] bg-white p-6 shadow-sm"><p class="text-xs tracking-[.2em] text-clay">SHIMMER YOGA CHECK-IN</p><h1 class="mt-2 font-display text-2xl text-ink">課程簽到 QR Code</h1><p class="mt-2 text-sm text-stone-500">{{ today }}</p><select v-model="selectedClassId" class="mt-5 w-full rounded-xl border border-sand bg-white px-3 py-3 text-sm" @change="generateQr"><option value="">選擇今日課程</option><option v-for="item in todayClasses" :key="item.id" :value="item.id">{{ formatTaiwanDateTime(item.start_time) }} · {{ item.title }}</option></select><p v-if="selectedClass" class="mt-3 text-sm font-semibold text-sage">{{ selectedClass.title }} · {{ selectedClass.room }}</p><div class="mx-auto my-6 max-w-[300px] rounded-2xl bg-white p-3"><img v-if="qrImage" :src="qrImage" :alt="`${selectedClass?.title ?? '課程'}簽到 QR Code`" class="w-full" /><p v-else class="py-12 text-sm text-stone-400">請先選擇課程</p></div><p class="text-xs leading-relaxed text-stone-500">請將目前選取課程的 QR Code 投影或列印於教室<br />學員掃描後只會簽到這一堂課</p></section>
  </div>
</template>
