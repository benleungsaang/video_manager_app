import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:convert' as convert;
import 'dart:convert' show base64;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:flutter/foundation.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'web_api_handler.dart';
import 'user_service.dart'; // 新增导入
import 'video_api_handler.dart'; // 新增导入
import 'price_calculator_api_handler.dart'; // 新增导入
import 'user_api_handler.dart'; // 新增导入
import 'file_upload_handler.dart'; // 新增导入

import '../utils/storage_utils.dart'; // 新增导入
import '../utils/file_utils.dart'; // 新增导入
import 'database_export_service.dart'; // 新增导入
import '../repositories/video_repository.dart'; // 新增导入
import '../repositories/tag_repository.dart'; // 新增导入
import '../models/machine_part.dart'; // 新增导入
import '../models/part.dart'; // 新增导入
import '../models/temp_fee.dart'; // 新增导入
import '../models/temp_factor.dart'; // 新增导入
import '../models/user.dart'; // 新增导入

// import '../providers/tag_provider.dart';

// import '../providers/video_provider.dart';

// import 'package:provider/provider.dart';

// import 'package:video_manager_app/main.dart';

// import 'package:video_manager_app/models/video.dart';

class ServerService with ChangeNotifier {
  bool _isRunning = false;
  int _port = 8080;
  String? _localIp;
  HttpServer? _server;

  bool get isRunning => _isRunning;
  int get port => _port;
  String? get localIp => _localIp;
  // 移除WebSocket连接相关属性，因为不再使用WebSocket
  int get connectionCount => 0; // 现在不追踪WebSocket连接
  Map<String, String> get clientDevices => {}; // 现在不追踪WebSocket连接

  // 移除WebSocket相关的消息日志和客户端详情

  late WebApiHandler _webApiHandler;
  late UserService _userService; // 新增用户服务
  late VideoApiHandler _videoApiHandler; // 新增视频API处理器
  late PriceCalculatorApiHandler _priceCalculatorApiHandler; // 新增价格计算器API处理器
  late UserApiHandler _userApiHandler; // 新增用户API处理器
  late FileUploadHandler _fileUploadHandler; // 新增文件上传处理器

  // bool _isInitialized = false; // 新增初始化标记
  // bool get isInitialized => _isInitialized;

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

  // void initApiHandler(TagProvider tagProvider, VideoProvider videoProvider) {
  //   _webApiHandler = WebApiHandler(
  //     tagProvider: tagProvider,
  //     videoProvider: videoProvider,
  //   );
  //   _isInitialized = true;
  // }

  // VideoProvider get _videoProvider =>
  //     Provider.of<VideoProvider>(navigatorKey.currentContext!, listen: false);

  // 移除WebSocket相关的客户端管理方法

  Future<void> _getLocalIp() async {
    final info = NetworkInfo();
    _localIp = await info.getWifiIP();
    notifyListeners();
  }

  Future<void> clearWebCache() async {
    final tempDir = StorageUtils.getTempDirectory();
    final webAssetsDir = Directory(p.join(tempDir, 'web'));

    if (await webAssetsDir.exists()) {
      await webAssetsDir.delete(recursive: true);
      print('Web资源缓存已清除');
    } else {
      print('没有可清除的Web资源缓存');
    }
    notifyListeners();
  }

