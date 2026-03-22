import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_zpl_printer/flutter_zpl_printer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('FlutterZplPrinter can be instantiated', () {
    final printer = FlutterZplPrinter();
    expect(printer, isNotNull);
    printer.dispose();
  });
}
