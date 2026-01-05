// 核心功能模块
// 包含全局变量、API客户端、认证和通用函数

// 全局变量
let baseData = []; // 存储基础数据
let selectedItems = []; // 存储已选择的项目
let tempItems = []; // 存储其它费用和系数
let cartItems = []; // 存储购物车项目
let currentView = "main"; // 当前显示的视图：main, cart, quote

let cachedBaseData = null;
let lastUpdateTime = null;

// HTTP API通信模块
const apiClient = {
  // 通用请求函数
  async request(endpoint, options = {}) {
    const url = `/api${endpoint}`;
    const config = {
      headers: {
        "Content-Type": "application/json",
        ...options.headers,
      },
      ...options,
    };

    try {
      const response = await fetch(url, config);

      if (!response.ok) {
        // 尝试解析错误响应，但如果失败则使用状态文本
        try {
          const errorData = await response.json();
          throw new Error(
            errorData.error ||
            `HTTP ${response.status}: ${response.statusText}`
          );
        } catch (parseError) {
          // 如果响应不是JSON，直接使用状态文本
          throw new Error(
            `HTTP ${response.status}: ${response.statusText}`
          );
        }
      }

      const data = await response.json();
      return data;
    } catch (error) {
      console.error(`API请求失败 ${url}:`, error);
      throw error;
    }
  },

  // 获取机器部件
  getMachines: async function () {
    const response = await this.request("/machines");
    // 如果服务器返回了时间戳，更新本地缓存的时间戳
    if (response.timestamp) {
      // 更新machines的时间戳缓存
      if (typeof window !== "undefined") {
        if (!window.timestampCache) window.timestampCache = {};
        window.timestampCache.machines = response.timestamp;
      }
    }
    return response.data || response;
  },

  // 获取部件
  getParts: async function () {
    const response = await this.request("/parts");
    // 如果服务器返回了时间戳，更新本地缓存的时间戳
    if (response.timestamp) {
      // 这里可以更新parts的时间戳缓存
      if (typeof window !== "undefined") {
        if (!window.timestampCache) window.timestampCache = {};
        window.timestampCache.parts = response.timestamp;
      }
    }
    return response.data || response;
  },

  // 获取机器数量
  getMachinesCount: async function () {
    const response = await this.request("/machines/count");
    return response.count || response.data || 0;
  },

  // 获取部件数量
  getPartsCount: async function () {
    try {
      const response = await this.request("/parts/count");
      return response.count || response.data || 0;
    } catch (error) {
      // 如果count API不存在，回退到获取所有数据然后计数
      console.warn("使用回退方式获取部件数量:", error.message);
      const items = await this.getParts();
      return items.length || 0;
    }
  },

  // 获取部件统计信息
  getPartsStats: async function () {
    const response = await this.request("/parts-stats");
    return response;
  },

  // 获取最常用的部件（基于本地缓存数据计算）
  getTopUsedParts: async function () {
    // 检查本地是否已有部件数据
    if (
      window.partsData &&
      Array.isArray(window.partsData) &&
      window.partsData.length > 0
    ) {
      // 基于本地数据按addedCount排序，取前5个
      const topParts = [...window.partsData]
        .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
        .slice(0, 5);
      return topParts;
    } else {
      // 如果本地没有数据，尝试从localStorage加载缓存的部件数据
      const cachedPartsData = localStorage.getItem("cachedParts");
      if (cachedPartsData) {
        try {
          const partsFromCache = JSON.parse(cachedPartsData);
          if (
            Array.isArray(partsFromCache) &&
            partsFromCache.length > 0
          ) {
            // 基于缓存数据按addedCount排序，取前5个
            const topParts = [...partsFromCache]
              .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
              .slice(0, 5);
            return topParts;
          }
        } catch (e) {
          console.error("解析缓存的部件数据失败:", e);
        }
      }
      // 如果仍然没有数据，返回空数组
      return [];
    }
  },

  // 获取最常用的费用（基于本地缓存数据计算）
  getTopUsedFees: async function () {
    // 检查本地是否已有费用数据
    if (
      window.feesData &&
      Array.isArray(window.feesData) &&
      window.feesData.length > 0
    ) {
      // 基于本地数据按addedCount排序，取前5个
      const topFees = [...window.feesData]
        .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
        .slice(0, 5);
      return topFees;
    } else {
      // 如果本地没有数据，尝试从localStorage加载缓存的费用数据
      const cachedFeesData = localStorage.getItem("cachedFees");
      if (cachedFeesData) {
        try {
          const feesFromCache = JSON.parse(cachedFeesData);
          if (Array.isArray(feesFromCache) && feesFromCache.length > 0) {
            // 基于缓存数据按addedCount排序，取前5个
            const topFees = [...feesFromCache]
              .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
              .slice(0, 5);
            return topFees;
          }
        } catch (e) {
          console.error("解析缓存的费用数据失败:", e);
        }
      }
      // 如果仍然没有数据，返回空数组
      return [];
    }
  },

  // 获取最常用的系数（基于本地缓存数据计算）
  getTopUsedFactors: async function () {
    // 检查本地是否已有系数数据
    if (
      window.factorsData &&
      Array.isArray(window.factorsData) &&
      window.factorsData.length > 0
    ) {
      // 基于本地数据按addedCount排序，取前5个
      const topFactors = [...window.factorsData]
        .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
        .slice(0, 5);
      return topFactors;
    } else {
      // 如果本地没有数据，尝试从localStorage加载缓存的系数数据
      const cachedFactorsData = localStorage.getItem("cachedFactors");
      if (cachedFactorsData) {
        try {
          const factorsFromCache = JSON.parse(cachedFactorsData);
          if (
            Array.isArray(factorsFromCache) &&
            factorsFromCache.length > 0
          ) {
            // 基于缓存数据按addedCount排序，取前5个
            const topFactors = [...factorsFromCache]
              .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
              .slice(0, 5);
            return topFactors;
          }
        } catch (e) {
          console.error("解析缓存的系数数据失败:", e);
        }
      }
      // 如果仍然没有数据，返回空数组
      return [];
    }
  },

  // 检查数据是否有更新
  checkDataUpdate: async function () {
    const response = await this.request("/check-data-update");
    return response;
  },

  // 创建机器
  createMachine: async function (part) {
    const response = await this.request("/machines", {
      method: "POST",
      body: JSON.stringify(part),
    });
    return response.data;
  },

  // 创建部件
  createPart: async function (part) {
    const response = await this.request("/parts", {
      method: "POST",
      body: JSON.stringify(part),
    });
    // 返回完整响应，包括success、data和timestamp
    return response;
  },

  // 创建其它费用
  createTempFee: async function (fee) {
    const response = await this.request("/temp-fees", {
      method: "POST",
      body: JSON.stringify(fee),
    });
    // 返回完整响应，包括success、data和timestamp
    return response;
  },

  // 更新其它费用
  updateTempFee: async function (id, fee) {
    const response = await this.request(
      `/temp-fees/${encodeURIComponent(id)}`,
      {
        method: "PUT",
        body: JSON.stringify(fee),
      }
    );
    // 如果服务器返回了时间戳，更新本地缓存的时间戳
    if (response.timestamp) {
      if (typeof window !== "undefined") {
        if (!window.timestampCache) window.timestampCache = {};
        window.timestampCache.fees = response.timestamp;
      }
    }
    return response;
  },

  // 删除其它费用
  deleteTempFee: async function (id) {
    const response = await this.request(
      `/temp-fees/${encodeURIComponent(id)}`,
      {
        method: "DELETE",
      }
    );
    // 如果服务器返回了时间戳，更新本地缓存的时间戳
    if (response.timestamp) {
      if (typeof window !== "undefined") {
        if (!window.timestampCache) window.timestampCache = {};
        window.timestampCache.fees = response.timestamp;
      }
    }
    return response;
  },

  // 创建临时系数
  createTempFactor: async function (factor) {
    const response = await this.request("/temp-factors", {
      method: "POST",
      body: JSON.stringify(factor),
    });
    // 返回完整响应，包括success、data和timestamp
    return response;
  },

  // 更新临时系数
  updateTempFactor: async function (id, factor) {
    const response = await this.request(
      `/temp-factors/${encodeURIComponent(id)}`,
      {
        method: "PUT",
        body: JSON.stringify(factor),
      }
    );
    // 如果服务器返回了时间戳，更新本地缓存的时间戳
    if (response.timestamp) {
      if (typeof window !== "undefined") {
        if (!window.timestampCache) window.timestampCache = {};
        window.timestampCache.factors = response.timestamp;
      }
    }
    return response;
  },

  // 删除临时系数
  deleteTempFactor: async function (id) {
    const response = await this.request(
      `/temp-factors/${encodeURIComponent(id)}`,
      {
        method: "DELETE",
      }
    );
    // 如果服务器返回了时间戳，更新本地缓存的时间戳
    if (response.timestamp) {
      if (typeof window !== "undefined") {
        if (!window.timestampCache) window.timestampCache = {};
        window.timestampCache.factors = response.timestamp;
      }
    }
    return response;
  },

  // 更新机器
  updateMachine: async function (id, part) {
    const response = await this.request(`/machines/${id}`, {
      method: "PUT",
      body: JSON.stringify(part),
    });
    return response.data;
  },

  // 更新部件
  updatePart: async function (id, part) {
    const response = await this.request(`/parts/${id}`, {
      method: "PUT",
      body: JSON.stringify(part),
    });
    return response.data;
  },

  // 删除机器
  deleteMachine: async function (id) {
    const response = await this.request(`/machines/${id}`, {
      method: "DELETE",
    });
    return response;
  },

  // 获取所有费用
  getFees: async function () {
    const response = await this.request("/temp-fees");
    // 如果服务器返回了时间戳，更新本地缓存的时间戳
    if (response.timestamp) {
      if (typeof window !== "undefined") {
        if (!window.timestampCache) window.timestampCache = {};
        window.timestampCache.fees = response.timestamp;
      }
    }
    return response.data || response;
  },

  // 获取所有系数
  getFactors: async function () {
    const response = await this.request("/temp-factors");
    // 如果服务器返回了时间戳，更新本地缓存的时间戳
    if (response.timestamp) {
      if (typeof window !== "undefined") {
        if (!window.timestampCache) window.timestampCache = {};
        window.timestampCache.factors = response.timestamp;
      }
    }
    return response.data || response;
  },
};

