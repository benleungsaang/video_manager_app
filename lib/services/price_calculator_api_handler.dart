import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/machine_part.dart';
import '../models/part.dart';
import '../models/temp_fee.dart';
import '../models/temp_factor.dart';

class PriceCalculatorApiHandler {
  // 数据版本时间戳 - 追踪机器部件、部件、费用和系数的最后修改时间
  int _lastMachinePartsUpdate = DateTime.now().millisecondsSinceEpoch;
  int _lastPartsUpdate = DateTime.now().millisecondsSinceEpoch;
  int _lastFeesUpdate = DateTime.now().millisecondsSinceEpoch;
  int _lastFactorsUpdate = DateTime.now().millisecondsSinceEpoch;

  int get lastMachinePartsUpdate => _lastMachinePartsUpdate;
  int get lastPartsUpdate => _lastPartsUpdate;
  int get lastFeesUpdate => _lastFeesUpdate;
  int get lastFactorsUpdate => _lastFactorsUpdate;

  // 更新机器部件最后修改时间
  void updateMachinePartsTimestamp() {
    _lastMachinePartsUpdate = DateTime.now().millisecondsSinceEpoch;
    print(
        '机器部件数据版本已更新: ${DateTime.fromMillisecondsSinceEpoch(_lastMachinePartsUpdate)}');
  }

  // 更新部件最后修改时间
  void updatePartsTimestamp() {
    _lastPartsUpdate = DateTime.now().millisecondsSinceEpoch;
    print(
        '部件数据版本已更新: ${DateTime.fromMillisecondsSinceEpoch(_lastPartsUpdate)}');
  }

  // 更新费用最后修改时间
  void updateFeesTimestamp() {
    _lastFeesUpdate = DateTime.now().millisecondsSinceEpoch;
    print(
        '费用数据版本已更新: ${DateTime.fromMillisecondsSinceEpoch(_lastFeesUpdate)}');
  }

  // 更新系数最后修改时间
  void updateFactorsTimestamp() {
    _lastFactorsUpdate = DateTime.now().millisecondsSinceEpoch;
    print(
        '系数数据版本已更新: ${DateTime.fromMillisecondsSinceEpoch(_lastFactorsUpdate)}');
  }

