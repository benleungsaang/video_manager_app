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

    // 初始化备注，从localStorage加载之前保存的备注（如果存在）
    const savedRemark = loadRemarkFromLocalStorage(item.id, 'cart');
    if (item.remark === undefined) {
      itemCopy.remark = savedRemark;
    } else {
      itemCopy.remark = item.remark;
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

    // 初始化备注，从localStorage加载之前保存的备注（如果存在）
    const savedRemark = loadRemarkFromLocalStorage(item.id, 'temp');
    if (item.remark === undefined) {
      itemCopy.remark = savedRemark;
    } else {
      itemCopy.remark = item.remark;
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
        remark: "Remark",
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
        remark: "备注",
      };

  // 确定标题：如果用户已经修改过标题，则使用修改后的标题，否则使用语言相关的默认标题
  const displayTitle = window.currentQuoteTitle ? window.currentQuoteTitle : labels.quotation;

  let html = `
      <div class="section">
          <h2 id="quoteTitle" style="text-align: center; color: #333; cursor: pointer;" onclick="editQuoteTitle(this)">${displayTitle}</h2>
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
                    <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">${labels.remark}</th>
                </tr>
            </thead>
            <tbody>
        `;
    // 添加购物车项目（使用报价单副本的显示价格）
    quoteCartItems.forEach((item, index) => {
      const itemIndex = index + 1; // 序号从1开始

      const subtotal = item.displayPrice * item.quantity;

      // 初始化备注值，如果不存在则为空字符串
      const remark = item.remark || "";

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
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; cursor: pointer;" data-index="${index}" data-type="cart" data-item-id="${item.id}">${remark}</td>
          </tr>
      `;
    });

    // 添加商品小计行
    if (quoteCartItems.length > 0) {
      // 从localStorage获取商品小计的备注
      const subtotalRemark = loadRemarkFromLocalStorage('subtotal', 'summary');
      html += `
          <tr style="background-color: #f0f8ff; font-weight: bold;">
              <td colspan="4" style="border: 1px solid #ddd; padding: 10px; text-align: right;">${
      labels.subtotalExcludingFees
    }</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      baseTotal
    )}</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; cursor: pointer;" data-index="0" data-type="summary" data-item-id="subtotal">${subtotalRemark}</td>
          </tr>
          `;
    }

    // 添加其它费用（使用报价单副本的显示金额）
    quoteTempItems
      .filter((item) => item.displayType === "费用")
      .forEach((item) => {
        const remark = item.remark || "";
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
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; cursor: pointer;" data-index="${quoteCartItems.length + quoteTempItems.findIndex(i => i.id === item.id)}" data-type="fee" data-item-id="${item.id}">${remark}</td>
          </tr>
      `;
      });

    // 添加系数（使用原始值，因为系数不涉及汇率转换）
    quoteTempItems
      .filter((item) => item.displayType === "系数")
      .forEach((item) => {
        const remark = item.remark || "";
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
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; cursor: pointer;" data-index="${quoteCartItems.length + quoteTempItems.findIndex(i => i.id === item.id)}" data-type="factor" data-item-id="${item.id}">${remark}</td>
          </tr>
      `;
      });

    // 显示总计，确保币种代码正确显示
    // 从localStorage获取总计的备注
    const totalRemark = loadRemarkFromLocalStorage('total', 'summary');
    html += `
          <tr style="background-color: #e8f5e9; font-weight: bold;">
              <td colspan="4" style="border: 1px solid #ddd; padding: 10px; text-align: right;">${
      labels.total
    }</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      total
    )}</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; cursor: pointer;" data-index="0" data-type="summary" data-item-id="total">${totalRemark}</td>
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
                  <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">${labels.remark}</th>
              </tr>
          </thead>
          <tbody>
    `;

    // 添加购物车项目（使用报价单副本）
    quoteCartItems.forEach((item, index) => {
      const itemIndex = index + 1; // 序号从1开始

      // 初始化备注值，如果不存在则为空字符串
      const remark = item.remark || "";

      html += `
          <tr>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; white-space: nowrap;">${itemIndex}</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">
                  <strong>${item.model}</strong>
              </td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">${item.quantity}</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; cursor: pointer;" data-index="${index}" data-type="cart" data-item-id="${item.id}">${remark}</td>
          </tr>
      `;
    });

    // 添加商品小计行
    if (quoteCartItems.length > 0) {
      // 从localStorage获取商品小计的备注
      const subtotalRemark = loadRemarkFromLocalStorage('subtotal', 'summary');
      html += `
          <tr style="background-color: #f0f8ff; font-weight: bold;">
              <td colspan="2" style="border: 1px solid #ddd; padding: 10px; text-align: right;">${
      labels.subtotalExcludingFees
    }</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      baseTotal
    )}</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; cursor: pointer;" data-index="0" data-type="summary" data-item-id="subtotal">${subtotalRemark}</td>
          </tr>
      `;
    }

    // 添加其它费用（使用报价单副本的显示金额）
    quoteTempItems
      .filter((item) => item.displayType === "费用")
      .forEach((item) => {
        const remark = item.remark || "";
        html += `
              <tr style="background-color: #f9f9f9;">
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: center; white-space: nowrap;"><strong>${
      labels.add
    }</strong></td>
                  <td colspan="1" style="border: 1px solid #ddd; padding: 10px; text-align: center;"><strong>${
      item.name
    }</strong></td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      item.displayAmount
    )}</td>
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: center; cursor: pointer;" data-index="${quoteCartItems.length + quoteTempItems.findIndex(i => i.id === item.id)}" data-type="fee" data-item-id="${item.id}">${remark}</td>
              </tr>
          `;
      });

    // 添加系数（使用原始值）
    quoteTempItems
      .filter((item) => item.displayType === "系数")
      .forEach((item) => {
        const remark = item.remark || "";
        html += `
          <tr style="background-color: #f9f9f9;">
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; white-space: nowrap;"><strong>${
      isEnglish
        ? "Factor"
        : "系数"
    }</strong></td>
              <td colspan="1" style="border: 1px solid #ddd; padding: 10px; text-align: center;"><strong>${
      item.name
    }</strong></td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">x ${
      item.value
    }</td>
              <td style="border: 1px solid #ddd; padding: 10px; text-align: center; cursor: pointer;" data-index="${quoteCartItems.length + quoteTempItems.findIndex(i => i.id === item.id)}" data-type="factor" data-item-id="${item.id}">${remark}</td>
          </tr>
      `;
      });

    // 显示总计，确保币种代码正确显示
    // 从localStorage获取总计的备注
    const totalRemark = loadRemarkFromLocalStorage('total', 'summary');
    html += `
      <tr style="background-color: #e8f5e9; font-weight: bold;">
          <td colspan="2" style="border: 1px solid #ddd; padding: 10px; text-align: right;">${
      labels.total
    }</td>
          <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      total
    )}</td>
          <td style="border: 1px solid #ddd; padding: 10px; text-align: center; cursor: pointer;" data-index="0" data-type="summary" data-item-id="total">${totalRemark}</td>
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

  // 为备注单元格添加点击事件监听器
  const remarkCells = document.querySelectorAll('td[data-item-id]');
  remarkCells.forEach(cell => {
    cell.addEventListener('click', function() {
      const index = parseInt(this.getAttribute('data-index'));
      const type = this.getAttribute('data-type');
      const itemId = this.getAttribute('data-item-id');
      editRemark(this, index, type, itemId);
    });
  });

  // 保存当前的显示状态
  if (window.currentShowUnitPrice === undefined) {
    window.currentShowUnitPrice = false; // 初始状态为false
  }

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