// 全局变量存储用户角色信息，避免重复请求
let currentUserRole = null;

// 检查登录状态
async function checkAuth() {
  const sessionId = localStorage.getItem("sessionId");
  if (!sessionId) {
    // 未登录，重定向到登录页面
    alert("请先登录系统");
    window.location.href = "auth.html";
    return false;
  }

  // 验证会话是否仍然有效
  try {
    // 使用更安全的API端点，只返回当前用户信息
    const response = await fetch("/api/session-validation", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ sessionId: sessionId }),
    });

    if (!response.ok) {
      // 如果API返回错误，会话可能已过期，重定向到登录页面
      window.location.href = "auth.html";
      return false;
    }

    const result = await response.json();
    if (!result.success) {
      window.location.href = "auth.html";
      return false;
    }
  } catch (error) {
    console.error("验证会话失败:", error);
    window.location.href = "auth.html";
    return false;
  }

  return true;
}

// 获取用户角色（使用缓存的角色信息）
async function checkUserRole() {
  if (currentUserRole !== null) {
    return currentUserRole; // 直接返回已缓存的角色信息
  }

  const sessionId = localStorage.getItem("sessionId");
  if (!sessionId) {
    return null;
  }

  try {
    // 使用安全的API端点获取当前用户信息（只返回当前用户信息）
    const response = await fetch("/api/current-user-info", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ sessionId: sessionId }),
    });

    if (!response.ok) {
      console.error("获取用户信息失败:", response.status);
      return null;
    }

    const result = await response.json();
    if (result.success && result.user) {
      currentUserRole = result.user.role; // 缓存角色信息
      return result.user.role;
    }
  } catch (error) {
    console.error("获取用户信息时出错:", error);
  }

  return null;
}

