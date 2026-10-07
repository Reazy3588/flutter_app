import 'package:flutter_test/flutter_test.dart';

import 'package:ecommerce_app/main.dart';

void main() {
  testWidgets('app shows the splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const EcommerceApp());

    expect(find.text('ShopEase'), findsOneWidget);
    expect(find.text('Your one-stop online store'), findsOneWidget);
  });
}
