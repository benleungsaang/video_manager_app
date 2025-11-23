import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../widgets/tag_selector.dart';
import '../../utils/file_utils.dart';
import '../../utils/video_uploader.dart';
import '../../utils/video_player_utils.dart';
import '../../providers/video_provider.dart';
import '../../models/video.dart';
import '../../utils/toast_utils.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoPlayPage extends StatefulWidget {
  // 两种打开方式：1.通过文件路径（新视频） 2.通过视频ID（已有视频）
  final String? filePath;
  final String? videoId;

  const VideoPlayPage({
    super.key,
    this.filePath,
    this.videoId,
  }) : assert(filePath != null || videoId != null, "必须提供filePath或videoId");

  @override
  State<VideoPlayPage> createState() => _VideoPlayPageState();
}

class _VideoPlayPageState extends State<VideoPlayPage> {
  late TextEditingController _titleController;
  late TextEditingController _remarkController;
  List<String> _selectedTagIds = [];
  File? _sourceFile;
  Video? _existingVideo;
  final VideoPlayerUtils _playerUtils = VideoPlayerUtils();
  bool _isProcessing = false;
  bool _isSaved = false;
  bool _isInitializing = true;
  final TextEditingController _newTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _remarkController = TextEditingController();
    _initVideo();
  }

  @override
  void dispose() {
    _playerUtils.dispose();
    _titleController.dispose();
    _remarkController.dispose();
    _newTagController.dispose();
    super.dispose();
  }

  // 初始化视频（加载文件+初始化播放器）
  Future<void> _initVideo() async {
    try {
      if (widget.videoId != null) {
        // 打开已有视频
        final videoProvider =
            Provider.of<VideoProvider>(context, listen: false);
        _existingVideo = videoProvider.getVideoById(widget.videoId!);

        if (_existingVideo != null) {
          _titleController.text = _existingVideo!.title;
          _remarkController.text = _existingVideo!.remark; // 设置备注
          _selectedTagIds = List.from(_existingVideo!.tagIds);
          _sourceFile = File(_existingVideo!.filePath);
          _isSaved = true;
          await _playerUtils.initialize(_sourceFile!);
        } else {
          throw Exception("视频不存在");
        }
      } else if (widget.filePath != null) {
        // 打开新选择的视频（待保存）
        _sourceFile = File(widget.filePath!);
        final fileName = widget.filePath!.split('/').last;
        _titleController.text = fileName.split('.').first;
        _remarkController.text = ''; // 新视频备注为空
        await _playerUtils.initialize(_sourceFile!);
      }
    } catch (e) {
      ToastUtils.showError(context, '初始化失败: ${e.toString()}');
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  // 处理标签选择变化
  void _onTagsSelected(List<String> tagIds) {
    setState(() => _selectedTagIds = tagIds);
  }

  // 添加新标签
  void _addNewTag() {
    if (_newTagController.text.trim().isNotEmpty) {
      // 这里需要一个标签服务来添加新标签，暂时只是模拟
      // 在实际实现中，需要调用标签服务添加新标签
      ToastUtils.showInfo('暂不支持直接添加新标签，功能待实现');
      _newTagController.clear();
    }
  }

  // 保存视频（本地复制并保存信息）
  Future<void> _saveVideo() async {
    if (_titleController.text.trim().isEmpty) {
      ToastUtils.showWarning('请输入视频标题');
      return;
    }

    if (_sourceFile == null) {
      ToastUtils.showError(context, '视频文件不存在');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 在Android上请求存储权限
      if (Theme.of(context).platform == TargetPlatform.android) {
        final status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          // 如果权限被拒绝，尝试使用应用专属存储
          ToastUtils.showInfo('存储权限被拒绝，将使用应用内部存储');
        }
      }

      final videoProvider = Provider.of<VideoProvider>(context, listen: false);

      if (_existingVideo != null) {
        // 更新已有视频信息
        _existingVideo!.title = _titleController.text.trim();
        _existingVideo!.remark = _remarkController.text.trim(); // 更新备注
        _existingVideo!.tagIds = _selectedTagIds;
        _existingVideo!.duration = _playerUtils.getdDuration();

        // 如果没有缩略图，生成一个
        if (_existingVideo!.thumbnailPath == null ||
            !await File(_existingVideo!.thumbnailPath!).exists()) {
          final thumbnailPath =
              await FileUtils.generateVideoThumbnail(_existingVideo!.filePath);
          _existingVideo!.thumbnailPath = thumbnailPath;
        }

        await videoProvider.saveVideo(_existingVideo!);
        ToastUtils.showSuccess('信息已更新');
      } else {
        // 确保视频播放器已初始化后再获取时长
        int durationTime = 0;
        if (_playerUtils.getdDuration() > 0) {
          durationTime = _playerUtils.getdDuration();
        } else {
          // 如果无法获取视频时长，使用0作为默认值
          // 播放器可能还未完全加载时长信息
          print('警告：无法获取视频时长，默认设置为0');
        }
        // 新视频：复制到APP目录并保存信息（包含备注）
        await VideoUploader.copyToAppDirectoryWithRemark(
          _sourceFile!,
          _titleController.text.trim(),
          _selectedTagIds,
          _remarkController.text.trim(), // 添加备注
          videoProvider,
          durationTime,
        );
        ToastUtils.showSuccess('视频已添加到库中');
        _isSaved = true;
      }

      // 返回上一页
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ToastUtils.showError(context, '操作失败: ${e.toString()}');
      print('保存视频失败: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSaved ? '编辑视频' : '添加视频'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.save,
              color: Colors.white,
              size: 32,
            ),
            onPressed: _isProcessing ? null : _saveVideo,
            tooltip: '保存视频',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  // 构建页面主体
  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(child: CircularProgressIndicator());
    }

    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          // 横屏：左右排布
          return Row(
            children: [
              // 左边：视频播放框和文件信息
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _playerUtils.getPlayerWidget(),
                        ),
                      ),
                      // 文件信息
                      if (_sourceFile != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '文件大小: ${FileUtils.formatFileSize(_sourceFile!.lengthSync())}',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 18),
                              ),
                              Text(
                                '时长: ${_playerUtils.getFormattedDuration()}',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // 右边：标题、标签等
              Expanded(
                flex: 1,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  color: Colors.grey[50],
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 视频标题
                        Text(
                          '视频标题',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            hintText: '请输入视频标题',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLength: 50,
                          enabled: !_isProcessing,
                        ),

                        const SizedBox(height: 16),

                        // 视频备注
                        Text(
                          '视频备注',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _remarkController,
                          decoration: InputDecoration(
                            hintText: '请输入视频备注',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: 3,
                          maxLength: 200,
                          enabled: !_isProcessing,
                        ),

                        const SizedBox(height: 16),

                        // 新标签输入框
                        TagSelector(
                          selectedTagIds: _selectedTagIds,
                          onTagsSelected: _onTagsSelected,
                          enabled: !_isProcessing,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          // 竖屏：上下排布
          return SingleChildScrollView(
            child: Column(
              children: [
                // 视频播放器
                Container(
                  height: 250, // 增加播放器高度
                  width: double.infinity,
                  margin: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _playerUtils.getPlayerWidget(),
                ),
                // 文件信息
                if (_sourceFile != null)
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '文件大小: ${FileUtils.formatFileSize(_sourceFile!.lengthSync())}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        Text(
                          '时长: ${_playerUtils.getFormattedDuration()}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // 标题输入
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '视频标题',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: '请输入视频标题',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLength: 50,
                        enabled: !_isProcessing,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 备注输入
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '视频备注',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _remarkController,
                        decoration: InputDecoration(
                          hintText: '请输入视频备注',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: 3,
                        maxLength: 200,
                        enabled: !_isProcessing,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 可选标签
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TagSelector(
                        selectedTagIds: _selectedTagIds,
                        onTagsSelected: _onTagsSelected,
                        enabled: !_isProcessing,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }
      },
    );
  }
}