// 编辑备注功能
function editRemark(cell, index, type, itemId) {
  // 如果当前单元格已经是编辑状态（包含textarea），则不重复创建
  if (cell.querySelector('textarea')) {
    const textarea = cell.querySelector('textarea');
    textarea.focus();
    return;
  }

  // 核心：从单元格innerHTML中还原纯文本（<br>替换为\n，保留换行）
  const cellHtml = cell.innerHTML || '';
  const currentRemark = cellHtml.replace(/<br>/g, '\n');

  // 创建多行文本框
  const textarea = document.createElement('textarea');
  textarea.value = currentRemark;
  textarea.style.width = '100%';
  textarea.style.height = 'auto';
  textarea.style.minHeight = '40px';
  textarea.style.padding = '5px';
  textarea.style.border = '1px solid #ccc';
  textarea.style.borderRadius = '3px';
  textarea.style.resize = 'vertical';
  textarea.style.fontFamily = 'inherit';
  textarea.style.fontSize = 'inherit';

  // 替换单元格内容为文本框
  cell.innerHTML = '';
  cell.appendChild(textarea);
  textarea.focus();

  // 自动调整高度
  textarea.addEventListener('input', function() {
    this.style.height = 'auto';
    this.style.height = (this.scrollHeight) + 'px';
  });

  // 保存备注到本地存储的函数
  const saveRemark = (remarkValue) => {
    // 根据类型和ID更新相应的数据
    if (type === 'cart') {
      // 在购物车中找到对应的项目
      const cartItem = cartItems.find(item => item.id == itemId);
      if (cartItem) {
        cartItem.remark = remarkValue;
      }

      // 在报价单副本中也更新（如果报价单正在显示）
      if (window.currentQuoteCartItems) {
        const quoteItem = window.currentQuoteCartItems.find(item => item.id == itemId);
        if (quoteItem) {
          quoteItem.remark = remarkValue;
        }
      }
    } else if (type === 'fee') {
      // 处理费用项目
      const tempItem = tempItems.find(item => item.id == itemId);
      if (tempItem) {
        tempItem.remark = remarkValue;
      }
    } else if (type === 'factor') {
      // 处理系数项目
      const tempItem = tempItems.find(item => item.id == itemId);
      if (tempItem) {
        tempItem.remark = remarkValue;
      }
    } else if (type === 'summary') {
      // 处理小计和总计的备注（这些是特殊类型）
      // 这里不需要特殊处理，因为它们已经在localStorage中保存
    }

    // 将备注保存到localStorage
    saveRemarkToLocalStorage(itemId, remarkValue, type);

    // ② 更新单元格innerHTML（直接展示换行）
    cell.innerHTML = remarkValue.replace(/\n/g, '<br>');
    // 重新设置data属性以确保事件监听器能正常工作
    cell.setAttribute('data-index', index);
    cell.setAttribute('data-type', type);
    cell.setAttribute('data-item-id', itemId);
    cell.style.cursor = 'pointer';
  };

  // 处理文本框失焦事件
  textarea.addEventListener('blur', function() {
    saveRemark(textarea.value);
  });

  // 处理回车键 - 用于换行而不是保存
  textarea.addEventListener('keydown', function(e) {
    // 如果按住Shift+Enter，则正常换行
    // 如果只按Enter，则不保存，允许换行
    if (e.key === 'Enter' && !e.shiftKey) {
      // 允许正常换行，不阻止默认行为
      // 但不保存内容
      e.stopPropagation(); // 防止冒泡触发其他事件
    }
    // 如果按Ctrl+Enter或Cmd+Enter，则保存内容
    else if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
      e.preventDefault(); // 防止添加新行
      saveRemark(textarea.value);
    }
  });
}

// 保存备注到本地存储
function saveRemarkToLocalStorage(itemId, remark, type) {
  // 从localStorage获取tempData
  let tempData = JSON.parse(localStorage.getItem('tempData') || '{}');

  // 如果tempData不存在或格式不正确，创建一个默认结构
  if (!tempData.id || !tempData.items) {
    tempData = {
      "id": "temp",
      "title": "临时报价单",
      "items": [],
      "subtotal": 0,
      "subtotal_remark": "",
      "total": 0,
      "total_remark": "",
      "currency": "CNY",
      "createdBy": localStorage.getItem('username') || 'user'
    };
  }

  // 根据类型处理备注存储
  if (type === 'cart' || type === 'fee' || type === 'factor') {
    // 对于项目备注，更新items数组中对应项目的remark字段
    tempData.items = tempData.items.map(item => {
      if (item.id == itemId) {
        // 创建项目副本并更新备注
        return { ...item, remark: remark };
      }
      return item;
    });
  } else if (type === 'summary') {
    // 对于小计和总计备注
    if (itemId === 'subtotal') {
      tempData.subtotal_remark = remark;
    } else if (itemId === 'total') {
      tempData.total_remark = remark;
    }
  }

  // 保存tempData到localStorage
  localStorage.setItem('tempData', JSON.stringify(tempData));
}

