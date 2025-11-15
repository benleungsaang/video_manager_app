import 'package:flutter/material.dart';
import 'package:video_manager_app/utils/file_utils.dart';
import '../pages/video_play_page.dart';

class UploadButton extends StatelessWidget {
  const UploadButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.upload),
      label: const Text('添加视频'),
      onPressed: () async {
        // 选择视频后直接跳转到播放页
        final result = await FileUtils.pickVideo();
        if (result != null && result.files.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayPage(
                filePath: result.files.single.path,
              ),
            ),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
