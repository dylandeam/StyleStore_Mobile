import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import '../../config/api_config.dart';
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

  // Permisos y Controlador de Cámara Hardware Real
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  int _selectedCameraIndex = 0;
  bool _hasCameraPermission = false;
  bool _isCameraActive = false;
  bool _isCameraInitialized = false;
  bool _isCameraLoading = false;
  String? _cameraError;

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

    // Inicializar Cámara AR automáticamente al entrar a la pantalla (Paridad con Web)
    _initHardwareCamera();
  }

  @override
  void dispose() {
    _swayController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // Inicializa la cámara física solicitando permisos de forma nativa e invisible al usuario
  Future<void> _initHardwareCamera() async {
    setState(() {
      _isCameraLoading = true;
      _cameraError = null;
    });

    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _hasCameraPermission = false;
          _isCameraActive = false;
          _isCameraLoading = false;
          _cameraError = 'Permiso de cámara no concedido.';
        });
        return;
      }

      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _isCameraLoading = false;
          _cameraError = 'No se encontró cámara disponible en el dispositivo.';
        });
        return;
      }

      // Buscar cámara frontal por defecto para el vestidor probador
      int frontIndex = _availableCameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = frontIndex != -1 ? frontIndex : 0;

      await _setupCameraController(_availableCameras[_selectedCameraIndex]);
    } catch (e) {
      setState(() {
        _isCameraLoading = false;
        _isCameraActive = false;
        _cameraError = 'Error al iniciar la cámara: $e';
      });
    }
  }

  Future<void> _setupCameraController(CameraDescription camera) async {
    await _cameraController?.dispose();
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _hasCameraPermission = true;
          _isCameraActive = true;
          _isCameraInitialized = true;
          _isCameraLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCameraLoading = false;
          _isCameraActive = false;
          _isCameraInitialized = false;
          _cameraError = 'Error configurando la cámara: $e';
        });
      }
    }
  }

  Future<void> _switchCameraLens() async {
    if (_availableCameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    setState(() => _isCameraLoading = true);
    await _setupCameraController(_availableCameras[_selectedCameraIndex]);
  }

  void _toggleCameraMode() {
    if (!_isCameraActive) {
      if (!_isCameraInitialized) {
        _initHardwareCamera();
      } else {
        setState(() => _isCameraActive = true);
      }
    } else {
      setState(() => _isCameraActive = false);
    }
  }

  void _updateBackViewFromRotation() {
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
    return ApiConfig.resolveImageUrl(foto);
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
              'Vestidor Virtual AR',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          if (_availableCameras.length > 1 && _isCameraActive && _isCameraInitialized)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Color(0xFFC8A97E)),
              tooltip: 'Cambiar Cámara',
              onPressed: _switchCameraLens,
            ),
          IconButton(
            icon: Icon(
              _isCameraActive ? Icons.camera : Icons.camera_alt_outlined,
              color: _isCameraActive ? const Color(0xFFC8A97E) : Colors.white60,
            ),
            tooltip: _isCameraActive ? 'Desactivar Cámara AR' : 'Activar Cámara AR',
            onPressed: _toggleCameraMode,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Maniquí / Probador Interactivo 3D con Vista de Cámara Real y Físicas
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
                  // Capa 0: Vista previa de Cámara Real Hardware o Fondo Radial Luxury
                  if (_isCameraActive &&
                      _isCameraInitialized &&
                      _cameraController != null &&
                      _cameraController!.value.isInitialized)
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize!.height,
                          height: _cameraController!.value.previewSize!.width,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                    )
                  else if (_isCameraLoading)
                    Container(
                      color: Colors.black,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFFC8A97E)),
                            SizedBox(height: 12),
                            Text(
                              'Iniciando cámara AR...',
                              style: TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
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

                  // Overlay oscuro semitransparente sobre la cámara para legibilidad y elegancia AR
                  if (_isCameraActive && _isCameraInitialized)
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.black.withOpacity(0.18),
                    ),

                  // Maniquí y Prendas con Perspectiva 3D y Balanceo de Tela
                  AnimatedBuilder(
                    animation: _swayController,
                    builder: (context, child) {
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
                        // Silueta elegante Maniquí
                        Center(
                          child: Opacity(
                            opacity: 0.20,
                            child: Container(
                              width: 170 * _scaleMultiplier,
                              height: 280 * _scaleMultiplier,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC8A97E).withOpacity(0.08),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.elliptical(85 * _scaleMultiplier, 55 * _scaleMultiplier),
                                  bottom: Radius.circular(35 * _scaleMultiplier),
                                ),
                                border: Border.all(color: const Color(0xFFC8A97E).withOpacity(0.4), width: 1.5),
                              ),
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

                  // Top Pill Centrado: Selector Frente / Espalda y Giro 360°
                  Positioned(
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xDD1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0x44C8A97E)),
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                  ),

                  // Badges de Estado (Esquina Superior Izquierda)
                  Positioned(
                    top: 54,
                    left: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xCC14263D),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x66C8A97E)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isBackView ? Icons.flip_camera_android : Icons.person_outline,
                                size: 12,
                                color: const Color(0xFFC8A97E),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isBackView
                                    ? '🔄 Espalda (${((_rotationY * 180 / math.pi).round()) % 360}°)'
                                    : '✨ Frente (${((_rotationY * 180 / math.pi).round()) % 360}°)',
                                style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isCameraActive ? const Color(0xCC059669) : const Color(0xCC0369A1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _isCameraActive ? const Color(0x8834D399) : const Color(0x8838BDF8)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_isCameraActive ? Icons.videocam : Icons.radar, size: 10, color: Colors.white),
                              const SizedBox(width: 3),
                              Text(
                                _isCameraActive ? 'REC • Cámara AR Celular Activa' : '⚡ Profundidad IA Activa',
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
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
