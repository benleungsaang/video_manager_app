import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'package:path/path.dart' as p;

import '../utils/toast_utils.dart';

class VideoCompressionService {
  // 优化：对齐微信一般压缩参数（平衡体积和体验）
  static const _wechatGeneralVideoMaxBitrate =
      1500 * 1000; // 1.5Mbps（微信视频码率1472kbps）
  static const _wechatOriginalVideoMaxBitrate = 8500 * 1000;
  static const _wechatGeneralMaxW = 1280;
  static const _wechatOriginalMaxW = 1920;
  static const _wechatGeneralAudioBitrate = 72000; // 72kbps（微信音频72kbps）
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
  /// [compressionMode] - 压缩模式 ('full' 或 'original')
  /// 返回压缩后视频的路径，如果失败则返回null
  /// 核心修改：移除视频信息解析，直接按微信规则压缩（兼容所有Android FFmpeg-Kit）
  static Future<String?> compressVideo({
    required String inputPath,
    required String compressionMode,
  }) async {
    try {
      print('开始压缩视频，输入路径: $inputPath, 压缩模式: $compressionMode');
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
      final inputExt =
          p.extension(inputName).toLowerCase().replaceFirst('.', '');
      final outputName = inputName.replaceAll('.$inputExt', '_compressed.mp4');
      final outputPath = p.join(inputDir, outputName);
      print('输出路径: $outputPath');

      // 生成核心压缩命令（根据模式选择）
      String mainCommand;
      if (compressionMode == 'full') {
        mainCommand = _buildWechatGeneralCommand(inputPath, outputPath);
      } else if (compressionMode == 'original') {
        mainCommand = _buildWechatOriginalCommand(inputPath, outputPath);
      } else {
        print('未知的压缩模式: $compressionMode');
        return null;
      }

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
          return _fallbackCompression(inputPath, outputPath, compressionMode);
        }
      } else {
        // 打印详细视频压缩失败命令
        await detailLog(mainSession);
        return _fallbackCompression(inputPath, outputPath, compressionMode);
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

  /// 尝试使用备用的简单FFmpeg命令进行压缩
  static Future<String?> _tryFallbackCompression(
      String inputPath, String outputPath) async {
    // 首先尝试标准备用命令
    String? result = await _trySimpleFallbackCompression(inputPath, outputPath);
    if (result != null) {
      return result;
    }

    // 如果标准备用命令失败，尝试更简化的命令
    print('尝试使用更简化的备用命令进行视频压缩...');
    result = await _tryUltraSimpleFallbackCompression(inputPath, outputPath);
    if (result != null) {
      return result;
    }

    print('所有备用压缩方法都失败了');
    return null;
  }

  /// 尝试使用标准备用的简单FFmpeg命令进行压缩
  static Future<String?> _trySimpleFallbackCompression(
      String inputPath, String outputPath) async {
    try {
      // 使用更简单的H.264压缩命令作为备用方案，确保音频也重新编码以提高兼容性
      final fallbackCommand =
          '-i "$inputPath" -c:v libx264 -profile:v baseline -level 3.0 -crf 28 -preset fast -c:a aac -b:a 128k -vf format=yuv420p -f mp4 -movflags +faststart -y "$outputPath"';
      print('执行标准备用FFmpeg命令: $fallbackCommand');

      final session = await FFmpegKit.execute(fallbackCommand);
      final returnCode = await session.getReturnCode();

      print('标准备用命令执行完成，返回码: ${returnCode?.getValue()}');

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final outputStat = await outputFile.stat();
          print('标准备用压缩成功，输出文件大小: ${outputStat.size} bytes');
          // 计算压缩耗时
          if (_compressionStartTime != null) {
            Duration duration =
                DateTime.now().difference(_compressionStartTime!);
            final String fileName = p.basename(outputPath);
            ;
            ToastUtils.showSuccess(
                '视频 【 ${fileName} 】 压缩耗时: ${duration.inSeconds}秒');
            _compressionStartTime = null; // 重置时间变量
          }
          return outputPath;
        }
      } else {
        print('标准备用压缩失败，返回码: ${returnCode?.getValue()}');

        final failStackTrace = await session.getFailStackTrace();
        final logOutput = await session.getLogsAsString();
        final allLogs = await session.getAllLogsAsString();

        if (failStackTrace != null && failStackTrace.isNotEmpty) {
          print('标准备用命令错误堆栈: $failStackTrace');
        }

        if (logOutput != null && logOutput.isNotEmpty) {
          print('标准备用命令FFmpeg日志: $logOutput');
        }

        if (allLogs != null && allLogs.isNotEmpty) {
          print('标准备用命令完整FFmpeg日志: $allLogs');
        }
      }
    } catch (e) {
      print('标准备用压缩过程中发生异常: $e');
    }

