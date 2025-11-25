import 'package:flutter/material.dart';

enum TranscodeStatus { pending, running, completed, failed, cancelled }

class TranscodeTask {
  final String id;
  final String videoId;
  final String videoTitle;
  final String inputFilePath;
  final int inputFileSize;
  String? outputFilePath;
  int? outputFileSize;
  double progress;
  TranscodeStatus status;
  DateTime startTime;
  DateTime? endTime;
  String? errorMessage;

  TranscodeTask({
    required this.id,
    required this.videoId,
    required this.videoTitle,
    required this.inputFilePath,
    required this.inputFileSize,
    this.outputFilePath,
    this.outputFileSize,
    this.progress = 0.0,
    this.status = TranscodeStatus.pending,
    required this.startTime,
    this.endTime,
    this.errorMessage,
  });

  double get durationInMinutes {
    if (endTime != null) {
      return endTime!.difference(startTime).inMinutes.toDouble();
    }
    // 如果任务正在进行中，使用当前时间计算持续时间
    return DateTime.now().difference(startTime).inMinutes.toDouble();
  }
}