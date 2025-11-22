import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/tag_list_item.dart';
import '../../providers/tag_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TagManagementPage extends StatefulWidget {
  const TagManagementPage({super.key});

  @override
  State<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends State<TagManagementPage> {
  final TextEditingController _tagNameController = TextEditingController();

  // 显示添加标签对话框
  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加标签'),
        content: TextField(
          controller: _tagNameController,
          decoration: const InputDecoration(
            hintText: '请输入标签名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final tagName = _tagNameController.text.trim();
              if (tagName.isNotEmpty) {
                final tagProvider =
                    Provider.of<TagProvider>(context, listen: false);
                final newTag = await tagProvider.createTag(tagName);

                if (newTag != null) {
                  _tagNameController.clear();
                  Navigator.pop(context);
                  Fluttertoast.showToast(msg: '标签添加成功');
                } else {
                  Fluttertoast.showToast(msg: '标签已存在');
                }
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 在构建界面时重新计算标签关联数量
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tagProvider = Provider.of<TagProvider>(context, listen: false);
      tagProvider.recalculateVideoCounts();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddTagDialog,
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100], // 设置背景色
        child: Consumer<TagProvider>(
          builder: (context, provider, child) {
            if (provider.tags.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.tag,
                      size: 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      '暂无标签，请添加标签',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                // 下拉刷新时重新计算标签关联数量
                await provider.recalculateVideoCounts();
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: provider.tags.length,
                itemBuilder: (context, index) {
                  final tag = provider.tags[index];
                  return TagListItem(
                    tag: tag,
                    onDeleted: () async {
                      // 显示确认对话框
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('确认删除'),
                          content: Text('删除后影响 ${tag.videoCount} 个视频，确认删除？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                '删除',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await provider.deleteTag(tag.id);
                        // 删除标签后重新计算所有标签的关联数量
                        await provider.recalculateVideoCounts();
                        Fluttertoast.showToast(msg: '标签已删除');
                      }
                    },
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}