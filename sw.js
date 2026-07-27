// Service Worker — 離線快取（cache-first，背景更新）
const CACHE = 'dou-dizhu-v2';
const ASSETS = [
  './',
  './index.html',
  './manifest.json',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
  'icons/icon-192.png',
  'icons/icon-256.png',
  'icons/icon-512.png'
];

// 安裝：預先快取核心檔案
self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(ASSETS).catch(()=>{})).then(() => self.skipWaiting())
  );
});

// 啟用：清舊快取
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== CACHE).map(k => caches.delete(k))
    )).then(() => self.clients.claim())
  );
});

// 請求：cache-first，背景更新
self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  // 同源 + Supabase CDN 才攔截；其他（API 資料）直接上網
  const url = new URL(req.url);
  const isAsset = url.origin === location.origin || url.href.includes('cdn.jsdelivr.net');
  if (!isAsset) return;  // Supabase API 請求唔快取，保證資料最新

  e.respondWith(
    caches.match(req).then(cached => {
      const fetchPromise = fetch(req).then(res => {
        if (res && res.status === 200) {
          const clone = res.clone();
          caches.open(CACHE).then(c => c.put(req, clone));
        }
        return res;
      }).catch(() => cached);
      return cached || fetchPromise;
    })
  );
});
