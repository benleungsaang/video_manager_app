import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as p;

class VideoInitializationDialog extends StatefulWidget {
  final List<String> unregisteredVideos;
  final Function(List<String>) onConfirm;
  final Function onCancel;

  const VideoInitializationDialog({
    Key? key,
    required this.unregisteredVideos,
    required this.onConfirm,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<VideoInitializationDialog> createState() => _VideoInitializationDialogState();
}

class _VideoInitializationDialogState extends State<VideoInitializationDialog> {
  late List<bool> _selectedVideos;

  @override
  void initState() {
    super.initState();
    // 默认全部选中
    _selectedVideos = List.generate(widget.unregisteredVideos.length, (index) => true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('视频初始化'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            const Text(
              '检测到以下未登记的视频文件，选择要添加到系统的视频：',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: widget.unregisteredVideos.length,
                itemBuilder: (context, index) {
                  final videoPath = widget.unregisteredVideos[index];
                  final fileName = p.basename(videoPath);
                  final fileSize = _getFileSize(videoPath);
                  
                  return CheckboxListTile(
                    title: Text(fileName),
                    subtitle: Text('路径: $videoPath\n大小: $fileSize'),
                    value: _selectedVideos[index],
                    onChanged: (bool? value) {
                      setState(() {
                        _selectedVideos[index] = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.onCancel();
            Navigator.of(context).pop();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            // 获取选中的视频路径
            final selectedPaths = <String>[];
            for (int i = 0; i < widget.unregisteredVideos.length; i++) {
              if (_selectedVideos[i]) {
                selectedPaths.add(widget.unregisteredVideos[i]);
              }
            }
            widget.onConfirm(selectedPaths);
            Navigator.of(context).pop();
          },
          child: const Text('确认'),
        ),
      ],
    );
  }

  String _getFileSize(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        final size = file.lengthSync();
        return _formatFileSize(size);
      }
    } catch (e) {
      print('获取文件大小失败: $e');
    }
    return '未知';
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int i = (bytes == 0 ? 0 : (bytes ~/ 1024).floor()).clamp(0, suffixes.length - 1);
    double size = bytes / math.pow(1024, i).toDouble();
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  // double pow(double base, int exponent) {
  //   return math.pow(base, exponent).toDouble();
  // }
}
