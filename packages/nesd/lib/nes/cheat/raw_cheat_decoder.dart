// ignore_for_file: avoid_classes_with_only_static_members

import 'package:nesd/nes/cheat/cheat.dart';

class RawCheatDecoder {
  static final _pattern = RegExp(
    r'^\s*([0-9A-Fa-f]{4})\s*-\s*([0-9A-Fa-f]{2})\s*-\s*([0-9A-Fa-f]{2})\s*$',
  );

  static Cheat? decode(String code, {String? name}) {
    final match = _pattern.firstMatch(code);

    if (match == null) {
      return null;
    }

    final address = int.parse(match.group(1)!, radix: 16);
    final length = int.parse(match.group(2)!, radix: 16);
    final value = int.parse(match.group(3)!, radix: 16);
    final normalizedCode =
        '${match.group(1)!.toUpperCase()}-'
        '${match.group(2)!.toUpperCase()}-'
        '${match.group(3)!.toUpperCase()}';

    if (length != 0x01) {
      return null;
    }

    return Cheat(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name ?? normalizedCode,
      type: CheatType.raw,
      address: address,
      value: value,
      code: normalizedCode,
    );
  }
}
