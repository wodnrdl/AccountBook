# PWA 패키징 — 다음 세션 작업 메모

> 목적: v2 가계부를 PWA(Progressive Web App)로 만들어 홈 화면 설치 + 네이티브-스러운 실행 환경 제공.
> 작성일: 2026-05-10
> 상태: 미착수 — v2 사용해보고 만족스러우면 진행.

---

## 왜 PWA?

- 별도 앱스토어 배포 없이 **모바일/데스크톱 모두 홈 화면 설치 가능**
- 기존 Vite + Vue 프로젝트에 플러그인 하나 추가로 끝 (작업 30분~1시간)
- 브라우저 UI 가 사라져 화면 면적 ↑, 앱 셸이 캐시되어 로딩 ↑
- 자체 아이콘 + 스플래시 스크린

## 제약사항 (가계부 특성)

| 항목 | 가능 여부 | 비고 |
|---|---|---|
| 홈 화면 설치 | ✅ | iOS Safari, Android Chrome, Edge, 데스크톱 Chrome 모두 |
| 앱 셸 오프라인 | ✅ | HTML/JS/CSS 캐시 (Service Worker) |
| **데이터 오프라인** | ❌ | Supabase 호출은 항상 네트워크 필요 — 오프라인이면 빈 화면 |
| 푸시 알림 | ⚠️ | 가능하지만 Supabase Edge Function 등 백엔드 작업 필요 |
| iOS PWA | ⚠️ | 동작은 하나 백그라운드 알림 제약, 앱 종료 시 상태 보존 약함 |

데이터 오프라인이 필요하면 **IndexedDB 캐시 + Supabase 동기화** 전략을 별도 설계해야 함 (이번 작업 범위 밖).

## 작업 단계

### 1) 의존성 설치
```bash
npm install -D vite-plugin-pwa
# 아이콘 생성기 (선택)
npm install -D @vite-pwa/assets-generator
```

### 2) `vite.config.js` 설정
```js
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    vue(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.ico', 'apple-touch-icon.png'],
      manifest: {
        name: '가계부',
        short_name: '가계부',
        description: '재욱/공주님 가계부',
        theme_color: '#5e72e4',
        background_color: '#ffffff',
        display: 'standalone',
        orientation: 'portrait',
        scope: '/',
        start_url: '/v2',
        icons: [
          { src: '/icons/icon-192.png',  sizes: '192x192', type: 'image/png' },
          { src: '/icons/icon-512.png',  sizes: '512x512', type: 'image/png' },
          { src: '/icons/icon-512-maskable.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      workbox: {
        // Supabase API 응답은 캐시하지 않음 (실시간 데이터)
        navigateFallbackDenylist: [/^\/api\//, /supabase\.co/],
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/.*\.(?:googleapis|gstatic|jsdelivr|toast)\.(?:com|net)\/.*/i,
            handler: 'CacheFirst',
            options: {
              cacheName: 'cdn-cache',
              expiration: { maxEntries: 30, maxAgeSeconds: 60 * 60 * 24 * 30 },
            },
          },
        ],
      },
    }),
  ],
  server: { proxy: { '/api': { target: 'http://localhost:3000', changeOrigin: true } } },
})
```

### 3) 아이콘 자산
필요 파일 (모두 `/public/icons/` 에 배치):
- `icon-192.png` (192×192) — Android 홈 아이콘
- `icon-512.png` (512×512) — 스플래시 / 고해상도
- `icon-512-maskable.png` (512×512, 안전영역 80%) — Android 적응형 아이콘
- `apple-touch-icon.png` (180×180) — iOS 홈 아이콘
- `favicon.ico` (이미 있음)

기존 piggy-bank 아이콘을 `public/icons/source.png` 로 두고 자동 생성:
```bash
npx @vite-pwa/assets-generator --preset minimal-2023 public/icons/source.png
```
또는 직접 디자인 (Figma/Photoshop, 단색 배경 + 가운데 심볼 패턴 권장).

### 4) `index.html` 메타태그 추가
```html
<head>
  <!-- 기존 메타 ... -->
  <meta name="theme-color" content="#5e72e4" />
  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-status-bar-style" content="default" />
  <meta name="apple-mobile-web-app-title" content="가계부" />
  <link rel="apple-touch-icon" href="/icons/apple-touch-icon.png" />
</head>
```

### 5) 앱 업데이트 알림 (선택)
새 버전 배포 시 사용자에게 새로고침 안내. `App.vue` 에 prompt 추가:
```vue
<script setup>
import { useRegisterSW } from 'virtual:pwa-register/vue'
const { needRefresh, updateServiceWorker } = useRegisterSW()
</script>

<template>
  <!-- 기존 ... -->
  <div v-if="needRefresh" class="update-banner">
    새 버전이 있습니다.
    <button @click="updateServiceWorker(true)">업데이트</button>
  </div>
</template>
```

### 6) 검증
- `npm run build && npm run preview` 로 로컬 확인
- Chrome DevTools → Application 탭 → Manifest / Service Workers 확인
- Lighthouse PWA 점수 확인 (90 이상 목표)
- Vercel 배포 후 모바일에서 "홈 화면에 추가" 테스트
  - iOS: Safari 공유 → "홈 화면에 추가"
  - Android: Chrome 메뉴 → "앱 설치"

## 선택 사항 (필요 시)

### A. 푸시 알림
- Web Push API + Service Worker
- Supabase Edge Function 으로 알림 발송 트리거
- 예: 매월 1일 "월급 자동 입금 처리됨" 알림
- 작업량: 추가 3~5시간

### B. 네이티브 앱 패키징 (PWA 너머)
- **Capacitor**: 웹앱을 iOS/Android 네이티브 래핑 → 앱스토어 등록 가능
  - Apple 개발자 등록 99$/년
  - Xcode (Mac 필요) / Android Studio
  - 작업량: 1~2일 + 심사 대기
- **Tauri / Electron**: 데스크톱 앱. 모바일 가계부면 불필요

### C. 데이터 오프라인 캐싱
- IndexedDB 에 transactions/accounts 캐시
- Supabase 응답 받으면 IDB 업데이트
- 오프라인일 때 IDB 에서 읽기 + 로컬 큐잉
- 변경사항 동기화는 충돌 처리 필요 (last-write-wins or CRDT)
- 작업량: 1주 이상

## 우선순위 추천

1. ✅ **PWA 기본 설치** (이 문서 1~6 단계만) — 효과 대비 가장 가성비 좋음
2. ⚠️ **푸시 알림** — 사용해보고 정말 원하면
3. ❌ **네이티브 앱** — 가족 2~3명 쓰는 앱이면 PWA 로 충분
4. ❌ **오프라인 데이터** — 외출 중 거래 등록 자주 필요해지면 그때

## 참고 링크

- vite-plugin-pwa: https://vite-pwa-org.netlify.app/
- Workbox: https://developer.chrome.com/docs/workbox
- iOS PWA 제약: https://firt.dev/notes/pwa-ios/
- Maskable icon 가이드: https://web.dev/articles/maskable-icon
