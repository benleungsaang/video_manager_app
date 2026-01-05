// 购物车功能模块
// 包含购物车管理、添加部件、费用、系数等功能

// 显示购物车
function showCart() {
  currentView = "cart";
  renderCart();

  // 显示购物车模态框
  document.getElementById("cartModal").style.display = "block";

  // 显示操作按钮
  document.getElementById("cartActions").style.display = "block";

  // 控制清空购物车按钮的显示：只有在购物车有内容时才显示
  const modalClearCartBtn = document.getElementById("modalClearCartBtn");
  if (cartItems.length > 0) {
    modalClearCartBtn.style.display = "inline-block";
  } else {
    modalClearCartBtn.style.display = "none";
  }

  // 在显示购物车时，更新最常用的项目显示
  // 基于当前的缓存数据重新计算topUsed数据
  showTopUsedItems("parts");
  showTopUsedItems("fees");
  showTopUsedItems("factors");

  // 同时更新主页面清空按钮显示状态
  updateCartCount();
}

// 关闭购物车
function closeCartModal() {
  document.getElementById("cartModal").style.display = "none";
  currentView = "main";
}

// 渲染购物车内容
function renderCart() {
  const cartContent = document.getElementById("cartContent");

  let html = `
          <table style="width: 100%; border-collapse: collapse;">
              <thead>
                  <tr style="background-color: #f2f2f2;">
                      <th style="border: 1px solid #ddd; padding: 10px; text-align: center; width: 50px;">序号</th>
                      <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">图片</th>
                      <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">型号</th>
                      <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">单价</th>
                      <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">数量</th>
                      <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">小计</th>
                      <th style="border: 1px solid #ddd; padding: 10px; text-align: center;">操作</th>
                  </tr>
              </thead>
              <tbody>
          `;

  if (cartItems.length === 0 && tempItems.length === 0) {
    // 购物车和临时项目都为空时，显示表头和"购物车为空"的提示行
    html += `
              <tr>
                  <td colspan="7" style="border: 1px solid #ddd; padding: 20px; text-align: center; font-size: 16px; color: #666;">购物车为空</td>
              </tr>
          `;
  } else {
    // 添加机器及部件标题行
    html += `
              <tr style="background-color: #e6f3ff; font-weight: bold;">
                  <td colspan="7" style="border: 1px solid #ddd; padding: 10px; text-align: center;">机器及部件</td>
              </tr>
          `;

    // 显示购物车项目
    cartItems.forEach((item, index) => {
      const itemIndex = index + 1; // 序号从1开始
      const subtotal = item.actualPrice * item.quantity;
      html += `
                  <tr>
                      <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">${itemIndex}</td>
                      <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">
                          <img src="data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='60' height='60' viewBox='0 0 24 24' fill='none' stroke='%23ccc' stroke-width='2'><rect x='3' y='3' width='18' height='18' rx='2' ry='2'/><line x1='8' y1='12' x2='16' y2='12'/><line x1='12' y1='8' x2='12' y2='16'/></svg>" alt="${item.model
        }" style="width: 60px; height: 60px; object-fit: cover; border: 1px solid #ddd;">
                      </td>
                      <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">
                          <strong>${item.model}</strong>
                      </td>
                      <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">
                          <input type="number"
                                 value="${item.actualPrice.toFixed(2)}"
                                 onchange="updateCartItemPrice(${index}, this.value)"
                                 min="0"
                                 step="0.01"
                                 style="width: 100px; padding: 5px; border: 1px solid #ccc; border-radius: 3px; text-align: center;">
                      </td>
                      <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">
                          <input type="number"
                                 value="${item.quantity}"
                                 onchange="updateCartItemQuantity(${index}, this.value)"
                                 min="1"
                                 step="1"
                                 style="width: 60px; padding: 5px; border: 1px solid #ccc; border-radius: 3px; text-align: center;">
                      </td>
                      <td style="border: 1px solid #ddd; padding: 10px; text-align: right; font-weight: bold;">${formatCurrency(
          subtotal
        )}</td>
                      <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">
                          <button class="danger" onclick="removeCartItem(${index})" title="删除">🗑️</button>
                      </td>
                  </tr>
              `;
    });
  }

  // 添加商品小计行（即使没有购物车项目也要计算baseTotal）
  let baseTotal = cartItems.reduce(
    (sum, item) => sum + item.actualPrice * item.quantity,
    0
  );

  // 如果有购物车项目，则显示商品小计行
  if (cartItems.length > 0) {
    html += `
              <tr style="background-color: #f0f8ff; font-weight: bold;">
                  <td colspan="5" style="border: 1px solid #ddd; padding: 10px; text-align: right;">商品小计</td>
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      baseTotal
    )}</td>
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">-</td>
              </tr>
          `;
  }

  // 如果有其它费用项目，则添加其它费用标题行
  if (tempItems.some((item) => item.displayType === "费用")) {
    html += `
              <tr style="background-color: #fff3e6; font-weight: bold;">
                  <td colspan="7" style="border: 1px solid #ddd; padding: 10px; text-align: center;">其它费用</td>
              </tr>
          `;
  }

  // 添加其它费用行（只要有其它费用项目就显示）
  tempItems
    .filter((item) => item.displayType === "费用")
    .forEach((item, index) => {
      const itemIndex = tempItems.findIndex((i) => i.id === item.id);
      html += `
              <tr style="background-color: #f9f9f9;">
                  <td colspan="3" style="border: 1px solid #ddd; padding: 10px; text-align: center;"><strong>${item.name
        }</strong></td>
                  <td colspan="2" style="border: 1px solid #ddd; padding: 10px; text-align: center;">
                      <input type="number"
                             value="${item.actualAmount.toFixed(2)}"
                             onchange="updateTempFeeAmount(${itemIndex}, this.value)"
                             min="0"
                             step="0.01"
                             style="width: 100px; padding: 5px; border: 1px solid #ccc; border-radius: 3px; text-align: center;">
                  </td>
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: center; font-weight: bold;">${formatCurrency(
          item.actualAmount
        )}</td>
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">
                      <button class="danger" onclick="removeTempItemFromCart(${itemIndex})">删除</button>
                  </td>
              </tr>
          `;
    });

  // 如果有系数项目，则添加系数标题行
  if (tempItems.some((item) => item.displayType === "系数")) {
    html += `
              <tr style="background-color: #f0f8e6; font-weight: bold;">
                  <td colspan="7" style="border: 1px solid #ddd; padding: 10px; text-align: center;">系数</td>
              </tr>
          `;
  }

  // 添加系数行（只要有系数项目就显示）
  tempItems
    .filter((item) => item.displayType === "系数")
    .forEach((item, index) => {
      const itemIndex = tempItems.findIndex((i) => i.id === item.id);
      html += `
              <tr style="background-color: #f9f9f9;">
                  <td colspan="3" style="border: 1px solid #ddd; padding: 10px; text-align: center;"><strong>${item.name}</strong></td>
                  <td colspan="2" style="border: 1px solid #ddd; padding: 10px; text-align: center;">
                      <input type="number"
                             value="${item.value}"
                             onchange="updateTempFactorValue(${itemIndex}, this.value)"
                             min="0"
                             step="0.01"
                             style="width: 100px; padding: 5px; border: 1px solid #ccc; border-radius: 3px; text-align: center;">
                  </td>
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: center; font-weight: bold;">x ${item.value}</td>
                  <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">
                      <button class="danger" onclick="removeTempItemFromCart(${itemIndex})">删除</button>
                  </td>
              </tr>
          `;
    });

  // 计算总计（只要有临时项目就显示总计行）
  if (tempItems.length > 0 || cartItems.length > 0) {
    let tempFees = tempItems
      .filter((item) => item.displayType === "费用")
      .reduce((sum, item) => sum + item.actualAmount, 0);
    let factor = tempItems
      .filter((item) => item.displayType === "系数")
      .reduce((prod, item) => prod * item.value, 1);
    let total = (baseTotal + tempFees) * factor;

    // 添加总计行
    const currencyCode = window.currentCurrencyCode || "CNY"; // 使用当前币种代码
    html += `
                      <tr style="background-color: #e8f5e9; font-weight: bold;">
                          <td colspan="5" style="border: 1px solid #ddd; padding: 10px; text-align: right;">总计 (${currencyCode})</td>
                          <td style="border: 1px solid #ddd; padding: 10px; text-align: right;">${formatCurrency(
      total
    )}</td>
                          <td style="border: 1px solid #ddd; padding: 10px; text-align: center;">-</td>
                      </tr>
                  `;
  }

  html += `
              </tbody>
          </table>
      `;

  cartContent.innerHTML = html;
}

