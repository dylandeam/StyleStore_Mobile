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
            icon: Icon(Icons.add_circle_outline, color: AppTheme.accentGold),
            tooltip: 'Crear Outfit Personalizado',
            onPressed: () => _showCreateOutfitModal(context),
          ),
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
                  final it = items[i] as Map<String, dynamic>;
                  final prodNom = it['producto_nombre'] ?? 'Prenda';
                  final prodFotoRaw = (it['producto_foto'] ?? it['foto_url']) as String?;
                  final prodFoto = ApiConfig.resolveImageUrl(prodFotoRaw);
                  final tipo = (it['tipo_prenda'] ?? 'Prenda').toString().toUpperCase();
                  final precio = (it['producto_precio'] as num?)?.toDouble() ?? (it['precio'] as num?)?.toDouble() ?? 0.0;

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

  void _showCreateOutfitModal(BuildContext context) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    List<Producto> catalog = widget.availableProducts ?? [];

    if (catalog.isEmpty) {
      try {
        final resCat = await apiService.get(ApiConfig.catalogoUrl, requireAuth: false);
        if (resCat.statusCode == 200) {
          final List<dynamic> list = jsonDecode(utf8.decode(resCat.bodyBytes));
          catalog = list.map((item) => Producto.fromJson(item as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }

    if (catalog.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ No se encontraron prendas en el catálogo.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final nameCtrl = TextEditingController(text: 'Mi Outfit Estilo ' + (DateTime.now().minute % 100).toString());
    final descCtrl = TextEditingController(text: 'Combinación personalizada creada desde StyleStore App');
    final List<Producto> selectedProds = [];
    bool isSaving = false;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double currentTotal = selectedProds.fold(0.0, (sum, p) => sum + p.precio);

            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('✨', style: TextStyle(fontSize: 20)),
                            SizedBox(width: 8),
                            Text(
                              'Crear Outfit Personalizado',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Nombre del Outfit',
                        labelStyle: TextStyle(color: AppTheme.accentGold),
                        filled: true,
                        fillColor: AppTheme.bgPrimary,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Descripción / Estilo',
                        labelStyle: const TextStyle(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.bgPrimary,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Selecciona las Prendas (1-4):',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentGold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.accentGold),
                          ),
                          child: Text(
                            'Total: Bs ${currentTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: AppTheme.accentGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: catalog.length,
                        itemBuilder: (context, idx) {
                          final prod = catalog[idx];
                          final isSelected = selectedProds.any((p) => p.codigo == prod.codigo);
                          final foto = ApiConfig.resolveImageUrl(prod.foto);

                          return Card(
                            color: isSelected ? AppTheme.accentIndigo.withOpacity(0.2) : AppTheme.bgPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? AppTheme.accentIndigo : Colors.white12,
                              ),
                            ),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: foto != null
                                    ? Image.network(
                                        foto,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.checkroom),
                                      )
                                    : const Icon(Icons.checkroom),
                              ),
                              title: Text(
                                prod.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              subtitle: Text(
                                '${prod.tipoPrenda.toUpperCase()} • Bs ${prod.precio.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 11, color: AppTheme.accentGold),
                              ),
                              trailing: Checkbox(
                                value: isSelected,
                                activeColor: AppTheme.accentIndigo,
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      if (!isSelected) selectedProds.add(prod);
                                    } else {
                                      selectedProds.removeWhere((p) => p.codigo == prod.codigo);
                                    }
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSaving || selectedProds.isEmpty
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                final payload = {
                                  'nombre': nameCtrl.text.trim().isEmpty ? 'Mi Outfit Personalizado' : nameCtrl.text.trim(),
                                  'descripcion': descCtrl.text.trim(),
                                  'items': selectedProds.map((p) => {
                                    'producto_codigo': p.codigo,
                                    'tipo_prenda': p.tipoPrenda,
                                    'posicion_x': 50.0,
                                    'posicion_y': 50.0,
                                    'orden_capa': 1,
                                  }).toList(),
                                };

                                try {
                                  final res = await apiService.post(
                                    ApiConfig.outfitsUrl,
                                    body: payload,
                                    requireAuth: true,
                                  );

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    if (res.statusCode == 200 || res.statusCode == 201) {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text('✨ ¡Outfit guardado exitosamente!'),
                                          backgroundColor: AppTheme.successGreen,
                                        ),
                                      );
                                      _fetchOutfits();
                                    } else {
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        const SnackBar(
                                          content: Text('⚠️ Se guardó el outfit localmente en tu sesión.'),
                                          backgroundColor: AppTheme.accentIndigo,
                                        ),
                                      );
                                      setState(() {
                                        _outfits.insert(0, {
                                          'id': DateTime.now().millisecondsSinceEpoch,
                                          'nombre': payload['nombre'],
                                          'descripcion': payload['descripcion'],
                                          'total': currentTotal,
                                          'items': selectedProds.map((p) => {
                                            'producto_codigo': p.codigo,
                                            'producto_nombre': p.nombre,
                                            'tipo_prenda': p.tipoPrenda,
                                            'foto_url': p.foto,
                                            'precio': p.precio,
                                          }).toList(),
                                        });
                                      });
                                    }
                                  }
                                } catch (_) {
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('✨ Outfit añadido a tus combinaciones.'),
                                        backgroundColor: AppTheme.successGreen,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          isSaving ? 'Guardando...' : 'Guardar Outfit (${selectedProds.length} prendas)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentGold,
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
