import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../services/server_service.dart';
import 'package:provider/provider.dart';
import '../../providers/video_provider.dart';
import '../../providers/tag_provider.dart';
import '../../models/video.dart';
import '../../models/tag.dart';
import 'dart:convert';
import 'dart:io';
import 'package:fluttertoast/fluttertoast.dart';
import '../../utils/file_utils.dart';
import '../../utils/video_uploader.dart';
import 'package:path_provider/path_provider.dart';

class WebAccessPage extends StatefulWidget {
  const WebAccessPage({super.key});

  @override
  State<WebAccessPage> createState() => _WebAccessPageState();
}

class _WebAccessPageState extends State<WebAccessPage> {
  late WebViewController _controller;
  // 存储JS调用的处理函数
  final Map<String, Function(List<dynamic>)> _jsHandlers = {};

  @override
  void initState() {
    super.initState();
    // 初始化平台特定参数
    final params = _createPlatformParams();

    // 注册JS调用处理函数
    _registerJsHandlers();

    // 使用最新的控制器初始化方式
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'JS_ERROR_CHANNEL',
        onMessageReceived: (message) {
          print('页面JS错误: ${message.message}');
        },
      )
      // 添加主通信通道
      ..addJavaScriptChannel(
        'FLUTTER_CHANNEL',
        onMessageReceived: (message) async {
          await _handleJsMessage(message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // 可添加加载进度显示逻辑
          },
          onPageStarted: (String url) {
            print('开始加载页面: $url');
          },
          onPageFinished: (String url) {
            print('页面加载完成: $url');
          },
          onHttpError: (HttpResponseError error) {
            print('HTTP错误: ${error}');
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == true) {
              print('主框架资源错误: ${error.description}');
            } else {
              print('子资源错误: ${error.description}');
            }
            print('错误URL: ${error.url}');
            print('错误代码: ${error.errorCode}');
          },
          onNavigationRequest: (NavigationRequest request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setOnConsoleMessage((consoleMessage) {
        print('JS控制台: ${consoleMessage.message}');
      })
      ..runJavaScript('''
        // 定义供Flutter调用的JS函数
        window.flutter = {
          // 调用Flutter方法
          callHandler: function(methodName, ...args) {
            return new Promise((resolve) => {
              const requestId = Math.random().toString(36).substring(2, 15);

              // 存储回调函数
              window.flutter.callbacks[requestId] = resolve;

              // 发送消息到Flutter
              FLUTTER_CHANNEL.postMessage(JSON.stringify({
                method: methodName,
                args: args,
                requestId: requestId
              }));
            });
          },
          // 存储回调函数
          callbacks: {}
        };

        window.addEventListener('error', function(e) {
          JS_ERROR_CHANNEL.postMessage('运行时错误: ' + e.message + ' 位置: ' + e.filename + ':' + e.lineno);
        });
        window.addEventListener('unhandledrejection', function(e) {
          JS_ERROR_CHANNEL.postMessage('Promise错误: ' + e.reason);
        });
      ''');

    // 配置平台特定功能
    _configurePlatformFeatures();
  }

  // 注册JS调用的处理函数
  void _registerJsHandlers() {
    _jsHandlers['getVideos'] = (args) async {
      return await _getVideosForWeb();
    };
    _jsHandlers['getTags'] = (args) async {
      return await _getTagsForWeb();
    };
    _jsHandlers['uploadVideo'] = (args) async {
      final fileName = args[0] as String;
      final base64Data = args[1] as String;
      return await _handleWebVideoUpload(fileName, base64Data);
    };
    _jsHandlers['addTag'] = (args) async {
      final tagName = args[0] as String;
      return await _addTagFromWeb(tagName);
    };
    _jsHandlers['deleteTag'] = (args) async {
      final tagId = args[0] as String;
      return await _deleteTagFromWeb(tagId);
    };
    _jsHandlers['addTagToVideo'] = (args) async {
      final videoId = args[0] as String;
      final tagId = args[1] as String;
      return await _addTagToVideoFromWeb(videoId, tagId);
    };
  }

  // 处理JS发送的消息
  Future<void> _handleJsMessage(JavaScriptMessage message) async {
    try {
      final data = json.decode(message.message);
      final method = data['method'] as String;
      final args = data['args'] as List<dynamic>;
      final requestId = data['requestId'] as String;

      // 查找并执行对应的处理函数
      if (_jsHandlers.containsKey(method)) {
        final result = await _jsHandlers[method]!(args);

        // 将结果返回给JS
        await _controller.runJavaScript('''
          if (window.flutter.callbacks['$requestId']) {
            window.flutter.callbacks['$requestId'](${json.encode(result)});
            delete window.flutter.callbacks['$requestId'];
          }
        ''');
      } else {
        print('未找到对应的处理函数: $method');
        await _controller.runJavaScript('''
          if (window.flutter.callbacks['$requestId']) {
            window.flutter.callbacks['$requestId']({error: 'Method not found: $method'});
            delete window.flutter.callbacks['$requestId'];
          }
        ''');
      }
    } catch (e) {
      print('处理JS消息出错: $e');
    }
  }

  // 为Web端准备视频数据
  Future<List<Map<String, dynamic>>> _getVideosForWeb() async {
    final videoProvider = Provider.of<VideoProvider>(context, listen: false);
    final tagProvider = Provider.of<TagProvider>(context, listen: false);

    // 确保视频数据已加载
    if (videoProvider.videos.isEmpty) {
      videoProvider.loadVideos();
    }

    final List<Map<String, dynamic>> webVideos = [];

    for (final video in videoProvider.videos) {
      // 获取视频关联的标签详情
      final tags = video.tagIds
          .map((id) => tagProvider.getTagById(id))
          .where((tag) => tag != null)
          .cast<Tag>()
          .toList();

      // 获取缩略图Base64（用于Web显示）
      String? thumbnailBase64;
      if (video.thumbnailPath != null) {
        final file = File(video.thumbnailPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          thumbnailBase64 = base64Encode(bytes);
        }
      }

      webVideos.add({
        'id': video.id,
        'title': video.title,
        'filePath': video.filePath,
        'duration': video.duration,
        'uploadTime': video.uploadTime.toIso8601String(),
        'thumbnailPath': video.thumbnailPath,
        'thumbnailBase64': thumbnailBase64,
        'tagIds': video.tagIds,
        'tags': tags
            .map((t) => {
                  'id': t.id,
                  'name': t.name,
                })
            .toList(),
      });
    }

    return webVideos;
  }

  // 为Web端准备标签数据
  Future<List<Map<String, dynamic>>> _getTagsForWeb() async {
    final tagProvider = Provider.of<TagProvider>(context, listen: false);

    // 确保标签数据已加载
    if (tagProvider.tags.isEmpty) {
      tagProvider.loadTags();
    }

    // 计算每个标签关联的视频数量
    final videoProvider = Provider.of<VideoProvider>(context, listen: false);
    videoProvider.loadVideos();

    return tagProvider.tags.map((tag) {
      // 计算关联视频数量
      final count = videoProvider.videos
          .where((video) => video.tagIds.contains(tag.id))
          .length;

      return {
        'id': tag.id,
        'name': tag.name,
        'videoCount': count,
      };
    }).toList();
  }

  // 处理Web端上传的视频
  Future<Map<String, dynamic>> _handleWebVideoUpload(
      String fileName, String base64Data) async {
    try {
      // 将Base64数据转换为文件
      final bytes = base64Decode(base64Data);
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName');
      await tempFile.writeAsBytes(bytes);

      // 复制到应用目录并添加到库中
      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      final newVideo = await VideoUploader.copyToAppDirectory(
        tempFile,
        fileName.split('.').first, // 使用文件名作为标题（不含扩展名）
        [], // 初始无标签
        videoProvider,
      );

      // 生成缩略图
      if (newVideo != null) {
        final thumbnailPath =
            await FileUtils.generateVideoThumbnail(newVideo.filePath);
        newVideo.thumbnailPath = thumbnailPath;
        await videoProvider.saveVideo(newVideo);
      }

      Fluttertoast.showToast(msg: '视频上传成功');
      return {
        'success': true,
        'videoId': newVideo?.id,
      };
    } catch (e) {
      print('Web视频上传失败: $e');
      Fluttertoast.showToast(msg: '视频上传失败: ${e.toString()}');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // 从Web端添加标签
  Future<Map<String, dynamic>?> _addTagFromWeb(String tagName) async {
    try {
      final tagProvider = Provider.of<TagProvider>(context, listen: false);
      final newTag = await tagProvider.createTag(tagName);

      if (newTag != null) {
        return {
          'id': newTag.id,
          'name': newTag.name,
          'videoCount': 0,
        };
      }
      return null;
    } catch (e) {
      print('添加标签失败: $e');
      return null;
    }
  }

  // 从Web端删除标签
  Future<bool> _deleteTagFromWeb(String tagId) async {
    try {
      final tagProvider = Provider.of<TagProvider>(context, listen: false);
      await tagProvider.deleteTag(tagId);
      return true;
    } catch (e) {
      print('删除标签失败: $e');
      return false;
    }
  }

  // 从Web端为视频添加标签
  Future<bool> _addTagToVideoFromWeb(String videoId, String tagId) async {
    try {
      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      final video = videoProvider.getVideoById(videoId);

      if (video != null && !video.tagIds.contains(tagId)) {
        video.tagIds.add(tagId);
        await videoProvider.saveVideo(video);

        // 更新标签的视频计数
        final tagProvider = Provider.of<TagProvider>(context, listen: false);
        await tagProvider.recalculateVideoCounts();

        return true;
      }
      return false;
    } catch (e) {
      print('为视频添加标签失败: $e');
      return false;
    }
  }

  // 创建平台特定参数
  PlatformWebViewControllerCreationParams _createPlatformParams() {
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      return WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true, // iOS/macOS支持 inline 媒体播放
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{}, // 无需用户交互即可播放媒体
      );
    } else {
      return const PlatformWebViewControllerCreationParams();
    }
  }

  // 配置平台特定功能
  void _configurePlatformFeatures() {
    // Android平台配置
    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true); // 启用调试
      (_controller.platform as AndroidWebViewController)
        ..setMediaPlaybackRequiresUserGesture(false); // 无需用户交互即可播放媒体
    }

    // iOS平台配置
    if (_controller.platform is WebKitWebViewController) {
      (_controller.platform as WebKitWebViewController)
        ..setAllowsBackForwardNavigationGestures(true); // 启用滑动返回手势
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ServerService>(
      builder: (context, serverService, child) {
        if (serverService.isRunning && serverService.localIp != null) {
          // 使用最新的loadRequest方法
          _controller.loadRequest(
            Uri.parse('http://${serverService.localIp}:${serverService.port}'),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Web访问'),
          ),
          body: serverService.isRunning
              ? WebViewWidget(controller: _controller)
              : const Center(
                  child: Text('请先启动服务器'),
                ),
        );
      },
    );
  }
}
