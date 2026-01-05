// 报价单功能模块
// 包含生成报价单、汇率转换、页面切换等功能

// 生成报价单
function generateQuote() {
  // 在生成报价单前，批量更新所有使用过的项目次数
  batchUpdateItemUsage();

  // 使用当前的显示状态，默认为false（不显示单价）
  const showUnitPrice =
    window.currentShowUnitPrice !== undefined
      ? window.currentShowUnitPrice
      : false;

  closeCartModal();

  // 切换到报价单页面
  document.querySelector(".container").style.display = "none";
  document.getElementById("quotePage").style.display = "block";

  currentView = "quote";

  // 获取当前汇率设置
  const currencyCode = window.currencyCode || "CNY"; // 默认为CNY (人民币)
  const exchangeRate = window.exchangeRate || 1.0; // 默认汇率为1.0

  // 保存当前币种到全局变量，以便后续使用
  window.currentCurrencyCode = currencyCode;
  window.currentExchangeRate = exchangeRate;

  // 创建购物车和临时项目的副本用于显示，不修改原始数据
  const quoteCartItems = cartItems.map((item) => {
    // 创建项目副本
    const itemCopy = { ...item };

    // 保留基准价格（原始人民币价格），如果未定义则使用当前价格作为基准
    if (item.basePrice === undefined) {
      itemCopy.basePrice = itemCopy.actualPrice;
    } else {
      itemCopy.basePrice = item.basePrice;
    }

    // 应用汇率转换（如果当前设置了汇率）
    if (window.showForeignCurrency && exchangeRate) {
      // 使用两步计算公式：
      // 1. 当前数值 / 当前汇率 = 基准数值
      // 2. 基准数值 * 新汇率 = 新数值
      // 获取当前汇率（切换前的汇率）
      const currentRate = window.currentExchangeRate || 1.0;

      // 第一步：当前数值 / 当前汇率 = 基准数值
      const baseValue = itemCopy.actualPrice / currentRate;

      // 第二步：基准数值 * 新汇率 = 新数值
      itemCopy.displayPrice = baseValue * exchangeRate;
    } else {
      // 如果不显示外币，则直接使用当前的实际价格
      itemCopy.displayPrice = itemCopy.actualPrice;
    }

    return itemCopy;
  });

  const quoteTempItems = tempItems.map((item) => {
    // 创建项目副本
    const itemCopy = { ...item };

    // 保留基准金额（原始人民币金额），如果未定义则使用当前金额
    if (item.displayType === "费用" && item.baseAmount === undefined) {
      itemCopy.baseAmount = itemCopy.actualAmount;
    } else if (item.displayType === "费用") {
      itemCopy.baseAmount = item.baseAmount;
    }

    // 应用汇率转换（如果当前设置了汇率）
    if (
      item.displayType === "费用" &&
      window.showForeignCurrency &&
      exchangeRate
    ) {
      // 使用两步计算公式：
      // 1. 当前数值 / 当前汇率 = 基准数值
      // 2. 基准数值 * 新汇率 = 新数值
      // 获取当前汇率（切换前的汇率）
      const currentRate = window.currentExchangeRate || 1.0;

      // 第一步：当前数值 / 当前汇率 = 基准数值
      const baseValue = itemCopy.actualAmount / currentRate;

      // 第二步：基准数值 * 新汇率 = 新数值
      itemCopy.displayAmount = baseValue * exchangeRate;
    } else if (item.displayType === "费用") {
      // 如果不显示外币，则直接使用当前的实际金额
      itemCopy.displayAmount = itemCopy.actualAmount;
    } else {
      // 对于系数，不需要汇率转换
      itemCopy.displayValue = itemCopy.value;
    }

    return itemCopy;
  });

  // 计算总计（使用显示价格，已应用汇率转换）
  let baseTotal = quoteCartItems.reduce(
    (sum, item) => sum + item.displayPrice * item.quantity,
    0
  );

  let tempFees = quoteTempItems
    .filter((item) => item.displayType === "费用")
    .reduce((sum, item) => sum + item.displayAmount, 0);

  let factor = quoteTempItems
    .filter((item) => item.displayType === "系数")
    .reduce((prod, item) => prod * item.value, 1);

  let total = (baseTotal + tempFees) * factor;

  // 语言设置
  const isEnglish = window.isEnglishDisplay || false;

  // 根据语言设置定义标签，确保币种尾标正确显示
  const labels = isEnglish
    ? {
        quotation: "Quotation",
        no: "No.",
        name: "Name",
        unitPrice: "Unit Price",
        qty: "Qty.",
        subtotal: "Subtotal",
        subtotalExcludingFees: "Subtotal (Excluding Additional Fees)",
        add: "Add",
        total: `TOTAL (${currencyCode})`, // 总计后显示正确的币种代码
      }
    : {
        quotation: "报价单",
        no: "序号",
        name: "型号",
        unitPrice: "单价",
        qty: "数量",
        subtotal: "小计",
        subtotalExcludingFees: "商品小计",
        add: "其它费用",
        total: `总计 (${currencyCode})`, // 总计后显示正确的币种代码
      };

  let html = `
      <div class="section">
          <h2 style="text-align: center; color: #333;">${labels.quotation}</h2>
  `;

  if (showUnitPrice) {
    // 显示单价的表格
    html += `
      <table style="width: 100%; border-collapse: collapse; margin-top: 15px;">
          <thead>
              <tr style="background-color: #f2f2f2;">
                  <th style="border: 1px solid #ddd; padding: 10px; text-align: center; width: 60px; white-space: nowrap;">${labels.no}</th>
                  <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">${labels.name}</th>
                  <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">${labels.unitPrice}</th>
                  <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">${labels.qty}</th>
                  <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">${labels.subtotal}</th>
              </tr>
          </thead>
          <tbody>
      `;

    // 添加购物车项目（使用报价单副本的显示价格）
    quoteCartItems.forEach((item, index) => {
      const itemIndex = index + 1; // 序号从1开始

      const subtotal = item.displayPrice * item.quantity;

      html += `
          <tr>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; white-space: nowrap;">${itemIndex}</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">
                  <strong>${
                    item.model
                  }</strong>
              </td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      item.displayPrice
    )}</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">${
      item.quantity
    }</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      subtotal
    )}</td>
          </tr>
      `;
    });

    // 添加商品小计行
    if (quoteCartItems.length > 0) {
      html += `
          <tr style="background-color: #f0f8ff; font-weight: bold;">
              <td colspan="4" style="border: 1px solid #ddd; padding: 10px; text-align: right;">${
      labels.subtotalExcludingFees
    }</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      baseTotal
    )}</td>
          </tr>
          `;
    }

    // 添加其它费用（使用报价单副本的显示金额）
    quoteTempItems
      .filter((item) => item.displayType === "费用")
      .forEach((item) => {
        html += `
          <tr style="background-color: #f9f9f9;">
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; white-space: nowrap;"><strong>${
      labels.add
    }</strong></td>
              <td colspan="3" style="border: 1px solid #ddd; padding: 10px; text-align: center;"><strong>${
      item.name
    }</strong></td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      item.displayAmount
    )}</td>
          </tr>
      `;
      });

    // 添加系数（使用原始值，因为系数不涉及汇率转换）
    quoteTempItems
      .filter((item) => item.displayType === "系数")
      .forEach((item) => {
        html += `
          <tr style="background-color: #f9f9f9;">
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; white-space: nowrap;"><strong>${
      isEnglish
        ? "Factor"
        : "系数"
    }</strong></td>
              <td colspan="3" style="border: 1px solid #ddd; padding: 10px; text-align: center;"><strong>${
      item.name
    }</strong></td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">x ${
      item.value
    }</td>
          </tr>
      `;
      });

    // 显示总计，确保币种代码正确显示
    html += `
          <tr style="background-color: #e8f5e9; font-weight: bold;">
              <td colspan="4" style="border: 1px solid #ddd; padding: 10px; text-align: right;">${
      labels.total
    }</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      total
    )}</td>
          </tr>
      `;
    html += `
          </tbody>
      </table>
  `;
  } else {
    // 不显示单价的表格
    html += `
      <table style="width: 100%; border-collapse: collapse; margin-top: 15px;">
          <thead>
              <tr style="background-color: #f2f2f2;">
                  <th style="border: 1px solid #ddd; padding: 10px; text-align: center; width: 60px; white-space: nowrap;">${labels.no}</th>
                  <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">${labels.name}</th>
                  <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">${labels.qty}</th>
              </tr>
          </thead>
          <tbody>
    `;

    // 添加购物车项目（使用报价单副本）
    quoteCartItems.forEach((item, index) => {
      const itemIndex = index + 1; // 序号从1开始

      html += `
          <tr>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; white-space: nowrap;">${itemIndex}</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">
                  <strong>${item.model}</strong>
              </td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">${item.quantity}</td>
          </tr>
      `;
    });

    // 添加商品小计行
    if (quoteCartItems.length > 0) {
      html += `
          <tr style="background-color: #f0f8ff; font-weight: bold;">
              <td colspan="2" style="border: 1px solid #ddd; padding: 10px; text-align: right;">${
      labels.subtotalExcludingFees
    }</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      baseTotal
    )}</td>
          </tr>
      `;
    }

    // 添加其它费用（使用报价单副本的显示金额）
    quoteTempItems
      .filter((item) => item.displayType === "费用")
      .forEach((item) => {
        html += `
              <tr style="background-color: #f9f9f9;">
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: center; white-space: nowrap;"><strong>${
      labels.add
    }</strong></td>
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: center;"><strong>${
      item.name
    }</strong></td>
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      item.displayAmount
    )}</td>
              </tr>
          `;
      });

    // 添加系数（使用原始值）
    quoteTempItems
      .filter((item) => item.displayType === "系数")
      .forEach((item) => {
        html += `
          <tr style="background-color: #f9f9f9;">
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; white-space: nowrap;"><strong>${
      isEnglish
        ? "Factor"
        : "系数"
    }</strong></td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center;"><strong>${
      item.name
    }</strong></td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">x ${
      item.value
    }</td>
          </tr>
      `;
      });

    // 显示总计，确保币种代码正确显示
    html += `
      <tr style="background-color: #e8f5e9; font-weight: bold;">
          <td colspan="2" style="border: 1px solid #ddd; padding: 10px; text-align: right;">${
      labels.total
    }</td>
          <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      total
    )}</td>
      </tr>
  `;

    html += `
          </tbody>
      </table>
  `;
  }

  html += `
      </div>
  `;

  document.getElementById("quoteContent").innerHTML = html;

  // 保存当前的显示状态
  if (window.currentShowUnitPrice === undefined) {
    window.currentShowUnitPrice = false; // 初始状态为false
  }

  // 保持当前的显示状态，不重置

  // 更新浮动按钮显示
  updateFloatingButtons();
}

