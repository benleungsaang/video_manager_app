import 'package:flutter/material.dart';
import '../../models/quotation.dart';
import '../../services/hive_service.dart';

class QuotationTestPage extends StatelessWidget {
  const QuotationTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotation模型测试'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _testQuotationModel,
              child: const Text('测试Quotation模型'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveQuotation,
              child: const Text('保存报价单到Hive'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadQuotations,
              child: const Text('加载报价单'),
            ),
          ],
        ),
      ),
    );
  }

  void _testQuotationModel() {
    // 创建一个示例报价单
    final quotation = Quotation(
      id: 'q-001',
      title: '测试报价单',
      items: [
        {
          'id': 'item-001',
          'name': '产品A',
          'price': 100.0,
          'quantity': 2,
        },
        {
          'id': 'item-002',
          'name': '产品B',
          'price': 50.0,
          'quantity': 5,
        }
      ],
      remarks: {
        'item-001': '这是产品A的备注',
        'summary': '总计备注',
      },
      subtotal: 200.0,
      total: 230.0, // 包含税费
      currency: 'CNY',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      createdBy: 'test-user',
    );

    debugPrint('报价单ID: ${quotation.id}');
    debugPrint('报价单标题: ${quotation.title}');
    debugPrint('项目数量: ${quotation.items.length}');
    debugPrint('备注数量: ${quotation.remarks.length}');
    debugPrint('小计: ${quotation.subtotal}');
    debugPrint('总计: ${quotation.total}');
    debugPrint('币种: ${quotation.currency}');
  }

  void _saveQuotation() async {
    try {
      // 创建一个示例报价单
      final quotation = Quotation(
        id: 'q-test-${DateTime.now().millisecondsSinceEpoch}',
        title: '测试报价单-${DateTime.now()}',
        items: [
          {
            'id': 'item-001',
            'name': '产品A',
            'price': 100.0,
            'quantity': 2,
          }
        ],
        remarks: {
          'item-001': '这是产品A的备注',
        },
        subtotal: 200.0,
        total: 230.0,
        currency: 'CNY',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'test-user',
      );

      // 保存到Hive
      await HiveService.quotationBox.add(quotation);

      debugPrint('报价单已保存到Hive: ${quotation.id}');
    } catch (e) {
      debugPrint('保存报价单失败: $e');
    }
  }

  void _loadQuotations() async {
    try {
      final quotations = HiveService.quotationBox.values.toList();
      debugPrint('从Hive加载了 ${quotations.length} 个报价单');

      for (final quotation in quotations) {
        debugPrint('报价单: ${quotation.title} (ID: ${quotation.id})');
      }
    } catch (e) {
      debugPrint('加载报价单失败: $e');
    }
  }
}