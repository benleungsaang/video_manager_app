import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

/// 视频播放器工具类
class VideoPlayerUtils {
  late VideoPlayerController _videoController;
  late ChewieController _chewieController;
  bool _isInitialized = false;

  // 初始化视频播放器（通过文件路径）
  Future<void> initialize(File videoFile) async {
    _videoController = VideoPlayerController.file(videoFile);
    await _videoController.initialize();

    // 配置Chewie控制器（提供播放控制UI）
    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: true, // 自动播放
      looping: false, // 不循环播放
      allowFullScreen: true, // 允许全屏
      allowPlaybackSpeedChanging: true, // 允许调整播放速度
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.blue,
        handleColor: Colors.blueAccent,
        backgroundColor: Colors.grey[300]!,
        bufferedColor: Colors.grey[400]!,
      ),
      placeholder: const Center(child: CircularProgressIndicator()),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            '播放失败: $errorMessage',
            style: const TextStyle(color: Colors.red),
          ),
        );
      },
    );

    _isInitialized = true;
  }

  // 获取Chewie播放器组件
  Widget getPlayerWidget() {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Chewie(controller: _chewieController);
  }

  // 释放资源
  void dispose() {
    _videoController.dispose();
    _chewieController.dispose();
  }

  // 暂停播放
  void pause() {
    if (_isInitialized && _videoController.value.isPlaying) {
      _videoController.pause();
    }
  }

  // 继续播放
  void play() {
    if (_isInitialized && !_videoController.value.isPlaying) {
      _videoController.play();
    }
  }

  // 获取视频时长（格式化）
  String getFormattedDuration() {
    if (!_isInitialized) return '00:00';
    final duration = _videoController.value.duration;
    return '${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
