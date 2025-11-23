import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'web_api_handler.dart';
import '../utils/storage_utils.dart'; // 新增导入
import 'database_export_service.dart'; // 新增导入
import '../repositories/video_repository.dart'; // 新增导入
import '../repositories/tag_repository.dart'; // 新增导入
// import '../providers/tag_provider.dart';
// import '../providers/video_provider.dart';
// import 'package:provider/provider.dart';
// import 'package:video_manager_app/main.dart';
// import 'package:video_manager_app/models/video.dart';

// 消息类型枚举
enum MessageType {
  chat, // 聊天消息
  command, // 命令消息
  connectionStatus, // 连接状态消息
  error, // 错误消息
  acknowledge // 确认消息
}

// 消息日志类
class MessageLog {
  final String? clientId;
  final String type;
  final dynamic data;
  final String timestamp;

  MessageLog({
    this.clientId,
    required this.type,
    required this.data,
    String? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toString().substring(0, 19);
}

// 客户端详情类
class ClientDetails {
  final String deviceType;
  final String connectedAt;
  String? remark;

  ClientDetails({
    required this.deviceType,
    String? connectedAt,
    this.remark,
  }) : connectedAt = connectedAt ?? DateTime.now().toString().substring(0, 19);
}

// 基础消息结构
class WebSocketMessage {
  final String type;
  final String? clientId;
  final dynamic data;
  final String? timestamp;

  WebSocketMessage({
    required this.type,
    this.clientId,
    this.data,
    String? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toJson() => {
        'type': type,
        'clientId': clientId,
        'data': data,
        'timestamp': timestamp,
      };

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      type: json['type'] as String,
      clientId: json['clientId'] as String?,
      data: json['data'],
      timestamp: json['timestamp'] as String?,
    );
  }
}

class ServerService with ChangeNotifier {
  bool _isRunning = false;
  int _port = 8080;
  String? _localIp;
  final Map<String, WebSocketChannel> _connectedClients = {}; // 使用clientId作为键
  final Map<String, String> _clientDevices = {}; // 存储客户端设备信息
  HttpServer? _server;

  bool get isRunning => _isRunning;
  int get port => _port;
  String? get localIp => _localIp;
  int get connectionCount => _connectedClients.length;
  Map<String, String> get clientDevices => _clientDevices;

  // 新增属性 - 关于处理server_control_page 客户信息相关的
  final List<MessageLog> _messageLogs = [];
  final Map<String, ClientDetails> _clientDetails = {};

  // 新增getter - 关于处理server_control_page 客户信息相关的
  List<MessageLog> get messageLogs => List.unmodifiable(_messageLogs);
  Map<String, ClientDetails> get clientDetails =>
      Map.unmodifiable(_clientDetails);

  late WebApiHandler _webApiHandler;
  // bool _isInitialized = false; // 新增初始化标记
  // bool get isInitialized => _isInitialized;

  // void initApiHandler(TagProvider tagProvider, VideoProvider videoProvider) {
  //   _webApiHandler = WebApiHandler(
  //     tagProvider: tagProvider,
  //     videoProvider: videoProvider,
  //   );
  //   _isInitialized = true;
  // }

  // VideoProvider get _videoProvider =>
  //     Provider.of<VideoProvider>(navigatorKey.currentContext!, listen: false);

  // 新增方法：记录消息日志
  void _logMessage(String? clientId, String type, dynamic data) {
    if (clientId == null) return; // 如果clientId为空，则不记录日志
    
    _messageLogs.add(MessageLog(
      clientId: clientId,
      type: type,
      data: data,
    ));
    // 限制日志数量，避免内存溢出
    if (_messageLogs.length > 100) {
      _messageLogs.removeAt(0);
    }
    notifyListeners();
  }

  // 新增方法：设置客户端备注
  void setClientRemark(String clientId, String remark) {
    if (_clientDetails.containsKey(clientId)) {
      _clientDetails[clientId]!.remark = remark;
      notifyListeners();
    }
  }

  // 新增方法：断开特定客户端连接
  void disconnectClient(String clientId) {
    if (_connectedClients.containsKey(clientId)) {
      final client = _connectedClients[clientId]!;
      client.sink.close(1000, '服务器主动断开连接');
      _connectedClients.remove(clientId);
      _clientDetails.remove(clientId);
      print('已断开客户端连接');
      _broadcastConnectionStatus();
      notifyListeners();
    } else {
      print('客户端 $clientId 不存在');
      _clientDetails.remove(clientId);
      _broadcastConnectionStatus();
      notifyListeners();
    }
  }

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

    // WebSocket连接处理
    router.get('/ws', (Request request) {
      print('检测到 WebSocket 请求 ${request.url} ${request.params}');
      return webSocketHandler((WebSocketChannel channel) {
        _handleWebSocketConnection(channel, request);
      })(request);
    });

    // // 文件上传接口
    router.post('/upload', _handleFileUpload);

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
        final headers = {
          'Content-Length': _fileSize,
          'Content-Type': 'application/octet-stream',
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
          'Content-Type': 'application/octet-stream', // 兼容下载和播放
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

  // 提取WebSocket处理为独立方法
  // 处理WebSocket连接
  void _handleWebSocketConnection(WebSocketChannel channel, Request request) {
    print('开始处理WebSocket连接');

    // 从请求参数获取客户端ID（如果有的话）
    String? clientId = request.url.queryParameters['clientId'];
    
    // 如果没有提供客户端ID，则生成一个临时ID
    if (clientId == null || clientId.isEmpty) {
      // 改进临时ID生成，确保唯一性
      do {
        clientId =
            'temp_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1000)}';
      } while (_connectedClients.containsKey(clientId)); // 检查是否已有该ID
    } else {
      // 如果客户端提供了ID，检查是否已有连接，如果有则断开旧连接
      if (_connectedClients.containsKey(clientId)) {
        final oldChannel = _connectedClients[clientId]!;
        print('客户端 $clientId 已有连接，断开旧连接');
        try {
          oldChannel.sink.close(1000, '新的相同ID连接已建立');
        } catch (e) {
          print('关闭旧连接时出错: $e');
        }
      }
    }

    // 记录客户端详情
    final userAgent = request.headers['user-agent'] ?? '';
    final deviceType = _getDeviceType(userAgent);
    if (clientId != null) {
      _clientDetails[clientId] = ClientDetails(deviceType: deviceType);

      // 确认没问题的临时ID，装入对应通信通道 channel
      _connectedClients[clientId] = channel;

      // 记录连接日志
      _logMessage(clientId, 'connection', '客户端已连接');
    }

    // 监听客户端消息
    if (clientId != null) {
      final subscription = channel.stream
          .listen((message) => _handleClientMessage(message, channel, clientId),
              onDone: () {
        // 连接关闭时清理（新方式）
        final removedClient = _connectedClients.remove(clientId);
        if (removedClient != null) {
          _clientDevices.remove(clientId);
          _logMessage(clientId, 'connection', '客户端已断开');
          print('WebSocket连接已关闭: $clientId，剩余连接: ${_connectedClients.length}');
          _broadcastConnectionStatus(); // 通知所有客户端连接状态变化
        }
      }, onError: (error) {
        print('WebSocket错误: $error');
        _logMessage(clientId, 'error', error.toString());
      });

      // 处理连接关闭
      channel.sink.done.then((_) {
        subscription.cancel();
      });
    }
  }

  // 处理客户端消息
  void _handleClientMessage(
      dynamic message, WebSocketChannel channel, String? clientId) {
    if (clientId == null) {
      print('错误：客户端ID为空');
      return;
    }

    try {
      // 处理二进制数据
      if (message is Uint8List) {
        _handleBinaryData(channel, clientId, message);
        return;
      }

      // 解析消息
      Map<String, dynamic> messageJson;
      if (message is String) {
        messageJson = json.decode(message);
      } else if (message is List<int>) {
        messageJson = json.decode(utf8.decode(message));
      } else {
        throw FormatException('不支持的消息格式');
      }

      // 记录二进制请求上下文
      if (messageJson['action'] == 'uploadBinaryChunk') {
        _pendingBinaryRequests[clientId] = messageJson;
      }

      print('收到客户端【 $clientId 】发来指令: $messageJson');
      // 记录消息日志
      _logMessage(clientId, messageJson['action'] ?? 'unknown', messageJson);

      // 调用WebApiHandler处理请求
      _webApiHandler.handleRequest(channel, messageJson).then((response) {
        // 给响应添加请求ID，以便客户端匹配请求和响应
        final responseWithId = {'id': messageJson['id'], ...response};
        // 发送响应给客户端
        channel.sink.add(json.encode(responseWithId));
      }).catchError((error) {
        // 处理异步错误
        channel.sink.add(json.encode({
          'id': messageJson['id'],
          'success': false,
          'error': error.toString()
        }));
      });
    } catch (e) {
      print('消息处理错误: $e');
      _logMessage(clientId, 'error', e.toString());
      // 发送错误响应
      channel.sink.add(json.encode({'success': false, 'error': e.toString()}));
    }
  }

  final Map<String, Map<String, dynamic>> _pendingBinaryRequests = {};

  // 处理二进制数据
  void _handleBinaryData(
      WebSocketChannel channel, String clientId, Uint8List data) {
    if (!_pendingBinaryRequests.containsKey(clientId)) {
      channel.sink.add(json.encode({'success': false, 'error': '未找到对应的二进制请求'}));
      return;
    }

    // 获取对应的请求信息
    final request = _pendingBinaryRequests.remove(clientId);
    final requestId = request!['id'];
    final params = request['params'];

    // 交给API处理器处理二进制块
    _webApiHandler.handleBinaryData(
        channel: channel,
        fileId: params['fileId'],
        chunkIndex: params['chunkIndex'],
        data: data,
        requestId: requestId);
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
        defaultDocument: 'index.html',
        listDirectories: false,
      )(request);
    };
  }

  // 优化文件上传处理
  Future<Response> _handleFileUpload(Request request) async {
    try {
      // 这里可以添加实际的文件上传处理逻辑
      return Response.ok(json.encode({'status': '上传成功'}),
          headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.badRequest(
        body: json.encode({'error': '上传失败: ${e.toString()}'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 修复广播消息逻辑
  void _broadcastMessage(dynamic message) {
    print('广播消息到 ${_connectedClients.length} 个客户端');

    // 给每个在登记的用户广播消息
    for (final entry in _connectedClients.entries) {
      final clientId = entry.key;
      final client = entry.value;
      try {
        if (client.closeCode == null) {
          client.sink.add(message);
          print('已向客户端 $clientId 发送消息');
        } else {
          print('客户端 $clientId 连接已关闭，跳过发送');
        }
      } catch (e) {
        print('向客户端 $clientId 广播消息失败: $e');
      }
    }
  }

  Future<void> stopServer() async {
    if (!_isRunning) return;

    // 发送服务器关闭消息
    final shutdownMsg = WebSocketMessage(
        type: MessageType.command.toString().split('.').last,
        data: {'command': 'server_shutdown', 'message': '服务器正在关闭'});
    _broadcastMessage(json.encode(shutdownMsg.toJson()));

    // 关闭所有WebSocket连接
    for (final client in _connectedClients.values) {
      await client.sink.close(1000, '服务器关闭');
    }
    _connectedClients.clear();
    _clientDevices.clear();

    await _server?.close(force: true);
    _server = null;

    _isRunning = false;
    notifyListeners();
  }

  // 更新客户端ID（从临时ID到正式ID）
  void _updateClientId(
      String oldId, String newId, Function(String) setClientId) {
    print('更新客户端ID: $oldId -> $newId');
    print('当前连接的客户端: ${_connectedClients.keys.toList()}');

    // 检查新ID是否已存在
    if (_connectedClients.containsKey(newId)) {
      print('警告: 客户端ID $newId 已存在，无法更新');
      return;
    }

    if (_connectedClients.containsKey(oldId)) {
      final channel = _connectedClients[oldId]!;
      _connectedClients.remove(oldId);
      _connectedClients[newId] = channel;

      // 更新设备信息
      if (_clientDevices.containsKey(oldId)) {
        final deviceType = _clientDevices[oldId]!;
        _clientDevices.remove(oldId);
        _clientDevices[newId] = deviceType;
      }

      // 同步更新客户端详情
      if (_clientDetails.containsKey(oldId)) {
        final details = _clientDetails[oldId]!;
        _clientDetails.remove(oldId);
        _clientDetails[newId] = details;
      }

      setClientId(newId);
      print('客户端ID更新: $oldId -> $newId');
      _broadcastConnectionStatus();
    }
  }

  // 处理聊天消息
  void _handleChatMessage(WebSocketMessage message) {
    print('收到聊天消息 from ${message.clientId}: ${message.data}');
    // 广播聊天消息给所有客户端
    _broadcastMessage(json.encode(message.toJson()));
  }

  // 处理命令消息
  void _handleCommandMessage(WebSocketMessage message) {
    print('收到命令消息 from ${message.clientId}: ${message.data}');

    // 处理特定命令
    if (message.data is Map) {
      final commandData = message.data as Map;
      final command = commandData['command'] as String?;

      switch (command) {
        case 'ping':
          // 回复pong
          if (message.clientId != null) {
            final response = WebSocketMessage(
                type: MessageType.acknowledge.toString().split('.').last,
                clientId: message.clientId,
                data: {
                  'command': 'pong',
                  'timestamp': DateTime.now().toIso8601String()
                });
            _sendToClient(message.clientId!, json.encode(response.toJson()));
          }
          break;
        case 'broadcast':
          // 客户端请求广播消息
          _broadcastMessage(json.encode(message.toJson()));
          break;
        default:
          // 未知命令，广播出去
          _broadcastMessage(json.encode(message.toJson()));
      }
    } else {
      // 格式不正确的命令消息
      if (message.clientId != null) {
        final errorMsg = WebSocketMessage(
            type: MessageType.error.toString().split('.').last,
            clientId: message.clientId,
            data: {'message': '无效的命令格式'});
        _sendToClient(message.clientId!, json.encode(errorMsg.toJson()));
      }
    }
  }

  // 广播连接状态
  void _broadcastConnectionStatus() {
    final status = WebSocketMessage(
      type: MessageType.connectionStatus.toString().split('.').last,
      data: {
        'count': _connectedClients.length,
        'clients': _clientDevices.map((id, type) => MapEntry(id, {
              'deviceType': type,
              'connectedAt': DateTime.now().toIso8601String()
            }))
      },
    );
    _broadcastMessage(json.encode(status.toJson()));
  }

  // 广播消息给所有连接的客户端
  // void _broadcastMessage(dynamic message) {
  //   for (final client in _connectedClients.values) {
  //     try {
  //       if (client.closeCode == null) {
  //         continue;
  //       }
  //       client.sink.add(message);
  //     } catch (e) {
  //       print('广播消息失败: $e');
  //     }
  //   }
  // }

  // 发送消息给特定客户端
  void _sendToClient(String clientId, dynamic message) {
    final client = _connectedClients[clientId];
    if (client != null && client.closeCode == null) {
      try {
        client.sink.add(message);
      } catch (e) {
        print('发送消息给客户端 $clientId 失败: $e');
      }
    } else {
      print('客户端 $clientId 不存在或已关闭');
    }
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
}
