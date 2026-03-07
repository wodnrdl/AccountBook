<template>
  <div v-cloak>
    <!-- Top Navbar -->
    <nav class="top-navbar">
      <div class="d-flex align-items-center gap-3">
        <!-- Year & Month (right aligned) -->
        <div class="d-flex gap-3 ms-auto">
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
        </div>
      </div>
      <!-- Refresh -->
      <div class="mt-2">
        <span class="refresh-btn" @click="dataReload">
          최신 업데이트 {{ lastUpdate }}
          <i class="fas fa-sync-alt ms-1"></i>
        </span>
      </div>
    </nav>

    <!-- Header -->
    <div class="header-bg">
      <div class="container-fluid">
        <div class="row g-3">
          <!-- 수입 -->
          <div class="col-6">
            <div class="card stats-card">
              <div class="card-body">
                <div class="card-title">수입</div>
                <template v-if="loading">
                  <div class="skeleton-line tall"></div>
                  <div class="skeleton-line short mt-2"></div>
                </template>
                <template v-else>
                  <div class="stat-value">{{ comma(salaryAmount) }}</div>
                  <div class="stat-compare">
                    전월 대비<br />
                    <span :class="salaryAmount - beforeSalaryAmount >= 0 ? 'text-success' : 'text-danger'">
                      <i class="fas" :class="salaryAmount - beforeSalaryAmount >= 0 ? 'fa-arrow-up' : 'fa-arrow-down'"></i>
                      {{ comma(Math.abs(salaryAmount - beforeSalaryAmount)) }}
                    </span>
                  </div>
                </template>
              </div>
            </div>
          </div>
          <!-- 지출 -->
          <div class="col-6">
            <div class="card stats-card">
              <div class="card-body">
                <div class="card-title">지출</div>
                <template v-if="loading">
                  <div class="skeleton-line tall"></div>
                  <div class="skeleton-line short mt-2"></div>
                </template>
                <template v-else>
                  <div class="stat-value">{{ comma(outAmount) }}</div>
                  <div class="stat-compare">
                    전월 대비<br />
                    <span :class="beforeOutAmount - outAmount >= 0 ? 'text-success' : 'text-danger'">
                      <i class="fas" :class="beforeOutAmount - outAmount >= 0 ? 'fa-arrow-down' : 'fa-arrow-up'"></i>
                      {{ comma(Math.abs(beforeOutAmount - outAmount)) }}
                    </span>
                  </div>
                </template>
              </div>
            </div>
          </div>
          <!-- 남은 생활비 -->
          <div class="col-6">
            <div class="card stats-card">
              <div class="card-body">
                <div class="card-title">이번달 생활비</div>
                <template v-if="loading">
                  <div class="skeleton-line tall"></div>
                  <div class="skeleton-line short mt-2"></div>
                </template>
                <template v-else>
                  <div class="stat-value">{{ comma(remainingBudget) }}</div>
                  <div class="stat-compare">
                    이월 생활비<br />
                    <span class="text-info">{{ comma(remainingBudget - 1000000) }}</span>
                  </div>
                </template>
              </div>
            </div>
          </div>
          <!-- 현재 남은돈 -->
          <div class="col-6">
            <div class="card stats-card">
              <div class="card-body">
                <div class="card-title">현재 남은돈</div>
                <template v-if="loading">
                  <div class="skeleton-line tall"></div>
                  <div class="skeleton-line short mt-2"></div>
                </template>
                <template v-else>
                  <div class="stat-value">{{ comma(remainingMoney) }}</div>
                  <div class="stat-compare">
                    전월 사용 대비<br />
                    <span :class="lifeAmount - beforeLifeAmount <= 0 ? 'text-success' : 'text-danger'">
                      <i class="fas" :class="lifeAmount - beforeLifeAmount <= 0 ? 'fa-arrow-down' : 'fa-arrow-up'"></i>
                      {{ comma(Math.abs(lifeAmount - beforeLifeAmount)) }}
                    </span>
                  </div>
                </template>
              </div>
            </div>
          </div>
          <!-- 저축 -->
          <div class="col-12">
            <div class="card stats-card">
              <div class="card-body">
                <div class="card-title">저축</div>
                <template v-if="loading">
                  <div class="skeleton-line tall"></div>
                  <div class="skeleton-line short mt-2"></div>
                </template>
                <template v-else>
                  <div class="stat-value">{{ comma(saveAmount) }}</div>
                  <div class="stat-compare">
                    전월 대비<br />
                    <span :class="saveAmount - beforeSaveAmount >= 0 ? 'text-success' : 'text-danger'">
                      <i class="fas" :class="saveAmount - beforeSaveAmount >= 0 ? 'fa-arrow-up' : 'fa-arrow-down'"></i>
                      {{ comma(Math.abs(saveAmount - beforeSaveAmount)) }}
                    </span>
                  </div>
                </template>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Charts Tab -->
    <div class="content-area">
      <ul class="nav nav-pills mb-3">
        <li class="nav-item">
          <a class="nav-link" :class="{ active: activeTab === 'calendar' }" href="#" @click.prevent="switchTab('calendar')">달력</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" :class="{ active: activeTab === 'column' }" href="#" @click.prevent="switchTab('column')">월별 차트</a>
        </li>
        <li class="nav-item">
          <a class="nav-link" :class="{ active: activeTab === 'pie' }" href="#" @click.prevent="switchTab('pie')">지출 분포</a>
        </li>
      </ul>
      <div class="card chart-card">
        <div class="card-body">
          <div v-show="activeTab === 'calendar'">
            <div id="calendar"></div>
          </div>
          <div v-show="activeTab === 'column'">
            <div id="chart-area" style="width: 100%; height: 300px"></div>
          </div>
          <div v-show="activeTab === 'pie'">
            <div id="pieChart" style="width: 100%; height: 300px"></div>
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
const years = [2025, 2026, 2027, 2028, 2029, 2030, 2031, 2032]
const lastUpdate = ref(formatNow())

