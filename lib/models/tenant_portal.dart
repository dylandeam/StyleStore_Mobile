import 'package:flutter/material.dart';

class TenantPortal {
  const TenantPortal({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.nombreMarca,
    this.eslogan,
    this.logoUrl,
    required this.colorPrimario,
    required this.colorSecundario,
    required this.colorAcento,
    required this.colorFondo,
    required this.colorTexto,
    this.colorTextoContraste = '#FFFFFF',
  });

  final int id;
  final String codigo;
  final String nombre;
  final String nombreMarca;
  final String? eslogan;
  final String? logoUrl;
  final String colorPrimario;
  final String colorSecundario;
  final String colorAcento;
  final String colorFondo;
  final String colorTexto;
  final String colorTextoContraste;

  factory TenantPortal.fromJson(Map<String, dynamic> json) => TenantPortal(
        id: int.parse(json['id'].toString()),
        codigo: json['codigo'].toString(),
        nombre: json['nombre'].toString(),
        nombreMarca: (json['nombre_marca'] ?? json['nombre']).toString(),
        eslogan: json['eslogan']?.toString(),
        logoUrl: json['logo_url']?.toString(),
        colorPrimario: (json['color_primario'] ?? '#14263D').toString(),
        colorSecundario: (json['color_secundario'] ?? '#FBF8F1').toString(),
        colorAcento: (json['color_acento'] ?? '#274C77').toString(),
        colorFondo: (json['color_fondo'] ?? '#EEE7D8').toString(),
        colorTexto: (json['color_texto'] ?? '#172536').toString(),
        colorTextoContraste:
            (json['color_texto_contraste'] ?? '#FFFFFF').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'codigo': codigo,
        'nombre': nombre,
        'nombre_marca': nombreMarca,
        'eslogan': eslogan,
        'logo_url': logoUrl,
        'color_primario': colorPrimario,
        'color_secundario': colorSecundario,
        'color_acento': colorAcento,
        'color_fondo': colorFondo,
        'color_texto': colorTexto,
        'color_texto_contraste': colorTextoContraste,
      };

  Color get primaryColor => _parseColor(colorPrimario, const Color(0xFF14263D));
  Color get secondaryColor =>
      _parseColor(colorSecundario, const Color(0xFFFBF8F1));
  Color get accentColor => _parseColor(colorAcento, const Color(0xFF274C77));
  Color get backgroundColor => _parseColor(colorFondo, const Color(0xFFEEE7D8));
  Color get textColor => _parseColor(colorTexto, const Color(0xFF172536));
  Color get contrastTextColor => _parseColor(colorTextoContraste, Colors.white);

  static Color _parseColor(String value, Color fallback) {
    final normalized = value.replaceFirst('#', '');
    final parsed = int.tryParse(normalized, radix: 16);
    return parsed == null ? fallback : Color(0xFF000000 | parsed);
  }
}
