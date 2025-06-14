import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../services/follow_up_service.dart';
import '../auth/login_screen.dart';
import 'admin_individual_map_screen.dart';
import 'admin_create_user_screen.dart';
import 'user_detail_screen.dart';
import '../auth/profile_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<User> _users = [];
  Set<int> _followedUserIds = {};
  int? _currentAdminId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
  }

  Future<void> _fetchAdminData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) {
        _logout();
        return;
      }

      final results = await Future.wait([
        UserService.getAllUsers(token),
        FollowUpService.getFollowing(token),
        UserService.getProfile(token),
      ]);

      if (mounted) {
        final allUsers = results[0] as List<User>;
        final followedUsers = results[1] as List<User>;
        final currentAdmin = results[2] as User;

        setState(() {
          _users = allUsers;
          _followedUserIds = followedUsers.map((u) => u.id).toSet();
          _currentAdminId = currentAdmin.id;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll("Exception: ", "");
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow(int userId, bool isCurrentlyFollowing) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || !mounted) return;

    setState(() {
      isCurrentlyFollowing
          ? _followedUserIds.remove(userId)
          : _followedUserIds.add(userId);
    });

    try {
      if (isCurrentlyFollowing) {
        await FollowUpService.unfollowUser(token, userId);
      } else {
        await FollowUpService.followUser(token, userId);
      }
    } catch (e) {
      setState(() {
        isCurrentlyFollowing
            ? _followedUserIds.add(userId)
            : _followedUserIds.remove(userId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll("Exception: ", "")),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  Future<void> _deleteUserWithConfirmation(User userToDelete) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Estás seguro de que quieres eliminar a ${userToDelete.name}? Esta acción no se puede deshacer.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null || !mounted) return;

      try {
        await UserService.deleteUser(token, userToDelete.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Usuario ${userToDelete.name} eliminado correctamente.'),
          backgroundColor: Colors.green,
        ));
        setState(() {
          _users.removeWhere((user) => user.id == userToDelete.id);
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll("Exception: ", "")),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _navigateToUserMap(User user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdminIndividualMapScreen(userToTrack: user),
      ),
    );
  }

  void _navigateToUserDetails(User user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AdminUserDetailScreen(user: user),
      ),
    );
  }

  void _navigateToCreateUser() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AdminCreateUserScreen()),
    );
    if (result == true) {
      _fetchAdminData();
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        actions: [
          // <<<--- 2. AÑADIMOS EL BOTÓN DE PERFIL AQUÍ ---
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            tooltip: 'Mi Perfil',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Error al cargar datos: $_errorMessage")))
          : RefreshIndicator(
        onRefresh: _fetchAdminData,
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: _users.length,
          itemBuilder: (context, index) {
            final user = _users[index];
            final isFollowing = _followedUserIds.contains(user.id);
            final canBeFollowed = user.role == 'LOCATION';
            final canBeDeleted = user.id != _currentAdminId;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _navigateToUserDetails(user),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blueAccent.withOpacity(0.2),
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${user.email} - Rol: ${user.role}",
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canBeFollowed) ...[
                            if (isFollowing)
                              IconButton(
                                icon: const Icon(Icons.map_outlined, color: Colors.green),
                                onPressed: () => _navigateToUserMap(user),
                                tooltip: 'Ver en Mapa',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ElevatedButton(
                              onPressed: () => _toggleFollow(user.id, isFollowing),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing ? Colors.grey[700] : Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              child: Text(isFollowing ? 'Siguiendo' : 'Seguir'),
                            ),
                          ],
                          if (canBeDeleted)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteUserWithConfirmation(user),
                              tooltip: 'Eliminar Usuario',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateUser,
        tooltip: 'Crear Usuario',
        child: const Icon(Icons.add),
      ),
    );
  }
}
