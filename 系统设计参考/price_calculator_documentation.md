# Flutter价格计算器模块开发文档

## 1. 项目概述

本项目是将现有的HTML价格计算器转换为Flutter页面，实现机器及零部件的价格计算、购物车管理和报价单生成功能。

## 2. 数据模型设计

### 2.1 MachinePart (机器部件基础数据模型)
```dart
class MachinePart {
  final String model;             // 型号 (必填) - 对应JSON中的"Model"
  final String originalModel;     // 原型号 (必填) - 对应JSON中的"OriginalModel" 
  final double originalPrice;     // 原价格 (必填) - 对应JSON中的"OriginalPrice"
  final double showPrice;         // 显示价格 (必填) - 对应JSON中的"ShowPrice"
  final String image;             // 图片URL (必填) - 对应JSON中的"image"
  final int addedCount;           // 被添加次数 (默认0) - 对应JSON中的"addedCount"
  final Map<String, String> otherProperties; // 其他属性，以字符串形式保存
  final DateTime createdAt;       // 创建时间 (必填)
  final DateTime updatedAt;       // 最后修改时间 (必填)
  final String createdBy;         // 创建人 (必填)
  final String updatedBy;         // 最后修改人 (必填)
  
  MachinePart({
    required this.model,
    required this.originalModel,
    required this.originalPrice,
    required this.showPrice,
    required this.image,
    this.addedCount = 0,
    required this.otherProperties,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });
  
  factory MachinePart.fromJson(Map<String, dynamic> json) {
    // 提取通用属性
    String model = json['Model']?.toString() ?? '';
    String originalModel = json['OriginalModel']?.toString() ?? '';
    double originalPrice = (json['OriginalPrice'] as num?)?.toDouble() ?? 0.0;
    double showPrice = (json['ShowPrice'] as num?)?.toDouble() ?? 0.0;
    String image = json['image']?.toString() ?? '';
    int addedCount = json['addedCount']?.toInt() ?? 0;
    
    // 提取审计字段
    DateTime createdAt = DateTime.parse(json['createdAt']?.toString() ?? DateTime.now().toIso8601String());
    DateTime updatedAt = DateTime.parse(json['updatedAt']?.toString() ?? DateTime.now().toIso8601String());
    String createdBy = json['createdBy']?.toString() ?? 'system';
    String updatedBy = json['updatedBy']?.toString() ?? 'system';
    
    // 提取其他所有属性并转换为字符串
    Map<String, String> otherProperties = {};
    json.forEach((key, value) {
      if (key != 'Model' && 
          key != 'OriginalModel' && 
          key != 'OriginalPrice' && 
          key != 'ShowPrice' && 
          key != 'image' && 
          key != 'addedCount' &&
          key != 'createdAt' &&
          key != 'updatedAt' &&
          key != 'createdBy' &&
          key != 'updatedBy') {
        otherProperties[key] = value?.toString() ?? '';
      }
    });
    
    return MachinePart(
      model: model,
      originalModel: originalModel,
      originalPrice: originalPrice,
      showPrice: showPrice,
      image: image,
      addedCount: addedCount,
      otherProperties: otherProperties,
      createdAt: createdAt,
      updatedAt: updatedAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
    );
  }
  
  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'Model': model,
      'OriginalModel': originalModel,
      'OriginalPrice': originalPrice,
      'ShowPrice': showPrice,
      'image': image,
      'addedCount': addedCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
    
    // 添加其他属性
    otherProperties.forEach((key, value) {
      json[key] = value;
    });
    
    return json;
  }
  
  // 用于更新记录的方法
  MachinePart copyWith({
    String? model,
    String? originalModel,
    double? originalPrice,
    double? showPrice,
    String? image,
    int? addedCount,
    Map<String, String>? otherProperties,
    DateTime? updatedAt,
    String? updatedBy,
  }) {
    return MachinePart(
      model: model ?? this.model,
      originalModel: originalModel ?? this.originalModel,
      originalPrice: originalPrice ?? this.originalPrice,
      showPrice: showPrice ?? this.showPrice,
      image: image ?? this.image,
      addedCount: addedCount ?? this.addedCount,
      otherProperties: otherProperties ?? this.otherProperties,
      createdAt: this.createdAt, // 保持创建时间不变
      updatedAt: updatedAt ?? DateTime.now(), // 更新为当前时间
      createdBy: this.createdBy, // 保持创建人不变
      updatedBy: updatedBy ?? this.updatedBy, // 更新修改人
    );
  }
}
```

