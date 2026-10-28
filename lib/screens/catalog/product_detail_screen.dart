import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../config/routes.dart';
import '../../models/producto.dart';
import '../../services/api_service.dart';
import '../../services/cart_service.dart';
import '../../services/catalog_service.dart';
import '../../services/offline_sync_service.dart';
import '../../utils/reservation_slots.dart';

class ProductDetailScreen extends StatefulWidget {
  final String codigo;
  final bool openReservationOnLoad;

  const ProductDetailScreen({
    super.key,
    required this.codigo,
    this.openReservationOnLoad = false,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _reservationPromptOpened = false;
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _producto;
  List<dynamic> _recomendados = [];
  bool _showBackPhoto = false;
  bool _usingOfflineData = false;
  DateTime? _cachedAt;
  Map<String, dynamic>? _reviews;
  bool _reviewsLoading = true;
  String? _reviewsError;
  int _reviewScore = 0;
  final TextEditingController _reviewController = TextEditingController();

  // Variantes seleccionadas
  int? _selectedColorId;
  int? _selectedTallaId;
  int? _selectedStockInventarioId;
  int? _filtroSucursalId;
  int _selectedSucursalId = 1;
  int _availableStock = 0;
  int _quantity = 1;
  double? _selectedVariantPrice;
  double? _selectedOriginalPrice;
  Map<String, dynamic> _selectedMeasurements = {};

  @override
  void initState() {
    super.initState();
    final catService = Provider.of<CatalogService>(context, listen: false);
    _filtroSucursalId = catService.selectedSucursalId;
    _loadProductData();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _loadProductData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = Provider.of<ApiService>(context, listen: false);
    final catalog = Provider.of<CatalogService>(context, listen: false);

    try {
      // 1. Cargar detalle completo
      final resDetalle = await api.get(
        '${ApiConfig.catalogoUrl}/${widget.codigo}/detalle',
      );

      if (resDetalle.statusCode == 200) {
        final prodData = jsonDecode(utf8.decode(resDetalle.bodyBytes))
            as Map<String, dynamic>;
        List<dynamic> recData = [];
        try {
          final resRec = await api.get(
            '${ApiConfig.catalogoUrl}/${widget.codigo}/recomendados?limit=4',
          );
          if (resRec.statusCode == 200) {
            final recJson = jsonDecode(utf8.decode(resRec.bodyBytes));
            if (recJson is List) {
              recData = recJson;
            } else if (recJson is Map) {
              recData = recJson['recomendaciones'] ?? recJson['items'] ?? [];
            }
          }
        } catch (_) {}
        _applyProduct(prodData, recData: recData);
        _loadReviews();
      } else {
        await _loadCachedProduct(catalog);
      }
    } catch (_) {
      await _loadCachedProduct(catalog);
    }
  }

  Future<void> _loadReviews() async {
    if (mounted) {
      setState(() {
        _reviewsLoading = true;
        _reviewsError = null;
      });
    }
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final response = await api
          .get('${ApiConfig.baseUrl}/productos/${widget.codigo}/resenas');
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final own = data['mi_resena'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _reviews = data;
        _reviewsLoading = false;
        _reviewScore = (own?['puntuacion'] as num?)?.toInt() ?? 0;
        _reviewController.text = own?['comentario']?.toString() ?? '';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reviewsLoading = false;
        _reviewsError =
            'No pudimos cargar las opiniones. Comprueba tu conexión.';
      });
    }
  }

