// Service Worker — 離線快取（network-first，避免 Safari redirect 問題）
const CACHE = 'dou-dizhu-v3';
const ASSETS = [
  './',
  './index.html',
  './manifest.json',
  'icons/icon-192.png',
  'icons/icon-256.png',
  'icons/icon-512.png',
  'icons/apple-touch-icon.png'
];

// 安裝：預先快取核心檔案
self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(ASSETS).catch(()=>{})).then(() => self.skipWaiting())
  );
});

// 啟用：清舊快取 + 接管
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== CACHE).map(k => caches.delete(k))
    )).then(() => self.clients.claim())
  );
});

// 請求：network-first（優先用最新，離線先用 cache）
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  // 淨係處理同源請求；Supabase API + CDN 直接放行（唔攔截）
  if (url.origin !== location.origin) return;

  e.respondWith(
    fetch(req).then(res => {
      // 只快取正常（200）同基本類型嘅 response，唔快取 redirect/opaque
      if (res && res.status === 200 && res.type === 'basic') {
        const clone = res.clone();
        caches.open(CACHE).then(c => c.put(req, clone));
      }
      return res;
    }).catch(() => {
      // 離線：用 cache
      return caches.match(req).then(cached => cached || caches.match('./index.html'));
    })
  );
});
