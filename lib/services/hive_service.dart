import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video.dart';
import '../models/tag.dart';
import '../models/machine_part.dart';
import '../models/cart_item.dart';
import '../models/part.dart';
import '../models/temp_fee.dart';
import '../models/temp_factor.dart';
import '../models/price_calculator_adapters.dart';
import '../utils/storage_utils.dart'; // 新增导入

class HiveService {
  // 箱名定义
  static const String _videoBox = 'videos';
  static const String _tagBox = 'tags';
  static const String _machinePartsBox = 'machine_parts';
  static const String _cartItemsBox = 'cart_items';
  static const String _tempPartsBox = 'temp_parts';
  static const String _tempFeesBox = 'temp_fees';
  static const String _tempFactorsBox = 'temp_factors';

  // 初始化数据库
  static Future<void> init() async {
    // 获取新的存储位置
    final rootDir = StorageUtils.getRootDirectory();
    Hive.init(rootDir);

    // 注册适配器
    Hive.registerAdapter(VideoAdapter());
    Hive.registerAdapter(TagAdapter());
    registerPriceCalculatorAdapters();

    // 清理旧的temp_fees和temp_factors数据，由于模型改变导致不兼容
    try {
      await Hive.deleteBoxFromDisk(_tempFeesBox); // 删除旧的不兼容费用数据
    } catch (e) {
      print('删除旧的temp_fees数据失败(可能不存在): $e');
    }
    
    try {
      await Hive.deleteBoxFromDisk(_tempFactorsBox); // 删除旧的不兼容系数数据
    } catch (e) {
      print('删除旧的temp_factors数据失败(可能不存在): $e');
    }

    // 打开箱
    await Hive.openBox<Video>(_videoBox);
    await Hive.openBox<Tag>(_tagBox);
    await Hive.openBox<MachinePart>(_machinePartsBox);
    await Hive.openBox<CartItem>(_cartItemsBox);
    await Hive.openBox<Part>(_tempPartsBox);
    await Hive.openBox<TempFee>(_tempFeesBox);
    await Hive.openBox<TempFactor>(_tempFactorsBox);
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