// 控制零件管理按钮、上传按钮和编辑按钮的显示（统一函数，避免重复API调用）
async function controlButtonsVisibility() {
  // 获取用户角色（只调用一次）
  const userRole = await checkUserRole();

  // 控制零件管理按钮的显示
  const partsManagementBtn = document.getElementById(
    "parts-management-btn"
  );
  if (partsManagementBtn) {
    if (userRole !== "admin") {
      // 如果不是管理员，隐藏零件管理按钮
      partsManagementBtn.style.display = "none";
    } else {
      // 如果是管理员，显示零件管理按钮
      partsManagementBtn.style.display = "block";
    }
  } else {
    console.error("找不到零件管理按钮");
  }

  // 控制上传按钮的显示
  const uploadBtn = document.getElementById("uploadBtn");
  if (uploadBtn) {
    if (userRole !== "admin") {
      // 如果不是管理员，隐藏上传按钮
      uploadBtn.style.display = "none";
    } else {
      // 如果是管理员，显示上传按钮
      uploadBtn.style.display = "block";
    }
  } else {
    console.error("找不到上传按钮");
  }

  // 控制编辑按钮的显示
  const editButton = document.getElementById("editButton");
  if (editButton) {
    if (userRole !== "admin") {
      // 如果不是管理员，隐藏编辑按钮
      editButton.style.display = "none";
    } else {
      // 如果是管理员，显示编辑按钮
      editButton.style.display = "block";
    }
  }
}

