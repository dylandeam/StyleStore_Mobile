import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.bolt, color: AppTheme.accentIndigo, size: 24),
            SizedBox(width: 8),
            Text(
              'StyleStore',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.dangerRed),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await authService.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
          ),
        ],
      ),
      body: authService.status == AuthStatus.loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accentIndigo),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0x336366F1), Color(0x1AA855F7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0x336366F1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0x336366F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user, color: Color(0xFFA5B4FC), size: 14),
                              SizedBox(width: 6),
                              Text(
                                'Sesión Segura',
                                style: TextStyle(
                                  color: Color(0xFFA5B4FC),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '¡Hola, ${user?.name ?? "Usuario"}!',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Has ingresado correctamente a través de la aplicación móvil de StyleStore.',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Account Details Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderGlass),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person, color: AppTheme.accentIndigo, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Detalles del Perfil',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: AppTheme.borderGlass, height: 24),
                        _buildDataRow('ID de Usuario', '#${user?.id ?? "-"}'),
                        _buildDataRow('Nombre', user?.name ?? '-'),
                        _buildDataRow('Correo Electrónico', user?.email ?? '-'),
                        _buildDataRow(
                          'Estado',
                          user?.isActive == true ? 'Activo' : 'Inactivo',
                          isSuccess: user?.isActive == true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // System Information Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderGlass),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.security, color: AppTheme.successGreen, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Arquitectura y Seguridad',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Divider(color: AppTheme.borderGlass, height: 24),
                        _SecurityBullet(
                          title: 'FastAPI REST Backend',
                          subtitle: 'Conexión HTTPS y serialización rápida con Pydantic',
                          color: AppTheme.accentIndigo,
                        ),
                        SizedBox(height: 12),
                        _SecurityBullet(
                          title: 'Tokens Cifrados',
                          subtitle: 'Almacenamiento seguro con flutter_secure_storage',
                          color: AppTheme.accentPurple,
                        ),
                        SizedBox(height: 12),
                        _SecurityBullet(
                          title: 'Gestión de Estado Centralizada',
                          subtitle: 'Arquitectura Provider con actualización reactiva',
                          color: AppTheme.accentPink,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDataRow(String label, String value, {bool isSuccess = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
          ),
          if (isSuccess)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x2610B981),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  color: AppTheme.successGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _SecurityBullet extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _SecurityBullet({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
