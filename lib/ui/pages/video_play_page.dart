import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../widgets/tag_selector.dart';
import '../../utils/file_utils.dart';
import '../../utils/video_uploader.dart';
import '../../utils/video_player_utils.dart';
import '../../providers/video_provider.dart';
// import '../../providers/tag_provider.dart';
import '../../models/video.dart';
import 'package:fluttertoast/fluttertoast.dart';

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
  List<String> _selectedTagIds = [];
  File? _sourceFile;
  Video? _existingVideo;
  final VideoPlayerUtils _playerUtils = VideoPlayerUtils();
  bool _isProcessing = false;
  bool _isSaved = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _initVideo();
  }

  @override
  void dispose() {
    _playerUtils.dispose();
    _titleController.dispose();
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
        await _playerUtils.initialize(_sourceFile!);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: '初始化失败: ${e.toString()}');
    } finally {
      setState(() => _isInitializing = false);
    }
  }

  // 处理标签选择变化
  void _onTagsSelected(List<String> tagIds) {
    setState(() => _selectedTagIds = tagIds);
  }

  // 保存视频（本地复制并保存信息）
  Future<void> _saveVideo() async {
    if (_titleController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: '请输入视频标题');
      return;
    }

    if (_sourceFile == null) {
      Fluttertoast.showToast(msg: '视频文件不存在');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final videoProvider = Provider.of<VideoProvider>(context, listen: false);

      if (_existingVideo != null) {
        // 更新已有视频信息
        _existingVideo!.title = _titleController.text.trim();
        _existingVideo!.tagIds = _selectedTagIds;

        // 如果没有缩略图，生成一个
        if (_existingVideo!.thumbnailPath == null ||
            !await File(_existingVideo!.thumbnailPath!).exists()) {
          final thumbnailPath =
              await FileUtils.generateVideoThumbnail(_existingVideo!.filePath);
          _existingVideo!.thumbnailPath = thumbnailPath;
        }

        await videoProvider.saveVideo(_existingVideo!);
        Fluttertoast.showToast(msg: '信息已更新');
      } else {
        // 新视频：复制到APP目录并保存信息
        await VideoUploader.copyToAppDirectory(
          _sourceFile!,
          _titleController.text.trim(),
          _selectedTagIds,
          videoProvider,
        );
        Fluttertoast.showToast(msg: '视频已添加到库中');
        _isSaved = true;
      }

      // 返回上一页
      if (mounted) Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: '操作失败: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSaved ? '编辑视频' : '添加视频'),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _saveVideo,
            child: Text(
              _isSaved ? '保存' : '添加到库',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
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

    return SingleChildScrollView(
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _playerUtils.getPlayerWidget(),
          ),
          // 视频播放器

          // 文件信息
          if (_sourceFile != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

          // 标题输入
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '视频标题',
                border: OutlineInputBorder(),
                hintText: '请输入视频标题',
              ),
              maxLength: 50,
              enabled: !_isProcessing,
            ),
          ),

          // 标签选择
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('选择标签：'),
                TagSelector(
                  selectedTagIds: _selectedTagIds,
                  onTagsSelected: _onTagsSelected,
                  enabled: !_isProcessing,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
