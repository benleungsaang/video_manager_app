import 'package:flutter/material.dart';
import '../../models/tag.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../providers/tag_provider.dart';
import '../../providers/video_provider.dart';
import '../pages/home_page.dart';
import '../../main.dart'; // 导入全局navigatorKey

class TagListItem extends StatefulWidget {
  final Tag tag;
  final VoidCallback onDeleted;

  const TagListItem({
    super.key,
    required this.tag,
    required this.onDeleted,
  });

  @override
  State<TagListItem> createState() => _TagListItemState();
}

class _TagListItemState extends State<TagListItem> {
  final TextEditingController _editController = TextEditingController();
  bool _isEditing = false;

  // 编辑标签
  void _editTag() {
    _editController.text = widget.tag.name;
    setState(() => _isEditing = true);
  }

  // 保存标签编辑
  void _saveEdit() {
    final newName = _editController.text.trim();
    if (newName.isEmpty || newName == widget.tag.name) {
      setState(() => _isEditing = false);
      return;
    }

    // 调用Provider更新标签
    final tagProvider = Provider.of<TagProvider>(context, listen: false);
    tagProvider.updateTag(widget.tag.id, newName).then((updatedTag) {
      if (updatedTag != null) {
        Fluttertoast.showToast(msg: '标签已更新');
      } else {
        Fluttertoast.showToast(msg: '标签名称已存在');
      }
      setState(() => _isEditing = false);
    });
  }

  // 搜索视频
  void _searchVideos() {
    // 导航到新页面并传递搜索关键字
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(initialSearchKeyword: widget.tag.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 2.0,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _isEditing
                      ? TextField(
                          controller: _editController,
                          autofocus: true,
                          onSubmitted: (_) => _saveEdit(),
                        )
                      : Text(
                          widget.tag.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  const SizedBox(height: 4),
                  Text(
                    '关联 ${widget.tag.videoCount} 个视频',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _isEditing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.save, color: Colors.green),
                        onPressed: _saveEdit,
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => setState(() => _isEditing = false),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search, color: Colors.blue),
                        onPressed: _searchVideos,
                        tooltip: '搜索包含此标签的视频',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: _editTag,
                        tooltip: '编辑标签',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: widget.onDeleted,
                        tooltip: '删除标签',
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
