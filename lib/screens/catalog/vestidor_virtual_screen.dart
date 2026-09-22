import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/producto.dart';
import '../../services/auth_service.dart';
import '../../services/catalog_service.dart';
import '../../services/storage_service.dart';
import 'product_detail_screen.dart';
import 'probador_foto_screen.dart';

class VestidorVirtualScreen extends StatefulWidget {
  final Producto? initialProduct;

  const VestidorVirtualScreen({super.key, this.initialProduct});

  @override
  State<VestidorVirtualScreen> createState() => _VestidorVirtualScreenState();
}

class _VestidorVirtualScreenState extends State<VestidorVirtualScreen> {
  Producto? _selectedProduct;
  bool _isOpeningWeb = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct != null) {
      _selectedProduct = widget.initialProduct;
    }
  }

  Future<void> _openWebVestidorAR() async {
    setState(() => _isOpeningWeb = true);

    try {
      final storageService = StorageService();
      final token = await storageService.getAccessToken();

      // Construcción del enlace Web oficial
      String webUrl = 'https://style-store-frontend-nine.vercel.app/vestidor-virtual';
      final params = <String>[];

      if (token != null && token.isNotEmpty) {
        params.add('auth_token=${Uri.encodeComponent(token)}');
      }
      if (_selectedProduct != null) {
        params.add('producto=${Uri.encodeComponent(_selectedProduct!.codigo)}');
      }

      if (params.isNotEmpty) {
        webUrl += '?${params.join('&')}';
      }

      final uri = Uri.parse(webUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Redirigiendo al Vestidor Virtual AR en la Plataforma Web...'),
            backgroundColor: Color(0xFFC8A97E),
            duration: Duration(seconds: 3),
          ),
        );
      }

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback a apertura genérica
        await launchUrl(Uri.parse('https://style-store-frontend-nine.vercel.app/vestidor-virtual'), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ No se pudo abrir la web automáticamente: $e'),
            backgroundColor: AppTheme.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningWeb = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final catalogService = Provider.of<CatalogService>(context);
    final user = authService.currentUser;
    final products = catalogService.productos;

    if (_selectedProduct == null && products.isNotEmpty) {
      _selectedProduct = products.first;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('👗 Vestidor Virtual AR StyleStore'),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner Principal
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFC8A97E).withValues(alpha: 0.4)),
                boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 6))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC8A97E).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFC8A97E)),
                    ),
                    child: const Icon(Icons.view_in_ar, size: 44, color: Color(0xFFC8A97E)),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Vestidor Virtual 3D & Realidad Aumentada',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Disfruta de la experiencia AR oficial en la plataforma web de StyleStore con renderizado 3D de alta definición, prueba en tiempo real, rotación 360° y combinador de outfits.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8), height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Card de Sesión de Usuario Registrado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFC8A97E),
                    radius: 22,
                    child: Text(
                      user != null && user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              user?.name ?? 'Usuario StyleStore',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified, color: Color(0xFFC8A97E), size: 14),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'Sesión activa vinculada',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0x22C8A97E),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0x66C8A97E)),
                          ),
                          child: const Text(
                            '🔒 Sesión vinculada al navegador web',
                            style: TextStyle(fontSize: 10, color: Color(0xFFC8A97E), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Prenda Seleccionada
            if (_selectedProduct != null) ...[
              const Text(
                'Prenda lista para probar en AR Web:',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC8A97E).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        ApiConfig.resolveImageUrl(_selectedProduct!.foto) ?? '',
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.checkroom, color: Color(0xFFC8A97E), size: 36),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedProduct!.nombre,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Código: ${_selectedProduct!.codigo} | Cat: ${_selectedProduct!.categoriaNombre ?? 'Prenda'}',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bs. ${_selectedProduct!.precio.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFFC8A97E), fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Botón Principal REDIRECCIÓN WEB
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isOpeningWeb ? null : _openWebVestidorAR,
                icon: _isOpeningWeb
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF0F172A), strokeWidth: 2))
                    : const Icon(Icons.open_in_browser, size: 22),
                label: Text(
                  _isOpeningWeb ? 'Abriendo Navegador...' : '✨ Abrir Vestidor Virtual AR en la Web',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC8A97E),
                  foregroundColor: const Color(0xFF0F172A),
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Botón Probador por Foto IA (Prueba Rápida)
            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProbadorFotoScreen(initialProduct: _selectedProduct),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_awesome, color: Color(0xFFC8A97E)),
                label: const Text('📸 Usar Probador por Foto IA en la App'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC8A97E),
                  side: const BorderSide(color: Color(0xFFC8A97E)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),

            if (_selectedProduct != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(codigo: _selectedProduct!.codigo),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white70),
                  label: const Text('Ver Ficha y Comprar Prenda', style: TextStyle(color: Colors.white70)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
