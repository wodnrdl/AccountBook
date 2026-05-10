import { supabase } from './supabase.js'

// ----- 공통 -----
export const OWNERS = ['재욱', '공주님', '공동']

export const ACCOUNT_TYPES = [
  { value: 'envelope',    label: '봉투 (가상)' },
  { value: 'savings',     label: '예금' },
  { value: 'installment', label: '적금' },
  { value: 'housing',     label: '주택청약' },
  { value: 'voucher',     label: '상품권' },
  { value: 'gold',        label: '금' },
  { value: 'irp',         label: 'IRP/연금' },
  { value: 'deposit',     label: '보증금' },
  { value: 'loan',        label: '대출' },
]

export const RECURRING_KINDS = [
  { value: 'income',       label: '수입' },
  { value: 'transfer',     label: '저축/이체' },
  { value: 'expense',      label: '지출' },
  { value: 'insurance',    label: '보험' },
  { value: 'loan_payment', label: '대출상환' },
]

export const won = (n) => Number(n || 0).toLocaleString('ko-KR') + ' ₩'
export const wonShort = (n) => {
  const v = Math.abs(Number(n || 0))
  if (v >= 100000000) return (v / 100000000).toFixed(1).replace(/\.0$/, '') + '억'
  if (v >= 10000)     return (v / 10000).toFixed(0) + '만'
  return v.toLocaleString('ko-KR')
}
export const ymNow = () => {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}
export const cmpYm = (a, b) => a < b ? -1 : a > b ? 1 : 0

// 'YYYY-MM' → { first: 'YYYY-MM-01', last: 'YYYY-MM-DD(말일)' }
export function ymRange(ym) {
  const [y, m] = ym.split('-').map(Number)
  const lastDay = new Date(y, m, 0).getDate()  // 해당 월 말일
  return {
    first: `${ym}-01`,
    last:  `${ym}-${String(lastDay).padStart(2, '0')}`,
  }
}

// ym 의 직전 달
export function prevYm(ym) {
  let [y, m] = ym.split('-').map(Number)
  m--; if (m < 1) { m = 12; y-- }
  return `${y}-${String(m).padStart(2, '0')}`
}

// ===== accounts =====
// 모듈 레벨 캐시 — accounts 는 자주 조회되지만 변경 빈도는 낮음.
// 변경 함수들은 모두 invalidateAccounts() 를 호출해서 다음 조회 때 재로딩.
let _accountsCache = null
let _accountsPromise = null
function invalidateAccounts() {
  _accountsCache = null
  _accountsPromise = null
}
async function getAccountsCached() {
  if (_accountsCache) return _accountsCache
  if (_accountsPromise) return _accountsPromise
  _accountsPromise = (async () => {
    const { data, error } = await supabase
      .from('accounts')
      .select('*')
      .order('owner').order('sort_order').order('id')
    if (error) { _accountsPromise = null; throw error }
    _accountsCache = data || []
    _accountsPromise = null
    return _accountsCache
  })()
  return _accountsPromise
}

export async function listAccounts() {
  return getAccountsCached()
}

export async function createAccount(payload) {
  const { data, error } = await supabase.from('accounts').insert(payload).select().single()
  if (error) throw error
  invalidateAccounts()
  return data
}

export async function updateAccount(id, fields) {
  const { data, error } = await supabase.from('accounts').update(fields).eq('id', id).select().single()
  if (error) throw error
  invalidateAccounts()
  return data
}

export async function deleteAccount(id) {
  const { error } = await supabase.from('accounts').delete().eq('id', id)
  if (error) throw error
  invalidateAccounts()
}

// 결제 계좌 (거래 등록 시 선택 가능) — 캐시된 accounts 에서 필터링
export async function listPaymentAccounts() {
  const all = await getAccountsCached()
  return all.filter(a => a.tx_enabled).slice().sort((a, b) => {
    if (a.tx_default !== b.tx_default) return a.tx_default ? -1 : 1
    if (a.owner !== b.owner) return a.owner < b.owner ? -1 : 1
    if ((a.sort_order || 0) !== (b.sort_order || 0)) return (a.sort_order || 0) - (b.sort_order || 0)
    return a.id - b.id
  })
}

