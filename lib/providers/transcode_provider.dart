import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/video.dart';
import '../models/transcode_task.dart';
import '../services/video_compression_service.dart';
import 'package:video_manager_app/providers/video_provider.dart';

class TranscodeProvider with ChangeNotifier {
  final List<TranscodeTask> _tasks = [];
  bool _isTranscoding = false;
  bool _isCancelled = false;

  List<TranscodeTask> get tasks => _tasks;
  bool get isTranscoding => _isTranscoding;

  // 添加转码任务
  void addTask(TranscodeTask task) {
    _tasks.add(task);
    notifyListeners();
  }

  // 批量添加转码任务
  void addTasks(List<TranscodeTask> tasks) {
    _tasks.addAll(tasks);
    notifyListeners();
  }

  // 更新任务状态
  void updateTask(String taskId,
      {double? progress,
      TranscodeStatus? status,
      String? outputFilePath,
      int? outputFileSize,
      String? errorMessage}) {
    final task = _tasks.firstWhere((t) => t.id == taskId,
        orElse: () => _tasks.firstWhere((t) => false,
            orElse: () => throw Exception('Task not found')));
    if (progress != null) task.progress = progress;
    if (status != null) task.status = status;
    if (outputFilePath != null) task.outputFilePath = outputFilePath;
    if (outputFileSize != null) task.outputFileSize = outputFileSize;
    if (errorMessage != null) task.errorMessage = errorMessage;

    if (status == TranscodeStatus.completed ||
        status == TranscodeStatus.failed) {
      task.endTime = DateTime.now();
    }

    notifyListeners();
  }

  // 开始转码队列
  Future<void> startTranscodingQueue({VideoProvider? videoProvider}) async {
    if (_isTranscoding) return;

    _isTranscoding = true;
    _isCancelled = false;

    // 按顺序处理队列中的任务
    for (final task in _tasks) {
      if (_isCancelled) break;

      if (task.status == TranscodeStatus.pending) {
        await _processSingleTask(task, videoProvider: videoProvider);
      }
    }

    _isTranscoding = false;
    notifyListeners();
  }

  // 处理单个转码任务
  Future<void> _processSingleTask(TranscodeTask task,
      {VideoProvider? videoProvider}) async {
    if (_isCancelled) return;

    updateTask(task.id, status: TranscodeStatus.running);

    try {
      // 执行转码
      String? resultPath = await VideoCompressionService.compressVideo(
          inputPath: task.inputFilePath);

      if (_isCancelled) {
        updateTask(task.id, status: TranscodeStatus.cancelled);
        return;
      }

      if (resultPath != null && resultPath != task.inputFilePath) {
        // 转码成功且生成了新文件
        int resultFileSize = await _getFileSize(resultPath);
        updateTask(
          task.id,
          status: TranscodeStatus.completed,
          outputFilePath: resultPath,
          outputFileSize: resultFileSize,
        );
        // 更新视频对象的filePath和fileSize，并删除原视频文件
        if (videoProvider != null) {
          await _updateVideoAndDeleteOriginal(videoProvider, task.videoId,
              resultPath, resultFileSize, task.inputFilePath);
        }
      } else if (resultPath != null && resultPath == task.inputFilePath) {
        // 转码完成但使用了原文件（例如反向压缩保护机制触发），添加"Soonwin_"前缀
        String prefixedPath =
            await _addPrefixToFileName(task.inputFilePath, "Soonwin_");
        updateTask(
          task.id,
          status: TranscodeStatus.completed,
          outputFilePath: prefixedPath, // 使用添加了前缀的路径
          outputFileSize: task.inputFileSize, // 使用原始文件大小
        );
        // 更新视频对象的filePath，并且不删除原文件
        if (videoProvider != null) {
          await _updateVideoWithoutDeletingOriginal(
              videoProvider, task.videoId, prefixedPath, task.inputFileSize);
        }
      } else {
        updateTask(task.id,
            status: TranscodeStatus.failed, errorMessage: '转码失败');
      }
    } catch (e) {
      if (!_isCancelled) {
        updateTask(task.id,
            status: TranscodeStatus.failed, errorMessage: e.toString());
      }
    }
  }

  // 更新视频对象的filePath和fileSize，并删除原视频文件
  Future<void> _updateVideoAndDeleteOriginal(
      VideoProvider videoProvider,
      String videoId,
      String newFilePath,
      int newFileSize,
      String originalFilePath) async {
    try {
      final video = videoProvider.getVideoById(videoId);
      if (video != null) {
        // 更新视频的文件路径和大小
        final updatedVideo = Video(
          id: video.id,
          title: video.title,
          filePath: newFilePath,
          fileSize: newFileSize,
          tagIds: video.tagIds,
          remark: video.remark,
          uploadTime: video.uploadTime,
          duration: video.duration,
          thumbnailPath: video.thumbnailPath,
        );
        await videoProvider.saveVideo(updatedVideo);

        // 删除原视频文件（如果新文件路径与原路径不同）
        if (newFilePath != originalFilePath) {
          final originalFile = File(originalFilePath);
          if (await originalFile.exists()) {
            await originalFile.delete();
          }
        }
      }
    } catch (e) {
      print('更新视频对象或删除原文件时出错: $e');
    }
  }

