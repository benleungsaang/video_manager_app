import 'dart:async';
import 'dart:convert';
import 'dart:io';
// import 'package:dhttpd/dhttpd.dart';
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
import 'package:flutter/services.dart'; // 导入AssetManifest

class ServerService with ChangeNotifier {
  bool _isRunning = false;
  int _port = 8080;
  String? _localIp;
  final Set<WebSocketChannel> _connectedClients = {};
  final Map<String, String> _clientDevices = {}; // 存储客户端设备信息
  HttpServer? _server; // 保存服务器实例，用于后续保证服务器能被完整关闭并再次启动

  bool get isRunning => _isRunning;
  int get port => _port;
  String? get localIp => _localIp;
  int get connectionCount => _connectedClients.length;
  Map<String, String> get clientDevices => _clientDevices;

  // 获取本地IP地址
  Future<void> _getLocalIp() async {
    final info = NetworkInfo();
    _localIp = await info.getWifiIP();
    notifyListeners();
  }

  // 手动清除Web资源缓存
  Future<void> clearWebCache() async {
    final tempDir = await getTemporaryDirectory();
    final webAssetsDir = Directory(p.join(tempDir.path, 'web'));

    if (await webAssetsDir.exists()) {
      await webAssetsDir.delete(recursive: true);
      print('Web资源缓存已清除');
    } else {
      print('没有可清除的Web资源缓存');
    }
    notifyListeners(); // 通知UI状态更新
  }

  // 递归复制assets中的Web资源到目标目录
  Future<void> _copyWebAssets() async {
    final tempDir = await getTemporaryDirectory();
    final webAssetsDir = Directory(p.join(tempDir.path, 'web'));
    await webAssetsDir.create(recursive: true);

    try {
      // ########## 关键变更：使用AssetManifest API获取资源列表 ##########
      final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final allAssets = await assetManifest.listAssets(); // 获取所有资源路径

      // ########## 检查静态目录中的文件 ，以及确认AssetManifest.bin包含的文件 ##########
      // for (final assetPath in allAssets) {
      //   print('静态目录: $assetPath');
      // }

      // final pathToAssetManifest = '/data/local/tmp/AssetManifest.bin';
      // final manifest = File(pathToAssetManifest).readAsBytesSync();
      // final decoded = const StandardMessageCodec()
      //     .decodeMessage(ByteData.sublistView(manifest));
      // final assets = decoded.keys.cast<String>().toList();

      // for (final assetPath in assets) {
      //   print('AssetManifest中文件: $assetPath');
      // }

      // ########## 检查静态目录中的文件 ，以及确认AssetManifest.bin包含的文件 ##########

      // 过滤出 build/web 目录下的资源（仅复制Web相关文件）
      final webAssetPaths = allAssets
          .where((path) =>
                  path.startsWith('build/web/') ||
                  // path.startsWith('assets/') || // 包含根目录assets
                  // path.startsWith('fonts/') || // 包含根目录assets
                  path.startsWith('packages/') // 包含第三方包资源
              // path.endsWith('FontManifest.json') // 显式包含字体清单文件
              )
          .toList();

      if (webAssetPaths.isEmpty) {
        throw Exception('未找到build/web目录下的资源，请检查pubspec.yaml配置');
      }

      print('开始复制Web资源（共 ${webAssetPaths.length} 个文件）...');

      // 逐个复制资源到临时目录
      for (final assetPath in webAssetPaths) {
        // 资源路径示例：build/web/index.html → 目标路径：temp/web/index.html

        String relativePath;
        if (assetPath.startsWith('build/web/')) {
          relativePath = p.relative(assetPath, from: 'build/web');
        } else if (assetPath.startsWith('assets/')) {
          // 对于assets目录，保留完整路径（包括assets前缀）
          relativePath = assetPath;
        } else if (assetPath.startsWith('packages/')) {
          // 对于packages目录，添加assets前缀以匹配请求路径
          relativePath = 'assets/${assetPath}';
        } else {
          continue; // 跳过其他目录
        }

        final targetFile = File(p.join(webAssetsDir.path, relativePath));

        // 打印当前正在复制的文件名
        print('复制文件: $relativePath');

        // 确保目标目录存在
        await targetFile.parent.create(recursive: true);

        // 读取资源（支持二进制文件，如图片、JS等）
        final byteData = await rootBundle.load(assetPath);
        await targetFile.writeAsBytes(byteData.buffer.asUint8List());
      }

      print('Web资源复制完成，共 ${webAssetPaths.length} 个文件');
    } catch (e) {
      print('复制Web资源失败：$e');
      // 清除不完整的缓存
      if (await webAssetsDir.exists()) {
        await webAssetsDir.delete(recursive: true);
      }
      rethrow;
    }
  }

