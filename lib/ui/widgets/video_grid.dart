import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_manager_app/models/tag.dart';
import '../../models/video.dart';
// import '../../utils/file_utils.dart';
import '../pages/video_play_page.dart';
import '../../providers/tag_provider.dart';

class VideoGrid extends StatelessWidget {
  final List<Video> videos;

  const VideoGrid({super.key, required this.videos});

  @override
  Widget build(BuildContext context) {
    // 平板端使用2列网格
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2列布局
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8, // 宽高比
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return _buildVideoCard(context, video);
      },
    );
  }

  // 构建视频卡片
  Widget _buildVideoCard(BuildContext context, Video video) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayPage(videoId: video.id),
          ),
        );
      },
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                  image: video.thumbnailPath != null
                      ? DecorationImage(
                          image: FileImage(File(video.thumbnailPath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: video.thumbnailPath == null
                    ? const Center(
                        child: Icon(Icons.video_library,
                            size: 48, color: Colors.grey))
                    : null,
              ),
            ),

            // 视频信息
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 4),

                  // 标签
                  _buildTagsDisplay(video.tagIds),

                  const SizedBox(height: 4),

                  // 上传时间
                  Text(
                    _formatDateTime(video.uploadTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),

                  // 备注预览
                  if (video.remark.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        video.remark.length > 20
                            ? '${video.remark.substring(0, 20)}...'
                            : video.remark,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建标签显示
  Widget _buildTagsDisplay(List<String> tagIds) {
    // 这里简化处理，实际应通过TagProvider获取标签名称
    return Consumer<TagProvider>(
      builder: (context, tagProvider, child) {
        final tags = tagIds
            .map((id) => tagProvider.getTagById(id))
            .where((tag) => tag != null)
            .cast<Tag>()
            .toList();

        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            ...tags.take(3).map((tag) => Chip(
                  label: Text(
                    tag.name,
                    style: const TextStyle(
                      fontSize: 10,
                      height: 1.2,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )),
            if (tags.length > 3)
              Chip(
                label: Text(
                  '+${tags.length - 3}',
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                backgroundColor: Colors.grey[200],
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        );
      },
    );
  }

  // 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
