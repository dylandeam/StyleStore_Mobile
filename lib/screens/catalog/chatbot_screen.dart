import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../services/api_service.dart';
import '../../services/cart_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final List<Map<String, dynamic>>? chips;
  final bool isIa;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.chips,
    this.isIa = false,
  });
}

class ChatbotScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const ChatbotScreen({super.key, this.onNavigateTab});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final List<ChatMessage> _messages = [];

  final List<String> _quickSuggestions = [
    '👗 ¿Qué prendas tienen en el catálogo?',
    '💡 Recomiéndame un outfit para salir',
    '🛵 ¿Cómo funciona el delivery y rastreo?',
    '📍 ¿Dónde están sus sucursales?',
    '🛒 Agrega camisa al carrito',
  ];

  @override
  void initState() {
    super.initState();
    // Mensaje de bienvenida inicial
    _messages.add(
      ChatMessage(
        text: '¡Hola! 👋 Soy tu Asesor de Moda e Imagen con Inteligencia Artificial de StyleStore.\n\n¿En qué puedo ayudarte hoy? Puedes preguntarme sobre combinaciones de prendas, sucursales, o pedirme que agregue ropa a tu bolsa de compra.',
        isUser: false,
        time: DateTime.now(),
        isIa: true,
        chips: [
          {'label': '👗 Ver Catálogo', 'action': 'navigate', 'route': '/catalogo'},
          {'label': '✨ Outfits Recomendados', 'action': 'navigate', 'route': '/outfits'},
          {'label': '🛵 Rastrear Pedido', 'action': 'navigate', 'route': '/pedidos'},
        ],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;

    _textController.clear();
    setState(() {
      _messages.add(
        ChatMessage(
          text: query,
          isUser: true,
          time: DateTime.now(),
        ),
      );
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final res = await apiService.post(
        ApiConfig.chatbotConversarUrl,
        body: {'mensaje': query},
        requireAuth: true,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final respText = data['respuesta'] ?? 'Entendido.';
        final chipsList = (data['chips'] as List<dynamic>?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList();

        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.add(
              ChatMessage(
                text: respText,
                isUser: false,
                time: DateTime.now(),
                chips: chipsList,
                isIa: data['ia_powered'] ?? false,
              ),
            );
          });
        }
      } else {
        _handleFallbackResponse(query);
      }
    } catch (e) {
      _handleFallbackResponse(query);
    }

    _scrollToBottom();
  }

  void _handleFallbackResponse(String query) {
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(
        ChatMessage(
          text: 'Entendido. En StyleStore contamos con prendas de alta calidad, envíos con rastreo GPS en vivo y combinaciones de moda.',
          isUser: false,
          time: DateTime.now(),
          chips: [
            {'label': '👗 Ir al Catálogo', 'action': 'navigate', 'route': '/catalogo'},
            {'label': '🛵 Ver Mis Pedidos', 'action': 'navigate', 'route': '/pedidos'},
          ],
        ),
      );
    });
  }

  Future<void> _handleChipAction(Map<String, dynamic> chip) async {
    final action = chip['action'];
    final scaffold = ScaffoldMessenger.of(context);
    final cartService = Provider.of<CartService>(context, listen: false);

    if (action == 'add_to_cart') {
      final stockId = chip['stock_inventario_id'] ?? chip['stock_id'];
      final cantidad = chip['cantidad'] ?? 1;

      if (stockId != null) {
        final ok = await cartService.addStockItem(stockId, cantidad: cantidad);
        if (ok) {
          scaffold.showSnackBar(
            const SnackBar(
              content: Text('🛒 ¡Producto añadido al carrito desde el Chatbot!'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        } else {
          scaffold.showSnackBar(
            const SnackBar(
              content: Text('No se pudo añadir la prenda (sin stock suficiente).'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } else if (action == 'navigate') {
      final route = chip['route'] as String?;
      if (route != null && widget.onNavigateTab != null) {
        if (route.contains('catalogo')) {
          widget.onNavigateTab!(0);
          Navigator.pop(context);
        } else if (route.contains('outfit')) {
          widget.onNavigateTab!(1);
          Navigator.pop(context);
        } else if (route.contains('carrito')) {
          widget.onNavigateTab!(3);
          Navigator.pop(context);
        } else if (route.contains('pedidos') || route.contains('compras')) {
          widget.onNavigateTab!(4);
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: const Row(
          children: [
            Text('🤖 ', style: TextStyle(fontSize: 20)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Asesor de Moda IA',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'StyleStore Intelligence en vivo',
                  style: TextStyle(fontSize: 10, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: AppTheme.bgSecondary,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 1. LISTA DE MENSAJES
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // 2. INDICADOR DE ESCRIBIENDO
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentIndigo),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Asistente IA pensando...',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

          // 3. CHIPS DE SUGERENCIAS RÁPIDAS
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickSuggestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final sug = _quickSuggestions[i];
                return ActionChip(
                  label: Text(sug, style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary)),
                  backgroundColor: AppTheme.bgSecondary,
                  side: BorderSide(color: AppTheme.accentIndigo.withOpacity(0.3)),
                  onPressed: () => _sendMessage(sug),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // 4. CAMPO DE ENTRADA Y BOTÓN ENVIAR
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppTheme.bgSecondary,
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Pregunta sobre moda, tallas, pedidos...',
                        hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: AppTheme.bgPrimary,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.accentIndigo,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: () => _sendMessage(_textController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        child: Column(
          crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: msg.isUser ? AppTheme.accentIndigo : AppTheme.bgSecondary,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: msg.isUser ? const Radius.circular(0) : const Radius.circular(16),
                  bottomLeft: !msg.isUser ? const Radius.circular(0) : const Radius.circular(16),
                ),
                border: msg.isUser ? null : Border.all(color: Colors.white10),
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: msg.isUser ? Colors.white : AppTheme.textPrimary,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),

            // Chips interactivos de acción si la respuesta los incluye
            if (msg.chips != null && msg.chips!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: msg.chips!.map((chip) {
                  final label = chip['label'] ?? 'Acción';
                  final isAddCart = chip['action'] == 'add_to_cart';
                  return ActionChip(
                    avatar: isAddCart ? const Icon(Icons.add_shopping_cart, size: 14, color: Colors.white) : null,
                    label: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isAddCart ? Colors.white : AppTheme.accentIndigo,
                      ),
                    ),
                    backgroundColor: isAddCart ? const Color(0xFF10B981) : AppTheme.accentIndigo.withOpacity(0.15),
                    side: BorderSide(
                      color: isAddCart ? const Color(0xFF10B981) : AppTheme.accentIndigo,
                    ),
                    onPressed: () => _handleChipAction(chip),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
