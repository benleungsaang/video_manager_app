import 'package:flutter/material.dart';
import '../../models/tag.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../providers/tag_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: _isEditing
          ? TextField(
              controller: _editController,
              autofocus: true,
              onSubmitted: (_) => _saveEdit(),
            )
          : Text(widget.tag.name),
      subtitle: Text('关联 ${widget.tag.videoCount} 个视频'),
      trailing: _isEditing
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: _saveEdit,
                ),
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: () => setState(() => _isEditing = false),
                ),
              ],
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _editTag,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDeleted,
                ),
              ],
            ),
    );
  }
}
