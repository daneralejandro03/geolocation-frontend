import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/user_service.dart';
import '../models/user.dart';
import 'map_screen.dart';
import './user/admin_screen.dart';
import 'auth/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkSessionAndNavigate();
  }

  Future<void> _checkSessionAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null) {
      _goToLogin();
      return;
    }

    try {
      final User user = await UserService.getProfile(token);

      if (!mounted) return;

      if (user.role == 'LOCATION') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      } else if (user.role == 'ADMIN') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminScreen()),
        );
      } else {
        print("Rol desconocido: ${user.role}. Cerrando sesión.");
        await _logoutAndGoToLogin();
      }
    } catch (e) {

      print("Error al verificar sesión: $e");
      await _logoutAndGoToLogin();
    }
  }

  Future<void> _logoutAndGoToLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    _goToLogin();
  }

  void _goToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Verificando sesión..."),
          ],
        ),
      ),
    );
  }
}