// 显示/隐藏外币设置框
function toggleCurrencySettings() {
  const settingsBox = document.getElementById("currencySettingsBox");
  if (
    settingsBox.style.display === "block" ||
    settingsBox.style.display === ""
  ) {
    settingsBox.style.display = "none";
  } else {
    settingsBox.style.display = "block";
  }
}

// 切换语言显示 - 只切换中英显示，不涉及汇率计算
function toggleLanguageDisplay() {
  // 切换语言显示状态
  window.isEnglishDisplay = !window.isEnglishDisplay;

  // 重新生成报价单以反映更改
  generateQuote();
}

// 选择内置货币
function selectCurrency(code, rate) {
  // 填充币种代码和汇率输入框
  document.getElementById("currencyCodeInput").value = code;
  document.getElementById("exchangeRateInput").value = rate;

  // 应用汇率计算
  applyCurrencyRate(code, rate);
}

// 应用汇率计算
function applyCurrencyRate(currencyCode, exchangeRate) {
  // 记录切换前的币种和汇率状态
  const previousCurrencyCode = window.currentCurrencyCode || "CNY";
  const previousExchangeRate = window.currentExchangeRate || 1.0;

  // 保存设置到全局变量
  window.currencyCode = currencyCode;
  window.exchangeRate = exchangeRate;
  window.showForeignCurrency = true; // 启用外币显示

  // 在更新当前汇率前，先对购物车中的项目进行汇率转换
  // 使用两步计算法：当前数值/当前汇率*新汇率
  // 实际上是：(当前数值/当前汇率)*新汇率
  cartItems.forEach((item) => {
    // 第一步：当前数值 / 当前汇率 = 基准数值
    const baseValue = item.actualPrice / previousExchangeRate;

    // 第二步：基准数值 * 新汇率 = 新数值
    item.actualPrice = baseValue * exchangeRate;

    // 保存基准价格（如果尚未保存）
    if (item.basePrice === undefined) {
      item.basePrice = item.actualPrice / exchangeRate; // 反算基准价格
    }
  });

  // 对临时费用项目也进行同样的转换
  tempItems.forEach((item) => {
    if (item.displayType === "费用") {
      // 第一步：当前数值 / 当前汇率 = 基准数值
      const baseValue = item.actualAmount / previousExchangeRate;

      // 第二步：基准数值 * 新汇率 = 新数值
      item.actualAmount = baseValue * exchangeRate;

      // 保存基准金额（如果尚未保存）
      if (item.baseAmount === undefined) {
        item.baseAmount = item.actualAmount / exchangeRate; // 反算基准金额
      }
    }
  });

  // 保存当前币种状态（已经更新了项目价格）
  window.currentCurrencyCode = currencyCode;
  window.currentExchangeRate = exchangeRate;

  // 保存切换前的币种和汇率，用于计算
  window.previousCurrencyCode = previousCurrencyCode;
  window.previousExchangeRate = previousExchangeRate;

  // 更新外币设置框标题
  updateCurrencySettingsTitle(currencyCode);

  // 重新生成报价单以反映更改
  generateQuote();
}

