import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class StorageUtils {
  // SoonwinFiles根目录
  static late String _rootDirectory;

  // 目录名称
  static const String _rootDirName = 'SoonwinFiles';
  static const String _videosDirName = 'Videos';
  static const String _thumbnailsDirName = 'Thumbnails';
  static const String _tempDirName = 'Temp';

  // 初始化存储目录
  static Future<void> init() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android平台：请求存储权限后访问外部存储
      try {
        // 请求存储权限
        final status = await Permission.manageExternalStorage.request();
        if (status.isGranted) {
          // 权限被授予，使用外部存储
          final externalStorageDir = await getExternalStorageDirectory();
          if (externalStorageDir != null) {
            _rootDirectory =
                p.join('/storage/emulated/0', _rootDirName); // 在外部存储根目录创建
            await Directory(_rootDirectory).create(recursive: true);
            print('使用外部存储根目录: $_rootDirectory');
          } else {
            // 使用应用专属外部存储目录（始终可访问）
            final externalDir = await getApplicationDocumentsDirectory();
            _rootDirectory = p.join(externalDir.path, _rootDirName);
            await Directory(_rootDirectory).create(recursive: true);
            print('使用应用外部存储目录: $_rootDirectory');
          }
        } else {
          // 权限被拒绝，使用应用专属外部存储目录（始终可访问）
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            _rootDirectory = p.join(externalDir.path, _rootDirName);
            await Directory(_rootDirectory).create(recursive: true);
            print('使用应用外部存储目录 (无MANAGE_EXTERNAL_STORAGE权限): $_rootDirectory');
          } else {
            // 回退到应用文档目录
            final appDir = await getApplicationDocumentsDirectory();
            _rootDirectory = p.join(appDir.path, _rootDirName);
            await Directory(_rootDirectory).create(recursive: true);
            print('使用应用文档目录: $_rootDirectory');
          }
        }
      } catch (e) {
        print('外部存储访问失败: $e');
        // 如果外部存储访问失败，使用应用文档目录
        final appDir = await getApplicationDocumentsDirectory();
        _rootDirectory = p.join(appDir.path, _rootDirName);
        await Directory(_rootDirectory).create(recursive: true);
        print('使用应用文档目录: $_rootDirectory');
      }
    } else {
      // 非Android平台（iOS, Windows, macOS, Linux等）：使用应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      _rootDirectory = p.join(appDir.path, _rootDirName);
      await Directory(_rootDirectory).create(recursive: true);
      print('使用应用文档目录: $_rootDirectory');
    }

    if (_rootDirectory != null && _rootDirectory.isNotEmpty) {
      print('存储根目录: $_rootDirectory');
    } else {
      throw Exception('无法创建根目录');
    }
  }

  // 获取根目录路径
  static String getRootDirectory() {
    if (!_isInitialized()) {
      throw Exception('StorageUtils未初始化，请先调用init()方法');
    }
    return _rootDirectory;
  }

  // 获取视频目录路径
  static String getVideosDirectory() {
    if (!_isInitialized()) {
      throw Exception('StorageUtils未初始化，请先调用init()方法');
    }
    final videosDir = p.join(_rootDirectory, _videosDirName);
    Directory(videosDir).createSync(recursive: true);
    return videosDir;
  }

  // 获取缩略图目录路径
  static String getThumbnailsDirectory() {
    if (!_isInitialized()) {
      throw Exception('StorageUtils未初始化，请先调用init()方法');
    }
    final thumbnailsDir = p.join(_rootDirectory, _thumbnailsDirName);
    Directory(thumbnailsDir).createSync(recursive: true);
    return thumbnailsDir;
  }

  // 获取临时目录路径
  static String getTempDirectory() {
    if (!_isInitialized()) {
      throw Exception('StorageUtils未初始化，请先调用init()方法');
    }
    final tempDir = p.join(_rootDirectory, _tempDirName);
    Directory(tempDir).createSync(recursive: true);
    return tempDir;
  }

  // 检查是否已初始化
  static bool _isInitialized() {
    return _rootDirectory != null && _rootDirectory.isNotEmpty;
  }
}
