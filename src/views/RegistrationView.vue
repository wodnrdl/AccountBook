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
                  전월 대비<br />
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
                  전월 대비<br />
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
                  전월 대비<br />
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
                  전월 대비<br />
                  <span :class="saveAmount - beforeSaveAmount >= 0 ? 'text-success' : 'text-danger'">
                    <i class="fas" :class="saveAmount - beforeSaveAmount >= 0 ? 'fa-arrow-up' : 'fa-arrow-down'"></i>
                    {{ comma(saveAmount - beforeSaveAmount) }}
                  </span>
                </div>
              </div>
            </div>
          </div>
          <!-- 남은돈 -->
          <div class="col-xl-2 col-lg-4 col-md-6">
            <div class="card stats-card">
              <div class="card-body">
                <div class="card-title">현재 남은돈</div>
                <div class="stat-value">{{ comma(salaryAllAmount) }}</div>
                <div class="stat-compare">
                  전월 대비<br />
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

    <!-- Grids -->
    <div class="content-area">
      <div class="row g-3">
        <div class="col-xl-4 col-lg-6" v-for="(cat, index) in categories" :key="cat.id">
          <div class="card grid-card">
            <div class="card-header d-flex justify-content-between align-items-center">
              <h5 class="mb-0">{{ cat.title }}</h5>
              <div>
                <button class="btn btn-sm btn-danger me-1" data-bs-toggle="modal" data-bs-target="#deleteModal"
                        @click="gridRemoveId = index">삭제-</button>
                <button class="btn btn-sm btn-primary" @click="rowRegister(index)">등록+</button>
              </div>
            </div>
            <div :id="'grid_' + cat.id" style="min-height: 300px"></div>
          </div>
        </div>
      </div>
    </div>

    <!-- Delete Modal -->
    <div class="modal fade" id="deleteModal" tabindex="-1">
      <div class="modal-dialog modal-dialog-centered">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">삭제</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
          </div>
          <div class="modal-body">
            체크한 값들이 삭제됩니다.<br />복구 불가
          </div>
          <div class="modal-footer">
            <button type="button" id="deleteCancel" class="btn btn-secondary" data-bs-dismiss="modal">취소</button>
            <button type="button" class="btn btn-danger" @click="rowRemove">삭제</button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, onMounted, nextTick } from 'vue'
import {
  comma, fetchAllData, fetchCategories, fetchData,
  registerData, deleteData,
} from '../lib/api.js'

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

const categories = ref([])
const categoryNavs = ref([])
const grids = ref([])
const gridRemoveId = ref(0)

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

async function loadGridData(categoryId, idx) {
  const data = await fetchData(year.value, month.value, categoryId)
  if (grids.value[idx]) {
    grids.value[idx].resetData(data)
    grids.value[idx].restore()
  }
}

function updateSummary(response) {
  salaryAmount.value = response.salary_amount
  outAmount.value = response.out_amount
  saveAmount.value = response.save_amount
  lifeAmount.value = response.life_amount
  beforeSalaryAmount.value = response.before_salary_amount
  beforeOutAmount.value = response.before_out_amount
  beforeSaveAmount.value = response.before_save_amount
  beforeLifeAmount.value = response.before_life_amount
  salaryAllAmount.value = response.salary_all_amount
  beforeSalaryAllAmount.value = response.before_salary_all_amount
}

