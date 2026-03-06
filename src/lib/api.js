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

// 카테고리별 월 총액
async function getAmount(categoryIds, year, month) {
  const { first, last } = getMonthRange(year, month)
  const { data } = await supabase
    .from('row_data')
    .select('amount')
    .in('category_id', categoryIds)
    .gte('update_at', first)
    .lte('update_at', last)

  if (!data || data.length === 0) return 0
  return data.reduce((sum, r) => sum + Number(r.amount), 0)
}

// 전체 남은돈
async function getAllAmount(year, month) {
  let incomeQuery = supabase.from('row_data').select('amount').in('category_id', [2, 11])
  let expenseQuery = supabase.from('row_data').select('amount').in('category_id', [3, 5, 6, 7])

  if (year !== 0 && month !== 0) {
    const { first, last } = getMonthRange(year, month)
    incomeQuery = incomeQuery.gte('update_at', first).lte('update_at', last)
    expenseQuery = expenseQuery.gte('update_at', first).lte('update_at', last)
  }

  const [incomeRes, expenseRes] = await Promise.all([incomeQuery, expenseQuery])
  const income = (incomeRes.data || []).reduce((s, r) => s + Number(r.amount), 0)
  const expense = (expenseRes.data || []).reduce((s, r) => s + Number(r.amount), 0)
  return income - expense
}

// 전체 요약 데이터 가져오기
export async function fetchAllData(year, month) {
  let y = Number(year)
  let pm = Number(month) - 1
  if (pm === 0) { pm = 12; y-- }

  const [
    salary_amount, out_amount, save_amount, life_amount,
    before_salary_amount, before_out_amount, before_save_amount, before_life_amount,
    salary_all_amount, before_salary_all_amount,
  ] = await Promise.all([
    getAmount([2, 11], year, month),
    getAmount([5, 6, 7], year, month),
    getAmount([3], year, month),
    getAmount([7], year, month),
    getAmount([2, 11], y, pm),
    getAmount([5, 6, 7], y, pm),
    getAmount([3], y, pm),
    getAmount([7], y, pm),
    getAllAmount(0, 0),
    getAllAmount(y, pm),
  ])

  return {
    salary_amount, out_amount, save_amount, life_amount,
    before_salary_amount, before_out_amount, before_save_amount, before_life_amount,
    salary_all_amount, before_salary_all_amount,
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

// 카테고리 + 네비 가져오기
export async function fetchCategories() {
  const [catRes, navRes] = await Promise.all([
    supabase.from('category').select('id, title').order('id'),
    supabase.from('category_nav').select('name, title, option, category_id').order('id'),
  ])
  return {
    categories: catRes.data || [],
    categoryNavs: navRes.data || [],
  }
}

// 카테고리별 월 데이터 가져오기
export async function fetchData(year, month, categoryId) {
  const { first, last } = getMonthRange(year, month)
  const { data } = await supabase
    .from('row_data')
    .select('id, row_key, detail_type, amount, pay_type, update_at, memo')
    .eq('category_id', categoryId)
    .gte('update_at', first)
    .lte('update_at', last)
    .order('update_at', { ascending: false })

  return (data || []).map(r => ({
    row_id: r.id,
    rowKey: r.row_key,
    detailType: r.detail_type,
    amount: r.amount,
    payType: r.pay_type,
    update_at: r.update_at ? r.update_at.substring(0, 10) : '',
    memo: r.memo,
  }))
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

// 데이터 등록/수정
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

  // 로그 저장
  await supabase.from('data_log').insert({ json_data: JSON.stringify(row), created_at: now })

  let id
  if (!model.row_id || model.row_id === 0) {
    row.created_at = now
    const { data } = await supabase.from('row_data').insert(row).select('id').single()
    id = data?.id
  } else {
    id = Number(model.row_id)
    await supabase.from('row_data').update(row).eq('id', id)
  }

  // 요약 데이터 다시 계산
  const summary = await fetchAllData(model.year, model.month)
  return { id, ...summary }
}

// 데이터 삭제
export async function deleteData(rowIds) {
  await supabase.from('row_data').delete().in('id', rowIds)
}
