import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_manager_app/main.dart';
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
    // 1. 从客户端详情中获取备注名
    final clientDetail = serverService.clientDetails[clientId];
    final remark = clientDetail?.remark;

    // 2. 有备注则显示“备注名(缩写ID)”，无备注则显示缩写ID
    if (remark != null && remark.isNotEmpty) {
      return '$remark(${_truncateClientId(clientId)})';
    } else {
      return _truncateClientId(clientId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器控制'),
        backgroundColor: Colors.blue[800],
        // 避免AppBar被遮挡（可选）
        centerTitle: true,
      ),
      // 关键：外层添加SingleChildScrollView，支持整个页面滚动
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), // 回弹滚动效果
        child: Consumer<ServerService>(
          builder: (context, serverService, child) {
            _portController.text = serverService.port.toString();

            // 初始化新客户端的备注控制器
            for (var clientId in serverService.clientDetails.keys) {
              if (!_clientRemarkControllers.containsKey(clientId)) {
                _clientRemarkControllers[clientId] = TextEditingController(
                  text: serverService.clientDetails[clientId]?.remark,
                );
              }
            }

            // 容器添加最大宽度约束，避免超宽
            return ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    AppBar().preferredSize.height -
                    MediaQuery.of(context).padding.top,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 服务器开关按钮（固定宽度，避免拉伸）
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
                              await serverService.startServer(customPort: port);
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
                              horizontal: 32, vertical: 16),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child:
                            Text(serverService.isRunning ? '停止服务器' : '启动服务器'),
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
                                const SnackBar(content: Text('Web资源缓存已清除')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('清除Web资源缓存'),
                        ),
                      ),

                    const SizedBox(height: 20),

                    // 连接信息（换行显示，避免水平溢出）
                    if (serverService.isRunning &&
                        serverService.localIp != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('连接信息:',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          // 用SelectableText方便复制，同时自动换行
                          SelectableText(
                            '内网地址: http://${serverService.localIp}:${serverService.port}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),

                    const SizedBox(height: 20),

                    // 端口设置
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('端口设置:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: '输入端口(1024-65535)',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          enabled: !serverService.isRunning,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 客户端列表（优化卡片布局，避免溢出）
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('客户端列表 (${serverService.clientDetails.length}):',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (serverService.isRunning &&
                            serverService.clientDetails.isNotEmpty)
                          Column(
                            children: serverService.clientDetails.entries
                                .map((entry) {
                              final clientId = entry.key;
                              final details = entry.value;
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  // 用Column替换Row，避免水平溢出
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // 客户端基础信息（换行显示）
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 6,
                                        children: [
                                          Text(
                                              'ID: ${_truncateClientId(clientId)}',
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                          Text('设备: ${details.deviceType}',
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                          Text('连接时间: ${details.connectedAt}',
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // 备注输入框+按钮（横向布局，限制宽度）
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _getRemarkController(
                                                  clientId, details.remark),
                                              decoration: const InputDecoration(
                                                labelText: '备注名称',
                                                labelStyle:
                                                    TextStyle(fontSize: 13),
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 12),
                                                isDense: true, // 紧凑模式
                                              ),
                                              style:
                                                  const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // 保存按钮
                                          IconButton(
                                            icon: const Icon(Icons.save,
                                                size: 20),
                                            onPressed: () {
                                              final remark =
                                                  _getRemarkController(clientId,
                                                          details.remark)
                                                      .text;
                                              serverService.setClientRemark(
                                                  clientId, remark);
                                            },
                                            tooltip: '保存备注',
                                          ),
                                          // 断开按钮
                                          IconButton(
                                            icon: const Icon(Icons.close,
                                                color: Colors.red, size: 20),
                                            onPressed: () {
                                              serverService
                                                  .disconnectClient(clientId);
                                            },
                                            tooltip: '断开连接',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          )
                        else if (serverService.isRunning)
                          const Text('暂无客户端连接', style: TextStyle(fontSize: 14))
                        else
                          const Text('服务器未运行', style: TextStyle(fontSize: 14)),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 消息日志（固定高度+内部滚动）
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('消息日志:',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        // 限制容器高度，内部独立滚动
                        Container(
                          height: 200, // 固定高度，避免占满屏幕
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[50],
                          ),
                          child: SingleChildScrollView(
                            reverse: true, // 新消息在底部
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: serverService.messageLogs
                                    .map((log) =>
                                        _buildLogItem(log, serverService))
                                    .toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // 底部留白，避免最后一个组件被遮挡
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 构建格式化的日志条目
  Widget _buildLogItem(MessageLog log, ServerService serverService) {
    Color color;
    switch (log.type) {
      case 'command':
        color = Colors.blue;
        break;
      case 'error':
        color = Colors.red;
        break;
      case 'connection':
        color = Colors.green;
        break;
      default:
        color = Colors.black87;
    }
    // 关键：获取客户端显示名称（备注名优先）
    final clientDisplayName =
        _getClientDisplayName(log.clientId, serverService);

    // 解析 JSON 中的 action 和 params（核心简化逻辑）
    final Map<String, dynamic> parsedData = _parseLogData(log.data);
    final String action = parsedData['action'] ?? '未知操作';
    final dynamic params = parsedData['params'] ?? '无参数';
    final String simplifiedParams = _simplifyParams(params);

    // 日志展开/收起状态管理
    final ValueNotifier<bool> isExpanded = ValueNotifier(false);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 简化日志行（时间 + 备注名 + action + 简略params）
          InkWell(
            onTap: () => isExpanded.value = !isExpanded.value,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '[${log.timestamp}] 【$clientDisplayName】 $action | 参数: $simplifiedParams',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    softWrap: true,
                  ),
                ),
                // 展开/收起图标
                ValueListenableBuilder<bool>(
                  valueListenable: isExpanded,
                  builder: (context, expanded, child) {
                    return Icon(
                      expanded
                          ? (Icons.keyboard_double_arrow_up)
                          : (Icons.keyboard_double_arrow_down),
                      size: 16,
                      color: Colors.grey[500],
                    );
                  },
                ),
              ],
            ),
          ),
          // 可选：展开显示完整 JSON（默认隐藏）
          ValueListenableBuilder<bool>(
            valueListenable: isExpanded,
            builder: (context, expanded, child) {
              if (!expanded) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    _formatJson(log.data),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                    softWrap: true,
                  ),
                ),
              );
            },
          ),
        ],
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

    // 限制长度为 50 字符，超出部分省略
    return paramsStr.length > 50
        ? '${paramsStr.substring(0, 50)}...'
        : paramsStr;
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
}