// 从本地存储加载备注
function loadRemarkFromLocalStorage(itemId, type) {
  // 从localStorage获取tempData
  const tempData = JSON.parse(localStorage.getItem('tempData') || '{}');

  // 根据类型处理备注加载
  if (type === 'cart' || type === 'fee' || type === 'factor') {
    // 对于项目备注，查找items数组中对应项目的remark字段
    if (tempData && tempData.items) {
      const item = tempData.items.find(item => item.id == itemId);
      if (item && item.remark !== undefined) {
        return item.remark || '';
      }
    }
    // 为了向后兼容，如果在新位置找不到备注，尝试从旧位置加载
    if (tempData && tempData.remarks) {
      const remarkKey = `${type}_${itemId}`;
      return tempData.remarks[remarkKey] || '';
    }
  } else if (type === 'summary') {
    // 对于小计和总计备注
    if (itemId === 'subtotal') {
      return tempData.subtotal_remark || '';
    } else if (itemId === 'total') {
      return tempData.total_remark || '';
    }
  }

  // 如果tempData不存在或没有找到备注，返回空字符串
  return '';
}

// 初始化tempData，如果不存在的话
function initializeTempData() {
  const tempDataStr = localStorage.getItem('tempData');
  if (!tempDataStr) {
    // 创建默认的tempData结构
    const defaultTempData = {
      "id": "temp",
      "title": "临时报价单",
      "items": [],
      "subtotal": 0,
      "subtotal_remark": "",
      "total": 0,
      "total_remark": "",
      "currency": "CNY",
      "createdBy": localStorage.getItem('username') || 'user',
      "createdAt": new Date().toISOString()
    };
    localStorage.setItem('tempData', JSON.stringify(defaultTempData));
  }
}

// 从tempData加载数据到购物车和报价单
function loadTempDataToCart() {
  const tempDataStr = localStorage.getItem('tempData');
  if (!tempDataStr) {
    return; // 如果没有tempData，则返回
  }

  const tempData = JSON.parse(tempDataStr);
  if (!tempData || !tempData.items) {
    return; // 如果tempData格式不正确，则返回
  }

  // 清空当前购物车
  cartItems = [];
  tempItems = [];

  // 遍历tempData.items并根据类型加载到相应数组
  tempData.items.forEach(item => {
    let displayType = "部件";
    if (item.type === "fees" || item.type === "费用") {
      displayType = "费用";
    } else if (item.type === "factors" || item.type === "系数") {
      displayType = "系数";
    }

    if (displayType === "费用") {
      // 添加到临时项目中作为费用
      const tempItem = {
        id: item.id || Date.now() + Math.random(),
        displayType: "费用",
        name: item.name || "",
        baseAmount: item.price || item.amount || 0,
        actualAmount: item.price || item.amount || 0,
        remark: item.remark || "",
        type: "fees"
      };
      tempItems.push(tempItem);
    } else if (displayType === "系数") {
      // 添加到临时项目中作为系数
      const tempItem = {
        id: item.id || Date.now() + Math.random(),
        displayType: "系数",
        name: item.name || "",
        value: item.price || item.value || 1,
        remark: item.remark || "",
        type: "factors"
      };
      tempItems.push(tempItem);
    } else {
      // 添加到购物车项目
      const cartItem = {
        id: item.id || Date.now() + Math.random(),
        type: item.type || "部件",
        model: item.name || item.model || "",
        name: item.name || item.model || "",
        basePrice: item.price || 0,
        actualPrice: item.price || 0,
        quantity: item.quantity || 1,
        remark: item.remark || "",
        image: item.image || "./sample.jpg"
      };
      cartItems.push(cartItem);
    }
  });

  // 更新购物车计数
  updateCartCount();

  // 重新生成报价单以显示备注
  if (currentView === 'quote') {
    generateQuote();
  }
}