async function initGrids() {
  const { categories: cats, categoryNavs: navs } = await fetchCategories()
  categories.value = cats
  categoryNavs.value = navs

  await nextTick()

  const Grid = tui.Grid
  Grid.setLanguage('ko')

  cats.forEach((cat, idx) => {
    const navItems = navs.filter(n => Number(n.category_id) === cat.id)
    const columns = []
    let summary = {}

    navItems.forEach(item => {
      const info = { name: item.name, header: item.title, width: 95 }

      if (item.title === '금액') {
        info.validation = { regExp: /^[0-9]+$/ }
        info.formatter = ({ value }) => {
          const str = String(value).replace(/^0+/, '') || '0'
          return Number(str).toLocaleString('ko-KR') + ' ₩'
        }
        summary = {
          height: 30,
          position: 'bottom',
          columnContent: {
            [item.name]: {
              template: (valueMap) => {
                return `TOTAL<br/>${Number(valueMap.sum).toLocaleString('ko-KR')} ₩`
              },
            },
          },
        }
        info.onBeforeChange = (ev) => {
          const { nextValue } = ev
          if (!/^\d+$/.test(nextValue)) {
            alert('숫자만 입력해주세요.')
            ev.stop()
          } else if (/^0+/.test(nextValue)) {
            alert('첫자리는 0이 될 수 없습니다.')
            ev.stop()
          }
        }
      } else if (item.title === '결제일') {
        info.sortingType = 'asc'
        info.sortable = true
        info.editor = {
          type: 'datePicker',
          options: { format: 'yyyy-MM-dd' },
        }
      }

      if (item.option) {
        try {
          JSON.parse(item.option).forEach(opt => {
            Object.keys(opt).forEach(k => { info[k] = opt[k] })
          })
        } catch (e) { /* ignore */ }
      }

      columns.push(info)
    })

    columns.push({ name: 'row_id', hidden: true })

    const el = document.getElementById('grid_' + cat.id)
    if (!el) return

    const grid = new Grid({
      el,
      scrollX: true,
      scrollY: true,
      bodyHeight: 250,
      rowHeaders: [
        {
          type: 'checkbox',
          header: `<label for="all-checkbox-${cat.id}" class="checkbox mb-0">
            <input type="checkbox" id="all-checkbox-${cat.id}" class="hidden-input" name="_checked" />
            <span class="custom-input"></span>
          </label>`,
        },
        { type: 'rowNum' },
      ],
      editingEvent: 'click',
      columns,
      pageOptions: { type: 'scroll', perPage: 30 },
      columnOptions: { resizable: true, frozenCount: 1, frozenBorderWidth: 2 },
      summary,
    })

    grid.on('afterChange', (event) => {
      const categoryId = cat.id
      const changes = event.changes
      const rowKey = changes[0].rowKey
      const rowData = Object.entries(grid.getData().find(row => row.rowKey === rowKey))

      let i = 0
      const model = {}

      // 저축, 투자, 수입 (payType 없는 카테고리)
      if ([2, 3, 7, 11].includes(categoryId)) {
        i = 1
        for (const [, value] of rowData) {
          if (i === 1) model.detailType = value
          else if (i === 2) model.amount = value
          else if (i === 3) model.update_at = value
          else if (i === 4) model.memo = value
          if (i > 3) break
          if (value === '' || value === null || value === undefined || model.amount === 0) break
          i++
        }
        model.row_id = rowData[4]?.[1] || 0
      } else {
        for (const [, value] of rowData) {
          if (i === 0) model.detailType = value
          else if (i === 1) model.amount = value
          else if (i === 2) model.payType = value
          else if (i === 3) model.update_at = value
          else if (i === 4) model.memo = value
          if (i > 3) break
          if (value === '' || value === null || value === undefined || model.amount === 0) break
          i++
        }
        model.row_id = rowData[5]?.[1] || 0
      }

      if (i === 4) {
        model.rowKey = rowKey
        model.category_id = categoryId
        model.year = year.value
        model.month = month.value
        rowRegisterDB(model, idx)
      }
    })

    loadGridData(cat.id, idx)
    grids.value.push(grid)
  })
}

async function rowRegisterDB(model, gridIdx) {
  try {
    const response = await registerData(model)

    // row_id 업데이트
    if (response.id) {
      const rawData = grids.value[gridIdx].store.data.rawData
      for (let i = 0; i < rawData.length; i++) {
        if (rawData[i].rowKey === model.rowKey) {
          rawData[i].row_id = response.id
          break
        }
      }
    }

    updateSummary(response)
  } catch (err) {
    console.error('Error:', err)
    alert('등록 오류: ' + err.message)
  }
}

function rowRegister(index) {
  const cat = categories.value[index]
  const data = {}
  const noPayType = [2, 3, 7, 11].includes(cat.id)

  grids.value[index].getColumns().forEach((item, colIdx) => {
    if (noPayType) {
      if (colIdx === 1 || colIdx === 4) data[item.name] = 0
      else if (colIdx === 2) data[item.name] = new Date().toISOString().substring(0, 10)
      else data[item.name] = ''
    } else {
      if (colIdx === 1 || colIdx === 5) data[item.name] = 0
      else if (colIdx === 3) data[item.name] = new Date().toISOString().substring(0, 10)
      else data[item.name] = ''
    }
  })

  grids.value[index].prependRow(data, { at: grids.value[index].getRowCount() })
  grids.value[index].enable()
}

async function rowRemove() {
  const grid = grids.value[gridRemoveId.value]
  const checked = grid.getCheckedRows()
  if (checked.length === 0) return

  const rowIds = checked.map(r => r.row_id).filter(id => id && id !== 0)
  if (rowIds.length > 0) {
    await deleteData(rowIds)
  }
  grid.removeCheckedRows()
  document.getElementById('deleteCancel')?.click()
  await loadAllData()
}

function dataReload() {
  loadAllData()
  lastUpdate.value = formatNow()
  categories.value.forEach((cat, idx) => {
    loadGridData(cat.id, idx)
  })
}

watch([year, month], () => {
  loadAllData()
  categories.value.forEach((cat, idx) => {
    loadGridData(cat.id, idx)
  })
})

onMounted(() => {
  loadAllData()
  initGrids()
})
</script>