// 用于记录需要批量更新使用次数的项目
let itemsForBatchUpdate = [];

// 记录需要批量更新使用次数的项目
function recordItemUsageForBatchUpdate(
  itemId,
  type = "machines"
) {
  // 检查项目是否已在记录列表中（同时比较ID和类型）
  const existingIndex = itemsForBatchUpdate.findIndex(
    (item) => item.id === itemId && item.type === type
  );

  if (existingIndex !== -1) {
    // 如果已存在，增加计数
    itemsForBatchUpdate[existingIndex].count += 1;
  } else {
    // 如果不存在，添加新记录
    itemsForBatchUpdate.push({
      id: itemId,
      type: type,
      count: 1,
    });
  }
}

// 批量更新项目使用次数
async function batchUpdateItemUsage() {
  if (itemsForBatchUpdate.length === 0) {
    return; // 没有需要更新的项目
  }

  try {
    // 准备批量更新数据
    const batchData = {
      items: itemsForBatchUpdate.map(item => ({
        type: item.type,
        id: item.id, // 使用ID字段进行更新
        count: item.count || 1
      }))
    };

    // 尝试使用批量更新API
    const batchResponse = await apiClient.request('/batch-update-added-count', {
      method: 'POST',
      body: JSON.stringify(batchData)
    });

    if (batchResponse.success) {
      console.log(`批量更新完成: ${batchResponse.machinesUpdated}个机器, ${batchResponse.partsUpdated}个部件, ${batchResponse.feesUpdated}个费用, ${batchResponse.factorsUpdated}个系数`);
    } else {
      console.error('批量更新失败:', batchResponse.error);
      throw new Error('批量更新失败');
    }

    // 更新本地缓存中的addedCount字段
    await updateLocalCacheAfterBatchUpdate();

    // 清空记录列表
    itemsForBatchUpdate = [];
  } catch (error) {
    console.error("批量更新项目使用次数失败:", error);
    // 批量更新失败，回退到逐个更新
    console.warn('回退到逐个更新模式');

    // 逐个更新每个项目
    for (const item of itemsForBatchUpdate) {
      // 根据不同类型调用不同的API
      let response;
      switch (item.type) {
        case "machines":
          response = await apiClient.request(
            `/machines/${encodeURIComponent(item.id)}`,
            {
              method: "PUT",
              body: JSON.stringify({
                action: "incrementAddedCount",
                id: item.id,
              }),
            }
          );
          break;
        case "parts":
          // 对于incrementAddedCount操作，使用request方法直接调用API
          response = await apiClient.request(
            `/parts/${encodeURIComponent(item.id)}`,
            {
              method: "PUT",
              body: JSON.stringify({
                action: "incrementAddedCount",
                id: item.id,
              }),
            }
          );
          break;
        case "fees":
          response = await apiClient.request(
            `/temp-fees/${encodeURIComponent(item.id)}`,
            {
              method: "PUT",
              body: JSON.stringify({
                action: "incrementAddedCount",
                id: item.id,
              }),
            }
          );
          break;
        case "factors":
          response = await apiClient.request(
            `/temp-factors/${encodeURIComponent(item.id)}`,
            {
              method: "PUT",
              body: JSON.stringify({
                action: "incrementAddedCount",
                id: item.id,
              }),
            }
          );
          break;
        default:
          console.warn(`未知的项目类型: ${item.type}`);
          continue;
      }

      if (response && response.success) {
        console.log(`${item.type} ${item.id} 使用次数已更新`);
      } else {
        console.error(
          `${item.type} ${item.id} 更新失败:`,
          response?.error
        );
      }
    }

    // 更新本地缓存中的addedCount字段
    await updateLocalCacheAfterBatchUpdate();

    // 清空记录列表
    itemsForBatchUpdate = [];
  }
}

