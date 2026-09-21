import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/producto.dart';
import '../../services/catalog_service.dart';
import 'product_detail_screen.dart';

class VestidorVirtualScreen extends StatefulWidget {
  final Producto? initialProduct;

  const VestidorVirtualScreen({super.key, this.initialProduct});

  @override
  State<VestidorVirtualScreen> createState() => _VestidorVirtualScreenState();
}

class _VestidorVirtualScreenState extends State<VestidorVirtualScreen>
    with SingleTickerProviderStateMixin {
  Producto? _activeTop;
  Producto? _activeBottom;
  Producto? _activeDress;

  bool _isBackView = false;
  double _scaleMultiplier = 1.0;
  double _verticalOffset = 0.0;
  double _opacity = 1.0;
  String _selectedCategory = 'all';

  // Ajuste de Entalle al Cuerpo (Fit)
  String _bodyFit = 'slim'; // 'slim' (pegado), 'regular', 'loose'
  double get _fitFactor => _bodyFit == 'slim' ? 0.88 : (_bodyFit == 'regular' ? 1.0 : 1.15);

  // Rotación 360° interactiva y animación orgánica de tela
  double _rotationY = 0.0; // En radianes (0..2pi)
  bool _autoSpin = false;
  late AnimationController _swayController;

  @override
  void initState() {
    super.initState();
    _swayController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _swayController.addListener(() {
      if (_autoSpin) {
        setState(() {
          _rotationY += 0.025;
          if (_rotationY >= 2 * math.pi) _rotationY -= 2 * math.pi;
          _updateBackViewFromRotation();
        });
      }
    });

    if (widget.initialProduct != null) {
      _equipProduct(widget.initialProduct!);
    }
  }

  @override
  void dispose() {
    _swayController.dispose();
    super.dispose();
  }

  void _updateBackViewFromRotation() {
    // Cuando el modelo gira entre 90° y 270° (pi/2 y 3pi/2), se ve la espalda
    final isBack = _rotationY > (math.pi / 2) && _rotationY < (3 * math.pi / 2);
    if (isBack != _isBackView) {
      _isBackView = isBack;
    }
  }

  void _equipProduct(Producto p) {
    setState(() {
      final tipo = p.tipoPrenda.toLowerCase();
      if (tipo == 'cuerpo_entero') {
        _activeTop = null;
        _activeBottom = null;
        _activeDress = p;
      } else if (tipo == 'superior') {
        _activeDress = null;
        _activeTop = p;
      } else if (tipo == 'inferior') {
        _activeDress = null;
        _activeBottom = p;
      } else {
        _activeTop = p;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✨ Te estás probando: ${p.nombre}'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF14263D),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  String? _getGarmentImage(Producto p) {
    if (_isBackView) {
      if (p.fotoVestidorTrasera != null && p.fotoVestidorTrasera!.isNotEmpty) {
        return p.fotoVestidorTrasera;
      }
      if (p.fotoTrasera != null && p.fotoTrasera!.isNotEmpty) {
        return p.fotoTrasera;
      }
      return p.fotoVestidorFrontal ?? p.foto;
    } else {
      return p.fotoVestidorFrontal ?? p.foto;
    }
  }

  double get _totalPrice {
    double total = 0.0;
    if (_activeDress != null) {
      total += _activeDress!.precio;
    } else {
      if (_activeTop != null) total += _activeTop!.precio;
      if (_activeBottom != null) total += _activeBottom!.precio;
    }
    return total;
  }

  void _addToCart() {
    final List<Producto> items = [];
    if (_activeDress != null) items.add(_activeDress!);
    if (_activeTop != null) items.add(_activeTop!);
    if (_activeBottom != null) items.add(_activeBottom!);

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ No tienes prendas equipadas para añadir al carrito.'),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    // Abrir ficha del producto principal para elegir talla y sucursal
    final p = items.first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(codigo: p.codigo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogService = Provider.of<CatalogService>(context);
    final allProducts = catalogService.productos;

    final filteredProducts = allProducts.where((p) {
      if (_selectedCategory == 'all') return true;
      return p.tipoPrenda.toLowerCase() == _selectedCategory;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🪞', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text(
              'Vestidor Virtual',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          // Selector Frente / Espalda y Giro 360°
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0x33C8A97E)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _autoSpin = false;
                    _rotationY = 0.0;
                    _isBackView = false;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: !_isBackView && !_autoSpin ? const Color(0xFFC8A97E) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Frente',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: !_isBackView && !_autoSpin ? const Color(0xFF0F172A) : Colors.white70,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _autoSpin = false;
                    _rotationY = math.pi;
                    _isBackView = true;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isBackView && !_autoSpin ? const Color(0xFFC8A97E) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Espalda',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isBackView && !_autoSpin ? const Color(0xFF0F172A) : Colors.white70,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _autoSpin = !_autoSpin),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _autoSpin ? const Color(0xFFC8A97E) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.rotate_right,
                          size: 14,
                          color: _autoSpin ? const Color(0xFF0F172A) : const Color(0xFFC8A97E),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '360°',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _autoSpin ? const Color(0xFF0F172A) : const Color(0xFFC8A97E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Maniquí / Probador Interactivo 3D con Giro y Físicas
          Expanded(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _autoSpin = false;
                  _rotationY += details.primaryDelta! * 0.012;
                  while (_rotationY < 0) {
                    _rotationY += 2 * math.pi;
                  }
                  while (_rotationY >= 2 * math.pi) {
                    _rotationY -= 2 * math.pi;
                  }
                  _updateBackViewFromRotation();
                });
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Fondo oscuro Luxury con gradiente radial
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 0.85,
                        colors: [Color(0xFF1E293B), Color(0xFF020617)],
                      ),
                    ),
                  ),

                  // Maniquí y Prendas con Perspectiva 3D y Balanceo de Tela
                  AnimatedBuilder(
                    animation: _swayController,
                    builder: (context, child) {
                      // Balanceo orgánico sutil de tela
                      final swayOffsetY = math.sin(_swayController.value * 2 * math.pi) * 3.0;
                      final swayAngle = math.sin(_swayController.value * 2 * math.pi) * 0.012;

                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0012)
                          ..rotateY(_rotationY)
                          ..rotateZ(swayAngle)
                          ..translateByDouble(0.0, swayOffsetY, 0.0, 1.0),
                        child: child,
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Silueta base Maniquí Luxury
                        Center(
                          child: Opacity(
                            opacity: 0.22,
                            child: Icon(
                              _isBackView ? Icons.accessibility : Icons.accessibility_new,
                              size: 260,
                              color: const Color(0xFFC8A97E),
                            ),
                          ),
                        ),

                        // Prenda Inferior (Pantalón / Falda)
                        if (_activeBottom != null && _activeDress == null)
                          Positioned(
                            top: 150 + _verticalOffset,
                            child: _buildGarmentDisplay(
                              _activeBottom!,
                              width: 145 * _scaleMultiplier * _fitFactor,
                              height: 185 * _scaleMultiplier,
                            ),
                          ),

                        // Prenda Superior (Camisa / Polera)
                        if (_activeTop != null && _activeDress == null)
                          Positioned(
                            top: 50 + _verticalOffset,
                            child: _buildGarmentDisplay(
                              _activeTop!,
                              width: 175 * _scaleMultiplier * _fitFactor,
                              height: 175 * _scaleMultiplier,
                            ),
                          ),

                        // Prenda de Cuerpo Entero (Vestido / Enterizo)
                        if (_activeDress != null)
                          Positioned(
                            top: 55 + _verticalOffset,
                            child: _buildGarmentDisplay(
                              _activeDress!,
                              width: 185 * _scaleMultiplier * _fitFactor,
                              height: 275 * _scaleMultiplier,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Badge de Orientación 3D y Grados de Rotación
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xCC14263D),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x66C8A97E)),
                            boxShadow: const [
                              BoxShadow(color: Colors.black38, blurRadius: 6),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isBackView
                                    ? Icons.flip_camera_android
                                    : (_rotationY > 1.0 && _rotationY < 2.1) || (_rotationY > 4.2 && _rotationY < 5.3)
                                        ? Icons.transform
                                        : Icons.person_outline,
                                size: 14,
                                color: const Color(0xFFC8A97E),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isBackView
                                    ? '🔄 Espalda (${((_rotationY * 180 / math.pi).round()) % 360}°)'
                                    : (_rotationY > 1.0 && _rotationY < 2.1) || (_rotationY > 4.2 && _rotationY < 5.3)
                                        ? '📐 Perfil (${((_rotationY * 180 / math.pi).round()) % 360}°)'
                                        : '✨ Frente (${((_rotationY * 180 / math.pi).round()) % 360}°)',
                                style: const TextStyle(
                                  color: Color(0xFFF1F5F9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Badge de Sensor de Profundidad Neuronal
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xCC0369A1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x8838BDF8)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.radar, size: 11, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                '⚡ Profundidad IA Activa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Hint inferior de interacción
                  Positioned(
                    top: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x990F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, size: 12, color: Color(0xFFC8A97E)),
                          SizedBox(width: 4),
                          Text(
                            'Desliza para girar 360°',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Controles flotantes de calibración rápida
                  Positioned(
                    right: 12,
                    top: 16,
                    child: Column(
                      children: [
                        _buildQuickAction(
                          icon: _bodyFit == 'slim'
                              ? Icons.accessibility
                              : (_bodyFit == 'regular' ? Icons.checkroom : Icons.aspect_ratio),
                          tooltip:
                              'Ajuste al Cuerpo (${_bodyFit == 'slim' ? 'Pegado' : _bodyFit == 'regular' ? 'Regular' : 'Holgado'})',
                          onTap: () {
                            setState(() {
                              if (_bodyFit == 'slim') {
                                _bodyFit = 'regular';
                              } else if (_bodyFit == 'regular') {
                                _bodyFit = 'loose';
                              } else {
                                _bodyFit = 'slim';
                              }
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✨ Entalle: ${_bodyFit == 'slim' ? 'Pegado al Cuerpo (Slim Fit)' : _bodyFit == 'regular' ? 'Corte Clásico (Regular)' : 'Holgado (Loose)'}',
                                ),
                                duration: const Duration(seconds: 1),
                                backgroundColor: const Color(0xFF14263D),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        _buildQuickAction(
                          icon: Icons.zoom_in,
                          tooltip: 'Agrandar',
                          onTap: () {
                            setState(() {
                              if (_scaleMultiplier < 1.4) _scaleMultiplier += 0.05;
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        _buildQuickAction(
                          icon: Icons.zoom_out,
                          tooltip: 'Reducir',
                          onTap: () {
                            setState(() {
                              if (_scaleMultiplier > 0.7) _scaleMultiplier -= 0.05;
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        _buildQuickAction(
                          icon: Icons.arrow_upward,
                          tooltip: 'Subir',
                          onTap: () {
                            setState(() => _verticalOffset -= 8);
                          },
                        ),
                        const SizedBox(height: 6),
                        _buildQuickAction(
                          icon: Icons.arrow_downward,
                          tooltip: 'Bajar',
                          onTap: () {
                            setState(() => _verticalOffset += 8);
                          },
                        ),
                        const SizedBox(height: 6),
                        _buildQuickAction(
                          icon: Icons.restart_alt,
                          tooltip: 'Reiniciar',
                          onTap: () {
                            setState(() {
                              _scaleMultiplier = 1.0;
                              _verticalOffset = 0.0;
                              _opacity = 1.0;
                              _bodyFit = 'slim';
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                // Resumen de look y botón comprar
                if (_totalPrice > 0)
                  Positioned(
                    bottom: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xE60F172A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0x66C8A97E)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black45,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'TOTAL DEL LOOK',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Bs. ${_totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: Color(0xFFC8A97E),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: _addToCart,
                            icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                            label: const Text('Comprar Look'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC8A97E),
                              foregroundColor: const Color(0xFF0F172A),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

          // 2. Carrusel Inferior Estilo TikTok
          Container(
            color: const Color(0xFF0B1322),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pestañas de categorías
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildCategoryChip('all', 'Todo'),
                      const SizedBox(width: 8),
                      _buildCategoryChip('superior', '👕 Superior'),
                      const SizedBox(width: 8),
                      _buildCategoryChip('inferior', '👖 Inferior'),
                      const SizedBox(width: 8),
                      _buildCategoryChip('cuerpo_entero', '👗 Vestidos'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Lista horizontal de prendas
                SizedBox(
                  height: 115,
                  child: filteredProducts.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay prendas disponibles.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final prod = filteredProducts[index];
                            final isEquipped = _activeTop?.codigo == prod.codigo ||
                                _activeBottom?.codigo == prod.codigo ||
                                _activeDress?.codigo == prod.codigo;
                            final imgUrl = _resolveImageUrl(_getGarmentImage(prod));

                            return GestureDetector(
                              onTap: () => _equipProduct(prod),
                              child: Container(
                                width: 95,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: isEquipped
                                      ? const Color(0x33C8A97E)
                                      : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isEquipped
                                        ? const Color(0xFFC8A97E)
                                        : Colors.white12,
                                    width: isEquipped ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(10),
                                        ),
                                        child: imgUrl != null
                                            ? Image.network(
                                                imgUrl,
                                                fit: BoxFit.contain,
                                                errorBuilder: (_, __, ___) => const Center(
                                                  child: Text('👕', style: TextStyle(fontSize: 24)),
                                                ),
                                              )
                                            : const Center(
                                                child: Text('👕', style: TextStyle(fontSize: 24)),
                                              ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: Column(
                                        children: [
                                          Text(
                                            prod.nombre,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            'Bs. ${prod.precio.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              color: Color(0xFFC8A97E),
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGarmentDisplay(
    Producto p, {
    required double width,
    required double height,
  }) {
    final imgUrl = _resolveImageUrl(_getGarmentImage(p));
    return Opacity(
      opacity: _opacity,
      child: SizedBox(
        width: width,
        height: height,
        child: imgUrl != null
            ? Image.network(
                imgUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.checkroom,
                  size: 64,
                  color: Color(0xFFC8A97E),
                ),
              )
            : const Icon(Icons.checkroom, size: 64, color: Color(0xFFC8A97E)),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xCC1E293B),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0x33C8A97E)),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFFC8A97E)),
      ),
    );
  }

  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = category),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC8A97E) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFC8A97E) : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF0F172A) : Colors.white70,
          ),
        ),
      ),
    );
  }
}
