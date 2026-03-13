import 'package:flutter/services.dart';

/// Formata campos monetários no padrão brasileiro (1.500,00).
/// - Aceita apenas dígitos e vírgula (ponto é convertido para vírgula).
/// - Adiciona ponto como separador de milhar automaticamente.
/// - Limita a 2 casas decimais.
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;

    // Converte ponto para vírgula (teclados numéricos que usam ponto)
    text = text.replaceAll('.', ',');

    // Mantém apenas dígitos e no máximo uma vírgula (máx 2 casas decimais)
    final buffer = StringBuffer();
    bool hasComma = false;
    int digitsAfterComma = 0;
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == ',' && !hasComma) {
        hasComma = true;
        buffer.write(char);
      } else if (RegExp(r'\d').hasMatch(char)) {
        if (hasComma) {
          if (digitsAfterComma < 2) {
            buffer.write(char);
            digitsAfterComma++;
          }
        } else {
          buffer.write(char);
        }
      }
    }

    text = buffer.toString();
    final commaIndex = text.indexOf(',');
    final intPart = commaIndex >= 0 ? text.substring(0, commaIndex) : text;
    final suffix = commaIndex >= 0 ? text.substring(commaIndex) : '';

    // Adiciona separadores de milhar na parte inteira
    final formattedInt = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        formattedInt.write('.');
      }
      formattedInt.write(intPart[i]);
    }

    final result = formattedInt.toString() + suffix;
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

/// Converte double para string formatada para campos de texto (ex: 1500.0 → "1.500,00").
String formatarValorParaCampo(double valor) {
  final parts = valor.toStringAsFixed(2).split('.');
  final intPart = parts[0];
  final decPart = parts[1];
  final buffer = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write('.');
    buffer.write(intPart[i]);
  }
  return '${buffer.toString()},$decPart';
}

/// Parse de string formatada (ex: "1.500,00") para double.
double? parseCurrency(String text) {
  return double.tryParse(text.replaceAll('.', '').replaceAll(',', '.'));
}
