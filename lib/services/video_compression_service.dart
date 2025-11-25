import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'package:path/path.dart' as p;

import '../utils/toast_utils.dart';

class VideoCompressionService {
  // 优化：对齐微信一般压缩参数（平衡体积和体验）
  static const _wechatOriginalVideoMaxBitrate = 8500 * 1000;
  // static const _wechatOriginalMaxW = 1920;
  static const _wechatOriginalAudioBitrate = 128000;

  // 全局时间变量，用于记录压缩开始时间
  static DateTime? _compressionStartTime;

  /// 检查FFmpeg是否可用
  static Future<bool> isFFmpegAvailable() async {
    try {
      // 执行简单的FFmpeg命令来检查可用性
      final session = await FFmpegKit.execute('-version');
      final returnCode = await session.getReturnCode();
      return ReturnCode.isSuccess(returnCode);
    } catch (e) {
      print('FFmpeg不可用: $e');
      return false;
    }
  }

  /// 根据指定的压缩模式压缩视频
  ///
  /// [inputPath] - 输入视频路径
  /// 返回压缩后视频的路径，如果失败则返回null
  /// 核心修改：移除视频信息解析，直接按微信规则压缩（兼容所有Android FFmpeg-Kit）
  static Future<String?> compressVideo({
    required String inputPath,
  }) async {
    try {
      print('开始压缩视频，输入路径: $inputPath');
      _compressionStartTime = DateTime.now();
      final inputFile = File(inputPath);

      // 基础校验
      if (!await inputFile.exists()) {
        print('输入文件不存在: $inputPath');
        return null;
      }

      // 输出路径处理
      final inputStat = await inputFile.stat();
      print('输入文件大小: ${inputStat.size} bytes, 路径: $inputPath');

      final inputDir = inputFile.parent.path;
      final inputName = p.basename(inputFile.path);
      // final inputExt =
      //     p.extension(inputName).toLowerCase().replaceFirst('.', '');
      final outputName = inputName.replaceAll('unTransCode', 'Soonwin');
      final outputPath = p.join(inputDir, outputName);
      print('输出路径: $outputPath');

      // 生成核心压缩命令
      String mainCommand;
      mainCommand = _buildWechatOriginalCommand(inputPath, outputPath);

      // 执行主命令
      print('执行FFmpeg主命令: $mainCommand');
      final mainSession = await FFmpegKit.execute(mainCommand);
      final mainReturnCode = await mainSession.getReturnCode();
      print('主命令执行完成，返回码: ${mainReturnCode?.getValue()}');

      if (ReturnCode.isSuccess(mainReturnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final outputStat = await outputFile.stat();
          print('主命令压缩成功，输出文件大小: ${outputStat.size} bytes');
          final resultPath =
              await _verifyAndReturnResult(inputPath, outputPath);
          if (resultPath == inputPath) {
            return inputPath; // 反向压缩，返回原文件
          }
          ToastUtils.showSuccess('视频压缩成功');
          return outputPath;
        } else {
          print('主命令压缩成功但未找到输出文件');
          return _fallbackCompression(inputPath, outputPath);
        }
      } else {
        // 打印详细视频压缩失败命令
        await detailLog(mainSession);
        return _fallbackCompression(inputPath, outputPath);
      }
    } catch (e) {
      print('视频压缩过程中发生异常: $e');
      return null;
    }
  }

  // 打印详细视频压缩失败命令
  static detailLog(mainSession) async {
    print('主命令压缩失败，触发备用命令');
    // 新增：获取并打印主命令的详细日志
    final mainLogs = await mainSession.getAllLogsAsString();
    final mainFailStackTrace = await mainSession.getFailStackTrace();

    print('主命令执行失败详细日志:');
    print('===================== FFmpeg 输出日志 =====================');
    print(mainLogs ?? '无日志输出');
    print('=========================================================');

    if (mainFailStackTrace != null && mainFailStackTrace.isNotEmpty) {
      print('===================== 错误堆栈 =====================');
      print(mainFailStackTrace);
      print('=====================================================');
    }
  }

  /// 微信原画压缩命令（宽松限制，保画质）
  static String _buildWechatOriginalCommand(
      String inputPath, String outputPath) {
    return '-i \'$inputPath\' '
        '-c:v libx264 -profile:v main -level 4.0 '
        '-crf 28 -preset medium '
        '-maxrate $_wechatOriginalVideoMaxBitrate -bufsize ${_wechatOriginalVideoMaxBitrate * 2} '
        '-vf "scale=w=min(iw\\,1920):h=-2:force_original_aspect_ratio=decrease,'
        'pad=width=ceil(iw/2)*2:height=ceil(ih/2)*2:x=0:y=0:color=black,'
        'format=yuv420p" '
        '-c:a aac -ac 2 -ar 44100 -b:a ${_wechatOriginalAudioBitrate} '
        '-r 30 '
        '-f mp4 -movflags +faststart -y \'$outputPath\'';
  }

  // 2. 新增：压缩后体积校验（兜底机制，避免反向压缩）
  static Future<String?> _verifyAndReturnResult(
      String inputPath, String outputPath) async {
    final inputFile = File(inputPath);
    final outputFile = File(outputPath);

    if (!await outputFile.exists()) {
      print('输出文件不存在，返回原文件');
      return inputPath;
    }

    final inputSize = (await inputFile.stat()).size;
    final outputSize = (await outputFile.stat()).size;

    // 若输出体积 > 输入体积的90%（视为反向压缩），返回原文件+删除压缩文件
    if (outputSize > inputSize * 0.9) {
      print('反向压缩：输入${inputSize} bytes → 输出${outputSize} bytes，返回原文件');
      await outputFile.delete().catchError((e) => print('删除无效压缩文件失败: $e'));
      ToastUtils.showInfo('视频已为最优体积，无需压缩');
      return inputPath;
    }

    // 正常压缩，返回输出路径
    print('有效压缩：输入${inputSize} bytes → 输出${outputSize} bytes');
    return outputPath;
  }

  /// 优化后的备用命令（解决反向压缩问题）
  static Future<String?> _fallbackCompression(
      String inputPath, String outputPath) async {
    try {
      String fallbackCommand;
      fallbackCommand = '-i \'$inputPath\' '
          '-c:v libx264 -profile:v main -level 4.0 '
          '-crf 30 -preset medium '
          '-c:a aac -ac 2 -ar 44100 -b:a 96000 '
          '-vf "format=yuv420p" '
          '-f mp4 -movflags +faststart -y \'$outputPath\'';

      print('执行备用FFmpeg命令: $fallbackCommand');
      final session = await FFmpegKit.execute(fallbackCommand);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final resultPath =
              await _verifyAndReturnResult(inputPath, outputPath);
          if (resultPath == inputPath) {
            return inputPath;
          }
          print('备用命令压缩成功，输出文件大小: ${(await outputFile.stat()).size} bytes');
          ToastUtils.showSuccess('视频压缩成功（兼容模式）');
          return outputPath;
        }
      }

      print('备用命令执行失败，返回码: ${returnCode?.getValue()}');
      return inputPath;
    } catch (e) {
      print('备用压缩异常: $e');
      return inputPath;
    }
  }
}
