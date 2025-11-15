import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video.dart';
import '../models/tag.dart';

class HiveService {
  // 箱名定义
  static const String _videoBox = 'videos';
  static const String _tagBox = 'tags';

  // 初始化数据库
  static Future<void> init() async {
    // 获取应用文档目录
    final appDocumentDir = await getApplicationDocumentsDirectory();
    Hive.init(appDocumentDir.path);

    // 注册适配器
    Hive.registerAdapter(VideoAdapter());
    Hive.registerAdapter(TagAdapter());

    // 打开箱
    await Hive.openBox<Video>(_videoBox);
    await Hive.openBox<Tag>(_tagBox);
  }

  // 获取视频箱
  static Box<Video> get videoBox => Hive.box<Video>(_videoBox);

  // 获取标签箱
  static Box<Tag> get tagBox => Hive.box<Tag>(_tagBox);

  // 关闭数据库
  static Future<void> close() async {
    await Hive.close();
  }
}
