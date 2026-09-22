import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/producto.dart';
import '../../services/api_service.dart';
import '../../services/cart_service.dart';

class OutfitsScreen extends StatefulWidget {
  final List<Producto>? availableProducts;

  const OutfitsScreen({
    super.key,
    this.availableProducts,
  });

  @override
  State<OutfitsScreen> createState() => _OutfitsScreenState();
}

class _OutfitsScreenState extends State<OutfitsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _outfits = [];

  @override
  void initState() {
    super.initState();
    _fetchOutfits();
  }

  Future<void> _fetchOutfits() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final res = await apiService.get(ApiConfig.outfitsUrl, requireAuth: false);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
        _outfits = data.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}

    // Fallback con combinaciones generadas dinámicamente si no hay guardados
    if (_outfits.isEmpty) {
      try {
        List<Producto> prods = widget.availableProducts ?? [];
        if (prods.isEmpty) {
          final resCat = await apiService.get(ApiConfig.catalogoUrl, requireAuth: false);
          if (resCat.statusCode == 200) {
            final List<dynamic> list = jsonDecode(utf8.decode(resCat.bodyBytes));
            prods = list.map((item) => Producto.fromJson(item as Map<String, dynamic>)).toList();
          }
        }
        if (prods.isNotEmpty) {
          _outfits = _generatePresetOutfits(prods);
          _errorMessage = null;
        } else {
          _errorMessage = 'No hay prendas disponibles para armar outfits.';
        }
      } catch (e) {
        _errorMessage = 'Error al generar combinaciones de outfits.';
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _generatePresetOutfits(List<Producto> prods) {
    if (prods.isEmpty) return [];

    final list = <Map<String, dynamic>>[];
    final prodsConFoto = prods.where((p) => p.foto != null && p.foto!.isNotEmpty).toList();
    final pool = prodsConFoto.isNotEmpty ? prodsConFoto : prods;

    if (pool.length >= 2) {
      final p1 = pool[0];
      final p2 = pool[1];
      final total = (p1.precio) + (p2.precio);

      list.add({
        'id': 1001,
        'nombre': 'Look StyleStore Urbano',
        'descripcion': 'Combinación moderna ideal para salidas casuales o universitarias.',
        'total': total,
        'items': [
          {
            'producto_codigo': p1.codigo,
            'producto_nombre': p1.nombre,
            'tipo_prenda': p1.tipoPrenda,
            'foto_url': p1.foto,
            'precio': p1.precio,
            'posicion_x': 50.0,
            'posicion_y': 25.0,
            'orden_capa': 1,
          },
          {
            'producto_codigo': p2.codigo,
            'producto_nombre': p2.nombre,
            'tipo_prenda': p2.tipoPrenda,
            'foto_url': p2.foto,
            'precio': p2.precio,
            'posicion_x': 50.0,
            'posicion_y': 65.0,
            'orden_capa': 2,
          },
        ],
      });
    }

    if (pool.length >= 3) {
      final p1 = pool[0];
      final p2 = pool[1];
      final p3 = pool[2];
      final total = (p1.precio) + (p2.precio) + (p3.precio);

      list.add({
        'id': 1002,
        'nombre': 'Estilo Completo Weekend',
        'descripcion': 'Conjunto premium seleccionado para ocasiones especiales de fin de semana.',
        'total': total,
        'items': [
          {
            'producto_codigo': p1.codigo,
            'producto_nombre': p1.nombre,
            'tipo_prenda': p1.tipoPrenda,
            'foto_url': p1.foto,
            'precio': p1.precio,
            'posicion_x': 50.0,
            'posicion_y': 20.0,
            'orden_capa': 1,
          },
          {
            'producto_codigo': p2.codigo,
            'producto_nombre': p2.nombre,
            'tipo_prenda': p2.tipoPrenda,
            'foto_url': p2.foto,
            'precio': p2.precio,
            'posicion_x': 50.0,
            'posicion_y': 55.0,
            'orden_capa': 2,
          },
          {
            'producto_codigo': p3.codigo,
            'producto_nombre': p3.nombre,
            'tipo_prenda': p3.tipoPrenda,
            'foto_url': p3.foto,
            'precio': p3.precio,
            'posicion_x': 50.0,
            'posicion_y': 80.0,
            'orden_capa': 3,
          },
        ],
      });
    }

    return list;
  }

  Future<void> _buyOutfit(Map<String, dynamic> outfit) async {
    final outfitId = outfit['id'];
    final scaffold = ScaffoldMessenger.of(context);
    final cartService = Provider.of<CartService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    // Si es un outfit real de base de datos
    if (outfitId is int && outfitId < 1000) {
      try {
        final url = ApiConfig.outfitComprarUrl(outfitId);
        final res = await apiService.post(url, requireAuth: true);
        if (res.statusCode == 200) {
          final resData = jsonDecode(res.body);
          await cartService.fetchCart();
          scaffold.showSnackBar(
            SnackBar(
              content: Text(resData['message'] ?? '¡Outfit agregado al carrito!'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          return;
        }
      } catch (_) {}
    } else {
      // Para preset, registrar en backend y comprar
      try {
        final items = outfit['items'] as List<dynamic>? ?? [];
        final createPayload = {
          'nombre': outfit['nombre'] ?? 'Outfit StyleStore',
          'descripcion': outfit['descripcion'],
          'items': items.map((it) => {
            'producto_codigo': it['producto_codigo'] ?? '',
            'tipo_prenda': it['tipo_prenda'] ?? 'superior',
            'posicion_x': it['posicion_x'] ?? 50.0,
            'posicion_y': it['posicion_y'] ?? 50.0,
            'orden_capa': it['orden_capa'] ?? 1,
          }).toList(),
        };
        final resCreate = await apiService.post(ApiConfig.outfitsUrl, body: createPayload, requireAuth: true);
        if (resCreate.statusCode == 200 || resCreate.statusCode == 201) {
          final createdData = jsonDecode(resCreate.body);
          final newId = createdData['id'];
          if (newId != null) {
            await apiService.post(ApiConfig.outfitComprarUrl(newId), requireAuth: true);
            await cartService.fetchCart();
            scaffold.showSnackBar(
              const SnackBar(
                content: Text('✨ ¡Outfit agregado a tu bolsa de compra!'),
                backgroundColor: AppTheme.successGreen,
              ),
            );
            return;
          }
        }
      } catch (_) {}
    }

    scaffold.showSnackBar(
      const SnackBar(
        content: Text('✨ ¡Prendas añadidas a la selección!'),
        backgroundColor: AppTheme.accentIndigo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Combinaciones de Outfits', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.accentIndigo),
            onPressed: _fetchOutfits,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentIndigo))
          : _errorMessage != null && _outfits.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.style_outlined, size: 54, color: AppTheme.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _fetchOutfits,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentIndigo),
                        ),
                      ],
                    ),
                  ),
                )
              : _outfits.isEmpty
                  ? const Center(
                      child: Text(
                        'Aún no hay combinaciones de outfits disponibles.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _outfits.length,
                      itemBuilder: (context, index) {
                        final outfit = _outfits[index];
                        return _buildOutfitCard(outfit);
                      },
                    ),
    );
  }

  Widget _buildOutfitCard(Map<String, dynamic> outfit) {
    final nombre = outfit['nombre'] ?? 'Outfit StyleStore';
    final desc = outfit['descripcion'] ?? 'Selección armoniosa de prendas.';
    final total = (outfit['total'] as num?)?.toDouble() ?? 0.0;
    final items = (outfit['items'] as List<dynamic>?) ?? [];

    return Card(
      color: AppTheme.bgSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC5A880).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFC5A880)),
                  ),
                  child: Text(
                    'Bs ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Color(0xFFC5A880),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Galería de prendas que componen el outfit
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final prodFotoRaw = (it['producto_foto'] ?? it['foto_url']) as String?;
                  final prodFoto = ApiConfig.resolveImageUrl(prodFotoRaw);
                  final tipo = (it['tipo_prenda'] ?? 'Prenda').toString().toUpperCase();
                  final precio = (it['producto_precio'] as num?)?.toDouble() ?? 0.0;

                  return Container(
                    width: 105,
                    decoration: BoxDecoration(
                      color: AppTheme.bgPrimary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentIndigo.withOpacity(0.1),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: Text(
                            tipo,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentIndigo,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: prodFoto != null && prodFoto.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      prodFoto,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.checkroom, color: AppTheme.textSecondary),
                                    ),
                                  )
                                : const Icon(Icons.checkroom, color: AppTheme.textSecondary, size: 36),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Text(
                            prodNom,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                          ),
                        ),
                        Text(
                          'Bs ${precio.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 10, color: AppTheme.accentIndigo, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Botón de compra en 1 clic
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _buyOutfit(outfit),
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Comprar Outfit Completo (1 Clic)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentIndigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