// 更新购物车项目价格
function updateCartItemPrice(index, value) {
  const parsedValue = parseFloat(value);
  if (!isNaN(parsedValue) && parsedValue >= 0) {
    cartItems[index].actualPrice = parsedValue;
    renderCart(); // 重新渲染以更新总计
    updateCartSummary(); // 更新主页面购物车摘要
  } else {
    showMessage("请输入有效的价格", "error");
  }
}

// 更新购物车项目数量
function updateCartItemQuantity(index, value) {
  const parsedValue = parseInt(value);
  if (!isNaN(parsedValue) && parsedValue >= 1) {
    cartItems[index].quantity = parsedValue;
    renderCart(); // 重新渲染以更新总计
    updateCartSummary(); // 更新主页面购物车摘要
    updateCartCount(); // 更新计数
  } else {
    showMessage("请输入有效的数量（至少为1）", "error");
  }
}

// 显示其它费用表单
async function showTempFeeForm() {
  document.getElementById("tempFeeForm").style.display = "block";
  // 加载最常用的费用
  await showTopUsedItems("fees");
}

// 显示系数表单
async function showTempFactorForm() {
  document.getElementById("tempFactorForm").style.display = "block";
  // 加载最常用的系数
  await showTopUsedItems("factors");
}

// 关闭其它费用表单
function closeTempFeeForm() {
  document.getElementById("tempFeeForm").style.display = "none";
}

