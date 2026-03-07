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
          <!-- 등록/삭제 버튼 -->
          <div class="col-6">
            <button class="btn btn-danger w-100" :disabled="!hasCheckedRows" data-bs-toggle="modal" data-bs-target="#deleteModal">
              <i class="fas fa-minus me-1"></i>삭제
            </button>
          </div>
          <div class="col-6">
            <button class="btn btn-primary w-100" data-bs-toggle="modal" data-bs-target="#registerModal" @click="openRegisterModal">
              <i class="fas fa-plus me-1"></i>등록
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Grids -->
    <div class="content-area">
      <div class="row g-3">
        <div class="col-xl-4 col-lg-6" v-for="(cat, index) in categories" :key="cat.id">
          <div class="card grid-card">
            <div class="card-header">
              <h5 class="mb-0">{{ cat.title }}</h5>
            </div>
            <div :id="'grid_' + cat.id" style="min-height: 300px"></div>
          </div>
        </div>
      </div>
    </div>

    <!-- Register Modal -->
    <div class="modal fade" id="registerModal" tabindex="-1" data-bs-backdrop="static" data-bs-keyboard="false">
      <div class="modal-dialog modal-dialog-centered modal-lg">
        <div class="modal-content">
          <div class="modal-header">
            <h5 class="modal-title">등록</h5>
            <button type="button" class="btn-close" data-bs-dismiss="modal" :disabled="formSubmitting"></button>
          </div>
          <div class="modal-body">
            <!-- 입력 폼 -->
            <div class="row g-2 align-items-end">
              <div class="col">
                <label class="form-label form-label-sm mb-1">분류 <span class="text-danger">*</span></label>
                <select class="form-select form-select-sm" v-model="formInput.categoryIndex">
                  <option v-for="(cat, i) in categories" :key="cat.id" :value="i">{{ cat.title }}</option>
                </select>
              </div>
              <div class="col">
                <label class="form-label form-label-sm mb-1">항목 <span class="text-danger">*</span></label>
                <input type="text" class="form-control form-control-sm" v-model="formInput.detailType" placeholder="항목명" />
              </div>
            </div>
            <div class="row g-2 align-items-end mt-1">
              <div class="col">
                <label class="form-label form-label-sm mb-1">금액 <span class="text-danger">*</span></label>
                <input type="text" inputmode="decimal" pattern="[0-9,]*" class="form-control form-control-sm" :value="formatAmount(formInput.amount)" @input="onAmountInput" placeholder="금액" />
              </div>
              <div class="col" v-if="categories[formInput.categoryIndex]?.hasPayType">
                <label class="form-label form-label-sm mb-1">결제수단</label>
                <select class="form-select form-select-sm" v-model="formInput.payType">
                  <option value="카드">카드</option>
                  <option value="현금">현금</option>
                </select>
              </div>
              <div class="col">
                <label class="form-label form-label-sm mb-1">결제일</label>
                <input type="date" class="form-control form-control-sm" v-model="formInput.update_at" />
              </div>
            </div>
            <div class="row g-2 align-items-end mt-1">
              <div class="col-auto ms-auto">
                <button class="btn btn-sm btn-outline-primary" @click="formAddItem">추가</button>
              </div>
            </div>

            <!-- 추가된 목록 -->
            <div v-if="formItems.length > 0" class="mt-3">
              <table class="table table-sm table-bordered mb-0">
                <thead>
                  <tr>
                    <th>분류</th>
                    <th>항목</th>
                    <th>금액</th>
                    <th>결제</th>
                    <th>결제일</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(item, i) in formItems" :key="i">
                    <td>{{ item.categoryTitle }}</td>
                    <td>{{ item.detailType }}</td>
                    <td>{{ Number(item.amount).toLocaleString() }}</td>
                    <td>{{ item.payType || '-' }}</td>
                    <td>{{ item.update_at }}</td>
                    <td><button class="btn btn-sm btn-outline-danger py-0 px-1" @click="formItems.splice(i, 1)">X</button></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" id="registerCancel" class="btn btn-secondary" data-bs-dismiss="modal" :disabled="formSubmitting">취소</button>
            <button type="button" class="btn btn-primary" @click="formSubmit" :disabled="formSubmitting || formItems.length === 0">
              {{ formSubmitting ? '저장 중...' : '저장 (' + formItems.length + '건)' }}
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- Delete Modal -->
    <div class="modal fade" id="deleteModal" tabindex="-1" data-bs-backdrop="static" data-bs-keyboard="false">
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
            <button type="button" id="deleteCancel" class="btn btn-secondary" data-bs-dismiss="modal" :disabled="deleting">취소</button>
            <button type="button" class="btn btn-danger" @click="rowRemove" :disabled="deleting">
              {{ deleting ? '삭제 중...' : '삭제' }}
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, onMounted, nextTick } from 'vue'
import {
  comma, fetchAllData, fetchAllGridData,
  registerData, registerBulkData, deleteData,
} from '../lib/api.js'

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

