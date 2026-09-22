import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/producto.dart';
import '../../services/api_service.dart';
import '../../services/catalog_service.dart';
import 'product_detail_screen.dart';

class ProbadorFotoScreen extends StatefulWidget {
  final Producto? initialProduct;

  const ProbadorFotoScreen({super.key, this.initialProduct});

  @override
  State<ProbadorFotoScreen> createState() => _ProbadorFotoScreenState();
}

class _ProbadorFotoScreenState extends State<ProbadorFotoScreen> {
  Producto? _selectedProduct;
  File? _userPhoto;
  bool _isProcessing = false;
  String? _resultImageUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialProduct != null) {
      _selectedProduct = widget.initialProduct;
    }
  }

  Future<void> _pickPhoto() async {
    // En mobile permite seleccionar o simular la carga de foto de cuerpo completo
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Se requiere permiso de cámara/galería.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  Future<void> _generateTryOn() async {
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Por favor selecciona una prenda del catálogo.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final res = await apiService.post(
        '/prueba-virtual/generar',
        {
          'producto_codigo': _selectedProduct!.codigo,
        },
      );

      setState(() {
        _isProcessing = false;
        if (res != null && res['foto_resultado_url'] != null) {
          _resultImageUrl = ApiConfig.resolveImageUrl(res['foto_resultado_url']);
        } else {
          _resultImageUrl = ApiConfig.resolveImageUrl(_selectedProduct!.foto);
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _resultImageUrl = ApiConfig.resolveImageUrl(_selectedProduct!.foto);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogService = Provider.of<CatalogService>(context);
    final products = catalogService.productos;

    if (_selectedProduct == null && products.isNotEmpty) {
      _selectedProduct = products.first;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('📸 Probador por Foto IA'),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sube una foto tuya de cuerpo completo y pruébate prendas del catálogo:',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Tarjeta de Prenda Seleccionada
            if (_selectedProduct != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFC8A97E).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        ApiConfig.resolveImageUrl(_selectedProduct!.foto) ?? '',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.checkroom, color: Color(0xFFC8A97E)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedProduct!.nombre,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Bs. ${_selectedProduct!.precio.toStringAsFixed(2)}',
                            style: const TextStyle(color: Color(0xFFC8A97E), fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Vista del Resultado o Selector de Foto
            Container(
              height: 380,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF020617),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: _isProcessing
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Color(0xFFC8A97E)),
                          SizedBox(height: 16),
                          Text(
                            'Generando virtual try-on con IA...',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  : _resultImageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            _resultImageUrl!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_a_photo_outlined, size: 48, color: Colors.white30),
                              SizedBox(height: 10),
                              Text('Toma o selecciona una foto tuya', style: TextStyle(color: Colors.white54, fontSize: 13)),
                            ],
                          ),
                        ),
            ),

            const SizedBox(height: 20),

            // Botón Generar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _generateTryOn,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generar Prueba Virtual IA'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC8A97E),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            if (_resultImageUrl != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (_selectedProduct != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(codigo: _selectedProduct!.codigo),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Comprar esta prenda'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC8A97E),
                    side: const BorderSide(color: Color(0xFFC8A97E)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