// 기본 결제 계좌 지정 (다른 행은 자동으로 false)
export async function setDefaultPaymentAccount(id) {
  // 1) 모든 행 false 로
  const { error: e1 } = await supabase.from('accounts').update({ tx_default: false }).eq('tx_default', true)
  if (e1) throw e1
  // 2) 지정한 한 건만 true (tx_enabled 도 함께 보장)
  const { error: e2 } = await supabase.from('accounts').update({ tx_default: true, tx_enabled: true }).eq('id', id)
  if (e2) throw e2
  invalidateAccounts()
}

export async function clearDefaultPaymentAccount() {
  const { error } = await supabase.from('accounts').update({ tx_default: false }).eq('tx_default', true)
  if (error) throw error
  invalidateAccounts()
}

// 잔액 갱신 + 해당월 스냅샷 upsert
export async function updateBalance(accountId, newBalance, ym = ymNow()) {
  await updateAccount(accountId, { balance: newBalance })
  await upsertSnapshot(accountId, ym, newBalance)
}

// ===== balance_snapshots =====
export async function listSnapshots(accountId) {
  const { data, error } = await supabase
    .from('balance_snapshots')
    .select('*')
    .eq('account_id', accountId)
    .order('year_month')
  if (error) throw error
  return data || []
}

export async function listSnapshotsRange(fromYm, toYm) {
  const { data, error } = await supabase
    .from('balance_snapshots')
    .select('*')
    .gte('year_month', fromYm)
    .lte('year_month', toYm)
    .order('year_month')
  if (error) throw error
  return data || []
}

export async function upsertSnapshot(accountId, ym, balance) {
  const { error } = await supabase
    .from('balance_snapshots')
    .upsert({ account_id: accountId, year_month: ym, balance }, { onConflict: 'account_id,year_month' })
  if (error) throw error
}

// ===== recurring_items =====
export async function listRecurring({ ym = null, activeOnly = true } = {}) {
  let q = supabase.from('recurring_items').select('*').order('kind').order('sort_order').order('id')
  if (activeOnly) q = q.eq('active', true)
  const { data, error } = await q
  if (error) throw error
  let rows = data || []
  if (ym) {
    rows = rows.filter(r => cmpYm(r.start_ym, ym) <= 0 && (!r.end_ym || cmpYm(r.end_ym, ym) >= 0))
  }
  return rows
}

export async function createRecurring(payload) {
  const { data, error } = await supabase.from('recurring_items').insert(payload).select().single()
  if (error) throw error
  return data
}

export async function updateRecurring(id, fields) {
  const { data, error } = await supabase.from('recurring_items').update(fields).eq('id', id).select().single()
  if (error) throw error
  // 이번 달 자동 거래는 새 설정으로 재생성될 수 있도록 삭제
  // (applyRecurringTransfers 가 다음 호출 시 도래여부 체크 후 재생성)
  await deleteThisMonthAuto(id)
  return data
}

async function deleteThisMonthAuto(recurringId) {
  const ym = ymNow()
  const { first, last } = ymRange(ym)
  const { data: rows } = await supabase
    .from('transactions').select('id')
    .eq('recurring_id', recurringId)
    .gte('date', first).lte('date', last)
  for (const t of rows || []) {
    await deleteTransaction(t.id)
  }
}

export async function deleteRecurring(id) {
  // 이 항목이 만든 모든 자동 거래 먼저 정리 (잔액 원복 포함)
  const { data: rows } = await supabase
    .from('transactions').select('id')
    .eq('recurring_id', id)
  for (const t of rows || []) {
    await deleteTransaction(t.id)
  }
  const { error } = await supabase.from('recurring_items').delete().eq('id', id)
  if (error) throw error
}

