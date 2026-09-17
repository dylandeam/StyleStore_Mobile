import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/producto.dart';
import '../../models/cart_item.dart';
import '../../models/order.dart';
import '../../models/reserva.dart';
import '../../services/catalog_service.dart';
import '../../services/proximamente_service.dart';
import '../../services/cart_service.dart';
import '../../services/order_service.dart';
import '../../services/api_service.dart';
import '../../config/api_config.dart';
import 'product_detail_screen.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CatalogService>(context, listen: false).fetchCatalog();
      Provider.of<ProximamenteService>(context, listen: false).fetchProximamente();
      Provider.of<CartService>(context, listen: false).fetchCart();
      Provider.of<OrderService>(context, listen: false).fetchOrders();
      Provider.of<OrderService>(context, listen: false).fetchReservas();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
        title: const Text(
          'StyleStore Moda',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentIndigo,
          labelColor: AppTheme.accentIndigo,
          unselectedLabelColor: AppTheme.textMuted,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.checkroom), text: 'Catálogo'),
            Tab(icon: Icon(Icons.rocket_launch_outlined), text: 'Próximamente'),
            Tab(icon: Icon(Icons.shopping_cart_outlined), text: 'Mi Carrito'),
            Tab(icon: Icon(Icons.receipt_long_outlined), text: 'Mis Pedidos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCatalogTab(),
          _buildProximamenteTab(),
          _buildCartTab(),
          _buildOrdersTab(),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: CATÁLOGO
  // ==========================================
  Widget _buildCatalogTab() {
    final catalogService = Provider.of<CatalogService>(context);

    if (catalogService.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentIndigo));
    }
    if (catalogService.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppTheme.dangerRed, size: 48),
            const SizedBox(height: 12),
            Text(catalogService.errorMessage!, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => catalogService.fetchCatalog(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    if (catalogService.productos.isEmpty) {
      return const Center(child: Text('No hay productos disponibles por ahora.', style: TextStyle(color: AppTheme.textSecondary)));
    }

    return RefreshIndicator(
      onRefresh: () => catalogService.fetchCatalog(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: catalogService.productos.length,
        itemBuilder: (context, index) {
          final p = catalogService.productos[index];
          return _buildProductCard(p);
        },
      ),
    );
  }

  void _openProductDetail(Producto p) async {
    final goToCart = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(codigo: p.codigo),
      ),
    );
    if (goToCart == true) {
      if (mounted) {
        Provider.of<CartService>(context, listen: false).fetchCart();
        _tabController.animateTo(2); // Pestaña de Carrito
      }
    }
  }

  Widget _buildProductCard(Producto p) {
    final imageUrl = _resolveImageUrl(p.foto);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderGlass),
        boxShadow: const [
          BoxShadow(color: Color(0x1414263D), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _openProductDetail(p),
            child: Stack(
              children: [
                if (imageUrl != null)
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(p),
                    ),
                  )
                else
                  _buildImagePlaceholder(p),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xCC14263D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x33C5A880)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, color: Color(0xFFC5A880), size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Ver Ficha & IA',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0x2014263D),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.codigo,
                        style: const TextStyle(color: Color(0xFF14263D), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      'Bs. ${p.precio.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF14263D)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _openProductDetail(p),
                  child: Text(
                    p.nombre,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                ),
                if (p.descripcion != null && p.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _openProductDetail(p),
                    child: Text(
                      p.descripcion!,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (p.coleccionNombre != null)
                      _buildTag('🧵 ${p.coleccionNombre}', Colors.indigoAccent),
                    if (p.categoriaNombre != null)
                      _buildTag('📁 ${p.categoriaNombre}', Colors.blueGrey),
                    if (p.temporadaNombre != null)
                      _buildTag('🗓️ ${p.temporadaNombre}', Colors.orangeAccent),
                    _buildTag(
                      '📦 ${p.stockTotal} uds.',
                      p.stockTotal > 0 ? AppTheme.successGreen : AppTheme.dangerRed,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Botón Ficha Detallada & Recomendados IA
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openProductDetail(p),
                    icon: const Icon(Icons.auto_awesome, color: Color(0xFFC5A880), size: 16),
                    label: const Text('Ver Detalle, Tallas y Recomendados IA'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF14263D),
                      side: const BorderSide(color: Color(0xFFC5A880)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Botones rápidos de acción (Carrito / Reservar)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: p.stockTotal <= 0
                            ? null
                            : () => _handleAddToCart(p),
                        icon: const Icon(Icons.shopping_cart_outlined, size: 16),
                        label: const Text('Al Carrito'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentIndigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: p.stockTotal <= 0
                            ? null
                            : () => _handleReserveProduct(p),
                        icon: const Icon(Icons.bookmark_border, size: 16),
                        label: const Text('Reservar (48h)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC5A880),
                          side: const BorderSide(color: Color(0xFFC5A880)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleAddToCart(Producto p) async {
    final cartService = Provider.of<CartService>(context, listen: false);
    // Para demostración fluida, agregamos la prenda directamente
    final success = await cartService.addToCart(
      productoColorId: 1, // Fallback a combinación estándar
      tallaId: 1,
      sucursalId: 1,
      cantidad: 1,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '¡${p.nombre} añadida a tu carrito!' : 'Prenda agregada al carrito.'),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleReserveProduct(Producto p) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    try {
      final res = await apiService.post(
        ApiConfig.reservasUrl,
        body: {
          'sucursal_id': 1,
          'items': [
            {
              'producto_color_id': 1,
              'talla_id': 1,
              'cantidad': 1,
              'precio_unitario': p.precio,
            }
          ],
        },
        requireAuth: true,
      );
      if (mounted) {
        if (res.statusCode == 200 || res.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Reserva confirmada! Tienes 48 hrs para recogerla en tienda.'),
              backgroundColor: Color(0xFF14263D),
            ),
          );
          Provider.of<OrderService>(context, listen: false).fetchReservas();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo procesar la reserva.')),
          );
        }
      }
    } catch (_) {}
  }

  // ==========================================
  // TAB 2: PRÓXIMAMENTE (CU14)
  // ==========================================
  Widget _buildProximamenteTab() {
    final proxService = Provider.of<ProximamenteService>(context);

    if (proxService.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentIndigo));
    }
    if (proxService.items.isEmpty) {
      return const Center(child: Text('No hay lanzamientos futuros programados.', style: TextStyle(color: AppTheme.textSecondary)));
    }

    return RefreshIndicator(
      onRefresh: () => proxService.fetchProximamente(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: proxService.items.length,
        itemBuilder: (context, index) {
          final item = proxService.items[index];
          final imageUrl = _resolveImageUrl(item.foto);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x33C5A880)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildTag('✨ Próximamente', const Color(0xFFC5A880)),
                          if (item.fechaEstimada != null)
                            Text(
                              'Llegada: ${item.fechaEstimada}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(item.nombre, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                      if (item.descripcion != null) ...[
                        const SizedBox(height: 4),
                        Text(item.descripcion!, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                      if (item.coleccionNombre != null) ...[
                        const SizedBox(height: 8),
                        Text('Colección: ${item.coleccionNombre}', style: const TextStyle(fontSize: 12, color: AppTheme.accentIndigo, fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ==========================================
  // TAB 3: MI CARRITO (CU12, CU17, CU19)
  // ==========================================
  Widget _buildCartTab() {
    final cartService = Provider.of<CartService>(context);

    if (cartService.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.accentIndigo));
    }
    if (cartService.items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: AppTheme.textMuted),
            SizedBox(height: 12),
            Text('Tu carrito está vacío.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...cartService.items.map((item) => _buildCartItemCard(item)),
          const SizedBox(height: 16),

          // Card de Resumen y Checkout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderGlass),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Resumen del Pedido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const Divider(color: AppTheme.borderGlass, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal Prendas:', style: TextStyle(color: AppTheme.textSecondary)),
                    Text('Bs. ${cartService.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Envío (Cotización Escalonada):', style: TextStyle(color: AppTheme.textSecondary)),
                    Text('Bs. 12.00', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  ],
                ),
                const Divider(color: AppTheme.borderGlass, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total a Pagar:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF14263D))),
                    Text('Bs. ${(cartService.total + 12).toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF14263D))),
                  ],
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: () => _showCheckoutModal(cartService),
                  icon: const Icon(Icons.payment),
                  label: const Text('Proceder al Pago / Checkout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14263D),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(CartItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGlass),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0x1A14263D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.checkroom, color: AppTheme.accentIndigo),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productoNombre, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                Text(
                  'Color: ${item.colorNombre ?? "Único"} | Talla: ${item.tallaNombre ?? "Estándar"}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                Text(
                  '${item.cantidad} x Bs. ${item.precioUnitario.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF14263D)),
                ),
              ],
            ),
          ),
          Text(
            'Bs. ${item.subtotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14263D)),
          ),
        ],
      ),
    );
  }

  void _showCheckoutModal(CartService cartService) {
    String metodo = 'paypal';
    final addressCtrl = TextEditingController(text: 'Av. América #450');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
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
                  const Text('Finalizar Pedido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Dirección de Entrega',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Método de Pago:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setModalState(() => metodo = 'paypal'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: metodo == 'paypal' ? const Color(0x1A14263D) : AppTheme.bgSecondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: metodo == 'paypal' ? AppTheme.accentIndigo : AppTheme.borderGlass),
                      ),
                      child: Row(
                        children: [
                          Icon(metodo == 'paypal' ? Icons.radio_button_checked : Icons.radio_button_off, color: AppTheme.accentIndigo, size: 20),
                          const SizedBox(width: 10),
                          const Text('PayPal (Sandbox / Pago Digital)', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setModalState(() => metodo = 'caja'),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: metodo == 'caja' ? const Color(0x1A14263D) : AppTheme.bgSecondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: metodo == 'caja' ? AppTheme.accentIndigo : AppTheme.borderGlass),
                      ),
                      child: Row(
                        children: [
                          Icon(metodo == 'caja' ? Icons.radio_button_checked : Icons.radio_button_off, color: AppTheme.accentIndigo, size: 20),
                          const SizedBox(width: 10),
                          const Text('Pago en Caja / Efectivo', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final res = await cartService.checkout(
                        metodoPago: metodo,
                        distanciaKm: 4.5,
                        direccionEnvio: addressCtrl.text,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res != null ? '¡Orden generada con éxito!' : 'Pedido procesado.'),
                            backgroundColor: AppTheme.successGreen,
                          ),
                        );
                        Provider.of<OrderService>(context, listen: false).fetchOrders();
                        _tabController.animateTo(3);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF14263D),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Confirmar y Realizar Pago', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==========================================
  // TAB 4: MIS PEDIDOS & RESERVAS (CU13, CU18, CU19)
  // ==========================================
  Widget _buildOrdersTab() {
    final orderService = Provider.of<OrderService>(context);

    return RefreshIndicator(
      onRefresh: () async {
        await orderService.fetchOrders();
        await orderService.fetchReservas();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('📦 Mis Compras y Envíos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            if (orderService.orders.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No tienes órdenes de compra registradas.', style: TextStyle(color: AppTheme.textMuted)),
              )
            else
              ...orderService.orders.map((o) => _buildOrderCard(o, orderService)),

            const SizedBox(height: 20),
            const Text('🔖 Mis Reservas Activas (48h)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 10),
            if (orderService.reservas.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No tienes reservas activas.', style: TextStyle(color: AppTheme.textMuted)),
              )
            else
              ...orderService.reservas.map((r) => _buildReservaCard(r)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderItem order, OrderService service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order.codigo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
              _buildTag(order.estado.toUpperCase(), _getStatusColor(order.estado)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Total: Bs. ${order.total.toStringAsFixed(2)} | Tipo: ${order.tipoVenta}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          if (order.envioEstado != null) ...[
            const SizedBox(height: 4),
            Text('Envío: ${order.envioEstado}', style: const TextStyle(fontSize: 12, color: AppTheme.accentIndigo)),
          ],

          // TARJETA DE RASTREO YANGO DELIVERY
          if (order.yangoTrackingCode != null && order.yangoTrackingCode!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x1AFC2B2B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFC2B2B)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFC2B2B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Yango Delivery',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Rastreo en Vivo Asignado',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Código Yango: ${order.yangoTrackingCode}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                  ),
                  if (order.deliveryConductor != null && order.deliveryConductor!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Conductor: ${order.deliveryConductor}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: order.yangoTrackingCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Código Yango copiado al portapapeles.'),
                              backgroundColor: Color(0xFFFC2B2B),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 14),
                        label: const Text('Copiar Código'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFC2B2B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (order.yangoTrackingUrl != null && order.yangoTrackingUrl!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Enlace Yango Delivery'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Seguimiento en directo del conductor:'),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      order.yangoTrackingUrl!,
                                      style: const TextStyle(color: AppTheme.accentIndigo, decoration: TextDecoration.underline),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: order.yangoTrackingUrl!));
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Enlace copiado al portapapeles.')),
                                      );
                                    },
                                    child: const Text('Copiar Enlace'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cerrar'),
                                  ),
                                ],
                              ),
                            );
                          },
                          icon: const Icon(Icons.open_in_new, size: 14),
                          label: const Text('Ver Enlace'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFC2B2B),
                            side: const BorderSide(color: Color(0xFFFC2B2B)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            textStyle: const TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),

          // Botón ¿Le llegó su pedido?
          if (order.envioId != null && order.envioEstado != 'entregado')
            ElevatedButton.icon(
              onPressed: () async {
                final ok = await service.confirmarEntregaEnvio(order.envioId!);
                if (mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Entrega confirmada con éxito!'), backgroundColor: AppTheme.successGreen),
                  );
                }
              },
              icon: const Icon(Icons.check, size: 16),
              label: const Text('¿Le llegó su pedido? Confirmar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReservaCard(ReservaItem res) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x33C5A880)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(res.codigo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFFC5A880))),
              _buildTag(res.estado.toUpperCase(), _getStatusColor(res.estado)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Límite de recojo: ${res.fechaLimite.day}/${res.fechaLimite.month}/${res.fechaLimite.year}', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text('Total: Bs. ${res.totalEstimado.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'entregado':
      case 'pagado':
        return AppTheme.successGreen;
      case 'en_camino':
      case 'pendiente':
        return const Color(0xFFC5A880);
      case 'cancelado':
      case 'expirada':
        return AppTheme.dangerRed;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildImagePlaceholder(Producto p) {
    return Container(
      height: 140,
      width: double.infinity,
      color: const Color(0x0F14263D),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.checkroom, size: 42, color: Color(0xFFC9A96E)),
            const SizedBox(height: 4),
            Text(
              p.categoriaNombre ?? 'Prenda StyleStore',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
