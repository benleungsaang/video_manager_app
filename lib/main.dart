import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_manager_app/services/server_service.dart';
// import 'package:hive_flutter/hive_flutter.dart';
import 'services/hive_service.dart';
import 'providers/video_provider.dart';
import 'providers/tag_provider.dart';
import 'providers/transcode_provider.dart';
import 'ui/pages/home_page.dart';
import 'utils/file_utils.dart'; // 引入文件工具类
import 'utils/storage_utils.dart'; // 引入存储工具类

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 确保添加这行
  // 初始化新的存储目录
  await StorageUtils.init();
  // 初始化Hive数据库
  await HiveService.init();

  // 初始化时生成所有视频的缩略图（如果缺失）
  final tagProvider = TagProvider()..loadTags();
  final videoProvider = VideoProvider()..loadVideos();
  final serverService = ServerService();

  // serverService.initApiHandler(tagProvider, videoProvider); // 关联中转层

  final videoPaths = videoProvider.videos
      .where((v) => v.thumbnailPath == null)
      .map((v) => v.filePath)
      .toList();
  if (videoPaths.isNotEmpty) {
    await FileUtils.generateThumbnailsForVideos(videoPaths);
    // 重新加载视频列表（更新缩略图路径）
    videoProvider.loadVideos();
  }

  // runApp(const MyApp());
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: videoProvider), // 使用已创建的实例
        ChangeNotifierProvider.value(value: tagProvider), // 使用已创建的实例
        ChangeNotifierProvider.value(value: serverService), // 使用已初始化的实例
      ],
      child: const MyApp(),
    ),
  );
}

// 全局导航键，用于在非组件上下文中访问Provider
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 用于同时注册多个状态管理器（Provider），使整个应用可以共享这些状态。
    return MultiProvider(
      providers: [
        // ChangeNotifierProvider：具体的状态提供者，将VideoProvider和TagProvider实例注入到应用中
        // 注册后，应用中任何子组件都可以通过Provider.of<VideoProvider>(context)获取视频数据，实现跨组件数据共享。
        // 主要共享以下核心状态：
        // 【视频/标签】 列表：通过 List<Tag> _tags 存储所有标签数据（包括标签名称、ID、关联视频数量等），可通过 tags 属性获取。
        // 【视频/标签】 操作能力：提供加载、创建、更新、删除标签的方法（如 createTag()、deleteTag() 等），子组件调用后会同步更新全局状态。
        ChangeNotifierProvider(create: (_) => VideoProvider()..loadVideos()),
        ChangeNotifierProvider(create: (_) => TagProvider()..loadTags()),
        ChangeNotifierProvider(create: (_) => TranscodeProvider()),
        // ChangeNotifierProvider(create: (_) => ServerService()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey, // 配置全局key
        title: '视频管理APP',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          // 平板适配主题
          appBarTheme: const AppBarTheme(
            toolbarHeight: 60,
            titleTextStyle: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        home: HomePage(),
      ),
    );
  }
}

// 保活服务管理类
class KeepAliveManager {
  static const MethodChannel _channel = MethodChannel('keep_alive_channel');

  // 启动前台服务
  static Future<void> startForegroundService() async {
    try {
      await _channel.invokeMethod('startForegroundService');
    } on PlatformException catch (e) {
      print('启动前台服务失败: ${e.message}');
    }
  }

  // 停止前台服务
  static Future<void> stopForegroundService() async {
    try {
      await _channel.invokeMethod('stopForegroundService');
    } on PlatformException catch (e) {
      print('停止前台服务失败: ${e.message}');
    }
  }

  // 请求忽略电池优化
  static Future<bool> requestIgnoreBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod('requestIgnoreBatteryOptimizations') ??
          false;
    } on PlatformException catch (e) {
      print('请求忽略电池优化失败: ${e.message}');
      return false;
    }
  }
}
