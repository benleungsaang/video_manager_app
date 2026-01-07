import 'package:shelf/shelf.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../models/quotation.dart';

class QuotationApiHandler {
  // 创建报价单
  Future<Response> handleCreateQuotation(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final quotation = Quotation(
        title: params['title'] ?? '',
        items: List<Map<String, dynamic>>.from(params['items'] ?? []),
        remarks: Map<String, String>.from(params['remarks'] ?? {}),
        subtotal: (params['subtotal'] ?? 0).toDouble(),
        total: (params['total'] ?? 0).toDouble(),
        currency: params['currency'] ?? 'CNY',
        createdBy: params['createdBy'] ?? 'user',
        subtotal_remark: params['subtotal_remark'] ?? '',
        total_remark: params['total_remark'] ?? '',
      );

      final quotationsBox = Hive.box<Quotation>('quotations');
      await quotationsBox.add(quotation);

      return Response.ok(
        json.encode({
          'success': true,
          'id': quotation.id, // 返回生成的UUID
          'createdAt': quotation.createdAt.toIso8601String(),
          'message': '报价单创建成功'
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('创建报价单失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取所有报价单
  Future<Response> handleGetQuotations(Request request) async {
    try {
      final quotationsBox = Hive.box<Quotation>('quotations');
      final quotations = quotationsBox.values.toList();

      final quotationsData = <Map<String, dynamic>>[];
      for (final quotation in quotations) {
        quotationsData.add(quotation.toJson());
      }

      return Response.ok(
        json.encode({'success': true, 'data': quotationsData}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取报价单失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 根据ID获取报价单
  Future<Response> handleGetQuotationById(Request request, String id) async {
    try {
      final quotationsBox = Hive.box<Quotation>('quotations');
      final decodedId = Uri.decodeComponent(id);

      Quotation? targetQuotation;

      // 在Hive box中查找指定ID的报价单
      for (final key in quotationsBox.keys) {
        final quotation = quotationsBox.get(key)!;
        if (quotation.id == decodedId) {
          targetQuotation = quotation;
          break;
        }
      }

      if (targetQuotation != null) {
        return Response.ok(
          json.encode({'success': true, 'data': targetQuotation.toJson()}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '报价单不存在'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('获取报价单失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 搜索报价单
  Future<Response> handleSearchQuotations(Request request) async {
    try {
      // 获取查询参数
      final queryParams = request.url.queryParameters;
      final query = queryParams['q']?.toLowerCase() ?? '';

      final quotationsBox = Hive.box<Quotation>('quotations');
      final allQuotations = quotationsBox.values.toList();

      // 根据查询参数过滤报价单
      final matchingQuotations = allQuotations.where((quotation) {
        return quotation.title.toLowerCase().contains(query) ||
            quotation.createdBy.toLowerCase().contains(query) ||
            quotation.currency.toLowerCase().contains(query);
      }).toList();

      final quotationsData = <Map<String, dynamic>>[];
      for (final quotation in matchingQuotations) {
        // 只返回标题、作者、金额和创建时间，节省带宽
        quotationsData.add({
          'id': quotation.id,
          'title': quotation.title,
          'createdBy': quotation.createdBy,
          'total': quotation.total,
          'createdAt': quotation.createdAt.toIso8601String(),
          'updatedAt': quotation.updatedAt.toIso8601String(),
          'currency': quotation.currency, // 保留币种信息
        });
      }

      return Response.ok(
        json.encode({'success': true, 'data': quotationsData}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('搜索报价单失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 更新报价单
  Future<Response> handleUpdateQuotation(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final quotationsBox = Hive.box<Quotation>('quotations');
      final decodedId = Uri.decodeComponent(id);

      Quotation? targetQuotation;
      int? targetKey;

      // 在Hive box中查找指定ID的报价单
      for (final key in quotationsBox.keys) {
        final quotation = quotationsBox.get(key)!;
        if (quotation.id == decodedId) {
          targetQuotation = quotation;
          targetKey = key;
          break;
        }
      }

      if (targetQuotation != null && targetKey != null) {
        // 创建更新后的报价单
        final updatedQuotation = targetQuotation.copyWith(
          title: params['title'] ?? targetQuotation.title,
          items: params['items'] != null
              ? List<Map<String, dynamic>>.from(params['items'])
              : targetQuotation.items,
          remarks: params['remarks'] != null
              ? Map<String, String>.from(params['remarks'])
              : targetQuotation.remarks,
          subtotal: params['subtotal'] != null
              ? (params['subtotal'] as num).toDouble()
              : targetQuotation.subtotal,
          total: params['total'] != null
              ? (params['total'] as num).toDouble()
              : targetQuotation.total,
          currency: params['currency'] ?? targetQuotation.currency,
          updatedAt: DateTime.now(),
          createdBy: params['createdBy'] ?? targetQuotation.createdBy,
        );

        // 更新到Hive数据库
        await quotationsBox.put(targetKey, updatedQuotation);

        return Response.ok(
          json.encode({'success': true, 'data': updatedQuotation.toJson()}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '报价单不存在'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('更新报价单失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 删除报价单
  Future<Response> handleDeleteQuotation(Request request, String id) async {
    try {
      final quotationsBox = Hive.box<Quotation>('quotations');
      final decodedId = Uri.decodeComponent(id);

      bool found = false;
      for (final key in quotationsBox.keys) {
        final quotation = quotationsBox.get(key)!;
        if (quotation.id == decodedId) {
          await quotationsBox.delete(key);
          found = true;
          break;
        }
      }

      if (found) {
        return Response.ok(
          json.encode({'success': true, 'message': '报价单删除成功'}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '报价单不存在'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('删除报价单失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 清空报价单数据库
  Future<Response> handleClearQuotations(Request request) async {
    try {
      final quotationsBox = Hive.box<Quotation>('quotations');
      
      // 清空整个box
      await quotationsBox.clear();
      
      return Response.ok(
        json.encode({'success': true, 'message': '报价单数据库已清空'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('清空报价单数据库失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
