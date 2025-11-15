import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tag_provider.dart';
// import '../../models/tag.dart';
import 'package:fluttertoast/fluttertoast.dart';

class TagSelector extends StatefulWidget {
  final List<String> selectedTagIds;
  final Function(List<String>) onTagsSelected;
  final bool enabled;

  const TagSelector({
    super.key,
    required this.selectedTagIds,
    required this.onTagsSelected,
    this.enabled = true,
  });

  @override
  State<TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends State<TagSelector> {
  late List<String> _selectedTagIds;
  final TextEditingController _newTagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedTagIds = List.from(widget.selectedTagIds);
  }

  @override
  void didUpdateWidget(covariant TagSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTagIds != oldWidget.selectedTagIds) {
      _selectedTagIds = List.from(widget.selectedTagIds);
    }
  }

  // 切换标签选择状态
  void _toggleTag(String tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
      widget.onTagsSelected(_selectedTagIds);
    });
  }

  // 添加新标签
  void _addNewTag() {
    final tagName = _newTagController.text.trim();
    if (tagName.isEmpty) return;

    final tagProvider = Provider.of<TagProvider>(context, listen: false);
    tagProvider.createTag(tagName).then((newTag) {
      if (newTag != null) {
        _newTagController.clear();
        setState(() {
          _selectedTagIds.add(newTag.id);
          widget.onTagsSelected(_selectedTagIds);
        });
      } else {
        Fluttertoast.showToast(msg: '标签已存在');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TagProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // 已选标签
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTagIds
                  .map((id) {
                    final tag = provider.getTagById(id);
                    return tag != null
                        ? Chip(
                            label: Text(tag.name),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted:
                                widget.enabled ? () => _toggleTag(id) : null,
                            backgroundColor:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                          )
                        : null;
                  })
                  .whereType<Widget>()
                  .toList(),
            ),

            const SizedBox(height: 16),

            // 标签选择区
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('可选标签：'),
            ),
            const SizedBox(height: 8),

            // 标签列表
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: provider.tags
                  .where((tag) => !_selectedTagIds.contains(tag.id))
                  .map((tag) => ChoiceChip(
                        label: Text(tag.name),
                        selected: _selectedTagIds.contains(tag.id),
                        onSelected:
                            widget.enabled ? (_) => _toggleTag(tag.id) : null,
                      ))
                  .toList(),
            ),

            const SizedBox(height: 16),

            // 添加新标签
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newTagController,
                    decoration: const InputDecoration(
                      hintText: '输入新标签名称',
                      border: OutlineInputBorder(),
                    ),
                    enabled: widget.enabled,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: widget.enabled ? _addNewTag : null,
                  child: const Text('添加'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