const categories = [
  { id: 2, title: '수입', hasPayType: false },
  { id: 3, title: '저축/투자', hasPayType: false },
  { id: 5, title: '고정지출', hasPayType: true },
  { id: 6, title: '변동지출', hasPayType: true },
  { id: 7, title: '생활비', hasPayType: false },
  { id: 11, title: '기타수입', hasPayType: false },
]
const grids = ref([])
const hasCheckedRows = ref(false)

const formSubmitting = ref(false)
const formItems = ref([])
const formInput = ref({
  categoryIndex: 0,
  detailType: '',
  amount: '',
  payType: '카드',
  update_at: '',
  memo: '',
})

function formatAmount(val) {
  if (!val && val !== 0) return ''
  return Number(String(val).replace(/,/g, '')).toLocaleString('ko-KR')
}

function onAmountInput(e) {
  const raw = e.target.value.replace(/[^0-9]/g, '')
  formInput.value.amount = raw ? Number(raw) : ''
}

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

async function loadAllGrids() {
  const grouped = await fetchAllGridData(year.value, month.value)
  categories.forEach((cat, idx) => {
    if (grids.value[idx]) {
      grids.value[idx].resetData(grouped[cat.id] || [])
      grids.value[idx].restore()
    }
  })
}

function loadGridData(categoryId, idx) {
  // 단건 리로드용 (등록 후)
  fetchAllGridData(year.value, month.value).then(grouped => {
    if (grids.value[idx]) {
      grids.value[idx].resetData(grouped[categoryId] || [])
      grids.value[idx].restore()
    }
  })
}


function initGrids() {
  const Grid = tui.Grid
  Grid.setLanguage('ko')

  categories.forEach((cat, idx) => {
    const columns = [
      { name: 'detailType', header: '항목', width: 95, editor: 'text' },
      {
        name: 'amount', header: '금액', width: 95, editor: 'text',
        validation: { regExp: /^[0-9]+$/ },
        formatter: ({ value }) => {
          const str = String(value).replace(/^0+/, '') || '0'
          return Number(str).toLocaleString('ko-KR') + ' ₩'
        },
        onBeforeChange: (ev) => {
          const { nextValue } = ev
          if (!/^\d+$/.test(nextValue)) {
            alert('숫자만 입력해주세요.')
            ev.stop()
          } else if (/^0+/.test(nextValue)) {
            alert('첫자리는 0이 될 수 없습니다.')
            ev.stop()
          }
        },
      },
    ]

    if (cat.hasPayType) {
      columns.push({ name: 'payType', header: '결제수단', width: 95, editor: 'text' })
    }

    columns.push({
      name: 'update_at', header: '결제일', width: 95,
      sortingType: 'asc', sortable: true,
      editor: { type: 'datePicker', options: { format: 'yyyy-MM-dd' } },
    })
    columns.push({ name: 'memo', header: '메모', width: 95, editor: 'text' })
    columns.push({ name: 'row_id', hidden: true })

    const summary = {
      height: 30,
      position: 'bottom',
      columnContent: {
        amount: {
          template: (valueMap) => `TOTAL<br/>${Number(valueMap.sum).toLocaleString('ko-KR')} ₩`,
        },
      },
    }

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
      if (skipGridEvents) return
      const rowKey = event.changes[0].rowKey
      const row = grid.getData().find(r => r.rowKey === rowKey)

      const model = {
        detailType: row.detailType,
        amount: row.amount,
        update_at: row.update_at,
        memo: row.memo,
        row_id: row.row_id || 0,
      }

      if (cat.hasPayType) {
        model.payType = row.payType
      }

      // 필수값 체크
      if (!model.detailType || !model.amount || model.amount === 0 || !model.update_at) return

      model.rowKey = rowKey
      model.category_id = cat.id
      model.year = year.value
      model.month = month.value
      rowRegisterDB(model, idx)
    })

    grid.on('check', () => updateCheckedState())
    grid.on('uncheck', () => updateCheckedState())
    grid.on('checkAll', () => updateCheckedState())
    grid.on('uncheckAll', () => updateCheckedState())

    grids.value.push(grid)
  })
  loadAllGrids()
}