// 关闭系数表单
function closeTempFactorForm() {
  document.getElementById("tempFactorForm").style.display = "none";
}

// 添加其它费用到购物车
async function addTempFeeToCart() {
  const inputIds = {
    name: "tempFeeNameCart",
    amount: "tempFeeAmountCart",
  };

  const validationFn = (inputs) => {
    const name = inputs.name;
    const amount = parseFloat(inputs.amount) || 0;
    if (!name) {
      return { isValid: false, message: "请输入费用名称" };
    }
    return { isValid: true };
  };

  const createCartObjectFn = (inputs) => {
    const amount = parseFloat(inputs.amount) || 0;
    return {
      id: Date.now(),
      displayType: "费用", // 用于显示的类型
      name: inputs.name,
      baseAmount: amount, // 原始金额
      actualAmount: amount, // 实际金额，默认等于原始金额
      type: "fees", // 标记为费用类型
    };
  };

  const apiCallFn = async (inputs) => {
    const newFee = {
      name: inputs.name,
      value: parseFloat(inputs.amount) || 0,  // 使用 value 字段而不是 amount
      addedCount: 1, // 初始添加次数为1
      action: "createTempFee", // 操作类型
    };
    return await apiClient.createTempFee(newFee);
  };

  await addToCartGeneric(
    "fees",
    inputIds,
    validationFn,
    createCartObjectFn,
    "fees",
    apiCallFn,
    "其它费用",
    closeTempFeeForm
  );
}

// 添加系数到购物车
async function addTempFactorToCart() {
  const inputIds = {
    name: "tempFactorNameCart",
    value: "tempFactorValueCart",
  };

  const validationFn = (inputs) => {
    const name = inputs.name;
    if (!name) {
      return { isValid: false, message: "请输入系数名称" };
    }
    return { isValid: true };
  };

  const createCartObjectFn = (inputs) => {
    const value = parseFloat(inputs.value) || 1;
    return {
      id: Date.now(),
      displayType: "系数", // 用于显示的类型
      name: inputs.name,
      value: value,
      type: "factors", // 标记为系数类型
    };
  };

  const apiCallFn = async (inputs) => {
    const newFactor = {
      name: inputs.name,
      value: parseFloat(inputs.value) || 1,
      addedCount: 1, // 初始添加次数为1
      action: "createTempFactor", // 操作类型
    };
    return await apiClient.createTempFactor(newFactor);
  };

  await addToCartGeneric(
    "factors",
    inputIds,
    validationFn,
    createCartObjectFn,
    "factors",
    apiCallFn,
    "系数",
    closeTempFactorForm
  );
}

