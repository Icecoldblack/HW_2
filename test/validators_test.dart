import 'package:flutter_test/flutter_test.dart';
import 'package:message_board/screens/login_screen.dart';

void main() {
  group('validateEmail', () {
    test('rejects empty', () => expect(validateEmail(''), isNotNull));
    test('rejects missing @', () => expect(validateEmail('ada.test.dev'), isNotNull));
    test('rejects missing domain dot', () => expect(validateEmail('ada@test'), isNotNull));
    test('accepts valid', () => expect(validateEmail('ada@test.dev'), isNull));
    test('trims spaces', () => expect(validateEmail('  ada@test.dev '), isNull));
  });
}
