import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stylestore_mobile/config/theme.dart';

void main() {
  test('elige texto legible cuando el color configurado no contrasta', () {
    const whiteSurface = Color(0xFFFFFFFF);
    const nearlyWhiteText = Color(0xFFF8F8F8);

    final readable = AppTheme.readableOn(
      whiteSurface,
      preferred: nearlyWhiteText,
    );

    expect(AppTheme.contrastRatio(whiteSurface, readable),
        greaterThanOrEqualTo(4.5));
  });

  test('conserva el color configurado cuando supera contraste AA', () {
    const darkSurface = Color(0xFF00112E);
    const whiteText = Color(0xFFFFFFFF);

    expect(AppTheme.readableOn(darkSurface, preferred: whiteText), whiteText);
    expect(AppTheme.contrastRatio(darkSurface, whiteText),
        greaterThanOrEqualTo(4.5));
  });
}
