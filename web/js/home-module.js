// 主页功能模块
// 包含搜索、添加到购物车等主页相关功能

// 搜索功能相关函数
let searchTimeout = null;

// 搜索功能 - 只在回车时进行搜索
document.getElementById("searchInput").addEventListener("keypress", function (event) {
  if (event.key === "Enter") {
    performSearch();
  }
});

// 防抖搜索函数 - 现在使用缓存数据进行本地搜索
function performSearch() {
  // 清除之前的防抖定时器
  if (searchTimeout) {
    clearTimeout(searchTimeout);
  }

  // 设置新的防抖定时器
  searchTimeout = setTimeout(() => {
    const searchTerm = document.getElementById("searchInput").value.toLowerCase();
    const resultsDiv = document.getElementById("searchResults");

    if (!searchTerm) {
      // 如果搜索框为空，显示热门商品
      showPopularItems();
      return;
    }

    // 优先使用localStorage缓存数据，如果没有则使用内存缓存数据
    let localStorageData = localStorage.getItem("cachedMachines");
    let searchDataSource = [];

    if (localStorageData) {
      searchDataSource = JSON.parse(localStorageData);
    } else if (cachedBaseData) {
      searchDataSource = cachedBaseData;
    } else {
      searchDataSource = baseData;
    }

    // 支持新旧型号搜索，但只显示新型号
    const filteredItems = searchDataSource.filter(
      (item) =>
        item.Model.toLowerCase().includes(searchTerm) ||
        (item.OriginalModel &&
          item.OriginalModel.toLowerCase().includes(searchTerm))
    );

    let html = `<h3>搜索结果 (${filteredItems.length} 项):</h3>`;
    if (filteredItems.length === 0) {
      html += "<p>未找到匹配的项目</p>";
    } else {
      filteredItems.forEach((item) => {
        html += `
                      <div class="item-row" style="display: flex; align-items: center; padding: 10px; border: 1px solid #eee; border-radius: 4px; background-color: #fff; margin-bottom: 10px; cursor: pointer;" onclick="showItemDetail(${JSON.stringify(
                        item
                      ).replace(/"/g, "&quot;")})">
                          <img src="data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='80' height='80' viewBox='0 0 24 24' fill='none' stroke='%23ccc' stroke-width='2'><rect x='3' y='3' width='18' height='18' rx='2' ry='2'/><line x1='8' y1='12' x2='16' y2='12'/><line x1='12' y1='8' x2='12' y2='16'/></svg>" alt="${
                            item.Model
                          }" style="width: 80px; height: 80px; object-fit: cover; margin-right: 15px; border: 1px solid #ddd; border-radius: 4px;">
                          <div style="flex: 1;">
                              <div><strong>${item.Model}</strong></div>
                              <div style="color: #666; font-size: 0.9em;">价格: <span style="color: #e74c3c; font-weight: bold;">${formatCurrency(
                                item.ShowPrice
                              )}</span></div>
                          </div>
                          <button class="secondary" onclick="event.stopPropagation(); addToCart(${JSON.stringify(
                            item
                          ).replace(
                            /"/g,
                            "&quot;"
                          )})" title="添加到购物车">🛒</button>
                      </div>
                  `;
      });
    }

    resultsDiv.innerHTML = html;
  }, 300); // 300ms防抖延迟
}

// 显示热门商品（被添加次数最多的前5个）
function showPopularItems() {
  // 从本地缓存获取数据
  const cachedData = JSON.parse(
    localStorage.getItem("cachedMachines") || "[]"
  );
  const allData = cachedData.length > 0 ? cachedData : baseData;

  // 直接对全部数据按addedCount排序，取前5个
  const popularItems = [...allData]
    .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
    .slice(0, 5);

  let html = "<h3>热门机器（被添加次数最多）:</h3>";
  if (popularItems.length === 0) {
    html += "<p>暂无数据</p>";
  } else {
    popularItems.forEach((item) => {
      html += `
              <div class="item-row" style="display: flex; align-items: center; padding: 10px; border: 1px solid #eee; border-radius: 4px; background-color: #fff; margin-bottom: 10px; cursor: pointer;" onclick="showItemDetail(${JSON.stringify(
                      item
                  ).replace(
                      /"/g,
                      "&quot;"
                  )})">
                  <img src="data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='80' height='80' viewBox='0 0 24 24' fill='none' stroke='%23ccc' stroke-width='2'><rect x='3' y='3' width='18' height='18' rx='2' ry='2'/><line x1='8' y1='12' x2='16' y2='12'/><line x1='12' y1='8' x2='12' y2='16'/></svg>" alt="${
                      item.Model
                  }" style="width: 80px; height: 80px; object-fit: cover; margin-right: 15px; border: 1px solid #ddd; border-radius: 4px;">
                  <div style="flex: 1;">
                      <div><strong>${
                      item.Model
                  }</strong></div>
                      <div style="color: #666; font-size: 0.9em;">价格: <span style="color: #e74c3c; font-weight: bold;">${formatCurrency(
                      item.ShowPrice
                  )}</span></div>
                      <div style="color: #999; font-size: 0.8em;">被添加 ${
                      item.addedCount ||
                      0
                  } 次</div>
                  </div>
                  <button class="secondary" onclick="event.stopPropagation(); addToCart(${JSON.stringify(
                      item
                  ).replace(
                      /"/g,
                      "&quot;"
                  )})" title="添加到购物车">🛒</button>
              </div>
          `;
    });
  }

  document.getElementById("searchResults").innerHTML = html;
}

// 添加项目到购物车
async function addToCart(item) {
  // 检查项目是否已在购物车中
  const existingItemIndex = cartItems.findIndex(
    (cartItem) => cartItem.model === item.Model
  );

  if (existingItemIndex !== -1) {
    // 如果已在购物车中，增加数量
    cartItems[existingItemIndex].quantity += 1;
  } else {
    // 如果不在购物车中，添加新项目
    const cartItem = {
      id: Date.now(), // 唯一ID
      type: "机器",
      model: item.Model,
      name: item.OriginalModel,
      basePrice: item.ShowPrice,
      actualPrice: item.ShowPrice, // 默认实际价格等于基础价格
      quantity: 1, // 默认数量为1
      image: item.image,
    };

    cartItems.push(cartItem);
  }

  // 记录需要更新使用次数的项目（在生成报价单时统一更新）
  recordItemUsageForBatchUpdate(item.Model, "machine_parts");

  // 更新购物车计数
  updateCartCount();

  // 显示成功消息
  showMessage(`已将 ${item.Model} 添加到购物车`, "success");
}

