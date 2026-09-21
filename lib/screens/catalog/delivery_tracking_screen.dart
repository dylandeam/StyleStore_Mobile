import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/order.dart';

class DeliveryTrackingScreen extends StatefulWidget {
  final String token;
  final OrderItem? order;

  const DeliveryTrackingScreen({
    super.key,
    required this.token,
    this.order,
  });

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _trackingData;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _fetchTrackingInfo();
    // Polling cada 4 segundos para actualización en tiempo real
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      _fetchTrackingInfo(isBackground: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchTrackingInfo({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final url = ApiConfig.rastreoPublicoUrl(widget.token);
      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _trackingData = data;
            _isLoading = false;
          });
        }
      } else {
        if (!isBackground && mounted) {
          setState(() {
            _errorMessage = 'No se encontró la información del envío (${res.statusCode})';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!isBackground && mounted) {
        setState(() {
          _errorMessage = 'Error de conexión con el servicio de rastreo.';
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String? estado) {
    switch (estado?.toLowerCase()) {
      case 'entregado':
      case 'completado':
        return AppTheme.successGreen;
      case 'en camino':
      case 'en_camino':
        return const Color(0xFFF59E0B);
      case 'asignado':
        return AppTheme.accentIndigo;
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _formatStatus(String? estado) {
    switch (estado?.toLowerCase()) {
      case 'entregado':
      case 'completado':
        return '¡Entregado!';
      case 'en camino':
      case 'en_camino':
        return 'En Camino a tu Domicilio';
      case 'asignado':
        return 'Repartidor Asignado';
      case 'pendiente':
        return 'Preparando tu Paquete';
      default:
        return estado?.toUpperCase() ?? 'PENDIENTE';
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = _trackingData?['estado'] ?? widget.order?.envioEstado ?? 'pendiente';
    final statusColor = _getStatusColor(estado);

    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: const Text(
          'Rastreo Delivery StyleStore',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.accentIndigo),
            onPressed: () => _fetchTrackingInfo(),
            tooltip: 'Actualizar ubicación',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.accentIndigo),
                  SizedBox(height: 16),
                  Text(
                    'Conectando con el repartidor GPS...',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _fetchTrackingInfo(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentIndigo),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildTrackingContent(statusColor, estado),
    );
  }

  Widget _buildTrackingContent(Color statusColor, String estado) {
    final origen = _trackingData?['origen'] as Map<String, dynamic>?;
    final destino = _trackingData?['destino'] as Map<String, dynamic>?;
    final repartidor = _trackingData?['repartidor'] as Map<String, dynamic>?;
    final repartidorInfo = _trackingData?['repartidor_info'] as Map<String, dynamic>?;

    final distKm = (_trackingData?['distancia_km'] ?? 3.5).toDouble();
    final minEst = (_trackingData?['minutos_estimados'] ?? 20) as int;
    final conductor = repartidorInfo?['nombre'] ?? widget.order?.repartidorNombre ?? 'Repartidor Oficial';
    final trackingCode = _trackingData?['tracking_code'] ?? widget.order?.trackingCode ?? widget.token;

    final destLat = (destino?['lat'] ?? -17.7812).toDouble();
    final destLon = (destino?['lon'] ?? -63.1812).toDouble();
    final repLat = repartidor != null ? (repartidor['lat'] as num).toDouble() : null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. BANNER DE ESTADO Y TIEMPO
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withOpacity(0.12),
                  const Color(0xFF14263D).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      estado == 'entregado' ? '✅' : '🛵',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatStatus(estado),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        estado == 'entregado'
                            ? 'Tu pedido ya fue entregado con éxito.'
                            : 'Tiempo estimado de llegada: ~$minEst min',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.accentIndigo,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${distKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. CANVAS VISUAL / RADAR DE RUTA EN VIVO
          Container(
            height: 250,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1B2B),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  // Patrón de cuadrícula de radar
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GridBackgroundPainter(),
                    ),
                  ),

                  // Trayecto entre Sucursal y Casita
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _RoutePathPainter(
                        hasRepartidor: repLat != null,
                      ),
                    ),
                  ),

                  // Pin Sucursal Origen (🏬 Izquierda Superior)
                  Positioned(
                    left: 24,
                    top: 36,
                    child: _buildLocationPin(
                      emoji: '🏬',
                      title: origen?['nombre'] ?? 'Sucursal',
                      subtitle: origen?['ciudad'] ?? 'Tienda StyleStore',
                      isOrigin: true,
                    ),
                  ),

                  // Pin Casita Destino (🏠 Derecha Inferior)
                  Positioned(
                    right: 24,
                    bottom: 36,
                    child: _buildLocationPin(
                      emoji: '🏠',
                      title: 'Tu Casita',
                      subtitle: destino?['direccion'] ?? 'Ubicación exacta',
                      isOrigin: false,
                    ),
                  ),

                  // Pin Repartidor en Movimiento (🛵 Centro)
                  if (estado != 'entregado')
                    Positioned(
                      left: 120,
                      top: 105,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 44 + (_pulseController.value * 16),
                                height: 44 + (_pulseController.value * 16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.amber.withOpacity(0.25 * (1 - _pulseController.value)),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('🛵', style: TextStyle(fontSize: 14)),
                                    SizedBox(width: 4),
                                    Text(
                                      'En Vivo',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                  // Badge GPS exacto del cliente en la esquina
                  Positioned(
                    bottom: 8,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Casita GPS: ${destLat.toStringAsFixed(4)}, ${destLon.toStringAsFixed(4)}',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. TARJETA DE DETALLES DEL REPARTIDOR Y ENVÍO
          Card(
            color: AppTheme.bgSecondary,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información del Despacho',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  const Divider(height: 20),
                  _buildDetailRow(
                    icon: Icons.badge_outlined,
                    label: 'Repartidor',
                    value: conductor,
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    icon: Icons.qr_code,
                    label: 'Código de Rastreo',
                    value: trackingCode,
                    canCopy: true,
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    icon: Icons.storefront_outlined,
                    label: 'Despachado desde',
                    value: origen?['nombre'] ?? 'Sucursal Central',
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow(
                    icon: Icons.home_outlined,
                    label: 'Destino (Tu Casita)',
                    value: destino?['direccion'] ?? 'Ubicación GPS compartida',
                  ),
                  if (destino?['referencia'] != null && (destino!['referencia'] as String).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildDetailRow(
                      icon: Icons.notes_outlined,
                      label: 'Referencia',
                      value: destino['referencia'],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 4. ACCIONES RÁPIDAS: ABRIR EN GOOGLE MAPS O NAVEGADOR
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$destLat,$destLon';
                    Clipboard.setData(ClipboardData(text: mapsUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📍 Enlace de tu casita copiado al portapapeles.'),
                        backgroundColor: AppTheme.accentIndigo,
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_location, size: 16),
                  label: const Text('Copiar GPS Casita'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final webUrl = ApiConfig.webTrackerUrl(widget.token);
                    Clipboard.setData(ClipboardData(text: webUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🌐 Enlace de mapa interactivo copiado.'),
                        backgroundColor: AppTheme.accentIndigo,
                      ),
                    );
                  },
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Enlace Web'),
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLocationPin({
    required String emoji,
    required String title,
    required String subtitle,
    required bool isOrigin,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOrigin ? const Color(0xFF38BDF8) : const Color(0xFF10B981),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool canCopy = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.accentIndigo),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
        if (canCopy)
          IconButton(
            icon: const Icon(Icons.copy, size: 16, color: AppTheme.accentIndigo),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copiado al portapapeles.'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
      ],
    );
  }
}

class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF334155).withOpacity(0.2)
      ..strokeWidth = 1.0;

    const step = 25.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RoutePathPainter extends CustomPainter {
  final bool hasRepartidor;

  _RoutePathPainter({required this.hasRepartidor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC5A880)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final path = Path();
    const start = Offset(60, 60);
    final end = Offset(size.width - 60, size.height - 60);
    final control = Offset(size.width * 0.45, size.height * 0.7);

    path.moveTo(start.dx, start.dy);
    path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
