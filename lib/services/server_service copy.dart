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

  void initApiHandler(TagProvider tagProvider, VideoProvider videoProvider) {
    _webApiHandler = WebApiHandler(
      tagProvider: tagProvider,
      videoProvider: videoProvider,
    );
  }

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

    if (customPort != null) {
      if (customPort < 1024 || customPort > 65535) {
        throw Exception("端口必须在1024-65535范围内");
      }
      _port = customPort;
    }

    await _getLocalIp();

    final router = Router();

    final corsMiddleware = corsHeaders(
      headers: {
        ACCESS_CONTROL_ALLOW_ORIGIN: '*',
        ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, DELETE, OPTIONS',
        ACCESS_CONTROL_ALLOW_HEADERS: 'Content-Type',
      },
    );

    // WebSocket连接处理（增强版）
    router.get(
      '/ws',
      webSocketHandler((WebSocketChannel channel, Request request) {
        print('检测到WebSocket连接请求，开始处理');
        String? clientId;
        final deviceType = _getDeviceType(request.headers['user-agent']);

        // 生成临时ID，直到客户端发送身份验证
        final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
        // print(
        // '新客户端临时连接: temp_${DateTime.now().microsecondsSinceEpoch}, 设备类型: $deviceType');
        _connectedClients[tempId] = channel;
        _clientDevices[tempId] = deviceType;

        _broadcastConnectionStatus();

        // 向客户端发送连接成功消息
        final welcomeMessage = WebSocketMessage(
            type: MessageType.acknowledge.toString().split('.').last,
            data: {'message': '连接成功，请发送身份信息', 'tempId': tempId});
        channel.sink.add(json.encode(welcomeMessage.toJson()));

        // 监听客户端消息
        final subscription = channel.stream.listen((message) {
          try {
            // 处理消息
            _handleClientMessage(message, channel, tempId, (String newId) {
              clientId = newId;
            });
          } catch (e) {
            print('处理消息错误: $e');
            final errorMsg = WebSocketMessage(
                type: MessageType.error.toString().split('.').last,
                clientId: clientId ?? tempId,
                data: {'message': '消息处理错误: ${e.toString()}'});
            channel.sink.add(json.encode(errorMsg.toJson()));
          }
        }, onDone: () {
          // 客户端断开连接
          final removedId = clientId ?? tempId;
          _connectedClients.remove(removedId);
          _clientDevices.remove(removedId);
          print('客户端断开连接: $removedId');
          _broadcastConnectionStatus();
        }, onError: (error) {
          print('WebSocket错误: $error');
          final errorId = clientId ?? tempId;
          final errorMsg = WebSocketMessage(
              type: MessageType.error.toString().split('.').last,
              clientId: errorId,
              data: {'message': '连接错误: ${error.toString()}'});
          channel.sink.add(json.encode(errorMsg.toJson()));
        });

        // 处理连接关闭
        channel.sink.done.then((_) {
          subscription.cancel();
        });
      }),
    );

    // 文件上传接口
    router.post('/upload', (Request request) async {
      return Response.ok('上传成功');
    });

    // 配置静态资源服务
    final tempDir = await getTemporaryDirectory();
    final webAssetsDir = Directory('${tempDir.path}/web');

    if (!await webAssetsDir.exists()) {
      await _copyWebAssets();
    }

    final staticHandler = createStaticHandler(
      webAssetsDir.path,
      defaultDocument: 'index.html',
      listDirectories: false,
    );

    router.all('/<path|.*>', staticHandler);

    _server = await serve(
      const Pipeline()
          .addMiddleware(logRequests())
          .addMiddleware(corsMiddleware)
          .addHandler(router.call),
      InternetAddress.anyIPv4,
      _port,
    );

    _isRunning = true;
    notifyListeners();
    print('服务器启动于 http://${_localIp}:${_port}');
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

  // 处理客户端消息
  void _handleClientMessage(dynamic message, WebSocketChannel channel,
      String tempId, Function(String) setClientId) {
    try {
      // 解析消息
      Map<String, dynamic> messageJson;

      if (message is String) {
        messageJson = json.decode(message);
      } else if (message is List<int>) {
        messageJson = json.decode(utf8.decode(message));
      } else {
        throw FormatException('不支持的消息格式');
      }

      final wsMessage = WebSocketMessage.fromJson(messageJson);

      // 处理身份验证消息（首次消息应该是身份验证）
      if (wsMessage.type == 'identify' && wsMessage.data is Map) {
        final clientId = wsMessage.data['clientId'] as String?;

        if (clientId == null || clientId.isEmpty) {
          throw Exception('客户端ID不能为空');
        }

        // 检查客户端ID是否已存在
        if (_connectedClients.containsKey(clientId)) {
          // 生成一个新的唯一ID
          final newClientId =
              '${clientId}_${DateTime.now().microsecondsSinceEpoch}';
          final errorMsg = WebSocketMessage(
              type: MessageType.error.toString().split('.').last,
              data: {'message': 'ID已存在，已分配新ID', 'newClientId': newClientId});
          channel.sink.add(json.encode(errorMsg.toJson()));
          _updateClientId(tempId, newClientId, setClientId);
        } else {
          // 使用客户端提供的ID
          _updateClientId(tempId, clientId, setClientId);
        }

        // 发送确认消息
        final ackMsg = WebSocketMessage(
            type: MessageType.acknowledge.toString().split('.').last,
            clientId: wsMessage.data['clientId'],
            data: {'message': '身份验证成功'});
        channel.sink.add(json.encode(ackMsg.toJson()));
        return;
      }

      // 验证客户端是否已认证
      if (wsMessage.clientId == null ||
          !_connectedClients.containsKey(wsMessage.clientId)) {
        throw Exception('未认证的客户端，请先发送身份信息');
      }

      // 根据消息类型处理
      switch (wsMessage.type) {
        case 'chat':
          _handleChatMessage(wsMessage);
          break;
        case 'command':
          _handleCommandMessage(wsMessage);
          break;
        default:
          // 未知消息类型，广播出去
          _broadcastMessage(json.encode(wsMessage.toJson()));
      }
    } catch (e) {
      print('消息处理错误: $e');
      final errorMsg = WebSocketMessage(
          type: MessageType.error.toString().split('.').last,
          data: {'message': e.toString()});
      channel.sink.add(json.encode(errorMsg.toJson()));
    }
  }

  // 更新客户端ID（从临时ID到正式ID）
  void _updateClientId(
      String oldId, String newId, Function(String) setClientId) {
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
  void _broadcastMessage(dynamic message) {
    for (final client in _connectedClients.values) {
      try {
        if (client.closeCode == null) {
          continue;
        }
        client.sink.add(message);
      } catch (e) {
        print('广播消息失败: $e');
      }
    }
  }

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
