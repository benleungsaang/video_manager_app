import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_manager_app/utils/file_utils.dart';
import '../widgets/video_grid.dart';
import '../widgets/upload_button.dart';
import 'video_play_page.dart';
import '../pages/tag_management_page.dart';
import '../../providers/video_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();

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
          actions: [
            IconButton(
              icon: const Icon(Icons.tag),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TagManagementPage(),
                  ),
                );
              },
            ),
          ],
        ),
        body: Column(
          children: [
            // 搜索栏和上传按钮
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // 搜索框（占80%宽度）
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '搜索视频标题、标签或备注...',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8.0)),
                        ),
                      ),
                      onSubmitted: (_) => _handleSearch(), // 回车触发搜索
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 上传按钮（占20%宽度）
                  const Expanded(
                    flex: 1,
                    child: UploadButton(),
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
        // 悬浮上传按钮
        floatingActionButton: FloatingActionButton(
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
          child: const Icon(Icons.add),
        ));
  }
}
