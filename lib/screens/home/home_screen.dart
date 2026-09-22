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
      drawer: _buildNavigationDrawer(context, authService, user),
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

                  // Accesos Rápidos para Celular (Módulos de la Tienda - Colapsable)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderGlass),
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        leading: const Icon(Icons.storefront, color: AppTheme.accentIndigo, size: 22),
                        title: const Text(
                          'Secciones de la Tienda',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        children: [
                          const Divider(color: AppTheme.borderGlass, height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickActionCard(
                                  context: context,
                                  icon: Icons.checkroom,
                                  title: 'Catálogo',
                                  subtitle: 'Prendas y stock',
                                  color: AppTheme.accentIndigo,
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.catalog, arguments: 0),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickActionCard(
                                  context: context,
                                  icon: Icons.local_offer,
                                  title: 'Promociones',
                                  subtitle: 'Hasta 90% OFF',
                                  color: const Color(0xFFE63946),
                                  isBadge: true,
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.catalog, arguments: 1),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickActionCard(
                                  context: context,
                                  icon: Icons.hourglass_top,
                                  title: 'Próximamente',
                                  subtitle: 'Alertas de estreno',
                                  color: const Color(0xFFC5A880),
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.catalog, arguments: 3),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickActionCard(
                                  context: context,
                                  icon: Icons.shopping_cart_outlined,
                                  title: 'Mi Carrito',
                                  subtitle: 'Bolsa y pagos',
                                  color: const Color(0xFFA855F7),
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.catalog, arguments: 4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickActionCard(
                                  context: context,
                                  icon: Icons.shopping_bag_outlined,
                                  title: 'Mis Pedidos',
                                  subtitle: 'Seguimiento Yango',
                                  color: const Color(0xFF10B981),
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.catalog, arguments: 5),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickActionCard(
                                  context: context,
                                  icon: Icons.camera_front,
                                  title: 'Vestidor Virtual',
                                  subtitle: 'Probador AR en vivo',
                                  color: const Color(0xFFC8A97E),
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.vestidorVirtual),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Account Details Card (Colapsable)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderGlass),
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: true,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        leading: const Icon(Icons.person, color: AppTheme.accentIndigo, size: 22),
                        title: const Text(
                          'Detalles del Perfil',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        children: [
                          const Divider(color: AppTheme.borderGlass, height: 16),
                          _buildDataRow('ID de Usuario', '#${user?.id ?? "-"}'),
                          _buildDataRow('Nombre', user?.name ?? '-'),
                          _buildDataRow('Correo Electrónico', user?.email ?? '-'),
                          _buildDataRow('Rol', user?.role ?? 'cliente'),
                          _buildDataRow(
                            'Estado',
                            user?.isActive == true ? 'Activo' : 'Inactivo',
                            isSuccess: user?.isActive == true,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pushNamed(context, AppRoutes.catalog);
                                  },
                                  icon: const Icon(Icons.checkroom, size: 18),
                                  label: const Text('Catálogo & Pedidos'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentIndigo,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, AppRoutes.profile);
                                },
                                icon: const Icon(Icons.person_outline, size: 16),
                                label: const Text('Perfil'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.accentIndigo,
                                  side: const BorderSide(color: AppTheme.accentIndigo),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(context, AppRoutes.changePassword);
                                },
                                icon: const Icon(Icons.lock_outline, size: 16),
                                label: const Text('Clave'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.accentIndigo,
                                  side: const BorderSide(color: AppTheme.accentIndigo),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // System Information Card (Colapsable)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderGlass),
                      ),
                      child: const ExpansionTile(
                        initiallyExpanded: false,
                        tilePadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        childrenPadding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
                        leading: Icon(Icons.security, color: AppTheme.successGreen, size: 22),
                        title: Text(
                          'Arquitectura y Seguridad',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        children: [
                          Divider(color: AppTheme.borderGlass, height: 16),
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

  Widget _buildQuickActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isBadge = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.bgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (isBadge)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'NUEVO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: color,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationDrawer(BuildContext context, AuthService authService, dynamic user) {
    final role = (user?.role ?? '').toString().toLowerCase();
    final isStaff = role.contains('admin') || role.contains('encargado') || role.contains('cajero');
    final canManageStore = role.contains('admin') || role.contains('encargado');

    return Drawer(
      backgroundColor: AppTheme.bgSecondary,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: AppTheme.bgCard,
              border: Border(bottom: BorderSide(color: AppTheme.borderGlass)),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: AppTheme.accentIndigo,
              child: Text(
                user?.name != null && user!.name.toString().isNotEmpty
                    ? user.name.toString()[0].toUpperCase()
                    : 'U',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            accountName: Text(
              user?.name ?? 'Usuario',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 16),
            ),
            accountEmail: Text(
              '${user?.email ?? ""} • ${(user?.role ?? "cliente").toString().toUpperCase()}',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              children: [
                // Categoria 1: CATÁLOGO Y MODA
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    leading: const Icon(Icons.style, color: AppTheme.accentIndigo),
                    title: const Text('CATÁLOGO Y MODA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary, letterSpacing: 0.5)),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.checkroom, color: AppTheme.accentIndigo, size: 20),
                        title: const Text('Catálogo de Prendas', style: TextStyle(fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRoutes.catalog, arguments: 0);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.dry_cleaning, color: AppTheme.accentPurple, size: 20),
                        title: const Text('Probador de Outfits', style: TextStyle(fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRoutes.catalog, arguments: 1);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.camera_front, color: Color(0xFFC8A97E), size: 20),
                        title: const Text('Vestidor Virtual AR', style: TextStyle(fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRoutes.vestidorVirtual);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.hourglass_top, color: Color(0xFFC5A880), size: 20),
                        title: const Text('Próximamente', style: TextStyle(fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRoutes.catalog, arguments: 1);
                        },
                      ),
                    ],
                  ),
                ),

                // Categoria 2: COMPRAS Y PEDIDOS
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: true,
                    leading: const Icon(Icons.shopping_bag_outlined, color: AppTheme.successGreen),
                    title: const Text('COMPRAS Y PEDIDOS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary, letterSpacing: 0.5)),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.shopping_cart_outlined, color: AppTheme.accentPurple, size: 20),
                        title: const Text('Mi Carrito', style: TextStyle(fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRoutes.catalog, arguments: 2);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.receipt_long_outlined, color: AppTheme.successGreen, size: 20),
                        title: const Text('Mis Pedidos y Reservas', style: TextStyle(fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRoutes.catalog, arguments: 3);
                        },
                      ),
                    ],
                  ),
                ),

                // Categoria 3: GESTIÓN DE TIENDA Y OPERACIONES (Solo Staff/Admin)
                if (isStaff)
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      leading: const Icon(Icons.admin_panel_settings, color: Color(0xFFF59E0B)),
                      title: const Text('VENTAS Y OPERACIONES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary, letterSpacing: 0.5)),
                      children: [
                        ListTile(
                          leading: const Icon(Icons.point_of_sale, color: AppTheme.accentIndigo, size: 20),
                          title: const Text('Gestión de Ventas & POS', style: TextStyle(fontSize: 14)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, AppRoutes.catalog);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.people_alt_outlined, color: Color(0xFF10B981), size: 20),
                          title: const Text('Directorio de Clientes', style: TextStyle(fontSize: 14)),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, AppRoutes.profile);
                          },
                        ),
                        if (canManageStore)
                          ListTile(
                            leading: const Icon(Icons.badge_outlined, color: Color(0xFF8B5CF6), size: 20),
                            title: const Text('Empleados & Permisos', style: TextStyle(fontSize: 14)),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, AppRoutes.profile);
                            },
                          ),
                      ],
                    ),
                  ),

                // Categoria 4: MI CUENTA Y SEGURIDAD
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    leading: const Icon(Icons.person_outline, color: AppTheme.accentPink),
                    title: const Text('MI CUENTA Y SEGURIDAD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary, letterSpacing: 0.5)),
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person, color: AppTheme.accentIndigo, size: 20),
                        title: const Text('Mi Perfil', style: TextStyle(fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRoutes.profile);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.lock_outline, color: AppTheme.accentPink, size: 20),
                        title: const Text('Cambiar Contraseña', style: TextStyle(fontSize: 14)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, AppRoutes.changePassword);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: AppTheme.borderGlass),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.dangerRed),
            title: const Text('Cerrar Sesión', style: TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold)),
            onTap: () async {
              Navigator.pop(context);
              await authService.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
          ),
          const SizedBox(height: 12),
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