// 更新本地缓存中的addedCount字段
async function updateLocalCacheAfterBatchUpdate() {
  // 更新各种缓存数据
  if (window.baseData && Array.isArray(window.baseData)) {
    itemsForBatchUpdate
      .filter((item) => item.type === "machine_parts")
      .forEach((updateItem) => {
        const baseDataIndex = window.baseData.findIndex(
          (item) => item.Model === updateItem.model
        );
        if (baseDataIndex !== -1) {
          window.baseData[baseDataIndex].addedCount =
            (window.baseData[baseDataIndex].addedCount || 0) +
            updateItem.count;
        }
      });
  }

  if (window.partsData && Array.isArray(window.partsData)) {
    itemsForBatchUpdate
      .filter((item) => item.type === "parts")
      .forEach((updateItem) => {
        const partsDataIndex = window.partsData.findIndex(
          (item) => item.model === updateItem.model
        );
        if (partsDataIndex !== -1) {
          window.partsData[partsDataIndex].addedCount =
            (window.partsData[partsDataIndex].addedCount || 0) +
            updateItem.count;
        }
      });
  }

  if (window.feesData && Array.isArray(window.feesData)) {
    itemsForBatchUpdate
      .filter((item) => item.type === "fees")
      .forEach((updateItem) => {
        const feesDataIndex = window.feesData.findIndex(
          (item) => item.name === updateItem.model
        );
        if (feesDataIndex !== -1) {
          window.feesData[feesDataIndex].addedCount =
            (window.feesData[feesDataIndex].addedCount || 0) +
            updateItem.count;
        }
      });
  }

  if (window.factorsData && Array.isArray(window.factorsData)) {
    itemsForBatchUpdate
      .filter((item) => item.type === "factors")
      .forEach((updateItem) => {
        const factorsDataIndex = window.factorsData.findIndex(
          (item) => item.name === updateItem.model
        );
        if (factorsDataIndex !== -1) {
          window.factorsData[factorsDataIndex].addedCount =
            (window.factorsData[factorsDataIndex].addedCount || 0) +
            updateItem.count;
        }
      });
  }
}