### 2.2 CartItem (购物车项目模型)
```dart
class CartItem {
  final String id;              // 唯一ID (必填)
  final String type;            // 类型 ('机器', '部件') (必填)
  final String model;           // 模型 (必填)
  final String name;            // 名称 (必填)
  final double basePrice;       // 基础价格 (必填)
  final double actualPrice;     // 实际价格 (必填)
  final int quantity;           // 数量 (默认1)
  final String image;           // 图片URL (必填)
}
```

### 2.3 Part (用户添加的部件模型)
```dart
class Part {
  final String id;              // 唯一ID (必填)
  final String model;           // 部件型号 (必填)
  final String name;            // 部件名称 (必填)
  final double defaultPrice;    // 默认价格 (必填)
  final int usageCount;         // 使用次数 (默认0，用于显示热门部件)

  Part({
    required this.id,
    required this.model,
    required this.name,
    required this.defaultPrice,
    this.usageCount = 0,
  });
}
```

### 2.4 TempFee (临时费用模型)
```dart
class TempFee {
  final String id;              // 唯一ID (必填)
  final String name;            // 费用名称 (必填，如"包装费", "海运费", "陆运费")
  final double defaultAmount;   // 默认金额 (必填)
  final int usageCount;         // 使用次数 (默认0，用于显示热门费用)

  TempFee({
    required this.id,
    required this.name,
    required this.defaultAmount,
    this.usageCount = 0,
  });
}
```

### 2.5 TempFactor (临时系数模型)
```dart
class TempFactor {
  final String id;              // 唯一ID (必填)
  final String name;            // 系数名称 (必填，如"利润率", "税率", "预留点数")
  final double defaultValue;    // 默认系数值 (必填)
  final int usageCount;         // 使用次数 (默认0，用于显示热门系数)

  TempFactor({
    required this.id,
    required this.name,
    required this.defaultValue,
    this.usageCount = 0,
  });
}
```



## 3. 数据持久化要求

- **MachinePart**：**需要持久化存储**，从您提供的JSON文件导入数据，通用属性保留，其他参数以字符串形式保存，包含完整的审计字段
- **Part/TempFee/TempFactor**：需要持久化存储（使用Hive）
- **使用次数统计**：需要持久化以显示热门项目



## 5. JSON数据处理

### 5.1 必需的通用属性
- `Model` (型号)
- `OriginalModel` (原型号) 
- `OriginalPrice` (原价格)
- `ShowPrice` (显示价格)
- `image` (图片路径)
- `addedCount` (被添加次数)





### 5.3 其他属性处理
- 将JSON中除通用属性和审计字段外的所有属性存储到`otherProperties` Map中
- 所有属性值转换为字符串形式存储
- 保持原始JSON结构的完整性

### 5.4 数据导入功能
- 程序设计一个标准的数据库结构（使用Hive）
- 提供数据导入功能，可以从您提供的外部JSON文件导入数据
- 导入时自动为MachinePart设置审计字段（创建时间、创建人等）
- 导入后数据完全存储在应用的数据库中，后续所有操作都在数据库中进行
- JSON文件仅作为初始数据源，导入后可删除或存档

## 6. 搜索优化

### 6.1 Model和OriginalModel搜索优化
- **索引优化**：在Hive中为`model`和`originalModel`字段创建索引
- **模糊搜索**：实现不区分大小写的模糊搜索
- **性能优化**：使用内存缓存机制提升搜索性能
- **搜索建议**：基于历史搜索记录提供智能建议