// 显示产品详情
async function showItemDetail(item) {
  // 获取用户角色
  const userRole = await checkUserRole();

  // 构建所有字段的表格，以只读形式显示
  let fieldsTable =
    '<div style="max-height: 70vh; overflow-y: auto;"><table style="width: 100%; border-collapse: collapse; margin-top: 15px; margin-bottom:35px;">';
  fieldsTable += "<tbody>";

  // 遍历item的所有属性（除了image，因为我们要单独处理）
  for (const key in item) {
    if (item.hasOwnProperty(key) && key !== "image") {
      // 非管理员跳过id、OriginalPrice、ShowPrice字段
      if (
        userRole !== "admin" &&
        (key === "id" ||
          key === "Id" ||
          key === "_id" ||
          key === "OriginalPrice" ||
          key === "ShowPrice")
      ) {
        continue; // 跳过这些字段
      }
      // 以只读形式显示字段值
      fieldsTable += `<tr><td style="border: 1px solid #ddd; padding: 10px;"><strong>${key}</strong></td><td id="detail-field-${key}" style="border: 1px solid #ddd; padding: 10px;">${item[key]}</td></tr>`;
    }
  }

  fieldsTable += "</tbody></table></div>";

  const detailContent = document.getElementById("detailContent");

  // 根据用户角色决定是否显示编辑按钮
  const editButtonHtml =
    userRole === "admin"
      ? '<button id="editButton" class="secondary" onclick="toggleEditDetail()" style="background-color: #2196F3; color: white;" title="编辑">✏️ 编辑</button>'
      : ""; // 非管理员不显示编辑按钮

  detailContent.innerHTML = `
          <div style="display: flex; align-items: flex-start; margin-bottom: 15px;">
              <div style="position: relative; display: inline-block;">
                  <img id="detailImage" src="data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='150' height='150' viewBox='0 0 24 24' fill='none' stroke='%23ccc' stroke-width='2'><rect x='3' y='3' width='18' height='18' rx='2' ry='2'/><line x1='8' y1='12' x2='16' y2='12'/><line x1='12' y1='8' x2='12' y2='16'/></svg>" alt="${
                    item.Model
                  }" style="width: 150px; height: 150px; object-fit: cover; border: 1px solid #ddd; border-radius: 4px;">
                  <button id="changeImageButton" onclick="changeImage()" style="position: absolute; bottom: 5px; right: 5px; background-color: rgba(0,0,0,0.5); color: white; border: none; border-radius: 50%; width: 25px; height: 25px; font-size: 14px; cursor: pointer; z-index: 10;" title="更换图片">+</button>
              </div>
              <div style="margin-left: 20px;">
                  <h3>${item.Model}</h3>
                  <p><strong>价格:</strong> <span id="detailShowPriceDisplay">${formatCurrency(
                    item.ShowPrice
                  )}</span></p>
                  <div style="margin-top: 10px;">
                      <button class="secondary" onclick="addToCartFromDetail()" style="margin-right: 10px;" title="添加到购物车">🛒 添加到购物车</button>
                      ${editButtonHtml}
                  </div>
              </div>
          </div>
          <div id="fieldsContainer">${fieldsTable}</div>
          <div id="editControls" style="display: none; margin-top: 10px;">
              <button class="secondary" onclick="saveDetailChanges()" style="background-color: #4CAF50; color: white;" title="保存修改">💾 保存</button>
              <button class="secondary" onclick="cancelEditDetail()" style="background-color: #f44336; color: white;" title="取消编辑">❌ 取消</button>
          </div>
      `;

  // 保存当前项目以供添加到购物车和保存使用
  window.currentDetailItem = JSON.parse(JSON.stringify(item)); // 深拷贝原始数据
  window.originalDetailItem = JSON.parse(JSON.stringify(item)); // 保存原始数据用于取消编辑

  // 显示模态框
  document.getElementById("detailModal").style.display = "block";
}

// 关闭详情模态框
function closeDetailModal() {
  document.getElementById("detailModal").style.display = "none";
}

// 从详情页面添加到购物车
function addToCartFromDetail() {
  if (window.currentDetailItem) {
    // 创建当前项目的副本以避免修改原始数据
    const currentItem = JSON.parse(
      JSON.stringify(window.currentDetailItem)
    );

    // 更新价格字段
    const showPriceInput = document.querySelector(
      '.detail-field-input[data-field="ShowPrice"]'
    );
    if (showPriceInput) {
      currentItem.ShowPrice = parseFloat(showPriceInput.value) || 0;
    }

    // 更新其他可能已修改的字段
    const detailInputs = document.querySelectorAll(".detail-field-input");
    detailInputs.forEach((input) => {
      const fieldName = input.getAttribute("data-field");
      if (typeof currentItem[fieldName] === "number") {
        currentItem[fieldName] = parseFloat(input.value) || 0;
      } else {
        currentItem[fieldName] = input.value;
      }
    });

    // 更新图片（如果用户更改了图片）
    const imgElement = document.getElementById("detailImage");
    if (imgElement) {
      currentItem.image = imgElement.src;
    }

    addToCart(currentItem);
  }
}

