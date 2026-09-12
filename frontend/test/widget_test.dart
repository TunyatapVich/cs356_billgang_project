import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cs356_billgang/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    dotenv.loadFromString(envString: 'API_BASE_URL=https://billgang.onrender.com\n');
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(MyApp), findsOneWidget);
  });
}