  Future<void> _copyWebAssets() async {
    final tempDir = StorageUtils.getTempDirectory();
    final webAssetsDir = Directory(p.join(tempDir, 'web'));
    await webAssetsDir.create(recursive: true);

    try {
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = await assetManifest.listAssets();

      final webAssetPaths = allAssets
          .where((path) =>
              path.startsWith('build/web/') || path.startsWith('packages/'))
          .toList();

      if (webAssetPaths.isEmpty) {
        throw Exception('未找到build/web目录下的资源，请检查pubspec.yaml配置');
      }

      print('开始复制Web资源（共 ${webAssetPaths.length} 个文件）...');

      for (final assetPath in webAssetPaths) {
        String relativePath;
        if (assetPath.startsWith('build/web/')) {
          relativePath = p.relative(assetPath, from: 'build/web');
        } else if (assetPath.startsWith('packages/')) {
          relativePath = 'assets/${assetPath}';
        } else {
          continue;
        }

        final targetFile = File(p.join(webAssetsDir.path, relativePath));

        print('复制文件: $relativePath');

        await targetFile.parent.create(recursive: true);

        final byteData = await rootBundle.load(assetPath);
        await targetFile.writeAsBytes(byteData.buffer.asUint8List());
      }

      print('Web资源复制完成，共 ${webAssetPaths.length} 个文件');
    } catch (e) {
      print('复制Web资源失败：$e');
      if (await webAssetsDir.exists()) {
        await webAssetsDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> startServer({int? customPort}) async {
    if (_isRunning) return;

    // // 新增检查：确保初始化完成
    // if (!_isInitialized) {
    //   throw Exception("startServer => ServerService未初始化，请先调用initApiHandler");
    // }
    // _webApiHandler = WebApiHandler(
    //   tagProvider:
    //       navigatorKey.currentState!.context.read<TagProvider>(),
    //   videoProvider:
    //       navigatorKey.currentState!.context.read<VideoProvider>(),
    // );
    _webApiHandler = WebApiHandler();
    _userService = UserService(); // 初始化用户服务
    await _userService.init(); // 初始化用户服务
    _videoApiHandler = VideoApiHandler(_webApiHandler); // 初始化视频API处理器
    _priceCalculatorApiHandler = PriceCalculatorApiHandler(); // 初始化价格计算器API处理器
    _userApiHandler = UserApiHandler(_userService); // 初始化用户API处理器
    _fileUploadHandler = FileUploadHandler(_webApiHandler); // 初始化文件上传处理器

    if (customPort != null) {
      if (customPort < 1024 || customPort > 65535) {
        throw Exception("端口必须在1024-65535范围内");
      }
      _port = customPort;
    }

    await _getLocalIp();
    final router = _createRouter();

    // 1. 基础日志中间件
    // final logMiddleware = logRequests(
    //   logger: (message, isError) {
    //     if (isError) {
    //       print('[错误 ERROR] $message');
    //     } else {
    //       print('[正常 INFO] $message');
    //     }
    //   },
    // );

    // 2. CORS跨域中间件
    final corsMiddleware = corsHeaders(
      headers: {
        ACCESS_CONTROL_ALLOW_ORIGIN: '*',
        ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, DELETE, OPTIONS',
        ACCESS_CONTROL_ALLOW_HEADERS: 'Range, Content-Type, Origin',
        ACCESS_CONTROL_EXPOSE_HEADERS:
            'Content-Length, Accept-Ranges, Content-Type', // 显式声明暴露的头
        ACCESS_CONTROL_MAX_AGE: '86400', // 24小时缓存预检请求
      },
    );

    // final corsMiddleware = (Handler handler) {
    //   return (Request request) async {
    //     // Skip CORS for non-HTTP requests (e.g., WebSocket)
    //     if (request.method == 'OPTIONS' ||
    //         request.method == 'GET' ||
    //         request.method == 'HEAD') {
    //       final response = await handler(request);
    //       return response.change(headers: {
    //         'Access-Control-Allow-Origin': '*',
    //         'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
    //         'Access-Control-Allow-Headers': 'Range, Content-Type, Origin',
    //         'Access-Control-Expose-Headers':
    //             'Content-Length, Accept-Ranges, Content-Type',
    //       });
    //     }
    //     return handler(request);
    //   };
    // };

    // 3. 错误处理中间件
    final errorHandlerMiddleware = createMiddleware(
      errorHandler: (Object error, StackTrace stackTrace) {
        print('服务器错误: $error\n$stackTrace');
        return Response.internalServerError(
          body: json.encode({
            'error': '服务器内部错误',
            'message': kReleaseMode ? null : error.toString(),
          }),
          headers: {'Content-Type': 'application/json'},
        );
      },
    );

    // 4. 请求超时中间件
    // final timeoutMiddleware = createMiddleware(
    //   requestHandler: (Request request, PipelineHandler next) {
    //     return next(request).timeout(
    //       const Duration(seconds: 30),
    //       onTimeout: () => Response(
    //         HttpStatus.gatewayTimeout,
    //         body: json.encode({'error': '请求超时'}),
    //         headers: {'Content-Type': 'application/json'},
    //       ),
    //     );
    //   },
    // );

    // 组合中间件
    final middlewarePipeline = Pipeline()
        // .addMiddleware(logMiddleware)
        .addMiddleware(corsMiddleware)
        .addMiddleware(errorHandlerMiddleware);
    // .addMiddleware(timeoutMiddleware);

    _server = await serve(
      middlewarePipeline.addHandler(router.call),
      InternetAddress.anyIPv4,
      _port,
    );

    _isRunning = true;
    notifyListeners();
    print('服务器启动于 http://${_localIp}:${_port}');
  }

  Router _createRouter() {
    final router = Router();

    // HTTP API端点 - 视频相关
    router.get('/api/videos', _videoApiHandler.handleGetVideos);
    router.get('/api/videos/<limit>', _videoApiHandler.handleGetRecentVideos);
    router.get('/api/videos/<id>', _videoApiHandler.handleGetVideo);
    router.post('/api/videos', _videoApiHandler.handleCreateVideo);
    router.put('/api/videos/<id>', _videoApiHandler.handleUpdateVideo);
    router.delete('/api/videos/<id>', _videoApiHandler.handleDeleteVideo);

    // HTTP API端点 - 标签相关
    router.get('/api/tags', _videoApiHandler.handleGetTags);
    router.post('/api/tags', _videoApiHandler.handleCreateTag);
    router.delete('/api/tags/<id>', _videoApiHandler.handleDeleteTag);

    // HTTP API端点 - 文件上传
    router.post('/api/upload', _fileUploadHandler.handleFileUpload);

    // HTTP API端点 - 搜索
    router.get('/api/search', _videoApiHandler.handleSearch);

    // HTTP API端点 - 缩略图
    router.get('/api/thumbnails/<id>', _videoApiHandler.handleGetThumbnail);

    // HTTP API端点 - 价格计算器相关
    router.get('/api/machine-parts', _priceCalculatorApiHandler.handleGetMachineParts);
    router.post('/api/machine-parts', _priceCalculatorApiHandler.handleCreateMachinePart);
    router.put('/api/machine-parts/<id>', _priceCalculatorApiHandler.handleUpdateMachinePart);
    router.delete('/api/machine-parts/<id>', _priceCalculatorApiHandler.handleDeleteMachinePart);

    // HTTP API端点 - 视频信息
    router.get('/api/videos/<id>/url', _videoApiHandler.handleGetVideoUrl);
    router.get('/api/videos/<id>/size', _videoApiHandler.handleGetVideoSize);

    // HTTP API端点 - 部件相关（价格计算器）
    router.get('/api/parts', _priceCalculatorApiHandler.handleGetParts);
    router.post('/api/parts', _priceCalculatorApiHandler.handleCreatePart);
    router.put('/api/parts/<id>', _priceCalculatorApiHandler.handleUpdatePart);
    router.delete('/api/parts/<id>', _priceCalculatorApiHandler.handleDeletePart);

    // HTTP API端点 - 统计信息（价格计算器）
    router.get('/api/parts-stats', _priceCalculatorApiHandler.handleGetPartsStats);

    // HTTP API端点 - 费用相关（价格计算器）
    router.get('/api/temp-fees', _priceCalculatorApiHandler.handleGetTempFees);
    router.post('/api/temp-fees', _priceCalculatorApiHandler.handleCreateTempFee);
    router.put('/api/temp-fees/<id>', _priceCalculatorApiHandler.handleUpdateTempFee);
    router.delete('/api/temp-fees/<id>', _priceCalculatorApiHandler.handleDeleteTempFee);
    
    // HTTP API端点 - 系数相关（价格计算器）
    router.get('/api/temp-factors', _priceCalculatorApiHandler.handleGetTempFactors);
    router.post('/api/temp-factors', _priceCalculatorApiHandler.handleCreateTempFactor);
    router.put('/api/temp-factors/<id>', _priceCalculatorApiHandler.handleUpdateTempFactor);
    router.delete('/api/temp-factors/<id>', _priceCalculatorApiHandler.handleDeleteTempFactor);

    // HTTP API端点 - 常用项目相关（价格计算器）
    router.get('/api/top-used/parts', _priceCalculatorApiHandler.handleGetTopUsedParts);
    router.get('/api/top-used/fees', _priceCalculatorApiHandler.handleGetTopUsedFees);
    router.get('/api/top-used/factors', _priceCalculatorApiHandler.handleGetTopUsedFactors);

    // HTTP API端点 - 数据更新检查（价格计算器）
    router.get('/api/check-data-update', _priceCalculatorApiHandler.handleCheckDataUpdate);

    // HTTP API端点 - 用户管理相关
    router.get('/api/users', _userApiHandler.handleGetUsers);
    router.post('/api/users', _userApiHandler.handleCreateUser);
    router.post('/api/users/generate-totp', _userApiHandler.handleGenerateTotpSecret);
    router.post('/api/users/verify-totp', _userApiHandler.handleVerifyTotpCode);
    router.post('/api/users/authenticate', _userApiHandler.handleAuthenticateUser);
    router.get('/api/users/pending-approval', _userApiHandler.handleGetPendingApprovalUsers);
    router.post('/api/users/approve', _userApiHandler.handleApproveUser);
    router.post('/api/users/reject', _userApiHandler.handleRejectUser);
    router.delete('/api/users/<username>', _userApiHandler.handleDeleteUser); // 删除用户
    router.post('/api/users/<username>/disable', _userApiHandler.handleDisableUser); // 禁用用户
    router.post('/api/users/<username>/enable', _userApiHandler.handleEnableUser);  // 恢复用户
    router.post('/api/users/<username>/reset-binding', _userApiHandler.handleResetUserBinding); // 重置绑定
    router.post('/api/session-validation', _userApiHandler.handleSessionValidation); // 会话验证
    router.post('/api/current-user-info', _userApiHandler.handleGetCurrentUserInfo); // 获取当前用户信息

    // 视频流处理路由 - 支持Range和HEAD请求
    router.get('/videoStream/<videoId>', _handleVideoStream);

    router.options('/<path|.*>', (Request request) {
      return Response.ok('', headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
        'Access-Control-Allow-Headers': 'Range, Content-Type, Origin',
        'Access-Control-Expose-Headers': 'Content-Length, Accept-Ranges',
        'Access-Control-Max-Age': '86400', // 预检结果缓存24小时
        'Content-Length': '0', // OPTIONS请求无响应体
      });
    });

    // 配置静态资源服务
    router.all('/<path|.*>', _createStaticHandler());
    return router;
  }

  // 处理视频流式传输（支持断点续传和Range请求）
  Future<Response> _handleVideoStream(Request request, String videoId) async {
    try {
      // print('=' * 50);
      print('播放视频 ID=> ${videoId}');
      // print('=' * 50);
      // print('收到请求的完整 Header：');
      // print('=' * 50);
      // print(request.headers); // 直接打印 Headers 对象（会自动展开所有键值）

      final video = _webApiHandler.getVideoById(videoId);
      if (video == null || video.filePath == null) {
        return Response.notFound(json.encode({'error': '视频不存在'}));
      }
      final file = File(video.filePath!);
      if (!await file.exists()) {
        return Response.notFound(json.encode({'error': '视频文件不存在'}));
      }

      // 2. 处理HEAD请求（仅返回头信息）
      if (request.method == 'HEAD') {
        final _fileSize = video.fileSize.toString();
        print('fileSize inside: ${_fileSize}');
        // 根据文件扩展名确定Content-Type
        final fileExtension = file.path.split('.').last.toLowerCase();
        final contentType = _getVideoContentType(fileExtension);
        final headers = {
          'Content-Length': _fileSize,
          'Content-Type': contentType,
          'Accept-Ranges': 'bytes',
          'Cache-Control': 'public, max-age=3600',
          // 跨域配置
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
          // 补充暴露更多必要的头信息
          'Access-Control-Expose-Headers':
              'Content-Length, Accept-Ranges, Content-Type',
          // 允许前端读取的请求头
          'Access-Control-Allow-Headers': 'Range, Content-Type',
        };
        print('headers: ${headers}');
        return Response(200, headers: headers);
      }

      // 3. 处理GET请求和Range
      final fileLength = await file.length();
      // 从请求头中获取 Range（格式如：bytes=1024-2047 或 bytes=512-）
      final rangeHeader = request.headers['Range'];
      int start = 0; // 默认从文件开头开始
      int end = fileLength - 1; // 默认到文件末尾结束

      // 解析 Range 头（正则匹配字节范围）
      if (rangeHeader != null) {
        final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(rangeHeader);
        if (match != null) {
          start = int.parse(match.group(1)!); // 提取起始字节
          // 提取结束字节（若未指定，保持默认到文件末尾）
          if (match.group(2) != null && match.group(2)!.isNotEmpty) {
            end = int.parse(match.group(2)!);
          }
        }
      }

// 校验 Range 合法性（避免无效范围请求）
      if (start > end || start >= fileLength) {
        return Response(416, // 416 状态码：Range Not Satisfiable（范围不合法）
            headers: {
              'Content-Range': 'bytes */$fileLength',
              'Content-Length': '0',
            });
      }

// 调整 end 不超过文件长度（防止客户端请求超出文件大小）
      end = end > fileLength - 1 ? fileLength - 1 : end;
      final contentLength = end - start + 1;

      // 根据文件扩展名确定Content-Type
      final fileExtension = file.path.split('.').last.toLowerCase();
      final contentType = _getVideoContentType(fileExtension);

      // 打开文件为随机访问流（支持跳转到指定位置读取，避免加载整个文件）
      final raf = await file.open(mode: FileMode.read);
      await raf.setPosition(start); // 跳转到 Range 指定的起始位置

      // 创建 StreamController 手动控制流的生命周期（修复 Stream 无 whenComplete 的问题）
      final streamController = StreamController<List<int>>();

      // 读取指定长度的文件数据（contentLength 为当前分块的字节数）
      raf.read(contentLength).then((data) {
        streamController.add(data); // 向流中添加数据（发送给客户端）
        streamController.close(); // 数据发送完成，关闭控制器
      }).catchError((error) {
        print('文件读取错误: $error');
        raf.close(); // 出错时关闭文件，避免资源泄漏
        streamController.addError(error); // 向客户端返回错误
        streamController.close();
      }).whenComplete(() {
        raf.close(); // 无论成功失败，最终都关闭文件句柄
      });

// 监听流的错误事件，兜底关闭文件句柄
      final stream = streamController.stream.handleError((error) {
        print('流处理错误: $error');
        raf.close();
      });

      // 5. 返回响应
      return Response(
        rangeHeader != null ? 206 : 200, // 206：Partial Content（分块响应）；200：完整响应
        body: stream, // 响应体为流式数据（避免内存溢出）
        headers: {
          'Content-Type': contentType, // 使用根据文件扩展名确定的类型
          'Content-Length': contentLength.toString(), // 当前分块的字节数
          'Content-Range': 'bytes $start-$end/$fileLength', // 告知客户端当前分块的范围和总长度
          'Accept-Ranges': 'bytes', // 再次声明支持 Range 请求
          'Cache-Control': 'public, max-age=3600', // 分块数据缓存 1 小时
        },
      );
    } catch (e) {
      print('视频流处理错误: $e');
      return Response.internalServerError(
          body: json.encode({'error': '视频流处理失败'}));
    }
  }

  // 提取静态资源处理器
  Handler _createStaticHandler() {
    return (Request request) async {
      final tempDir = StorageUtils.getTempDirectory();
      final webAssetsDir = Directory('${tempDir}/web');
      // print('处理静态资源请求: ${request.url.path}');
      // print('静态资源目录: ${webAssetsDir.path}');

      if (!await webAssetsDir.exists()) {
        try {
          await _copyWebAssets();
        } catch (e) {
          return Response.internalServerError(
            body: json.encode({'error': '静态资源加载失败: ${e.toString()}'}),
          );
        }
      }

      return createStaticHandler(
        webAssetsDir.path,
        defaultDocument: 'entry.html',
        listDirectories: false,
      )(request);
    };
  }

  // 根据浏览器类型和文件大小确定最优分块大小
  int _getOptimalChunkSize(int totalSize, String userAgent) {
    // 对于Safari浏览器使用更小的块
    if (userAgent.toLowerCase().contains('safari') &&
        !userAgent.toLowerCase().contains('chrome')) {
      if (totalSize > 100 * 1024 * 1024) {
        // > 100MB
        return 2 * 1024 * 1024; // 2MB
      } else if (totalSize > 10 * 1024 * 1024) {
        // > 10MB
        return 1 * 1024 * 1024; // 1MB
      } else {
        return 512 * 1024; // 512KB
      }
    } else {
      // 对于其他浏览器（如Chrome）
      if (totalSize > 500 * 1024 * 1024) {
        // > 500MB
        return 10 * 1024 * 1024; // 10MB
      } else if (totalSize > 100 * 1024 * 1024) {
        // > 100MB
        return 5 * 1024 * 1024; // 5MB
      } else if (totalSize > 10 * 1024 * 1024) {
        // > 10MB
        return 2 * 1024 * 1024; // 2MB
      } else {
        return 1024 * 1024; // 1MB
      }
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

  // 导出数据库

  Future<String> exportDatabase() async {
    // 导入需要的类

    final videoRepo = VideoRepository();

    final tagRepo = TagRepository();

    final exportService = DatabaseExportService(videoRepo, tagRepo);

    try {
      return await exportService.exportDatabaseToFile();
    } catch (e) {
      print('导出数据库失败: $e');

      rethrow;
    }
  }

  // 导入数据库

  Future<void> importDatabase(String filePath) async {
    // 导入需要的类

    final videoRepo = VideoRepository();

    final tagRepo = TagRepository();

    final exportService = DatabaseExportService(videoRepo, tagRepo);

    try {
      await exportService.importDatabaseFromFile(filePath);

      notifyListeners(); // 通知UI更新
    } catch (e) {
      print('导入数据库失败: $e');

      rethrow;
    }
  }

  // 根据文件扩展名获取视频的Content-Type
  String _getVideoContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'ogg':
        return 'video/ogg';
      case 'avi':
        return 'video/x-msvideo';
      case 'wmv':
        return 'video/x-ms-wmv';
      case 'flv':
        return 'video/x-flv';
      case 'm4v':
        return 'video/x-m4v';
      case '3gp':
        return 'video/3gpp';
      case 'mkv':
        return 'video/x-matroska';
      default:
        return 'application/octet-stream'; // 默认类型
    }
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;

    // 发送服务器关闭消息 - 现在使用HTTP API，无需广播

    // 使用连接池清理所有连接 - 现在已移除WebSocket连接池

    await _server?.close(force: true);
    _server = null;

    _isRunning = false;
    notifyListeners();
  }

  // 从User-Agent判断设备类型
  String _getDeviceType(String? userAgent) {
    try {
      if (userAgent == null) return '未知设备';
      if (userAgent.contains('Mobile')) {
        return '手机';
      } else if (userAgent.contains('Tablet')) {
        return '平板';
      } else {
        return '电脑';
      }
    } catch (e) {
      print('获取设备类型失败: $e');
      return '设备类型解析错误';
    }
  }

  void setPort(int newPort) {
    if (newPort < 1024 || newPort > 65535) {
      throw Exception("端口必须在1024-65535范围内");
    }

    _port = newPort;

    notifyListeners();
  }
}