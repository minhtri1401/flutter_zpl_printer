import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('FlutterZplPrinter can be instantiated', (WidgetTester tester) async {
    final FlutterZplPrinter plugin = FlutterZplPrinter();
    expect(plugin, isNotNull);
    plugin.dispose();
  });
}