// ===== transactions =====
// includeRecurring=false (기본): 자동 이체로 생성된 거래(recurring_id IS NOT NULL) 제외
export async function listTransactions({ ym = null, owner = null, kind = null, includeRecurring = false, accountId = null, limit = null } = {}) {
  let q = supabase.from('transactions').select('*').order('date', { ascending: false }).order('id', { ascending: false })
  if (ym) {
    const { first, last } = ymRange(ym)
    q = q.gte('date', first).lte('date', last)
  }
  if (owner) q = q.eq('owner', owner)
  if (kind)  q = q.eq('kind', kind)
  if (accountId) q = q.eq('account_id', accountId)
  if (!includeRecurring) q = q.is('recurring_id', null)
  if (limit) q = q.limit(limit)
  const { data, error } = await q
  if (error) throw error
  return data || []
}

// 거래 → 계좌잔액 자동 동기화 (income +, expense -)
async function adjustAccountBalance(accountId, delta) {
  if (!accountId || !delta) return
  const { error } = await supabase.rpc('increment_account_balance', { p_account_id: accountId, p_delta: delta })
  if (error) throw error
  invalidateAccounts()
}
function txDelta(t) {
  return (t.kind === 'income' ? 1 : -1) * Number(t.amount || 0)
}

// 거래용(tx_default) 계좌의 수동 지출은 자산 잔액 미반영 — 생활비 봉투 used 로만 추적
// 캐시된 accounts 에서 lookup (별도 SELECT 없음)
async function shouldSkipBalanceSync(t) {
  if (!t || t.kind !== 'expense' || t.recurring_id) return false
  if (!t.account_id) return false
  const accs = await getAccountsCached()
  const a = accs.find(x => x.id === t.account_id)
  return !!a?.tx_default
}

async function applyTxBalance(t, delta) {
  if (!t?.account_id || !delta) return
  if (await shouldSkipBalanceSync(t)) return
  await adjustAccountBalance(t.account_id, delta)
}

export async function createTransaction(payload) {
  const { data, error } = await supabase.from('transactions').insert(payload).select().single()
  if (error) throw error
  await applyTxBalance(data, txDelta(data))
  return data
}

export async function updateTransaction(id, fields) {
  const { data: oldRow } = await supabase.from('transactions').select('*').eq('id', id).single()
  const { data, error } = await supabase.from('transactions').update(fields).eq('id', id).select().single()
  if (error) throw error
  // 이전 영향 되돌리기
  if (oldRow) await applyTxBalance(oldRow, -txDelta(oldRow))
  // 새 영향 적용
  await applyTxBalance(data, txDelta(data))
  return data
}

export async function deleteTransaction(id) {
  const { data: oldRow } = await supabase.from('transactions').select('*').eq('id', id).single()
  const { error } = await supabase.from('transactions').delete().eq('id', id)
  if (error) throw error
  if (oldRow) await applyTxBalance(oldRow, -txDelta(oldRow))
}

// ===== living_budget (생활비 봉투) =====
// 자동 충전 기능은 제거됨 — 저축/이체 income 거래로 자연스럽게 채워지고 이월은 누적 계산.

// ===== 매월 자동 거래 처리 =====
// recurring_items 의 종류별로 멱등 자동 거래를 생성한다.
// 종류                   계좌 입력             생성되는 거래
// ─────────────────────────────────────────────────────────
// income                 입금(target)          income +amount
// expense / insurance    출금(source)          expense -amount
// transfer / loan_payment 출금+입금            expense -amount + income +amount (한 쌍)
// ─────────────────────────────────────────────────────────
// 각 거래는 recurring_id 로 마킹되어 거래 페이지/대시보드 요약에서 제외된다.
// 한 항목당 한 달에 한 번만 실행 (recurring_id+date 로 중복 체크).
export const RECURRING_INCOME_CATEGORY    = '월급/수입'
export const RECURRING_EXPENSE_CATEGORY   = '고정지출'
export const RECURRING_INSURANCE_CATEGORY = '보험'
export const RECURRING_TRANSFER_CATEGORY  = '저축이체'