// 保存当前报价单到服务器和localStorage
async function saveCurrentQuoteToStorage() {
  // 获取当前显示的标题，如果没有编辑过则使用默认标题
  const titleElement = document.getElementById('quoteTitle');
  const title = titleElement ? titleElement.textContent : '报价单';

  // 从localStorage获取tempData，并直接使用其中的数据
  let tempData = JSON.parse(localStorage.getItem('tempData') || '{}');

  // 如果tempData不存在或格式不正确，创建一个包含当前购物车数据的tempData
  if (!tempData.id) {
    // 计算总计
    const baseTotal = cartItems.reduce((sum, item) => sum + (item.actualPrice || 0) * (item.quantity || 0), 0);
    const tempFees = tempItems
      .filter(item => item.displayType === '费用')
      .reduce((sum, item) => sum + (item.actualAmount || 0), 0);
    const factor = tempItems
      .filter(item => item.displayType === '系数')
      .reduce((prod, item) => prod * (item.value || 1), 1);
    const total = (baseTotal + tempFees) * factor;

    // 创建临时的tempData结构，包含当前购物车数据
    tempData = {
      "id": "temp",
      "title": title,
      "items": [],
      "subtotal": baseTotal,
      "subtotal_remark": "",
      "total": total,
      "total_remark": "",
      "currency": window.currentCurrencyCode || 'CNY',
      "createdBy": localStorage.getItem('username') || 'user'
    };

    // 添加购物车项目
    cartItems.forEach(item => {
      tempData.items.push({
        id: item.id,
        type: item.type || "parts",
        name: item.model,
        model: item.model,
        price: item.actualPrice,
        quantity: item.quantity,
        remark: item.remark || ""
      });
    });

    // 添加费用项目
    tempItems
      .filter(item => item.displayType === '费用')
      .forEach(item => {
        tempData.items.push({
          id: item.id,
          type: "fees",
          name: item.name,
          price: item.actualAmount,
          quantity: 1,
          remark: item.remark || ""
        });
      });

    // 添加系数项目
    tempItems
      .filter(item => item.displayType === '系数')
      .forEach(item => {
        tempData.items.push({
          id: item.id,
          type: "factors",
          name: item.name,
          price: item.value,
          quantity: 1,
          remark: item.remark || ""
        });
      });
  }

  // 检查tempData的id是否为temp
  if (tempData.id === "temp") {
    // tempData的id是temp，直接执行原来的保存流程
    // 准备报价单数据（不需要提供ID，服务器将自动生成UUID）
    const quotationData = {
      ...tempData,  // 使用tempData中的所有数据
      title: title,  // 更新标题
      items: tempData.items || [],  // 确保items字段存在
      createdAt: new Date().toISOString()  // 设置创建时间为当前时间
    };

    try {
      // 首先尝试将报价单保存到服务器
      const response = await fetch('/api/quotations', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(quotationData)
      });

      let finalId = null; // 服务器生成的UUID

      if (response.ok) {
        // 从服务器响应中获取新的UUID
        const responseData = await response.json();
        finalId = responseData.id;
        showMessage('报价单已保存到服务器', 'success');
      } else {
        console.error('保存到服务器失败:', response.status, response.statusText);
        // 如果服务器保存失败，至少保留本地保存
        showMessage('服务器保存失败，已保存到本地', 'warning');
      }

      // 如果服务器保存成功，使用服务器返回的ID
      if (finalId) {
        // 更新报价单数据，加入服务器返回的ID
        quotationData.id = finalId;
      } else {
        // 如果服务器保存失败，使用本地生成的ID
        finalId = 'local_' + Date.now();
        quotationData.id = finalId;
      }

      // 从localStorage获取现有报价单列表
      const existingQuotations = JSON.parse(localStorage.getItem('savedQuotations') || '[]');

      // 检查是否已有相同ID的报价单，如果有则更新，否则添加新的
      const existingIndex = existingQuotations.findIndex(q => q.id === finalId);
      if (existingIndex !== -1) {
        existingQuotations[existingIndex] = quotationData;
      } else {
        existingQuotations.push(quotationData);
      }

      // 保存到localStorage（限制保存最近的50个报价单）
      const limitedQuotations = existingQuotations.slice(-50);
      localStorage.setItem('savedQuotations', JSON.stringify(limitedQuotations));

      // 更新tempData，将ID从temp改为新ID
      const updatedTempData = {
        ...tempData,
        id: finalId,
        title: title,
      };
      localStorage.setItem('tempData', JSON.stringify(updatedTempData));

      return finalId;
    } catch (error) {
      console.error('保存报价单时发生错误:', error);

      // 发生网络错误时，至少将报价单保存到本地
      const finalId = 'local_' + Date.now();
      const quotationData = {
        ...tempData,  // 使用tempData中的所有数据
        id: finalId,
        title: title,
        items: tempData.items || []  // 确保items字段存在
      };

      const existingQuotations = JSON.parse(localStorage.getItem('savedQuotations') || '[]');
      existingQuotations.push(quotationData);

      // 保存到localStorage（限制保存最近的50个报价单）
      const limitedQuotations = existingQuotations.slice(-50);
      localStorage.setItem('savedQuotations', JSON.stringify(limitedQuotations));

      // 更新tempData，将ID从temp改为新ID
      const updatedTempData = {
        ...tempData,
        id: finalId,
        title: title
      };
      localStorage.setItem('tempData', JSON.stringify(updatedTempData));

      showMessage('报价单已保存到本地（服务器连接失败）', 'warning');
      return finalId;
    }
  } else {
    // tempData的id不是temp，询问用户是覆盖、新建还是取消
    const shouldOverride = confirm(`当前报价单为: ${tempData.title} 金额为：${formatCurrency(tempData.total)}\n\n选择操作：\n"确定" - 覆盖原报价单\n"取消" - 其他选项`);

    if (shouldOverride) {
      // 用户选择覆盖原报价单
      const quotationData = {
        ...tempData,  // 使用tempData中的所有数据
        title: title,  // 更新标题
        id: tempData.id, // 使用现有ID
        items: tempData.items || []  // 确保items字段存在
      };

      try {
        // 尝试更新服务器上的报价单
        const response = await fetch(`/api/quotations/${tempData.id}`, {
          method: 'PUT', // 使用PUT方法更新
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(quotationData)
        });

        if (response.ok) {
          showMessage('报价单已更新到服务器', 'success');
        } else {
          console.error('更新服务器报价单失败:', response.status, response.statusText);
          showMessage('更新服务器报价单失败，但已保存到本地', 'warning');
        }

        // 从localStorage获取现有报价单列表并更新
        const existingQuotations = JSON.parse(localStorage.getItem('savedQuotations') || '[]');
        const existingIndex = existingQuotations.findIndex(q => q.id === tempData.id);
        if (existingIndex !== -1) {
          existingQuotations[existingIndex] = quotationData;
        } else {
          existingQuotations.push(quotationData);
        }

        // 保存到localStorage
        localStorage.setItem('savedQuotations', JSON.stringify(existingQuotations));

        // 更新tempData
        const updatedTempData = {
          ...tempData,
          title: title
        };
        localStorage.setItem('tempData', JSON.stringify(updatedTempData));

        return tempData.id;
      } catch (error) {
        console.error('更新报价单时发生错误:', error);
        showMessage('更新报价单时发生错误', 'error');
        return tempData.id;
      }
    } else {
      // 用户选择不是覆盖，询问是否新建
      const shouldCreateNew = confirm('是否新建报价单？\n"确定" - 新建报价单\n"取消" - 取消操作');

      if (!shouldCreateNew) {
        // 用户选择取消操作
        showMessage('保存操作已取消', 'info');
        return tempData.id;
      }
      // 用户选择新建报价单，继续执行新建逻辑
      const quotationData = {
        ...tempData,  // 使用tempData中的所有数据
        title: title,  // 更新标题
        items: tempData.items || []  // 确保items字段存在
      };

      try {
        // 首先尝试将报价单保存到服务器
        const response = await fetch('/api/quotations', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(quotationData)
        });

        let finalId = null; // 服务器生成的UUID

        if (response.ok) {
          // 从服务器响应中获取新的UUID
          const responseData = await response.json();
          finalId = responseData.id;
          showMessage('新报价单已保存到服务器', 'success');
        } else {
          console.error('保存到服务器失败:', response.status, response.statusText);
          // 如果服务器保存失败，至少保留本地保存
          showMessage('服务器保存失败，已保存到本地', 'warning');
        }

        // 如果服务器保存成功，使用服务器返回的ID
        if (finalId) {
          // 更新报价单数据，加入服务器返回的ID
          quotationData.id = finalId;
        } else {
          // 如果服务器保存失败，使用本地生成的ID
          finalId = 'local_' + Date.now();
          quotationData.id = finalId;
        }

        // 从localStorage获取现有报价单列表
        const existingQuotations = JSON.parse(localStorage.getItem('savedQuotations') || '[]');

        // 检查是否已有相同ID的报价单，如果有则更新，否则添加新的
        const existingIndex = existingQuotations.findIndex(q => q.id === finalId);
        if (existingIndex !== -1) {
          existingQuotations[existingIndex] = quotationData;
        } else {
          existingQuotations.push(quotationData);
        }

        // 保存到localStorage（限制保存最近的50个报价单）
        const limitedQuotations = existingQuotations.slice(-50);
        localStorage.setItem('savedQuotations', JSON.stringify(limitedQuotations));

        // 创建新的tempData，ID为新生成的ID
        const newTempData = {
          ...tempData,
          id: finalId,
          title: title
        };
        localStorage.setItem('tempData', JSON.stringify(newTempData));

        return finalId;
      } catch (error) {
        console.error('保存新报价单时发生错误:', error);

        // 发生网络错误时，至少将报价单保存到本地
        const finalId = 'local_' + Date.now();
        quotationData.id = finalId;

        const existingQuotations = JSON.parse(localStorage.getItem('savedQuotations') || '[]');
        existingQuotations.push(quotationData);

        // 保存到localStorage（限制保存最近的50个报价单）
        const limitedQuotations = existingQuotations.slice(-50);
        localStorage.setItem('savedQuotations', JSON.stringify(limitedQuotations));

        // 创建新的tempData，ID为新生成的ID
        const newTempData = {
          ...tempData,
          id: finalId,
          title: title
        };
        localStorage.setItem('tempData', JSON.stringify(newTempData));

        showMessage('新报价单已保存到本地（服务器连接失败）', 'warning');
        return finalId;
      }
    }
  }
}