  // 添加文件名前缀
  Future<String> _addPrefixToFileName(String filePath, String prefix) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final pathParts = filePath.split('/');
        String fileName = pathParts.last;
        if (fileName.isEmpty) {
          // 如果最后一个是空的，尝试用反斜杠分割
          pathParts.clear();
          pathParts.addAll(filePath.split('\\'));
          fileName = pathParts.last;
        }
        final directory =
            filePath.substring(0, filePath.length - fileName.length);
        final fileExtension = fileName.contains('.')
            ? fileName.substring(fileName.lastIndexOf('.'))
            : '';
        final fileNameWithoutExtension = fileExtension.isEmpty
            ? fileName
            : fileName.substring(0, fileName.lastIndexOf('.'));
        final newFileName =
            '${prefix}${fileNameWithoutExtension}${fileExtension}';
        final newFilePath = '${directory}${newFileName}';

        // 重命名文件
        await file.rename(newFilePath);
        return newFilePath;
      }
    } catch (e) {
      print('添加文件名前缀失败: $e');
    }
    return filePath; // 如果失败，返回原路径
  }

  // 仅更新视频对象的filePath，不删除原文件
  Future<void> _updateVideoWithoutDeletingOriginal(VideoProvider videoProvider,
      String videoId, String newFilePath, int newFileSize) async {
    try {
      final video = videoProvider.getVideoById(videoId);
      if (video != null) {
        // 更新视频的文件路径和大小
        final updatedVideo = Video(
          id: video.id,
          title: video.title,
          filePath: newFilePath,
          fileSize: newFileSize,
          tagIds: video.tagIds,
          remark: video.remark,
          uploadTime: video.uploadTime,
          duration: video.duration,
          thumbnailPath: video.thumbnailPath,
        );
        await videoProvider.saveVideo(updatedVideo);
      }
    } catch (e) {
      print('更新视频对象时出错: $e');
    }
  }

  // 获取文件大小
  Future<int> _getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      return stat.size;
    } catch (e) {
      print('获取文件大小失败: $e');
      return 0;
    }
  }

  // 取消所有转码任务
  void cancelAllTasks() {
    _isCancelled = true;
    for (final task in _tasks) {
      if (task.status == TranscodeStatus.pending ||
          task.status == TranscodeStatus.running) {
        updateTask(task.id, status: TranscodeStatus.cancelled);
      }
    }
    _isTranscoding = false;
    notifyListeners();
  }

  // 清空已完成的任务
  void clearCompletedTasks() {
    _tasks.removeWhere((task) => task.status == TranscodeStatus.completed);
    notifyListeners();
  }

  // 清空指定状态的任务（已完成、已取消、已失败的任务）
  void clearTasksByStatus(Set<TranscodeStatus> statuses) {
    _tasks.removeWhere((task) => statuses.contains(task.status));
    notifyListeners();
  }

  // 清空所有非运行中和非待处理的任务
  void clearNonActiveTasks() {
    _tasks.removeWhere((task) =>
        task.status == TranscodeStatus.completed ||
        task.status == TranscodeStatus.failed ||
        task.status == TranscodeStatus.cancelled);
    notifyListeners();
  }

  // 重新开始指定的任务
  Future<void> restartTask(String taskId,
      {VideoProvider? videoProvider}) async {
    final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
    if (taskIndex != -1) {
      final task = _tasks[taskIndex];
      // 重置任务状态为待处理
      _tasks[taskIndex] = TranscodeTask(
        id: task.id,
        videoId: task.videoId,
        videoTitle: task.videoTitle,
        inputFilePath: task.inputFilePath,
        inputFileSize: task.inputFileSize,
        outputFilePath: null,
        outputFileSize: null,
        progress: 0.0,
        status: TranscodeStatus.pending,
        startTime: DateTime.now(), // 更新开始时间为当前时间
        endTime: null,
        errorMessage: null,
      );
      notifyListeners();

      // 如果转码队列当前未运行，自动开始转码
      if (!_isTranscoding) {
        startTranscodingQueue(videoProvider: videoProvider);
      }
    }
  }

  // 重新开始所有可以重新开始的任务（已完成、已失败、已取消的任务）
  Future<void> restartAllTasks({VideoProvider? videoProvider}) async {
    for (int i = 0; i < _tasks.length; i++) {
      final task = _tasks[i];
      if (task.status == TranscodeStatus.completed ||
          task.status == TranscodeStatus.failed ||
          task.status == TranscodeStatus.cancelled) {
        _tasks[i] = TranscodeTask(
          id: task.id,
          videoId: task.videoId,
          videoTitle: task.videoTitle,
          inputFilePath: task.inputFilePath,
          inputFileSize: task.inputFileSize,
          outputFilePath: null,
          outputFileSize: null,
          progress: 0.0,
          status: TranscodeStatus.pending,
          startTime: DateTime.now(), // 更新开始时间为当前时间
          endTime: null,
          errorMessage: null,
        );
      }
    }
    notifyListeners();

    // 如果转码队列当前未运行，自动开始转码
    if (!_isTranscoding) {
      startTranscodingQueue(videoProvider: videoProvider);
    }
  }

  // 重置状态
  void reset() {
    _isTranscoding = false;
    _isCancelled = false;
    notifyListeners();
  }
}
