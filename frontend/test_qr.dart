// ignore_for_file: avoid_print
import 'package:thaiqr/thaiqr.dart';

void main() {
  final generator = ThaiQRGenerator();
  final payload = generator.generateCodeFromMobileOrId(
    '0843654067',
    10.50.toString(),
  );
  print(payload);
}
