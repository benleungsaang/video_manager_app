// 自动生成的 Hive 注册文件
import 'package:hive_flutter/hive_flutter.dart';
import 'machine.dart';
import 'cart_item.dart';
import 'part.dart';
import 'temp_fee.dart';
import 'temp_factor.dart';

/// 注册所有价格计算器相关的 Hive 类型
void registerPriceCalculatorAdapters() {
  Hive.registerAdapter(MachineAdapter());
  Hive.registerAdapter(CartItemAdapter());
  Hive.registerAdapter(PartAdapter());
  Hive.registerAdapter(TempFeeAdapter());
  Hive.registerAdapter(TempFactorAdapter());
}