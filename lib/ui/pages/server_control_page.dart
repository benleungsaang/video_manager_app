import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/server_service.dart';

class ServerControlPage extends StatefulWidget {
  const ServerControlPage({super.key});

  @override
  State<ServerControlPage> createState() => _ServerControlPageState();
}

class _ServerControlPageState extends State<ServerControlPage> {
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服务器控制'),
      ),
      body: Consumer<ServerService>(
        builder: (context, serverService, child) {
          _portController.text = serverService.port.toString();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 服务器开关按钮
                ElevatedButton(
                  onPressed: () async {
                    if (serverService.isRunning) {
                      await serverService.stopServer();
                    } else {
                      try {
                        final port = int.parse(_portController.text);
                        await serverService.startServer(customPort: port);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        serverService.isRunning ? Colors.red : Colors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                  child: Text(serverService.isRunning ? '停止服务器' : '启动服务器'),
                ),

                const SizedBox(height: 24),

                // 清除Web资源缓存按钮
                if (!serverService.isRunning) // 服务器停止时才允许清除
                  ElevatedButton(
                    onPressed: () async {
                      await serverService.clearWebCache();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Web资源缓存已清除')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    child: const Text('清除Web资源缓存'),
                  ),

                const SizedBox(height: 24),

                // 连接信息
                if (serverService.isRunning && serverService.localIp != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('连接信息:',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                          '内网地址: http://${serverService.localIp}:${serverService.port}'),
                    ],
                  ),

                const SizedBox(height: 24),

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
                      ),
                      enabled: !serverService.isRunning,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 连接监控
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('连接监控:',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (serverService.isRunning)
                      Text('${serverService.connectionCount} 台设备连接: '
                          '${_getDeviceSummary(serverService.clientDevices)}'),
                    if (!serverService.isRunning) const Text('服务器未运行'),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
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