  // 获取所有机器部件
  Future<Response> handleGetMachineParts(Request request) async {
    try {
      // 从Hive数据库中获取机器部件数据
      final machinePartsBox = Hive.box<MachinePart>('machine_parts');
      final machineParts = machinePartsBox.values.toList();

      // 将MachinePart对象转换为Map格式
      final parts = <Map<String, dynamic>>[];
      for (final part in machineParts) {
        // 首先获取基本属性
        final partMap = <String, dynamic>{
          'Model': part.model,
          'OriginalModel': part.originalModel,
          'OriginalPrice': part.originalPrice,
          'ShowPrice': part.showPrice,
          'image': part.image,
          'addedCount': part.addedCount,
        };

        // 添加otherProperties中的所有属性
        part.otherProperties.forEach((key, value) {
          partMap[key] = value;
        });

        parts.add(partMap);
      }

      return Response.ok(
        json.encode({
          'success': true, 
          'data': parts,
          'timestamp': _lastMachinePartsUpdate  // 返回当前机器部件数据的时间戳
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取机器部件失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 创建机器部件
  Future<Response> handleCreateMachinePart(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      // 需要实现实际的机器部件创建逻辑
      final machinePartsBox = Hive.box<MachinePart>('machine_parts');
      
      // 创建MachinePart对象
      final newPart = MachinePart(
        model: params['Model']?.toString() ?? params['model']?.toString() ?? '',
        originalModel: params['OriginalModel']?.toString() ?? '',
        originalPrice: (params['OriginalPrice'] as num?)?.toDouble() ?? 0.0,
        showPrice: (params['ShowPrice'] as num?)?.toDouble() ?? 0.0,
        image: params['image']?.toString() ?? '',
        addedCount: params['addedCount']?.toInt() ?? 0,
        otherProperties: _extractOtherProperties(params, {}),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: 'system',
        updatedBy: 'system',
      );
      
      // 保存到Hive数据库
      await machinePartsBox.add(newPart);
      
      // 更新机器部件数据版本时间戳
      updateMachinePartsTimestamp();
      
      // 返回成功响应，包括部件数据和时间戳信息
      return Response.ok(
        json.encode({
          'success': true, 
          'data': newPart.toJson(),
          'timestamp': _lastMachinePartsUpdate  // 返回当前机器部件数据的时间戳
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 更新机器部件
  Future<Response> handleUpdateMachinePart(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      // 检查是否是incrementAddedCount操作
      if (params['action'] == 'incrementAddedCount' &&
          params['model'] != null) {
        final model = params['model'] as String;

        final machinePartsBox = Hive.box<MachinePart>('machine_parts');

        // 遍历box中的所有项目找到匹配的model
        for (final key in machinePartsBox.keys) {
          final part = machinePartsBox.get(key)!;

          if (part.model == model) {
            // 创建更新后的MachinePart对象，增加addedCount
            final updatedPart = MachinePart(
              model: part.model,
              originalModel: part.originalModel,
              originalPrice: part.originalPrice,
              showPrice: part.showPrice,
              image: part.image,
              addedCount: part.addedCount + 1, // 增加被添加次数
              otherProperties: part.otherProperties,
              createdAt: part.createdAt, // 保持原始创建时间
              updatedAt: DateTime.now(), // 更新最后修改时间
              createdBy: part.createdBy, // 保持原始创建人
              updatedBy: 'system', // 使用系统作为更新人
            );

            // 更新到Hive数据库
            await machinePartsBox.put(key, updatedPart);

            // 更新机器部件数据版本时间戳
            updateMachinePartsTimestamp();
            
            return Response.ok(
              json.encode({
                'success': true, 
                'message': 'addedCount已更新',
                'timestamp': _lastMachinePartsUpdate  // 返回当前机器部件数据的时间戳
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        // 如果没有找到对应的机器部件
        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的机器部件'}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        // 处理普通的更新操作

        // 从URL参数获取ID（模型名称）
        final model = id; // URL中的id参数实际上是模型名称

        final machinePartsBox = Hive.box<MachinePart>('machine_parts');

        // 遍历box中的所有项目找到匹配的model
        for (final key in machinePartsBox.keys) {
          final part = machinePartsBox.get(key)!;

          if (part.model == model) {
            // 注意：如果只是addedCount变化，不更新时间戳；其他字段变化则更新时间戳
            bool isOnlyAddedCountChange =
                _isOnlyAddedCountChanged(part, params);

            // 根据参数创建更新后的MachinePart对象
            final updatedPart = MachinePart(
              model: params['Model'] ?? part.model,
              originalModel: params['OriginalModel'] ?? part.originalModel,
              originalPrice: (params['OriginalPrice'] as num)?.toDouble() ??
                  part.originalPrice,
              showPrice:
                  (params['ShowPrice'] as num)?.toDouble() ?? part.showPrice,
              image: params['image'] ?? part.image,
              addedCount: params['addedCount'] ?? part.addedCount,
              otherProperties:
                  _extractOtherProperties(params, part.otherProperties),
              createdAt: part.createdAt, // 保持原始创建时间
              updatedAt: DateTime.now(), // 更新最后修改时间
              createdBy: part.createdBy, // 保持原始创建人
              updatedBy: params['updatedBy'] ?? 'system', // 使用指定的更新人或默认为system
            );

            // 更新到Hive数据库
            await machinePartsBox.put(key, updatedPart);

            // 如果不是仅addedCount的变化，则更新数据版本时间戳
            if (!isOnlyAddedCountChange) {
              updateMachinePartsTimestamp();
              print('机器部件数据已更新: ${updatedPart.model}');
            } else {
              print('仅addedCount更新，不更新数据版本: ${updatedPart.model}');
            }

            // 返回更新后的数据
            final partMap = <String, dynamic>{
              'Model': updatedPart.model,
              'OriginalModel': updatedPart.originalModel,
              'OriginalPrice': updatedPart.originalPrice,
              'ShowPrice': updatedPart.showPrice,
              'image': updatedPart.image,
              'addedCount': updatedPart.addedCount,
              'createdAt': updatedPart.createdAt.toIso8601String(),
              'updatedAt': updatedPart.updatedAt.toIso8601String(),
              'createdBy': updatedPart.createdBy,
              'updatedBy': updatedPart.updatedBy,
            };

            updatedPart.otherProperties.forEach((key, value) {
              partMap[key] = value;
            });

            return Response.ok(
              json.encode({
                'success': true, 
                'data': partMap,
                'timestamp': _lastMachinePartsUpdate  // 返回当前机器部件数据的时间戳
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        // 如果没有找到对应的机器部件
        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的机器部件'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('更新机器部件失败: $e');

      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 删除机器部件
  Future<Response> handleDeleteMachinePart(Request request, String id) async {
    try {
      // 从Hive数据库删除机器部件
      // 这里需要实现实际的删除逻辑
      final machinePartsBox = Hive.box<MachinePart>('machine_parts');
      
      bool found = false;
      for (final key in machinePartsBox.keys) {
        final part = machinePartsBox.get(key)!;
        
        if (part.model == id) { // 机器部件使用model作为标识
          await machinePartsBox.delete(key);
          found = true;
          break;
        }
      }
      
      if (found) {
        // 更新机器部件数据版本时间戳
        updateMachinePartsTimestamp();
        
        return Response.ok(
          json.encode({
            'success': true,
            'timestamp': _lastMachinePartsUpdate  // 返回当前机器部件数据的时间戳
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的机器部件'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取部件统计信息
  Future<Response> handleGetPartsStats(Request request) async {
    try {
      // 从Hive数据库中获取机器部件和部件的数量
      final machinePartsBox = Hive.box<MachinePart>('machine_parts');
      final partsBox = Hive.box<Part>('temp_parts');

      final machinePartsCount = machinePartsBox.length;
      final partsCount = partsBox.length;

      return Response.ok(
        json.encode({
          'success': true,
          'data': {
            'machinePartsCount': machinePartsCount,
            'partsCount': partsCount,
          }
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取部件统计失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 检查数据是否有更新
  Future<Response> handleCheckDataUpdate(Request request) async {
    try {
      // 获取查询参数（客户端上次更新时间）
      final queryParams = request.url.queryParameters;
      final lastUpdateStr = queryParams['lastUpdate'];

      // 使用服务器维护的数据版本时间戳
      final lastMachinePartsUpdate = _lastMachinePartsUpdate;
      final lastPartsUpdate = _lastPartsUpdate;
      final lastFeesUpdate = _lastFeesUpdate;
      final lastFactorsUpdate = _lastFactorsUpdate;

      bool hasUpdates = false;
      if (lastUpdateStr != null) {
        final lastUpdate = int.tryParse(lastUpdateStr) ?? 0;
        hasUpdates =
            lastMachinePartsUpdate > lastUpdate || 
            lastPartsUpdate > lastUpdate ||
            lastFeesUpdate > lastUpdate ||
            lastFactorsUpdate > lastUpdate;
      } else {
        hasUpdates = true; // 如果没有提供上次更新时间，则认为有更新
      }

      return Response.ok(
        json.encode({
          'success': true,
          'hasUpdates': hasUpdates,
          'lastMachinePartsUpdate': lastMachinePartsUpdate,
          'lastPartsUpdate': lastPartsUpdate,
          'lastFeesUpdate': lastFeesUpdate,
          'lastFactorsUpdate': lastFactorsUpdate,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('检查数据更新失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取所有部件
  Future<Response> handleGetParts(Request request) async {
    try {
      // 从Hive数据库中获取部件数据
      final partsBox = Hive.box<Part>('temp_parts');
      final partsData = partsBox.values.toList();

      // 将Part对象转换为Map格式
      final parts = <Map<String, dynamic>>[];
      for (final part in partsData) {
        parts.add({
          'id': part.id,
          'model': part.model,
          'price': part.price,
          'remark': part.remark,
          'addedCount': part.addedCount,
        });
      }

      return Response.ok(
        json.encode({
          'success': true, 
          'data': parts,
          'timestamp': _lastPartsUpdate  // 返回当前部件数据的时间戳
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取部件失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 创建部件
  Future<Response> handleCreatePart(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);
      
      // 从Hive数据库获取部件
      final partsBox = Hive.box<Part>('temp_parts');
      
      final model = params['model']?.toString() ?? '';
      final name = params['name']?.toString() ?? ''; // 保留name参数用于兼容性
      final price = (params['price'] as num?)?.toDouble() ?? (params['defaultPrice'] as num?)?.toDouble() ?? 0.0; // 兼容旧字段名
      final remark = params['remark']?.toString() ?? '';
      final addedCount = params['addedCount']?.toInt() ?? 1; // 默认为1，表示被添加1次
      
      // 检查是否已存在相同型号的部件，如果是则更新而不是创建新实例
      Part? existingPart = null;
      int? existingPartKey;  // 使用int类型，因为Hive的key通常是int
      
      // 遍历box中的所有项目查找匹配的model
      for (final key in partsBox.keys) {
        final part = partsBox.get(key)!;
        if (part.model == model) {
          existingPart = part;
          existingPartKey = key as int; // Hive的key是int类型
          break;
        }
      }
      
      Part resultPart;
      
      if (existingPart != null && existingPartKey != null) {
        // 更新现有部件，增加addedCount
        resultPart = Part(
          id: existingPart.id,
          model: model,
          price: price != 0.0 ? price : existingPart.price,
          remark: remark.isNotEmpty ? remark : existingPart.remark,
          addedCount: existingPart.addedCount + 1,  // 增加被添加次数（而不是使用传入的参数）
        );
        
        // 更新到Hive数据库
        await partsBox.put(existingPartKey, resultPart);
      } else {
        // 创建新部件
        final id = 'part_${DateTime.now().millisecondsSinceEpoch}_${model.isEmpty ? 'unknown' : model}';
        
        resultPart = Part(
          id: id,
          model: model,
          price: price,
          remark: remark,
          addedCount: addedCount,
        );
        
        // 保存到Hive数据库
        await partsBox.add(resultPart);
      }
      
      // 更新部件数据版本时间戳
      updatePartsTimestamp();
      
      // 返回成功响应，包括部件数据和时间戳信息
      return Response.ok(
        json.encode({
          'success': true, 
          'data': resultPart.toJson(),
          'timestamp': _lastPartsUpdate  // 返回当前部件数据的时间戳
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('创建部件失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 更新部件
  Future<Response> handleUpdatePart(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      // 从Hive数据库获取部件
      final partsBox = Hive.box<Part>('temp_parts');
      
      // 检查是否是incrementAddedCount操作
      if (params['action'] == 'incrementAddedCount' &&
          params['model'] != null) {
        final model = params['model'] as String;

        // 遍历box中的所有项目找到匹配的model
        for (final key in partsBox.keys) {
          final part = partsBox.get(key)!;

          if (part.model == model) {
            // 创建更新后的Part对象，增加addedCount
            final updatedPart = Part(
              id: part.id,
              model: part.model,
              price: part.price,
              remark: part.remark,
              addedCount: part.addedCount + 1, // 增加被添加次数
            );

            // 更新到Hive数据库
            await partsBox.put(key, updatedPart);

            // 更新部件数据版本时间戳
            updatePartsTimestamp();
            
            print('部件使用次数已更新: ${updatedPart.model}, 次数: ${updatedPart.addedCount}');

            return Response.ok(
              json.encode({
                'success': true,
                'data': updatedPart.toJson(),
                'timestamp': _lastPartsUpdate // 返回当前部件数据的时间戳
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的部件'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 遍历box中的所有项目找到匹配的id
      for (final key in partsBox.keys) {
        final part = partsBox.get(key)!;
        
        if (part.id == id) {
          // 创建更新后的Part对象
          final updatedPart = Part(
            id: part.id,
            model: params['model'] ?? part.model,
            price: (params['price'] as num?)?.toDouble() ?? (params['defaultPrice'] as num?)?.toDouble() ?? part.price, // 兼容旧字段名
            remark: params['remark'] ?? part.remark,
            addedCount: params['addedCount'] ?? part.addedCount,
          );
          
          // 更新到Hive数据库
          await partsBox.put(key, updatedPart);
          
          // 更新部件数据版本时间戳
          updatePartsTimestamp();
          
          return Response.ok(
            json.encode({
              'success': true, 
              'data': updatedPart.toJson(),
              'timestamp': _lastPartsUpdate  // 返回当前部件数据的时间戳
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }
      
      // 如果没有找到对应的部件
      return Response.notFound(
        json.encode({'success': false, 'error': '未找到对应的部件'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('更新部件失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 删除部件
  Future<Response> handleDeletePart(Request request, String id) async {
    try {
      // 从Hive数据库删除部件
      final partsBox = Hive.box<Part>('temp_parts');
      
      // 遍历box中的所有项目找到匹配的id
      bool found = false;
      for (final key in partsBox.keys) {
        final part = partsBox.get(key)!;
        
        if (part.id == id) {
          await partsBox.delete(key);
          found = true;
          break;
        }
      }
      
      if (found) {
        // 更新部件数据版本时间戳
        updatePartsTimestamp();
        
        return Response.ok(
          json.encode({
            'success': true,
            'timestamp': _lastPartsUpdate  // 返回当前部件数据的时间戳
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的部件'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('删除部件失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取最常用的部件
  Future<Response> handleGetTopUsedParts(Request request) async {
    try {
      final box = Hive.box<Part>('temp_parts');
      final parts = box.values.toList();

      // 按被添加次数排序并取前5个
      parts.sort((a, b) => b.addedCount.compareTo(a.addedCount));
      final topParts = parts.take(5).toList();

      final partsData = <Map<String, dynamic>>[];
      for (final part in topParts) {
        final partMap = <String, dynamic>{};
        partMap['id'] = part.id;
        partMap['model'] = part.model;
        partMap['price'] = part.price;
        partMap['remark'] = part.remark;
        partMap['addedCount'] = part.addedCount;
        partsData.add(partMap);
      }

      return Response.ok(
        json.encode({'success': true, 'data': partsData}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取最常用部件失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取最常用的费用
  Future<Response> handleGetTopUsedFees(Request request) async {
    try {
      // 从Hive数据库中获取临时费用数据
      final box = Hive.box<TempFee>('temp_fees');
      final fees = box.values.toList();

      // 按被添加次数排序并取前5个
      fees.sort((a, b) => b.addedCount.compareTo(a.addedCount));
      final topFees = fees.take(5).toList();

      final feesData = <Map<String, dynamic>>[];
      for (final fee in topFees) {
        final feeMap = <String, dynamic>{};
        feeMap['name'] = fee.name;
        feeMap['value'] = fee.value;
        feeMap['addedCount'] = fee.addedCount;
        feesData.add(feeMap);
      }

      return Response.ok(
        json.encode({
          'success': true, 
          'data': feesData,
          'timestamp': _lastPartsUpdate  // 使用parts的时间戳，因为费用也是价格计算器的一部分
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取最常用费用失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取最常用的系数
  Future<Response> handleGetTopUsedFactors(Request request) async {
    try {
      // 从Hive数据库中获取临时系数数据
      final box = Hive.box<TempFactor>('temp_factors');
      final factors = box.values.toList();

      // 按被添加次数排序并取前5个
      factors.sort((a, b) => b.addedCount.compareTo(a.addedCount));
      final topFactors = factors.take(5).toList();

      final factorsData = <Map<String, dynamic>>[];
      for (final factor in topFactors) {
        final factorMap = <String, dynamic>{};
        factorMap['name'] = factor.name;
        factorMap['value'] = factor.value;
        factorMap['addedCount'] = factor.addedCount;
        factorsData.add(factorMap);
      }

      return Response.ok(
        json.encode({
          'success': true, 
          'data': factorsData,
          'timestamp': _lastPartsUpdate  // 使用parts的时间戳，因为系数也是价格计算器的一部分
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取最常用系数失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 检查是否仅仅是addedCount字段发生了变化
  bool _isOnlyAddedCountChanged(MachinePart part, Map<String, dynamic> params) {
    // 检查除了addedCount之外的其他字段是否发生变化
    if ((params['Model'] != null && params['Model'] != part.model) ||
        (params['OriginalModel'] != null &&
            params['OriginalModel'] != part.originalModel) ||
        (params['OriginalPrice'] != null &&
            (params['OriginalPrice'] as num).toDouble() !=
                part.originalPrice) ||
        (params['ShowPrice'] != null &&
            (params['ShowPrice'] as num).toDouble() != part.showPrice) ||
        (params['image'] != null && params['image'] != part.image) ||
        (params['createdAt'] != null &&
            params['createdAt'] != part.createdAt.toIso8601String()) ||
        (params['updatedAt'] != null &&
            params['updatedAt'] != part.updatedAt.toIso8601String()) ||
        (params['createdBy'] != null &&
            params['createdBy'] != part.createdBy) ||
        (params['updatedBy'] != null &&
            params['updatedBy'] != part.updatedBy)) {
      // 检查otherProperties中的字段是否发生变化
      for (final key in params.keys) {
        if (![
          'Model',
          'OriginalModel',
          'OriginalPrice',
          'ShowPrice',
          'image',
          'addedCount',
          'createdAt',
          'updatedAt',
          'createdBy',
          'updatedBy',
          'action'
        ].contains(key)) {
          if (part.otherProperties.containsKey(key) &&
              part.otherProperties[key] != params[key]) {
            return false; // 发现otherProperties中的字段变化
          } else if (!part.otherProperties.containsKey(key) &&
              params[key] != null) {
            return false; // 发现新增的otherProperties字段
          }
        }
      }
      return false; // 有其他字段变化
    }

    // 检查otherProperties的长度是否变化
    int paramsOtherPropsCount = 0;
    for (final key in params.keys) {
      if (![
        'Model',
        'OriginalModel',
        'OriginalPrice',
        'ShowPrice',
        'image',
        'addedCount',
        'createdAt',
        'updatedAt',
        'createdBy',
        'updatedBy',
        'action'
      ].contains(key)) {
        paramsOtherPropsCount++;
      }
    }

    if (part.otherProperties.length != paramsOtherPropsCount) {
      return false; // otherProperties的长度变化
    }

    return true; // 只有addedCount变化或没有变化
  }

  // 检查费用是否仅仅是addedCount字段发生了变化
  bool _isOnlyAddedCountChangedForFee(TempFee fee, Map<String, dynamic> params) {
    // 检查除了addedCount之外的其他字段是否发生变化
    if ((params['name'] != null && params['name'] != fee.name) ||
        (params['Model'] != null && params['Model'] != fee.name) ||
        (params['model'] != null && params['model'] != fee.name) ||
        (params['value'] != null && 
            (params['value'] as num).toDouble() != fee.value) ||
        (params['defaultAmount'] != null && 
            (params['defaultAmount'] as num).toDouble() != fee.value) ||
        (params['price'] != null && 
            (params['price'] as num).toDouble() != fee.value)) {
      return false; // 有其他字段变化
    }
    return true; // 只有addedCount变化或没有变化
  }

  // 检查系数是否仅仅是addedCount字段发生了变化
  bool _isOnlyAddedCountChangedForFactor(TempFactor factor, Map<String, dynamic> params) {
    // 检查除了addedCount之外的其他字段是否发生变化
    if ((params['name'] != null && params['name'] != factor.name) ||
        (params['Model'] != null && params['Model'] != factor.name) ||
        (params['model'] != null && params['model'] != factor.name) ||
        (params['value'] != null && 
            (params['value'] as num).toDouble() != factor.value) ||
        (params['defaultValue'] != null && 
            (params['defaultValue'] as num).toDouble() != factor.value) ||
        (params['price'] != null && 
            (params['price'] as num).toDouble() != factor.value)) {
      return false; // 有其他字段变化
    }
    return true; // 只有addedCount变化或没有变化
  }

  // 从参数中提取otherProperties
  Map<String, String> _extractOtherProperties(Map<String, dynamic> params,
      Map<String, String> existingOtherProperties) {
    final Map<String, String> otherProperties =
        Map.from(existingOtherProperties);

    // 添加或更新参数中提供的其他属性
    for (final key in params.keys) {
      if (![
        'Model',
        'OriginalModel',
        'OriginalPrice',
        'ShowPrice',
        'image',
        'addedCount',
        'createdAt',
        'updatedAt',
        'createdBy',
        'updatedBy',
        'action'
      ].contains(key)) {
        otherProperties[key] = params[key]?.toString() ?? '';
      }
    }

    return otherProperties;
  }
  
  // 获取费用
  Future<Response> handleGetTempFees(Request request) async {
    try {
      final feesBox = Hive.box<TempFee>('temp_fees');
      final fees = feesBox.values.toList();

      final feesData = <Map<String, dynamic>>[];
      for (final fee in fees) {
        feesData.add({
          'name': fee.name,
          'value': fee.value,
          'addedCount': fee.addedCount,
        });
      }

      return Response.ok(
        json.encode({
          'success': true, 
          'data': feesData,
          'timestamp': _lastPartsUpdate  // 使用parts的时间戳
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取费用失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 创建费用
  Future<Response> handleCreateTempFee(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final feesBox = Hive.box<TempFee>('temp_fees');
      
      final name = params['name']?.toString() ?? params['Model']?.toString() ?? params['model']?.toString() ?? '';
      final value = (params['value'] as num?)?.toDouble() ?? (params['defaultAmount'] as num?)?.toDouble() ?? (params['price'] as num?)?.toDouble() ?? 0.0;
      final addedCount = params['addedCount']?.toInt() ?? params['usageCount']?.toInt() ?? 1; // 默认为1次添加
      final action = params['action']?.toString() ?? ''; // 操作类型
      
      // 检查是否已存在相同名称的费用，如果是则更新而不是创建新实例
      TempFee? existingFee = null;
      int? existingFeeKey;  // 使用int类型，因为Hive的key通常是int
      
      // 遍历box中的所有项目查找匹配的name
      for (final key in feesBox.keys) {
        final fee = feesBox.get(key)!;
        if (fee.name == name) {
          existingFee = fee;
          existingFeeKey = key as int; // Hive的key是int类型
          break;
        }
      }
      
      TempFee resultFee;
      
      if (existingFee != null && existingFeeKey != null) {
        // 更新现有费用，增加addedCount
        resultFee = TempFee(
          name: name,
          value: value != 0.0 ? value : existingFee.value,
          addedCount: existingFee.addedCount + 1,  // 增加被添加次数（而不是使用传入的参数）
        );
        
        // 更新到Hive数据库
        await feesBox.put(existingFeeKey, resultFee);
      } else {
        // 创建新费用
        resultFee = TempFee(
          name: name,
          value: value,
          addedCount: addedCount,
        );
        
        // 保存到Hive数据库
        await feesBox.add(resultFee);
      }
      
      // 更新费用数据版本时间戳
      updateFeesTimestamp();
      
      // 返回成功响应，包括费用数据和时间戳信息
      return Response.ok(
        json.encode({
          'success': true, 
          'data': resultFee.toJson(),
          'timestamp': _lastFeesUpdate,  // 返回当前费用数据的时间戳
          'action': action  // 返回操作类型
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('创建费用失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 更新费用
  Future<Response> handleUpdateTempFee(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final feesBox = Hive.box<TempFee>('temp_fees');
      
      // 检查是否是incrementAddedCount操作
      if (params['action'] == 'incrementAddedCount' &&
          params['name'] != null) {
        final name = params['name'] as String;

        // 在Hive中，TempFee没有ID，所以我们需要通过name来匹配
        for (final key in feesBox.keys) {
          final fee = feesBox.get(key)!;

          if (fee.name == name) {
            // 创建更新后的TempFee对象，增加addedCount
            final updatedFee = TempFee(
              name: fee.name,
              value: fee.value,
              addedCount: fee.addedCount + 1, // 增加被添加次数
            );

            // 更新到Hive数据库
            await feesBox.put(key, updatedFee);

            // 更新费用数据版本时间戳
            updateFeesTimestamp();
            
            print('费用使用次数已更新: ${updatedFee.name}, 次数: ${updatedFee.addedCount}');

            return Response.ok(
              json.encode({
                'success': true,
                'data': updatedFee.toJson(),
                'timestamp': _lastFeesUpdate // 返回当前费用数据的时间戳
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的费用'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 在Hive中，TempFee没有ID，所以我们需要通过name来匹配
      // 这里我们假设URL参数id实际上是name
      for (final key in feesBox.keys) {
        final fee = feesBox.get(key)!;
        
        // 检查name是否匹配（兼容多种可能的字段名）
        if (fee.name == id || 
            fee.name == params['name']?.toString() || 
            fee.name == params['Model']?.toString()) {
          final updatedFee = TempFee(
            name: params['name'] ?? params['Model'] ?? fee.name,
            value: (params['value'] as num?)?.toDouble() ?? (params['defaultAmount'] as num?)?.toDouble() ?? (params['price'] as num?)?.toDouble() ?? fee.value,
            addedCount: params['addedCount'] ?? params['usageCount'] ?? fee.addedCount,
          );
          
          await feesBox.put(key, updatedFee);
          
          // 检查是否是仅addedCount字段的变化
          bool isOnlyAddedCountChange = _isOnlyAddedCountChangedForFee(fee, params);
          
          // 如果不是仅addedCount的变化，则更新数据版本时间戳
          if (!isOnlyAddedCountChange) {
            updateFeesTimestamp();
            print('费用数据版本已更新（非addedCount字段变化）: ${updatedFee.name}');
          } else {
            print('仅addedCount更新，不更新费用数据版本: ${updatedFee.name}');
          }
          
          return Response.ok(
            json.encode({
              'success': true, 
              'data': updatedFee.toJson(),
              'timestamp': _lastFeesUpdate  // 返回当前费用数据的时间戳
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }
      
      return Response.notFound(
        json.encode({'success': false, 'error': '未找到对应的费用'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('更新费用失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 删除费用
  Future<Response> handleDeleteTempFee(Request request, String id) async {
    try {
      final feesBox = Hive.box<TempFee>('temp_fees');
      
      bool found = false;
      for (final key in feesBox.keys) {
        final fee = feesBox.get(key)!;
        
        // 检查name是否匹配
        if (fee.name == id || 
            fee.name == Uri.decodeComponent(id)) {  // 解码URL参数
          await feesBox.delete(key);
          found = true;
          break;
        }
      }
      
      if (found) {
        // 更新费用数据版本时间戳
        updateFeesTimestamp();
        
        return Response.ok(
          json.encode({
            'success': true,
            'timestamp': _lastFeesUpdate  // 返回当前费用数据的时间戳
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的费用'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('删除费用失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取系数
  Future<Response> handleGetTempFactors(Request request) async {
    try {
      final factorsBox = Hive.box<TempFactor>('temp_factors');
      final factors = factorsBox.values.toList();

      final factorsData = <Map<String, dynamic>>[];
      for (final factor in factors) {
        factorsData.add({
          'name': factor.name,
          'value': factor.value,
          'addedCount': factor.addedCount,
        });
      }

      return Response.ok(
        json.encode({
          'success': true, 
          'data': factorsData,
          'timestamp': _lastPartsUpdate  // 使用parts的时间戳
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取系数失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 创建系数
  Future<Response> handleCreateTempFactor(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final factorsBox = Hive.box<TempFactor>('temp_factors');
      
      final name = params['name']?.toString() ?? params['Model']?.toString() ?? params['model']?.toString() ?? '';
      final value = (params['value'] as num?)?.toDouble() ?? (params['defaultValue'] as num?)?.toDouble() ?? (params['price'] as num?)?.toDouble() ?? 0.0;
      final addedCount = params['addedCount']?.toInt() ?? params['usageCount']?.toInt() ?? 1; // 默认为1次添加
      final action = params['action']?.toString() ?? ''; // 操作类型
      
      // 检查是否已存在相同名称的系数，如果是则更新而不是创建新实例
      TempFactor? existingFactor = null;
      int? existingFactorKey;  // 使用int类型，因为Hive的key通常是int
      
      // 遍历box中的所有项目查找匹配的name
      for (final key in factorsBox.keys) {
        final factor = factorsBox.get(key)!;
        if (factor.name == name) {
          existingFactor = factor;
          existingFactorKey = key as int; // Hive的key是int类型
          break;
        }
      }
      
      TempFactor resultFactor;
      
      if (existingFactor != null && existingFactorKey != null) {
        // 更新现有系数，增加addedCount
        resultFactor = TempFactor(
          name: name,
          value: value != 0.0 ? value : existingFactor.value,
          addedCount: existingFactor.addedCount + 1,  // 增加被添加次数（而不是使用传入的参数）
        );
        
        // 更新到Hive数据库
        await factorsBox.put(existingFactorKey, resultFactor);
      } else {
        // 创建新系数
        resultFactor = TempFactor(
          name: name,
          value: value,
          addedCount: addedCount,
        );
        
        // 保存到Hive数据库
        await factorsBox.add(resultFactor);
      }
      
      // 更新系数数据版本时间戳
      updateFactorsTimestamp();
      
      // 返回成功响应，包括系数数据和时间戳信息
      return Response.ok(
        json.encode({
          'success': true, 
          'data': resultFactor.toJson(),
          'timestamp': _lastFactorsUpdate,  // 返回当前系数数据的时间戳
          'action': action  // 返回操作类型
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('创建系数失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 更新系数
  Future<Response> handleUpdateTempFactor(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final factorsBox = Hive.box<TempFactor>('temp_factors');
      
      // 检查是否是incrementAddedCount操作
      if (params['action'] == 'incrementAddedCount' &&
          params['name'] != null) {
        final name = params['name'] as String;

        // 在Hive中，TempFactor没有ID，所以我们需要通过name来匹配
        for (final key in factorsBox.keys) {
          final factor = factorsBox.get(key)!;

          if (factor.name == name) {
            // 创建更新后的TempFactor对象，增加addedCount
            final updatedFactor = TempFactor(
              name: factor.name,
              value: factor.value,
              addedCount: factor.addedCount + 1, // 增加被添加次数
            );

            // 更新到Hive数据库
            await factorsBox.put(key, updatedFactor);

            // 更新系数数据版本时间戳
            updateFactorsTimestamp();
            
            print('系数使用次数已更新: ${updatedFactor.name}, 次数: ${updatedFactor.addedCount}');

            return Response.ok(
              json.encode({
                'success': true,
                'data': updatedFactor.toJson(),
                'timestamp': _lastFactorsUpdate // 返回当前系数数据的时间戳
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的系数'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 在Hive中，TempFactor没有ID，所以我们需要通过name来匹配
      for (final key in factorsBox.keys) {
        final factor = factorsBox.get(key)!;
        
        // 检查name是否匹配（兼容多种可能的字段名）
        if (factor.name == id || 
            factor.name == params['name']?.toString() || 
            factor.name == params['Model']?.toString()) {
          final updatedFactor = TempFactor(
            name: params['name'] ?? params['Model'] ?? factor.name,
            value: (params['value'] as num?)?.toDouble() ?? (params['defaultValue'] as num?)?.toDouble() ?? (params['price'] as num?)?.toDouble() ?? factor.value,
            addedCount: params['addedCount'] ?? params['usageCount'] ?? factor.addedCount,
          );
          
          await factorsBox.put(key, updatedFactor);
          
          // 检查是否是仅addedCount字段的变化
          bool isOnlyAddedCountChange = _isOnlyAddedCountChangedForFactor(factor, params);
          
          // 如果不是仅addedCount的变化，则更新数据版本时间戳
          if (!isOnlyAddedCountChange) {
            updateFactorsTimestamp();
            print('系数数据版本已更新（非addedCount字段变化）: ${updatedFactor.name}');
          } else {
            print('仅addedCount更新，不更新系数数据版本: ${updatedFactor.name}');
          }
          
          return Response.ok(
            json.encode({
              'success': true, 
              'data': updatedFactor.toJson(),
              'timestamp': _lastFactorsUpdate  // 返回当前系数数据的时间戳
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }
      }
      
      return Response.notFound(
        json.encode({'success': false, 'error': '未找到对应的系数'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('更新系数失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 删除系数
  Future<Response> handleDeleteTempFactor(Request request, String id) async {
    try {
      final factorsBox = Hive.box<TempFactor>('temp_factors');
      
      bool found = false;
      for (final key in factorsBox.keys) {
        final factor = factorsBox.get(key)!;
        
        // 检查name是否匹配
        if (factor.name == id || 
            factor.name == Uri.decodeComponent(id)) {  // 解码URL参数
          await factorsBox.delete(key);
          found = true;
          break;
        }
      }
      
      if (found) {
        // 更新系数数据版本时间戳
        updateFactorsTimestamp();
        
        return Response.ok(
          json.encode({
            'success': true,
            'timestamp': _lastFactorsUpdate  // 返回当前系数数据的时间戳
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的系数'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('删除系数失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}