// 显示添加部件表单
async function showAddPartForm() {
  document.getElementById("addPartForm").style.display = "block";
  // 加载最常用的部件
  await showTopUsedItems("parts");
}

// 关闭添加部件表单
function closeAddPartForm() {
  document.getElementById("addPartForm").style.display = "none";
}

// 添加部件到购物车
async function addPartToCart() {
  const inputIds = {
    model: "partModel",
    price: "partPrice",
  };

  const validationFn = (inputs) => {
    const model = inputs.model;
    const price = parseFloat(inputs.price) || 0;

    if (!model) {
      return { isValid: false, message: "请输入部件型号" };
    }

    if (price < 0) {
      return { isValid: false, message: "请输入有效的部件单价" };
    }

    return { isValid: true };
  };

  const createCartObjectFn = (inputs) => {
    const price = parseFloat(inputs.price) || 0;

    return {
      id: Date.now(),
      type: "部件",
      model: inputs.model,
      name: inputs.model, // 使用型号作为名称
      basePrice: price, // 原始价格
      actualPrice: price, // 实际价格，默认等于原始价格
      quantity: 1, // 添加时默认数量为1
      image: "./sample.jpg", // 使用临时部件图片
      type: "parts", // 标记为部件类型
    };
  };

  const apiCallFn = async (inputs) => {
    const response = await apiClient.createPart({
      model: inputs.model,
      price: parseFloat(inputs.price) || 0, // 使用新的price字段
      remark: "", // 部件详细描述
      addedCount: 1, // 被添加次数
      action: "createPart", // 操作类型
    });

    return response;
  };

  await addToCartGeneric(
    "parts",
    inputIds,
    validationFn,
    createCartObjectFn,
    "parts",
    apiCallFn,
    "部件",
    closeAddPartForm
  );

  updateCartCount(); // 更新计数
}

// 更新其它费用金额
function updateTempFeeAmount(index, value) {
  const parsedValue = parseFloat(value);
  if (!isNaN(parsedValue) && parsedValue >= 0) {
    tempItems[index].actualAmount = parsedValue;
    renderCart(); // 重新渲染以更新总计
    updateCartSummary(); // 更新主页面购物车摘要
  } else {
    showMessage("请输入有效的金额", "error");
  }
}

// 更新系数值
function updateTempFactorValue(index, value) {
  const parsedValue = parseFloat(value);
  if (!isNaN(parsedValue) && parsedValue >= 0) {
    tempItems[index].value = parsedValue;
    renderCart(); // 重新渲染以更新总计
    updateCartSummary(); // 更新主页面购物车摘要
  } else {
    showMessage("请输入有效的系数", "error");
  }
}

// 从购物车中删除临时项目
function removeTempItemFromCart(index) {
  if (confirm("确定要删除这个临时项目吗？")) {
    tempItems.splice(index, 1);
    renderCart();
    updateCartSummary(); // 更新主页面购物车摘要
  }
}

// 从购物车中删除项目
function removeCartItem(index) {
  if (confirm("确定要从购物车中删除这个项目吗？")) {
    cartItems.splice(index, 1);
    renderCart();
    updateCartSummary(); // 更新主页面购物车摘要
    updateCartCount(); // 更新计数
  }
}