function recurringCategory(kind) {
  if (kind === 'income')    return RECURRING_INCOME_CATEGORY
  if (kind === 'insurance') return RECURRING_INSURANCE_CATEGORY
  if (kind === 'expense')   return RECURRING_EXPENSE_CATEGORY
  return RECURRING_TRANSFER_CATEGORY
}

// 자동 처리 가능 여부 (각 종류별로 필요한 계좌가 채워져있나?)
export function isRecurringAuto(r) {
  if (!r || !r.active) return false
  if (r.kind === 'income')                                  return !!r.target_account_id
  if (r.kind === 'expense' || r.kind === 'insurance')       return !!r.source_account_id
  if (r.kind === 'transfer' || r.kind === 'loan_payment')   return !!r.source_account_id && !!r.target_account_id
  return false
}

export async function applyRecurringTransfers(uptoYm = ymNow()) {
  // 미래월은 무시 (현재월 초과 방지)
  const cur = ymNow()
  if (cmpYm(uptoYm, cur) > 0) uptoYm = cur

  // 오늘(YYYY-MM-DD) — 이체일이 아직 안 도래한 이번 달 거래는 생성 보류
  const _now = new Date()
  const todayStr = `${_now.getFullYear()}-${String(_now.getMonth()+1).padStart(2,'0')}-${String(_now.getDate()).padStart(2,'0')}`

  const { data: items, error } = await supabase
    .from('recurring_items')
    .select('*')
    .eq('active', true)
  if (error) throw error
  const eligible = (items || []).filter(isRecurringAuto)
  if (!eligible.length) return { applied: 0 }

  let applied = 0
  for (const r of eligible) {
    // 처리할 월 목록: max(start_ym, '2026-05') ~ uptoYm
    // (마이그레이션 도입 이전 월은 백필하지 않음 — 자산 잔액 보호)
    const FEATURE_START = '2026-05'
    const startYm = cmpYm(r.start_ym, FEATURE_START) > 0 ? r.start_ym : FEATURE_START
    if (cmpYm(startYm, uptoYm) > 0) continue

    // 이미 처리된 월 조회
    const { first } = ymRange(startYm)
    const { last:  lastUpto } = ymRange(uptoYm)
    const { data: existing } = await supabase
      .from('transactions').select('date')
      .eq('recurring_id', r.id)
      .gte('date', first).lte('date', lastUpto)
    const done = new Set((existing || []).map(t => (t.date || '').slice(0, 7)))

    // 월 목록 생성
    let [y, m] = startYm.split('-').map(Number)
    const months = []
    while (true) {
      const ym = `${y}-${String(m).padStart(2, '0')}`
      months.push(ym)
      if (ym === uptoYm) break
      m++; if (m > 12) { m = 1; y++ }
      if (months.length > 240) break // safety
    }

    const category = recurringCategory(r.kind)

    for (const ym of months) {
      if (done.has(ym)) continue
      if (r.end_ym && cmpYm(ym, r.end_ym) > 0) continue

      // 날짜: day_of_month (없으면 1일), 말일 초과는 그 달 말일로 클램프
      const { last } = ymRange(ym)
      const lastDay = Number(last.slice(-2))
      const day = Math.min(Math.max(r.day_of_month || 1, 1), lastDay)
      const date = `${ym}-${String(day).padStart(2, '0')}`

      // 이체일이 아직 미래라면 이번 사이클은 스킵 — 다음 진입 시 도래하면 처리
      if (date > todayStr) continue

      if (r.kind === 'income') {
        // 단방향 입금
        await createTransaction({
          date, kind: 'income', amount: r.amount,
          category, owner: r.owner,
          account_id: r.target_account_id,
          memo: `자동: ${r.name}`,
          recurring_id: r.id,
        })
      } else if (r.kind === 'expense' || r.kind === 'insurance') {
        // 단방향 출금
        await createTransaction({
          date, kind: 'expense', amount: r.amount,
          category, owner: r.owner,
          account_id: r.source_account_id,
          memo: `자동: ${r.name}`,
          recurring_id: r.id,
        })
      } else {
        // transfer / loan_payment — 출금+입금 한 쌍
        await createTransaction({
          date, kind: 'expense', amount: r.amount,
          category, owner: r.owner,
          account_id: r.source_account_id,
          memo: `자동: ${r.name}`,
          recurring_id: r.id,
        })
        await createTransaction({
          date, kind: 'income', amount: r.amount,
          category, owner: r.owner,
          account_id: r.target_account_id,
          memo: `자동: ${r.name}`,
          recurring_id: r.id,
        })
      }
      applied++
    }
  }
  return { applied }
}

