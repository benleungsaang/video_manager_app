import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_manager_app/providers/transcode_provider.dart';
import 'package:video_manager_app/models/transcode_task.dart';
import 'package:video_manager_app/providers/video_provider.dart';

class TranscodeQueuePanel extends StatelessWidget {
  final VoidCallback? onHide; // 隐藏面板的回调函数

  const TranscodeQueuePanel({super.key, this.onHide});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: Provider.of<TranscodeProvider>(context),
        ),
        ChangeNotifierProvider.value(
          value: Provider.of<VideoProvider>(context),
        ),
      ],
      child: Consumer2<TranscodeProvider, VideoProvider>(
        builder: (context, transcodeProvider, videoProvider, child) {
          return Container(
            width: 400, // 固定宽度以显示在屏幕右侧
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                left: BorderSide(color: Colors.grey.shade300, width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 0,
                  offset: const Offset(-3, 0), // 阴影在左侧
                ),
              ],
            ),
            child: Column(
              children: [
                // 面板标题和控制按钮
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '转码任务队列',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          // 添加任务
                          IconButton(
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                            ),
                            onPressed: () async {
                              // 从VideoProvider获取所有视频并显示选择弹窗
                              await showVideoSelectionDialog(
                                  context, videoProvider, transcodeProvider);
                            },
                            tooltip: '添加任务',
                          ),
                          // 开始任务
                          IconButton(
                            icon: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              // 启动转码队列
                              transcodeProvider.startTranscodingQueue(
                                  videoProvider: videoProvider);
                            },
                            tooltip: '开始转码队列',
                          ),
                          // 终止全部任务
                          IconButton(
                            icon: const Icon(
                              Icons.stop,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              transcodeProvider.cancelAllTasks(); // 终止全部任务
                            },
                            tooltip: '终止全部任务',
                          ),
                          // 清空已完成任务
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              transcodeProvider
                                  .clearCompletedTasks(); // 清空已完成任务
                            },
                            tooltip: '清空已完成任务',
                          ),
                          // 清空所有非活动任务（已完成、已失败、已取消）
                          IconButton(
                            icon: const Icon(
                              Icons.clear_all,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              transcodeProvider
                                  .clearNonActiveTasks(); // 清空所有非活动任务
                            },
                            tooltip: '清空所有非活动任务',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 任务列表或空状态提示
                Expanded(
                  child: transcodeProvider.tasks.isEmpty
                      ? const Center(
                          child: Text(
                            '暂无转码任务',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: transcodeProvider.tasks.length,
                          itemBuilder: (context, index) {
                            final task = transcodeProvider.tasks[index];
                            return _buildTaskItem(task);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskItem(TranscodeTask task) {
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.hourglass_empty;

    String formattedDuration = task.durationInMinutes.toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Consumer2<TranscodeProvider, VideoProvider>(
          builder: (context, transcodeProvider, videoProvider, child) {
            List<Widget> actionButtons = [];

            switch (task.status) {
              case TranscodeStatus.pending:
                statusColor = Colors.grey;
                statusIcon = Icons.hourglass_empty;
                // 为待处理任务添加清空按钮
                actionButtons.add(
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                    onPressed: () {
                      transcodeProvider
                          .clearTasksByStatus({TranscodeStatus.pending});
                    },
                    tooltip: '清空任务',
                  ),
                );
                break;
              case TranscodeStatus.running:
                statusColor = Colors.blue;
                statusIcon = Icons.hourglass_bottom;
                // 为运行中任务添加停止按钮
                actionButtons.add(
                  IconButton(
                    icon:
                        const Icon(Icons.stop, color: Colors.orange, size: 18),
                    onPressed: () {
                      // 将正在运行的任务标记为已取消
                      transcodeProvider.updateTask(task.id,
                          status: TranscodeStatus.cancelled);
                    },
                    tooltip: '停止任务',
                  ),
                );
                break;
              case TranscodeStatus.completed:
                statusColor = Colors.green;
                statusIcon = Icons.check_circle;
                // 为已完成任务添加重新开始和清空按钮
                actionButtons.addAll([
                  IconButton(
                    icon:
                        const Icon(Icons.replay, color: Colors.blue, size: 18),
                    onPressed: () async {
                      await transcodeProvider.restartTask(task.id,
                          videoProvider: videoProvider);
                    },
                    tooltip: '重新开始',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                    onPressed: () {
                      transcodeProvider
                          .clearTasksByStatus({TranscodeStatus.completed});
                    },
                    tooltip: '清空任务',
                  ),
                ]);
                break;
              case TranscodeStatus.failed:
                statusColor = Colors.red;
                statusIcon = Icons.error;
                // 为失败任务添加重新开始和清空按钮
                actionButtons.addAll([
                  IconButton(
                    icon:
                        const Icon(Icons.replay, color: Colors.blue, size: 18),
                    onPressed: () async {
                      await transcodeProvider.restartTask(task.id,
                          videoProvider: videoProvider);
                    },
                    tooltip: '重新开始',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                    onPressed: () {
                      transcodeProvider
                          .clearTasksByStatus({TranscodeStatus.failed});
                    },
                    tooltip: '清空任务',
                  ),
                ]);
                break;
              case TranscodeStatus.cancelled:
                statusColor = Colors.orange;
                statusIcon = Icons.cancel;
                // 为已取消任务添加重新开始和清空按钮
                actionButtons.addAll([
                  IconButton(
                    icon:
                        const Icon(Icons.replay, color: Colors.blue, size: 18),
                    onPressed: () async {
                      await transcodeProvider.restartTask(task.id,
                          videoProvider: videoProvider);
                    },
                    tooltip: '重新开始',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                    onPressed: () {
                      transcodeProvider
                          .clearTasksByStatus({TranscodeStatus.cancelled});
                    },
                    tooltip: '清空任务',
                  ),
                ]);
                break;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 任务标题和状态
                Row(
                  children: [
                    Icon(statusIcon, color: statusColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.videoTitle.length > 20
                            ? '${task.videoTitle.substring(0, 20)}...'
                            : task.videoTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    // 根据任务状态显示操作按钮
                    if (actionButtons.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: actionButtons,
                      ),
                    // 当任务正在运行时显示转动图标
                    if (task.status == TranscodeStatus.running)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 4),

                // 文件大小信息
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '原大小: ${formatFileSize(task.inputFileSize)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    if (task.outputFileSize != null)
                      Text(
                        '转码后: ${formatFileSize(task.outputFileSize!)}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                  ],
                ),

                // 转码用时
                Text(
                  '用时: ${formattedDuration}分钟',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),

                // 错误信息
                if (task.status == TranscodeStatus.failed &&
                    task.errorMessage != null)
                  Text(
                    '错误: ${task.errorMessage}',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // 显示视频选择对话框
  static Future<void> showVideoSelectionDialog(BuildContext context,
      VideoProvider videoProvider, TranscodeProvider transcodeProvider) async {
    final allVideos = videoProvider.videos;
    final selectedVideoIds = <String>{};

    // 获取当前任务列表中已存在的视频ID，避免重复添加
    final existingTaskVideoIds =
        transcodeProvider.tasks.map((task) => task.videoId).toSet();

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext builderContext, StateSetter setState) {
            return AlertDialog(
              title: const Text('选择视频添加到转码队列'),
              content: SizedBox(
                width: 500,
                height: 400,
                child: ListView.builder(
                  itemCount: allVideos.length,
                  itemBuilder: (BuildContext itemBuilderContext, int index) {
                    final video = allVideos[index];
                    final isAlreadyInQueue =
                        existingTaskVideoIds.contains(video.id);
                    final isSelected = selectedVideoIds.contains(video.id);

                    return CheckboxListTile(
                      title: Text(video.title.length > 30
                          ? '${video.title.substring(0, 30)}...'
                          : video.title),
                      subtitle:
                          Text('文件大小: ${formatFileSize(video.fileSize)}'),
                      value: isSelected,
                      onChanged: isAlreadyInQueue
                          ? null // 如果已经在队列中，则禁用选择
                          : (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedVideoIds.add(video.id);
                                } else {
                                  selectedVideoIds.remove(video.id);
                                }
                              });
                            },
                      secondary: isAlreadyInQueue
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: selectedVideoIds.isEmpty
                      ? null
                      : () {
                          // 创建选中视频的转码任务
                          final selectedVideos = allVideos
                              .where((video) =>
                                  selectedVideoIds.contains(video.id))
                              .toList();

                          final tasks = <TranscodeTask>[];
                          for (final video in selectedVideos) {
                            tasks.add(TranscodeTask(
                              id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString() +
                                  video.id, // 创建唯一ID
                              videoId: video.id,
                              videoTitle: video.title,
                              inputFilePath: video.filePath,
                              inputFileSize: video.fileSize,
                              startTime: DateTime.now(),
                            ));
                          }

                          // 添加任务到队列
                          if (tasks.isNotEmpty) {
                            transcodeProvider.addTasks(tasks);
                          }

                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('添加'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
