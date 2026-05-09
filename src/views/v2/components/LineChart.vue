<template>
  <div class="lc-wrap">
    <svg :viewBox="`0 0 ${width} ${height}`" :width="width" :height="height" class="lc">
      <!-- 가로 그리드 -->
      <line v-for="(g, i) in gridY" :key="'gy'+i"
            :x1="padL" :x2="width - padR" :y1="g.y" :y2="g.y"
            stroke="#f0f3f7" stroke-width="1" />
      <text v-for="(g, i) in gridY" :key="'gyt'+i"
            :x="padL - 6" :y="g.y + 3" text-anchor="end" class="lc-axis">{{ g.label }}</text>

      <!-- X축 라벨 -->
      <text v-for="(m, i) in months" :key="'xt'+i"
            :x="xOf(i)" :y="height - padB + 14" text-anchor="middle" class="lc-axis">{{ shortYm(m) }}</text>

      <!-- 시리즈 라인 -->
      <g v-for="(s, si) in series" :key="'s'+si">
        <polyline
          v-if="s.points.length >= 2"
          :points="polyline(s.values)"
          fill="none" :stroke="s.color" stroke-width="2"
          stroke-linecap="round" stroke-linejoin="round" />
        <circle v-for="(p, pi) in s.points" :key="'p'+si+'-'+pi"
                :cx="xOf(p.idx)" :cy="yOf(p.value)" r="3.5" :fill="s.color" />
      </g>

      <!-- 호버 가이드 -->
      <line v-if="hoverIdx !== null"
            :x1="xOf(hoverIdx)" :x2="xOf(hoverIdx)"
            :y1="padT" :y2="height - padB"
            stroke="#cdd5e0" stroke-dasharray="3,3" />

      <!-- 마우스 캡처 영역 -->
      <rect :x="padL" :y="padT"
            :width="width - padL - padR" :height="height - padT - padB"
            fill="transparent"
            @mousemove="onMove" @mouseleave="hoverIdx = null" />
    </svg>

    <!-- 호버 툴팁 -->
    <div v-if="hoverIdx !== null && tooltipRows.length" class="lc-tip"
         :style="{ left: tipX + 'px' }">
      <div class="tip-ym">{{ months[hoverIdx] }}</div>
      <div v-for="r in tooltipRows" :key="r.label" class="tip-row">
        <span class="tip-dot" :style="{ background: r.color }"></span>
        <span class="tip-label">{{ r.label }}</span>
        <strong>{{ wonShort(r.value) }}</strong>
      </div>
    </div>

    <!-- 범례 -->
    <div class="lc-legend">
      <span v-for="s in series" :key="s.label" class="leg">
        <span class="dot" :style="{ background: s.color }"></span>{{ s.label }}
      </span>
    </div>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'
import { wonShort } from '../../../lib/api_v2.js'

const props = defineProps({
  months: { type: Array, required: true },        // ['2026-01', ...]
  series: { type: Array, required: true },        // [{label, color, values: [num|null,...]}]
  width:  { type: Number, default: 720 },
  height: { type: Number, default: 240 },
})

const padL = 56, padR = 16, padT = 12, padB = 24

const flatVals = computed(() => {
  const v = []
  for (const s of props.series) for (const x of s.values) if (x != null && Number.isFinite(x)) v.push(x)
  return v
})
const yMax = computed(() => {
  if (!flatVals.value.length) return 1
  const m = Math.max(...flatVals.value)
  return m <= 0 ? 1 : m * 1.1
})
const yMin = computed(() => {
  if (!flatVals.value.length) return 0
  const m = Math.min(...flatVals.value, 0)
  return m
})

const xOf = (i) => {
  const n = Math.max(1, props.months.length - 1)
  return padL + (props.width - padL - padR) * (i / n)
}
const yOf = (v) => {
  const span = (yMax.value - yMin.value) || 1
  return padT + (props.height - padT - padB) * (1 - (v - yMin.value) / span)
}

const series = computed(() => {
  return props.series.map(s => {
    const points = s.values
      .map((v, idx) => v == null || !Number.isFinite(v) ? null : { idx, value: v })
      .filter(Boolean)
    return { ...s, points }
  })
})

const polyline = (values) => {
  return values
    .map((v, i) => v == null ? null : `${xOf(i)},${yOf(v)}`)
    .filter(Boolean)
    .join(' ')
}

const gridY = computed(() => {
  const ticks = 4
  const span = yMax.value - yMin.value || 1
  return Array.from({ length: ticks + 1 }, (_, i) => {
    const v = yMin.value + (span * i) / ticks
    return { y: yOf(v), label: wonShort(v) }
  }).reverse()
})

const shortYm = (ym) => ym.slice(2).replace('-', '/')

// 호버
const hoverIdx = ref(null)
const tipX = ref(0)
function onMove(e) {
  const svg = e.currentTarget.ownerSVGElement
  const pt = svg.createSVGPoint()
  pt.x = e.clientX; pt.y = e.clientY
  const ctm = svg.getScreenCTM().inverse()
  const local = pt.matrixTransform(ctm)
  const n = Math.max(1, props.months.length - 1)
  const ratio = (local.x - padL) / (props.width - padL - padR)
  const idx = Math.round(ratio * n)
  hoverIdx.value = Math.max(0, Math.min(props.months.length - 1, idx))
  tipX.value = xOf(hoverIdx.value)
}

const tooltipRows = computed(() => {
  if (hoverIdx.value === null) return []
  return props.series
    .map(s => ({ label: s.label, color: s.color, value: s.values[hoverIdx.value] }))
    .filter(r => r.value != null && Number.isFinite(r.value))
})
</script>

<style scoped>
.lc-wrap { position: relative; width: 100%; }
.lc { width: 100%; height: auto; display: block; }
.lc-axis { fill: #8898aa; font-size: 10px; }
.lc-tip {
  position: absolute; top: 6px;
  transform: translateX(-50%);
  background: #32325d; color: #fff;
  border-radius: 6px; padding: 6px 8px;
  font-size: 11px; pointer-events: none;
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
  white-space: nowrap;
}
.tip-ym { font-weight: 700; margin-bottom: 4px; opacity: 0.9; }
.tip-row { display: flex; align-items: center; gap: 6px; padding: 1px 0; }
.tip-dot { width: 8px; height: 8px; border-radius: 50%; }
.tip-label { color: #cdd5e0; }

.lc-legend {
  display: flex; flex-wrap: wrap; gap: 0.75rem; justify-content: center;
  margin-top: 0.5rem; font-size: 0.85rem; color: #525f7f;
}
.lc-legend .dot { display:inline-block; width:10px; height:10px; border-radius:50%; margin-right:4px; vertical-align: middle; }
</style>