async function rowRegisterDB(model, gridIdx) {
  try {
    const response = await registerData(model)

    if (response.id) {
      const rawData = grids.value[gridIdx].store.data.rawData
      for (let i = 0; i < rawData.length; i++) {
        if (rawData[i].rowKey === model.rowKey) {
          rawData[i].row_id = response.id
          break
        }
      }
    }

    await loadAllData()
  } catch (err) {
    console.error('Error:', err)
    alert('등록 오류: ' + err.message)
  }
}

function openRegisterModal() {
  formItems.value = []
  formInput.value = {
    categoryIndex: 0,
    detailType: '',
    amount: '',
    payType: '카드',
    update_at: new Date().toISOString().substring(0, 10),
    memo: '',
  }
}

function formAddItem() {
  const fi = formInput.value
  if (!fi.detailType) return alert('항목명을 입력해주세요.')
  if (!fi.amount || fi.amount <= 0) return alert('금액을 입력해주세요.')

  const cat = categories[fi.categoryIndex]
  formItems.value.push({
    ...fi,
    categoryId: cat.id,
    categoryTitle: cat.title,
    payType: cat.hasPayType ? fi.payType : '',
  })
  formInput.value = {
    categoryIndex: fi.categoryIndex,
    detailType: '',
    amount: '',
    payType: fi.payType,
    update_at: fi.update_at,
    memo: '',
  }
}

async function formSubmit() {
  if (formSubmitting.value || formItems.value.length === 0) return
  formSubmitting.value = true

  try {
    await registerBulkData(formItems.value)
    await loadAllData()
    await loadAllGrids()
    const registerModal = bootstrap.Modal.getInstance(document.getElementById('registerModal'))
    if (registerModal) registerModal.hide()
  } catch (err) {
    alert('등록 오류: ' + err.message)
  } finally {
    formSubmitting.value = false
  }
}

const deleting = ref(false)
let skipGridEvents = false

function updateCheckedState() {
  hasCheckedRows.value = grids.value.some(g => g.getCheckedRows().length > 0)
}

async function rowRemove() {
  if (deleting.value) return
  deleting.value = true

  try {
    const allRowIds = []
    grids.value.forEach(grid => {
      const checked = grid.getCheckedRows()
      checked.forEach(r => {
        if (r.row_id && r.row_id !== 0) allRowIds.push(r.row_id)
      })
    })
    if (allRowIds.length > 0) {
      await deleteData(allRowIds)
    }
    skipGridEvents = true
    grids.value.forEach(grid => grid.removeCheckedRows())
    skipGridEvents = false
    const deleteModal = bootstrap.Modal.getInstance(document.getElementById('deleteModal'))
    if (deleteModal) deleteModal.hide()
    hasCheckedRows.value = false
    await loadAllData()
  } catch (err) {
    alert('삭제 오류: ' + err.message)
  } finally {
    deleting.value = false
  }
}

function dataReload() {
  loadAllData()
  loadAllGrids()
  lastUpdate.value = formatNow()
}

watch([year, month], () => {
  loadAllData()
  loadAllGrids()
})

onMounted(async () => {
  loadAllData()
  await nextTick()
  initGrids()
})
</script>