// 更换图片
function changeImage() {
  const input = document.createElement("input");
  input.type = "file";
  input.accept = "image/*";

  input.onchange = function (event) {
    const file = event.target.files[0];
    if (file) {
      const reader = new FileReader();
      reader.onload = function (e) {
        // 更新图片显示
        const imgElement = document.getElementById("detailImage");
        if (imgElement) {
          imgElement.src = e.target.result;

          // 更新当前项目的数据
          window.currentDetailItem.image = e.target.result;

          // 同时更新显示的详情价格，以防价格在输入框中被修改但未保存
          const showPriceInput = document.querySelector(
            '.detail-field-input[data-field="ShowPrice"]'
          );
          if (showPriceInput) {
            const currentPrice = parseFloat(showPriceInput.value) || 0;
            document.getElementById(
              "detailShowPriceDisplay"
            ).textContent = formatCurrency(currentPrice);
          }

          // 显示消息
          showMessage("图片已更新", "success");
        }
      };
      reader.readAsDataURL(file);
    }
  };

  input.click();
}

// 切换编辑模式
async function toggleEditDetail() {
  // 检查用户角色
  const userRole = await checkUserRole();
  if (userRole !== "admin") {
    alert("只有管理员才能编辑项目信息");
    return; // 非管理员不能编辑
  }

  const fieldsContainer = document.getElementById("fieldsContainer");
  const editControls = document.getElementById("editControls");
  const editButton = document.getElementById("editButton");

  if (editButton.textContent.includes("编辑")) {
    // 切换到编辑模式
    editFields();
    editButton.innerHTML = "💾 保存";
    editButton.onclick = async function () {
      await saveDetailChanges(); // saveDetailChanges函数内部会处理界面切换
    };
    editControls.style.display = "block";
  } else {
    // 切换回查看模式
    viewFields();
    editButton.innerHTML = "✏️ 编辑";
    editButton.onclick = toggleEditDetail;
    editControls.style.display = "none";
  }
}

// 进入编辑模式
function editFields() {
  for (const key in window.currentDetailItem) {
    if (window.currentDetailItem.hasOwnProperty(key) && key !== "image") {
      const fieldElement = document.getElementById(`detail-field-${key}`);
      if (fieldElement) {
        const currentValue = window.currentDetailItem[key];
        let inputField;
        if (typeof currentValue === "number") {
          if (key === "ShowPrice") {
            // Special handling for ShowPrice - update the display when changed
            inputField = `<input type="number" class="detail-field-input" data-field="${key}" value="${currentValue}" style="width: 100%; padding: 5px; border: 1px solid #ccc; border-radius: 3px;" onchange="updatePriceDisplay('${key}', this.value)">`;
          } else {
            inputField = `<input type="number" class="detail-field-input" data-field="${key}" value="${currentValue}" style="width: 100%; padding: 5px; border: 1px solid #ccc; border-radius: 3px;">`;
          }
        } else {
          inputField = `<input type="text" class="detail-field-input" data-field="${key}" value="${currentValue}" style="width: 100%; padding: 5px; border: 1px solid #ccc; border-radius: 3px;">`;
        }
        fieldElement.innerHTML = inputField;
      }
    }
  }
}

// 进入查看模式
function viewFields() {
  for (const key in window.currentDetailItem) {
    if (window.currentDetailItem.hasOwnProperty(key) && key !== "image") {
      const fieldElement = document.getElementById(`detail-field-${key}`);
      if (fieldElement) {
        const currentValue = window.currentDetailItem[key];
        fieldElement.innerHTML = currentValue;
      }
    }
  }
}

// 取消编辑并恢复原始值
function cancelEditDetail() {
  // 恢复原始数据
  window.currentDetailItem = JSON.parse(
    JSON.stringify(window.originalDetailItem)
  );

  // 切换回查看模式
  viewFields();

  const editButton = document.getElementById("editButton");
  editButton.innerHTML = "✏️ 编辑";
  editButton.onclick = toggleEditDetail;

  const editControls = document.getElementById("editControls");
  editControls.style.display = "none";
}

// 保存详情页的修改
async function saveDetailChanges() {
  // 检查用户角色
  const userRole = await checkUserRole();

  if (userRole !== "admin") {
    showMessage("只有管理员才能保存更改", "error");
    // 切换回查看模式
    viewFields();

    const editButton = document.getElementById("editButton");
    editButton.innerHTML = "✏️ 编辑";
    editButton.onclick = toggleEditDetail;

    const editControls = document.getElementById("editControls");
    editControls.style.display = "none";
    return;
  }

  if (!window.currentDetailItem) {
    showMessage("没有可保存的数据", "error");
    return;
  }

  // 获取当前显示的表单值并更新当前项目的值
  const currentModel = window.currentDetailItem.Model;

  // 检查是否有实际更改
  let hasChanges = false;
  const updatedItem = JSON.parse(
    JSON.stringify(window.currentDetailItem)
  );

  // 遍历所有详情字段，检查并更新当前项目的数据
  for (const key in updatedItem) {
    if (updatedItem.hasOwnProperty(key) && key !== "image") {
      const fieldElement = document.getElementById(`detail-field-${key}`);
      if (fieldElement && fieldElement.querySelector("input")) {
        const inputElement = fieldElement.querySelector("input");
        let newValue;

        if (typeof updatedItem[key] === "number") {
          newValue = parseFloat(inputElement.value) || 0;
        } else {
          newValue = inputElement.value;
        }

        // 检查值是否发生变化
        if (updatedItem[key] !== newValue) {
          hasChanges = true;
          updatedItem[key] = newValue;
        }
      }
    }
  }

  // 如果没有变化，不执行任何操作
  if (!hasChanges) {
    showMessage("没有检测到更改，无需保存", "info");
    // 切换回查看模式
    viewFields();

    const editButton = document.getElementById("editButton");
    editButton.innerHTML = "✏️ 编辑";
    editButton.onclick = toggleEditDetail;

    const editControls = document.getElementById("editControls");
    editControls.style.display = "none";
    return;
  }

  // 用更新后的数据替换当前项目
  window.currentDetailItem = updatedItem;

  // 向后端发送更新请求
  updateItemOnServer(updatedItem)
    .then((success) => {
      if (success) {
        // 在baseData中找到对应的项目并更新
        const baseDataIndex = baseData.findIndex(
          (item) => item.Model === currentModel
        );
        if (baseDataIndex !== -1) {
          baseData[baseDataIndex] = JSON.parse(
            JSON.stringify(window.currentDetailItem)
          );

          // 更新显示
          showItemDetail(window.currentDetailItem);

          showMessage("数据已保存", "success");
        } else {
          showMessage("无法找到对应的数据项", "error");
        }
      } else {
        showMessage("保存到服务器失败", "error");
      }
    })
    .catch((error) => {
      showMessage("保存到服务器时出错: " + error.message, "error");
    });
}