// 记录项目使用情况到服务器（不触发数据更新检查）
async function recordItemUsage(itemModel) {
  try {
    // 简单地向服务器发送添加次数增加的请求，但不影响主要数据
    const response = await apiClient.request(
      `/machines/${encodeURIComponent(itemModel)}`,
      {
        method: "PUT",
        body: JSON.stringify({
          action: "incrementAddedCount",
          model: itemModel,
        }),
      }
    );
    console.log("项目使用情况已记录:", response.message || response);
  } catch (error) {
    console.error("记录项目使用情况失败:", error);
  }
}

// 更新项目被添加次数并同步到localStorage
function updateAddedCount(model) {
  // 在baseData中找到对应的项目并更新addedCount
  const baseDataIndex = baseData.findIndex(
    (item) => item.Model === model
  );
  if (baseDataIndex !== -1) {
    // 如果addedCount字段不存在，初始化为1，否则递增
    if (baseData[baseDataIndex].addedCount === undefined) {
      baseData[baseDataIndex].addedCount = 1;
    } else {
      baseData[baseDataIndex].addedCount += 1;
    }
  }

  // 在localStorage缓存中也更新addedCount
  const cachedData = JSON.parse(
    localStorage.getItem("cachedMachines") || "[]"
  );
  if (cachedData && cachedData.length > 0) {
    const cachedIndex = cachedData.findIndex(
      (item) => item.Model === model
    );
    if (cachedIndex !== -1) {
      if (cachedData[cachedIndex].addedCount === undefined) {
        cachedData[cachedIndex].addedCount = 1;
      } else {
        cachedData[cachedIndex].addedCount += 1;
      }
    } else {
      // 如果项目在localStorage中不存在但存在于baseData中，也将其添加到缓存
      const baseItem = baseData.find((item) => item.Model === model);
      if (baseItem) {
        if (baseItem.addedCount === undefined) {
          baseItem.addedCount = 1;
        } else {
          baseItem.addedCount += 1;
        }
      }
    }

    // 同步更新后的数据到localStorage
    localStorage.setItem("cachedMachines", JSON.stringify(cachedData));
  } else {
    // 如果localStorage中没有数据，使用baseData并更新addedCount
    const localStorageData = JSON.parse(JSON.stringify(baseData));
    localStorageData.forEach((item) => {
      if (item.Model === model) {
        if (item.addedCount === undefined) {
          item.addedCount = 1;
        } else {
          item.addedCount += 1;
        }
      }
    });
    localStorage.setItem(
      "cachedMachines",
      JSON.stringify(localStorageData)
    );
  }
}

// 添加项目到选择列表
function addItem(item) {
  const newItem = {
    id: Date.now(), // 唯一ID
    type: "机器",
    model: item.Model,
    name: item.OriginalModel,
    basePrice: item.ShowPrice,
    actualPrice: item.ShowPrice, // 默认实际价格等于基础价格
    quantity: 1, // 默认数量为1
  };

  selectedItems.push(newItem);
  renderSelectedItems();
  updateTotal();

  // 不再清除搜索结果，允许重复添加
  // document.getElementById('searchInput').value = '';
  // document.getElementById('searchResults').innerHTML = '';
}

// 更新购物车计数显示
function updateCartCount() {
  const count = cartItems.reduce((sum, item) => sum + item.quantity, 0);
  document.getElementById("cartItemCount").textContent = count;
  document.getElementById("floatingCartCount").textContent = count;

  // 控制清空购物车按钮的显示：只有在购物车有内容时才显示，并且不在报价单页面
  const clearCartBtn = document.getElementById("clearCartBtn");
  if (currentView !== "quote" && count > 0) {
    clearCartBtn.style.display = "flex";
  } else {
    clearCartBtn.style.display = "none";
  }

  updateCartSummary();

  // 更新浮动按钮显示
  updateFloatingButtons();
}