  Future<void> _saveReview(StateSetter setSheetState) async {
    final comment = _reviewController.text.trim();
    if (_reviewScore < 1 || comment.length < 4) return;
    final api = Provider.of<ApiService>(context, listen: false);
    final response = await api.put(
      '${ApiConfig.baseUrl}/productos/${widget.codigo}/resenas/mia',
      body: {'puntuacion': _reviewScore, 'comentario': comment},
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
      Navigator.pop(context);
      await _loadReviews();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tu opinión ya está publicada.'),
        backgroundColor: AppTheme.successGreen,
      ));
      return;
    }
    String message = 'No pudimos publicar tu opinión.';
    try {
      message =
          jsonDecode(utf8.decode(response.bodyBytes))['detail'] ?? message;
    } catch (_) {}
    setSheetState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppTheme.dangerRed));
  }

  void _openReviewComposer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                            color: AppTheme.borderGlass,
                            borderRadius: BorderRadius.circular(4)))),
                const SizedBox(height: 20),
                Text(
                    _reviews?['mi_resena'] == null
                        ? 'Comparte tu opinión'
                        : 'Actualiza tu opinión',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                const Text(
                    'Tu experiencia o interés puede ayudar a alguien a decidir.',
                    style:
                        TextStyle(color: AppTheme.textSecondary, height: 1.4)),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final score = index + 1;
                    return IconButton(
                      tooltip:
                          '$score ${score == 1 ? 'estrella' : 'estrellas'}',
                      onPressed: () =>
                          setSheetState(() => _reviewScore = score),
                      iconSize: 38,
                      color: const Color(0xFFD99B24),
                      icon: Icon(score <= _reviewScore
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reviewController,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 1200,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Tu comentario',
                    hintText:
                        'Habla del diseño, el material o por qué te gustaría comprarla…',
                    labelStyle: TextStyle(color: Color(0xFF42536A)),
                    hintStyle: TextStyle(color: Color(0xFF6F756F)),
                    counterStyle: TextStyle(color: Color(0xFF6F756F)),
                    filled: true,
                    fillColor: Color(0xFFF7F2E9),
                    alignLabelWithHint: true,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(color: Color(0xFFD9D0BF)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide:
                          BorderSide(color: Color(0xFF14263D), width: 2),
                    ),
                  ),
                  style: const TextStyle(color: Color(0xFF172536)),
                  onChanged: (_) => setSheetState(() {}),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _reviewScore > 0 &&
                          _reviewController.text.trim().length >= 4
                      ? () => _saveReview(setSheetState)
                      : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF14263D),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: Text(_reviews?['mi_resena'] == null
                      ? 'Publicar opinión'
                      : 'Guardar cambios'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _applyProduct(Map<String, dynamic> prodData,
      {List<dynamic> recData = const [],
      bool offline = false,
      DateTime? cachedAt}) {
    if (!mounted) return;
    setState(() {
      _producto = prodData;
      _recomendados = recData;
      _usingOfflineData = offline;
      _cachedAt = cachedAt;
      _isLoading = false;
      _errorMessage = null;
      final variantes = (prodData['variantes'] as List<dynamic>?) ?? [];
      if (variantes.isNotEmpty) {
        final primerColor = variantes.first;
        _selectedColorId = primerColor['producto_color_id'];
        _actualizarTallasParaColor(primerColor);
      }
    });
    if (widget.openReservationOnLoad && !_reservationPromptOpened) {
      _reservationPromptOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _availableStock > 0) _abrirModalReserva(prodData);
      });
    }
  }

  Future<void> _loadCachedProduct(CatalogService catalog) async {
    final cached = await catalog.findCachedProduct(widget.codigo);
    if (cached != null) {
      _applyProduct(cached.product, offline: true, cachedAt: cached.syncedAt);
      return;
    }
    if (!mounted) return;
    setState(() {
      _errorMessage =
          'Sin conexión y sin detalle descargado. Abre el catálogo una vez con internet para guardarlo.';
      _isLoading = false;
    });
  }

  String _formatCachedAt(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month $hour:$minute';
  }

  Map<String, dynamic>? _selectedVariant() {
    final variants = (_producto?['variantes'] as List<dynamic>?) ?? const [];
    for (final raw in variants) {
      final variant = Map<String, dynamic>.from(raw as Map);
      if (variant['producto_color_id'] == _selectedColorId) return variant;
    }
    return null;
  }

  Map<String, dynamic>? _selectedExistence() {
    final variant = _selectedVariant();
    final stocks = (variant?['existencias'] as List<dynamic>?) ?? const [];
    for (final raw in stocks) {
      final stock = Map<String, dynamic>.from(raw as Map);
      if ((stock['stock_inventario_id'] ?? stock['id']) ==
          _selectedStockInventarioId) {
        return stock;
      }
    }
    return null;
  }

  void _actualizarTallasParaColor(dynamic varianteColor) {
    final existencias = (varianteColor['existencias'] as List<dynamic>?) ?? [];
    if (existencias.isNotEmpty) {
      dynamic seleccion;
      if (_filtroSucursalId != null) {
        try {
          seleccion = existencias.firstWhere(
            (e) =>
                e['sucursal_id'] == _filtroSucursalId &&
                ((e['cantidad'] as num?)?.toInt() ?? 0) > 0,
          );
        } catch (_) {
          try {
            seleccion = existencias
                .firstWhere((e) => e['sucursal_id'] == _filtroSucursalId);
          } catch (_) {
            seleccion = existencias.first;
          }
        }
      } else {
        seleccion = existencias.first;
      }

      _selectedTallaId = seleccion['talla_id'];
      _selectedStockInventarioId =
          seleccion['stock_inventario_id'] ?? seleccion['id'];
      _selectedSucursalId = seleccion['sucursal_id'] ?? 1;
      _availableStock = (seleccion['cantidad'] as num?)?.toInt() ?? 0;
      _selectedVariantPrice = (seleccion['precio'] as num?)?.toDouble() ??
          (seleccion['precio_variante'] as num?)?.toDouble();
      _selectedOriginalPrice =
          (seleccion['precio_original'] as num?)?.toDouble() ??
              (seleccion['precio_variante'] as num?)?.toDouble();
      _selectedMeasurements =
          Map<String, dynamic>.from(seleccion['medidas'] ?? const {});
      _quantity = _availableStock > 0 ? 1 : 0;
    } else {
      _selectedTallaId = null;
      _selectedStockInventarioId = null;
      _availableStock = 0;
      _selectedVariantPrice = null;
      _selectedOriginalPrice = null;
      _selectedMeasurements = {};
      _quantity = 0;
    }
  }

  String? _resolveImageUrl(String? foto) {
    return ApiConfig.resolveImageUrl(foto);
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
    if (_selectedColorId == null ||
        _selectedTallaId == null ||
        _availableStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Por favor selecciona un color y talla con existencias disponibles.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    final cartService = Provider.of<CartService>(context, listen: false);
    final variant = _selectedVariant();
    final existence = _selectedExistence();
    final unitPrice = _selectedVariantPrice ??
        double.tryParse(_producto?['precio']?.toString() ?? '0') ??
        0;
    final ok = await cartService.addToCart(
      productoColorId: _selectedColorId!,
      tallaId: _selectedTallaId!,
      sucursalId: _selectedSucursalId,
      cantidad: _quantity,
      stockInventarioId: _selectedStockInventarioId,
      productoNombre: _producto?['nombre']?.toString(),
      colorNombre: (variant?['color_nombre'] ?? variant?['nombre'])?.toString(),
      tallaNombre:
          (existence?['talla_nombre'] ?? existence?['talla'])?.toString(),
      foto: _producto?['foto']?.toString(),
      precioUnitario: unitPrice,
      sucursalNombre: existence?['sucursal_nombre']?.toString(),
      sucursalCiudad: existence?['sucursal_ciudad']?.toString(),
      sucursalMapsUrl: existence?['sucursal_maps_url']?.toString(),
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cartService.usingOfflineData
              ? 'Guardado en el carrito offline. Se sincronizará al reconectar.'
              : '¡${_producto?['nombre']} agregado al carrito!'),
          backgroundColor: cartService.usingOfflineData
              ? AppTheme.warningOrange
              : AppTheme.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );

      if (irAlCheckout) {
        Navigator.pop(context, true); // Regresa e indica que debe ir al carrito
      }
    } else {
      final msg =
          cartService.errorMessage ?? 'No se pudo añadir la prenda al carrito.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
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
                const Icon(Icons.error_outline,
                    color: AppTheme.dangerRed, size: 48),
                const SizedBox(height: 16),
                Text(
                  _errorMessage ?? 'Prenda no encontrada',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 16),
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
    final fotoToUse = _showBackPhoto && p['foto_trasera'] != null
        ? p['foto_trasera']
        : p['foto'];
    final imageUrl = _resolveImageUrl(fotoToUse);
    final variantes = (p['variantes'] as List<dynamic>?) ?? [];
    final varianteActual = variantes.firstWhere(
      (v) => v['producto_color_id'] == _selectedColorId,
      orElse: () => variantes.isNotEmpty ? variantes.first : null,
    );
    final todasExistencias =
        (varianteActual?['existencias'] as List<dynamic>?) ?? [];
    final existenciasActuales = _filtroSucursalId == null
        ? todasExistencias
        : todasExistencias
            .where((e) => e['sucursal_id'] == _filtroSucursalId)
            .toList();

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
            if (_usingOfflineData) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.warningOrange.withValues(alpha: 0.45)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.offline_bolt,
                        color: AppTheme.warningOrange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Detalle guardado en el dispositivo${_cachedAt == null ? '' : ' · ${_formatCachedAt(_cachedAt!)}'}. El stock se confirmará al reconectar.',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            // Galería / Imagen de portada
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 280,
                width: double.infinity,
                color: AppTheme.bgCard,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _buildPlaceholder(),
                      )
                    : _buildPlaceholder(),
              ),
            ),

            // Selector de Ángulo Frontal / Trasera
            if (p['foto_trasera'] != null &&
                p['foto_trasera'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Frente',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    avatar: const Icon(Icons.accessibility_new, size: 16),
                    selected: !_showBackPhoto,
                    selectedColor: const Color(0xFFC8A97E),
                    onSelected: (val) => setState(() => _showBackPhoto = false),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Espalda',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    avatar: const Icon(Icons.flip_camera_android, size: 16),
                    selected: _showBackPhoto,
                    selectedColor: const Color(0xFFC8A97E),
                    onSelected: (val) => setState(() => _showBackPhoto = true),
                  ),
                ],
              ),
            ],

            // Botón Destacado: Probar en Vestidor Virtual
            Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF14263D), Color(0xFF1E3A5F)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x66C8A97E)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3314263D),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    final prodObj = Producto.fromJson(p);
                    Navigator.pushNamed(
                      context,
                      AppRoutes.vestidorVirtual,
                      arguments: prodObj,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0x33C8A97E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFC8A97E)),
                          ),
                          child: const Center(
                            child: Text('🪞', style: TextStyle(fontSize: 22)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Probar en Vestidor Virtual',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pruébate esta prenda en tiempo real',
                                style: TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC8A97E),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Probar →',
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Código y Precio
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                if (_selectedVariantPrice != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (_selectedOriginalPrice != null &&
                          _selectedOriginalPrice! > _selectedVariantPrice!)
                        Text(
                          'Bs. ${_selectedOriginalPrice!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                            decoration: TextDecoration.lineThrough,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      Text(
                        'Bs. ${_selectedVariantPrice!.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF14263D)),
                      ),
                      Text(
                          _selectedTallaId == null
                              ? 'Precio vigente'
                              : 'Precio para la talla seleccionada',
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  )
                else if (p['en_promocion'] == true &&
                    p['precio_descuento'] != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bs. ${(p['precio'] as num?)?.toStringAsFixed(2) ?? "0.00"}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Bs. ${(p['precio_descuento'] as num?)?.toStringAsFixed(2) ?? "0.00"}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFE63946),
                        ),
                      ),
                    ],
                  )
                else
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
            if (p['en_promocion'] == true) ...[
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEAEA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0x40D62828)),
                ),
                child: Text(
                  '🔥 ${p['titulo_promocion'] ?? "Promoción Especial"} (${p['porcentaje_descuento'] ?? 0}% OFF)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD62828),
                  ),
                ),
              ),
            ],
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
                  _buildTag(
                      '🗓️ ${p['temporada_nombre']}', Colors.orangeAccent),
                _buildTag(
                  '📦 Stock total: ${p['stock_total'] ?? 0} uds.',
                  (p['stock_total'] ?? 0) > 0
                      ? AppTheme.successGreen
                      : AppTheme.dangerRed,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Descripción
            if (p['descripcion'] != null &&
                p['descripcion'].toString().isNotEmpty) ...[
              const Text(
                'Descripción',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                p['descripcion'],
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
              ),
              const Divider(color: AppTheme.borderGlass, height: 32),
            ],

            // Selector de Sucursal
            Consumer<CatalogService>(
              builder: (context, catService, _) {
                final sucursales = catService.sucursales;
                if (sucursales.isEmpty) return const SizedBox.shrink();

                Map<String, dynamic>? selBranch;
                if (_filtroSucursalId != null) {
                  for (final s in sucursales) {
                    if (s['id'] == _filtroSucursalId) {
                      selBranch = s;
                      break;
                    }
                  }
                }
                final mapsUrl = selBranch != null
                    ? (selBranch['maps_url'] ?? selBranch['ubicacion_url'])
                    : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      margin: EdgeInsets.only(
                          bottom: mapsUrl != null &&
                                  mapsUrl.toString().trim().isNotEmpty
                              ? 6
                              : 18),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderGlass),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            '📍 Sucursal:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary),
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
                                    child: Text('🌐 Todas las sucursales',
                                        style: TextStyle(fontSize: 13)),
                                  ),
                                  ...sucursales.map((s) {
                                    final sId = s['id'] as int;
                                    final nombre =
                                        s['nombre'] ?? 'Sucursal #$sId';
                                    return DropdownMenuItem<int?>(
                                      value: sId,
                                      child: Text(nombre,
                                          style: const TextStyle(fontSize: 13)),
                                    );
                                  }),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    _filtroSucursalId = val;
                                    if (_selectedColorId != null) {
                                      final v = variantes.firstWhere(
                                        (item) =>
                                            item['producto_color_id'] ==
                                            _selectedColorId,
                                        orElse: () => variantes.isNotEmpty
                                            ? variantes.first
                                            : null,
                                      );
                                      if (v != null) {
                                        _actualizarTallasParaColor(v);
                                      }
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (mapsUrl != null &&
                        mapsUrl.toString().trim().isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16, left: 4),
                        child: InkWell(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: mapsUrl.toString()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    '📍 Enlace de Maps de ${selBranch?['nombre'] ?? 'Sucursal'} copiado'),
                                backgroundColor: AppTheme.accentIndigo,
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 14, color: AppTheme.accentIndigo),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Ver sucursal en Google Maps (${selBranch?['nombre'] ?? 'Sucursal'}) ↗',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.accentIndigo,
                                      decoration: TextDecoration.underline),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),

            // Selector de Color
            if (variantes.isNotEmpty) ...[
              const Text(
                'Selecciona Color',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0x2014263D)
                            : AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF14263D)
                              : AppTheme.borderGlass,
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
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            v['color_nombre'] ?? 'Color',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
                    Icon(Icons.info_outline,
                        color: Color(0xFFFC2B2B), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esta prenda no tiene existencias en la sucursal seleccionada. Cambia de sucursal o selecciona "Todas las sucursales" para ver disponibilidad.',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                            height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

            // Selector de Talla
            if (existenciasActuales.isNotEmpty) ...[
              const Text(
                'Selecciona Talla',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
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
                              _selectedStockInventarioId =
                                  e['stock_inventario_id'] ?? e['id'];
                              _selectedSucursalId = e['sucursal_id'] ?? 1;
                              _availableStock = stock;
                              _selectedVariantPrice = (e['precio'] as num?)
                                      ?.toDouble() ??
                                  (e['precio_variante'] as num?)?.toDouble();
                              _selectedOriginalPrice =
                                  (e['precio_original'] as num?)?.toDouble() ??
                                      (e['precio_variante'] as num?)
                                          ?.toDouble();
                              _selectedMeasurements = Map<String, dynamic>.from(
                                  e['medidas'] ?? const {});
                              _quantity = 1;
                            });
                          },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.accentIndigo
                            : (isOutOfStock
                                ? AppTheme.bgSecondary
                                : AppTheme.bgCard),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.accentIndigo
                              : AppTheme.borderGlass,
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
                                  : (isOutOfStock
                                      ? AppTheme.textMuted
                                      : AppTheme.textPrimary),
                            ),
                          ),
                          Text(
                            'Bs. ${((e['precio'] as num?)?.toDouble() ?? (e['precio_variante'] as num?)?.toDouble() ?? (_producto?['precio'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : (isOutOfStock
                                      ? AppTheme.textMuted
                                      : AppTheme.textPrimary),
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
                                  color: isSelected
                                      ? Colors.white70
                                      : AppTheme.accentIndigo,
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
                                  : (isOutOfStock
                                      ? AppTheme.dangerRed
                                      : AppTheme.textSecondary),
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

            if (_selectedMeasurements.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderGlass),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Medidas de la prenda',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedMeasurements.entries
                          .map((entry) => Chip(
                                label: Text(
                                    '${entry.key.replaceAll('_', ' ')}: ${entry.value} cm'),
                                backgroundColor: AppTheme.bgSecondary,
                                side: const BorderSide(
                                    color: AppTheme.borderGlass),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],

            // Selector de Cantidad
            if (_availableStock > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cantidad',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppTheme.accentIndigo,
                      ),
                      Text(
                        '$_quantity',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        onPressed: _quantity < _availableStock
                            ? () => setState(() => _quantity++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppTheme.accentIndigo,
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(color: AppTheme.borderGlass, height: 28),
            ],

            _buildReviewsSection(),
            const SizedBox(height: 28),

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
                    child: const Icon(Icons.auto_awesome,
                        color: Color(0xFFC5A880), size: 18),
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
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
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
                    final score =
                        ((item['score'] as num?)?.toDouble() ?? 0.0) * 100;
                    final razones = (item['razones'] as List<dynamic>?) ?? [];

                    return GestureDetector(
                      onTap: () {
                        // Navegar al detalle de la prenda recomendada
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailScreen(codigo: item['codigo']),
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
                                        ? CachedNetworkImage(
                                            imageUrl: recImg,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                const Icon(Icons.checkroom,
                                                    color: AppTheme.textMuted),
                                          )
                                        : const Icon(Icons.checkroom,
                                            color: AppTheme.textMuted),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
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
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFFC5A880)),
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
    final catalogService = Provider.of<CatalogService>(context, listen: false);
    final offlineSync = Provider.of<OfflineSyncService>(context, listen: false);

    bool puedeReservar = true;
    String mensaje = offlineSync.isOnline
        ? ''
        : 'Sin conexión: la reserva quedará pendiente hasta validar horario y stock.';
    if (offlineSync.isOnline) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
            child: CircularProgressIndicator(color: AppTheme.accentIndigo)),
      );
      try {
        final res =
            await api.get(ApiConfig.reservasElegibilidadUrl, requireAuth: true);
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          puedeReservar = data['puede_reservar'] != false;
          mensaje = data['mensaje'] ?? '';
        }
      } catch (_) {
        puedeReservar = true;
        mensaje =
            'Conexión inestable: la reserva quedará pendiente hasta validar horario y stock.';
      }
      if (mounted) Navigator.pop(context);
    }

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
    final selectedBranch =
        catalogService.sucursales.cast<Map<String, dynamic>?>().firstWhere(
              (branch) => branch?['id'] == sucursalSeleccionada,
              orElse: () => null,
            );
    final aperturaTexto =
        (selectedBranch?['hora_apertura'] ?? '09:00').toString();
    final cierreTexto = (selectedBranch?['hora_cierre'] ?? '18:00').toString();
    bool horarioProvisional = false;
    Future<List<Map<String, dynamic>>> cargarBloques(DateTime fecha) async {
      if (!offlineSync.isOnline) {
        horarioProvisional = true;
        return buildProvisionalReservationSlots(aperturaTexto, cierreTexto);
      }
      try {
        final response = await api.get(
          ApiConfig.reservasDisponibilidadUrl(
              sucursalSeleccionada, formatReservationDate(fecha)),
          requireAuth: true,
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          horarioProvisional = false;
          return List<Map<String, dynamic>>.from(data['bloques'] ?? const []);
        }
      } catch (_) {}
      horarioProvisional = true;
      return buildProvisionalReservationSlots(aperturaTexto, cierreTexto);
    }

    var bloques =
        await cargarBloques(DateTime.now().add(Duration(days: diasReserva)));
    String horaRetiro = bloques
            .cast<Map<String, dynamic>?>()
            .firstWhere((block) => block?['disponible'] == true,
                orElse: () => null)?['inicio']
            ?.toString() ??
        '';
    bool cargandoBloques = false;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final fechaLimite = DateTime.now().add(Duration(days: diasReserva));
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom +
                    MediaQuery.of(ctx).viewPadding.bottom +
                    20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Reservar Prenda en Tienda',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Text('Prenda: ${p['nombre']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF14263D))),
                    const SizedBox(height: 12),
                    const Text('Fecha de recogida (hasta 3 días):',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [1, 2, 3].map((d) {
                        final sel = diasReserva == d;
                        return ChoiceChip(
                          label: Text('$d días'),
                          selected: sel,
                          selectedColor: const Color(0xFFC5A880),
                          onSelected: (_) async {
                            setModalState(() {
                              diasReserva = d;
                              cargandoBloques = true;
                              horaRetiro = '';
                            });
                            final nuevos = await cargarBloques(
                                DateTime.now().add(Duration(days: d)));
                            if (!ctx.mounted) return;
                            setModalState(() {
                              bloques = nuevos;
                              horaRetiro = nuevos
                                      .cast<Map<String, dynamic>?>()
                                      .firstWhere(
                                          (block) =>
                                              block?['disponible'] == true,
                                          orElse: () => null)?['inicio']
                                      ?.toString() ??
                                  '';
                              cargandoBloques = false;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Fecha límite para recojo: ${fechaLimite.day}/${fechaLimite.month}/${fechaLimite.year}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: horaRetiro.isEmpty ? null : horaRetiro,
                      decoration: const InputDecoration(
                        labelText: 'Bloque de recogida (1 hora)',
                        prefixIcon: Icon(Icons.schedule),
                      ),
                      hint: Text(cargandoBloques
                          ? 'Consultando horarios...'
                          : 'Selecciona un bloque disponible'),
                      items: bloques.map((block) {
                        final disponible = block['disponible'] == true;
                        final inicio = block['inicio'].toString();
                        final fin = block['fin'].toString();
                        return DropdownMenuItem<String>(
                          value: disponible ? inicio : 'ocupado-$inicio',
                          enabled: disponible,
                          child: Text(
                              '$inicio–$fin ${disponible ? 'Disponible' : 'Ocupado'}'),
                        );
                      }).toList(),
                      onChanged: cargandoBloques
                          ? null
                          : (value) =>
                              setModalState(() => horaRetiro = value ?? ''),
                    ),
                    Text(
                      'Horario de atención: $aperturaTexto – $cierreTexto',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    if (horarioProvisional) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Sin conexión: el bloque es provisional. Se confirmará automáticamente al sincronizar.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9A5A00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: horaRetiro.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              final stockId = _selectedStockInventarioId;
                              if (stockId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Selecciona una talla disponible para reservar.')),
                                );
                                return;
                              }

                              final result =
                                  await Provider.of<OfflineSyncService>(context,
                                          listen: false)
                                      .submitReservation(
                                {
                                  'sucursal_id': sucursalSeleccionada,
                                  'fecha_limite':
                                      formatReservationDate(fechaLimite),
                                  'hora_retiro': '$horaRetiro:00',
                                  'items': [
                                    {
                                      'stock_inventario_id': stockId,
                                      'cantidad': _quantity,
                                    }
                                  ],
                                },
                              );

                              if (mounted) {
                                if (result.confirmed) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          '¡Prenda reservada con éxito! Puedes verla en la pestaña Mis Pedidos.'),
                                      backgroundColor: AppTheme.successGreen,
                                    ),
                                  );
                                  _loadProductData();
                                } else if (result.queued) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '${result.message} Comprobante: ${result.operationUuid.substring(0, 8).toUpperCase()}'),
                                      backgroundColor: const Color(0xFFB7791F),
                                      duration: const Duration(seconds: 6),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(result.message),
                                        backgroundColor: AppTheme.dangerRed),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF14263D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Confirmar Reserva en Sucursal',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
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

  Widget _buildBottomBar(Map<String, dynamic> p) {
    final bool canBuy = _availableStock > 0 &&
        _selectedColorId != null &&
        _selectedTallaId != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.borderGlass)),
        boxShadow: [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: canBuy ? () => _abrirModalReserva(p) : null,
              icon: const Icon(Icons.bookmark_add_outlined, size: 20),
              label: const Text('Reservar para recoger en tienda'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF14263D),
                side: const BorderSide(color: Color(0xFFC5A880), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canBuy
                      ? () => _agregarAlCarrito(irAlCheckout: false)
                      : null,
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('Al Carrito'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accentIndigo,
                    side: const BorderSide(color: AppTheme.accentIndigo),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canBuy
                      ? () => _agregarAlCarrito(irAlCheckout: true)
                      : null,
                  icon: const Icon(Icons.flash_on, size: 18),
                  label: const Text('Comprar Ahora'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14263D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewsSection() {
    if (_reviewsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(
            child: CircularProgressIndicator(color: AppTheme.accentIndigo)),
      );
    }
    if (_reviewsError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderGlass)),
        child: Row(children: [
          const Icon(Icons.rate_review_outlined, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
              child: Text(_reviewsError!,
                  style: const TextStyle(color: AppTheme.textSecondary))),
          TextButton(onPressed: _loadReviews, child: const Text('Reintentar')),
        ]),
      );
    }
    final summary = Map<String, dynamic>.from(_reviews?['resumen'] ?? const {});
    final reviews =
        List<Map<String, dynamic>>.from(_reviews?['resenas'] ?? const []);
    final average = (summary['promedio'] as num?)?.toDouble() ?? 0;
    final canComment = _reviews?['puede_comentar'] == true;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1F000000), blurRadius: 22, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Opiniones que ayudan a elegir',
                      style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
                  SizedBox(height: 4),
                  Text('Experiencias e interés de la comunidad',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12)),
                ])),
            Text(average.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF14263D))),
            const Padding(
                padding: EdgeInsets.only(bottom: 5, left: 3),
                child:
                    Text('/ 5', style: TextStyle(color: AppTheme.textMuted))),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            ...List.generate(
                5,
                (index) => Icon(
                    index < average.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: const Color(0xFFD99B24),
                    size: 23)),
            const SizedBox(width: 9),
            Text('${summary['total'] ?? 0} opiniones',
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600)),
          ]),
          if (canComment) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openReviewComposer,
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(_reviews?['mi_resena'] == null
                  ? 'Escribir una opinión'
                  : 'Editar mi opinión'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF14263D),
                  side: const BorderSide(color: Color(0xFF14263D)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
            ),
          ],
          const SizedBox(height: 18),
          if (reviews.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderGlass)),
              child: const Row(children: [
                Icon(Icons.forum_outlined, color: AppTheme.accentIndigo),
                SizedBox(width: 12),
                Expanded(
                    child: Text(
                        'Sé la primera persona en contar qué te gusta de esta prenda.',
                        style: TextStyle(
                            color: AppTheme.textSecondary, height: 1.4)))
              ]),
            )
          else
            ...reviews.take(6).map((review) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderGlass)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF14263D),
                              foregroundColor: Colors.white,
                              child: Text(
                                  _initials(
                                      review['autor_nombre']?.toString() ??
                                          'C'),
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(
                                  review['autor_nombre']?.toString() ??
                                      'Cliente',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary))),
                          ...List.generate(
                              5,
                              (index) => Icon(
                                  index <
                                          ((review['puntuacion'] as num?)
                                                  ?.toInt() ??
                                              0)
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  color: const Color(0xFFD99B24),
                                  size: 16)),
                        ]),
                        const SizedBox(height: 12),
                        Text(review['comentario']?.toString() ?? '',
                            style: const TextStyle(
                                color: AppTheme.textPrimary, height: 1.45)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Icon(
                              review['compra_verificada'] == true
                                  ? Icons.verified_outlined
                                  : Icons.favorite_border_rounded,
                              size: 15,
                              color: review['compra_verificada'] == true
                                  ? AppTheme.successGreen
                                  : const Color(0xFF9A6B27)),
                          const SizedBox(width: 5),
                          Text(
                              review['compra_verificada'] == true
                                  ? 'Compra verificada'
                                  : 'Cliente interesado',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: review['compra_verificada'] == true
                                      ? AppTheme.successGreen
                                      : const Color(0xFF9A6B27))),
                        ]),
                      ]),
                )),
        ],
      ),
    );
  }

  String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join()
      .toUpperCase();

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
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