// 向服务器更新项目
async function updateItemOnServer(item) {
  try {
    // 从原始API客户端复制请求方法
    const response = await fetch(
      `/api/machines/${encodeURIComponent(item.Model)}`,
      {
        method: "PUT",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          ...item,
          action: "updateMachine", // 添加action参数
        }),
      }
    );

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const result = await response.json();
    return result.success === true;
  } catch (error) {
    console.error("更新项目到服务器失败:", error);
    throw error;
  }
}

// 更新价格显示
function updatePriceDisplay(fieldKey, newValue) {
  if (fieldKey === "ShowPrice") {
    const displayElement = document.getElementById(
      "detailShowPriceDisplay"
    );
    if (displayElement) {
      // 只有当输入的是有效数字时才更新显示
      const numericValue = parseFloat(newValue);
      if (!isNaN(numericValue)) {
        displayElement.textContent = formatCurrency(numericValue);
      }
    }
  }
}

// 添加其它费用
async function addTempFee() {
  const name = document.getElementById("tempFeeName").value;
  const amount =
    parseFloat(document.getElementById("tempFeeAmount").value) || 0;

  if (!name) {
    alert("请输入费用名称");
    return;
  }

  const tempFee = {
    id: Date.now(),
    displayType: "费用", // 用于显示的类型
    name: name,
    baseAmount: amount, // 原始金额
    actualAmount: amount, // 实际金额，默认等于原始金额
    type: "fees", // 标记为费用类型
  };

  tempItems.push(tempFee);

  // 记录用户创建的费用（在服务器端记录）
  try {
    // 创建一个费用记录对象并发送到服务器
    const newFee = {
      name: name,
      amount: amount,
      addedCount: 1, // 初始添加次数为1
      action: "createTempFee", // 操作类型
    };

    const response = await apiClient.createTempFee(newFee);
    if (response.success) {
      // 更新本地费用数据缓存
      if (window.feesData) {
        // 检查是否已存在同名费用，如果存在则更新，否则添加
        const existingIndex = window.feesData.findIndex(
          (f) => f.name === name
        );
        if (existingIndex !== -1) {
          window.feesData[existingIndex] = {
            ...newFee,
            ...response.data,
          };
        } else {
          window.feesData.push({ ...newFee, ...response.data });
        }
      }

      // 更新本地时间戳缓存
      if (response.timestamp) {
        localStorage.setItem(
          "lastFeesTimestamp",
          response.timestamp.toString()
        );

        // 基于完整费用数据重新计算topused费用（按addedCount排序取前5个）
        if (window.feesData && Array.isArray(window.feesData)) {
          cachedTopFees = [...window.feesData]
            .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
            .slice(0, 5); // 取前5个最常用的费用

          // 更新localStorage中的缓存
          localStorage.setItem(
            "cachedTopUsedFees",
            JSON.stringify(cachedTopFees)
          );
        }
      }

      showMessage("费用已添加到服务器", "success");
    } else {
      showMessage(
        "费用添加失败: " + (response.error || "未知错误"),
        "error"
      );
    }
  } catch (error) {
    console.error("添加费用到服务器失败:", error);
    showMessage("添加费用失败: " + error.message, "error");
  }

  renderTempItems();
  updateTotal();

  // 清空输入框
  document.getElementById("tempFeeName").value = "";
  document.getElementById("tempFeeAmount").value = "";
}

// 添加系数
async function addTempFactor() {
  const name = document.getElementById("tempFactorName").value;
  const value =
    parseFloat(document.getElementById("tempFactorValue").value) || 1;

  if (!name) {
    alert("请输入系数名称");
    return;
  }

  const tempFactor = {
    id: Date.now(),
    displayType: "系数", // 用于显示的类型
    name: name,
    value: value,
    type: "factors", // 标记为系数类型
  };

  tempItems.push(tempFactor);

  // 记录用户创建的系数（在服务器端记录）
  try {
    const newFactor = {
      name: name,
      value: value,
      addedCount: 1, // 初始添加次数为1
      action: "createTempFactor", // 操作类型
    };

    const response = await apiClient.createTempFactor(newFactor);
    if (response.success) {
      // 更新本地系数数据缓存
      if (window.factorsData) {
        // 检查是否已存在同名系数，如果存在则更新，否则添加
        const existingIndex = window.factorsData.findIndex(
          (f) => f.name === name
        );
        if (existingIndex !== -1) {
          window.factorsData[existingIndex] = {
            ...newFactor,
            ...response.data,
          };
        } else {
          window.factorsData.push({ ...newFactor, ...response.data });
        }
      }

      // 更新本地时间戳缓存
      if (response.timestamp) {
        localStorage.setItem(
          "lastFactorsTimestamp",
          response.timestamp.toString()
        );

        // 基于完整系数数据重新计算topused系数（按addedCount排序取前5个）
        if (window.factorsData && Array.isArray(window.factorsData)) {
          cachedTopFactors = [...window.factorsData]
            .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
            .slice(0, 5); // 取前5个最常用的系数

          // 更新localStorage中的缓存
          localStorage.setItem(
            "cachedTopUsedFactors",
            JSON.stringify(cachedTopFactors)
          );
        }
      }

      showMessage("系数已添加到服务器", "success");
    } else {
      showMessage(
        "系数添加失败: " + (response.error || "未知错误"),
        "error"
      );
    }
  } catch (error) {
    console.error("添加系数到服务器失败:", error);
    showMessage("添加系数失败: " + error.message, "error");
  }

  renderTempItems();
  updateTotal();

  // 清空输入框
  document.getElementById("tempFactorName").value = "";
  document.getElementById("tempFactorValue").value = "";
}