  // 启动服务器
  Future<void> startServer({int? customPort}) async {
    if (_isRunning) return;

    if (customPort != null) {
      if (customPort < 1024 || customPort > 65535) {
        throw Exception("端口必须在1024-65535范围内");
      }
      _port = customPort;
    }

    await _getLocalIp();

    // 创建路由
    final router = Router();

    // 配置CORS
    final corsMiddleware = corsHeaders(
      headers: {
        ACCESS_CONTROL_ALLOW_ORIGIN: '*',
        ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, DELETE, OPTIONS',
        ACCESS_CONTROL_ALLOW_HEADERS: 'Content-Type',
      },
    );

    // WebSocket连接处理（用于实时同步）
    router.get(
      '/ws',
      webSocketHandler((WebSocketChannel channel, Request request) {
        // 记录新连接
        _connectedClients.add(channel);
        _clientDevices[channel.hashCode.toString()] =
            _getDeviceType(request.headers['user-agent']);

        // 发送连接通知
        _broadcastConnectionStatus();

        // 监听客户端消息
        channel.stream.listen(
          (message) {
            // 处理客户端消息并广播给所有连接
            _broadcastMessage(message);
          },
          onDone: () {
            // 客户端断开连接
            _connectedClients.remove(channel);
            _clientDevices.remove(channel.hashCode.toString());
            _broadcastConnectionStatus();
          },
        );
      }),
    );

    // 文件上传接口
    router.post('/upload', (Request request) async {
      // 处理视频上传逻辑
      // final multipart = await request.readAsString();
      // 实现文件保存逻辑...
      return Response.ok('上传成功');
    });

    // 配置静态资源服务（指向build/web目录）
    // 获取当前项目中build/web的绝对路径
    // 1. 获取APP的临时目录（平板端可读写的路径）
    final tempDir = await getTemporaryDirectory();
    final webAssetsDir = Directory('${tempDir.path}/web');

    // print('静态资源服务根目录: ${webAssetsDir.path}');

    // 2. 如果临时目录中没有Web资源，从APP资源中复制过去
    if (!await webAssetsDir.exists()) {
      // await webAssetsDir.create(recursive: true);
      // 复制build/web目录下的所有文件（需遍历资源列表）
      await _copyWebAssets();
    }

    // 创建静态资源处理器
    final staticHandler = createStaticHandler(
      webAssetsDir.path, // 指向临时目录中的web文件夹
      defaultDocument: 'index.html', // Flutter Web默认入口文件
      listDirectories: false, // 禁止目录列表
    );

    // 将静态资源处理器添加到路由（作为默认路由，放在最后）
    // router.all('/<ignored|.*>', staticHandler);
    router.all('/<path|.*>', staticHandler);

    // 静态资源服务（用于Web端页面）
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

  // 停止服务器
  Future<void> stopServer() async {
    if (!_isRunning) return;

    // 关闭所有WebSocket连接
    for (final client in _connectedClients) {
      client.sink.close();
    }
    _connectedClients.clear();
    _clientDevices.clear();

    await _server?.close(force: true); // force: true确保强制关闭
    _server = null; // 清空实例引用

    _isRunning = false;
    notifyListeners();
  }

  // 广播连接状态
  void _broadcastConnectionStatus() {
    final status = {
      'type': 'connection_status',
      'count': _connectedClients.length,
      'devices': _clientDevices,
    };
    _broadcastMessage(json.encode(status));
  }

  // 广播消息给所有连接的客户端
  void _broadcastMessage(dynamic message) {
    for (final client in _connectedClients) {
      client.sink.add(message);
    }
  }

  // 从User-Agent判断设备类型
  String _getDeviceType(String? userAgent) {
    if (userAgent == null) return '未知设备';
    if (userAgent.contains('Mobile')) {
      return '手机';
    } else if (userAgent.contains('Tablet')) {
      return '平板';
    } else {
      return '电脑';
    }
  }

  // 修改端口
  void setPort(int newPort) {
    if (newPort < 1024 || newPort > 65535) {
      throw Exception("端口必须在1024-65535范围内");
    }
    _port = newPort;
    notifyListeners();
  }
}
