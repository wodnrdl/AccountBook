import { supabase } from './supabase.js'

// 숫자 콤마 포맷
export function comma(number) {
  return Number(number).toLocaleString('ko-KR') + ' ₩'
}

// 월의 첫날, 마지막날
function getMonthRange(year, month) {
  const y = Number(year)
  const m = Number(month)
  const first = `${y}-${String(m).padStart(2, '0')}-01 00:00:00`
  const lastDay = new Date(y, m, 0).getDate()
  const last = `${y}-${String(m).padStart(2, '0')}-${String(lastDay).padStart(2, '0')} 23:59:59`
  return { first, last }
}

// 카테고리별 합산 헬퍼
function sumByCategory(rows, categoryIds) {
  return rows
    .filter(r => categoryIds.includes(r.category_id))
    .reduce((s, r) => s + Number(r.amount), 0)
}

// 생활비 누적 설정 (2026년 2월 남은 생활비 4,287원, 매월 +1,000,000원)
const LIFE_START_YEAR = 2026
const LIFE_START_MONTH = 2
const LIFE_INITIAL = 4287
const LIFE_MONTHLY = 1000000

// 전체 요약 데이터 가져오기 (3쿼리)
export async function fetchAllData(year, month) {
  let y = Number(year)
  let pm = Number(month) - 1
  if (pm === 0) { pm = 12; y-- }

  const curRange = getMonthRange(year, month)
  const prevRange = getMonthRange(y, pm)

  const [curRes, prevRes, lifeAllRes] = await Promise.all([
    supabase.from('row_data').select('category_id, amount')
      .in('category_id', [2, 3, 5, 6, 7, 11])
      .gte('update_at', curRange.first).lte('update_at', curRange.last),
    supabase.from('row_data').select('category_id, amount')
      .in('category_id', [2, 3, 5, 6, 7, 11])
      .gte('update_at', prevRange.first).lte('update_at', prevRange.last),
    supabase.from('row_data').select('amount, update_at')
      .eq('category_id', 7)
      .gte('update_at', `${LIFE_START_YEAR}-${String(LIFE_START_MONTH).padStart(2, '0')}-01 00:00:00`)
      .lte('update_at', curRange.last),
  ])

  const cur = curRes.data || []
  const prev = prevRes.data || []
  const lifeAll = lifeAllRes.data || []

  // 월별 생활비 사용액 그룹핑
  const monthlyExpenses = {}
  lifeAll.forEach(r => {
    const key = r.update_at.substring(0, 7)
    monthlyExpenses[key] = (monthlyExpenses[key] || 0) + Number(r.amount)
  })

  // 시작월부터 월별로 이월 계산
  let carryOver = LIFE_INITIAL
  let sy = LIFE_START_YEAR, sm = LIFE_START_MONTH
  let beforeRemainingBudget = 0
  let beforeRemainingMoney = 0

  while (sy < Number(year) || (sy === Number(year) && sm < Number(month))) {
    const key = `${sy}-${String(sm).padStart(2, '0')}`
    const spent = monthlyExpenses[key] || 0
    const remaining = carryOver - spent

    // 전월 값 저장
    if (sy === y && sm === pm) {
      beforeRemainingBudget = carryOver
      beforeRemainingMoney = remaining
    }

    // 다음달 남은 생활비 = 이번달 남은돈 + 100만원
    carryOver = remaining + LIFE_MONTHLY
    sm++
    if (sm > 12) { sm = 1; sy++ }
  }

  const remainingBudget = carryOver
  const curMonthKey = `${year}-${String(month).padStart(2, '0')}`
  const remainingMoney = remainingBudget - (monthlyExpenses[curMonthKey] || 0)

  return {
    salary_amount: sumByCategory(cur, [2, 11]),
    out_amount: sumByCategory(cur, [5, 6, 7]),
    save_amount: sumByCategory(cur, [3]),
    life_amount: sumByCategory(cur, [7]),
    before_salary_amount: sumByCategory(prev, [2, 11]),
    before_out_amount: sumByCategory(prev, [5, 6, 7]),
    before_save_amount: sumByCategory(prev, [3]),
    before_life_amount: sumByCategory(prev, [7]),
    remaining_budget: remainingBudget,
    remaining_money: remainingMoney,
    before_remaining_budget: beforeRemainingBudget,
    before_remaining_money: beforeRemainingMoney,
  }
}