// 更新购物车摘要显示
function updateCartSummary() {
  const cartSummary = document.getElementById("cartSummary");

  if (cartItems.length === 0 && tempItems.length === 0) {
    cartSummary.innerHTML =
      '<p style="text-align: center; color: #666;">购物车为空，请添加商品</p>';
    return;
  }

  let html = `
          <table style="width: 100%; border-collapse: collapse;">
              <thead>
                  <tr style="background-color: #f2f2f2;">
                      <th style="border: 1px solid #ddd; padding: 10px; text-align: left;">型号</th>
                      <th style="border: 1px solid #ddd; padding: 10px; text-align: right;">单价</th>
                      <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">数量</th>
                      <th style="border: 1px solid #ddd; padding: 10px; text-align: right;">小计</th>
                  </tr>
              </thead>
              <tbody>
          `;

  // 显示购物车项目
  cartItems.forEach((item) => {
    const subtotal = item.actualPrice * item.quantity;
    html += `
              <tr>
                  <td style="border: 1px solid #ddd; padding: 10px;">
                      <strong>${item.model}</strong>
                  </td>
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      item.actualPrice
    )}</td>
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">${item.quantity
      }</td>
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
        subtotal
      )}</td>
              </tr>
          `;
  });

  // 计算总计
  let baseTotal = cartItems.reduce(
    (sum, item) => sum + item.actualPrice * item.quantity,
    0
  );
  let tempFees = tempItems
    .filter((item) => item.displayType === "费用")
    .reduce((sum, item) => sum + item.actualAmount, 0);
  let factor = tempItems
    .filter((item) => item.displayType === "系数")
    .reduce((prod, item) => prod * item.value, 1);
  let total = (baseTotal + tempFees) * factor;

  html += `
              </tbody>
          </table>

          <div style="margin-top: 15px; text-align: right; font-weight: bold;">
      `;

  // 只有在有购物车项目时才显示商品小计
  if (cartItems.length > 0) {
    html += `<div>商品小计: ${formatCurrency(baseTotal)}</div>`;
  } else if (tempItems.length > 0) {
    html += `<div>商品小计: ${formatCurrency(0)}</div>`; // 没有购物车项目时显示0
  }

  if (tempItems.length > 0) {
    // 先显示其它费用
    tempItems
      .filter((item) => item.displayType === "费用")
      .forEach((item) => {
        html += `<div>其它费用 (${item.name}): ${formatCurrency(
          item.actualAmount
        )}</div>`;
      });

    // 再显示系数
    tempItems
      .filter((item) => item.displayType === "系数")
      .forEach((item) => {
        html += `<div>系数 (${item.name}): ${item.value}</div>`;
      });
  }

  html += `
              <div style="margin-top: 10px; font-size: 1.2em; color: #e74c3c;">总计: ${formatCurrency(
    total
  )}</div>
          </div>
      `;

  cartSummary.innerHTML = html;
}

// 更新浮动按钮显示状态
function updateFloatingButtons() {
  // 获取浮动按钮元素
  const allFloatingCarts = document.querySelectorAll(".floating-cart");
  const clearCartBtn = document.getElementById("clearCartBtn");
  const quoteButtons = document.querySelector(".floating-quote-buttons");

  // 分别处理普通购物车按钮和清空购物车按钮
  allFloatingCarts.forEach((btn) => {
    if (btn.id !== "clearCartBtn") {
      // 普通购物车按钮
      if (currentView === "quote") {
        btn.style.display = "none";
      } else {
        // 在主页和购物车页面始终显示购物车按钮
        btn.style.display = currentView !== "quote" ? "flex" : "none";
      }
    }
  });

  if (currentView === "quote") {
    // 在报价单页面，隐藏清空购物车按钮
    if (clearCartBtn) clearCartBtn.style.display = "none";
    // 显示报价单按钮
    if (quoteButtons) quoteButtons.style.display = "flex";
  } else {
    // 在其他页面，显示清空购物车按钮（如果购物车有内容）
    if (clearCartBtn) {
      const cartCount = cartItems.reduce(
        (sum, item) => sum + item.quantity,
        0
      );
      clearCartBtn.style.display = cartCount > 0 ? "flex" : "none";
    }
    // 隐藏报价单按钮
    if (quoteButtons) quoteButtons.style.display = "none";
  }
}