// 编辑报价单标题
function editQuoteTitle(element) {
  // 检查是否已经在编辑状态，如果是，则直接返回，避免重复创建输入框
  if (element.querySelector('input')) {
    const input = element.querySelector('input');
    input.focus();
    input.select();
    return;
  }

  // 获取当前标题内容（保留已修改的标题）
  const currentTitle = element.textContent;

  // 创建输入框
  const input = document.createElement('input');
  input.type = 'text';
  input.value = currentTitle;
  input.style.width = '100%';
  input.style.padding = '5px';
  input.style.border = '1px solid #ccc';
  input.style.borderRadius = '3px';
  input.style.textAlign = 'center';
  input.style.fontSize = '1.5em';
  input.style.fontWeight = 'bold';
  input.style.color = '#333';

  // 替换标题元素内容为输入框
  element.innerHTML = '';
  element.appendChild(input);
  input.focus();
  input.select(); // 选中所有文本以便编辑

  // 保存标题的函数
  const saveTitle = (titleValue) => {
    // 更新标题显示内容
    element.innerHTML = titleValue;
    element.setAttribute('onclick', 'editQuoteTitle(this)');
    element.style.cursor = 'pointer';

    // 保存到全局变量以便在保存报价单时使用
    window.currentQuoteTitle = titleValue;
  };

  // 处理输入框失焦事件
  input.addEventListener('blur', function() {
    saveTitle(input.value);
  });

  // 处理回车键
  input.addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
      saveTitle(input.value);
    }
  });
}

// 报价单搜索结果简明信息（作者、金额、时间）
function getQuoteSummaryHTML(quote, source) {
  return `
    <div style="font-size: 0.8em; color: #666;">
      作者: ${quote.createdBy} |
      金额：${formatCurrency(quote.total)} |
      更新时间：${new Date(quote.updatedAt).toLocaleString()} | ${source}
    </div>
  `;
}

// 本地搜索报价单
function searchQuotesLocal(query) {
  const searchResultsDiv = document.getElementById('quoteSearchResults');
  if (!query) {
    searchResultsDiv.style.display = 'none';
    return;
  }

  // 从localStorage获取所有报价单
  const allQuotations = JSON.parse(localStorage.getItem('savedQuotations') || '[]');

  // 过滤匹配的报价单
  const filteredQuotations = allQuotations.filter(quote =>
    quote.title.toLowerCase().includes(query.toLowerCase())
  );

  // 显示本地搜索结果
  displaySearchResults(filteredQuotations, 'local');

  // 显示提示信息
  const resultCount = filteredQuotations.length;
  let resultHTML = '';
  if (resultCount > 0) {
    resultHTML += `<div style="font-weight: bold; margin-bottom: 5px;">本地搜索结果 (${resultCount}):
                    <div style="font-style: italic;color: darkgray;display: inline-block;font-size: smaller;font-weight: 400;">当前展示为本地数据，回车确认搜索服务器数据</div>
    </div>`;


    filteredQuotations.forEach(quote => {
      resultHTML += `
        <div class="quote-result-item" style="padding: 5px; border-bottom: 1px solid #eee; cursor: pointer; display: flex; justify-content: space-between; align-items: center;"
             onclick="showQuotationDetail('${quote.id}', false)">
          <div style="flex: 1;">
            <div style="font-weight: bold;">标题：${quote.title}</div>
            ${getQuoteSummaryHTML(quote, '本地数据')}
          </div>
          <button class="secondary" onclick="loadQuotationToCartFromId('${quote.id}', false); event.stopPropagation();" style="background-color: #4caf50; color: white; margin-left: 10px; flex-shrink: 0;">
            🛒 加载到购物车
          </button>
        </div>
      `;
    });
  } else {
    resultHTML += `<div style="padding: 5px; color: #666;">未找到匹配的本地报价单</div>`;
  }

  // 添加提示信息，告诉用户可以按回车搜索服务器
  // resultHTML += `<div style="padding: 10px; font-style: italic; color: #888; border-top: 1px dashed #ccc;">当前展示为本地数据，回车确认搜索服务器数据</div>`;

  searchResultsDiv.innerHTML = resultHTML;
  searchResultsDiv.style.display = 'block';
}

// 处理报价单搜索输入框的键盘事件
function handleQuoteSearchKeyDown(event) {
  if (event.key === 'Enter') {
    event.preventDefault(); // 阻止表单提交或其他默认行为
    const searchInput = document.getElementById('quoteSearchInput');
    const query = searchInput.value.trim();

    if (query) {
      // 执行服务器搜索
      searchQuotesServer(query);
    }
  }
}

