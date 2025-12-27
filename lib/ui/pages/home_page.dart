import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:path_provider/path_provider.dart' as path_provider;
import '../../models/video.dart';

import 'package:provider/provider.dart';

import 'package:file_picker/file_picker.dart';

import 'package:video_manager_app/ui/pages/server_control_page.dart';
import 'package:video_manager_app/ui/pages/price_calculator_page.dart';

import 'package:video_manager_app/utils/file_utils.dart';

import '../widgets/video_grid.dart';

import '../widgets/upload_button.dart';

import 'video_play_page.dart';

import '../pages/tag_management_page.dart';

import '../../providers/video_provider.dart';

import '../../models/transcode_task.dart';
import '../../providers/transcode_provider.dart';
import '../widgets/transcode_queue_panel.dart';
import '../widgets/file_replace_dialog.dart';
import '../widgets/video_initialization_dialog.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../utils/storage_utils.dart';
import '../../utils/file_utils.dart';

class HomePage extends StatefulWidget {
  final String? initialSearchKeyword; // 添加初始搜索关键字参数

  const HomePage({super.key, this.initialSearchKeyword});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late TextEditingController _searchController;
  bool _isMultiSelectMode = false;
  Set<String> _selectedVideos = <String>{};

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.initialSearchKeyword); // 设置初始搜索关键字

    // 如果有初始搜索关键字，则自动执行搜索
    if (widget.initialSearchKeyword != null &&
        widget.initialSearchKeyword!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSearch();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    // 在页面销毁时取消所有转码任务
    final transcodeProvider =
        Provider.of<TranscodeProvider>(context, listen: false);
    transcodeProvider.cancelAllTasks();
    super.dispose();
  }

  // 处理搜索
  void _handleSearch() {
    final keyword = _searchController.text.trim();
    Provider.of<VideoProvider>(context, listen: false).searchVideos(keyword);
  }

  // 切换多选模式
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedVideos.clear();
      }
    });
  }

  // 选择单个视频
  void _toggleVideoSelection(String videoId) {
    setState(() {
      if (_selectedVideos.contains(videoId)) {
        _selectedVideos.remove(videoId);
      } else {
        _selectedVideos.add(videoId);
      }
    });
  }

  // 全选/反选
  void _toggleSelectAll() {
    Provider.of<VideoProvider>(context, listen: false).videos.forEach((video) {
      if (_selectedVideos.contains(video.id)) {
        _selectedVideos.remove(video.id);
      } else {
        _selectedVideos.add(video.id);
      }
    });
    setState(() {});
  }

  // 批量删除
  void _deleteSelectedVideos() async {
    if (_selectedVideos.isEmpty) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${_selectedVideos.length} 个视频吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      for (String videoId in _selectedVideos) {
        await videoProvider.deleteVideo(videoId);
      }
      setState(() {
        _selectedVideos.clear();
        _isMultiSelectMode = false;
      });
    }
  }

  bool _showTranscodeQueue = false; // 控制转码队列面板显示状态

  // 显示/隐藏转码队列，并添加选中视频到队列
  void _transcodeSelectedVideos() async {
    final transcodeProvider =
        Provider.of<TranscodeProvider>(context, listen: false);

    // 如果当前显示转码队列，则隐藏它
    if (_showTranscodeQueue) {
      setState(() {
        _showTranscodeQueue = false;
      });
      return;
    } else {
      // 否则显示转码队列，并添加新选中的视频到队列（避免重复）
      setState(() {
        _showTranscodeQueue = true;
      });

      if (_selectedVideos.isEmpty) return;

      // 获取选中的视频
      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      final selectedVideoObjects = videoProvider.videos
          .where((video) => _selectedVideos.contains(video.id))
          .toList();

      // 检查哪些视频ID还没有在任务列表中
      final existingTaskVideoIds =
          transcodeProvider.tasks.map((task) => task.videoId).toSet();
      final newVideosToTranscode = selectedVideoObjects
          .where((video) => !existingTaskVideoIds.contains(video.id))
          .toList();

      // 为新视频创建转码任务
      final tasks = <TranscodeTask>[];
      for (final video in newVideosToTranscode) {
        tasks.add(TranscodeTask(
          id: DateTime.now().millisecondsSinceEpoch.toString() +
              video.id, // 创建唯一ID
          videoId: video.id,
          videoTitle: video.title,
          inputFilePath: video.filePath,
          inputFileSize: video.fileSize,
          startTime: DateTime.now(),
        ));
      }

      // 添加新任务到队列
      if (tasks.isNotEmpty) {
        transcodeProvider.addTasks(tasks);
      }
    }
  }

  // 显示按文件路径筛选对话框
  void _showFilePathFilterDialog() async {
    final TextEditingController controller =
        TextEditingController(text: 'unTransCode');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('按文件路径筛选'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入要搜索的关键字',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('筛选'),
          ),
        ],
      ),
    );

    if (result != null) {
      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      videoProvider.filterVideosByFilePath(result);
    }
  }

  // 显示文件替换对话框
  void _showFileReplaceDialog() async {
    // 扫描当前目录中的unTransCode和Soonwin文件
    String currentDirPath = '';
    try {
      // 获取当前视频文件路径的目录
      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      if (videoProvider.videos.isNotEmpty) {
        String firstVideoPath = videoProvider.videos.first.filePath;
        currentDirPath =
            firstVideoPath.substring(0, firstVideoPath.lastIndexOf('/'));
      }
    } catch (e) {
      print('获取当前目录失败: $e');
    }

    if (currentDirPath.isEmpty) {
      // 如果无法从视频中获取目录，则使用应用文档目录
      try {
        final directory =
            await path_provider.getApplicationDocumentsDirectory();
        currentDirPath = directory.path;
      } catch (e) {
        print('获取应用文档目录失败: $e');
        return;
      }
    }

    // 扫描文件
    final unTransCodeFiles = <String>[];
    final soonwinFiles = <String>[];

    try {
      final dir = Directory(currentDirPath);
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is File) {
            String fileName = p.basename(entity.path);
            if (fileName.startsWith('unTransCode_')) {
              unTransCodeFiles.add(entity.path);
            } else if (fileName.startsWith('Soonwin_')) {
              soonwinFiles.add(entity.path);
            }
          }
        }
      }
    } catch (e) {
      print('扫描目录失败: $e');
    }

    // 配对文件
    final filePairs = <Map<String, String>>[];
    for (final unTransCodeFile in unTransCodeFiles) {
      String unTransCodeFileName = p.basename(unTransCodeFile);
      String baseName =
          unTransCodeFileName.substring('unTransCode_'.length); // 获取基础名称

      // 寻找对应的Soonwin文件
      String targetSoonwinFileName = 'Soonwin_$baseName';
      String? soonwinFile = soonwinFiles.firstWhere(
        (file) => p.basename(file) == targetSoonwinFileName,
        orElse: () => '',
      );

      if (soonwinFile.isNotEmpty) {
        filePairs.add({
          'unTransCode': unTransCodeFile,
          'Soonwin': soonwinFile,
        });
      }
    }

    // 显示对话框
    if (filePairs.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => FileReplaceDialog(
          filePairs: filePairs,
          onReplace: (selectedPairs) => _performFileReplacement(selectedPairs),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('未找到匹配的 unTransCode_ 和 Soonwin_ 文件对'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  // 执行文件替换
  Future<void> _performFileReplacement(
      List<Map<String, String>> selectedPairs) async {
    final videoProvider = Provider.of<VideoProvider>(context, listen: false);
    List<String> errors = [];

    for (final pair in selectedPairs) {
      String unTransCodeFile = pair['unTransCode']!;
      String soonwinFile = pair['Soonwin']!;
      String unTransCodeFileName = p.basename(unTransCodeFile);
      String baseName = unTransCodeFileName.substring('unTransCode_'.length);

      try {
        // 找到对应的视频对象
        Video? targetVideo;
        for (final video in videoProvider.videos) {
          String videoFileName = p.basename(video.filePath);
          if (videoFileName == unTransCodeFileName) {
            targetVideo = video;
            break;
          }
        }

        if (targetVideo != null) {
          // 更新视频对象的filePath
          Video updatedVideo = Video(
            id: targetVideo.id,
            title: targetVideo.title,
            filePath: soonwinFile,
            fileSize: targetVideo.fileSize,
            tagIds: targetVideo.tagIds,
            remark: targetVideo.remark,
            transcode: targetVideo.transcode,
            uploadTime: targetVideo.uploadTime,
            duration: targetVideo.duration,
            thumbnailPath: targetVideo.thumbnailPath,
          );

          await videoProvider.saveVideo(updatedVideo);

          // 删除原unTransCode文件
          File(unTransCodeFile).delete();
        } else {
          errors.add('未找到视频对象对应: $unTransCodeFileName');
        }
      } catch (e) {
        errors.add('处理文件对 $baseName 时出错: $e');
      }
    }

    // 显示结果
    String resultMessage = '文件替换完成！';
    if (errors.isNotEmpty) {
      resultMessage += '\n\n错误:\n${errors.join('\n')}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('替换结果'),
        content: Text(resultMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 扫描未登记的视频文件
  Future<List<String>> _scanUnregisteredVideos() async {
    try {
      // 获取视频存储目录
      final videoDir = StorageUtils.getVideosDirectory();
      final videoDirPath = Directory(videoDir).path;

      // 获取当前已登记的视频文件路径
      final videoProvider = Provider.of<VideoProvider>(context, listen: false);
      final registeredVideoPaths =
          videoProvider.videos.map((video) => video.filePath).toSet();

      // 扫描视频目录中的所有视频文件
      final dir = Directory(videoDirPath);
      if (!await dir.exists()) {
        return [];
      }

      final List<String> unregisteredVideos = [];
      final extensions = [
        '.mp4',
        '.avi',
        '.mov',
        '.wmv',
        '.flv',
        '.mkv',
        '.webm',
        '.m4v',
        '.3gp',
        '.mpg',
        '.mpeg'
      ];

      await for (final entity in dir.list()) {
        if (entity is File) {
          final fileName = p.basename(entity.path).toLowerCase();
          final extension = p.extension(fileName);

          // 检查是否为视频文件且未被登记
          if (extensions.contains(extension) &&
              !registeredVideoPaths.contains(entity.path)) {
            unregisteredVideos.add(entity.path);
          }
        }
      }

      return unregisteredVideos;
    } catch (e) {
      print('扫描未登记视频文件失败: $e');
      return [];
    }
  }

  // 初始化视频文件
  Future<void> _initializeVideos() async {
    final unregisteredVideos = await _scanUnregisteredVideos();

    if (unregisteredVideos.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('提示'),
          content: const Text('未找到未登记的视频文件'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    // 显示选择对话框
    showDialog(
      context: context,
      builder: (context) => VideoInitializationDialog(
        unregisteredVideos: unregisteredVideos,
        onConfirm: (selectedPaths) => _createVideoObjects(selectedPaths),
        onCancel: () {},
      ),
    );
  }

  // 创建视频对象并保存
  Future<void> _createVideoObjects(List<String> selectedPaths) async {
    final videoProvider = Provider.of<VideoProvider>(context, listen: false);
    List<String> errors = [];

    for (final videoPath in selectedPaths) {
      try {
        final file = File(videoPath);
        if (await file.exists()) {
          // 获取文件信息
          final fileName = p.basename(videoPath);
          final fileSize = await file.length();
          final title =
              fileName.substring(0, fileName.lastIndexOf('.')); // 去掉扩展名作为标题

          // 生成缩略图
          String? thumbnailPath;
          try {
            thumbnailPath = await FileUtils.generateVideoThumbnail(videoPath);
          } catch (e) {
            print('生成缩略图失败: $e');
          }

          // 创建视频对象
          final video = Video(
            title: title,
            filePath: videoPath,
            fileSize: fileSize,
            remark: '', // 初始备注为空
            tagIds: [], // 初始标签为空
            duration: null, // 初始时长为null，后续可以设置
            thumbnailPath: thumbnailPath,
          );

          // 保存视频对象
          await videoProvider.saveVideo(video);
        }
      } catch (e) {
        errors.add('处理文件 $videoPath 时出错: $e');
      }
    }

    // 显示结果
    String resultMessage =
        '视频初始化完成！成功添加 ${selectedPaths.length - errors.length} 个视频';
    if (errors.isNotEmpty) {
      resultMessage += '\n\n错误:\n${errors.join('\n')}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('初始化结果'),
        content: Text(resultMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isMultiSelectMode
            ? Text('已选择 ${_selectedVideos.length} 项')
            : Consumer<VideoProvider>(
                builder: (context, videoProvider, child) {
                  final videoCount = videoProvider.videos.length;
                  return Text('视频管理 ($videoCount)');
                },
              ),
        backgroundColor: Colors.blue[800],
        actions: [
          if (_isMultiSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: _showFilePathFilterDialog,
              tooltip: '按文件路径筛选',
            ),
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.white),
              onPressed: _transcodeSelectedVideos,
              tooltip: '显示/隐藏转码队列',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteSelectedVideos,
              tooltip: '删除选中视频',
            ),
            IconButton(
              icon: _selectedVideos.length ==
                      Provider.of<VideoProvider>(context, listen: false)
                          .videos
                          .length
                  ? const Icon(Icons.select_all, color: Colors.white)
                  : const Icon(Icons.deselect, color: Colors.white),
              onPressed: _toggleSelectAll,
              tooltip: _selectedVideos.length ==
                      Provider.of<VideoProvider>(context, listen: false)
                          .videos
                          .length
                  ? '取消全选'
                  : '全选',
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _toggleMultiSelectMode,
              tooltip: '退出多选',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.calculate, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PriceCalculatorPage(),
                  ),
                );
              },
              tooltip: '价格计算器',
            ),
            IconButton(
              icon: const Icon(Icons.cloud, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ServerControlPage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () async {
                // 使用UploadButton的上传逻辑

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
            ),
            IconButton(
              icon: const Icon(Icons.tag, color: Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TagManagementPage(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.playlist_add, color: Colors.white),
              onPressed: _initializeVideos,
              tooltip: '初始化视频',
            ),
            IconButton(
              icon: const Icon(Icons.swap_horiz, color: Colors.white),
              onPressed: _showFileReplaceDialog,
              tooltip: '文件替换',
            ),
            IconButton(
              icon: const Icon(Icons.select_all, color: Colors.white),
              onPressed: _toggleMultiSelectMode,
              tooltip: '多选模式',
            ),
          ],
        ],
      ),
      body: Row(
        // 使用Row来容纳视频网格和转码队列面板
        children: [
          // 搜索栏和视频网格（占据主要区域）
          Expanded(
            child: Column(
              children: [
                // 搜索栏和按钮
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // 搜索框（占剩余宽度）

                      Expanded(
                        flex: 10,
                        child: TextField(
                          controller: _searchController,

                          decoration: InputDecoration(
                            hintText: '搜索视频标题、标签或备注...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();

                                      _handleSearch(); // 清空搜索并重置结果
                                    },
                                  )
                                : null,
                            border: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8.0)),
                            ),
                          ),

                          onSubmitted: (_) => _handleSearch(), // 回车触发搜索
                        ),
                      ),

                      const SizedBox(width: 10),

                      // 搜索按钮

                      SizedBox(
                        height: 48, // 与搜索框同高

                        child: ElevatedButton.icon(
                          onPressed: _handleSearch,
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('搜索'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                  Radius.circular(8.0)), // 与搜索框相同的圆角
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 视频网格
                Expanded(
                  child: Consumer<VideoProvider>(
                    builder: (context, provider, child) {
                      if (provider.videos.isEmpty) {
                        return const Center(
                          child: Text('暂无视频，请上传视频'),
                        );
                      }
                      return VideoGrid(
                        videos: provider.videos,
                        isMultiSelectMode: _isMultiSelectMode,
                        selectedVideos: _selectedVideos,
                        onVideoSelected: _toggleVideoSelection,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // 转码队列面板（仅在需要显示时显示）
          if (_showTranscodeQueue)
            Consumer<TranscodeProvider>(
              builder: (context, transcodeProvider, child) {
                return TranscodeQueuePanel(
                  onHide: () {
                    setState(() {
                      _showTranscodeQueue = false; // 隐藏转码队列面板
                    });
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