// 渲染临时项目列表
function renderTempItems() {
  const tbody = document.getElementById("tempItemsBody");
  tbody.innerHTML = "";

  if (tempItems.length === 0) {
    tbody.innerHTML =
      '<tr><td colspan="4" style="text-align: center;">暂无临时项目</td></tr>';
    return;
  }

  tempItems.forEach((item, index) => {
    const row = document.createElement("tr");

    if (item.type === "费用") {
      row.innerHTML = `
                  <td>${item.type}</td>
                  <td>${item.name}</td>
                  <td>
                      <input type="number"
                             value="${item.actualAmount}"
                             onchange="updateTempFee(${index}, this.value)"
                             min="0"
                             step="0.01">
                  </td>
                  <td>
                      <button class="danger" onclick="removeTempItem(${index})">删除</button>
                  </td>
              `;
    } else {
      // 系数
      row.innerHTML = `
                  <td>${item.type}</td>
                  <td>${item.name}</td>
                  <td>
                      <input type="number"
                             value="${item.value}"
                             onchange="updateTempFactor(${index}, this.value)"
                             min="0"
                             step="0.01">
                  </td>
                  <td>
                      <button class="danger" onclick="removeTempItem(${index})">删除</button>
                  </td>
              `;
    }

    tbody.appendChild(row);
  });
}

// 更新其它费用
function updateTempFee(index, value) {
  tempItems[index].actualAmount = parseFloat(value) || 0;
  updateTotal();
}

// 更新系数
function updateTempFactor(index, value) {
  tempItems[index].value = parseFloat(value) || 1;
  updateTotal();
}

// 删除临时项目
function removeTempItem(index) {
  if (confirm("确定要删除这个临时项目吗？")) {
    tempItems.splice(index, 1);
    renderTempItems();
    updateTotal();
  }
}

// 更新汇总表中的项目价格
function updateSummaryItemPrice(index, type, value) {
  const parsedValue = parseFloat(value);
  if (isNaN(parsedValue) || parsedValue < 0) {
    alert("请输入有效的金额");
    updateTotal(); // 重新计算以恢复之前的值
    return;
  }

  if (type === "selected") {
    // 修改选中项目的价格
    selectedItems[index].actualPrice = parsedValue;
  } else if (type === "fee") {
    // 修改其它费用的实际金额
    tempItems[index].actualAmount = parsedValue;
  } else if (type === "factor") {
    // 修改系数
    tempItems[index].value = parsedValue;
  }

  updateTotal();
}

// 更新汇总表中的项目数量
function updateSummaryItemQuantity(index, type, value) {
  if (type !== "selected") {
    return; // 只有选中的项目才有数量
  }

  const parsedValue = parseInt(value);
  if (isNaN(parsedValue) || parsedValue < 1) {
    alert("请输入有效的数量（至少为1）");
    updateTotal(); // 重新计算以恢复之前的值
    return;
  }

  selectedItems[index].quantity = parsedValue;
  updateTotal();
}

// 从汇总表中删除项目
function removeSummaryItem(index, type) {
  if (confirm("确定要删除这个项目吗？")) {
    if (type === "selected") {
      selectedItems.splice(index, 1);
    } else if (type === "temp") {
      tempItems.splice(index, 1);
    }

    renderSelectedItems();
    renderTempItems();
    updateTotal();
  }
}

// 计算总价
function updateTotal() {
  // 计算基础项目总价（考虑数量）
  let baseTotal = selectedItems.reduce(
    (sum, item) => sum + item.actualPrice * item.quantity,
    0
  );

  // 计算其它费用
  let tempFees = 0;
  tempItems.forEach((item) => {
    if (item.type === "费用") {
      tempFees += item.actualAmount; // 使用实际金额而不是原始金额
    }
  });

  // 计算系数
  let factor = 1;
  tempItems.forEach((item) => {
    if (item.type === "系数") {
      factor *= item.value;
    }
  });

  // 最终总价 = (基础总价 + 其它费用) * 系数
  const total = (baseTotal + tempFees) * factor;

  document.getElementById("totalAmount").textContent =
    formatCurrency(total);

  // 更新详细项目列表
  renderDetailedSummary(baseTotal, tempFees, factor);
}