const loading = ref(true)

const salaryAmount = ref(0)
const outAmount = ref(0)
const saveAmount = ref(0)
const lifeAmount = ref(0)
const beforeSalaryAmount = ref(0)
const beforeOutAmount = ref(0)
const beforeSaveAmount = ref(0)
const beforeLifeAmount = ref(0)
const remainingBudget = ref(0)
const remainingMoney = ref(0)
const beforeRemainingBudget = ref(0)
const beforeRemainingMoney = ref(0)

const activeTab = ref('calendar')
let pieChart = null
let columnChart = null
let calendarInstance = null
let calendarLoading = false
let chartInitialized = false
let pieInitialized = false

function formatNow() {
  const d = new Date()
  const pad = n => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}`
}

async function loadAllData() {
  loading.value = true
  const d = await fetchAllData(year.value, month.value)
  salaryAmount.value = d.salary_amount
  outAmount.value = d.out_amount
  saveAmount.value = d.save_amount
  lifeAmount.value = d.life_amount
  beforeSalaryAmount.value = d.before_salary_amount
  beforeOutAmount.value = d.before_out_amount
  beforeSaveAmount.value = d.before_save_amount
  beforeLifeAmount.value = d.before_life_amount
  remainingBudget.value = d.remaining_budget
  remainingMoney.value = d.remaining_money
  beforeRemainingBudget.value = d.before_remaining_budget
  beforeRemainingMoney.value = d.before_remaining_money
  loading.value = false
}

async function loadChartData(init, type) {
  const d = await fetchChartData(year.value, month.value)

  if (type === 'column') {
    const colData = {
      categories: ['1월','2월','3월','4월','5월','6월','7월','8월','9월','10월','11월','12월'],
      series: [{ name: '', data: d.month_all_amount }],
    }
    if (init) {
      const colEl = document.getElementById('chart-area')
      if (colEl) {
        columnChart = toastui.Chart.columnChart({
          el: colEl, data: colData,
          options: {
            chart: { width: 'auto', height: 'auto' },
            tooltip: { formatter: v => v.toLocaleString('ko-KR') + ' ₩' },
            legend: { visible: false },
            theme: { series: { barWidth: 10, colors: ['#ff0000'], areaOpacity: 1 } },
          },
        })
      }
    } else if (columnChart) {
      columnChart.setData(colData)
    }
  } else if (type === 'pie') {
    const today = `${year.value}년 ${month.value}월`
    const pieData = {
      categories: [today],
      series: d.pie_chart_data.map(e => ({ name: e.detailType, data: e.total_amount })),
    }
    if (init) {
      const pieEl = document.getElementById('pieChart')
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
    } else if (pieChart && pieData.series.length > 0) {
      pieChart.setData(pieData)
    }
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
    dayHeaderContent(info) {
      const d = info.date
      const weekdays = ['일', '월', '화', '수', '목', '금', '토']
      if (info.view.type === 'dayGridDay') {
        return `${d.getDate()}일 (${weekdays[d.getDay()]})`
      }
      return weekdays[d.getDay()]
    },
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
  if (!calendarInstance || calendarLoading) return
  calendarLoading = true
  calendarInstance.getEventSources().forEach(s => s.remove())
  const events = await fetchMonthData(y, m, [5, 6, 7])
  calendarInstance.getEventSources().forEach(s => s.remove())
  calendarInstance.addEventSource(events)
  calendarLoading = false
}

async function loadDayCalendar(clickedDate) {
  if (!calendarInstance || calendarLoading) return
  calendarLoading = true
  calendarInstance.getEventSources().forEach(s => s.remove())
  const d = new Date(clickedDate)
  const events = await fetchDayData(d.getFullYear(), d.getMonth() + 1, d.getDate(), [5, 6, 7])
  calendarInstance.getEventSources().forEach(s => s.remove())
  calendarInstance.addEventSource(events)
  calendarLoading = false
}

async function switchTab(tab) {
  activeTab.value = tab
  await nextTick()
  if (tab === 'calendar') {
    if (!calendarInstance) {
      createCalendar()
    } else {
      calendarInstance.updateSize()
    }
  } else if (tab === 'column') {
    if (!chartInitialized) {
      await loadChartData(true, 'column')
      chartInitialized = true
    } else {
      columnChart?.resize()
    }
  } else if (tab === 'pie') {
    if (!pieInitialized) {
      await loadChartData(true, 'pie')
      pieInitialized = true
    } else {
      pieChart?.resize()
    }
  }
}

function dataReload() {
  loadAllData()
  lastUpdate.value = formatNow()
  if (chartInitialized) loadChartData(false, 'column')
  if (pieInitialized) loadChartData(false, 'pie')
}

watch([year, month], () => {
  loadAllData()
  if (chartInitialized) loadChartData(false, 'column')
  if (pieInitialized) loadChartData(false, 'pie')
})

onMounted(async () => {
  await loadAllData()
  await nextTick()
  createCalendar()

  // 달력 로드 후 차트 백그라운드 초기화
  await loadChartData(true, 'column')
  chartInitialized = true
  await loadChartData(true, 'pie')
  pieInitialized = true
})
</script>
