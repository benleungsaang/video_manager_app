import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/price_calculator_provider.dart';
import '../../models/machine_part.dart';
import '../../models/temp_fee.dart';
import '../../models/temp_factor.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class PriceCalculatorPage extends StatefulWidget {
  const PriceCalculatorPage({Key? key}) : super(key: key);

  @override
  _PriceCalculatorPageState createState() => _PriceCalculatorPageState();
}

class _PriceCalculatorPageState extends State<PriceCalculatorPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _showDataSection = false;
  bool _showCartModal = false;
  bool _showDetailModal = false;
  bool _showTempFeeModal = false;
  bool _showTempFactorModal = false;
  bool _showAddPartModal = false;
  bool _showQuotePage = false;
  MachinePart? _selectedItem;
  Map<String, TextEditingController> _editingControllers = {};
  bool _showQuoteUnitPrice = true; // 控制报价单中是否显示单价

  // 临时费用表单控制器
  final TextEditingController _tempFeeNameController = TextEditingController();
  final TextEditingController _tempFeeAmountController =
      TextEditingController();

  // 临时系数表单控制器
  final TextEditingController _tempFactorNameController =
      TextEditingController();
  final TextEditingController _tempFactorValueController =
      TextEditingController();

  // 添加部件表单控制器
  final TextEditingController _partModelController = TextEditingController();
  final TextEditingController _partPriceController = TextEditingController();
  final TextEditingController _partQuantityController = TextEditingController();
  
  // 焦点节点，用于处理Tab键切换
  final FocusNode _partModelFocusNode = FocusNode();
  final FocusNode _partPriceFocusNode = FocusNode();
  final FocusNode _partQuantityFocusNode = FocusNode();
  
  // 临时费用焦点节点
  final FocusNode _tempFeeNameFocusNode = FocusNode();
  final FocusNode _tempFeeAmountFocusNode = FocusNode();
  
  // 临时系数焦点节点
  final FocusNode _tempFactorNameFocusNode = FocusNode();
  final FocusNode _tempFactorValueFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('价格计算器'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () {
              setState(() {
                _showDataSection = !_showDataSection;
              });
            },
            tooltip: '上传数据',
          ),
        ],
      ),
      body: Consumer<PriceCalculatorProvider>(
        builder: (context, provider, child) {
          // 确保数据已初始化
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (provider.baseData.isEmpty) {
              provider.initializeData();
            }
          });

          return Stack(
            children: [
              // 主页面内容
              _buildMainContent(provider),

              // 详情模态框
              if (_showDetailModal && _selectedItem != null)
                _buildDetailModal(provider),

              // 购物车模态框
              if (_showCartModal) _buildCartModal(provider),

              // 添加临时费用模态框
              if (_showTempFeeModal) _buildTempFeeModal(provider),

              // 添加临时系数模态框
              if (_showTempFactorModal) _buildTempFactorModal(provider),

              // 添加部件模态框
              if (_showAddPartModal) _buildAddPartModal(provider),

              // 报价单页面
              if (_showQuotePage) _buildQuotePage(provider),
            ],
          );
        },
      ),
      floatingActionButton: (!_showCartModal && !_showQuotePage) ? Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // 清空购物车按钮 - 仅在购物车有数据时显示
          if (context.watch<PriceCalculatorProvider>().cartItemCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FloatingActionButton(
                onPressed: () {
                  final provider = context.read<PriceCalculatorProvider>();
                  provider.clearCart();
                  provider.clearTempFees();
                  provider.clearTempFactors();
                },
                backgroundColor: Colors.red,
                child: const Icon(Icons.delete),
              ),
            ),
          // 购物车按钮
          FloatingActionButton(
            onPressed: () {
              setState(() {
                _showCartModal = true;
              });
            },
            child: Stack(
              children: [
                const Icon(Icons.shopping_cart),
                // 购物车项目数量徽章
                if (context.watch<PriceCalculatorProvider>().cartItemCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        context
                            .watch<PriceCalculatorProvider>()
                            .cartItemCount
                            .toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ) : null, // 在显示购物车模态框或报价单时不显示悬浮按钮
    );
  }

  // 构建主页面内容
  Widget _buildMainContent(PriceCalculatorProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 数据上传部分
          if (_showDataSection) _buildDataSection(provider),

          // 搜索部分
          _buildSearchSection(provider),

          // 搜索结果
          _buildSearchResults(provider),
        ],
      ),
    );
  }

  // 构建数据上传部分
  Widget _buildDataSection(PriceCalculatorProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. 上传机器及零部件基础信息',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('选择JSON文件'),
              onPressed: () async {
                await _importJsonData(context, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  // 构建搜索部分
  Widget _buildSearchSection(PriceCalculatorProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '搜索机器或零部件:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: '输入型号或名称进行搜索...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      // 只更新控制器的值，不触发搜索
                    },
                    onSubmitted: (value) {
                      // 按回车时立即执行搜索
                      provider.setSearchTermImmediate(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // 点击按钮时立即执行搜索
                    provider.setSearchTermImmediate(_searchController.text);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 构建搜索结果
  Widget _buildSearchResults(PriceCalculatorProvider provider) {
    final items = _searchController.text.isEmpty
        ? provider.baseData.take(5).toList() // 显示热门商品
        : provider.filteredData;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '搜索结果',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Center(
                child: Text(
                  '未找到匹配的项目',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: item.image.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.image,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[300],
                                    child:
                                        const Icon(Icons.image_not_supported),
                                  );
                                },
                              ),
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image),
                            ),
                      title: Text(
                        item.model,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '型号: ${item.originalModel}\n价格: ¥${item.showPrice.toStringAsFixed(2)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: ElevatedButton.icon(
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: const Text('购物车', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          provider.addToCart(
                            type: '机器',
                            model: item.model,
                            name: item.originalModel,
                            basePrice: item.originalPrice,
                            actualPrice: item.showPrice,
                            image: item.image,
                          );
                          provider.updateMachinePartAddedCount(item.model);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${item.model} 已添加到购物车'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedItem = item;
                          _showDetailModal = true;
                        });
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // 构建详情模态框
  Widget _buildDetailModal(PriceCalculatorProvider provider) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // 模态框标题和关闭按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '产品详情',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _showDetailModal = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 详情内容
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 产品图和基本信息行
                      if (_selectedItem!.image.isNotEmpty || _selectedItem!.model.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 产品图 (左边)
                              if (_selectedItem!.image.isNotEmpty)
                                Expanded(
                                  flex: 1,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      _selectedItem!.image,
                                      height: 150,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          height: 150,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.image_not_supported,
                                              size: 50),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              if (_selectedItem!.image.isNotEmpty)
                                const SizedBox(width: 16),
                              // 产品信息 (右边)
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedItem!.model,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '显示价格: ¥${_selectedItem!.showPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      // 滚动的详细信息部分
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '原型号: ${_selectedItem!.originalModel}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '原价格: ¥${_selectedItem!.originalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '被添加次数: ${_selectedItem!.addedCount}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '其他属性:',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                // 创建编辑控制器
                                Builder(
                                  builder: (context) {
                                    // 初始化编辑控制器
                                    _selectedItem!.otherProperties.forEach((key, value) {
                                      if (!_editingControllers.containsKey(key)) {
                                        _editingControllers[key] = TextEditingController(text: value);
                                      }
                                    });
                                    return Container();
                                  },
                                ),
                                // 以表格形式显示其他属性
                                Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(1),
                                    1: FlexColumnWidth(2),
                                  },
                                  children: _selectedItem!.otherProperties.entries
                                      .map((entry) => TableRow(
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 8.0),
                                                child: Text(
                                                  entry.key,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 8.0),
                                                child: TextField(
                                                  controller: _editingControllers[entry.key],
                                                  decoration: InputDecoration(
                                                    hintText: entry.value,
                                                    border: const OutlineInputBorder(),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ))
                                      .toList(),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    // 保存修改后的值
                                    Map<String, String> updatedProperties = {};
                                    _selectedItem!.otherProperties.forEach((key, value) {
                                      updatedProperties[key] = _editingControllers[key]?.text ?? value;
                                    });
                                    
                                    // 更新机器部件的其他属性
                                    final updatedItem = _selectedItem!.copyWith(
                                      otherProperties: updatedProperties,
                                      updatedAt: DateTime.now(),
                                      updatedBy: 'user',
                                    );
                                    
                                    // 更新 provider 中的数据
                                    Provider.of<PriceCalculatorProvider>(context, listen: false)
                                        .saveMachinePart(updatedItem);
                                    
                                    // 更新本地变量
                                    _selectedItem = updatedItem;
                                    
                                    // 显示成功提示
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('属性已保存'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.save),
                                  label: const Text('保存属性'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 添加到购物车按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            provider.addToCart(
                              type: '机器',
                              model: _selectedItem!.model,
                              name: _selectedItem!.originalModel,
                              basePrice: _selectedItem!.originalPrice,
                              actualPrice: _selectedItem!.showPrice,
                              image: _selectedItem!.image,
                            );
                            provider.updateMachinePartAddedCount(
                                _selectedItem!.model);
                            setState(() {
                              _showDetailModal = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('${_selectedItem!.model} 已添加到购物车'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          },
                          child: const Text('添加到购物车'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showDetailModal = false;
                            });
                          },
                          child: const Text('关闭'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建购物车模态框
  Widget _buildCartModal(PriceCalculatorProvider provider) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            height: MediaQuery.of(context).size.height * 0.9,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // 模态框标题和关闭按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '购物车',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _showCartModal = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 购物车内容
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // 购物车列表
                        Expanded(
                          child: provider.cartItems.isEmpty
                              ? const Center(
                                  child: Text(
                                    '购物车为空',
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: provider.cartItems.length,
                                  itemBuilder: (context, index) {
                                    final item = provider.cartItems[index];
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            // 商品图片
                                            if (item.image.isNotEmpty)
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  item.image,
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      width: 50,
                                                      height: 50,
                                                      color: Colors.grey[300],
                                                      child: const Icon(Icons
                                                          .image_not_supported),
                                                    );
                                                  },
                                                ),
                                              ),
                                            const SizedBox(width: 12),

                                            // 商品信息
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // 根据类型显示不同的信息
                                                  if (item.type == '部件')
                                                    Text(
                                                      item.name, // 部件显示部件名
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    )
                                                  else
                                                    Text(
                                                      item.model, // 机器显示型号
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold),
                                                    ),
                                                  if (item.type != '部件')
                                                    Text('型号: ${item.model}'),
                                                  Text(
                                                    '单价: ¥${item.actualPrice.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                        color: Colors.green),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // 数量调整
                                            Column(
                                              children: [
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.remove,
                                                          size: 20),
                                                      onPressed: () {
                                                        provider
                                                            .updateCartItemQuantity(
                                                          item.id,
                                                          item.quantity - 1,
                                                        );
                                                      },
                                                    ),
                                                    Text('${item.quantity}'),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.add,
                                                          size: 20),
                                                      onPressed: () {
                                                        provider
                                                            .updateCartItemQuantity(
                                                          item.id,
                                                          item.quantity + 1,
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  '小计: ¥${(item.actualPrice * item.quantity).toStringAsFixed(2)}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),

                        // 价格汇总
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('商品小计:',
                                      style: TextStyle(fontSize: 16)),
                                  Text(
                                    '¥${provider.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // 逐一显示临时费用
                              if (provider.tempFees.isNotEmpty) ...[
                                const Text('临时费用明细:',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                ...provider.tempFees.map((fee) => Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${fee.name}:',
                                        style: const TextStyle(fontSize: 13)),
                                    Text('¥${fee.defaultAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(fontSize: 13, color: Colors.green)),
                                  ],
                                )),
                              ],
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('临时费用合计:',
                                      style: TextStyle(fontSize: 16)),
                                  Text(
                                    '¥${provider.totalFees.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // 逐一显示临时系数
                              if (provider.tempFactors.isNotEmpty) ...[
                                const Text('系数明细:',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                ...provider.tempFactors.map((factor) => Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('${factor.name}:',
                                        style: const TextStyle(fontSize: 13)),
                                    Text('${factor.defaultValue.toStringAsFixed(2)}x',
                                        style: const TextStyle(fontSize: 13, color: Colors.orange)),
                                  ],
                                )),
                              ],
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('系数合计:',
                                      style: TextStyle(fontSize: 16)),
                                  Text(
                                    '${provider.totalFactors.toStringAsFixed(2)}x',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('总计:',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold)),
                                  Text(
                                    '¥${provider.totalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 操作按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius:
                        const BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: context.watch<PriceCalculatorProvider>().cartItems.isNotEmpty
                            ? () {
                                Provider.of<PriceCalculatorProvider>(context, listen: false)
                                    .clearCart();
                                Provider.of<PriceCalculatorProvider>(context, listen: false)
                                    .clearTempFees();
                                Provider.of<PriceCalculatorProvider>(context, listen: false)
                                    .clearTempFactors();
                                setState(() {
                                  _showCartModal = false;
                                });
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('🗑️ 清空购物车'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showAddPartModal = true;
                            _showCartModal = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('⚙️ 添加部件'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showTempFeeModal = true;
                            _showCartModal = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('💰 添加临时费用'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showTempFactorModal = true;
                            _showCartModal = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('📊 添加系数'),
                      ),
                      ElevatedButton(
                        onPressed: context.watch<PriceCalculatorProvider>().cartItems.isNotEmpty
                            ? () {
                                setState(() {
                                  _showQuotePage = true;
                                  _showCartModal = false;
                                });
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('📋 生成报价单'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showCartModal = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('❌ 关闭'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建添加临时费用模态框
  Widget _buildTempFeeModal(PriceCalculatorProvider provider) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 模态框标题和关闭按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '添加临时费用',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _showTempFeeModal = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 预选费用按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '预选费用:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              _tempFeeNameController.text = '包装费';
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('包装费'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _tempFeeNameController.text = '海运费';
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('海运费'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _tempFeeNameController.text = '陆运费';
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('陆运费'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 表单
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _tempFeeNameController,
                        focusNode: _tempFeeNameFocusNode,
                        decoration: const InputDecoration(
                          labelText: '费用名称',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (value) {
                          FocusScope.of(context).requestFocus(_tempFeeAmountFocusNode);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _tempFeeAmountController,
                        focusNode: _tempFeeAmountFocusNode,
                        decoration: const InputDecoration(
                          labelText: '费用金额',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),

                // 按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_tempFeeNameController.text.isNotEmpty &&
                                _tempFeeAmountController.text.isNotEmpty) {
                              double amount = double.tryParse(
                                      _tempFeeAmountController.text) ??
                                  0;
                              await provider.addTempFee(
                                _tempFeeNameController.text,
                                amount,
                              );
                              _tempFeeNameController.clear();
                              _tempFeeAmountController.clear();
                              setState(() {
                                _showTempFeeModal = false;
                                _showCartModal = true; // 返回购物车
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('添加费用'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showTempFeeModal = false;
                              _showCartModal = true; // 返回购物车
                            });
                          },
                          child: const Text('取消'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建添加临时系数模态框
  Widget _buildTempFactorModal(PriceCalculatorProvider provider) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 模态框标题和关闭按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '添加系数',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _showTempFactorModal = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 预选系数按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '预选系数:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              _tempFactorNameController.text = '利润率';
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('利润率'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _tempFactorNameController.text = '税率';
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('税率'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _tempFactorNameController.text = '预留点数';
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('预留点数'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 表单
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _tempFactorNameController,
                        focusNode: _tempFactorNameFocusNode,
                        decoration: const InputDecoration(
                          labelText: '系数名称',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (value) {
                          FocusScope.of(context).requestFocus(_tempFactorValueFocusNode);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _tempFactorValueController,
                        focusNode: _tempFactorValueFocusNode,
                        decoration: const InputDecoration(
                          labelText: '系数值',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),

                // 按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_tempFactorNameController.text.isNotEmpty &&
                                _tempFactorValueController.text.isNotEmpty) {
                              double value = double.tryParse(
                                      _tempFactorValueController.text) ??
                                  0;
                              await provider.addTempFactor(
                                _tempFactorNameController.text,
                                value,
                              );
                              _tempFactorNameController.clear();
                              _tempFactorValueController.clear();
                              setState(() {
                                _showTempFactorModal = false;
                                _showCartModal = true; // 返回购物车
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('添加系数'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showTempFactorModal = false;
                              _showCartModal = true; // 返回购物车
                            });
                          },
                          child: const Text('取消'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建添加部件模态框
  Widget _buildAddPartModal(PriceCalculatorProvider provider) {
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 模态框标题和关闭按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '添加部件',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _showAddPartModal = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // 表单
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _partModelController,
                        focusNode: _partModelFocusNode,
                        decoration: const InputDecoration(
                          labelText: '部件型号',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (value) {
                          FocusScope.of(context).requestFocus(_partPriceFocusNode);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _partPriceController,
                        focusNode: _partPriceFocusNode,
                        decoration: const InputDecoration(
                          labelText: '部件单价',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        onSubmitted: (value) {
                          FocusScope.of(context).requestFocus(_partQuantityFocusNode);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _partQuantityController,
                        focusNode: _partQuantityFocusNode,
                        decoration: const InputDecoration(
                          labelText: '数量',
                          border: OutlineInputBorder(),
                          hintText: '默认为1',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),

                // 按钮
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (_partModelController.text.isNotEmpty &&
                                _partPriceController.text.isNotEmpty) {
                              String model = _partModelController.text;
                              double price =
                                  double.tryParse(_partPriceController.text) ??
                                      0;
                              int quantity = _partQuantityController.text.isNotEmpty
                                  ? int.tryParse(_partQuantityController.text) ??
                                      1
                                  : 1;

                              provider.addToCart(
                                type: '部件',
                                model: model,
                                name: model,
                                basePrice: price,
                                actualPrice: price,
                                image: '', // 部件可能没有图片
                                quantity: quantity,
                              );

                              _partModelController.clear();
                              _partPriceController.clear();
                              _partQuantityController.clear();
                              setState(() {
                                _showAddPartModal = false;
                                _showCartModal = true; // 返回购物车
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('添加部件'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showAddPartModal = false;
                              _showCartModal = true; // 返回购物车
                            });
                          },
                          child: const Text('取消'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 构建报价单页面
  Widget _buildQuotePage(PriceCalculatorProvider provider) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('报价单'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
        actions: [
          // 切换单价显示按钮
          IconButton(
            icon: Icon(_showQuoteUnitPrice ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _showQuoteUnitPrice = !_showQuoteUnitPrice;
              });
            },
            tooltip: _showQuoteUnitPrice ? '隐藏单价' : '显示单价',
          ),
          // 返回主页按钮
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              setState(() {
                _showQuotePage = false;
              });
            },
            tooltip: '返回主页',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 购物车项目列表
              const Text(
                '商品明细',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              ...provider.cartItems
                  .map((item) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    Text('型号: ${item.model}'),
                                  ],
                                ),
                              ),
                                                                  Expanded(
                                                                    child: Text('数量: ${item.quantity}'),
                                                                  ),
                                                                  if (_showQuoteUnitPrice) ...[
                                                                    Expanded(
                                                                      child: Text(
                                                                          '单价: ¥${item.actualPrice.toStringAsFixed(2)}'),
                                                                    ),
                                                                    Expanded(
                                                                      child: Text(
                                                                        '小计: ¥${(item.actualPrice * item.quantity).toStringAsFixed(2)}',
                                                                        style: const TextStyle(
                                                                            fontWeight: FontWeight.bold),
                                                                      ),
                                                                    ),
                                                                  ],                            ],
                          ),
                        ),
                      ))
                  .toList(),

              const SizedBox(height: 16),

              // 临时费用
              if (provider.tempFees.isNotEmpty) ...[
                const Text(
                  '临时费用',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...provider.tempFees
                    .map((fee) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(fee.name),
                                ),
                                Expanded(
                                  child: Text(
                                    '¥${fee.defaultAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
                const SizedBox(height: 16),
              ],

              // 价格汇总
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('商品小计:'),
                          Text(
                              '¥${provider.subtotal.toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('临时费用:'),
                          Text(
                              '¥${provider.totalFees.toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('系数:'),
                          Text(
                              '${provider.totalFactors.toStringAsFixed(2)}x'),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '总计:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '¥${provider.totalPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 导入JSON数据
  Future<void> _importJsonData(
      BuildContext context, PriceCalculatorProvider provider) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        PlatformFile file = result.files.first;
        // 安全处理可能为空的文件字节数据
        if (file.bytes != null) {
          String jsonString = String.fromCharCodes(file.bytes!);

          await provider.importMachinePartsFromJson(jsonString);

          setState(() {
            _showDataSection = false; // 隐藏数据上传部分
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('JSON数据导入成功')),
          );
        } else {
          // 尝试从文件路径读取文件内容
          if (file.path != null) {
            String jsonString = await File(file.path!).readAsString();
            
            await provider.importMachinePartsFromJson(jsonString);

            setState(() {
              _showDataSection = false; // 隐藏数据上传部分
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('JSON数据导入成功')),
            );
          } else {
            throw Exception('无法读取文件内容');
          }
        }
      }
    } catch (e) {
      print('导入JSON数据失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tempFeeNameController.dispose();
    _tempFeeAmountController.dispose();
    _tempFactorNameController.dispose();
    _tempFactorValueController.dispose();
    _partModelController.dispose();
    _partPriceController.dispose();
    _partQuantityController.dispose();
    
    // 释放FocusNode资源
    _partModelFocusNode.dispose();
    _partPriceFocusNode.dispose();
    _partQuantityFocusNode.dispose();
    _tempFeeNameFocusNode.dispose();
    _tempFeeAmountFocusNode.dispose();
    _tempFactorNameFocusNode.dispose();
    _tempFactorValueFocusNode.dispose();
    
    super.dispose();
  }
}
