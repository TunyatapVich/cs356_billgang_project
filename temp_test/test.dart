import 'package:thaiqr/thaiqr.dart';

void main() {
  final generator = ThaiQRGenerator();
  try {
    print("Test 1 (double): " + generator.generateCodeFromMobileOrId('0843654067', 10.50));
  } catch(e) { print("Error 1: $e"); }
}
