<template>
  <div v-cloak>
    <!-- Top Navbar -->
    <nav class="top-navbar d-flex align-items-center flex-wrap gap-3">
      <!-- Year -->
      <div class="dropdown">
        <a class="dropdown-toggle" href="#" data-bs-toggle="dropdown">
          <i class="fas fa-calendar-alt"></i> {{ year }}년
        </a>
        <ul class="dropdown-menu">
          <li v-for="y in years" :key="y">
            <a class="dropdown-item" href="#" @click.prevent="year = y">{{ y }}년</a>
          </li>
        </ul>
      </div>

      <!-- Month -->
      <div class="dropdown">
        <a class="dropdown-toggle" href="#" data-bs-toggle="dropdown">
          <i class="fas fa-calendar-alt"></i> {{ month }}월
        </a>
        <ul class="dropdown-menu">
          <li v-for="m in 12" :key="m">
            <a class="dropdown-item" href="#" @click.prevent="month = m">{{ m }}월</a>
          </li>
        </ul>
      </div>

      <!-- Refresh -->
      <span class="refresh-btn ms-auto" @click="dataReload">
        최신 업데이트 {{ lastUpdate }}
        <i class="fas fa-sync-alt ms-1"></i>
      </span>
    </nav>

    <!-- Header -->
    <div class="header-bg">
      <div class="container-fluid">
        <div class="row g-3">
          <!-- 수입 -->
          <div class="col-xl-2 col-lg-4 col-md-6">
            <div class="card stats-card">
              <div class="card-body">
                <div class="card-title">수입</div>
                <div class="stat-value">{{ comma(salaryAmount) }}</div>
                <div class="stat-compare">
                  전월 대비 수입<br />
                  <span :class="salaryAmount - beforeSalaryAmount >= 0 ? 'text-success' : 'text-danger'">
                    <i class="fas" :class="salaryAmount - beforeSalaryAmount >= 0 ? 'fa-arrow-up' : 'fa-arrow-down'"></i>
                    {{ comma(salaryAmount - beforeSalaryAmount) }}
                  </span>
                </div>
              </div>
            </div>
          </div>
          <!-- 지출 -->
          <div class="col-xl-2 col-lg-4 col-md-6">
            <div class="card stats-card">
              <div class="card-body">
                <div class="card-title">지출</div>
                <div class="stat-value">{{ comma(outAmount) }}</div>
                <div class="stat-compare">
                  전월 대비 지출<br />
                  <span :class="beforeOutAmount - outAmount >= 0 ? 'text-success' : 'text-danger'">
                    <i class="fas" :class="beforeOutAmount - outAmount >= 0 ? 'fa-arrow-down' : 'fa-arrow-up'"></i>
                    {{ comma(beforeOutAmount - outAmount) }}
                  </span>
                </div>
              </div>
            </div>
          </div>
          <!-- 남은 생활비 -->
          <div class="col-xl-2 col-lg-4 col-md-6">
            <div class="card stats-card">
              <div class="card-body">
                <div class="card-title">남은 생활비</div>
                <div class="stat-value">{{ comma(1000000 - lifeAmount) }}</div>
                <div class="stat-compare">
                  전월 생활비 대비<br />
                  <span :class="lifeAmount - beforeLifeAmount >= 0 ? 'text-danger' : 'text-success'">
                    <i class="fas" :class="lifeAmount - beforeLifeAmount >= 0 ? 'fa-arrow-up' : 'fa-arrow-down'"></i>
                    {{ comma(lifeAmount - beforeLifeAmount) }}
                  </span>
                </div>
              </div>
            </div>
          </div>
          <!-- 저축 -->
          <div class="col-xl-2 col-lg-4 col-md-6">
            <div class="card stats-card">
              <div class="card-body">
                <div class="card-title">저축</div>
                <div class="stat-value">{{ comma(saveAmount) }}</div>
                <div class="stat-compare">
                  전월 저축 대비<br />
                  <span :class="saveAmount - beforeSaveAmount >= 0 ? 'text-success' : 'text-danger'">
                    <i class="fas" :class="saveAmount - beforeSaveAmount >= 0 ? 'fa-arrow-up' : 'fa-arrow-down'"></i>
                    {{ comma(saveAmount - beforeSaveAmount) }}
                  </span>
                </div>
              </div>
            </div>
          </div>
          <!-- 현재 남은돈 -->
          <div class="col-xl-2 col-lg-4 col-md-6">
            <div class="card stats-card">
              <div class="card-body">
                <div class="card-title">현재 남은돈</div>
                <div class="stat-value">{{ comma(salaryAllAmount) }}</div>
                <div class="stat-compare">
                  전월 남은돈 대비<br />
                  <span :class="salaryAllAmount - beforeSalaryAllAmount >= 0 ? 'text-success' : 'text-danger'">
                    <i class="fas" :class="salaryAllAmount - beforeSalaryAllAmount >= 0 ? 'fa-arrow-up' : 'fa-arrow-down'"></i>
                    {{ comma(salaryAllAmount - beforeSalaryAllAmount) }}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Charts -->
    <div class="content-area">
      <div class="row g-3">
        <!-- Column Chart -->
        <div class="col-xl-4">
          <div class="card chart-card">
            <div class="card-header">
              <h6>{{ year }}년 사용량</h6>
              <h2>지출</h2>
            </div>
            <div class="card-body">
              <div id="chart-area" style="width: 100%; height: 300px"></div>
            </div>
          </div>
        </div>
        <!-- Pie Chart -->
        <div class="col-xl-4">
          <div class="card chart-card">
            <div class="card-header">
              <h6>{{ year }}년 {{ month }}월</h6>
              <h2>지출 분포</h2>
            </div>
            <div class="card-body">
              <div id="pieChart" style="width: 100%; height: 300px"></div>
            </div>
          </div>
        </div>
        <!-- Calendar -->
        <div class="col-xl-4">
          <div class="card chart-card">
            <div class="card-header">
              <h6>일자별 조회</h6>
              <h2>달력</h2>
            </div>
            <div class="card-body">
              <div id="calendar"></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, onMounted, nextTick } from 'vue'