// 渲染详细项目列表
function renderDetailedSummary(baseTotal, tempFees, factor) {
  const summaryTableBody = document.getElementById("summaryTableBody");
  summaryTableBody.innerHTML = "";

  let itemIndex = 1;

  // 添加选中的项目
  selectedItems.forEach((item) => {
    const row = document.createElement("tr");

    // 计算小计
    const subtotal = item.actualPrice * item.quantity;

    row.innerHTML = `
              <td style="border: 1px solid #ddd; padding: 10px;">${itemIndex}</td>
              <td style="border: 1px solid #ddd; padding: 10px;">${
                item.type
              } - ${item.model} (${item.name})</td>
              <td style="border: 1px solid #ddd; padding: 10px;">
                  <input type="number"
                         value="${item.quantity}"
                         onchange="updateSummaryItemQuantity(${selectedItems.indexOf(
                           item
                         )}, 'selected', this.value)"
                         min="1"
                         step="1"
                         style="width: 100%; padding: 5px; border: 1px solid #ccc; border-radius: 3px;">
              </td>
              <td style="border: 1px solid #ddd; padding: 10px;">${formatCurrency(
                item.basePrice
              )}</td>
              <td style="border: 1px solid #ddd; padding: 10px;">
                  <input type="number"
                         value="${item.actualPrice}"
                         onchange="updateSummaryItemPrice(${selectedItems.indexOf(
                           item
                         )}, 'selected', this.value)"
                         min="0"
                         step="0.01"
                         style="width: 100%; padding: 5px; border: 1px solid #ccc; border-radius: 3px;">
              </td>
              <td style="border: 1px solid #ddd; padding: 10px;">${formatCurrency(
                subtotal
              )}</td>
              <td style="border: 1px solid #ddd; padding: 10px;">
                  <button class="danger" onclick="removeSummaryItem(${selectedItems.indexOf(
                    item
                  )}, 'selected')">删除</button>
              </td>
          `;

    summaryTableBody.appendChild(row);
    itemIndex++;
  });

  // 添加其它费用
  tempItems
    .filter((item) => item.displayType === "费用")
    .forEach((item) => {
      const row = document.createElement("tr");

      row.innerHTML = `
              <td style="border: 1px solid #ddd; padding: 10px;">${itemIndex}</td>
              <td style="border: 1px solid #ddd; padding: 10px;">其它费用 - ${
                item.name
              }</td>
              <td style="border: 1px solid #ddd; padding: 10px;">-</td>
              <td style="border: 1px solid #ddd; padding: 10px;">${formatCurrency(
                item.baseAmount
              )}</td>
              <td style="border: 1px solid #ddd; padding: 10px;">
                  <input type="number"
                         value="${item.actualAmount}"
                         onchange="updateSummaryItemPrice(${tempItems.indexOf(
                           item
                         )}, 'fee', this.value)"
                         min="0"
                         step="0.01"
                         style="width: 100%; padding: 5px; border: 1px solid #ccc; border-radius: 3px;">
              </td>
              <td style="border: 1px solid #ddd; padding: 10px;">${formatCurrency(
                item.actualAmount
              )}</td>
              <td style="border: 1px solid #ddd; padding: 10px;">
                  <button class="danger" onclick="removeSummaryItem(${tempItems.indexOf(
                    item
                  )}, 'temp')">删除</button>
              </td>
          `;

      summaryTableBody.appendChild(row);
      itemIndex++;
    });

  // 添加系数
  tempItems
    .filter((item) => item.displayType === "系数")
    .forEach((item) => {
      const row = document.createElement("tr");

      row.innerHTML = `
              <td style="border: 1px solid #ddd; padding: 10px;">${itemIndex}</td>
              <td style="border: 1px solid #ddd; padding: 10px;">系数 - ${
                item.name
              }</td>
              <td style="border: 1px solid #ddd; padding: 10px;">-</td>
              <td style="border: 1px solid #ddd; padding: 10px;">x ${
                item.value
              }</td>
              <td style="border: 1px solid #ddd; padding: 10px;">
                  <input type="number"
                         value="${item.value}"
                         onchange="updateSummaryItemPrice(${tempItems.indexOf(
                           item
                         )}, 'factor', this.value)"
                         min="0"
                         step="0.01"
                         style="width: 100%; padding: 5px; border: 1px solid #ccc; border-radius: 3px;">
              </td>
              <td style="border: 1px solid #ddd; padding: 10px;">x ${
                item.value
              }</td>
              <td style="border: 1px solid #ddd; padding: 10px;">
                  <button class="danger" onclick="removeSummaryItem(${tempItems.indexOf(
                    item
                  )}, 'temp')">删除</button>
              </td>
          `;

      summaryTableBody.appendChild(row);
      itemIndex++;
    });

  // 如果没有项目，显示提示
  if (selectedItems.length === 0 && tempItems.length === 0) {
    const row = document.createElement("tr");
    row.innerHTML = `<td colspan="7" style="border: 1px solid #ddd; padding: 10px; text-align: center;">暂无项目</td>`;
    summaryTableBody.appendChild(row);
  }
}

// 渲染已选择的项目列表
function renderSelectedItems() {
  const tbody = document.getElementById("selectedItemsBody");
  tbody.innerHTML = "";

  if (selectedItems.length === 0) {
    tbody.innerHTML =
      '<tr><td colspan="6" style="text-align: center;">暂无已选择的项目</td></tr>';
    return;
  }

  selectedItems.forEach((item, index) => {
    const row = document.createElement("tr");

    row.innerHTML = `
              <td>${item.type}</td>
              <td>${item.model} (${item.name})</td>
              <td>${item.quantity}</td>
              <td>${formatCurrency(item.basePrice)}</td>
              <td>
                  <input type="number"
                         value="${item.actualPrice}"
                         onchange="updateActualPrice(${index}, this.value)"
                         min="0"
                         step="0.01">
              </td>
              <td>
                  <button class="danger" onclick="removeSelectedItem(${index})">删除</button>
              </td>
          `;

    tbody.appendChild(row);
  });
}

// 更新实际价格
function updateActualPrice(index, value) {
  selectedItems[index].actualPrice = parseFloat(value) || 0;
  updateTotal();
}

// 删除已选择的项目
function removeSelectedItem(index) {
  if (confirm("确定要删除这个项目吗？")) {
    selectedItems.splice(index, 1);
    renderSelectedItems();
    updateTotal();
  }
}

// 修改选中项目
function modifySelectedItem(index) {
  const item = selectedItems[index];
  const newPrice = prompt(
    `修改 ${item.name}(${item.model}) 的价格:`,
    item.actualPrice
  );
  if (newPrice !== null) {
    const parsedPrice = parseFloat(newPrice);
    if (!isNaN(parsedPrice) && parsedPrice >= 0) {
      selectedItems[index].actualPrice = parsedPrice;
      renderSelectedItems();
      updateTotal();
    } else {
      alert("请输入有效的价格");
    }
  }
}

// 修改其它费用
function modifyTempFee(index) {
  const item = tempItems[index];
  const newAmount = prompt(
    `修改 ${item.name} 的金额:`,
    item.actualAmount
  );
  if (newAmount !== null) {
    const parsedAmount = parseFloat(newAmount);
    if (!isNaN(parsedAmount) && parsedAmount >= 0) {
      tempItems[index].actualAmount = parsedAmount;
      renderTempItems();
      updateTotal();
    } else {
      alert("请输入有效的金额");
    }
  }
}

// 修改临时系数
function modifyTempFactor(index) {
  const item = tempItems[index];
  const newValue = prompt(`修改 ${item.name} 的系数:`, item.value);
  if (newValue !== null) {
    const parsedValue = parseFloat(newValue);
    if (!isNaN(parsedValue) && parsedValue >= 0) {
      tempItems[index].value = parsedValue;
      renderTempItems();
      updateTotal();
    } else {
      alert("请输入有效的系数");
    }
  }
}

