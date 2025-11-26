import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_manager_app/models/tag.dart';
import 'package:video_manager_app/utils/file_utils.dart';
import '../../models/video.dart';
// import '../../utils/file_utils.dart';
import '../pages/video_play_page.dart';
import '../../providers/tag_provider.dart';
import '../../providers/video_provider.dart';

class VideoGrid extends StatefulWidget {
  final List<Video> videos;
  final bool isMultiSelectMode;
  final Set<String> selectedVideos;
  final Function(String) onVideoSelected;

  const VideoGrid({
    super.key,
    required this.videos,
    this.isMultiSelectMode = false,
    required this.selectedVideos,
    required this.onVideoSelected,
  });

  @override
  State<VideoGrid> createState() => _VideoGridState();
}

class _VideoGridState extends State<VideoGrid> {
  late ScrollController _scrollController;
  int _loadMoreThreshold = 15; // 当距离底部多少个item时开始加载更多

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 根据屏幕宽度决定列数
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = screenWidth > 800 ? 3 : 2; // 大屏幕3列，小屏幕2列

    return Padding(
      // 视频卡片与屏外之间的间距
      padding: const EdgeInsets.all(16), // 添加边距
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 计算每个item的宽度，用于确定每行显示多少个
          double itemWidth =
              (constraints.maxWidth - ((crossAxisCount - 1) * 16)) /
                  crossAxisCount;
          double itemHeight = itemWidth * .91; // 使用相同宽高比

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: itemWidth / itemHeight, // 宽高比
                ),
                delegate: SliverChildBuilderDelegate(
                  childCount: widget.videos.length,
                  addAutomaticKeepAlives: false, // 优化性能
                  addRepaintBoundaries: false, // 优化性能
                  addSemanticIndexes: false, // 优化性能
                  (context, index) {
                    final video = widget.videos[index];
                    return _buildVideoCard(context, video);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // 构建视频卡片
  Widget _buildVideoCard(BuildContext context, Video video) {
    bool isSelected = widget.selectedVideos.contains(video.id);

    return GestureDetector(
      onTap: () {
        if (widget.isMultiSelectMode) {
          widget.onVideoSelected(video.id);
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPlayPage(videoId: video.id),
            ),
          );
        }
      },

      // 重要：让 GestureDetector 只响应非删除按钮区域的点击
      behavior: HitTestBehavior.translucent,
      child: Container(
        decoration: BoxDecoration(
          border:
              isSelected ? Border.all(color: Colors.blue, width: 3.0) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          fit: StackFit.expand, // Stack 占满整个卡片
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              margin: EdgeInsets.zero, // 移除卡片默认边距，定位更精准
              child: Stack(
                fit: StackFit.expand, // Stack 占满整个卡片
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8)),
                            image: video.thumbnailPath != null
                                ? DecorationImage(
                                    image:
                                        FileImage(File(video.thumbnailPath!)),
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
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                                mainAxisAlignment: MainAxisAlignment
                                    .spaceBetween, // 水平方向两端对齐（一左一右）
                                crossAxisAlignment: CrossAxisAlignment
                                    .center, // 垂直方向居中对齐（避免两个元素高低不一）
                                children: [
                                  // 标题
                                  Text(
                                    video.title.length > 10
                                        ? '${video.title.substring(0, 10)}...'
                                        : video.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),

                                  // 上传时间
                                  Text(
                                    _formatDateTime(video.uploadTime),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ]),
                            const SizedBox(height: 4),
                            Row(
                                mainAxisAlignment: MainAxisAlignment
                                    .spaceBetween, // 水平方向两端对齐（一左一右）
                                crossAxisAlignment: CrossAxisAlignment
                                    .center, // 垂直方向居中对齐（避免两个元素高低不一）
                                children: [
                                  Text(
                                    // 原始文件名
                                    video.filePath.split('/').last.length > 30
                                        ? '${video.filePath.split('/').last.substring(0, 30)} . . .'
                                        : video.filePath.split('/').last,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    // video.fileSize as String,
                                    '文件大小: ${FileUtils.formatFileSize(video.fileSize)}',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ]),
                            // const SizedBox(height: 2),
                            Row(
                                mainAxisAlignment: MainAxisAlignment
                                    .spaceBetween, // 水平方向两端对齐（一左一右）
                                crossAxisAlignment: CrossAxisAlignment
                                    .center, // 垂直方向居中对齐（避免两个元素高低不一）
                                children: [
                                  Text(''),

                                  // 备注预览
                                  if (video.remark.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        video.remark.length > 15
                                            ? '备注：${video.remark.substring(0, 15)}...'
                                            : '备注：${video.remark}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    )
                                  else
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '备注：暂无',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                ]),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment
                                  .spaceBetween, // 水平方向两端对齐（一左一右）
                              crossAxisAlignment: CrossAxisAlignment
                                  .center, // 垂直方向居中对齐（避免两个元素高低不一）
                              children: [
                                Text(''),
                                // 标签
                                if (video.tagIds.isNotEmpty)
                                  _buildTagsDisplay(video.tagIds)
                                else
                                  Chip(
                                    label: Text(
                                      '未有标签',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        height: 1.2,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 2),
                                    backgroundColor: Colors.grey[300],
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                  // 右上角删除菜单按钮
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Center(
                              child: Icon(Icons.delete_forever,
                                  size: 48, color: Colors.redAccent)),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'delete') {
                          _confirmDelete(context, video.id);
                        }
                      },
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            // 选择指示器
            if (widget.isMultiSelectMode)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String videoId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个视频吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final videoProvider =
                  Provider.of<VideoProvider>(context, listen: false);
              await videoProvider.deleteVideo(videoId);
              if (mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
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
