let videoUrl;
let totalSize;
let chunkSize;
let cachedChunks;
let isAndroidTablet;
let activeRequests = 0;
const maxConcurrentRequests = 3; // 安卓平板平板限制并发数
const retryLimit = 3;

self.onmessage = async (e) => {
    if (e.data.type === 'init') {
        videoUrl = e.data.videoUrl;
        totalSize = e.data.totalSize;
        chunkSize = e.data.chunkSize;
        cachedChunks = e.data.cachedChunks || [];
        isAndroidTablet = e.data.isAndroidTablet;

        // 开始下载分块
        await startDownloading();
    }
};

async function startDownloading() {
    const chunks = [];
    // 计算需要下载的分块
    for (let start = 0; start < totalSize; start += chunkSize) {
        const end = Math.min(start + chunkSize - 1, totalSize - 1);
        // 检查是否已缓存
        const isCached = cachedChunks.some(c => c.start === start && c.end === end);
        if (!isCached) {
            chunks.push({ start, end });
        }
    }

    // 计算已完成进度
    const completedSize = cachedChunks.reduce((sum, c) => sum + (c.end - c.start + 1), 0);
    sendProgress(completedSize);

    // 并发下载分块
    await processChunksInParallel(chunks);
}

async function processChunksInParallel(chunks) {
    const results = [];
    for (const chunk of chunks) {
        // 控制并发数
        if (isAndroidTablet && activeRequests >= maxConcurrentRequests) {
            await new Promise(resolve => {
                const check = () => {
                    if (activeRequests < maxConcurrentRequests) resolve();
                    else setTimeout(check, 100);
                };
                check();
            });
        }

        results.push(downloadChunk(chunk.start, chunk.end));
    }
    await Promise.all(results);

    // 所有分块下载完成
    self.postMessage({ type: 'complete' });
}

async function downloadChunk(start, end, retryCount = 0) {
    if (retryCount >= retryLimit) {
        self.postMessage({
            type: 'error',
            error: `分块 ${start}-${end} 下载失败，已达最大重试次数`
        });
        return;
    }

    try {
        activeRequests++;
        const response = await fetch(videoUrl, {
            headers: { 'Range': `bytes=${start}-${end}` }
        });

        if (!response.ok && response.status !== 206) {
            throw new Error(`HTTP错误: ${response.status}`);
        }

        const blob = await response.blob();
        self.postMessage({
            type: 'chunk',
            start,
            end,
            blob
        });

        // 发送进度更新
        sendProgress(end);
    } catch (error) {
        console.error(`分块 ${start}-${end} 下载失败，正在重试（${retryCount + 1}/${retryLimit}）`, error);
        // 指数退避重试
        await new Promise(resolve => setTimeout(resolve, 1000 * Math.pow(2, retryCount)));
        return downloadChunk(start, end, retryCount + 1);
    } finally {
        activeRequests--;
    }
}

function sendProgress(downloadedSize) {
    const progress = Math.floor((downloadedSize / totalSize) * 100);
    self.postMessage({ type: 'progress', progress });
}
