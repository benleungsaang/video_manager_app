import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:file_picker/file_picker.dart';

import 'package:video_manager_app/ui/pages/server_control_page.dart';

import 'package:video_manager_app/utils/file_utils.dart';

import '../widgets/video_grid.dart';

import '../widgets/upload_button.dart';

import 'video_play_page.dart';

import '../pages/tag_management_page.dart';

import '../../providers/video_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isMultiSelectMode
            ? Text('已选择 ${_selectedVideos.length} 项')
            : const Text('视频管理'),
        backgroundColor: Colors.blue[800],
        actions: [
          if (_isMultiSelectMode) ...[
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
              icon: const Icon(Icons.select_all, color: Colors.white),
              onPressed: _toggleMultiSelectMode,
              tooltip: '多选模式',
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
            const SizedBox(width: 8),
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
          ],
        ],
      ),
      body: Column(
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
                        borderRadius: BorderRadius.all(Radius.circular(8.0)),
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
                        borderRadius:
                            BorderRadius.all(Radius.circular(8.0)), // 与搜索框相同的圆角
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
    );
  }
}
