import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class FileReplaceDialog extends StatefulWidget {
  final List<Map<String, String>> filePairs;
  final Function(List<Map<String, String>>) onReplace;

  const FileReplaceDialog({
    Key? key,
    required this.filePairs,
    required this.onReplace,
  }) : super(key: key);

  @override
  State<FileReplaceDialog> createState() => _FileReplaceDialogState();
}

class _FileReplaceDialogState extends State<FileReplaceDialog> {
  late List<bool> _selectedPairs;

  @override
  void initState() {
    super.initState();
    // 默认全部选中
    _selectedPairs = List.generate(widget.filePairs.length, (index) => true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('文件替换'),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            const Text(
              '以下为找到的文件对，勾选需要替换的文件对：',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: widget.filePairs.length,
                itemBuilder: (context, index) {
                  final pair = widget.filePairs[index];
                  final unTransCodeFile = pair['unTransCode']!;
                  final soonwinFile = pair['Soonwin']!;
                  final unTransCodeFileName = p.basename(unTransCodeFile);
                  final soonwinFileName = p.basename(soonwinFile);

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _selectedPairs[index],
                            onChanged: (value) {
                              setState(() {
                                _selectedPairs[index] = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '原文件: $unTransCodeFileName',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '替换为: $soonwinFileName',
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('返回'),
        ),
        TextButton(
          onPressed: () {
            // 获取选中的文件对
            List<Map<String, String>> selectedPairs = [];
            for (int i = 0; i < widget.filePairs.length; i++) {
              if (_selectedPairs[i]) {
                selectedPairs.add(widget.filePairs[i]);
              }
            }

            // 执行替换
            widget.onReplace(selectedPairs);
            
            // 关闭对话框
            Navigator.of(context).pop();
          },
          child: const Text('执行替换'),
        ),
      ],
    );
  }
}