import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'user_service.dart';
import '../models/user.dart';

class UserApiHandler {
  final UserService _userService;

  UserApiHandler(this._userService);

  // 获取所有用户
  Future<Response> handleGetUsers(Request request) async {
    try {
      final users = await _userService.getAllUsers();
      final usersJson = users.map((user) => user.toJson()).toList();
      return Response.ok(
        json.encode({'success': true, 'data': usersJson}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取用户失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 创建用户
  Future<Response> handleCreateUser(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final username = params['username'] as String? ?? '';
      final role = params['role'] as String? ?? 'user';

      if (username.isEmpty) {
        return Response.badRequest(
          body: json.encode({'success': false, 'error': '用户名不能为空'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final user = await _userService.createUser(username, role);

      return Response.ok(
        json.encode({'success': true, 'data': user.toJson()}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('创建用户失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 生成TOTP密钥
  Future<Response> handleGenerateTotpSecret(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final username = params['username'] as String? ?? '';
      final isReset = params['isReset'] as bool? ?? false;

      if (username.isEmpty) {
        return Response.badRequest(
          body: json.encode({'success': false, 'error': '用户名不能为空'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final secret = await _userService.generateTotpSecret(username, isReset: isReset);

      // 生成otpauth URL用于二维码
      final issuer = '视频管理系统';
      final otpAuthUrl = 'otpauth://totp/$issuer:$username?secret=$secret&issuer=$issuer';

      return Response.ok(
        json.encode({
          'success': true, 
          'data': {
            'secret': secret,
            'otpAuthUrl': otpAuthUrl,
          }
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('生成TOTP密钥失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 验证TOTP码
  Future<Response> handleVerifyTotpCode(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final username = params['username'] as String? ?? '';
      final code = params['code'] as String? ?? '';

      if (username.isEmpty || code.isEmpty) {
        return Response.badRequest(
          body: json.encode({'success': false, 'error': '用户名和验证码不能为空'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final isValid = await _userService.verifyTotpCode(username, code);

      return Response.ok(
        json.encode({'success': true, 'data': {'isValid': isValid}}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('验证TOTP码失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 用户认证（登录）
  Future<Response> handleAuthenticateUser(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final username = params['username'] as String? ?? '';
      final code = params['code'] as String? ?? '';

      if (username.isEmpty || code.isEmpty) {
        return Response.badRequest(
          body: json.encode({'success': false, 'error': '用户名和验证码不能为空'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final isAuthenticated = await _userService.authenticateUser(username, code);

      if (isAuthenticated) {
        // 创建会话
        final sessionId = await _userService.createSession(username);
        return Response.ok(
          json.encode({
            'success': true, 
            'data': {
              'authenticated': true,
              'sessionId': sessionId,
            }
          }),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.ok(
          json.encode({
            'success': true, 
            'data': {'authenticated': false}
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('用户认证失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 获取待审批用户列表
  Future<Response> handleGetPendingApprovalUsers(Request request) async {
    try {
      final users = await _userService.getPendingApprovalUsers();
      final usersJson = users.map((user) => user.toJson()).toList();
      return Response.ok(
        json.encode({'success': true, 'data': usersJson}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      print('获取待审批用户失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 审批用户
  Future<Response> handleApproveUser(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final username = params['username'] as String? ?? '';

      if (username.isEmpty) {
        return Response.badRequest(
          body: json.encode({'success': false, 'error': '用户名不能为空'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final success = await _userService.approveUser(username);

      if (success) {
        return Response.ok(
          json.encode({'success': true, 'message': '用户审批通过'}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.badRequest(
          body: json.encode({'success': false, 'error': '用户审批失败或用户状态不正确'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('审批用户失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  // 拒绝用户审批
  Future<Response> handleRejectUser(Request request) async {
    try {
      final body = await request.readAsString();
      final params = json.decode(body);

      final username = params['username'] as String? ?? '';

      if (username.isEmpty) {
        return Response.badRequest(
          body: json.encode({'success': false, 'error': '用户名不能为空'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final success = await _userService.rejectUser(username);

      if (success) {
        return Response.ok(
          json.encode({'success': true, 'message': '用户审批已拒绝'}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.badRequest(
          body: json.encode({'success': false, 'error': '用户拒绝审批失败或用户状态不正确'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('拒绝用户审批失败: $e');
      return Response.internalServerError(
        body: json.encode({'success': false, 'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}