    return null;
  }

  /// 尝试使用最简化的FFmpeg命令进行压缩
  static Future<String?> _tryUltraSimpleFallbackCompression(
      String inputPath, String outputPath) async {
    try {
      // 使用最简化的H.264压缩命令，专注于最大设备兼容性
      final ultraSimpleCommand =
          '-i "$inputPath" -c:v libx264 -profile:v baseline -level 3.0 -preset superfast -b:v 1000k -maxrate 1200k -bufsize 2000k -vf scale=-2:720,format=yuv420p -c:a aac -b:a 64k -ar 44100 -f mp4 -movflags +faststart -y "$outputPath"';
      print('执行超简备用FFmpeg命令: $ultraSimpleCommand');

      final session = await FFmpegKit.execute(ultraSimpleCommand);
      final returnCode = await session.getReturnCode();

      print('超简备用命令执行完成，返回码: ${returnCode?.getValue()}');

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final outputStat = await outputFile.stat();
          print('超简备用压缩成功，输出文件大小: ${outputStat.size} bytes');
          return outputPath;
        }
      } else {
        print('超简备用压缩失败，返回码: ${returnCode?.getValue()}');

        final failStackTrace = await session.getFailStackTrace();
        final logOutput = await session.getLogsAsString();
        final allLogs = await session.getAllLogsAsString();

        if (failStackTrace != null && failStackTrace.isNotEmpty) {
          print('超简备用命令错误堆栈: $failStackTrace');
        }

        if (logOutput != null && logOutput.isNotEmpty) {
          print('超简备用命令FFmpeg日志: $logOutput');
        }

        if (allLogs != null && allLogs.isNotEmpty) {
          print('超简备用命令完整FFmpeg日志: $allLogs');
        }
      }
    } catch (e) {
      print('超简备用压缩过程中发生异常: $e');
    }

    return null;
  }

  /// 构建完全压缩模式的FFmpeg命令
  static String _buildFullCompressionCommand(
      String inputPath, String outputPath) {
    // 使用FFmpeg的scale filter，保持宽高比的同时限制最大分辨率
    // 适用于横向视频 (宽>高)：最大1280x720
    // 适用于纵向视频 (高>宽)：最大720x1280
    // 首先尝试使用H.264编码器，因为它更通用且兼容性更好
    return '-i "$inputPath" '
        // H.264 Baseline@L3.0（设备兼容优先）+ CRF 质量控制（无冲突）
        '-c:v libx264 -profile:v baseline -level 3.0 '
        '-crf 28 -preset medium '
        // 终极简化 scale：用 "w=1280:h=720:force_original_aspect_ratio=decrease" 替代条件表达式
        // 效果等价于原需求（横屏≤1280x720，竖屏≤720x1280），且 FFmpeg-Kit 100% 支持
        '-vf scale=w=1280:h=720:force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2:color=black,format=yuv420p '
        // 音频压缩参数（保持低比特率，避免反向压缩）
        '-c:a aac -ac 1 -ar 44100 -b:a 48k '
        '-f mp4 ' // 显式指定 MP4 容器（Android 必需）
        '-movflags +faststart -y "$outputPath"';
  }

  /// 构建原视频压缩模式的FFmpeg命令
  static String _buildOriginalCompressionCommand(
      String inputPath, String outputPath) {
    // 使用FFmpeg的scale filter，保持宽高比的同时限制最大分辨率
    // 适用于横向视频 (宽>高)：最大1920x1080
    // 适用于纵向视频 (高>宽)：最大1080x1920
    // 首先尝试使用H.264编码器，因为它更通用且兼容性更好
    return '-i "$inputPath" '
        // H.264 Main@L4.0（更广泛的设备兼容性）+ 码率控制
        '-c:v libx264 -profile:v main -level 4.0 '
        '-crf 23 -preset medium -b:v 8500k -maxrate 8500k -bufsize 17000k '
        // 横屏：max 1920x1080；竖屏：max 1080x1920（保持宽高比）
        '-vf scale=\'if(gt(iw,ih),min(iw,1920),min(iw,1080)):if(gt(iw,ih),min(ih,1080),min(ih,1920))\',format=yuv420p '
        '-force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2:color=black '
        // 音频参数不变
        '-c:a aac -ac 2 -ar 48000 -b:a 164k '
        '-f mp4 ' // 显式指定 MP4 容器（关键）
        '-movflags +faststart -y "$outputPath"';
  }

  /// 检查视频是否符合指定的兼容性标准
  ///
  /// [inputPath] - 输入视频路径
  /// [compressionMode] - 压缩模式 ('full' 或 'original')
  /// 返回视频是否已符合标准
  static Future<bool> checkCompatibility({
    required String inputPath,
    required String compressionMode,
  }) async {
    try {
      final inputFile = File(inputPath);
      if (!await inputFile.exists()) return false;

      final inputStat = await inputFile.stat();
      final fileSize = inputStat.size;
      final maxSize = compressionMode == 'full'
          ? 10 * 1024 * 1024
          : 50 * 1024 * 1024; // 10MB/50MB

      // 简单判断：文件大小小于阈值 → 无需压缩（模拟微信逻辑）
      return fileSize < maxSize;
    } catch (e) {
      return false;
    }
  }

  /// 微信一般压缩命令（核心优化：用FFmpeg滤镜动态判断横竖屏+限制分辨率）
  static String _buildWechatGeneralCommand(
      String inputPath, String outputPath) {
    // 关键：用FFmpeg的if函数动态判断横竖屏，避免提前解析视频信息
    // scale逻辑：横屏→max 1280x720，竖屏→max 720x1280，自动保持宽高比
    return '-i \'$inputPath\' '
        // 1. 编码配置：Main@L4.1（兼容+高效），简化参考帧和B帧
        '-c:v libx264 -profile:v main -level 4.1 '
        '-crf 24 -preset medium ' // 2. CRF从28→24（降低压缩强度，无马赛克）
        '-b:v 600000 -maxrate $_wechatGeneralVideoMaxBitrate -bufsize ${_wechatGeneralVideoMaxBitrate * 2} ' // 平均码率600kbps
        // 3. 编码参数简化：1个参考帧+0个B帧（对齐微信逻辑，减少模糊）
        '-x264-params ref=1:bframes=0:cabac=1 '
        // 4. 滤镜：对齐720P分辨率+强制YUV色彩空间（解决马赛克核心）
        '-vf "scale=min(iw,$_wechatGeneralMaxW):-2,format=yuv420p,pad=ceil(iw/2)*2:ceil(ih/2)*2:color=black" '
        // 5. 音频：96k立体声（对齐微信，提升体验）
        '-c:a aac -ac 2 -ar 44100 -b:a ${_wechatGeneralAudioBitrate} '
        '-r 29.94 ' // 6. 帧率对齐微信29.94fps（更流畅）
        '-f mp4 -movflags +faststart -y \'$outputPath\'';
  }

  /// 微信原画压缩命令（宽松限制，保画质）
  static String _buildWechatOriginalCommand(
      String inputPath, String outputPath) {
    return '-i \'$inputPath\' '
        '-c:v libx264 -profile:v main -level 4.0 '
        '-crf 28 -preset medium '
        '-maxrate $_wechatOriginalVideoMaxBitrate -bufsize ${_wechatOriginalVideoMaxBitrate * 2} '
        // Simplified filter chain with safer syntax
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
      String inputPath, String outputPath, String mode) async {
    try {
      String fallbackCommand;
      if (mode == 'full') {
        fallbackCommand = '-i \'$inputPath\' '
            '-c:v libx264 -profile:v main -level 4.0 '
            '-crf 26 -preset faster '
            '-b:v 500000 -maxrate 1000000 '
            '-x264-params ref=1:bframes=0 '
            '-vf "scale=min(iw,$_wechatGeneralMaxW):-2,format=yuv420p" '
            '-c:a aac -ac 2 -ar 44100 -b:a 80000 '
            '-r 29.94 '
            '-f mp4 -movflags +faststart -y \'$outputPath\'';
      } else {
        fallbackCommand = '-i \'$inputPath\' '
            '-c:v libx264 -profile:v main -level 4.0 '
            '-crf 30 -preset medium '
            '-c:a aac -ac 2 -ar 44100 -b:a 96000 '
            '-vf "format=yuv420p" '
            '-f mp4 -movflags +faststart -y \'$outputPath\'';
      }

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
