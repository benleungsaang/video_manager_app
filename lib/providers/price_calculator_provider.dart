import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/machine.dart';
import '../models/cart_item.dart';
import '../models/part.dart';
import '../models/temp_fee.dart';
import '../models/temp_factor.dart';

class PriceCalculatorProvider extends ChangeNotifier {
  // 机器基础数据
  List<Machine> _baseData = [];
  List<Machine> _filteredData = [];
  String _searchTerm = '';
  
  // 购物车项目
  List<CartItem> _cartItems = [];
  
  // 临时项目
  List<Part> _tempParts = [];
  List<TempFee> _tempFees = [];
  List<TempFactor> _tempFactors = [];
  
  // 当前视图状态
  String _currentView = 'home'; // 'home', 'cart', 'quote'
  bool _showUnitPrice = true; // 是否显示单价
  
  // 获取器
  List<Machine> get baseData => _baseData;
  List<Machine> get filteredData => _searchTerm.isEmpty 
    ? _baseData.take(5).toList() // 显示热门商品（被添加次数最多的前5个）
    : _filteredData;
  String get searchTerm => _searchTerm;
  List<CartItem> get cartItems => _cartItems;
  List<Part> get tempParts => _tempParts;
  List<TempFee> get tempFees => _tempFees;
  List<TempFactor> get tempFactors => _tempFactors;
  String get currentView => _currentView;
  bool get showUnitPrice => _showUnitPrice;
  
  // 防抖相关
  Timer? _searchDebounce;
  
  // 计算属性
  int get cartItemCount => _cartItems.fold(0, (sum, item) => sum + item.quantity);
  
  double get subtotal => _cartItems.fold(0, (sum, item) => sum + (item.actualPrice * item.quantity));
  
  double get totalFees => _tempFees.fold(0, (sum, fee) => sum + fee.value);
  
  double get totalFactors => _tempFactors.fold(1, (sum, factor) => sum * factor.value);
  
  double get totalPrice => (subtotal + totalFees) * totalFactors;
  
