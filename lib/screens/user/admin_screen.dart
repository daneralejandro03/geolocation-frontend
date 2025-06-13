import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user.dart';
import '../../services/user_service.dart';
import '../../services/follow_up_service.dart';
import '../auth/login_screen.dart';
import 'admin_individual_map_screen.dart';
import 'admin_create_user_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<User> _locationUsers = [];
  Set<int> _followedUserIds = {};
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

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      _logout();
      return;
    }

    try {
      final usersFuture = UserService.getAllUsers(token);
      final followingFuture = FollowUpService.getFollowing(token);

      final results = await Future.wait([usersFuture, followingFuture]);

      final allUsers = results[0] as List<User>;
      final followedUsers = results[1] as List<User>;

      if (mounted) {
        setState(() {
          _locationUsers = allUsers;
          _followedUserIds = followedUsers.map((u) => u.id).toSet();
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
    if (token == null) return;

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
          content: Text("Error: ${e.toString().replaceAll("Exception: ", "")}"),
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
          itemCount: _locationUsers.length,
          itemBuilder: (context, index) {
            final user = _locationUsers[index];
            final isFollowing = _followedUserIds.contains(user.id);
            final canBeFollowed = user.role == 'LOCATION';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(user.name.isNotEmpty ? user.name[0] : '?'),
                ),
                title: Text(user.name),
                subtitle: Text("${user.email} - Rol: ${user.role}"),
                trailing: canBeFollowed ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isFollowing)
                      IconButton(
                        icon: const Icon(Icons.map, color: Colors.green),
                        onPressed: () => _navigateToUserMap(user),
                        tooltip: 'Ver en Mapa',
                      ),
                    ElevatedButton(
                      onPressed: () => _toggleFollow(user.id, isFollowing),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFollowing ? Colors.grey[700] : Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: Text(isFollowing ? 'Siguiendo' : 'Seguir'),
                    ),
                  ],
                ) : null,
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