// 차트 데이터 가져오기
export async function fetchChartData(year, month) {
  const { first, last } = getMonthRange(year, month)

  // 파이차트: 카테고리별 지출 합계
  const { data: pieRaw } = await supabase
    .from('row_data')
    .select('category_id, detail_type, amount')
    .in('category_id', [5, 6, 7])
    .gte('update_at', first)
    .lte('update_at', last)

  // detail_type별 그룹핑
  const pieMap = {}
  ;(pieRaw || []).forEach(r => {
    const key = r.detail_type || 'etc'
    pieMap[key] = (pieMap[key] || 0) + Number(r.amount)
  })
  const pie_chart_data = Object.entries(pieMap).map(([k, v]) => ({
    detailType: k,
    total_amount: v,
  }))

  // 월별 지출 합계 (1~12월)
  const monthlyTotals = {}
  for (let m = 1; m <= 12; m++) {
    monthlyTotals[m] = 0
  }

  const yearStart = `${year}-01-01 00:00:00`
  const yearEnd = `${year}-12-31 23:59:59`
  const { data: yearData } = await supabase
    .from('row_data')
    .select('amount, update_at')
    .in('category_id', [5, 6, 7])
    .gte('update_at', yearStart)
    .lte('update_at', yearEnd)

  ;(yearData || []).forEach(r => {
    const m = new Date(r.update_at).getMonth() + 1
    monthlyTotals[m] += Number(r.amount)
  })

  return { pie_chart_data, month_all_amount: Object.values(monthlyTotals) }
}

// 카테고리별 월 데이터 가져오기 (단건)
export async function fetchData(year, month, categoryId) {
  const all = await fetchAllGridData(year, month)
  return all[categoryId] || []
}

// 전체 그리드 데이터 한번에 가져오기 (1쿼리)
export async function fetchAllGridData(year, month) {
  const { first, last } = getMonthRange(year, month)
  const { data } = await supabase
    .from('row_data')
    .select('id, category_id, row_key, detail_type, amount, pay_type, update_at, memo')
    .in('category_id', [2, 3, 5, 6, 7, 11])
    .gte('update_at', first)
    .lte('update_at', last)
    .order('update_at', { ascending: false })

  const grouped = {}
  ;(data || []).forEach(r => {
    if (!grouped[r.category_id]) grouped[r.category_id] = []
    grouped[r.category_id].push({
      row_id: r.id,
      rowKey: r.row_key,
      detailType: r.detail_type,
      amount: r.amount,
      payType: r.pay_type,
      update_at: r.update_at ? r.update_at.substring(0, 10) : '',
      memo: r.memo,
    })
  })
  return grouped
}

// 캘린더 월별 데이터
export async function fetchMonthData(year, month, categoryIds) {
  const { first, last } = getMonthRange(year, month)
  const { data } = await supabase
    .from('row_data')
    .select('amount, update_at')
    .in('category_id', categoryIds)
    .gte('update_at', first)
    .lte('update_at', last)

  // 날짜별 그룹핑
  const dayMap = {}
  ;(data || []).forEach(r => {
    const day = r.update_at.substring(0, 10)
    dayMap[day] = (dayMap[day] || 0) + Number(r.amount)
  })

  return Object.entries(dayMap).map(([date, total]) => ({
    title: Number(total).toLocaleString('ko-KR'),
    date,
  }))
}

// 캘린더 일별 데이터
export async function fetchDayData(year, month, day, categoryIds) {
  const dateStr = `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`
  const start = `${dateStr} 00:00:00`
  const end = `${dateStr} 23:59:59`

  const { data } = await supabase
    .from('row_data')
    .select('id, row_key, detail_type, amount, pay_type, update_at, memo')
    .in('category_id', categoryIds)
    .gte('update_at', start)
    .lte('update_at', end)

  return (data || []).map(r => ({
    title: r.detail_type,
    start: r.update_at.substring(0, 10),
    amount: Number(r.amount).toLocaleString('ko-KR'),
    memo: r.memo || '',
    row_id: r.id,
    rowKey: r.row_key,
    payType: r.pay_type,
  }))
}

// 데이터 등록/수정 (단건)
export async function registerData(model) {
  const now = new Date().toISOString()
  const row = {
    category_id: model.category_id,
    row_key: model.rowKey,
    detail_type: model.detailType,
    amount: Number(model.amount),
    update_at: model.update_at,
    memo: model.memo || '',
  }
  if (model.payType !== undefined) {
    row.pay_type = model.payType
  }

  let id
  if (!model.row_id || model.row_id === 0) {
    row.created_at = now
    const { data } = await supabase.from('row_data').insert(row).select('id').single()
    id = data?.id
  } else {
    id = Number(model.row_id)
    await supabase.from('row_data').update(row).eq('id', id)
  }

  return { id }
}

// 데이터 일괄 등록 (1쿼리)
export async function registerBulkData(items) {
  const now = new Date().toISOString()
  const rows = items.map(item => {
    const row = {
      category_id: item.categoryId,
      detail_type: item.detailType,
      amount: Number(item.amount),
      update_at: item.update_at,
      memo: '',
      created_at: now,
    }
    if (item.payType) {
      row.pay_type = item.payType
    }
    return row
  })

  await supabase.from('row_data').insert(rows)
}

// 데이터 삭제
export async function deleteData(rowIds) {
  await supabase.from('row_data').delete().in('id', rowIds)
}