// 预加载最常用的项目（在页面初始化时） - 已合并到loadData中以避免重复请求
async function preloadTopUsedItems() {
  // 此函数保留用于兼容性，但实际功能已在loadData函数中实现
  // 以避免重复请求数据
  console.log("preloadTopUsedItems: 已合并到loadData中，避免重复请求");
}

// 重新计算并显示最常用的项目
async function showTopUsedItems(type) {
  let topItems = [];

  // 每次都基于当前缓存数据重新计算，不再使用已缓存的topUsed数据
  try {
    if (
      type === "parts" &&
      window.partsData &&
      Array.isArray(window.partsData)
    ) {
      // 基于当前parts数据按addedCount排序，取前5个
      topItems = [...window.partsData]
        .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
        .slice(0, 5);
    } else if (
      type === "fees" &&
      window.feesData &&
      Array.isArray(window.feesData)
    ) {
      // 基于当前fees数据按addedCount排序，取前5个
      topItems = [...window.feesData]
        .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
        .slice(0, 5);
    } else if (
      type === "factors" &&
      window.factorsData &&
      Array.isArray(window.factorsData)
    ) {
      // 基于当前factors数据按addedCount排序，取前5个
      topItems = [...window.factorsData]
        .sort((a, b) => (b.addedCount || 0) - (a.addedCount || 0))
        .slice(0, 5);
    } else {
      // 如果没有对应的数据，尝试从服务器获取
      if (type === "parts") {
        topItems = await apiClient.getTopUsedParts();
      } else if (type === "fees") {
        topItems = await apiClient.getTopUsedFees();
      } else if (type === "factors") {
        topItems = await apiClient.getTopUsedFactors();
      }
    }
  } catch (error) {
    console.error(`获取最常用${type}失败:`, error);
    // 如果计算失败，返回空数组
    topItems = [];
  }

  // 根据类型显示在不同的容器中
  let container;
  if (type === "parts") {
    container = document.getElementById("topUsedItems");
  } else if (type === "fees") {
    container = document.getElementById("topUsedFeesContainer");
  } else if (type === "factors") {
    container = document.getElementById("topUsedFactorsContainer");
  } else {
    container = document.getElementById("topUsedItems");
  }

  if (topItems.length === 0) {
    container.innerHTML = "<p>暂无常用项目</p>";
    return;
  }

  // 生成常用项目HTML - 使用原来的按钮样式，按使用次数排序，不显示次数
  let html = '<div style="margin-bottom: 10px;">';
  topItems.forEach((item) => {
    html += `
              <button type="button" class="secondary"
                   onclick="${
                     type === "parts"
                       ? "fillPartForm"
                       : type === "fees"
                       ? "fillTempFeeForm"
                       : "fillTempFactorForm"
                   }(${JSON.stringify(item).replace(/"/g, "&quot;")})"
                   style="background-color: ${
                     type === "parts"
                       ? "#2196F3"
                       : type === "fees"
                       ? "#4CAF50"
                       : "#FF9800"
                   }; color: white; margin-right: 5px; margin-bottom: 5px;"
                   title="${item.name || item.model}">
                  ${item.name || item.model}
              </button>
          `;
  });
  html += "</div>";

  container.innerHTML = html;
}

// 部件搜索输入处理
function partSearchInput(searchTerm) {
  // 从localStorage获取所有部件数据进行搜索
  let allParts = [];

  // 从localStorage获取完整部件数据
  const cachedPartsData = localStorage.getItem("cachedParts");
  if (cachedPartsData) {
    try {
      allParts = JSON.parse(cachedPartsData);
    } catch (e) {
      console.error("解析cachedParts失败:", e);
      allParts = [];
    }
  }

  const resultsContainer = document.getElementById("partSearchResults");
  if (!searchTerm.trim()) {
    // 如果搜索词为空，显示空内容但保持容器可见
    resultsContainer.innerHTML = "";
    return;
  }

  // 搜索model字段（主要字段）
  const filteredParts = allParts.filter(
    (part) =>
      part.model &&
      part.model.toLowerCase().includes(searchTerm.toLowerCase())
  );

  if (filteredParts.length === 0) {
    resultsContainer.innerHTML =
      '<span style="color: #999; font-size: 0.9em;">未找到匹配的部件</span>';
    return;
  }

  let html =
    '<div style="display: flex; flex-wrap: nowrap; overflow-x: auto; gap: 5px; padding: 2px 0;">';
  filteredParts.forEach((part) => {
    html += `
              <button type="button" class="secondary"
                   onclick="fillPartForm(${JSON.stringify(part).replace(
                     /"/g,
                     "&quot;"
                   )})"
                   style="background-color: #FF9800; color: white; margin-right: 5px; margin-bottom: 5px; white-space: nowrap;"
                   title="${part.model}">
                  ${part.model}
              </button>
          `;
  });
  html += "</div>";

  resultsContainer.innerHTML = html;
}

// 填充部件表单
function fillPartForm(part) {
  document.getElementById("partModel").value = part.model || "";
  document.getElementById("partPrice").value = part.price || "";

  // 保留搜索框的内容，这样用户可以继续搜索或从结果中选择其他项目
  // 搜索结果仍然可见，用户可以继续交互
}

