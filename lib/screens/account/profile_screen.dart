import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_database_service.dart';
import '../../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _apellidoController;
  late TextEditingController _emailController;
  late TextEditingController _ciController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _photoController;

  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Map<String, dynamic>? _tenantData;
  Map<String, dynamic>? _subscriptionData;
  List<Map<String, dynamic>> _branches = [];
  bool _loadingTenant = true;
  bool _offlineBranches = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthService>(context, listen: false).currentUser;
    _nameController = TextEditingController(text: user?.name ?? '');
    _apellidoController = TextEditingController(text: user?.apellido ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _ciController = TextEditingController(text: user?.ci ?? '');
    _phoneController = TextEditingController(text: user?.telefono ?? '');
    _addressController = TextEditingController(text: user?.direccion ?? '');
    _photoController = TextEditingController(text: user?.foto ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTenantInfo());
  }

  Future<void> _loadTenantInfo() async {
    final authService = context.read<AuthService>();
    final api = context.read<ApiService>();
    final storage = context.read<StorageService>();
    final localDb = context.read<LocalDatabaseService>();
    final user = authService.currentUser;
    if (user?.empresaId == null) {
      if (mounted) setState(() => _loadingTenant = false);
      return;
    }
    try {
      final tenant = await authService.getTenantDetails();
      final sub = await authService.getTenantSubscription();
      List<Map<String, dynamic>> branches = [];
      bool fromOffline = false;

      try {
        final res = await api.get(ApiConfig.sucursalesUrl);
        if (res.statusCode == 200) {
          final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
          branches =
              data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final scope = await storage.getOfflineScope();
          await localDb.saveBranches(scope, branches);
        }
      } catch (_) {
        final scope = await storage.getOfflineScope();
        branches = await localDb.loadBranches(scope);
        fromOffline = true;
      }

      if (mounted) {
        setState(() {
          _tenantData = tenant;
          _subscriptionData = sub;
          _branches = branches;
          _offlineBranches = fromOffline;
          _loadingTenant = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingTenant = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _ciController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _photoController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);

      final response = await apiService.patch(
        ApiConfig.meUrl,
        body: {
          'nombre': _nameController.text.trim(),
          'apellido': _apellidoController.text.trim(),
          'email': _emailController.text.trim(),
          'telefono': _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          'direccion': _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null,
          'foto': _photoController.text.trim().isNotEmpty
              ? _photoController.text.trim()
              : null,
        },
        requireAuth: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final updatedUser = User.fromJson(data);
        authService.updateCurrentUser(updatedUser);

        setState(() {
          _isLoading = false;
          _successMessage = 'Perfil actualizado exitosamente.';
        });
      } else {
        final err = jsonDecode(response.body);
        setState(() {
          _isLoading = false;
          _errorMessage = err['detail'] ?? 'Error al actualizar perfil.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error de conexión con el servidor ($e)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: const Text(
          'Mi Perfil de Usuario',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.bgCard,
                  backgroundImage: _photoController.text.isNotEmpty
                      ? NetworkImage(_photoController.text)
                      : null,
                  child: _photoController.text.isEmpty
                      ? const Icon(Icons.person,
                          size: 48, color: AppTheme.accentIndigo)
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              if (_successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x2610B981),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x4D10B981)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: AppTheme.successGreen, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                              color: AppTheme.successGreen, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0x26EF4444),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x4DEF4444)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.dangerRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                              color: AppTheme.dangerRed, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // CI (Inmutable)
              TextFormField(
                controller: _ciController,
                enabled: false,
                style: const TextStyle(color: AppTheme.textMuted),
                decoration: InputDecoration(
                  labelText: 'Cédula de Identidad (CI)',
                  prefixIcon: const Icon(Icons.lock, color: AppTheme.textMuted),
                  helperText: '🔒 Inmutable por seguridad de identidad',
                  filled: true,
                  fillColor: const Color(0x14FFFFFF),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              // Nombre
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Nombre *',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: AppTheme.bgCard,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingrese su nombre'
                    : null,
              ),
              const SizedBox(height: 14),

              // Apellido
              TextFormField(
                controller: _apellidoController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Apellido *',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  filled: true,
                  fillColor: AppTheme.bgCard,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingrese su apellido'
                    : null,
              ),
              const SizedBox(height: 14),

              // Email
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico *',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: AppTheme.bgCard,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Ingrese su correo'
                    : null,
              ),
              const SizedBox(height: 14),

              // Teléfono
              TextFormField(
                controller: _phoneController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Teléfono / Celular',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  filled: true,
                  fillColor: AppTheme.bgCard,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              // Dirección
              TextFormField(
                controller: _addressController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Dirección de Entrega',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  filled: true,
                  fillColor: AppTheme.bgCard,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              // Foto URL
              TextFormField(
                controller: _photoController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'URL Foto de Perfil',
                  prefixIcon: const Icon(Icons.image_outlined),
                  filled: true,
                  fillColor: AppTheme.bgCard,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateProfile,
                icon: const Icon(Icons.save),
                label: Text(_isLoading ? 'Guardando...' : 'Guardar Cambios'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentIndigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),

              // Sección Jerarquía SaaS & Sucursales (REQ-005)
              _buildTenantHierarchySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTenantHierarchySection() {
    final user = Provider.of<AuthService>(context).currentUser;
    final empresaNombre = _tenantData?['nombre'] ?? 'Empresa Activa';
    final empresaCodigo = _tenantData?['codigo'] ?? 'stylestore';
    final isTenantActive = _tenantData?['active'] as bool? ?? true;
    final planCodigo = (_subscriptionData?['plan_codigo'] ??
            _subscriptionData?['plan']?['codigo'] ??
            'profesional')
        .toString()
        .toLowerCase();
    final planNombre = (_subscriptionData?['plan_nombre'] ??
            _subscriptionData?['plan']?['nombre'] ??
            'Plan Profesional')
        .toString();

    Color planColor;
    if (planCodigo.contains('profesional')) {
      planColor = const Color(0xFF6366F1);
    } else if (planCodigo.contains('intermedio')) {
      planColor = const Color(0xFF0F766E);
    } else {
      planColor = const Color(0xFFB45309);
    }

    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1FFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentIndigo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.business_center,
                    color: AppTheme.accentIndigo, size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jerarquía de Empresa & Sucursales',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Estructura multi-tenant y asignaciones (REQ-005)',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_loadingTenant)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Empresa Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x0AFFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        empresaNombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isTenantActive
                            ? const Color(0x2610B981)
                            : const Color(0x26EF4444),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isTenantActive
                              ? AppTheme.successGreen
                              : AppTheme.dangerRed,
                        ),
                      ),
                      child: Text(
                        isTenantActive ? 'EMPRESA ACTIVA' : 'INACTIVA',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isTenantActive
                              ? AppTheme.successGreen
                              : AppTheme.dangerRed,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _infoBadge('CÓDIGO: $empresaCodigo', Icons.tag,
                        AppTheme.textSecondary),
                    _infoBadge('TENANT ID #${user?.empresaId ?? 1}',
                        Icons.domain, AppTheme.textSecondary),
                    _infoBadge(planNombre.toUpperCase(), Icons.star, planColor),
                    _infoBadge(
                        'ROL: ${(user?.role ?? "cliente").toUpperCase()}',
                        Icons.shield,
                        const Color(0xFFF59E0B)),
                    _infoBadge(
                        'CUPO SUCURSALES: ${_branches.where((b) => b['active'] != false).length} / ${_subscriptionData?['max_sucursales'] ?? (planCodigo.contains("profesional") ? 10 : (planCodigo.contains("intermedio") ? 5 : 2))}',
                        Icons.store_mall_directory_outlined,
                        const Color(0xFF38BDF8)),
                    if (planCodigo.contains('profesional'))
                      _infoBadge('IA + PREDICCIONES ACTIVAS',
                          Icons.auto_awesome, const Color(0xFF10B981))
                    else if (planCodigo.contains('intermedio'))
                      _infoBadge('CHATBOT IA ACTIVO', Icons.chat_bubble_outline,
                          const Color(0xFF10B981))
                    else
                      _infoBadge('SIN IA (PLAN BÁSICO)', Icons.lock_outline,
                          AppTheme.textSecondary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Sucursales Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.storefront,
                      size: 18, color: AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Sucursales autorizadas (${_branches.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_offlineBranches)
                const Row(
                  children: [
                    Icon(Icons.cloud_off, size: 14, color: Color(0xFFF59E0B)),
                    SizedBox(width: 4),
                    Text(
                      'SQLite local',
                      style: TextStyle(fontSize: 10, color: Color(0xFFF59E0B)),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_branches.isEmpty && !_loadingTenant)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No hay sucursales registradas o sincronizadas para esta empresa.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontStyle: FontStyle.italic),
              ),
            )
          else
            ..._branches.map((branch) {
              final isAssigned =
                  user?.sucursalId != null && branch['id'] == user?.sucursalId;
              final direccion =
                  (branch['direccion'] ?? branch['ciudad'] ?? 'Sin dirección')
                      .toString();
              final telefono = (branch['telefono'] ?? '').toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isAssigned
                      ? AppTheme.accentIndigo.withValues(alpha: 0.08)
                      : const Color(0x06FFFFFF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isAssigned
                        ? AppTheme.accentIndigo.withValues(alpha: 0.5)
                        : const Color(0x0FFFFFFF),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isAssigned
                            ? AppTheme.accentIndigo
                            : const Color(0x14FFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isAssigned ? Icons.star : Icons.store,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  branch['nombre']?.toString() ?? 'Sucursal',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isAssigned
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                              if (isAssigned)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentIndigo,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'TU SUCURSAL',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            telefono.isNotEmpty
                                ? '$direccion · Tel: $telefono'
                                : direccion,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _infoBadge(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