import { comma, fetchAllData, fetchChartData, fetchMonthData, fetchDayData } from '../lib/api.js'

const now = new Date()
const year = ref(now.getFullYear())
const month = ref(now.getMonth() + 1)
const years = [2024, 2025, 2026, 2027]
const lastUpdate = ref(formatNow())

const salaryAmount = ref(0)
const outAmount = ref(0)
const saveAmount = ref(0)
const lifeAmount = ref(0)
const beforeSalaryAmount = ref(0)
const beforeOutAmount = ref(0)
const beforeSaveAmount = ref(0)
const beforeLifeAmount = ref(0)
const salaryAllAmount = ref(0)
const beforeSalaryAllAmount = ref(0)

let pieChart = null
let columnChart = null
let calendarInstance = null

function formatNow() {
  const d = new Date()
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
}

async function loadAllData() {
  const d = await fetchAllData(year.value, month.value)
  salaryAmount.value = d.salary_amount
  outAmount.value = d.out_amount
  saveAmount.value = d.save_amount
  lifeAmount.value = d.life_amount
  beforeSalaryAmount.value = d.before_salary_amount
  beforeOutAmount.value = d.before_out_amount
  beforeSaveAmount.value = d.before_save_amount
  beforeLifeAmount.value = d.before_life_amount
  salaryAllAmount.value = d.salary_all_amount
  beforeSalaryAllAmount.value = d.before_salary_all_amount
}

async function loadChartData(init) {
  const d = await fetchChartData(year.value, month.value)
  const today = `${year.value}년 ${month.value}월`

  const pieData = {
    categories: [today],
    series: d.pie_chart_data.map(e => ({ name: e.detailType, data: e.total_amount })),
  }

  const colData = {
    categories: ['1월','2월','3월','4월','5월','6월','7월','8월','9월','10월','11월','12월'],
    series: [{ name: '', data: d.month_all_amount }],
  }

  if (init) {
    const pieEl = document.getElementById('pieChart')
    const colEl = document.getElementById('chart-area')
    if (pieEl && pieData.series.length > 0) {
      pieChart = toastui.Chart.pieChart({
        el: pieEl, data: pieData,
        options: {
          chart: { width: 'auto', height: 'auto' },
          tooltip: { formatter: v => v.toLocaleString('ko-KR') + ' ₩' },
          legend: { align: 'bottom' },
        },
      })
    }
    if (colEl) {
      columnChart = toastui.Chart.columnChart({
        el: colEl, data: colData,
        options: {
          chart: { width: 'auto', height: 'auto' },
          tooltip: { formatter: v => v.toLocaleString('ko-KR') + ' ₩' },
          legend: { visible: false },
          theme: {
            series: {
              barWidth: 10, colors: ['#ff0000'], areaOpacity: 1,
            },
          },
        },
      })
    }
  } else {
    if (pieChart && pieData.series.length > 0) pieChart.setData(pieData)
    if (columnChart) columnChart.setData(colData)
  }
}

function createCalendar() {
  const calendarEl = document.getElementById('calendar')
  if (!calendarEl) return

  calendarInstance = new FullCalendar.Calendar(calendarEl, {
    timeZone: 'Asia/Seoul',
    initialView: 'dayGridMonth',
    dayHeaderFormat: { weekday: 'short' },
    titleFormat: { year: 'numeric', month: 'long' },
    locale: 'ko',
    headerToolbar: { center: 'title', left: 'dayGridMonth' },
    buttonText: { prev: '이전', next: '다음', today: '오늘', month: '월', week: '주', day: '일' },
    navLinks: true,
    datesSet(info) {
      calendarInstance.getEventSources().forEach(s => s.remove())
      if (info.view.type === 'dayGridDay') {
        loadDayCalendar(info.startStr)
      } else {
        const startDate = new Date(info.startStr)
        const startDay = startDate.getDate()
        if (startDay === 1) {
          loadCalendar(startDate.getFullYear(), startDate.getMonth() + 1)
        } else {
          loadCalendar(startDate.getFullYear(), startDate.getMonth() + 2)
        }
      }
    },
    views: { dayGrid: { type: 'dayGridDay' } },
    eventContent(info) {
      const el = document.createElement('div')
      if (info.view.type === 'dayGridDay') {
        const ep = info.event.extendedProps
        el.innerText = `${info.event.title} - ${ep.amount || ''} / ${ep.memo || ''}`
      } else {
        el.innerText = info.event.title
      }
      return { domNodes: [el] }
    },
  })
  calendarInstance.render()
}

async function loadCalendar(y, m) {
  const events = await fetchMonthData(y, m, [5, 6, 7])
  if (calendarInstance) calendarInstance.addEventSource(events)
}

async function loadDayCalendar(clickedDate) {
  const d = new Date(clickedDate)
  const events = await fetchDayData(d.getFullYear(), d.getMonth() + 1, d.getDate(), [5, 6, 7])
  if (calendarInstance) calendarInstance.addEventSource(events)
}

function dataReload() {
  loadAllData()
  loadChartData(false)
  lastUpdate.value = formatNow()
}

watch([year, month], () => {
  loadAllData()
  loadChartData(false)
})

onMounted(async () => {
  await loadAllData()
  await nextTick()
  await loadChartData(true)
  createCalendar()
})
</script>
