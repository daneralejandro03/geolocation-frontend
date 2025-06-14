import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<User> _userProfileFuture;

  @override
  void initState() {
    super.initState();
    _userProfileFuture = _fetchUserProfile();
  }

  /// Obtiene el token y llama al servicio para traer el perfil del usuario.
  Future<User> _fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      // Si no hay token, se lanza un error para manejarlo en el FutureBuilder.
      throw Exception('No estás autenticado.');
    }
    return UserService.getProfile(token);
  }

  /// Cierra la sesión del usuario.
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    if (mounted) {
      // Navega a la pantalla de login y elimina todas las rutas anteriores.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  /// Muestra un diálogo modal para que el usuario cambie su contraseña.
  void _showChangePasswordDialog() {
    final formKey = GlobalKey<FormState>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;

    showDialog(
      context: context,
      barrierDismissible: !isLoading, // Evita cerrar el diálogo mientras carga
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {

            Future<void> handleChangePassword() async {
              if (formKey.currentState?.validate() ?? false) {
                setDialogState(() => isLoading = true);

                try {
                  final prefs = await SharedPreferences.getInstance();
                  final token = prefs.getString('jwt_token');
                  if (token == null) throw Exception("Sesión expirada.");

                  await UserService.changePassword(
                    token: token,
                    currentPassword: currentPasswordController.text,
                    newPassword: newPasswordController.text,
                  );

                  if (mounted) {
                    Navigator.of(dialogContext).pop(); // Cierra el diálogo
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Contraseña actualizada con éxito.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    // Muestra el error dentro del diálogo para no cerrarlo
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: ${e.toString().replaceAll("Exception: ", "")}"),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                } finally {
                  if(mounted) {
                    setDialogState(() => isLoading = false);
                  }
                }
              }
            }

            return AlertDialog(
              title: const Text('Cambiar Contraseña'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Contraseña Actual',
                          prefixIcon: const Icon(Icons.lock_clock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                          ),
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'Nueva Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                          ),
                        ),
                        validator: (value) => (value != null && value.length < 6) ? 'Mínimo 6 caracteres' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: obscureNew, // Usa la misma visibilidad que la nueva contraseña
                        decoration: const InputDecoration(
                          labelText: 'Confirmar Contraseña',
                          prefixIcon: Icon(Icons.lock_person_outlined),
                        ),
                        validator: (value) {
                          if (value != newPasswordController.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : handleChangePassword,
                  child: isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Actualizar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<User>(
        future: _userProfileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error al cargar el perfil: ${snapshot.error.toString().replaceAll("Exception: ", "")}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            );
          }
          if (snapshot.hasData) {
            final user = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 58,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildDetailRow(context, icon: Icons.tag, title: 'ID de Usuario', value: user.id.toString()),
                          const Divider(height: 24),
                          _buildDetailRow(context, icon: Icons.verified_user_outlined, title: 'Rol', value: user.role),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // --- NUEVA TARJETA PARA ACCEDER AL CAMBIO DE CONTRASEÑA ---
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                      title: const Text('Seguridad', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Cambiar mi contraseña'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: _showChangePasswordDialog,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar Sesión'),
                    onPressed: _logout,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            );
          }
          return const Center(child: Text('No se pudo cargar la información.'));
        },
      ),
    );
  }

  /// Widget auxiliar para construir una fila de detalle.
  Widget _buildDetailRow(BuildContext context, {required IconData icon, required String title, required String value}) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ],
    );
  }
}