// 搜索服务器报价单
async function searchQuotesServer(query) {
  const searchResultsDiv = document.getElementById('quoteSearchResults');

  try {
    // 向服务器发起搜索请求
    const response = await fetch(`/api/search-quotations?q=${encodeURIComponent(query)}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      }
    });

    let serverResults = [];
    if (response.ok) {
      const result = await response.json();
      // 确保从响应中正确提取数据数组
      serverResults = Array.isArray(result.data) ? result.data : [];
    } else {
      console.error('服务器搜索失败:', response.status, response.statusText);
      showMessage('服务器搜索失败', 'error');
    }

    // 同时获取本地搜索结果以进行对比展示
    const allQuotations = JSON.parse(localStorage.getItem('savedQuotations') || '[]');
    const localResults = allQuotations.filter(quote =>
      quote.title.toLowerCase().includes(query.toLowerCase())
    );

    // 显示合并的搜索结果
    displaySearchResults(localResults, serverResults, query);
  } catch (error) {
    console.error('搜索报价单时发生错误:', error);
    showMessage('搜索报价单时发生错误', 'error');

    // 显示本地结果作为备选
    const allQuotations = JSON.parse(localStorage.getItem('savedQuotations') || '[]');
    const localResults = allQuotations.filter(quote =>
      quote.title.toLowerCase().includes(query.toLowerCase())
    );

    displaySearchResults(localResults, [], query);
  }
}

// 显示搜索结果（本地和服务器）
function displaySearchResults(localResults, serverResults, query) {
  const searchResultsDiv = document.getElementById('quoteSearchResults');

  let resultHTML = '';

  // 确保serverResults是数组
  if (!Array.isArray(serverResults)) {
    serverResults = [];
  }

  // 显示服务器搜索结果
  if (serverResults && serverResults.length > 0) {
    // 如果本地和服务器结果都存在，添加分隔线
    // if (localResults && localResults.length > 0) {
    //   resultHTML += `<div style="height: 1px; background-color: #ccc; margin: 10px 0;"></div>`;
    // }
    resultHTML += `<div style="font-weight: bold; margin: 10px 0 5px 0;">服务器搜索结果 (${serverResults.length}):</div>`;
    serverResults.forEach(quote => {
      resultHTML += `
        <div class="quote-result-item" style="padding: 5px; border-bottom: 1px solid #eee; cursor: pointer; display: flex; justify-content: space-between; align-items: center;"
             onclick="showQuotationDetail('${quote.id}', true)">
          <div style="flex: 1;">
            <div style="font-weight: bold;">标题：${quote.title}</div>
              <div style="font-size: 0.8em; color: #666;">
              ${getQuoteSummaryHTML(quote, '服务器数据')}
              </div>
            </div>
          <button class="secondary" onclick="loadQuotationToCartFromId('${quote.id}', true); event.stopPropagation();" style="background-color: #4caf50; color: white; margin-left: 10px; flex-shrink: 0;">
            🛒 加载到购物车
          </button>
        </div>
      `;
    });
  } else if (query) {
    resultHTML += `<div style="padding: 5px; color: #666;">服务器未找到匹配的报价单，以下为本地数据</div>`;
    // 显示本地搜索结果
    if (localResults && localResults.length > 0) {
      resultHTML += `<div style="background-color: darkgray;color: white;padding-left: 10px;border-radius: 5px;font-weight: bold; margin: 10px 0 5px 0;">本地搜索结果 (${localResults.length}):</div>`;
      localResults.forEach(quote => {
        resultHTML += `
          <div class="quote-result-item" style="background-color: whitesmoke; padding: 5px; border-bottom: 1px solid #eee; cursor: pointer; display: flex; justify-content: space-between; align-items: center;"
              onclick="showQuotationDetail('${quote.id}', false)">
            <div style="flex: 1;">
              <div style="font-weight: bold;">标题：${quote.title}</div>
              <div style="font-size: 0.8em; color: #666;">
              ${getQuoteSummaryHTML(quote, '本地数据')}
              </div>
              </div>
            <button class="secondary" onclick="loadQuotationToCartFromId('${quote.id}', false); event.stopPropagation();" style="background-color: #4caf50; color: white; margin-left: 10px; flex-shrink: 0;">
              🛒 加载到购物车
            </button>
          </div>
        `;
      });
    }
  }

  searchResultsDiv.innerHTML = resultHTML;
  searchResultsDiv.style.display = 'block';
}

// 从服务器获取报价单
async function fetchQuotationFromServer(quoteId) {
  try {
    const response = await fetch(`/api/quotations/${quoteId}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
      }
    });

    if (response.ok) {
      const result = await response.json();
      // 确保从响应中正确提取数据
      const quotation = result.data;

      if (quotation) {
        // 将从服务器获取的报价单缓存到本地
        const existingQuotations = JSON.parse(localStorage.getItem('savedQuotations') || '[]');
        const existingIndex = existingQuotations.findIndex(q => q.id === quotation.id);

        if (existingIndex !== -1) {
          // 更新已存在的报价单
          existingQuotations[existingIndex] = quotation;
        } else {
          // 添加新的报价单
          existingQuotations.push(quotation);
        }

        // 限制保存最近的50个报价单
        const limitedQuotations = existingQuotations.slice(-50);
        localStorage.setItem('savedQuotations', JSON.stringify(limitedQuotations));

        return quotation;
      } else {
        console.error('从服务器获取的报价单数据为空');
        showMessage('从服务器获取的报价单数据为空', 'error');
        return null;
      }
    } else {
      console.error('获取服务器报价单失败:', response.status, response.statusText);
      showMessage('获取服务器报价单失败', 'error');
      return null;
    }
  } catch (error) {
    console.error('获取服务器报价单时发生错误:', error);
    showMessage('获取服务器报价单时发生错误', 'error');
    return null;
  }
}

