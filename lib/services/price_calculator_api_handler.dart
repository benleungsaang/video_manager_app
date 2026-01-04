import 'package:shelf/shelf.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/machine.dart';
import '../models/part.dart';
import '../models/temp_fee.dart';
import '../models/temp_factor.dart';

class PriceCalculatorApiHandler {
  // 数据版本时间戳 - 追踪机器、部件、费用和系数的最后修改时间
  int _lastMachinesUpdate = DateTime.now().millisecondsSinceEpoch;
  int _lastPartsUpdate = DateTime.now().millisecondsSinceEpoch;
  int _lastFeesUpdate = DateTime.now().millisecondsSinceEpoch;
  int _lastFactorsUpdate = DateTime.now().millisecondsSinceEpoch;

  int get lastMachinesUpdate => _lastMachinesUpdate;
  int get lastPartsUpdate => _lastPartsUpdate;
  int get lastFeesUpdate => _lastFeesUpdate;
  int get lastFactorsUpdate => _lastFactorsUpdate;

  // 更新机器最后修改时间
  void updateMachinesTimestamp() {
    _lastMachinesUpdate = DateTime.now().millisecondsSinceEpoch;
    print(
        '机器数据版本已更新: ${DateTime.fromMillisecondsSinceEpoch(_lastMachinesUpdate)}');
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

      // 获取所有机器
  Future<Response> handleGetMachines(Request request) async {
    try {
      // 从Hive数据库中获取机器数据
      final machinesBox = Hive.box<Machine>('machines');
      final machines = machinesBox.values.toList();

      // 将Machine对象转换为Map格式
      final machinesList = <Map<String, dynamic>>[];

      for (final machine in machines) {
        // 首先获取基本属性
        final machineMap = <String, dynamic>{
          'id': machine.id, // ID现在是必需的，不会为null
          'Model': machine.model,
          'OriginalModel': machine.originalModel,
          'OriginalPrice': machine.originalPrice,
          'ShowPrice': machine.showPrice,
          'image': machine.image,
          'addedCount': machine.addedCount,
        };

        // 添加otherProperties中的所有属性
        machine.otherProperties.forEach((key, value) {
          machineMap[key] = value;
        });

        machinesList.add(machineMap);
      }

      // 更新时间戳
      updateMachinesTimestamp();

      // 生成响应数据，包含数据和时间戳
      final responseData = {
        'data': machinesList,
        'timestamp': _lastMachinesUpdate, // 添加时间戳信息
      };

      return Response.ok(
        json.encode(responseData),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取机器数据失败: $e');
      return Response.internalServerError(
        body: json.encode({'error': '获取机器数据失败'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }



  // 创建机器
  Future<Response> handleCreateMachine(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      // 需要实现实际的机器创建逻辑
      final machinesBox = Hive.box<Machine>('machines');
      
      // 创建Machine对象，ID将自动生成
      final newMachine = Machine(
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
      await machinesBox.add(newMachine);
      
      // 更新机器数据版本时间戳
      updateMachinesTimestamp();
      
      // 返回成功响应，包括机器数据和时间戳信息
      return Response.ok(
        json.encode({
          'success': true, 
          'data': newMachine.toJson(),
          'timestamp': _lastMachinesUpdate  // 返回当前机器数据的时间戳
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

  // 更新机器
  Future<Response> handleUpdateMachine(Request request, String id) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      // 解码URL参数，处理空格和特殊字符
      String decodedId = Uri.decodeComponent(id);

      // 检查是否是incrementAddedCount操作
      if (params['action'] == 'incrementAddedCount' &&
          params['model'] != null) {
        final model = params['model'] as String;
        final decodedModel = Uri.decodeComponent(model);

        final machinesBox = Hive.box<Machine>('machines');

        // 遍历box中的所有项目找到匹配的model
        for (final key in machinesBox.keys) {
          final machine = machinesBox.get(key)!;

          if (machine.model == decodedModel) {
            // 创建更新后的Machine对象，增加addedCount
            final updatedMachine = Machine(
              model: machine.model,
              originalModel: machine.originalModel,
              originalPrice: machine.originalPrice,
              showPrice: machine.showPrice,
              image: machine.image,
              addedCount: machine.addedCount + 1, // 增加被添加次数
              otherProperties: machine.otherProperties,
              createdAt: machine.createdAt, // 保持原始创建时间
              updatedAt: DateTime.now(), // 更新最后修改时间
              createdBy: machine.createdBy, // 保持原始创建人
              updatedBy: 'system', // 使用系统作为更新人
            );

            // 更新到Hive数据库
            await machinesBox.put(key, updatedMachine);

            // 更新机器数据版本时间戳
            updateMachinesTimestamp();
            
            return Response.ok(
              json.encode({
                'success': true, 
                'message': 'addedCount已更新',
                'timestamp': _lastMachinesUpdate  // 返回当前机器数据的时间戳
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        // 如果没有找到对应的机器
        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的机器'}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        // 处理普通的更新操作

        // 从URL参数获取ID（模型名称）
        final model = decodedId; // URL中的id参数实际上是模型名称

        final machinesBox = Hive.box<Machine>('machines');

        // 遍历box中的所有项目找到匹配的model
        for (final key in machinesBox.keys) {
          final machine = machinesBox.get(key)!;

          if (machine.model == model) {
            // 注意：如果只是addedCount变化，不更新时间戳；其他字段变化则更新时间戳
            bool isOnlyAddedCountChange =
                _isOnlyAddedCountChangedForMachine(machine, params);

            // 根据参数创建更新后的Machine对象
            final updatedMachine = Machine(
              model: params['Model'] ?? machine.model,
              originalModel: params['OriginalModel'] ?? machine.originalModel,
              originalPrice: (params['OriginalPrice'] as num)?.toDouble() ??
                  machine.originalPrice,
              showPrice:
                  (params['ShowPrice'] as num)?.toDouble() ?? machine.showPrice,
              image: params['image'] ?? machine.image,
              addedCount: params['addedCount'] ?? machine.addedCount,
              otherProperties:
                  _extractOtherProperties(params, machine.otherProperties),
              createdAt: machine.createdAt, // 保持原始创建时间
              updatedAt: DateTime.now(), // 更新最后修改时间
              createdBy: machine.createdBy, // 保持原始创建人
              updatedBy: params['updatedBy'] ?? 'system', // 使用指定的更新人或默认为system
            );

            // 更新到Hive数据库
            await machinesBox.put(key, updatedMachine);

            // 如果不是仅addedCount的变化，则更新数据版本戳
            if (!isOnlyAddedCountChange) {
              updateMachinesTimestamp();
              print('机器数据已更新: ${updatedMachine.model}');
            } else {
              print('仅addedCount更新，不更新数据版本: ${updatedMachine.model}');
            }

            // 返回更新后的数据
            final partMap = <String, dynamic>{
              'id': updatedMachine.id,
              'Model': updatedMachine.model,
              'OriginalModel': updatedMachine.originalModel,
              'OriginalPrice': updatedMachine.originalPrice,
              'ShowPrice': updatedMachine.showPrice,
              'image': updatedMachine.image,
              'addedCount': updatedMachine.addedCount,
              'createdAt': updatedMachine.createdAt.toIso8601String(),
              'updatedAt': updatedMachine.updatedAt.toIso8601String(),
              'createdBy': updatedMachine.createdBy,
              'updatedBy': updatedMachine.updatedBy,
            };

            updatedMachine.otherProperties.forEach((key, value) {
              partMap[key] = value;
            });

            return Response.ok(
              json.encode({
                'success': true, 
                'data': partMap,
                'timestamp': _lastMachinesUpdate  // 返回当前机器数据的时间戳
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        // 如果没有找到对应的机器
        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的机器'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('更新机器失败: $e');

      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 删除机器
  Future<Response> handleDeleteMachine(Request request, String id) async {
    try {
      // 从Hive数据库删除机器
      // 这里需要实现实际的删除逻辑
      final machinesBox = Hive.box<Machine>('machines');
      
      // 解码URL参数，处理空格和特殊字符
      String decodedId = Uri.decodeComponent(id);
      
      bool found = false;
      for (final key in machinesBox.keys) {
        final machine = machinesBox.get(key)!;
        
        if (machine.model == decodedId) { // 机器使用model作为标识
          await machinesBox.delete(key);
          found = true;
          break;
        }
      }
      
      if (found) {
        // 更新机器数据版本时间戳
        updateMachinesTimestamp();
        
        return Response.ok(
          json.encode({
            'success': true,
            'timestamp': _lastMachinesUpdate  // 返回当前机器数据的时间戳
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.notFound(
          json.encode({'success': false, 'error': '未找到对应的机器'}),
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
      // 从Hive数据库中获取机器和部件的数量
      final machinesBox = Hive.box<Machine>('machines');
      final partsBox = Hive.box<Part>('temp_parts');

      final machinesCount = machinesBox.length;
      final partsCount = partsBox.length;

      return Response.ok(
        json.encode({
          'success': true,
          'data': {
            'machinesCount': machinesCount,
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
      final lastMachinesUpdate = _lastMachinesUpdate;
      final lastPartsUpdate = _lastPartsUpdate;
      final lastFeesUpdate = _lastFeesUpdate;
      final lastFactorsUpdate = _lastFactorsUpdate;

      bool hasUpdates = false;
      if (lastUpdateStr != null) {
        final lastUpdate = int.tryParse(lastUpdateStr) ?? 0;
        hasUpdates =
            lastMachinesUpdate > lastUpdate || 
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
          'lastMachinesUpdate': lastMachinesUpdate,
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
        final uuid = Uuid();
        final id = uuid.v4(); // 生成UUID
        
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
      
      // 解码URL参数，处理空格和特殊字符
      String decodedId = Uri.decodeComponent(id);
      
      // 检查是否是incrementAddedCount操作
      if (params['action'] == 'incrementAddedCount' &&
          params['model'] != null) {
        final model = params['model'] as String;
        final decodedModel = Uri.decodeComponent(model);

        // 遍历box中的所有项目找到匹配的model
        for (final key in partsBox.keys) {
          final part = partsBox.get(key)!;

          if (part.model == decodedModel) {
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
        
        if (part.id == decodedId) {
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
      
      // 解码URL参数，处理空格和特殊字符
      String decodedId = Uri.decodeComponent(id);
      
      // 遍历box中的所有项目找到匹配的id
      bool found = false;
      for (final key in partsBox.keys) {
        final part = partsBox.get(key)!;
        
        if (part.id == decodedId) {
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

  // 检查机器是否仅仅是addedCount字段发生了变化
  bool _isOnlyAddedCountChangedForMachine(Machine machine, Map<String, dynamic> params) {
    // 检查除了addedCount之外的其他字段是否发生变化
    if ((params['Model'] != null && params['Model'] != machine.model) ||
        (params['OriginalModel'] != null &&
            params['OriginalModel'] != machine.originalModel) ||
        (params['OriginalPrice'] != null &&
            (params['OriginalPrice'] as num).toDouble() !=
                machine.originalPrice) ||
        (params['ShowPrice'] != null &&
            (params['ShowPrice'] as num).toDouble() != machine.showPrice) ||
        (params['image'] != null && params['image'] != machine.image) ||
        (params['createdAt'] != null &&
            params['createdAt'] != machine.createdAt.toIso8601String()) ||
        (params['updatedAt'] != null &&
            params['updatedAt'] != machine.updatedAt.toIso8601String()) ||
        (params['createdBy'] != null &&
            params['createdBy'] != machine.createdBy) ||
        (params['updatedBy'] != null &&
            params['updatedBy'] != machine.updatedBy)) {
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
          if (machine.otherProperties.containsKey(key) &&
              machine.otherProperties[key] != params[key]) {
            return false; // 发现otherProperties中的字段变化
          } else if (!machine.otherProperties.containsKey(key) &&
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

    if (machine.otherProperties.length != paramsOtherPropsCount) {
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
          'id': fee.id,
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
          id: existingFee.id,
          name: name,
          value: value != 0.0 ? value : existingFee.value,
          addedCount: existingFee.addedCount + 1,  // 增加被添加次数（而不是使用传入的参数）
        );
        
        // 更新到Hive数据库
        await feesBox.put(existingFeeKey, resultFee);
      } else {
        // 创建新费用
        final uuid = Uuid();
        final id = uuid.v4(); // 生成UUID
        
        resultFee = TempFee(
          id: id,
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
      
      // 解码URL参数，处理空格和特殊字符
      String decodedId = Uri.decodeComponent(id);
      
      // 检查是否是incrementAddedCount操作
      if (params['action'] == 'incrementAddedCount' &&
          params['name'] != null) {
        final name = params['name'] as String;
        final decodedName = Uri.decodeComponent(name);

        for (final key in feesBox.keys) {
          final fee = feesBox.get(key)!;

          if (fee.id == decodedId || fee.name == decodedName) {
            // 创建更新后的TempFee对象，增加addedCount
            final updatedFee = TempFee(
              id: fee.id,
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

      // 遍历box中的所有项目找到匹配的ID或name
      for (final key in feesBox.keys) {
        final fee = feesBox.get(key)!;
        
        if (fee.id == decodedId) {
          final updatedFee = TempFee(
            id: fee.id,
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
      
      // 解码URL参数，处理空格和特殊字符
      String decodedId = Uri.decodeComponent(id);
      
      bool found = false;
      for (final key in feesBox.keys) {
        final fee = feesBox.get(key)!;
        
        // 检查ID是否匹配
        if (fee.id == decodedId) {
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
          'id': factor.id,
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
          id: existingFactor.id,
          name: name,
          value: value != 0.0 ? value : existingFactor.value,
          addedCount: existingFactor.addedCount + 1,  // 增加被添加次数（而不是使用传入的参数）
        );
        
        // 更新到Hive数据库
        await factorsBox.put(existingFactorKey, resultFactor);
      } else {
        // 创建新系数
        final uuid = Uuid();
        final id = uuid.v4(); // 生成UUID
        
        resultFactor = TempFactor(
          id: id,
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
      
      // 解码URL参数，处理空格和特殊字符
      String decodedId = Uri.decodeComponent(id);
      
      // 检查是否是incrementAddedCount操作
      if (params['action'] == 'incrementAddedCount' &&
          params['name'] != null) {
        final name = params['name'] as String;
        final decodedName = Uri.decodeComponent(name);

        for (final key in factorsBox.keys) {
          final factor = factorsBox.get(key)!;

          if (factor.id == decodedId || factor.name == decodedName) {
            // 创建更新后的TempFactor对象，增加addedCount
            final updatedFactor = TempFactor(
              id: factor.id,
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

      // 遍历box中的所有项目找到匹配的ID或name
      for (final key in factorsBox.keys) {
        final factor = factorsBox.get(key)!;
        
        if (factor.id == decodedId) {
          final updatedFactor = TempFactor(
            id: factor.id,
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
      
      // 解码URL参数，处理空格和特殊字符
      String decodedId = Uri.decodeComponent(id);
      
      bool found = false;
      for (final key in factorsBox.keys) {
        final factor = factorsBox.get(key)!;
        
        // 检查ID是否匹配
        if (factor.id == decodedId) {
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

  // 清空机器部件数据库
  Future<Response> handleClearMachineParts(Request request) async {
    try {
      final machinesBox = Hive.box<Machine>('machines');
      
      // 清空Box中的所有数据
      await machinesBox.clear();
      
      // 更新机器数据版本时间戳
      updateMachinesTimestamp();
      
      return Response.ok(
        json.encode({
          'success': true,
          'message': '机器数据库已清空',
          'timestamp': _lastMachinesUpdate
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('清空机器部件数据库失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 清空部件数据库
  Future<Response> handleClearParts(Request request) async {
    try {
      final partsBox = Hive.box<Part>('temp_parts');
      
      // 清空Box中的所有数据
      await partsBox.clear();
      
      // 更新部件数据版本时间戳
      updatePartsTimestamp();
      
      return Response.ok(
        json.encode({
          'success': true,
          'message': '部件数据库已清空',
          'timestamp': _lastPartsUpdate
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('清空部件数据库失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 清空费用数据库
  Future<Response> handleClearTempFees(Request request) async {
    try {
      final feesBox = Hive.box<TempFee>('temp_fees');
      
      // 清空Box中的所有数据
      await feesBox.clear();
      
      // 更新费用数据版本时间戳
      updateFeesTimestamp();
      
      return Response.ok(
        json.encode({
          'success': true,
          'message': '费用数据库已清空',
          'timestamp': _lastFeesUpdate
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('清空费用数据库失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 处理机器数据上传
  Future<Response> handleUploadMachines(Request request) async {
    try {
      // 检查Content-Type是否为multipart/form-data
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.contains('multipart/form-data')) {
        return Response.badRequest(
          body: json.encode({'success': false, 'error': 'Content-Type必须为multipart/form-data'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 解析multipart/form-data请求
      final boundary = contentType.split('boundary=').last;
      final bodyBytes = await request.read().toList();
      final flattenedBytes = <int>[];
      for (final byteList in bodyBytes) {
        flattenedBytes.addAll(byteList);
      }
      final body = Uint8List.fromList(flattenedBytes);

      // 手动解析multipart数据 - 简化版
      final parts = <Map<String, dynamic>>[];
      final boundaryBytes = utf8.encode('\r\n--$boundary');
      var start = 0;
      final firstBoundary = utf8.encode('--$boundary');
      var pos = this._findBytes(body, firstBoundary, start);
      if (pos == -1) {
        return Response.badRequest(
          body: json.encode({'success': false, 'error': '无效的multipart格式'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      pos += firstBoundary.length;

      while (pos < body.length - 2) {
        final nextBoundary = this._findBytes(body, boundaryBytes, pos);
        if (nextBoundary == -1) {
          // 最后一部分
          final partData = body.sublist(pos, body.length - 2); // -2 for \r\n
          parts.add(this._parseMultipartPart(partData));
          break;
        }

        final partData = body.sublist(pos, nextBoundary);
        parts.add(this._parseMultipartPart(partData));
        pos = nextBoundary + boundaryBytes.length;

        // 如果遇到结束标记
        if (pos < body.length &&
            body[pos] == 45 &&
            pos + 1 < body.length &&
            body[pos + 1] == 45) {
          // '--' 结束标记
          break;
        }
      }

      // 查找文件部分
      Uint8List? fileData;
      String? fileName;

      for (final part in parts) {
        final headers = part['headers'] as Map<String, String>;
        final content = part['content'] as Uint8List;

        final contentDisposition = headers['content-disposition'];
        if (contentDisposition != null) {
          final filenameMatch = RegExp(r'filename="([^"}]+)"').firstMatch(contentDisposition);
          if (filenameMatch != null) {
            fileName = filenameMatch.group(1);
            fileData = content;
            break;
          }
        }
      }

      if (fileData == null) {
        return Response.badRequest(
          body: json.encode({'success': false, 'error': '未找到上传的文件'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 解码文件内容并解析JSON
      final fileContent = utf8.decode(fileData);
      final List<dynamic> jsonData = json.decode(fileContent);

      // 验证数据格式
      if (jsonData.isEmpty) {
        return Response.badRequest(
          body: json.encode({'success': false, 'error': '上传的文件为空'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // 清空现有的机器数据
      final machinesBox = Hive.box<Machine>('machines');
      await machinesBox.clear();

      // 遍历并保存机器数据
      for (final item in jsonData) {
        if (item is Map<String, dynamic>) {
          // 为每个机器生成UUID
          final id = const Uuid().v4();
          
          // 创建Machine对象
          final machine = Machine(
            id: id,
            model: item['Model']?.toString() ?? '',
            originalModel: item['OriginalModel']?.toString() ?? '',
            originalPrice: (item['OriginalPrice'] as num?)?.toDouble() ?? 0.0,
            showPrice: (item['ShowPrice'] as num?)?.toDouble() ?? 0.0,
            image: item['image']?.toString() ?? '',
            addedCount: item['addedCount']?.toInt() ?? 0,
            otherProperties: _extractOtherProperties(item, {}),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            createdBy: 'system',
            updatedBy: 'system',
          );

          // 保存到Hive
          await machinesBox.put(id, machine);
        }
      }

      // 更新机器数据版本时间戳
      updateMachinesTimestamp();

      return Response.ok(
        json.encode({
          'success': true,
          'message': '机器数据上传成功',
          'count': jsonData.length,
          'timestamp': _lastMachinesUpdate
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('上传机器数据失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 清空系数数据库
  Future<Response> handleClearTempFactors(Request request) async {
    try {
      final factorsBox = Hive.box<TempFactor>('temp_factors');
      
      // 清空Box中的所有数据
      await factorsBox.clear();
      
      // 更新系数数据版本时间戳
      updateFactorsTimestamp();
      
      return Response.ok(
        json.encode({
          'success': true,
          'message': '系数数据库已清空',
          'timestamp': _lastFactorsUpdate
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('清空系数数据库失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 辅助方法：查找字节数组中的子序列（从FileUploadHandler复制）
  int _findBytes(Uint8List data, List<int> pattern, int startIndex) {
    for (int i = startIndex; i <= data.length - pattern.length; i++) {
      bool found = true;
      for (int j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) {
        return i;
      }
    }
    return -1;
  }

  // 辅助方法：解析multipart部分（从FileUploadHandler复制）
  Map<String, dynamic> _parseMultipartPart(Uint8List data) {
    // 查找头部和内容的分界（\r\n\r\n）
    int headerEnd = -1;
    for (int i = 0; i < data.length - 3; i++) {
      if (data[i] == 13 &&
          data[i + 1] == 10 &&
          data[i + 2] == 13 &&
          data[i + 3] == 10) {
        headerEnd = i + 4;
        break;
      }
    }

    final headers = <String, String>{};
    Uint8List content;

    if (headerEnd != -1) {
      // 解析头部
      final headerData = utf8.decode(data.sublist(0, headerEnd - 2)); // -2 to remove \r\n
      final headerLines = headerData.split('\r\n');

      for (final line in headerLines) {
        if (line.contains(':')) {
          final parts = line.split(':');
          headers[parts[0].trim().toLowerCase()] = parts.sublist(1).join(':').trim();
        }
      }

      content = data.sublist(headerEnd);
    } else {
      content = data;
    }

    // 移除内容前后的\r\n
    int start = 0;
    while (start < content.length && (content[start] == 13 || content[start] == 10)) {
      start++;
    }

    int end = content.length;
    while (end > start && (content[end - 1] == 13 || content[end - 1] == 10)) {
      end--;
    }

    return {
      'headers': headers,
      'content': content.sublist(start, end),
    };
  }
}