// 通用添加到购物车函数
async function addToCartGeneric(
  type,
  inputIds,
  validationFn,
  createCartObjectFn,
  recordUsageType,
  apiCallFn,
  successMessage,
  formCloseFn
) {
  // 获取输入值
  const inputs = {};
  for (const [key, id] of Object.entries(inputIds)) {
    inputs[key] = document.getElementById(id).value;
  }

  // 验证输入
  const validation = validationFn(inputs);
  if (!validation.isValid) {
    showMessage(validation.message, "error");
    return;
  }

  // 创建购物车项目
  const cartItem = createCartObjectFn(inputs);

  // 添加到购物车
  if (type === "parts") {
    cartItems.push(cartItem);
  } else {
    tempItems.push(cartItem);
  }

  // 记录使用次数 - 使用创建的购物车项目ID
  if (cartItem.id) {
    recordItemUsageForBatchUpdate(
      cartItem.id,
      recordUsageType
    );
  } else {
    // 如果购物车项目没有ID，尝试使用inputs中的name或model字段作为后备
    const itemId = inputs['id'] || inputs['name'] || inputs['model'] || inputs['tempFeeNameCart'] || inputs['tempFactorNameCart'] || inputs['partModel'];
    if (itemId) {
      recordItemUsageForBatchUpdate(
        itemId,
        recordUsageType
      );
    }
  }

  // 调用API
  try {
    const response = await apiCallFn(inputs);
    if (response.success || response.data) {
      // 确保window数据已初始化
      let dataKey = "";
      if (type === "parts") {
        dataKey = "partsData";
      } else if (type === "fees") {
        dataKey = "feesData";
      } else if (type === "factors") {
        dataKey = "factorsData";
      }

      if (response.data && response.timestamp && window[dataKey]) {
        // 更新本地缓存的时间戳
        if (response.timestamp > (lastUpdateTime || 0)) {
          lastUpdateTime = response.timestamp;

          let timestampKey = "";
          if (type === "parts") {
            timestampKey = "lastPartsTimestamp";
            // 更新parts时间戳
            localStorage.setItem(
              "lastPartsTimestamp",
              response.timestamp.toString()
            );
          } else if (type === "fees") {
            timestampKey = "lastFeesTimestamp";
            localStorage.setItem(
              "lastFeesTimestamp",
              response.timestamp.toString()
            );
          } else if (type === "factors") {
            timestampKey = "lastFactorsTimestamp";
            localStorage.setItem(
              "lastFactorsTimestamp",
              response.timestamp.toString()
            );
          }
        }

        // 更新数据缓存
        if (!window[dataKey]) {
          window[dataKey] = [];
        }

        // 查找并更新或添加项目
        const itemKey = type === "parts" ? "model" : "name";
        const itemValue = inputs[itemKey];

        const existingIndex = window[dataKey].findIndex(
          (p) => p[itemKey] === itemValue
        );
        if (existingIndex !== -1) {
          // 更新现有项
          window[dataKey][existingIndex] = response.data;
        } else {
          // 添加新项
          window[dataKey].push(response.data);
        }

        // 更新localStorage中的完整数据缓存
        localStorage.setItem(
          `cached${type === "parts"
            ? "Parts"
            : type === "fees"
              ? "Fees"
              : "Factors"
          }`,
          JSON.stringify(window[dataKey])
        );

        // 重新计算并更新最常用的项目（基于完整的数据和addedCount字段）
        if (window[dataKey] && Array.isArray(window[dataKey])) {
          // 基于addedCount字段排序，取前5个最常用的项目
          const topItems = [...window[dataKey]]
            .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
            .slice(0, 5);

          // 更新localStorage中的最常用项目缓存
          const topUsedKey = `cachedTopUsed${type === "parts"
            ? "Parts"
            : type === "fees"
              ? "Fees"
              : "Factors"
            }`;
          localStorage.setItem(topUsedKey, JSON.stringify(topItems));
        }
      }
      showMessage(successMessage + "已添加到服务器", "success");
    } else {
      showMessage(
        successMessage + "添加失败: " + (response.error || "未知错误"),
        "error"
      );
    }
  } catch (error) {
    console.error(`添加${successMessage}到服务器失败:`, error);
    showMessage(`${successMessage}添加失败: ${error.message}`, "error");
  }

  renderCart();
  updateCartSummary(); // 更新主页面购物车摘要

  // 清空输入框
  for (const [key, id] of Object.entries(inputIds)) {
    document.getElementById(id).value = ""; // 清空所有输入框
  }

  // 关闭模态框
  formCloseFn();

  showMessage(`${successMessage}已添加`, "success");
}

// 清空购物车确认
function clearCartConfirmation() {
  if (confirm("确定要清空购物车吗？")) {
    clearCart();
  }
}

// 清空购物车
function clearCart() {
  cartItems = [];
  tempItems = [];
  renderCart();
  updateCartCount();
  updateCartSummary();
  showMessage("购物车已清空", "success");
}