// 加载指定ID的报价单
async function loadQuotation(quoteId, fromServer = false) {
  if (fromServer) {
    // 从服务器加载报价单
    const quotation = await fetchQuotationFromServer(quoteId);
    if (quotation) {
      // 这里应该有加载报价单到界面的逻辑
      // 由于原始代码中没有完整的加载逻辑，这里仅做提示
      showMessage(`已从服务器加载报价单: ${quotation.title}`, 'success');
      console.log('加载的报价单数据:', quotation);
      // TODO: 实现将报价单数据加载到界面的逻辑
    }
  } else {
    // 从本地加载报价单
    const allQuotations = JSON.parse(localStorage.getItem('savedQuotations') || '[]');
    const quotation = allQuotations.find(q => q.id === quoteId);

    if (quotation) {
      // 这里应该有加载报价单到界面的逻辑
      // 由于原始代码中没有完整的加载逻辑，这里仅做提示
      showMessage(`已从本地加载报价单: ${quotation.title}`, 'success');
      console.log('加载的报价单数据:', quotation);
      // TODO: 实现将报价单数据加载到界面的逻辑
    } else {
      showMessage('未找到指定的报价单', 'error');
    }
  }

  // 隐藏搜索结果
  document.getElementById('quoteSearchResults').style.display = 'none';
  // 清空搜索框
  document.getElementById('quoteSearchInput').value = '';
}

// 从ID加载报价单到购物车
async function loadQuotationToCartFromId(quoteId, fromServer = false) {
  let quotation = null;

  // 检查是否当前页面已经显示了报价单详情且来自服务器，如果是则直接使用
  if (window.currentQuotationDetail && window.currentQuotationDetail.id === quoteId) {
    quotation = window.currentQuotationDetail;
  } else if (fromServer) {
    // 从服务器加载报价单
    quotation = await fetchQuotationFromServer(quoteId);
  } else {
    // 从本地加载报价单
    const allQuotations = JSON.parse(localStorage.getItem('savedQuotations') || '[]');
    quotation = allQuotations.find(q => q.id === quoteId);
  }

  if (!quotation) {
    showMessage('未找到指定的报价单', 'error');
    return;
  }

  // 调用加载到购物车的函数
  loadQuotationToCartFromObject(quotation);
  closeQuotationDetailModal();
}

// 从报价单对象加载到购物车
function loadQuotationToCartFromObject(quotation) {
  if (!quotation) {
    showMessage('没有可加载的报价单数据', 'error');
    return;
  }

  try {
    // 清空当前购物车
    cartItems = [];
    tempItems = [];

    // 添加商品项目到购物车
    if (quotation.items) {
      quotation.items.forEach(item => {
        // 根据项目类型确定显示类型
        let displayType = "部件";
        if (item.type === "fees" || item.type === "费用") {
          displayType = "费用";
        } else if (item.type === "factors" || item.type === "系数") {
          displayType = "系数";
        }

        // 创建项目副本并添加到相应的数组
        if (displayType === "费用") {
          // 添加到临时项目中作为费用
          const tempItem = {
            id: item.id || Date.now() + Math.random(), // 生成新ID
            displayType: "费用",
            name: item.name || item.title || item.model || "",
            baseAmount: item.price || item.amount || 0,
            actualAmount: item.price || item.amount || 0,
            remark: item.remark || "",
            type: "fees"
          };
          tempItems.push(tempItem);
        } else if (displayType === "系数") {
          // 添加到临时项目中作为系数
          const tempItem = {
            id: item.id || Date.now() + Math.random(), // 生成新ID
            displayType: "系数",
            name: item.name || item.title || item.model || "",
            value: item.price || item.value || 1, // 系数值
            remark: item.remark || "",
            type: "factors"
          };
          tempItems.push(tempItem);
        } else {
          // 添加到购物车项目
          const cartItem = {
            id: item.id || Date.now() + Math.random(), // 生成新ID
            type: item.type || "部件",
            model: item.model || item.name || item.title || "",
            name: item.name || item.model || item.title || "",
            basePrice: item.price || 0,
            actualPrice: item.price || 0,
            quantity: item.quantity || 1,
            remark: item.remark || "",
            image: item.image || "./sample.jpg"
          };
          cartItems.push(cartItem);
        }
      });
    }

    // 如果报价单中有明确的购物车项目、费用项目和系数项目，优先使用这些
    if (quotation.cartItems) {
      quotation.cartItems.forEach(item => {
        const cartItem = {
          id: item.id || Date.now() + Math.random(), // 生成新ID
          type: item.type || "部件",
          model: item.model || item.name || "",
          name: item.name || item.model || "",
          basePrice: item.basePrice || item.actualPrice || 0,
          actualPrice: item.actualPrice || item.basePrice || 0,
          quantity: item.quantity || 1,
          remark: item.remark || "",
          image: item.image || "./sample.jpg"
        };
        cartItems.push(cartItem);
      });
    }

    if (quotation.tempFees) {
      quotation.tempFees.forEach(fee => {
        const tempItem = {
          id: fee.id || Date.now() + Math.random(), // 生成新ID
          displayType: "费用",
          name: fee.name || "",
          baseAmount: fee.baseAmount || fee.actualAmount || 0,
          actualAmount: fee.actualAmount || fee.baseAmount || 0,
          remark: fee.remark || "",
          type: "fees"
        };
        tempItems.push(tempItem);
      });
    }

    if (quotation.tempFactors) {
      quotation.tempFactors.forEach(factor => {
        const tempItem = {
          id: factor.id || Date.now() + Math.random(), // 生成新ID
          displayType: "系数",
          name: factor.name || "",
          value: factor.value || 1,
          remark: factor.remark || "",
          type: "factors"
        };
        tempItems.push(tempItem);
      });
    }

    // 更新购物车计数
    updateCartCount();

    // 更新tempData以确保数据同步
    if (typeof updateTempData === 'function') {
      updateTempData();
    }

    // 更新tempData中的小计和总计备注内容
    const tempDataStr = localStorage.getItem('tempData');
    if (tempDataStr) {
      const tempData = JSON.parse(tempDataStr);
      tempData.subtotal_remark = quotation.subtotal_remark || "";
      tempData.total_remark = quotation.total_remark || "";
      tempData.id = quotation.id; // 确保ID同步
      localStorage.setItem('tempData', JSON.stringify(tempData));
    }

    showMessage('报价单已加载到购物车', 'success');

  } catch (error) {
    console.error('加载报价单到购物车时出错:', error);
    showMessage('加载报价单到购物车时出错', 'error');
  }
}

