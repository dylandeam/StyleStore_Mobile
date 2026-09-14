import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';

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
          'telefono': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
          'direccion': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
          'foto': _photoController.text.trim().isNotEmpty ? _photoController.text.trim() : null,
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
                      ? const Icon(Icons.person, size: 48, color: AppTheme.accentIndigo)
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
                      const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(color: AppTheme.successGreen, fontSize: 13),
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
                      const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.dangerRed, fontSize: 13),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese su nombre' : null,
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese su apellido' : null,
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Ingrese su correo' : null,
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