  // 搜索功能
  void setSearchTerm(String term) {
    _searchTerm = term;
    
    // 取消之前的防抖定时器
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    
    // 设置新的防抖定时器
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
      notifyListeners();
    });
  }
  
  // 立即执行搜索，不使用防抖（用于回车等场景）
  void setSearchTermImmediate(String term) {
    _searchTerm = term;
    _performSearch();
    notifyListeners();
  }
  
  void _performSearch() {
    if (_searchTerm.isEmpty) {
      // 如果搜索框为空，显示被添加次数最多的前5个项目（热门商品）
      _filteredData = List.from(_baseData)
        ..sort((a, b) => b.addedCount.compareTo(a.addedCount))
        ..removeRange(5, _filteredData.length > 5 ? _filteredData.length : 5);
    } else {
      // 进行搜索 - 只搜索 model 和 originalModel 字段
      String lowerSearchTerm = _searchTerm.toLowerCase();
      _filteredData = _baseData.where((item) =>
          item.model.toLowerCase().contains(lowerSearchTerm) ||
          item.originalModel.toLowerCase().contains(lowerSearchTerm)
      ).toList();
    }
  }
  
  // 切换视图
  void setCurrentView(String view) {
    _currentView = view;
    notifyListeners();
  }
  
  // 切换单价显示
  void toggleShowUnitPrice() {
    _showUnitPrice = !_showUnitPrice;
    notifyListeners();
  }
  
  // 初始化数据（从Hive加载）
  Future<void> initializeData() async {
    await _loadBaseData();
    await _loadCartItems();
    await _loadTempParts();
    await _loadTempFees();
    await _loadTempFactors();
    _performSearch(); // 初始化搜索结果
    notifyListeners();
  }
  
  // 机器部件基础数据管理
  Future<void> _loadBaseData() async {
    try {
      final box = await Hive.openBox<Machine>('machines');
      _baseData = box.values.toList();
      // 注意：不关闭box，让Hive管理box的生命周期
    } catch (e) {
      print('加载机器部件数据失败: $e');
      // 不清空现有数据，保持原有数据
    }
  }
  
  Future<void> saveMachine(Machine part) async {
    try {
      final box = await Hive.openBox<Machine>('machines');
      
      // 如果是更新现有项目，先找到并更新
      final existingIndex = _baseData.indexWhere((item) => item.model == part.model);
      if (existingIndex != -1) {
        _baseData[existingIndex] = part;
        // 重建整个box以确保数据一致性
        await _rebuildMachinesBox();
      } else {
        // 如果是新项目，添加到列表
        _baseData.add(part);
        await box.add(part);
      }
      
      _performSearch(); // 更新搜索结果
      notifyListeners();
    } catch (e) {
      print('保存机器部件失败: $e');
      // 如果保存失败，尝试重建box
      await _rebuildMachinesBox();
    }
  }
  
  Future<void> importMachinePartsFromJson(String jsonString) async {
    try {
      final List<dynamic> jsonData = json.decode(jsonString);
      
      // 清空现有数据
      _baseData.clear();
      
      // 导入新数据
      for (final item in jsonData) {
        if (item is Map<String, dynamic>) {
          // 创建带审计字段的MachinePart
          final now = DateTime.now();
          
          // 将所有值转换为字符串
          Map<String, String> allProperties = {};
          item.forEach((key, value) {
            allProperties[key] = value?.toString() ?? '';
          });
          
          final machine = Machine(
            model: item['Model']?.toString() ?? '',
            originalModel: item['OriginalModel']?.toString() ?? '',
            originalPrice: (item['OriginalPrice'] as num?)?.toDouble() ?? 0.0,
            showPrice: (item['ShowPrice'] as num?)?.toDouble() ?? 0.0,
            image: item['image']?.toString() ?? '',
            addedCount: item['addedCount']?.toInt() ?? 0,
            otherProperties: allProperties // 包含所有其他属性
              ..removeWhere((key, value) => 
                key == 'id' ||
                key == 'Id' ||
                key == '_id' ||
                key == 'Model' || 
                key == 'OriginalModel' || 
                key == 'OriginalPrice' || 
                key == 'ShowPrice' || 
                key == 'image' || 
                key == 'addedCount'),
            createdAt: now,
            updatedAt: now,
            createdBy: 'system',
            updatedBy: 'system',
            id: item['id']?.toString() ?? item['Id']?.toString() ?? item['_id']?.toString() ?? '',
          );
          
          _baseData.add(machine);
        }
      }
      
      // 将数据保存到Hive
      await _rebuildMachinesBox();
      
      _performSearch(); // 更新搜索结果
      notifyListeners();
    } catch (e) {
      print('从JSON导入机器部件失败: $e');
      rethrow;
    }
  }
  
  Future<void> updateMachineAddedCount(String model) async {
    final index = _baseData.indexWhere((item) => item.model == model);
    if (index != -1) {
      final part = _baseData[index];
      final updatedPart = part.copyWith(
        addedCount: part.addedCount + 1,
        updatedAt: DateTime.now(),
        updatedBy: 'user',
      );
      
      _baseData[index] = updatedPart;
      
      // 更新Hive存储 - 重建整个box以确保数据一致性
      try {
        await _rebuildMachinesBox();
      } catch (e) {
        print('更新机器部件添加次数失败: $e');
        // 如果重建失败，尝试重新加载数据
        await _loadBaseData();
      }
    }
  }
  
  // 用于重建机器部件box的辅助方法
  Future<void> _rebuildMachinesBox() async {
    try {
      final box = await Hive.openBox<Machine>('machines');
      await box.clear();
      for (final item in _baseData) {
        await box.add(item);
      }
    } catch (e) {
      print('重建机器box失败: $e');
      // 如果重建失败，尝试重新初始化数据
      await _loadBaseData();
    }
  }
  
  Machine? findMachineByModel(String model) {
    final index = _baseData.indexWhere((item) => item.model == model);
    return index != -1 ? _baseData[index] : null;
  }
  
  Machine? findMachineByOriginalModel(String originalModel) {
    final index = _baseData.indexWhere((item) => item.originalModel == originalModel);
    return index != -1 ? _baseData[index] : null;
  }
  
  // 购物车管理功能
  Future<void> _loadCartItems() async {
    try {
      final box = await Hive.openBox<CartItem>('cart_items');
      _cartItems = box.values.toList();
      // 注意：不关闭box，让Hive管理box的生命周期
    } catch (e) {
      print('加载购物车数据失败: $e');
      // 不清空现有数据，保持原有数据
    }
  }
  
  void addToCart({
    required String type,
    required String model,
    required String name,
    required double basePrice,
    required double actualPrice,
    required String image,
    int quantity = 1,
  }) {
    // 检查项目是否已存在于购物车中
    final existingItemIndex = _cartItems.indexWhere((item) => 
        item.model == model && item.type == type);
    
    if (existingItemIndex != -1) {
      // 如果已存在，增加数量
      final existingItem = _cartItems[existingItemIndex];
      _cartItems[existingItemIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
        actualPrice: actualPrice, // 更新价格
      );
    } else {
      // 如果不存在，添加新项目
      final newItem = CartItem(
        id: Uuid().v4(),
        type: type,
        model: model,
        name: name,
        basePrice: basePrice,
        actualPrice: actualPrice,
        quantity: quantity,
        image: image,
      );
      _cartItems.add(newItem);
    }
    
    notifyListeners();
    _saveCartItems(); // 持久化保存
  }
  
  void updateCartItemQuantity(String id, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(id);
      return;
    }
    
    final itemIndex = _cartItems.indexWhere((item) => item.id == id);
    if (itemIndex != -1) {
      _cartItems[itemIndex] = _cartItems[itemIndex].copyWith(quantity: newQuantity);
      notifyListeners();
      _saveCartItems(); // 持久化保存
    }
  }
  
  void updateCartItemPrice(String id, double newPrice) {
    final itemIndex = _cartItems.indexWhere((item) => item.id == id);
    if (itemIndex != -1) {
      _cartItems[itemIndex] = _cartItems[itemIndex].copyWith(actualPrice: newPrice);
      notifyListeners();
      _saveCartItems(); // 持久化保存
    }
  }
  
  void removeFromCart(String id) {
    _cartItems.removeWhere((item) => item.id == id);
    notifyListeners();
    _saveCartItems(); // 持久化保存
  }
  
  void clearCart() {
    _cartItems.clear();
    notifyListeners();
    _saveCartItems(); // 持久化保存
  }
  
  void clearTempFees() {
    _tempFees.clear();
    notifyListeners();
    _saveTempFees(); // 持久化保存
  }
  
  void clearTempFactors() {
    _tempFactors.clear();
    notifyListeners();
    _saveTempFactors(); // 持久化保存
  }
  
  Future<void> _saveCartItems() async {
    try {
      final box = await Hive.openBox<CartItem>('cart_items');
      await box.clear(); // 清除现有数据
      
      for (final item in _cartItems) {
        await box.add(item);
      }
      
      // 注意：不关闭box，让Hive管理box的生命周期
    } catch (e) {
      print('保存购物车数据失败: $e');
    }
  }
  
  // 临时项目管理功能（部件、费用、系数）
  Future<void> _loadTempParts() async {
    try {
      final box = await Hive.openBox<Part>('temp_parts');
      _tempParts = box.values.toList();
      // 注意：不关闭box，让Hive管理box的生命周期
    } catch (e) {
      print('加载临时部件数据失败: $e');
      // 不清空现有数据，保持原有数据
    }
  }
  
  Future<void> _loadTempFees() async {
    try {
      final box = await Hive.openBox<TempFee>('temp_fees');
      _tempFees = box.values.toList();
      // 注意：不关闭box，让Hive管理box的生命周期
    } catch (e) {
      print('加载临时费用数据失败: $e');
      // 不清空现有数据，保持原有数据
    }
  }
  
  Future<void> _loadTempFactors() async {
    try {
      final box = await Hive.openBox<TempFactor>('temp_factors');
      _tempFactors = box.values.toList();
      // 注意：不关闭box，让Hive管理box的生命周期
    } catch (e) {
      print('加载临时系数数据失败: $e');
      // 不清空现有数据，保持原有数据
    }
  }
  
  // 添加临时部件
  Future<void> addTempPart(String model, String name, double price, {String remark = ''}) async {
    final newPart = Part(
      id: Uuid().v4(),
      model: model,
      price: price,
      remark: remark, // 部件详细描述
      addedCount: 1, // 被添加次数
    );
    
    _tempParts.add(newPart);
    notifyListeners();
    await _saveTempParts();
  }
  
  // 添加临时费用
  Future<void> addTempFee(String name, double defaultAmount) async {
    final newFee = TempFee(
      id: Uuid().v4(),
      name: name,
      value: defaultAmount,
      addedCount: 1, // 新添加的项目被添加次数为1
    );
    
    _tempFees.add(newFee);
    notifyListeners();
    await _saveTempFees();
  }
  
  // 添加临时系数
  Future<void> addTempFactor(String name, double defaultValue) async {
    final newFactor = TempFactor(
      id: Uuid().v4(),
      name: name,
      value: defaultValue,
      addedCount: 1, // 新添加的项目被添加次数为1
    );
    
    _tempFactors.add(newFactor);
    notifyListeners();
    await _saveTempFactors();
  }
  
  // 更新临时项目使用次数
  Future<void> incrementTempPartUsage(String id) async {
    final index = _tempParts.indexWhere((item) => item.id == id);
    if (index != -1) {
      _tempParts[index] = _tempParts[index].copyWith(addedCount: _tempParts[index].addedCount + 1);
      notifyListeners();
      await _saveTempParts();
    }
  }
  
  Future<void> incrementTempFeeUsage(String name) async {
    final index = _tempFees.indexWhere((item) => item.name == name);
    if (index != -1) {
      _tempFees[index] = _tempFees[index].copyWith(addedCount: _tempFees[index].addedCount + 1);
      notifyListeners();
      await _saveTempFees();
    }
  }
  
  Future<void> incrementTempFactorUsage(String name) async {
    final index = _tempFactors.indexWhere((item) => item.name == name);
    if (index != -1) {
      _tempFactors[index] = _tempFactors[index].copyWith(addedCount: _tempFactors[index].addedCount + 1);
      notifyListeners();
      await _saveTempFactors();
    }
  }
  
  // 删除临时项目
  void removeTempPart(String id) {
    _tempParts.removeWhere((item) => item.id == id);
    notifyListeners();
    _saveTempParts();
  }
  
  void removeTempFee(String name) {
    _tempFees.removeWhere((item) => item.name == name);
    notifyListeners();
    _saveTempFees();
  }
  
  void removeTempFactor(String name) {
    _tempFactors.removeWhere((item) => item.name == name);
    notifyListeners();
    _saveTempFactors();
  }
  
  // 保存临时项目到Hive
  Future<void> _saveTempParts() async {
    try {
      final box = await Hive.openBox<Part>('temp_parts');
      await box.clear();
      
      for (final part in _tempParts) {
        await box.add(part);
      }
      
      // 注意：不关闭box，让Hive管理box的生命周期
    } catch (e) {
      print('保存临时部件数据失败: $e');
    }
  }
  
  Future<void> _saveTempFees() async {
    try {
      final box = await Hive.openBox<TempFee>('temp_fees');
      await box.clear();
      
      for (final fee in _tempFees) {
        await box.add(fee);
      }
      
      // 注意：不关闭box，让Hive管理box的生命周期
    } catch (e) {
      print('保存临时费用数据失败: $e');
    }
  }
  
  Future<void> _saveTempFactors() async {
    try {
      final box = await Hive.openBox<TempFactor>('temp_factors');
      await box.clear();
      
      for (final factor in _tempFactors) {
        await box.add(factor);
      }
      
      // 注意：不关闭box，让Hive管理box的生命周期
    } catch (e) {
      print('保存临时系数数据失败: $e');
    }
  }
  
  // 获取热门临时项目（被添加次数最多的项目）
  List<Part> getTopUsedParts(int count) {
    return List.from(_tempParts)..sort((a, b) => b.addedCount.compareTo(a.addedCount))..removeRange(count, _tempParts.length > count ? _tempParts.length : count);
  }
  
  List<TempFee> getTopUsedFees(int count) {
    return List.from(_tempFees)..sort((a, b) => b.addedCount.compareTo(a.addedCount))..removeRange(count, _tempFees.length > count ? _tempFees.length : count);
  }
  
  List<TempFactor> getTopUsedFactors(int count) {
    return List.from(_tempFactors)..sort((a, b) => b.addedCount.compareTo(a.addedCount))..removeRange(count, _tempFactors.length > count ? _tempFactors.length : count);
  }
  
  // 价格计算相关功能
  double calculateSubtotal() {
    return _cartItems.fold(0, (sum, item) => sum + (item.actualPrice * item.quantity));
  }
  
  double calculateTotalFees() {
    return _tempFees.fold(0, (sum, fee) => sum + fee.value);
  }
  
  double calculateTotalFactors() {
    return _tempFactors.fold(1, (sum, factor) => sum * factor.value);
  }
  
  double calculateTotalPrice() {
    final subtotal = calculateSubtotal();
    final totalFees = calculateTotalFees();
    final totalFactors = calculateTotalFactors();
    return (subtotal + totalFees) * totalFactors;
  }
  
  // 获取价格明细
  Map<String, dynamic> getPriceBreakdown() {
    return {
      'subtotal': calculateSubtotal(),
      'fees': calculateTotalFees(),
      'factor': calculateTotalFactors(),
      'total': calculateTotalPrice(),
      'cartItemsCount': _cartItems.length,
      'feesCount': _tempFees.length,
      'factorsCount': _tempFactors.length,
    };
  }
  
  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  // 在应用关闭时调用以正确关闭所有Hive box
  Future<void> closeAllBoxes() async {
    try {
      if (Hive.isBoxOpen('machine_parts')) {
        await Hive.box<Machine>('machines').close();
      }
      if (Hive.isBoxOpen('cart_items')) {
        await Hive.box<CartItem>('cart_items').close();
      }
      if (Hive.isBoxOpen('temp_parts')) {
        await Hive.box<Part>('temp_parts').close();
      }
      if (Hive.isBoxOpen('temp_fees')) {
        await Hive.box<TempFee>('temp_fees').close();
      }
      if (Hive.isBoxOpen('temp_factors')) {
        await Hive.box<TempFactor>('temp_factors').close();
      }
    } catch (e) {
      print('关闭Hive box时出错: $e');
    }
  }
}