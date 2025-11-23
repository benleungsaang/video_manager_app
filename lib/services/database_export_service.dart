import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:video_manager_app/models/video.dart';
import 'package:video_manager_app/models/tag.dart';
import 'package:video_manager_app/repositories/video_repository.dart';
import 'package:video_manager_app/repositories/tag_repository.dart';
import 'package:video_manager_app/services/hive_service.dart';
import 'package:video_manager_app/utils/storage_utils.dart'; // 新增导入

class DatabaseExportService {
  final VideoRepository _videoRepository;
  final TagRepository _tagRepository;

  DatabaseExportService(this._videoRepository, this._tagRepository);

  // 导出数据库到JSON文件
  Future<String> exportDatabase() async {
    try {
      // 获取所有视频和标签数据
      final videos = _videoRepository.getAllVideos();
      final tags = _tagRepository.getAllTags();

      // 将数据转换为Map格式
      final exportData = {
        'videos': videos.map((video) => _videoToMap(video)).toList(),
        'tags': tags.map((tag) => _tagToMap(tag)).toList(),
        'exportDate': DateTime.now().toIso8601String(),
      };

      // 转换为JSON字符串
      final jsonString = jsonEncode(exportData, toEncodable: _dateEncoder);

      return jsonString;
    } catch (e) {
      throw Exception('导出数据库失败: $e');
    }
  }

  // 导出数据库到文件
  Future<String> exportDatabaseToFile() async {
    final jsonString = await exportDatabase();
    
    // 获取根目录（与videos、temp等目录同级）
    final rootDir = StorageUtils.getRootDirectory();
    final exportDir = Directory('$rootDir/exports');
    
    // 创建导出目录（如果不存在）
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    
    // 生成文件名（包含时间戳）
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${exportDir.path}/video_manager_export_$timestamp.json');
    
    // 写入文件
    await file.writeAsString(jsonString);
    
    return file.path;
  }

  // 将Video对象转换为Map
  Map<String, dynamic> _videoToMap(Video video) {
    return {
      'id': video.id,
      'title': video.title,
      'filePath': video.filePath,
      'fileSize': video.fileSize,
      'tagIds': video.tagIds,
      'remark': video.remark,
      'uploadTime': video.uploadTime.toIso8601String(),
      'duration': video.duration,
      'thumbnailPath': video.thumbnailPath,
    };
  }

  // 将Tag对象转换为Map
  Map<String, dynamic> _tagToMap(Tag tag) {
    return {
      'id': tag.id,
      'name': tag.name,
      'videoCount': tag.videoCount,
    };
  }

  // 使用自定义编码器处理DateTime
  dynamic _dateEncoder(dynamic object) {
    if (object is DateTime) {
      return object.toIso8601String();
    }
    return object;
  }

  // 从JSON导入数据库
  Future<void> importDatabaseFromJson(String jsonString) async {
    try {
      final data = jsonDecode(jsonString);
      
      if (data is! Map<String, dynamic>) {
        throw Exception('无效的JSON格式');
      }

      // 清空当前数据（可选，根据需求决定是否清空）
      await _clearDatabase();

      // 导入标签
      if (data['tags'] != null && data['tags'] is List) {
        final tagsData = List<Map<String, dynamic>>.from(
          data['tags'].map((tag) => Map<String, dynamic>.from(tag))
        );
        await _importTags(tagsData);
      }

      // 导入视频
      if (data['videos'] != null && data['videos'] is List) {
        final videosData = List<Map<String, dynamic>>.from(
          data['videos'].map((video) => Map<String, dynamic>.from(video))
        );
        await _importVideos(videosData);
      }
    } catch (e) {
      throw Exception('导入数据库失败: $e');
    }
  }

  // 从文件导入数据库
  Future<void> importDatabaseFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('文件不存在: $filePath');
    }
    
    final jsonString = await file.readAsString();
    await importDatabaseFromJson(jsonString);
  }

  // 导入标签数据
  Future<void> _importTags(List<Map<String, dynamic>> tagsData) async {
    for (final tagData in tagsData) {
      try {
        final tag = Tag(
          id: tagData['id'] as String,
          name: tagData['name'] as String,
          videoCount: tagData['videoCount'] as int? ?? 0,
        );
        
        // 使用put方法直接保存，保留原始ID
        await HiveService.tagBox.put(tag.id, tag);
      } catch (e) {
        print('导入标签失败: $e, 数据: $tagData');
      }
    }
  }

  // 导入视频数据
  Future<void> _importVideos(List<Map<String, dynamic>> videosData) async {
    for (final videoData in videosData) {
      try {
        String filePath = videoData['filePath'] as String;
        
        // 检查文件是否存在于指定路径，如果不存在则尝试查找文件名
        final file = File(filePath);
        if (!await file.exists()) {
          // 尝试根据文件名在公共文档目录中查找
          final fileName = filePath.split('/').last;
          final newFilePath = await _findFileInDocuments(fileName);
          if (newFilePath != null) {
            filePath = newFilePath;
          } else {
            print('警告: 视频文件不存在于原始路径，且未在文档目录中找到: $filePath');
          }
        }
        
        final video = Video(
          id: videoData['id'] as String,
          title: videoData['title'] as String,
          filePath: filePath,
          fileSize: videoData['fileSize'] as int,
          tagIds: List<String>.from(videoData['tagIds'] ?? []),
          remark: videoData['remark'] as String? ?? '',
          uploadTime: DateTime.parse(videoData['uploadTime'] as String),
          duration: videoData['duration'] as int?,
          thumbnailPath: videoData['thumbnailPath'] as String?,
        );
        
        // 使用put方法直接保存，保留原始ID
        await HiveService.videoBox.put(video.id, video);
      } catch (e) {
        print('导入视频失败: $e, 数据: $videoData');
      }
    }
  }
  
  // 在根目录中查找文件
  Future<String?> _findFileInDocuments(String fileName) async {
    try {
      // 在根目录中查找文件（包括其子目录）
      final rootDirectory = StorageUtils.getRootDirectory();
      final dir = Directory(rootDirectory);
      
      if (await dir.exists()) {
        final files = dir.listSync(recursive: true);
        
        for (final entity in files) {
          if (entity is File) {
            final entityName = entity.path.split('/').last.split('\\').last;
            if (entityName == fileName) {
              return entity.path;
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('查找文件时出错: $e');
      return null;
    }
  }

  // 清空当前数据库
  Future<void> _clearDatabase() async {
    await HiveService.videoBox.clear();
    await HiveService.tagBox.clear();
  }

  // 验证导入的JSON格式
  bool validateJsonFormat(String jsonString) {
    try {
      final data = jsonDecode(jsonString);
      if (data is! Map<String, dynamic>) return false;
      
      // 检查是否包含必要的字段
      return data.containsKey('videos') && data.containsKey('tags');
    } catch (e) {
      return false;
    }
  }
}