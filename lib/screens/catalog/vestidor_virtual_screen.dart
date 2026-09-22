import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/producto.dart';
import '../../services/api_service.dart';
import '../../services/catalog_service.dart';
import 'product_detail_screen.dart';
import 'probador_foto_screen.dart';

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

  // ML Kit Pose Detector en Tiempo Real (IA tracking de cuerpo)
  PoseDetector? _poseDetector;
  bool _isProcessingFrame = false;
  bool _isPersonDetected = false;
  String _trackingStatus = "Iniciando Pose Tracking...";
  double _manualOffsetX = 0.0;
  double _manualOffsetY = 0.0;

  // Landmarks de la prenda desde el backend (Especificación v8)
  Map<String, dynamic>? _garmentLandmarks;
  String _tipoAr = 'superior';

  // Coordenadas suavizadas ancladas al cuerpo (EMA anti-temblor)
  double _smoothedShoulderMidX = 0.5;
  double _smoothedShoulderMidY = 0.25; // Anclaje superior (Hombros real)
  double _smoothedHipMidX = 0.5;
  double _smoothedHipMidY = 0.65; // Anclaje inferior (Cintura real)
  double _smoothedShoulderWidth = 0.30;
  double _smoothedTorsoHeight = 0.40;
  double _smoothedAngle = 0.0;

  // Ajuste de Entalle al Cuerpo (Fit)
  String _bodyFit = 'slim';
  double get _fitFactor => _bodyFit == 'slim' ? 0.90 : (_bodyFit == 'regular' ? 1.05 : 1.20);

  // Rotación 360° interactiva y animación orgánica de tela
  double _rotationY = 0.0;
  bool _autoSpin = false;
  late AnimationController _swayController;

  final Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

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

    _initHardwareCamera();
  }

  @override
  void dispose() {
    _swayController.dispose();
    _stopImageStream();
    _cameraController?.dispose();
    try {
      _poseDetector?.close();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _stopImageStream() async {
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      try {
        await _cameraController!.stopImageStream();
      } catch (_) {}
    }
  }

  Future<void> _fetchLandmarksForProduct(String codigo) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final response = await apiService.get('/productos/$codigo/landmarks');
      if (mounted && response.statusCode == 200) {
        final res = jsonDecode(response.body);
        setState(() {
          _tipoAr = res['tipo_ar'] ?? 'superior';
          _garmentLandmarks = res['landmarks'];
        });
      }
    } catch (_) {}
  }

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

      int frontIndex = _availableCameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      );
      _selectedCameraIndex = frontIndex != -1 ? frontIndex : 0;

      try {
        _poseDetector ??= PoseDetector(
          options: PoseDetectorOptions(
            mode: PoseDetectionMode.stream,
            model: PoseDetectionModel.accurate,
          ),
        );
      } catch (_) {
        _poseDetector = null;
      }

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
    await _stopImageStream();
    await _cameraController?.dispose();

    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
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

        _cameraController!.startImageStream(_processCameraImage);
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

  Future<void> _processCameraImage(CameraImage image) async {
    if (_poseDetector == null || _isProcessingFrame || !_isCameraActive || !_isCameraInitialized) return;
    _isProcessingFrame = true;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isProcessingFrame = false;
        return;
      }

      final camera = _availableCameras[_selectedCameraIndex];
      final isFront = camera.lensDirection == CameraLensDirection.front;
      final rotation = inputImage.metadata?.rotation ?? InputImageRotation.rotation270deg;

      final poses = await _poseDetector!.processImage(inputImage);
      if (poses.isNotEmpty && mounted) {
        final pose = poses.first;
        final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
        final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
        final lh = pose.landmarks[PoseLandmarkType.leftHip];
        final rh = pose.landmarks[PoseLandmarkType.rightHip];

        if (ls != null && rs != null && (ls.likelihood > 0.10 || rs.likelihood > 0.10)) {
          final pLs = _mapLandmarkToScreen(ls, image, rotation, isFront);
          final pRs = _mapLandmarkToScreen(rs, image, rotation, isFront);

          final normLsX = pLs.dx;
          final normLsY = pLs.dy;
          final normRsX = pRs.dx;
          final normRsY = pRs.dy;

          Offset pLh = Offset(normLsX, normLsY + 0.35);
          if (lh != null) {
            pLh = _mapLandmarkToScreen(lh, image, rotation, isFront);
          }

          Offset pRh = Offset(normRsX, normRsY + 0.35);
          if (rh != null) {
            pRh = _mapLandmarkToScreen(rh, image, rotation, isFront);
          }

          final targetShoulderMidX = (normLsX + normRsX) / 2.0;
          final targetShoulderMidY = (normLsY + normRsY) / 2.0;
          final targetHipMidX = (pLh.dx + pRh.dx) / 2.0;
          final targetHipMidY = (pLh.dy + pRh.dy) / 2.0;

          final targetShoulderWidth = math.sqrt(
            math.pow(normLsX - normRsX, 2) + math.pow(normLsY - normRsY, 2),
          ).clamp(0.20, 0.60);

          final targetTorsoHeight = math.sqrt(
            math.pow(targetHipMidX - targetShoulderMidX, 2) +
            math.pow(targetHipMidY - targetShoulderMidY, 2),
          ).clamp(0.25, 0.70);

          final targetAngle = math.atan2(normRsY - normLsY, normRsX - normLsX);

          if (mounted) {
            setState(() {
              _isPersonDetected = true;
              _trackingStatus = "IA Pose Tracking Activo 🟢";
              const alpha = 0.35;
              _smoothedShoulderMidX = _smoothedShoulderMidX * (1 - alpha) + targetShoulderMidX * alpha;
              _smoothedShoulderMidY = _smoothedShoulderMidY * (1 - alpha) + targetShoulderMidY * alpha;
              _smoothedHipMidX = _smoothedHipMidX * (1 - alpha) + targetHipMidX * alpha;
              _smoothedHipMidY = _smoothedHipMidY * (1 - alpha) + targetHipMidY * alpha;
              _smoothedShoulderWidth = _smoothedShoulderWidth * (1 - alpha) + targetShoulderWidth * alpha;
              _smoothedTorsoHeight = _smoothedTorsoHeight * (1 - alpha) + targetTorsoHeight * alpha;
              _smoothedAngle = _smoothedAngle * (1 - alpha) + targetAngle * alpha;
            });
          }
        } else {
          _fallbackToCenterAnchor();
        }
      } else {
        _fallbackToCenterAnchor();
      }
    } catch (_) {
      _fallbackToCenterAnchor();
    } finally {
      _isProcessingFrame = false;
    }
  }

  void _fallbackToCenterAnchor() {
    if (mounted) {
      setState(() {
        _isPersonDetected = true;
        _trackingStatus = "Anclaje Centrado en Hombros 🟡";
        const alpha = 0.20;
        _smoothedShoulderMidX = _smoothedShoulderMidX * (1 - alpha) + 0.50 * alpha;
        _smoothedShoulderMidY = _smoothedShoulderMidY * (1 - alpha) + 0.28 * alpha;
        _smoothedHipMidX = _smoothedHipMidX * (1 - alpha) + 0.50 * alpha;
        _smoothedHipMidY = _smoothedHipMidY * (1 - alpha) + 0.65 * alpha;
        _smoothedShoulderWidth = _smoothedShoulderWidth * (1 - alpha) + 0.32 * alpha;
        _smoothedTorsoHeight = _smoothedTorsoHeight * (1 - alpha) + 0.40 * alpha;
        _smoothedAngle = _smoothedAngle * (1 - alpha) + 0.0 * alpha;
      });
    }
  }

  Offset _mapLandmarkToScreen(PoseLandmark landmark, CameraImage image, InputImageRotation rotation, bool isFront) {
    final double imgWidth = image.width.toDouble();
    final double imgHeight = image.height.toDouble();

    double normX;
    double normY;

    if (rotation == InputImageRotation.rotation90deg || rotation == InputImageRotation.rotation270deg) {
      if (rotation == InputImageRotation.rotation270deg) {
        normX = isFront ? (landmark.y / imgHeight) : (1.0 - (landmark.y / imgHeight));
        normY = landmark.x / imgWidth;
      } else {
        normX = isFront ? (1.0 - (landmark.y / imgHeight)) : (landmark.y / imgHeight);
        normY = 1.0 - (landmark.x / imgWidth);
      }
    } else {
      normX = isFront ? (1.0 - (landmark.x / imgWidth)) : (landmark.x / imgWidth);
      normY = landmark.y / imgHeight;
    }

    return Offset(normX.clamp(0.0, 1.0), normY.clamp(0.0, 1.0));
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return null;

    final camera = _availableCameras[_selectedCameraIndex];
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      var deviceOrientation = _cameraController!.value.deviceOrientation;
      var rotationCompensation = _orientations[deviceOrientation] ?? 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    } else {
      rotation = InputImageRotation.rotation0deg;
    }
    rotation ??= InputImageRotation.rotation270deg;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    final inputFormat = format ?? InputImageFormat.nv21;

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: inputFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
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
        if (_cameraController != null && !_cameraController!.value.isStreamingImages) {
          _cameraController!.startImageStream(_processCameraImage);
        }
      }
    } else {
      _stopImageStream();
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

    _fetchLandmarksForProduct(p.codigo);

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
              'Vestidor Virtual AR v8',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_camera_back, color: Color(0xFFC8A97E)),
            tooltip: 'Probador por Foto IA',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProbadorFotoScreen(
                    initialProduct: _activeTop ?? _activeDress ?? _activeBottom,
                  ),
                ),
              );
            },
          ),
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
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenW = constraints.maxWidth;
                final screenH = constraints.maxHeight;

                final isDynamicFit = _isCameraActive;

                // Anclaje EXACTO de la prenda superior en los HOMBROS y CUELLO (evita caer a la cintura)
                final shoulderAnchorX = (_smoothedShoulderMidX * screenW) + _manualOffsetX;
                final shoulderAnchorY = (_smoothedShoulderMidY * screenH) + _manualOffsetY + _verticalOffset;
                final hipAnchorY = (_smoothedHipMidY * screenH) + _manualOffsetY + _verticalOffset;

                final garmentWidth = isDynamicFit
                    ? (_smoothedShoulderWidth * screenW * 2.3 * _scaleMultiplier * _fitFactor)
                    : (175 * _scaleMultiplier * _fitFactor);

                final garmentHeight = isDynamicFit
                    ? (math.max(120.0, (hipAnchorY - shoulderAnchorY) * 1.35 * _scaleMultiplier))
                    : (175 * _scaleMultiplier);

                final dynamicAngle = isDynamicFit ? _smoothedAngle : 0.0;

                return GestureDetector(
                  onPanUpdate: (details) {
                    if (_isCameraActive) {
                      setState(() {
                        _manualOffsetX += details.delta.dx;
                        _manualOffsetY += details.delta.dy;
                      });
                    } else {
                      setState(() {
                        _autoSpin = false;
                        _rotationY += details.delta.dx * 0.012;
                        while (_rotationY < 0) {
                          _rotationY += 2 * math.pi;
                        }
                        while (_rotationY >= 2 * math.pi) {
                          _rotationY -= 2 * math.pi;
                        }
                        _updateBackViewFromRotation();
                      });
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Capa 0: Stream de Cámara en Vivo
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
                                  'Iniciando cámara e IA Pose Tracking...',
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

                      if (_isCameraActive && _isCameraInitialized)
                        Container(
                          width: double.infinity,
                          height: double.infinity,
                          color: Colors.black.withOpacity(0.10),
                        ),

                      // Silueta Maniquí cuando no hay cámara activa
                      if (!_isCameraActive || !_isPersonDetected)
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

                      // Capa Ropa 3D Adaptativa Anclada a los Hombros (Mesh Alignment)
                      if (isDynamicFit) ...[
                        // Prenda Inferior (Pantalón / Falda) anclada a la cintura y cadera
                        if (_activeBottom != null && _activeDress == null)
                          Positioned(
                            left: (_smoothedHipMidX * screenW) - (garmentWidth * 0.88 / 2),
                            top: hipAnchorY - (garmentHeight * 0.05) + _verticalOffset,
                            child: Transform.rotate(
                              angle: dynamicAngle,
                              child: _buildGarmentDisplay(
                                _activeBottom!,
                                width: garmentWidth * 0.88,
                                height: garmentHeight * 1.15,
                              ),
                            ),
                          ),

                        // Prenda Superior (Camisa / Polera) anclada EXACTAMENTE a los Hombros
                        if (_activeTop != null && _activeDress == null)
                          Positioned(
                            left: shoulderAnchorX - (garmentWidth / 2),
                            top: shoulderAnchorY - (garmentHeight * 0.08) + _verticalOffset,
                            child: Transform.rotate(
                              angle: dynamicAngle,
                              child: _buildGarmentDisplay(
                                _activeTop!,
                                width: garmentWidth,
                                height: garmentHeight,
                              ),
                            ),
                          ),

                        // Prenda de Cuerpo Entero (Vestido / Enterizo) anclada a los Hombros
                        if (_activeDress != null)
                          Positioned(
                            left: shoulderAnchorX - (garmentWidth * 1.05 / 2),
                            top: shoulderAnchorY - (garmentHeight * 0.08) + _verticalOffset,
                            child: Transform.rotate(
                              angle: dynamicAngle,
                              child: _buildGarmentDisplay(
                                _activeDress!,
                                width: garmentWidth * 1.05,
                                height: garmentHeight * 1.6,
                              ),
                            ),
                          ),
                      ] else ...[
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
                              if (_activeBottom != null && _activeDress == null)
                                Positioned(
                                  top: 150 + _verticalOffset,
                                  child: _buildGarmentDisplay(
                                    _activeBottom!,
                                    width: 145 * _scaleMultiplier * _fitFactor,
                                    height: 185 * _scaleMultiplier,
                                  ),
                                ),
                              if (_activeTop != null && _activeDress == null)
                                Positioned(
                                  top: 50 + _verticalOffset,
                                  child: _buildGarmentDisplay(
                                    _activeTop!,
                                    width: 175 * _scaleMultiplier * _fitFactor,
                                    height: 175 * _scaleMultiplier,
                                  ),
                                ),
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
                      ],

                      // Top Chip Indicador de Estado del Tracking AR
                      if (_isCameraActive)
                        Positioned(
                          top: 80,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFC8A97E).withValues(alpha: 0.6)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _trackingStatus.contains("Activo") ? Icons.center_focus_strong : Icons.accessibility_new,
                                  color: const Color(0xFFC8A97E),
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _trackingStatus,
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                if (_manualOffsetX != 0 || _manualOffsetY != 0) ...[
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () => setState(() {
                                      _manualOffsetX = 0.0;
                                      _manualOffsetY = 0.0;
                                    }),
                                    child: const Text(
                                      '↺ Re-Centrar',
                                      style: TextStyle(color: Color(0xFFC8A97E), fontSize: 11, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ],
                            ),
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

                      // Badges de Estado e IA Pose Tracking
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
                                color: _isPersonDetected
                                    ? const Color(0xCC059669)
                                    : (_isCameraActive ? const Color(0xCCD97706) : const Color(0xCC0369A1)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _isPersonDetected
                                      ? const Color(0x8834D399)
                                      : (_isCameraActive ? const Color(0x88FBBF24) : const Color(0x8838BDF8)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isPersonDetected ? Icons.check_circle : (_isCameraActive ? Icons.center_focus_weak : Icons.radar),
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    _isPersonDetected
                                        ? '🤖 IA Tracking: Hombros Anclados'
                                        : (_isCameraActive ? '🤖 IA Tracking: Buscando cuerpo...' : '⚡ Profundidad IA Activa'),
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
                );
              },
            ),
          ),

          // Carrusel Inferior Estilo TikTok
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