// 이번 달 생활비 봉투 상태 (이월 carry-over 반영)
// 반환: { target, carryOver(전월말 잔액), income(이번달 모든 입금), used(이번달 지출), remaining, balanceNow }
// opts.accounts 가 주어지면 그 결과를 재사용 (불필요한 listAccounts 호출 제거)
export async function fetchLivingBudgetStatus(ym = ymNow(), opts = {}) {
  const accs = opts.accounts || await getAccountsCached()
  const target = accs.find(a => a.tx_default)
  if (!target) return { target: null, carryOver: 0, income: 0, used: 0, remaining: 0, balanceNow: 0 }

  const { last: lastOfYm } = ymRange(ym)

  // 해당 계좌의 ym 말일까지 모든 거래 (이전 월 누적 + 이번 달)
  const { data: txs } = await supabase
    .from('transactions').select('kind, amount, date')
    .eq('account_id', target.id)
    .lte('date', lastOfYm)

  const all = txs || []

  const thisYmPrefix = ym + '-'
  const thisMonth = []
  const prevMonths = []
  for (const t of all) {
    if ((t.date || '').startsWith(thisYmPrefix)) thisMonth.push(t)
    else prevMonths.push(t)
  }

  const sumKind = (rows, k) => rows.filter(t => t.kind === k).reduce((s, t) => s + Number(t.amount), 0)

  const carryOver = sumKind(prevMonths, 'income') - sumKind(prevMonths, 'expense')
  const income = sumKind(thisMonth, 'income')
  const used = sumKind(thisMonth, 'expense')

  return {
    target,
    carryOver,
    income,
    used,
    remaining: carryOver + income - used,
    balanceNow: Number(target.balance),
  }
}

// ===== 대시보드 요약 =====
// 한 달 기준 수입/지출/저축/보험/상환 합계 + 자산총합/부채/소유자별 자산
export async function fetchDashboard(ym = ymNow()) {
  const [accs, recs, txs] = await Promise.all([
    listAccounts(),
    listRecurring({ ym, activeOnly: true }),
    listTransactions({ ym }),
  ])

  const sumKind = (k) => recs.filter(r => r.kind === k).reduce((s, r) => s + Number(r.amount), 0)
  const recurring = {
    income:       sumKind('income'),
    transfer:     sumKind('transfer'),
    expense:      sumKind('expense'),
    insurance:    sumKind('insurance'),
    loan_payment: sumKind('loan_payment'),
  }
  recurring.totalOut = recurring.transfer + recurring.expense + recurring.insurance + recurring.loan_payment
  recurring.surplus  = recurring.income - recurring.totalOut

  const txIncome  = txs.filter(t => t.kind === 'income').reduce((s, t) => s + Number(t.amount), 0)
  const txExpense = txs.filter(t => t.kind === 'expense').reduce((s, t) => s + Number(t.amount), 0)

  const assets = accs.filter(a => !a.is_liability)
  const liabilities = accs.filter(a => a.is_liability)
  const assetTotal = assets.reduce((s, a) => s + Number(a.balance), 0)
  const liabilityTotal = liabilities.reduce((s, a) => s + Number(a.balance), 0)

  const byOwner = {}
  for (const o of OWNERS) byOwner[o] = 0
  for (const a of assets) byOwner[a.owner] = (byOwner[a.owner] || 0) + Number(a.balance)

  return {
    ym,
    recurring,
    tx: { income: txIncome, expense: txExpense },
    accounts: accs,
    assetTotal,
    liabilityTotal,
    netWorth: assetTotal - liabilityTotal,
    byOwner,
  }
}
