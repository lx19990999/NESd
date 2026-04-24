import 'package:flutter_test/flutter_test.dart';
import 'package:nesd/nes/cheat/cheat.dart';
import 'package:nesd/nes/cheat/raw_cheat_decoder.dart';

void main() {
  group('RawCheatDecoder', () {
    test('decodes raw cheats in address-length-value format', () {
      final cheat = RawCheatDecoder.decode('0032-01-64', name: 'Lives');

      expect(cheat, isNotNull);
      expect(cheat!.name, equals('Lives'));
      expect(cheat.type, equals(CheatType.raw));
      expect(cheat.address, equals(0x0032));
      expect(cheat.value, equals(0x64));
      expect(cheat.compareValue, isNull);
      expect(cheat.code, equals('0032-01-64'));
    });

    test('accepts lowercase hex and surrounding whitespace', () {
      final cheat = RawCheatDecoder.decode('  00b0-01-ff  ');

      expect(cheat, isNotNull);
      expect(cheat!.address, equals(0x00B0));
      expect(cheat.value, equals(0xFF));
      expect(cheat.code, equals('00B0-01-FF'));
    });

    test('rejects unsupported multi-byte raw cheats', () {
      expect(RawCheatDecoder.decode('0032-02-6464'), isNull);
    });

    test('rejects invalid formats', () {
      expect(RawCheatDecoder.decode('0032:64'), isNull);
      expect(RawCheatDecoder.decode('ZZZZ-01-64'), isNull);
      expect(RawCheatDecoder.decode('0032-00-64'), isNull);
    });
  });
}
