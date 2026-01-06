import 'package:hive/hive.dart';
import '../models/video.dart';
import '../models/tag.dart';
import '../models/machine.dart';
import '../models/cart_item.dart';
import '../models/part.dart';
import '../models/temp_fee.dart';
import '../models/temp_factor.dart';
import '../models/user.dart';
import '../models/quotation.dart';
import '../models/price_calculator_adapters.dart';
import '../utils/storage_utils.dart'; // 新增导入

// Temporary adapter for typeId 47 to handle old data
class Type47Adapter extends TypeAdapter {
  @override
  final int typeId = 47;

  @override
  void write(BinaryWriter writer, dynamic obj) {
    // Write nothing - this is just a placeholder to handle old data
    writer.writeByte(0); // Write 0 fields
  }

  @override
  dynamic read(BinaryReader reader) {
    // Read the number of fields
    final numOfFields = reader.readByte();

    // Skip all field keys and values to handle old data gracefully
    for (int i = 0; i < numOfFields; i++) {
      try {
        reader.readByte(); // Skip field key
        reader.read(); // Skip field value
      } catch (e) {
        // If there's an error reading, return null to avoid crashing
        break;
      }
    }
    return null; // Return null for old data that we no longer need
  }
}

class HiveService {
  // 箱名定义
  static const String _videoBox = 'videos';
  static const String _tagBox = 'tags';
  static const String _machinesBox = 'machines';
  static const String _cartItemsBox = 'cart_items';
  static const String _tempPartsBox = 'temp_parts';
  static const String _tempFeesBox = 'temp_fees';
  static const String _tempFactorsBox = 'temp_factors';
  static const String _usersBox = 'users'; // Adding users box
  static const String _quotationsBox = 'quotations'; // Adding quotations box

  // 初始化数据库
  static Future<void> init() async {
    // 获取新的存储位置
    final rootDir = StorageUtils.getRootDirectory();
    Hive.init(rootDir);

    // 检查是否需要重置数据库（处理typeId冲突）
    await _checkAndResetDatabaseIfNeeded();

    // 注册适配器 - 只确保每个适配器只注册一次
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(VideoAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TagAdapter());
    if (!Hive.isAdapterRegistered(6)) Hive.registerAdapter(QuotationAdapter());
    if (!Hive.isAdapterRegistered(15))
      Hive.registerAdapter(UserAdapter()); // User adapter now has typeId 15
    registerPriceCalculatorAdapters(); // This registers Machine, CartItem, Part, TempFee, TempFactor adapters

    // Register temporary adapter for typeId 47 to handle old data
    if (!Hive.isAdapterRegistered(47)) {
      Hive.registerAdapter(Type47Adapter());
    }

    // 注释掉清理旧数据框的代码，避免意外删除用户数据
    // 清理旧的temp_fees和temp_factors数据，由于模型改变导致不兼容
    // try {
    //   await Hive.deleteBoxFromDisk(_tempFeesBox); // 删除旧的不兼容费用数据
    // } catch (e) {
    //   print('删除舊的temp_fees数据失败(可能不存在): $e');
    // }

    // try {
    //   await Hive.deleteBoxFromDisk(_tempFactorsBox); // 删除旧的不兼容系数数据
    // } catch (e) {
    //   print('删除舊的temp_factors数据失败(可能不存在): $e');
    // }

    // try {
    //   await Hive.deleteBoxFromDisk(_quotationsBox); // 删除旧的不兼容系数数据
    // } catch (e) {
    //   print('删除舊的_quotationsBox数据失败(可能不存在): $e');
    // }

    // try {
    //   await Hive.deleteBoxFromDisk(_usersBox); // 删除旧的不兼容系数数据
    // } catch (e) {
    //   print('删除舊的_usersBox数据失败(可能不存在): $e');
    // }

    // 打开箱
    await Hive.openBox<Video>(_videoBox);
    await Hive.openBox<Tag>(_tagBox);
    await Hive.openBox<Machine>(_machinesBox);
    await Hive.openBox<CartItem>(_cartItemsBox);
    await Hive.openBox<Part>(_tempPartsBox);
    await Hive.openBox<TempFee>(_tempFeesBox);
    await Hive.openBox<TempFactor>(_tempFactorsBox);
    // Open users box as well since the error occurs when UserService.init() is called
    await Hive.openBox<User>(_usersBox);
    // Open quotations box
    await Hive.openBox<Quotation>(_quotationsBox);
  }

  // 检查并重置数据库（如果需要）
  static Future<void> _checkAndResetDatabaseIfNeeded() async {
    try {
      // 如果数据库已存在，为了处理typeId冲突，可能需要重置数据库
      // 在开发环境中，我们可以选择删除旧数据
      print('正在检查是否需要重置数据库以解决typeId冲突...');

      // 可以在这里添加检查逻辑，如果检测到typeId冲突，则重置数据库
      // 由于typeId冲突通常会在注册适配器时发生，我们先尝试重置
      // await Hive.deleteFromDisk(); // 开发环境重置数据库
      // print('数据库已重置以解决typeId冲突');
    } catch (e) {
      print('重置数据库时出错: $e');
    }
  }

  // 获取视频箱
  static Box<Video> get videoBox => Hive.box<Video>(_videoBox);

  // 获取标签箱
  static Box<Tag> get tagBox => Hive.box<Tag>(_tagBox);

  // 获取报价单箱
  static Box<Quotation> get quotationBox => Hive.box<Quotation>(_quotationsBox);

  // 关闭数据库
  static Future<void> close() async {
    await Hive.close();
  }
}