// 更新外币设置框标题
function updateCurrencySettingsTitle(currencyCode) {
  const titleElement = document.getElementById("currencySettingsTitle");
  if (titleElement) {
    titleElement.textContent = `当前币种：${currencyCode}`;
  }
}

// 处理币种输入框回车事件
function handleCurrencyInputKeyPress(event) {
  if (event.key === "Enter") {
    event.preventDefault(); // 阻止表单提交

    const currencyCode =
      document.getElementById("currencyCodeInput").value;
    const exchangeRate = parseFloat(
      document.getElementById("exchangeRateInput").value
    );

    if (currencyCode && exchangeRate) {
      applyCurrencyRate(currencyCode, exchangeRate);
    }
  }
}

// 处理币种输入框失焦事件
function handleCurrencyInputBlur() {
  const currencyCode = document.getElementById("currencyCodeInput").value;
  const exchangeRate = parseFloat(
    document.getElementById("exchangeRateInput").value
  );

  if (currencyCode && exchangeRate) {
    applyCurrencyRate(currencyCode, exchangeRate);
  }
}

// 返回主页
function backToMain() {
  document.querySelector(".container").style.display = "block";
  document.getElementById("quotePage").style.display = "none";
  currentView = "main";

  // 更新浮动按钮显示
  updateFloatingButtons();
}

// 切换单价显示
function toggleShowUnitPrice() {
  window.currentShowUnitPrice = !window.currentShowUnitPrice;
  generateQuote(); // 重新生成报价单
}

// 返回购物车
function backToCart() {
  document.querySelector(".container").style.display = "block";
  document.getElementById("quotePage").style.display = "none";
  showCart(); // 显示购物车模态框
  currentView = "cart";

  // 确保浮动按钮显示正确
  updateFloatingButtons();
}