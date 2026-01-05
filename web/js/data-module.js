// 数据加载模块
// 包含数据加载、缓存和初始化相关函数

// 全局变量用于存储缓存数据和时间戳
let cachedTopParts = [];
let cachedTopFees = [];
let cachedTopFactors = [];

// 加载基础数据（带缓存和更新检查）
async function loadData() {
  try {
    // 首先检查所有数据是否有更新 - 只调用一次checkDataUpdate
    const updateCheck = await apiClient.checkDataUpdate();

    // 检查本地缓存的时间戳
    const cachedMachinesTimestamp = localStorage.getItem(
      "lastMachinesTimestamp"
    );
    const serverMachinesTimestamp = updateCheck.lastMachinesUpdate;

    if (
      !cachedMachinesTimestamp ||
      (serverMachinesTimestamp &&
        parseInt(cachedMachinesTimestamp) < serverMachinesTimestamp)
    ) {
      // 机器数据有更新，从服务器加载完整数据
      console.log("检测到机器数据更新，加载完整数据...");
      baseData = await apiClient.getMachines();

      // 缓存数据到localStorage
      localStorage.setItem("cachedMachines", JSON.stringify(baseData));
      localStorage.setItem(
        "lastMachinesTimestamp",
        (serverMachinesTimestamp || Date.now()).toString()
      ); // 更新时间戳

      // 缓存数据到内存变量
      cachedBaseData = baseData;

      document.getElementById(
        "dataStatus"
      ).innerHTML = `<div class="status-message success">成功加载 ${baseData.length} 条机器部件数据</div>`;
      console.log("机器部件数据已更新");
    } else {
      // 机器部件数据没有更新，使用缓存数据
      const localStorageData = localStorage.getItem("cachedMachines");

      if (localStorageData) {
        baseData = JSON.parse(localStorageData);
        console.log("使用缓存的机器数据");
      } else {
        // 如果localStorage没有数据，从服务器加载（首次访问）
        console.log("首次访问，从服务器加载机器数据...");
        baseData = await apiClient.getMachines();
        localStorage.setItem(
          "lastMachinesTimestamp",
          (updateCheck.lastMachinesUpdate || Date.now()).toString()
        );
        localStorage.setItem("cachedMachines", JSON.stringify(baseData));
      }

      document.getElementById(
        "dataStatus"
      ).innerHTML = `<div class="status-message success">使用缓存的机器数据 (${baseData.length} 条)</div>`;
    }

    // 同时获取部件数据（如果有更新）
    const partsTimestamp = localStorage.getItem("lastPartsTimestamp");
    const serverPartsTimestamp = updateCheck.lastPartsUpdate;

    if (
      !partsTimestamp ||
      (serverPartsTimestamp &&
        parseInt(partsTimestamp) < serverPartsTimestamp)
    ) {
      // 部件数据有更新，从服务器加载
      console.log("检测到部件数据更新，加载部件数据...");
      window.partsData = await apiClient.getParts();
      localStorage.setItem(
        "lastPartsTimestamp",
        (serverPartsTimestamp || Date.now()).toString()
      );
      // 将部件数据保存到localStorage缓存
      localStorage.setItem(
        "cachedParts",
        JSON.stringify(window.partsData)
      );
      console.log(
        `部件数据已更新，共 ${
          window.partsData ? window.partsData.length : 0
        } 条`
      );
    } else {
      // 部件数据没有更新，从缓存加载
      console.log("使用缓存的部件数据");
      const cachedPartsData = localStorage.getItem("cachedParts");
      if (cachedPartsData) {
        window.partsData = JSON.parse(cachedPartsData);
      }
    }

    // 确保所有数据项都有addedCount字段
    if (baseData && Array.isArray(baseData)) {
      baseData.forEach((item) => {
        if (item.addedCount === undefined) {
          item.addedCount = 0;
        }
      });
    }

    // 检查费用数据是否有更新
    const feesTimestamp = localStorage.getItem("lastFeesTimestamp");
    const serverFeesTimestamp = updateCheck.lastFeesUpdate;

    if (
      !feesTimestamp ||
      (serverFeesTimestamp &&
        parseInt(feesTimestamp) < serverFeesTimestamp)
    ) {
      // 费用数据有更新，从服务器加载
      console.log("检测到费用数据更新，加载费用数据...");
      window.feesData = await apiClient.getFees();
      localStorage.setItem(
        "lastFeesTimestamp",
        (serverFeesTimestamp || Date.now()).toString()
      );
      // 保存完整的费用数据到localStorage缓存
      localStorage.setItem("cachedFees", JSON.stringify(window.feesData));
      console.log(
        `费用数据已更新，共 ${
          window.feesData ? window.feesData.length : 0
        } 条`
      );
    } else {
      // 费用数据没有更新，从缓存加载完整数据
      console.log("使用缓存的费用数据");
      const cachedFeesData = localStorage.getItem("cachedFees");
      if (cachedFeesData) {
        window.feesData = JSON.parse(cachedFeesData);
      }
    }

    // 检查系数数据是否有更新
    const factorsTimestamp = localStorage.getItem("lastFactorsTimestamp");
    const serverFactorsTimestamp = updateCheck.lastFactorsUpdate;

    if (
      !factorsTimestamp ||
      (serverFactorsTimestamp &&
        parseInt(factorsTimestamp) < serverFactorsTimestamp)
    ) {
      // 系数数据有更新，从服务器加载
      console.log("检测到系数数据更新，加载系数数据...");
      window.factorsData = await apiClient.getFactors();
      localStorage.setItem(
        "lastFactorsTimestamp",
        (serverFactorsTimestamp || Date.now()).toString()
      );
      // 保存完整的系数数据到localStorage缓存
      localStorage.setItem(
        "cachedFactors",
        JSON.stringify(window.factorsData)
      );
      console.log(
        `系数数据已更新，共 ${
          window.factorsData ? window.factorsData.length : 0
        } 条`
      );
    } else {
      // 系数数据没有更新，从缓存加载完整数据
      console.log("使用缓存的系数数据");
      const cachedFactorsData = localStorage.getItem("cachedFactors");

      if (cachedFactorsData) {
        window.factorsData = JSON.parse(cachedFactorsData);
      }
    }

    // 检查最常用项目是否有更新（通过时间戳比较）
    // 使用已获取的updateCheck数据，避免重复调用apiClient.checkDataUpdate()
    // 最常用项目基于基础数据，因此直接使用基础数据的时间戳
    try {
      // 检查topUsedParts数据 - 基于本地partsData计算最常用部件
      const partsTimestamp = localStorage.getItem("lastPartsTimestamp");
      if (
        !partsTimestamp ||
        (updateCheck.lastPartsUpdate &&
          parseInt(partsTimestamp) < updateCheck.lastPartsUpdate)
      ) {
        // 部件数据已更新，基于新数据计算最常用的部件
        if (window.partsData && Array.isArray(window.partsData)) {
          // 基于partsData中的addedCount字段计算最常用的部件
          cachedTopParts = [...window.partsData]
            .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
            .slice(0, 5); // 取前5个最常用的部件
        } else {
          // 如果没有partsData，从服务器获取最常用数据
          cachedTopParts = await apiClient.getTopUsedParts();
        }
      } else {
        // 从缓存加载（从localStorage加载已缓存的数据）
        console.log("使用缓存的topUsedParts数据");
        try {
          const cachedData = localStorage.getItem("cachedTopUsedParts");
          if (cachedData) {
            cachedTopParts = JSON.parse(cachedData);
          } else {
            // 如果缓存中没有数据，但parts数据存在，基于本地数据计算
            if (window.partsData && Array.isArray(window.partsData)) {
              // 基于partsData中的addedCount字段计算最常用的部件
              cachedTopParts = [...window.partsData]
                .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
                .slice(0, 5); // 取前5个最常用的部件
            } else {
              // 如果partsData也不存在，从服务器获取
              cachedTopParts = await apiClient.getTopUsedParts();
            }
          }
        } catch (parseError) {
          console.error("解析缓存的topUsedParts数据失败:", parseError);
          // 如果解析失败，但parts数据存在，基于本地数据计算
          if (window.partsData && Array.isArray(window.partsData)) {
            // 基于partsData中的addedCount字段计算最常用的部件
            cachedTopParts = [...window.partsData]
              .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
              .slice(0, 5); // 取前5个最常用的部件
          } else {
            // 如果partsData也不存在，从服务器获取
            cachedTopParts = await apiClient.getTopUsedParts();
          }
        }
      }

      // 检查topUsedFees时间戳 - 基于完整费用数据计算最常用费用
      const feesTimestamp = localStorage.getItem("lastFeesTimestamp");
      if (
        !feesTimestamp ||
        (updateCheck.lastFeesUpdate &&
          parseInt(feesTimestamp) < updateCheck.lastFeesUpdate)
      ) {
        // 费用数据已更新，基于完整费用数据计算最常用的费用
        if (window.feesData && Array.isArray(window.feesData)) {
          // 基于feesData中的addedCount字段计算最常用的费用
          cachedTopFees = [...window.feesData]
            .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
            .slice(0, 5); // 取前5个最常用的费用
        } else {
          // 如果没有完整费用数据，从服务器获取最常用数据
          cachedTopFees = await apiClient.getTopUsedFees();
        }
      } else {
        // 从缓存加载最常用费用数据
        console.log("使用缓存的topUsedFees数据");
        try {
          const cachedData = localStorage.getItem("cachedTopUsedFees");
          if (cachedData) {
            cachedTopFees = JSON.parse(cachedData);
          } else {
            // 如果缓存中没有数据，但完整费用数据存在，基于本地数据计算
            if (window.feesData && Array.isArray(window.feesData)) {
              // 基于feesData中的addedCount字段计算最常用的费用
              cachedTopFees = [...window.feesData]
                .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
                .slice(0, 5); // 取前5个最常用的费用
            } else {
              // 如果完整费用数据也不存在，从服务器获取
              cachedTopFees = await apiClient.getTopUsedFees();
            }
          }
        } catch (parseError) {
          console.error("解析缓存的topUsedFees数据失败:", parseError);
          // 如果解析失败，但完整费用数据存在，基于本地数据计算
          if (window.feesData && Array.isArray(window.feesData)) {
            // 基于feesData中的addedCount字段计算最常用的费用
            cachedTopFees = [...window.feesData]
              .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
              .slice(0, 5); // 取前5个最常用的费用
          } else {
            // 如果完整费用数据也不存在，从服务器获取
            cachedTopFees = await apiClient.getTopUsedFees();
          }
        }
      }

      // 检查topUsedFactors时间戳 - 基于完整系数数据计算最常用系数
      const factorsTimestamp = localStorage.getItem(
        "lastFactorsTimestamp"
      );
      if (
        !factorsTimestamp ||
        (updateCheck.lastFactorsUpdate &&
          parseInt(factorsTimestamp) < updateCheck.lastFactorsUpdate)
      ) {
        // 系数数据已更新，基于完整系数数据计算最常用的系数
        if (window.factorsData && Array.isArray(window.factorsData)) {
          // 基于factorsData中的addedCount字段计算最常用的系数
          cachedTopFactors = [...window.factorsData]
            .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
            .slice(0, 5); // 取前5个最常用的系数
        } else {
          // 如果没有完整系数数据，从服务器获取最常用数据
          cachedTopFactors = await apiClient.getTopUsedFactors();
        }
      } else {
        // 从缓存加载最常用系数数据
        console.log("使用缓存的topUsedFactors数据");
        try {
          const cachedData = localStorage.getItem("cachedTopUsedFactors");
          if (cachedData) {
            cachedTopFactors = JSON.parse(cachedData);
          } else {
            // 如果缓存中没有数据，但完整系数数据存在，基于本地数据计算
            if (window.factorsData && Array.isArray(window.factorsData)) {
              // 基于factorsData中的addedCount字段计算最常用的系数
              cachedTopFactors = [...window.factorsData]
                .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
                .slice(0, 5); // 取前5个最常用的系数
            } else {
              // 如果完整系数数据也不存在，从服务器获取
              cachedTopFactors = await apiClient.getTopUsedFactors();
            }
          }
        } catch (parseError) {
          console.error("解析缓存的topUsedFactors数据失败:", parseError);
          // 如果解析失败，但完整系数数据存在，基于本地数据计算
          if (window.factorsData && Array.isArray(window.factorsData)) {
            // 基于factorsData中的addedCount字段计算最常用的系数
            cachedTopFactors = [...window.factorsData]
              .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
              .slice(0, 5); // 取前5个最常用的系数
          } else {
            // 如果完整系数数据也不存在，从服务器获取
            cachedTopFactors = await apiClient.getTopUsedFactors();
          }
        }
      }

      // 同时保存数据到localStorage以便后续使用
      if (cachedTopParts) {
        localStorage.setItem(
          "cachedTopUsedParts",
          JSON.stringify(cachedTopParts)
        );
      }
      if (cachedTopFees) {
        localStorage.setItem(
          "cachedTopUsedFees",
          JSON.stringify(cachedTopFees)
        );
      }
      if (cachedTopFactors) {
        localStorage.setItem(
          "cachedTopUsedFactors",
          JSON.stringify(cachedTopFactors)
        );
      }
    } catch (e) {
      console.error("获取最常用项目失败:", e);
      // 如果获取最常用项目失败，使用空数组
      cachedTopParts = [];
      cachedTopFees = [];
      cachedTopFactors = [];
    }

    // 更新搜索框状态 - 始终启用搜索
    const searchInput = document.getElementById("searchInput");
    searchInput.disabled = false;
    searchInput.placeholder = "输入型号或名称进行搜索...";

    // 显示热门商品（被添加次数最多的前5个）
    showPopularItems();

    // 更新标题旁的统计数据
    updateStatsDisplay();
  } catch (error) {
    console.error("加载数据失败:", error);

    // 如果从服务器获取失败，尝试从localStorage缓存加载
    const localStorageData = localStorage.getItem("cachedMachines");
    if (localStorageData) {
      console.log("使用localStorage缓存数据（服务器加载失败）");
      baseData = JSON.parse(localStorageData);

      // 确保所有数据项都有addedCount字段（如果不存在则初始化为0）
      if (baseData && Array.isArray(baseData)) {
        baseData.forEach((item) => {
          if (item.addedCount === undefined) {
            item.addedCount = 0;
          }
        });
      }

      document.getElementById(
        "dataStatus"
      ).innerHTML = `<div class="status-message success">使用缓存数据 (${baseData.length} 条)</div>`;

      // 更新搜索框状态
      const searchInput = document.getElementById("searchInput");
      searchInput.disabled = false;
      searchInput.placeholder = "输入型号或名称进行搜索...";

      // 显示热门商品
      showPopularItems();

      // 更新标题旁的统计数据
      updateStatsDisplay();
    } else {
      document.getElementById(
        "dataStatus"
      ).innerHTML = `<div class="status-message error">从服务器加载数据失败: ${error.message}</div>`;
    }
  }
}

// 页面加载时初始化
window.onload = async function () {
  // 首先进行认证检查
  if (typeof checkAuth === "function") {
    const isAuthenticated = await checkAuth();
    if (!isAuthenticated) {
      return; // 如果认证失败，不继续初始化
    }
  }

  // 自动加载数据（包含最常用项目的加载）
  await loadData();

  // 控制按钮的可见性（统一调用，避免重复API调用）
  if (typeof controlButtonsVisibility === "function") {
    controlButtonsVisibility();
  }

  // 初始化购物车计数
  updateCartCount();

  // 绑定登出按钮事件
  document
    .getElementById("logout-btn")
    ?.addEventListener("click", logout);

  // 初始化浮动按钮显示
  updateFloatingButtons();

  // 初始化最常用项目显示 - 为部件、费用、系数分别显示
  // 直接调用而不是使用setTimeout，确保在数据加载完成后立即显示
  await showTopUsedItems("parts");
};