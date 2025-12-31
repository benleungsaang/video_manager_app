import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:crypto/crypto.dart';
import 'dart:math';
import '../models/user.dart';

class UserService {
  static const String _boxName = 'users';

  late Box<User> _box;

  Future<void> init() async {
    // 如果没有注册适配器，需要先注册
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(UserAdapter());
    }
    
    try {
      // Get the box that should have been opened by HiveService
      _box = Hive.box<User>(_boxName);
    } catch (e) {
      print('Error getting users box: $e');
      print('Attempting to open the users box...');
      
      try {
        _box = await Hive.openBox<User>(_boxName);
        print('Successfully opened users box');
      } catch (openError) {
        print('Error opening users box: $openError');
        rethrow;
      }
    }
  }

  // 创建用户
  Future<User> createUser(String username, String role) async {
    // 检查用户是否已存在
    final existingUser = await getUserByUsername(username);
    if (existingUser != null) {
      throw Exception('用户名已存在');
    }

    final user = User(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      username: username,
      role: role == 'admin' ? 'admin' : 'user', // 默认为普通用户
      totpSecret: null,
      pendingSecret: null,
      status: 'pending_activation', // 等待激活
      createdAt: DateTime.now(),
      lastLoginAt: null,
      sessions: [],
    );

    await _box.add(user);
    return user;
  }

  // 获取用户通过用户名
  Future<User?> getUserByUsername(String username) async {
    for (final user in _box.values) {
      if (user.username == username) {
        return user;
      }
    }
    return null;
  }

  // 获取用户通过ID
  Future<User?> getUserById(String id) async {
    for (final user in _box.values) {
      if (user.id == id) {
        return user;
      }
    }
    return null;
  }

  // 获取所有用户
  Future<List<User>> getAllUsers() async {
    return _box.values.toList();
  }

    // 生成TOTP密钥并更新用户状态（用于绑定或重置）
    Future<String> generateTotpSecret(String username, {bool isReset = false}) async {
      final user = await getUserByUsername(username);
      if (user == null) {
        throw Exception('用户不存在');
      }
  
      // 生成新的TOTP密钥 (使用随机字符串作为密钥)
      final secret = _generateRandomSecret();
      
      // 根据角色和操作类型处理
      if (user.role == 'admin' && !isReset) {
        // 管理员首次绑定，直接激活
        user.totpSecret = secret;
        user.status = 'active';
      } else {
        // 普通用户或重置操作，设置为待审核状态
        user.pendingSecret = secret;
        if (isReset) {
          user.status = 'pending_reset';
        } else {
          user.status = 'pending_approval';
        }
      }
      
      await user.save();
      
      return secret;
    }
  
    // 生成随机密钥
    String _generateRandomSecret() {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
      final random = Random.secure();
      return String.fromCharCodes(
        Iterable.generate(32, (_) => chars.codeUnitAt(random.nextInt(chars.length))),
      );
    }
    
              // 验证TOTP码
    
              Future<bool> verifyTotpCode(String username, String code) async {
    
                final user = await getUserByUsername(username);
    
                if (user == null) {
    
                  return false;
    
                }
    
            
    
                // 使用待处理的密钥（绑定/重置）或已激活的密钥进行验证
    
                final secret = user.pendingSecret ?? user.totpSecret;
    
                if (secret == null) {
    
                  return false;
    
                }
    
            
    
                try {
    
                  // 手动验证TOTP码
    
                  final isValid = _validateTotp(secret, code);
    
            
    
                  if (isValid) {
    
                    // 验证成功后，如果是待激活状态，根据角色处理
    
                    if (user.status == 'pending_activation' && user.pendingSecret != null) {
    
                      // 这种情况不应该发生，因为pending_activation没有pendingSecret
    
                      // 如果有pendingSecret，应该是pending_approval或pending_reset
    
                      if (user.role == 'admin') {
    
                        // 管理员绑定验证通过，直接激活
    
                        user.totpSecret = user.pendingSecret;
    
                        user.pendingSecret = null;
    
                        user.status = 'active';
    
                      } else {
    
                        // 普通用户，设置为待审批状态
    
                        user.totpSecret = user.pendingSecret;
    
                        user.pendingSecret = null;
    
                        user.status = 'pending_approval';
    
                      }
    
                    } else if (user.status == 'pending_approval' && user.pendingSecret != null) {
    
                      // 普通用户绑定验证通过，但需要审批才能激活
    
                      // 这里只是验证绑定过程，实际激活需要审批流程
    
                      user.totpSecret = user.pendingSecret;
    
                      user.pendingSecret = null;
    
                      user.status = 'pending_approval';
    
                    } else if (user.status == 'pending_reset' && user.pendingSecret != null) {
    
                      // 重置验证通过
    
                      if (user.role == 'admin') {
    
                        // 管理员重置，立即生效
    
                        user.totpSecret = user.pendingSecret;
    
                        user.pendingSecret = null;
    
                        user.status = 'active';
    
                      } else {
    
                        // 普通用户重置，需要审批
    
                        user.totpSecret = user.pendingSecret;
    
                        user.pendingSecret = null;
    
                        user.status = 'pending_reset';
    
                      }
    
                    }
    
                    await user.save();
    
                  }
    
            
    
                  return isValid;
    
                } catch (e) {
    
                  print('TOTP验证错误: $e');
    
                  return false;
    
                }
    
              }
    
              
    
              // 手动验证TOTP码
    
              bool _validateTotp(String secret, String code) {
    
                // 将base32编码的密钥转换为字节
    
                final keyBytes = _base32Decode(secret);
    
                
    
                // 检查当前时间窗口和前后各一个时间窗口
    
                final now = DateTime.now();
    
                final time = now.millisecondsSinceEpoch ~/ 1000;
    
                final period = 30;
    
                
    
                // 当前时间窗口
    
                final current = _generateTotpCode(keyBytes, time ~/ period);
    
                if (current == code) return true;
    
                
    
                // 前一个时间窗口
    
                final previous = _generateTotpCode(keyBytes, (time - period) ~/ period);
    
                if (previous == code) return true;
    
                
    
                // 后一个时间窗口
    
                final next = _generateTotpCode(keyBytes, (time + period) ~/ period);
    
                if (next == code) return true;
    
                
    
                return false;
    
              }
    
              
    
              // 生成TOTP码
    
              String _generateTotpCode(List<int> key, int counter) {
    
                // 将counter转换为字节数组（大端序）
    
                final counterBytes = <int>[
    
                  0, 0, 0, 0,  // 前4个字节为0
    
                  (counter >> 24) & 0xFF,
    
                  (counter >> 16) & 0xFF,
    
                  (counter >> 8) & 0xFF,
    
                  counter & 0xFF,
    
                ];
    
                
    
                // 使用HMAC-SHA1计算
    
                final hmac = Hmac(sha1, key);
    
                final digest = hmac.convert(counterBytes);
    
                final hash = digest.bytes;
    
                
    
                // 动态截断
    
                final offset = hash[19] & 0xf;
    
                final binary = ((hash[offset] & 0x7f) << 24) |
    
                              ((hash[offset + 1] & 0xff) << 16) |
    
                              ((hash[offset + 2] & 0xff) << 8) |
    
                              (hash[offset + 3] & 0xff);
    
                
    
                // 取模生成6位数字
    
                final otp = binary % 1000000;
    
                
    
                // 确保是6位数字，不足前补0
    
                return otp.toString().padLeft(6, '0');
    
              }
    
              
    
              // Base32解码
    
              List<int> _base32Decode(String input) {
    
                // 移除填充字符
    
                input = input.toUpperCase().replaceAll('=', '');
    
                
    
                // Base32字符映射
    
                const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    
                final bits = <int>[];
    
                
    
                for (int i = 0; i < input.length; i++) {
    
                  final char = input[i];
    
                  final index = alphabet.indexOf(char);
    
                  if (index == -1) {
    
                    throw FormatException('Invalid base32 character: $char');
    
                  }
    
                  
    
                  // 将5位数字添加到bits列表
    
                  for (int j = 4; j >= 0; j--) {
    
                    bits.add((index >> j) & 1);
    
                  }
    
                }
    
                
    
                // 将位转换为字节
    
                final result = <int>[];
    
                for (int i = 0; i < bits.length ~/ 8; i++) {
    
                  int byte = 0;
    
                  for (int j = 0; j < 8; j++) {
    
                    if (i * 8 + j < bits.length) {
    
                      byte = (byte << 1) | bits[i * 8 + j];
    
                    }
    
                  }
    
                  result.add(byte);
    
                }
    
                
    
                return result;
    
              }  // 审批用户（服务器端人工审批）
  Future<bool> approveUser(String username) async {
    final user = await getUserByUsername(username);
    if (user == null) {
      return false;
    }

    // 检查用户状态是否为待审批
    if (user.status == 'pending_approval') {
      // 审批通过，激活用户
      user.status = 'active';
      await user.save();
      return true;
    } else if (user.status == 'pending_reset') {
      // 重置审批通过，激活用户
      user.status = 'active';
      await user.save();
      return true;
    }

    return false;
  }

  // 拒绝用户审批
  Future<bool> rejectUser(String username) async {
    final user = await getUserByUsername(username);
    if (user == null) {
      return false;
    }

    // 检查用户状态是否为待审批
    if (user.status == 'pending_approval') {
      // 拒绝后，清除待处理的密钥
      user.pendingSecret = null;
      user.status = 'pending_activation'; // 回到待激活状态
      await user.save();
      return true;
    } else if (user.status == 'pending_reset') {
      // 重置审批拒绝，清除待处理的密钥
      user.pendingSecret = null;
      user.status = 'active'; // 保持活跃状态，只是不更新密钥
      await user.save();
      return true;
    }

    return false;
  }

  // 普通登录验证（验证TOTP码）
  Future<bool> authenticateUser(String username, String code) async {
    final user = await getUserByUsername(username);
    if (user == null || user.totpSecret == null || user.status != 'active') {
      return false;
    }

    try {
      // 手动验证TOTP码
      final isValid = _validateTotp(user.totpSecret!, code);

      if (isValid) {
        // 更新最后登录时间
        user.lastLoginAt = DateTime.now();
        await user.save();
      }

      return isValid;
    } catch (e) {
      print('TOTP验证错误: $e');
      return false;
    }
  }

  // 创建会话
  Future<String> createSession(String username) async {
    final user = await getUserByUsername(username);
    if (user == null) {
      throw Exception('用户不存在');
    }

    // 生成会话ID（使用时间戳+用户名的哈希）
    final sessionId = sha256.convert(utf8.encode('${username}_${DateTime.now().millisecondsSinceEpoch}')).toString();
    
    user.sessions.add(sessionId);
    await user.save();
    
    return sessionId;
  }

  // 验证会话
  Future<bool> validateSession(String sessionId) async {
    for (final user in _box.values) {
      if (user.sessions.contains(sessionId)) {
        return true;
      }
    }
    return false;
  }

  // 登出（删除会话）
  Future<void> logout(String sessionId) async {
    for (final user in _box.values) {
      if (user.sessions.contains(sessionId)) {
        user.sessions.remove(sessionId);
        await user.save();
        break;
      }
    }
  }

  // 获取待审批用户列表
  Future<List<User>> getPendingApprovalUsers() async {
    return _box.values
        .where((user) => user.status == 'pending_approval' || user.status == 'pending_reset')
        .toList();
  }

  // 关闭Hive box
  Future<void> close() async {
    if (_box.isOpen) {
      await _box.close();
    }
  }
}