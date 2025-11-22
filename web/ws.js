const CACHE_NAME = 'video-download-cache-v1';

// 安装Service Worker
self.addEventListener('install', (event) => {
    self.skipWaiting(); // 立即等待，立即激活
});

// 激活Service Worker
self.addEventListener('activate', (event) => {
    event.waitUntil(
        caches.keys().then(cacheNames => {
            return Promise.all(
                cacheNames.filter(name => name !== CACHE_NAME)
                    .map(name => caches.delete(name))
            );
        }).then(() => self.clients.claim())
    );
});

// 拦截请求
self.addEventListener('fetch', (event) => {
    // 只处理视频流请求
    if (event.request.url.includes('/videoStream/')) {
        event.respondWith(
            caches.match(event.request).then(cachedResponse => {
                // 如果缓存中有，直接返回
                if (cachedResponse) {
                    return cachedResponse;
                }

                // 否则请求网络
                return fetch(event.request).then(networkResponse => {
                    // 只缓存206部分响应
                    if (event.request.headers.has('Range') && networkResponse.status === 206) {
                        caches.open(CACHE_NAME).then(cache => {
                            cache.put(event.request, networkResponse.clone());
                        });
                    }
                    return networkResponse;
                });
            })
        );
    }
});
