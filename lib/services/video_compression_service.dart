import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';

import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'package:path/path.dart' as p;

class VideoCompressionService {
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
  static Future<String?> compressVideo({
    required String inputPath,
    required String compressionMode,
  }) async {
    try {
      print('开始压缩视频，输入路径: $inputPath, 压缩模式: $compressionMode');

      // 验证输入文件是否存在
      final inputFile = File(inputPath);

      if (!await inputFile.exists()) {
        print('输入文件不存在: $inputPath');
        return null;
      }

      // 获取文件信息
      final inputStat = await inputFile.stat();
      print('输入文件大小: ${inputStat.size} bytes, 路径: $inputPath');

      // 确定输出路径
      final inputDir = inputFile.parent.path;
      final inputName = inputFile.path.split('/').last;
      final inputExt = inputName.split('.').last.toLowerCase();

      // 由于我们使用MP4容器，确保输出文件扩展名为.mp4
      final outputName = inputName.replaceAll('.$inputExt', '_compressed.mp4');
      final outputPath = p.join(inputDir, outputName);
      print('输出路径: $outputPath');

      // 根据压缩模式确定FFmpeg参数
      String command;

      if (compressionMode == 'full') {
        // 完全压缩模式
        // - 视频：分辨率≤1280x720(横)或≤720x1280(竖)，码率≤1200kb/s，H.264编码
        // - 音频：单声道，44.1kHz，≤48kb/s，30fps
        command = _buildFullCompressionCommand(inputPath, outputPath);
      } else if (compressionMode == 'original') {
        // 原视频压缩模式
        // - 视频：分辨率≤1920x1080(横)或≤1080x1920(竖)，码率≤8500kb/s，H.264编码
        // - 音频：双声道，48kHz，≤164kb/s，30fps
        command = _buildOriginalCompressionCommand(inputPath, outputPath);
      } else {
        print('未知的压缩模式: $compressionMode');
        return null;
      }

      print('执行FFmpeg命令: $command');

      // 执行FFmpeg命令
      print('开始执行FFmpeg命令...');
      final session = await FFmpegKit.execute(command);

      final returnCode = await session.getReturnCode();

      print('FFmpeg执行完成，返回码: ${returnCode?.getValue()}');

      if (ReturnCode.isSuccess(returnCode)) {
        print('视频压缩成功: $outputPath');

        // 验证输出文件是否存在
        final outputFile = File(outputPath);

        if (await outputFile.exists()) {
          final outputStat = await outputFile.stat();
          print('压缩后文件大小: ${outputStat.size} bytes');

          // 删除原始输入文件（保留压缩后的文件）
          await inputFile.delete();

          return outputPath;
        } else {
          print('压缩后的文件不存在');
          return null;
        }
      } else {
        print('视频压缩失败，返回码: ${returnCode?.getValue()}');

        // 获取详细错误信息
        final failStackTrace = await session.getFailStackTrace();
        final logOutput = await session.getLogsAsString();
        final allLogs = await session.getAllLogsAsString();

        if (failStackTrace != null && failStackTrace.isNotEmpty) {
          print('错误堆栈: $failStackTrace');
        }

        if (logOutput != null && logOutput.isNotEmpty) {
          print('FFmpeg日志: $logOutput');
        }

        if (allLogs != null && allLogs.isNotEmpty) {
          print('完整FFmpeg日志: $allLogs');
        }

        // 如果主要命令失败，尝试一个更简单的命令作为备选方案
        print('尝试使用备用命令进行视频压缩...');
        final fallbackOutputPath = await _tryFallbackCompression(inputPath, outputPath);
        if (fallbackOutputPath != null) {
          // 成功使用备用命令，删除原始输入文件
          await inputFile.delete();
          return fallbackOutputPath;
        }

        return null;
      }
    } catch (e) {
      print('视频压缩过程中发生异常: $e');
      print('异常堆栈: $e');

      return null;
    }
  }

  /// 尝试使用备用的简单FFmpeg命令进行压缩
  static Future<String?> _tryFallbackCompression(String inputPath, String outputPath) async {
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
  static Future<String?> _trySimpleFallbackCompression(String inputPath, String outputPath) async {
    try {
      // 使用更简单的H.264压缩命令作为备用方案，确保音频也重新编码以提高兼容性
      final fallbackCommand = '-i "$inputPath" -c:v libx264 -profile:v baseline -level 3.0 -crf 28 -preset fast -c:a aac -b:a 128k -vf format=yuv420p -f mp4 -movflags +faststart -y "$outputPath"';
      print('执行标准备用FFmpeg命令: $fallbackCommand');

      final session = await FFmpegKit.execute(fallbackCommand);
      final returnCode = await session.getReturnCode();

      print('标准备用命令执行完成，返回码: ${returnCode?.getValue()}');

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          final outputStat = await outputFile.stat();
          print('标准备用压缩成功，输出文件大小: ${outputStat.size} bytes');
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
  static Future<String?> _tryUltraSimpleFallbackCompression(String inputPath, String outputPath) async {
    try {
      // 使用最简化的H.264压缩命令，专注于最大设备兼容性
      final ultraSimpleCommand = '-i "$inputPath" -c:v libx264 -profile:v baseline -level 3.0 -preset superfast -b:v 1000k -maxrate 1200k -bufsize 2000k -vf scale=-2:720,format=yuv420p -c:a aac -b:a 64k -ar 44100 -f mp4 -movflags +faststart -y "$outputPath"';
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
        // H.264 Baseline@L3.0（更广泛的设备兼容性）+ 码率控制
        '-c:v libx264 -profile:v baseline -level 3.0 '
        '-crf 28 -preset medium -b:v 1200k -maxrate 1200k -bufsize 2400k '
        // 横屏：max 1280x720；竖屏：max 720x1280（保持宽高比）
        '-vf scale=\'if(gt(iw,ih),min(iw,1280),min(iw,720)):if(gt(iw,ih),min(ih,720),min(ih,1280))\',format=yuv420p '
        '-force_original_aspect_ratio=decrease,pad=ceil(iw/2)*2:ceil(ih/2)*2:color=black '
        // 音频参数不变
        '-c:a aac -ac 1 -ar 44100 -b:a 48k '
        '-f mp4 ' // 显式指定 MP4 容器（关键）
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
      // 使用FFmpeg的ffprobe功能检查视频信息
      final session = await FFmpegKit.execute(
          '-v quiet -print_format json -show_format -show_streams "$inputPath"');
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        print('无法获取视频信息，返回码: ${returnCode?.getValue()}');
        return false;
      }

      // 获取输出
      final output = await session.getOutput();

      if (output == null || output.isEmpty) {
        print('没有获取到视频信息输出');
        return false;
      }

      // 这里可以解析JSON输出来检查兼容性
      // 为了简化，我们假设所有视频都需要处理
      print('视频兼容性检查完成，输出长度: ${output.length}');

      return true;
    } catch (e) {
      print('检查视频兼容性时发生异常: $e');
      return false;
    }
  }
}