// 显示报价单详情
async function showQuotationDetail(quotationId, fromServer = false) {
  let quotation = null;

  if (fromServer) {
    // 从服务器加载报价单
    quotation = await fetchQuotationFromServer(quotationId);
  } else {
    // 从本地加载报价单
    const allQuotations = JSON.parse(localStorage.getItem('savedQuotations') || '[]');
    quotation = allQuotations.find(q => q.id === quotationId);
  }

  if (!quotation) {
    showMessage('未找到指定的报价单', 'error');
    return;
  }

  // 存储当前报价单到全局变量，供加载到购物车时使用
  window.currentQuotationDetail = quotation;

  // 语言设置
  const isEnglish = window.isEnglishDisplay || false;

  // 根据语言设置定义标签
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
        total: `TOTAL (${quotation.currency || 'CNY'})`,
        remark: "Remark",
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
        total: `总计 (${quotation.currency || 'CNY'})`,
        remark: "备注",
      };

  // 构建详情内容 - 使用表格格式
  let detailHtml = `
    <div style="margin-bottom: 15px;">
      <h3>${quotation.title}</h3>
      <p><strong>总计:</strong> ${quotation.total ? formatCurrency(quotation.total) : 'N/A'} ${quotation.currency || ''}</p>
      <p><strong>创建时间:</strong> ${new Date(quotation.createdAt).toLocaleString()}</p>
      <p><strong>更新时间:</strong> ${new Date(quotation.updatedAt).toLocaleString()}</p>
    </div>
  `;

  // 从报价单中提取项目数据
  const allItems = quotation.items || [];
  const cartItems = allItems.filter(item =>
    item.type !== 'fees' && item.type !== 'factors' &&
    item.displayType !== '费用' && item.displayType !== '系数'
  );
  const feeItems = allItems.filter(item =>
    item.type === 'fees' || item.displayType === '费用'
  );
  const factorItems = allItems.filter(item =>
    item.type === 'factors' || item.displayType === '系数'
  );

  // 计算基础总计、费用总计和系数
  const baseTotal = cartItems.reduce((sum, item) => sum + (item.price || 0) * (item.quantity || 1), 0);
  const tempFees = feeItems.reduce((sum, item) => sum + (item.price || 0), 0);
  const factor = factorItems.reduce((prod, item) => prod * (item.price || item.value || 1), 1);
  const total = (baseTotal + tempFees) * factor;

  // 使用表格格式展示
  detailHtml += `
    <table style="width: 100%; border-collapse: collapse; margin-top: 15px;">
        <thead>
            <tr style="background-color: #f2f2f2;">
                <th style="border: 1px solid #ddd; padding: 10px; text-align: center; width: 60px; white-space: nowrap;">${labels.no}</th>
                <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">${labels.name}</th>
                <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">${labels.unitPrice}</th>
                <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">${labels.qty}</th>
                <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">${labels.subtotal}</th>
                <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">${labels.remark}</th>
            </tr>
        </thead>
        <tbody>
  `;

  // 添加购物车项目（商品项目）
  cartItems.forEach((item, index) => {
    const itemIndex = index + 1; // 序号从1开始
    const subtotal = (item.price || 0) * (item.quantity || 1);

    detailHtml += `
        <tr>
            <td style="border: 1px solid #ddd; padding: 10px; text-align: center; white-space: nowrap;">${itemIndex}</td>
            <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">
                <strong>${item.model || item.name || 'N/A'}</strong>
            </td>
            <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(item.price || 0)}</td>
            <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">${item.quantity || 1}</td>
            <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(subtotal)}</td>
            <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">${item.remark || ''}</td>
        </tr>
    `;
  });

  // 添加商品小计行
  if (cartItems.length > 0) {
    detailHtml += `
        <tr style="background-color: #f0f8ff; font-weight: bold;">
            <td colspan="4" style="border: 1px solid #ddd; padding: 10px; text-align: right;">${labels.subtotalExcludingFees}</td>
            <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(baseTotal)}</td>
            <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">${quotation.subtotal_remark || ''}</td>
        </tr>
    `;
  }

  // 添加其它费用
  feeItems.forEach((item, index) => {
    const itemIndex = cartItems.length + index + 1;
    detailHtml += `
        <tr style="background-color: #f9f9f9;">
            <td style="border: 1px solid #ddd; padding: 10px; text-align: center; white-space: nowrap;"><strong>${labels.add}</strong></td>
            <td colspan="3" style="border: 1px solid #ddd; padding: 10px; text-align: center;"><strong>${item.name || 'N/A'}</strong></td>
            <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(item.price || 0)}</td>
            <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">${item.remark || ''}</td>
        </tr>
    `;
  });

  // 添加系数
  factorItems.forEach((item, index) => {
    const itemIndex = cartItems.length + feeItems.length + index + 1;
    detailHtml += `
        <tr style="background-color: #f9f9f9;">
            <td style="border: 1px solid #ddd; padding: 10px; text-align: center; white-space: nowrap;"><strong>${isEnglish ? "Factor" : "系数"}</strong></td>
            <td colspan="3" style="border: 1px solid #ddd; padding: 10px; text-align: center;"><strong>${item.name || 'N/A'}</strong></td>
            <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">x ${item.price || item.value || 1}</td>
            <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">${item.remark || ''}</td>
        </tr>
    `;
  });

  // 显示总计
  detailHtml += `
      <tr style="background-color: #e8f5e9; font-weight: bold;">
          <td colspan="4" style="border: 1px solid #ddd; padding: 10px; text-align: right;">${labels.total}</td>
          <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(total)}</td>
          <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">${quotation.total_remark || ''}</td>
      </tr>
  `;

  detailHtml += `
        </tbody>
    </table>
  `;

  document.getElementById("quotationDetailContent").innerHTML = detailHtml;
  document.getElementById("quotationDetailModal").style.display = "block";

  // 动态设置加载到购物车按钮的点击事件，传递正确的报价单ID
  const loadToCartBtn = document.getElementById("loadQuotationToCartBtn");
  if (loadToCartBtn) {
    loadToCartBtn.onclick = function() {
      loadQuotationToCartFromId(quotationId, fromServer);
    };
  }

  // // 隐藏搜索结果
  // document.getElementById('quoteSearchResults').style.display = 'none';
  // // 清空搜索框
  // document.getElementById('quoteSearchInput').value = '';
}

// 关闭详情模态框
function closeQuotationDetailModal() {
  document.getElementById("quotationDetailModal").style.display = "none";
}