// 显示上传模态框
function showUploadModal() {
  document.getElementById("uploadModal").style.display = "block";
}

// 关闭上传模态框
function closeUploadModal() {
  document.getElementById("uploadModal").style.display = "none";
}

// 上传文件
async function uploadFile() {
  const fileInput = document.getElementById("uploadFile");
  const file = fileInput.files[0];

  if (!file) {
    showMessage("请选择要上传的文件", "error");
    return;
  }

  const formData = new FormData();
  formData.append("file", file);

  try {
    // 显示上传进度信息
    showMessage("正在上传文件...", "success");

    // 发送文件到服务器
    const response = await fetch("/api/upload-machines", {
      method: "POST",
      body: formData,
    });

    const result = await response.json();

    if (response.ok) {
      showMessage("文件上传成功", "success");
      closeUploadModal();

      // 重新加载数据以显示新上传的内容
      await loadData();
    } else {
      showMessage(`上传失败: ${result.error || "未知错误"}`, "error");
    }
  } catch (error) {
    console.error("上传文件时出错:", error);
    showMessage(`上传失败: ${error.message}`, "error");
  }
}

// 登出功能
async function logout() {
  try {
    // 从localStorage中获取sessionId
    const sessionId = localStorage.getItem("sessionId");

    if (sessionId) {
      // 调用后端API登出（可选，清理服务器端会话）
      await apiClient
        .request("/users/logout", {
          method: "POST",
          body: JSON.stringify({ sessionId: sessionId }),
        })
        .catch((error) => {
          // 如果登出API调用失败，也不影响本地登出
          console.warn("登出API调用失败:", error);
        });
    }

    // 清除本地存储的会话信息
    localStorage.removeItem("sessionId");
    localStorage.removeItem("username");

    // 重定向到登录页面
    window.location.href = "auth.html";
  } catch (error) {
    console.error("登出过程中发生错误:", error);
    // 即使出错也清除本地会话并重定向
    localStorage.removeItem("sessionId");
    localStorage.removeItem("username");
    window.location.href = "auth.html";
  }
}

// 回到主页功能
function goToHomePage() {
  // 重定向到主页
  window.location.href = "entry.html";
}

// 跳转到零件管理页面
function goToPartsManagement() {
  window.location.href = "parts_management.html";
}

// 格式化金额（每三位添加逗号）
function formatCurrency(amount) {
  return parseFloat(amount).toLocaleString("zh-CN", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
}

// 显示消息
function showMessage(message, type) {
  const messageDiv = document.createElement("div");
  messageDiv.className = `status-message ${type}`;
  messageDiv.textContent = message;
  messageDiv.style.position = "fixed";
  messageDiv.style.top = "20px";
  messageDiv.style.right = "20px";
  messageDiv.style.zIndex = "1000";
  messageDiv.style.padding = "10px 20px";
  messageDiv.style.borderRadius = "4px";
  messageDiv.style.boxShadow = "0 2px 10px rgba(0,0,0,0.1)";

  document.body.appendChild(messageDiv);

  // 3秒后自动移除消息
  setTimeout(() => {
    document.body.removeChild(messageDiv);
  }, 3000);
}

// 更新标题旁的统计数据
function updateStatsDisplay() {
  // 获取机器数量（MachinePart的数量）
  const machineCount = baseData && baseData.length ? baseData.length : 0;

  // 获取部件数量（Part的数量）
  const partCount =
    window.partsData && window.partsData.length
      ? window.partsData.length
      : 0;

  document.getElementById(
    "statsDisplay"
  ).innerHTML = `(<span title="机器数量">机器: ${machineCount}</span>, <span title="部件数量">部件: ${partCount}</span>)`;
}
