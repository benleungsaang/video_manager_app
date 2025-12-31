import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final TextEditingController _usernameController = TextEditingController();
  UserService? _userService;

  @override
  void initState() {
    super.initState();
    // 获取UserService实例
    _userService = UserService();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // 刷新用户列表
  void _refreshUsers() {
    if (mounted) {
      setState(() {});
    }
  }



  // 审批用户
  Future<void> _approveUser(User user) async {
    if (_userService == null) {
      if (mounted) {
        _showErrorDialog('用户服务未初始化');
      }
      return;
    }

    try {
      final result = await _userService!.approveUser(user.username);
      if (result) {
        _refreshUsers();
        _showSuccessDialog('用户审批成功');
      } else {
        _showErrorDialog('审批失败：用户状态不正确');
      }
    } catch (e) {
      _showErrorDialog('审批失败: ${e.toString()}');
    }
  }

  // 拒绝用户审批
  Future<void> _rejectUser(User user) async {
    if (_userService == null) {
      if (mounted) {
        _showErrorDialog('用户服务未初始化');
      }
      return;
    }

    try {
      final result = await _userService!.rejectUser(user.username);
      if (result) {
        _refreshUsers();
        _showSuccessDialog('用户审批已拒绝');
      } else {
        _showErrorDialog('拒绝审批失败：用户状态不正确');
      }
    } catch (e) {
      _showErrorDialog('拒绝审批失败: ${e.toString()}');
    }
  }

  // 删除用户
  Future<void> _deleteUser(User user) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除用户 "${user.username}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // 在实际应用中，可能需要一个删除用户的方法
        // 这里暂时将用户状态改为disabled
        user.status = 'disabled';
        await user.save();
        _refreshUsers();
        _showSuccessDialog('用户已禁用');
      } catch (e) {
        _showErrorDialog('禁用用户失败: ${e.toString()}');
      }
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('错误'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  void _showSuccessDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('成功'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  // 初始化UserService并加载用户
  Future<List<User>> _initializeAndLoadUsers() async {
    if (_userService != null) {
      try {
        // 如果尚未初始化，则进行初始化
        await _userService!.init();
      } catch (e) {
        // 初始化失败，但继续执行
        // print('UserService初始化失败: $e');
      }
    }
    
    // 加载用户列表
    if (_userService != null) {
      return await _userService!.getAllUsers();
    } else {
      return [];
    }
  }

  // 异步创建用户处理方法
  void _createUserHandler(String username, String role, BuildContext dialogContext) {
    if (_userService == null) {
      if (mounted) {
        _showErrorDialog('用户服务未初始化');
      }
      return;
    }

    if (username.isEmpty) {
      if (mounted) {
        _showErrorDialog('用户名不能为空');
      }
      return;
    }

    // 使用异步操作创建用户
    _performCreateUser(username, role, dialogContext);
  }

  Future<void> _performCreateUser(String username, String role, BuildContext dialogContext) async {
    if (_userService == null) {
      if (mounted) {
        _showErrorDialog('用户服务未初始化');
      }
      return;
    }

    try {
      await _userService!.createUser(username, role);
      _refreshUsers();
      if (mounted) {
        Navigator.of(dialogContext).pop(); // 关闭对话框
      }
      // 使用延迟避免BuildContext问题
      await Future.delayed(Duration.zero);
      if (mounted) {
        _showSuccessDialog('用户创建成功');
      }
    } catch (e) {
      // 使用延迟避免BuildContext问题
      await Future.delayed(Duration.zero);
      if (mounted) {
        _showErrorDialog('创建用户失败: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户管理'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateUserDialog,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户列表标题
            const Text(
              '用户列表',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            // 用户列表
            Expanded(
              child: FutureBuilder<List<User>>(
                future: _initializeAndLoadUsers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return const Center(child: Text('加载用户列表失败'));
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('暂无用户'));
                  }
                  
                  final users = snapshot.data!;
                  final pendingUsers = users.where((user) => 
                      user.status == 'pending_approval' || 
                      user.status == 'pending_reset' || 
                      user.status == 'pending_activation').toList();
                  final activeUsers = users.where((user) => 
                      user.status != 'pending_approval' && 
                      user.status != 'pending_reset' && 
                      user.status != 'pending_activation' &&
                      user.status != 'disabled').toList();
                  final disabledUsers = users.where((user) => 
                      user.status == 'disabled').toList();
                  
                  return ListView(
                    children: [
                      // 待审批用户
                      if (pendingUsers.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '待审批用户',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...pendingUsers.map((user) => _buildUserCard(user, isPending: true)),
                        const Divider(height: 20),
                      ],
                      
                      // 活跃用户
                      if (activeUsers.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '活跃用户',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...activeUsers.map((user) => _buildUserCard(user, isPending: false)),
                        const Divider(height: 20),
                      ],
                      
                      // 禁用用户
                      if (disabledUsers.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '禁用用户',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...disabledUsers.map((user) => _buildUserCard(user, isPending: false)),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 显示创建用户对话框
  Future<void> _showCreateUserDialog() async {
    final usernameController = TextEditingController();
    String selectedRole = 'user'; // 默认角色

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('创建新用户'),
            content: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    autofocus: true, // 焦点自动落在用户名输入框
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      border: OutlineInputBorder(),
                      hintText: '输入新用户名',
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '选择角色',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  ToggleButtons(
                    isSelected: selectedRole == 'admin' ? [false, true] : [true, false],
                    onPressed: (index) {
                      setDialogState(() {
                        selectedRole = index == 0 ? 'user' : 'admin';
                      });
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('普通用户'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('管理员'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  _createUserHandler(usernameController.text.trim(), selectedRole, dialogContext);
                },
                child: const Text('创建'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserCard(User user, {required bool isPending}) {
    String statusText = _getStatusText(user.status);
    Color statusColor = _getStatusColor(user.status);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.username,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '角色: ${user.role}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '状态: $statusText',
                    style: TextStyle(fontSize: 14, color: statusColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '创建时间: ${_formatDateTime(user.createdAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  if (user.lastLoginAt != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '最后登录: ${_formatDateTime(user.lastLoginAt!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPending) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        tooltip: '批准',
                        onPressed: () => _approveUser(user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: '拒绝',
                        onPressed: () => _rejectUser(user),
                      ),
                    ],
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: '删除/禁用',
                  onPressed: () => _deleteUser(user),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending_activation':
        return '待激活';
      case 'pending_approval':
        return '待审批';
      case 'pending_reset':
        return '重置待审批';
      case 'active':
        return '活跃';
      case 'disabled':
        return '已禁用';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_activation':
      case 'pending_approval':
      case 'pending_reset':
        return Colors.orange;
      case 'active':
        return Colors.green;
      case 'disabled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}