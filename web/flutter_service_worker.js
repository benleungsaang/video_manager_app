'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "ab931cb8398b2098cfc7f015e9760cc5",
"assets/AssetManifest.bin.json": "a840d4b82e2d9ee20ded82fbe10d72fd",
"assets/build/web/auth.html": "5c217727a6bad02d8192d3ec96d65ae8",
"assets/build/web/css/font-awesome.min.css": "a0e784c4ca94c271b0338dfb02055be6",
"assets/build/web/css/output.css": "c99c436db2287447633f9678f2954b40",
"assets/build/web/css/tailwind-input.css": "b25550adfadeca2b76f2ad638bc7446e",
"assets/build/web/css/tailwind.css": "beba90e3a74c7b50d3b1eaa497925ebe",
"assets/build/web/download-worker.js": "2a7f093a15ccccf5fe7f9ced22b2f828",
"assets/build/web/entry.html": "35703527cab0fa4b2059ea328156460a",
"assets/build/web/favicon.png": "5dcef449791fa27946b3d35ad8803796",
"assets/build/web/flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"assets/build/web/flutter_bootstrap.js": "c41dddfbc0eeb5f7b17aa9d5789c2344",
"assets/build/web/fonts/fontawesome-webfont.ttf": "dcb26c7239d850266941e80370e207c1",
"assets/build/web/fonts/fontawesome-webfont.woff": "3293616ec0c605c7c2db25829a0a509e",
"assets/build/web/fonts/fontawesome-webfont.woff2": "af7ae505a9eed503f8b8e6982036873e",
"assets/build/web/fonts/MaterialIcons-Regular.otf": "912f8648735d11cb5529bb8f78462471",
"assets/build/web/icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"assets/build/web/icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"assets/build/web/icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"assets/build/web/icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"assets/build/web/index.html": "196b0dd41e8ec89cb925f259b48f2f04",
"assets/build/web/js/cart-module.js": "5fb14efd822569d084bd1052bf6b94b5",
"assets/build/web/js/core-module.js": "bd6be87347d336c0e54aa9040812623a",
"assets/build/web/js/data-module.js": "a49aef1d7fbf1b319fe8ceecc478588d",
"assets/build/web/js/home-module.js": "133ed24a77f4ac75b3569f98716e8bc8",
"assets/build/web/js/quote-module.js": "7384d2ef73beab80aa2bee4bffc7c0a6",
"assets/build/web/Logo.png": "0713184a50485dc0f3e68563824a511f",
"assets/build/web/main.dart.js": "2bfb327a902777b746b4373527fba84c",
"assets/build/web/parts_management.html": "a998fa724fd31295ecd9d2b5aa2fcad1",
"assets/build/web/price_calculator.html": "3e2916d23071c4d7e9cb7946e97dd989",
"assets/build/web/qrcode.min.js": "517b55d3688ce9ef1085a3d9632bcb97",
"assets/build/web/sample.jpg": "ae71152cdc580ffd5672d1be01028f3c",
"assets/build/web/sync.ffs_db": "29c3604d5d9fe27a49ac9d8498e9d72e",
"assets/build/web/user_management.html": "866822e6b0321317ff0ffc0a13b17b6f",
"assets/build/web/version.json": "5e2f4b86383b5bc577f335589884c2ee",
"assets/build/web/ws.js": "6e3ca71583984a9f4eee49d276a28194",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "1d25b8d36724a144997b0590fd11d776",
"assets/NOTICES": "cfa0a9141f5ef84728bbf84448793c02",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "d7d83bd9ee909f8a9b348f56ca7b68c6",
"assets/packages/fluttertoast/assets/toastify.css": "a85675050054f179444bc5ad70ffc635",
"assets/packages/fluttertoast/assets/toastify.js": "56e2c9cedd97f10e7e5f1cebd85d53e3",
"assets/packages/wakelock_plus/assets/no_sleep.js": "7748a45cd593f33280669b29c2c8919a",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"auth.html": "5c217727a6bad02d8192d3ec96d65ae8",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"css/font-awesome.min.css": "a0e784c4ca94c271b0338dfb02055be6",
"css/output.css": "c99c436db2287447633f9678f2954b40",
"css/tailwind-input.css": "b25550adfadeca2b76f2ad638bc7446e",
"css/tailwind.css": "beba90e3a74c7b50d3b1eaa497925ebe",
"download-worker.js": "2a7f093a15ccccf5fe7f9ced22b2f828",
"entry.html": "35703527cab0fa4b2059ea328156460a",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"flutter_bootstrap.js": "c41dddfbc0eeb5f7b17aa9d5789c2344",
"fonts/fontawesome-webfont.ttf": "dcb26c7239d850266941e80370e207c1",
"fonts/fontawesome-webfont.woff": "3293616ec0c605c7c2db25829a0a509e",
"fonts/fontawesome-webfont.woff2": "af7ae505a9eed503f8b8e6982036873e",
"fonts/MaterialIcons-Regular.otf": "912f8648735d11cb5529bb8f78462471",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "196b0dd41e8ec89cb925f259b48f2f04",
"/": "196b0dd41e8ec89cb925f259b48f2f04",
"js/cart-module.js": "5fb14efd822569d084bd1052bf6b94b5",
"js/core-module.js": "bd6be87347d336c0e54aa9040812623a",
"js/data-module.js": "a49aef1d7fbf1b319fe8ceecc478588d",
"js/home-module.js": "133ed24a77f4ac75b3569f98716e8bc8",
"js/quote-module.js": "7384d2ef73beab80aa2bee4bffc7c0a6",
"Logo.png": "0713184a50485dc0f3e68563824a511f",
"main.dart.js": "2bfb327a902777b746b4373527fba84c",
"parts_management.html": "a998fa724fd31295ecd9d2b5aa2fcad1",
"price_calculator.html": "3e2916d23071c4d7e9cb7946e97dd989",
"qrcode.min.js": "517b55d3688ce9ef1085a3d9632bcb97",
"sample.jpg": "ae71152cdc580ffd5672d1be01028f3c",
"sync.ffs_db": "29c3604d5d9fe27a49ac9d8498e9d72e",
"user_management.html": "866822e6b0321317ff0ffc0a13b17b6f",
"version.json": "5e2f4b86383b5bc577f335589884c2ee",
"ws.js": "6e3ca71583984a9f4eee49d276a28194"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
