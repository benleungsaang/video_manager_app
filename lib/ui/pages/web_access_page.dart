import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import '../../services/server_service.dart';
import 'package:provider/provider.dart';

class WebAccessPage extends StatefulWidget {
  const WebAccessPage({super.key});

  @override
  State<WebAccessPage> createState() => _WebAccessPageState();
}

class _WebAccessPageState extends State<WebAccessPage> {
  late WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // 初始化平台特定参数
    final params = _createPlatformParams();

    // 使用最新的控制器初始化方式
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'JS_ERROR_CHANNEL',
        onMessageReceived: (message) {
          print('页面JS错误: ${message.message}');
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
            // 新增HTTP错误处理
            print('HTTP错误: ${error}');
          },
          onWebResourceError: (WebResourceError error) {
            // 区分主框架错误
            if (error.isForMainFrame == true) {
              print('主框架资源错误: ${error.description}');
            } else {
              print('子资源错误: ${error.description}');
            }
            print('错误URL: ${error.url}');
            print('错误代码: ${error.errorCode}');
          },
          onNavigationRequest: (NavigationRequest request) {
            // 新增导航请求拦截
            // 可添加URL过滤逻辑
            return NavigationDecision.navigate;
          },
        ),
      )
      ..setOnConsoleMessage((consoleMessage) {
        print('JS控制台: ${consoleMessage.message}');
      })
      ..runJavaScript('''
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
