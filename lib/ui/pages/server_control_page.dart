import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart'; // 新增导入
import '../../main.dart';
import '../../services/server_service.dart';

class ServerControlPage extends StatefulWidget {
  const ServerControlPage({super.key});

  @override
  State<ServerControlPage> createState() => _ServerControlPageState();
}

class _ServerControlPageState extends State<ServerControlPage> {
  late TextEditingController _portController;
  // 存储客户端备注控制器的映射表，key为clientId
  final Map<String, TextEditingController> _clientRemarkControllers = {};

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController();

    // 检查并请求电池优化豁免
    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        final isIgnoring =
            await KeepAliveManager.requestIgnoreBatteryOptimizations();
        if (!isIgnoring) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请允许应用忽略电池优化以保持后台运行')),
            );
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _portController.dispose();
    // 释放所有客户端备注控制器
    for (var controller in _clientRemarkControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // 获取客户端备注控制器，如果不存在则创建
  TextEditingController _getRemarkController(String clientId, String? remark) {
    if (!_clientRemarkControllers.containsKey(clientId)) {
      _clientRemarkControllers[clientId] = TextEditingController(text: remark);
    }
    return _clientRemarkControllers[clientId]!;
  }

  // 通过clientId获取客户端显示名称（备注名优先，无备注则显示缩写ID）
  String _getClientDisplayName(String clientId, ServerService serverService) {
    // clientDetails已移除，因为不再使用WebSocket
    // 直接返回缩写ID
    return _truncateClientId(clientId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器控制'),
        backgroundColor: Colors.blue[800],
        centerTitle: true,
      ),
      body: Consumer<ServerService>(
        builder: (context, serverService, child) {
          _portController.text = serverService.port.toString();

          // 初始化新客户端的备注控制器 - clientDetails已移除，因为不再使用WebSocket

          return Row(
            children: [
              // 左侧：服务器控制区域

              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 服务器开关按钮

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (serverService.isRunning) {
                              await serverService.stopServer();

                              await KeepAliveManager.stopForegroundService();
                            } else {
                              try {
                                final port = int.parse(_portController.text);

                                await serverService.startServer(
                                    customPort: port);

                                await KeepAliveManager.startForegroundService();
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: serverService.isRunning
                                ? Colors.red
                                : Colors.green,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: Text(
                            serverService.isRunning ? '停止服务器' : '启动服务器',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 清除缓存按钮

                      if (!serverService.isRunning)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              await serverService.clearWebCache();

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                    'Web资源缓存已清除',
                                  )),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Text('清除Web资源缓存',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18)),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // 连接信息

                      if (serverService.isRunning &&
                          serverService.localIp != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('连接信息',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              SelectableText(
                                '内网地址: http://${serverService.localIp}:${serverService.port}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

                      // 端口设置

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('端口设置',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _portController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: '输入端口(1024-65535)',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              enabled: !serverService.isRunning,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 36),

                      // 数据库导出按钮

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              final exportPath =
                                  await serverService.exportDatabase();

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                    '数据库已导出至: $exportPath',
                                  )),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('导出失败: $e')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text('导出数据库',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 数据库导入按钮

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              final result =
                                  await FilePicker.platform.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: ['json'],
                                dialogTitle: '选择数据库JSON文件',
                              );

                              if (result != null &&
                                  result.files.single.path != null) {
                                final filePath = result.files.single.path!;

                                await serverService.importDatabase(filePath);

                                if (mounted) {
                                  // 显示成功信息
                                  final snackBar = SnackBar(
                                    content: Text('数据库导入成功'),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 3),
                                  );
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(snackBar);
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                // 显示错误信息
                                final snackBar = SnackBar(
                                  content: Text('导入失败: $e'),
                                  backgroundColor: Colors.red,
                                  duration: const Duration(seconds: 3),
                                );
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(snackBar);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple[600],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text('导入数据库',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 分割线

              Container(
                width: 1,
                color: Colors.grey[300],
              ),

              // 右侧：客户端和日志区域

              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 客户端列表标题

                      Row(
                        children: [
                          const Text('客户端列表',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Text('(HTTP API)',
                              style: const TextStyle(fontSize: 16)),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // 客户端列表滚动区域

                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: serverService.isRunning &&
                                  false // clientDetails已移除，因为不再使用WebSocket
                              ? ListView(
                                                                    children: [], // clientDetails.entries已移除，因为不再使用WebSocket
                                )
                              : serverService.isRunning
                                  ? const Center(
                                      child: Text('暂无客户端连接',
                                          style: TextStyle(fontSize: 16)),
                                    )
                                  : const Center(
                                      child: Text('服务器未运行',
                                          style: TextStyle(fontSize: 16)),
                                    ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // 消息日志标题

                      const Text('消息日志',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),

                      const SizedBox(height: 12),

                      // 消息日志滚动区域

                      Expanded(
                        flex: 1,
                        child: Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: true // messageLogs已移除，因为不再使用WebSocket
                              ? const Center(
                                  child: Text('暂无消息日志',
                                      style: TextStyle(fontSize: 16)))
                              : ListView.builder(
                                  reverse: true, // 新消息在底部

                                  itemCount: 0, // messageLogs已移除，因为不再使用WebSocket

                                  itemBuilder: (context, index) {
                                    // messageLogs已移除，因为不再使用WebSocket
                                    final log = "No logs (HTTP API)";

                                    return _buildLogItem(log, serverService);
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 构建客户端卡片

  Widget _buildClientCard(
      String clientId, String details, ServerService serverService) {
    // details参数现在是String类型，因为ClientDetails类已移除
    final displayName = _truncateClientId(clientId);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        title: Text(displayName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('HTTP Client'),
        children: [
          const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text('使用HTTP API进行通信'),
          ),
        ],
      ),
    );
  }

  // 构建格式化的日志条目 - 简化版本，因为不再使用WebSocket
  Widget _buildLogItem(String log, ServerService serverService) {
    // MessageLog和clientDetails已移除，因为不再使用WebSocket
    return Card(
      margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'HTTP',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'HTTP API',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  DateTime.now().toString().substring(0, 19),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              log,
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

// 辅助方法1：解析日志数据（兼容 JSON/字符串/其他类型）
  Map<String, dynamic> _parseLogData(dynamic data) {
    if (data == null) return {};

    // 如果是字符串，尝试解析为 JSON
    if (data is String) {
      try {
        return json.decode(data) as Map<String, dynamic>;
      } catch (e) {
        // 非 JSON 字符串，直接封装为 action
        return {'action': data, 'params': '无'};
      }
    }

    // 如果是 Map，直接返回
    if (data is Map<String, dynamic>) {
      return data;
    }

    // 其他类型（如数字、布尔），转为字符串
    return {'action': data.toString(), 'params': '无'};
  }

// 辅助方法2：简略显示 params（限制长度，格式化输出）
  String _simplifyParams(dynamic params) {
    if (params == null || params == '无参数' || params == '无') {
      return '无';
    }

    // 转为字符串（如果是 Map/List，先格式化）
    String paramsStr;
    if (params is Map || params is List) {
      paramsStr = JsonEncoder.withIndent('').convert(params); // 无缩进紧凑显示
    } else {
      paramsStr = params.toString();
    }

    // 限制长度为 30 字符，超出部分省略

    return paramsStr.length > 30
        ? '${paramsStr.substring(0, 30)}...'
        : paramsStr;
  }
}

// 格式化JSON数据显示
String _formatJson(dynamic data) {
  try {
    if (data is String) {
      // 如果是 JSON 字符串，先解析再格式化
      final parsed = json.decode(data);
      return JsonEncoder.withIndent('  ').convert(parsed);
    }
    return JsonEncoder.withIndent('  ').convert(data);
  } catch (e) {
    return data.toString();
  }
}

// 截断过长的客户端ID
String _truncateClientId(String clientId) {
  if (clientId.length > 15) {
    return '${clientId.substring(0, 12)}...';
  }
  return clientId;
}

// 生成设备连接摘要
String _getDeviceSummary(Map<String, String> devices) {
  final counts = <String, int>{};
  for (final device in devices.values) {
    counts[device] = (counts[device] ?? 0) + 1;
  }
  return counts.entries.map((e) => '${e.key} ${e.value}台').join('，');
}

// 格式化Duration为可读字符串
String _formatDuration(Duration? duration) {
  if (duration == null) return '00:00:00.0';

  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
  String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
  String threeDigitMilliseconds =
      (duration.inMilliseconds.remainder(1000) ~/ 100).toString();

  return "${twoDigits(duration.inHours)}:${twoDigitMinutes}:${twoDigitSeconds}.${threeDigitMilliseconds}";
}
