<template>
  <div class="donut-wrap">
    <svg :viewBox="`0 0 ${size} ${size}`" :width="size" :height="size" class="donut">
      <!-- 배경 링 -->
      <circle :cx="c" :cy="c" :r="r" fill="none" stroke="#f0f3f7" :stroke-width="stroke" />

      <!-- 데이터 세그먼트 -->
      <circle
        v-for="(seg, i) in arcs" :key="i"
        :cx="c" :cy="c" :r="r"
        fill="none"
        :stroke="seg.color"
        :stroke-width="stroke"
        :stroke-dasharray="`${seg.len} ${circumference}`"
        :stroke-dashoffset="-seg.offset"
        :transform="`rotate(-90 ${c} ${c})`"
        stroke-linecap="butt"
      />

      <!-- 가운데 텍스트 -->
      <text :x="c" :y="c - 4" text-anchor="middle" class="donut-label">{{ loading ? '...' : '총 자산' }}</text>
      <text :x="c" :y="c + 16" text-anchor="middle" class="donut-value">{{ centerLabel }}</text>
    </svg>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { wonShort } from '../../../lib/api_v2.js'

const props = defineProps({
  segments: { type: Array, required: true }, // [{ value, color, label }]
  total:    { type: Number, default: 0 },
  loading:  { type: Boolean, default: false },
  size:     { type: Number, default: 160 },
  stroke:   { type: Number, default: 22 },
})

const c = computed(() => props.size / 2)
const r = computed(() => props.size / 2 - props.stroke / 2 - 2)
const circumference = computed(() => 2 * Math.PI * r.value)

const arcs = computed(() => {
  const sum = props.segments.reduce((s, x) => s + Math.max(0, x.value), 0)
  if (sum <= 0) return []
  let offset = 0
  const out = []
  for (const seg of props.segments) {
    const v = Math.max(0, seg.value)
    if (v <= 0) continue
    const len = (v / sum) * circumference.value
    out.push({ len, offset, color: seg.color })
    offset += len
  }
  return out
})

const centerLabel = computed(() => {
  if (props.loading) return ''
  return props.total > 0 ? wonShort(props.total) + '원' : '—'
})
</script>

<style scoped>
.donut-wrap { display: inline-block; }
.donut { display: block; margin: 0 auto; }
.donut-label { fill: #8898aa; font-size: 11px; font-weight: 600; }
.donut-value { fill: #32325d; font-size: 16px; font-weight: 700; }
</style>
