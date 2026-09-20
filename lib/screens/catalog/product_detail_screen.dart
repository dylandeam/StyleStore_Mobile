import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../services/cart_service.dart';
import '../../services/catalog_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final String codigo;

  const ProductDetailScreen({super.key, required this.codigo});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _producto;
  List<dynamic> _recomendados = [];

  // Variantes seleccionadas
  int? _selectedColorId;
  int? _selectedTallaId;
  int? _selectedStockInventarioId;
  int? _filtroSucursalId;
  int _selectedSucursalId = 1;
  int _availableStock = 0;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    final catService = Provider.of<CatalogService>(context, listen: false);
    _filtroSucursalId = catService.selectedSucursalId;
    _loadProductData();
  }

  Future<void> _loadProductData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);

    try {
      // 1. Cargar detalle completo
      final resDetalle = await api.get(
        '${ApiConfig.catalogoUrl}/${widget.codigo}/detalle',
        requireAuth: false,
      );

      // 2. Cargar recomendaciones IA Local
      final resRec = await api.get(
        '${ApiConfig.catalogoUrl}/${widget.codigo}/recomendados?limit=4',
        requireAuth: false,
      );

      if (resDetalle.statusCode == 200) {
        final prodData = jsonDecode(utf8.decode(resDetalle.bodyBytes)) as Map<String, dynamic>;
        List<dynamic> recData = [];
        if (resRec.statusCode == 200) {
          final recJson = jsonDecode(utf8.decode(resRec.bodyBytes));
          recData = recJson['recomendaciones'] ?? [];
        }

        if (mounted) {
          setState(() {
            _producto = prodData;
            _recomendados = recData;
            _isLoading = false;

            // Auto-seleccionar primer color disponible
            final variantes = (prodData['variantes'] as List<dynamic>?) ?? [];
            if (variantes.isNotEmpty) {
              final primerColor = variantes.first;
              _selectedColorId = primerColor['producto_color_id'];
              _actualizarTallasParaColor(primerColor);
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'No se pudo cargar la prenda (${resDetalle.statusCode}).';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de conexión: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _actualizarTallasParaColor(dynamic varianteColor) {
    final existencias = (varianteColor['existencias'] as List<dynamic>?) ?? [];
    if (existencias.isNotEmpty) {
      dynamic seleccion;
      if (_filtroSucursalId != null) {
        try {
          seleccion = existencias.firstWhere(
            (e) => e['sucursal_id'] == _filtroSucursalId && ((e['cantidad'] as num?)?.toInt() ?? 0) > 0,
          );
        } catch (_) {
          try {
            seleccion = existencias.firstWhere((e) => e['sucursal_id'] == _filtroSucursalId);
          } catch (_) {
            seleccion = existencias.first;
          }
        }
      } else {
        seleccion = existencias.first;
      }

      _selectedTallaId = seleccion['talla_id'];
      _selectedStockInventarioId = seleccion['stock_inventario_id'] ?? seleccion['id'];
      _selectedSucursalId = seleccion['sucursal_id'] ?? 1;
      _availableStock = (seleccion['cantidad'] as num?)?.toInt() ?? 0;
      _quantity = _availableStock > 0 ? 1 : 0;
    } else {
      _selectedTallaId = null;
      _selectedStockInventarioId = null;
      _availableStock = 0;
      _quantity = 0;
    }
  }

  String? _resolveImageUrl(String? foto) {
    if (foto == null || foto.trim().isEmpty) return null;
    final trimmed = foto.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    const origin = 'https://stylestorebackend-production.up.railway.app';
    return '$origin${trimmed.startsWith('/') ? trimmed : '/$trimmed'}';
  }

  Color _parseHex(String? hexString) {
    if (hexString == null || hexString.isEmpty) return const Color(0xFF14263D);
    String cleanHex = hexString.replaceAll('#', '').trim();
    if (cleanHex.length == 6) {
      cleanHex = 'FF$cleanHex';
    }
    final val = int.tryParse(cleanHex, radix: 16);
    return val != null ? Color(val) : const Color(0xFF14263D);
  }

  Future<void> _agregarAlCarrito({bool irAlCheckout = false}) async {
    if (_selectedColorId == null || _selectedTallaId == null || _availableStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un color y talla con existencias disponibles.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final cartService = Provider.of<CartService>(context, listen: false);
    final ok = await cartService.addToCart(
      productoColorId: _selectedColorId!,
      tallaId: _selectedTallaId!,
      sucursalId: _selectedSucursalId,
      cantidad: _quantity,
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡${_producto?['nombre']} agregado al carrito!'),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );

      if (irAlCheckout) {
        Navigator.pop(context, true); // Regresa e indica que debe ir al carrito
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo añadir la prenda al carrito.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle de Prenda'),
          backgroundColor: AppTheme.bgSecondary,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppTheme.accentIndigo),
        ),
      );
    }

    if (_errorMessage != null || _producto == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle de Prenda'),
          backgroundColor: AppTheme.bgSecondary,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Prenda no encontrada',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadProductData,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final p = _producto!;
    final imageUrl = _resolveImageUrl(p['foto']);
    final variantes = (p['variantes'] as List<dynamic>?) ?? [];
    final varianteActual = variantes.firstWhere(
      (v) => v['producto_color_id'] == _selectedColorId,
      orElse: () => variantes.isNotEmpty ? variantes.first : null,
    );
    final todasExistencias = (varianteActual?['existencias'] as List<dynamic>?) ?? [];
    final existenciasActuales = _filtroSucursalId == null
        ? todasExistencias
        : todasExistencias.where((e) => e['sucursal_id'] == _filtroSucursalId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          p['nombre'] ?? 'Detalle de Prenda',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        actions: [
          Consumer<CartService>(
            builder: (context, cart, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_bag_outlined),
                    tooltip: 'Mi Carrito',
                    onPressed: () => Navigator.pop(context, true),
                  ),
                  if (cart.items.isNotEmpty)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.accentIndigo,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${cart.items.length}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(p),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Galería / Imagen de portada
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 280,
                width: double.infinity,
                color: AppTheme.bgCard,
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(height: 18),

            // Código y Precio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0x2014263D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'CÓDIGO: ${p['codigo']}',
                    style: const TextStyle(
                      color: Color(0xFF14263D),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'Bs. ${(p['precio'] as num?)?.toStringAsFixed(2) ?? "0.00"}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF14263D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Nombre
            Text(
              p['nombre'] ?? '',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Chips / Categoría, Temporada, Colección
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (p['categoria_nombre'] != null)
                  _buildTag('📁 ${p['categoria_nombre']}', Colors.blueGrey),
                if (p['coleccion_nombre'] != null)
                  _buildTag('🧵 ${p['coleccion_nombre']}', Colors.indigoAccent),
                if (p['temporada_nombre'] != null)
                  _buildTag('🗓️ ${p['temporada_nombre']}', Colors.orangeAccent),
                _buildTag(
                  '📦 Stock total: ${p['stock_total'] ?? 0} uds.',
                  (p['stock_total'] ?? 0) > 0 ? AppTheme.successGreen : AppTheme.dangerRed,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Descripción
            if (p['descripcion'] != null && p['descripcion'].toString().isNotEmpty) ...[
              const Text(
                'Descripción',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                p['descripcion'],
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
              ),
              const Divider(color: AppTheme.borderGlass, height: 32),
            ],

            // Selector de Sucursal
            Consumer<CatalogService>(
              builder: (context, catService, _) {
                final sucursales = catService.sucursales;
                if (sucursales.isEmpty) return const SizedBox.shrink();

                return Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderGlass),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '📍 Sucursal:',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            isExpanded: true,
                            value: _filtroSucursalId,
                            dropdownColor: AppTheme.bgCard,
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('🌐 Todas las sucursales', style: TextStyle(fontSize: 13)),
                              ),
                              ...sucursales.map((s) {
                                final sId = s['id'] as int;
                                final nombre = s['nombre'] ?? 'Sucursal #$sId';
                                return DropdownMenuItem<int?>(
                                  value: sId,
                                  child: Text(nombre, style: const TextStyle(fontSize: 13)),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _filtroSucursalId = val;
                                if (_selectedColorId != null) {
                                  final v = variantes.firstWhere(
                                    (item) => item['producto_color_id'] == _selectedColorId,
                                    orElse: () => variantes.isNotEmpty ? variantes.first : null,
                                  );
                                  if (v != null) _actualizarTallasParaColor(v);
                                }
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Selector de Color
            if (variantes.isNotEmpty) ...[
              const Text(
                'Selecciona Color',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: variantes.map((v) {
                  final isSelected = v['producto_color_id'] == _selectedColorId;
                  final hexColor = _parseHex(v['color_hex']);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedColorId = v['producto_color_id'];
                        _actualizarTallasParaColor(v);
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0x2014263D) : AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF14263D) : AppTheme.borderGlass,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: hexColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            v['color_nombre'] ?? 'Color',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Alerta si la sucursal filtrada no tiene existencias
            if (todasExistencias.isNotEmpty && existenciasActuales.isEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x1AFC2B2B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x66FC2B2B)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFFFC2B2B), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta prenda no tiene existencias en la sucursal seleccionada. Cambia de sucursal o selecciona "Todas las sucursales" para ver disponibilidad.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

            // Selector de Talla
            if (existenciasActuales.isNotEmpty) ...[
              const Text(
                'Selecciona Talla',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: existenciasActuales.map((e) {
                  final isSelected = e['talla_id'] == _selectedTallaId;
                  final stock = (e['cantidad'] as num?)?.toInt() ?? 0;
                  final isOutOfStock = stock <= 0;

                  return InkWell(
                    onTap: isOutOfStock
                        ? null
                        : () {
                            setState(() {
                              _selectedTallaId = e['talla_id'];
                              _selectedStockInventarioId = e['stock_inventario_id'] ?? e['id'];
                              _selectedSucursalId = e['sucursal_id'] ?? 1;
                              _availableStock = stock;
                              _quantity = 1;
                            });
                          },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentIndigo
                            : (isOutOfStock ? AppTheme.bgSecondary : AppTheme.bgCard),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppTheme.accentIndigo : AppTheme.borderGlass,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            e['talla_nombre'] ?? 'Talla',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isOutOfStock ? AppTheme.textMuted : AppTheme.textPrimary),
                            ),
                          ),
                          if (e['sucursal_nombre'] != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                '${e['sucursal_nombre']}',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white70 : AppTheme.accentIndigo,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          Text(
                            isOutOfStock ? 'Agotado' : '$stock disp.',
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected
                                  ? Colors.white70
                                  : (isOutOfStock ? AppTheme.dangerRed : AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Selector de Cantidad
            if (_availableStock > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cantidad',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppTheme.accentIndigo,
                      ),
                      Text(
                        '$_quantity',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        onPressed: _quantity < _availableStock ? () => setState(() => _quantity++) : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppTheme.accentIndigo,
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: AppTheme.borderGlass, height: 28),
            ],

            // SECCIÓN DE IA LOCAL: RECOMENDACIONES INTELIGENTES
            if (_recomendados.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0x33C5A880),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Color(0xFFC5A880), size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recomendados por IA Local',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          'Algoritmo semántico de afinidad por corte, estilo y colección',
                          style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _recomendados.length,
                  itemBuilder: (context, index) {
                    final item = _recomendados[index];
                    final recImg = _resolveImageUrl(item['foto']);
                    final score = ((item['score'] as num?)?.toDouble() ?? 0.0) * 100;
                    final razones = (item['razones'] as List<dynamic>?) ?? [];

                    return GestureDetector(
                      onTap: () {
                        // Navegar al detalle de la prenda recomendada
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(codigo: item['codigo']),
                          ),
                        );
                      },
                      child: Container(
                        width: 170,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x33C5A880)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 100,
                                    width: double.infinity,
                                    color: AppTheme.bgSecondary,
                                    child: recImg != null
                                        ? Image.network(
                                            recImg,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.checkroom, color: AppTheme.textMuted),
                                          )
                                        : const Icon(Icons.checkroom, color: AppTheme.textMuted),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC5A880),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${score.toInt()}% afín',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['nombre'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Bs. ${(item['precio'] as num?)?.toStringAsFixed(2) ?? "0.00"}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF14263D),
                              ),
                            ),
                            if (razones.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                razones.first.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Color(0xFFC5A880)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _abrirModalReserva(Map<String, dynamic> p) async {
    final api = Provider.of<ApiService>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.accentIndigo)),
    );

    bool puedeReservar = false;
    String mensaje = '';
    try {
      final res = await api.get(ApiConfig.reservasElegibilidadUrl, requireAuth: true);
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        puedeReservar = data['puede_reservar'] == true;
        mensaje = data['mensaje'] ?? '';
      }
    } catch (_) {}

    if (mounted) Navigator.pop(context);

    if (!puedeReservar) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_clock, color: Color(0xFFC5A880)),
              SizedBox(width: 8),
              Text('Reserva Exclusiva', style: TextStyle(fontSize: 17)),
            ],
          ),
          content: Text(
            mensaje.isNotEmpty
                ? mensaje
                : 'La reserva de prendas es un beneficio exclusivo para clientes con al menos 1 compra previa pagada. ¡Realiza tu primera compra para desbloquear reservas gratuitas!',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    int diasReserva = 2;
    int sucursalSeleccionada = _selectedSucursalId;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final fechaLimite = DateTime.now().add(Duration(days: diasReserva));
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Reservar Prenda en Tienda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Text('Prenda: ${p['nombre']}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF14263D))),
                  const SizedBox(height: 12),
                  const Text('Plazo de reserva (hasta 7 días):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [1, 2, 3, 5, 7].map((d) {
                      final sel = diasReserva == d;
                      return ChoiceChip(
                        label: Text('$d días'),
                        selected: sel,
                        selectedColor: const Color(0xFFC5A880),
                        onSelected: (_) => setModalState(() => diasReserva = d),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fecha límite para recojo: ${fechaLimite.day}/${fechaLimite.month}/${fechaLimite.year}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final stockId = _selectedStockInventarioId;
                      if (stockId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Selecciona una talla disponible para reservar.')),
                        );
                        return;
                      }

                      final resPost = await api.post(
                        ApiConfig.reservasUrl,
                        body: {
                          'sucursal_id': sucursalSeleccionada,
                          'fecha_limite': fechaLimite.toIso8601String(),
                          'detalles': [
                            {
                              'stock_inventario_id': stockId,
                              'cantidad': _quantity,
                            }
                          ],
                        },
                        requireAuth: true,
                      );

                      if (mounted) {
                        if (resPost.statusCode == 200 || resPost.statusCode == 201) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('¡Prenda reservada con éxito! Puedes verla en la pestaña Mis Pedidos.'),
                              backgroundColor: AppTheme.successGreen,
                            ),
                          );
                          _loadProductData();
                        } else {
                          try {
                            final errBody = jsonDecode(resPost.body);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errBody['detail'] ?? 'No se pudo realizar la reserva.'),
                                backgroundColor: AppTheme.dangerRed,
                              ),
                            );
                          } catch (_) {}
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14263D),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Confirmar Reserva en Sucursal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomBar(Map<String, dynamic> p) {
    final bool canBuy = _availableStock > 0 && _selectedColorId != null && _selectedTallaId != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.borderGlass)),
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canBuy ? () => _agregarAlCarrito(irAlCheckout: false) : null,
                icon: const Icon(Icons.add_shopping_cart, size: 18),
                label: const Text('Al Carrito'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentIndigo,
                  side: const BorderSide(color: AppTheme.accentIndigo),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: canBuy ? () => _abrirModalReserva(p) : null,
              tooltip: 'Reservar Prenda (Elegibilidad v6)',
              icon: const Icon(Icons.bookmark_add_outlined, color: Color(0xFFC5A880)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: canBuy ? () => _agregarAlCarrito(irAlCheckout: true) : null,
                icon: const Icon(Icons.flash_on, size: 18),
                label: const Text('Comprar Ahora'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14263D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return const Center(
      child: Icon(Icons.checkroom, size: 64, color: AppTheme.textMuted),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