### 6.2 搜索实现建议
```dart
// 搜索方法示例
List<MachinePart> searchItems(String searchTerm) {
  // 转换为小写进行比较
  String lowerSearchTerm = searchTerm.toLowerCase();
  
  return _baseData.where((item) =>
      item.model.toLowerCase().contains(lowerSearchTerm) ||
      item.originalModel.toLowerCase().contains(lowerSearchTerm) ||
      item.otherProperties.values.any((value) => 
        value.toLowerCase().contains(lowerSearchTerm))
  ).toList();
}
```

### 6.3 搜索性能优化
- 预先建立`model`和`originalModel`的搜索索引
- 使用内存缓存减少数据库查询次数
- 对于大量数据，考虑使用分页加载

## 7. 其他功能要求

### 7.1 搜索功能
- **功能描述**：按型号或名称搜索机器部件
- **实现要求**：
  - 实时搜索（输入时即搜索）
  - 支持新型号和原型号搜索
  - 当搜索框为空时，显示热门商品（被添加次数最多的前5个）
  - 搜索结果以列表形式显示，包含图片、型号、价格
  - 搜索性能优化，确保响应速度
### 7.2 购物车功能
- **功能描述**：管理选中的项目
- **实现要求**：
  - 添加商品到购物车（如果已存在则增加数量）
  - 修改商品数量和价格
  - 删除购物车项目
  - 显示购物车总数（所有商品数量之和）
  - 悬浮购物车按钮显示购物车项目总数
### 7.3 临时项目管理
- **功能描述**：添加临时费用和系数
- **实现要求**：
  - **添加部件**：用户可手动添加新部件（型号、价格、数量）
  - **添加临时费用**：预设选项（包装费、海运费、陆运费）+ 自定义
  - **添加系数**：预设选项（利润率、税率、预留点数）+ 自定义
  - 所有临时项目需要持久化保存，使用次数会递增
### 7.4 价格计算
- **计算公式**：总价 = (商品小计 + 临时费用) × 系数
- **商品小计**：各商品(单价 × 数量)之和
- **临时费用**：各项临时费用之和
- **系数**：各项系数相乘

### 7.5 详情查看
- **功能描述**：查看商品详细信息
- **实现要求**：
  - 显示商品所有属性（图片、型号、价格及其他参数）
  - 对MachinePart显示审计信息（创建时间、创建人、最后修改时间、最后修改人）
  - 所有字段可编辑
  - 可更换图片
  - 编辑后可保存修改，并更新MachinePart的审计字段
### 7.6 报价单生成功能
- **功能描述**：生成最终报价单
- **实现要求**：
  - 可切换是否显示单价
  - 显示购物车中所有项目
  - 包含价格汇总信息
  - 提供返回购物车和主页的功能
## 8. UI/UX要求

### 8.1 响应式设计
- 适配移动端和平板端
- 在小屏幕设备上优化表格显示

### 8.2 悬浮按钮
- 购物车悬浮按钮（右下角）
- 清空购物车按钮（当购物车不为空时显示）
- 报价单页面的浮动按钮组（切换单价显示、返回购物车、返回主页）

### 8.3 模态框
- 商品详情模态框
- 购物车模态框
- 添加临时费用/系数/部件的表单模态框

## 9. 状态管理

使用Provider模式管理以下状态：
- 机器部件基础数据
- 购物车项目
- 临时费用/系数项目
- 搜索结果
- 当前视图状态（主页、购物车、报价单）

## 10. 集成要求

- 遵循项目现有的代码风格
- 使用现有的Provider状态管理模式
- 符合项目目录结构（在lib/ui/pages/下创建页面）
- 使用现有的数据持久化方案（Hive）
- 可以复用现有的文件处理工具（如file_picker）实现JSON文件导入功能
- 考虑到搜索性能，对于大量数据可能需要优化查询算法