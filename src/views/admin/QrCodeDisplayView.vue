<script setup lang="ts">
import { computed } from 'vue'
import QRCode from 'qrcode'
import { onMounted, ref } from 'vue'
import { formatTaiwanDateTime } from '../../utils/date'
const qrData = JSON.stringify({ studio: 'shimmer_yoga', action: 'checkin', code: 'SHIMMER_CHECKIN_SECRET' })
const qrImage = ref('')
const today = computed(() => formatTaiwanDateTime(new Date().toISOString()))
onMounted(async () => { qrImage.value = await QRCode.toDataURL(qrData, { width: 320, margin: 2 }) })
</script>

<template>
  <div class="animate-rise text-center">
    <section class="rounded-[28px] bg-white p-6 shadow-sm"><p class="text-xs tracking-[.2em] text-clay">SHIMMER YOGA CHECK-IN</p><h1 class="mt-2 font-display text-2xl text-ink">教室簽到 QR Code</h1><p class="mt-2 text-sm text-stone-500">{{ today }}</p><div class="mx-auto my-6 max-w-[300px] rounded-2xl bg-white p-3"><img v-if="qrImage" :src="qrImage" alt="微光空中瑜珈簽到 QR Code" class="w-full" /></div><p class="text-xs leading-relaxed text-stone-500">請投影或列印張貼於櫃檯／白板<br />學員掃描後即可自助簽到</p></section>
  </div>
</template>
