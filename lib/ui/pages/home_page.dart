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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearchKeyword); // 设置初始搜索关键字
    
    // 如果有初始搜索关键字，则自动执行搜索
    if (widget.initialSearchKeyword != null && widget.initialSearchKeyword!.isNotEmpty) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频管理'),
        backgroundColor: Colors.blue[800],
        actions: [
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
                return VideoGrid(videos: provider.videos);
              },
            ),
          ),
        ],
      ),
    );
  }
}
