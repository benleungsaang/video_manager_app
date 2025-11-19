import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
import '../providers/tag_provider.dart';
import '../providers/video_provider.dart';

// 消息类型枚举
enum MessageType {
  chat, // 聊天消息
  command, // 命令消息
  connectionStatus, // 连接状态消息
  error, // 错误消息
  acknowledge // 确认消息
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

  // void initApiHandler(TagProvider tagProvider, VideoProvider videoProvider) {
  //   _webApiHandler = WebApiHandler(
  //     tagProvider: tagProvider,
  //     videoProvider: videoProvider,
  //   );
  // }

  Future<void> _getLocalIp() async {
    final info = NetworkInfo();
    _localIp = await info.getWifiIP();
    notifyListeners();
  }

  Future<void> clearWebCache() async {
    final tempDir = await getTemporaryDirectory();
    final webAssetsDir = Directory(p.join(tempDir.path, 'web'));

    if (await webAssetsDir.exists()) {
      await webAssetsDir.delete(recursive: true);
      print('Web资源缓存已清除');
    } else {
      print('没有可清除的Web资源缓存');
    }
    notifyListeners();
  }

  Future<void> _copyWebAssets() async {
    final tempDir = await getTemporaryDirectory();
    final webAssetsDir = Directory(p.join(tempDir.path, 'web'));
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
    final logMiddleware = logRequests(
      logger: (message, isError) {
        if (isError) {
          print('[错误 ERROR] $message');
        } else {
          print('[正常 INFO] $message');
        }
      },
    );

    // 2. CORS跨域中间件
    final corsMiddleware = corsHeaders(
      headers: {
        ACCESS_CONTROL_ALLOW_ORIGIN: '*',
        ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, DELETE, OPTIONS',
        ACCESS_CONTROL_ALLOW_HEADERS: 'Content-Type, Authorization',
        ACCESS_CONTROL_MAX_AGE: '86400', // 24小时缓存预检请求
      },
    );

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
        .addMiddleware(logMiddleware)
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

    // 配置静态资源服务
    router.all('/<path|.*>', _createStaticHandler());

    return router;
  }

  // 提取WebSocket处理为独立方法
  // 处理WebSocket连接
  void _handleWebSocketConnection(WebSocketChannel channel, Request request) {
    print('开始处理WebSocket连接');

    // 生成临时ID标识连接
    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    _connectedClients[tempId] = channel;

    // 监听客户端消息
    final subscription = channel.stream
        .listen((message) => _handleClientMessage(message, channel, tempId),
            onDone: () {
      // 连接关闭时清理
      _connectedClients.remove(tempId);
      print('WebSocket连接已关闭');
    }, onError: (error) {
      print('WebSocket错误: $error');
    });

    // 处理连接关闭
    channel.sink.done.then((_) {
      subscription.cancel();
    });
  }

  // 处理客户端消息
  void _handleClientMessage(
      dynamic message, WebSocketChannel channel, String clientId) {
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

      print('收到客户端消息: $messageJson');

      // 检查消息格式是否正确
      // if (!messageJson.containsKey('id') ||
      //     !messageJson.containsKey('action')) {
      //   throw FormatException('消息格式错误，缺少id或action');
      // }

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
      // 发送错误响应
      channel.sink.add(json.encode({'success': false, 'error': e.toString()}));
    }
  }

  final Map<String, Map<String, dynamic>> _pendingBinaryRequests = {};
  void _handleBinaryData(WebSocketChannel channel, String clientId, Uint8List data) {
    if (!_pendingBinaryRequests.containsKey(clientId)) {
      channel.sink.add(json.encode({
        'success': false,
        'error': '未找到对应的二进制请求'
      }));
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
      requestId: requestId
    );
  }

  // 提取静态资源处理器
  Handler _createStaticHandler() {
    return (Request request) async {
      final tempDir = await getTemporaryDirectory();
      final webAssetsDir = Directory('${tempDir.path}/web');
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
    for (final client in _connectedClients.values) {
      try {
        // 修复判断逻辑：只有当连接未关闭时才发送消息
        if (client.closeCode == null) {
          client.sink.add(message);
        }
      } catch (e) {
        print('广播消息失败: $e');
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
          final response = WebSocketMessage(
              type: MessageType.acknowledge.toString().split('.').last,
              clientId: message.clientId,
              data: {
                'command': 'pong',
                'timestamp': DateTime.now().toIso8601String()
              });
          _sendToClient(message.clientId!, json.encode(response.toJson()));
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
      final errorMsg = WebSocketMessage(
          type: MessageType.error.toString().split('.').last,
          clientId: message.clientId,
          data: {'message': '无效的命令格式'});
      _sendToClient(message.clientId!, json.encode(errorMsg.toJson()));
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
}
