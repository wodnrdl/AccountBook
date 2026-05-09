import { createRouter, createWebHistory } from 'vue-router'
import { supabase } from './lib/supabase.js'
import HomeView from './views/HomeView.vue'
import RegistrationView from './views/RegistrationView.vue'
import LoginView from './views/LoginView.vue'

import V2Layout from './views/v2/V2Layout.vue'
import V2Dashboard from './views/v2/Dashboard.vue'
import V2Assets from './views/v2/Assets.vue'
import V2Recurring from './views/v2/Recurring.vue'
import V2Transactions from './views/v2/Transactions.vue'

const routes = [
  { path: '/', redirect: '/home' },
  { path: '/login', component: LoginView, meta: { public: true } },
  { path: '/home', component: HomeView },
  { path: '/registration', component: RegistrationView },
  {
    path: '/v2',
    component: V2Layout,
    meta: { v2: true },
    children: [
      { path: '',             component: V2Dashboard },
      { path: 'assets',       component: V2Assets },
      { path: 'recurring',    component: V2Recurring },
      { path: 'transactions', component: V2Transactions },
    ],
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach(async (to) => {
  if (to.meta.public) return true
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return '/login'
  return true
})

export default router
