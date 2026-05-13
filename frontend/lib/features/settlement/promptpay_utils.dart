import 'dart:convert';

class PromptPayUtils {
  static String generatePayload({
    required String promptpayId,
    required double amount,
  }) {
    final cleanId = promptpayId.replaceAll(RegExp(r'[^0-9]'), '');

    String targetType;
    String targetValue;

    if (cleanId.length == 10) {
      // Mobile Number -> Tag 01
      targetType = '01';
      targetValue = '0066${cleanId.substring(1)}';
    } else if (cleanId.length == 13) {
      // National ID -> Tag 02
      targetType = '02';
      targetValue = cleanId;
    } else if (cleanId.length == 15) {
      // E-Wallet -> Tag 03
      targetType = '03';
      targetValue = cleanId;
    } else {
      // Fallback
      targetType = '01';
      targetValue = cleanId;
    }

    final subTag00 = '0016A000000677010111';
    final subTagTarget =
        '$targetType${targetValue.length.toString().padLeft(2, '0')}$targetValue';
    final tag29Value = '$subTag00$subTagTarget';

    final tag00 = '000201';
    final tag01 = '010212'; // Dynamic QR
    final tag29 =
        '29${tag29Value.length.toString().padLeft(2, '0')}$tag29Value';
    final tag53 = '5303764'; // THB

    final amountStr = amount.toStringAsFixed(2);
    final tag54 = '54${amountStr.length.toString().padLeft(2, '0')}$amountStr';
    final tag58 = '5802TH';

    final payloadWithoutCrc = '$tag00$tag01$tag29$tag53$tag54$tag58' + '6304';
    final crc = _crc16(payloadWithoutCrc);

    return '$payloadWithoutCrc$crc';
  }

  static String _crc16(String payload) {
    int crc = 0xFFFF;
    for (int i = 0; i < payload.length; i++) {
      crc ^= payload.codeUnitAt(i) << 8;
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc <<= 1;
        }
      }
    }
    return (crc & 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