// 其它费用搜索输入处理
function tempFeeSearchInput(searchTerm) {
  // 搜索所有可用的费用（从缓存）
  let allFees = [];

  // 优先使用完整的费用数据，如果不存在则使用topFees
  if (window.feesData && window.feesData.length > 0) {
    allFees = [...window.feesData];
  } else if (cachedTopFees && cachedTopFees.length > 0) {
    allFees = [...cachedTopFees];
  }

  const resultsContainer = document.getElementById(
    "tempFeeSearchResults"
  );
  if (!searchTerm.trim()) {
    // 如果搜索词为空，显示空内容但保持容器可见
    resultsContainer.innerHTML = "";
    return;
  }

  const filteredFees = allFees.filter(
    (fee) =>
      fee.name &&
      fee.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  if (filteredFees.length === 0) {
    resultsContainer.innerHTML =
      '<span style="color: #999; font-size: 0.9em;">未找到匹配的费用</span>';
    return;
  }

  let html =
    '<div style="display: flex; flex-wrap: nowrap; overflow-x: auto; gap: 5px; padding: 2px 0;">';
  filteredFees.forEach((fee) => {
    html += `
              <button type="button" class="secondary"
                   onclick="fillTempFeeForm(${JSON.stringify(fee).replace(
                     /"/g,
                     "&quot;"
                   )})"
                   style="background-color: #4CAF50; color: white; margin-right: 5px; margin-bottom: 5px; white-space: nowrap;"
                   title="${fee.name}">
                  ${fee.name}
              </button>
          `;
  });
  html += "</div>";

  resultsContainer.innerHTML = html;
}

// 填充其它费用表单
function fillTempFeeForm(fee) {
  document.getElementById("tempFeeNameCart").value = fee.name || "";
  document.getElementById("tempFeeAmountCart").value = fee.value || "";

  // 保留搜索框的内容，这样用户可以继续搜索或从结果中选择其他项目
  // 搜索结果仍然可见，用户可以继续交互
}

// 系数搜索输入处理
function tempFactorSearchInput(searchTerm) {
  // 搜索所有可用的系数（从缓存）
  let allFactors = [];

  // 优先使用完整的系数数据，如果不存在则使用topFactors
  if (window.factorsData && window.factorsData.length > 0) {
    allFactors = [...window.factorsData];
  } else if (cachedTopFactors && cachedTopFactors.length > 0) {
    allFactors = [...cachedTopFactors];
  }

  const resultsContainer = document.getElementById(
    "tempFactorSearchResults"
  );
  if (!searchTerm.trim()) {
    // 如果搜索词为空，显示空内容但保持容器可见
    resultsContainer.innerHTML = "";
    return;
  }

  const filteredFactors = allFactors.filter(
    (factor) =>
      factor.name &&
      factor.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  if (filteredFactors.length === 0) {
    resultsContainer.innerHTML =
      '<span style="color: #999; font-size: 0.9em;">未找到匹配的系数</span>';
    return;
  }

  let html =
    '<div style="display: flex; flex-wrap: nowrap; overflow-x: auto; gap: 5px; padding: 2px 0;">';
  filteredFactors.forEach((factor) => {
    html += `
              <button type="button" class="secondary"
                   onclick="fillTempFactorForm(${JSON.stringify(
                     factor
                   ).replace(/"/g, "&quot;")})"
                   style="background-color: #2196F3; color: white; margin-right: 5px; margin-bottom: 5px; white-space: nowrap;"
                   title="${factor.name}">
                  ${factor.name}
              </button>
          `;
  });
  html += "</div>";

  resultsContainer.innerHTML = html;
}

// 填充系数表单
function fillTempFactorForm(factor) {
  document.getElementById("tempFactorNameCart").value = factor.name || "";
  document.getElementById("tempFactorValueCart").value =
    factor.value || "";

  // 保留搜索框的内容，这样用户可以继续搜索或从结果中选择其他项目
  // 搜索结果仍然可见，用户可以继续交互
}

// 本地搜索功能
function localSearch(type, searchTerm) {
  let allItems = [];

  // 根据类型获取所有项目（优先使用完整数据，其次使用top数据）
  if (type === "parts" && window.partsData) {
    allItems = [...window.partsData];
  } else if (type === "parts" && cachedTopParts) {
    allItems = [...cachedTopParts];
  } else if (type === "fees" && window.feesData) {
    allItems = [...window.feesData];
  } else if (type === "fees" && cachedTopFees) {
    allItems = [...cachedTopFees];
  } else if (type === "factors" && window.factorsData) {
    allItems = [...window.factorsData];
  } else if (type === "factors" && cachedTopFactors) {
    allItems = [...cachedTopFactors];
  }

  const resultsContainer = document.querySelector("#topUsedItems");
  if (!searchTerm.trim()) {
    // 如果搜索词为空，重新显示常用项目
    showTopUsedItems(type);
    return;
  }

  const filteredItems = allItems.filter(
    (item) =>
      (item.name &&
        item.name.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (item.model &&
        item.model.toLowerCase().includes(searchTerm.toLowerCase()))
  );

  if (filteredItems.length === 0) {
    resultsContainer.innerHTML = "<p>未找到匹配的项目</p>";
    return;
  }

  let html = `<h3>搜索结果 (${filteredItems.length} 项):</h3>`;
  filteredItems.forEach((item) => {
    html += `
              <div class="top-item" style="padding: 8px; border: 1px solid #ddd; border-radius: 4px; margin-bottom: 8px; background-color: #f9f9f9; cursor: pointer;"
                   onclick="fillItemForm(${JSON.stringify(item).replace(
                     /"/g,
                     "&quot;"
                   )}, '${type}')">
                  <div><strong>${item.name || item.model}</strong></div>
                  <div style="font-size: 0.8em; color: #666;">被添加次数: ${
                    item.addedCount || item.useCount || 1
                  }</div>
                  ${
                    type === "parts"
                      ? `<div style="font-size: 0.8em; color: #888;">价格: ${
                          item.price || 0
                        }</div>`
                      : ""
                  }
              </div>
          `;
  });

  // 添加搜索框
  html += `
          <div class="form-group" style="margin-top: 15px;">
              <label for="localSearchInput">本地搜索:</label>
              <input type="text" id="localSearchInput" placeholder="搜索本地项目..." oninput="localSearch('${type}', this.value)" value="${searchTerm}">
          </div>
      `;

  resultsContainer.innerHTML = html;
}

// 填充项目表单
function fillItemForm(item, type) {
  if (type === "parts") {
    document.getElementById("partModel").value = item.model || item.name;
    document.getElementById("partPrice").value = item.price || "";
  } else if (type === "fees") {
    document.getElementById("tempFeeNameCart").value =
      item.Model || item.name;
    document.getElementById("tempFeeAmountCart").value =
      item.ShowPrice || item.price || "";
    showTempFeeForm();
  } else if (type === "factors") {
    document.getElementById("tempFactorNameCart").value =
      item.Model || item.name;
    document.getElementById("tempFactorValueCart").value =
      item.ShowPrice || item.value || "";
    showTempFactorForm();
  }
}