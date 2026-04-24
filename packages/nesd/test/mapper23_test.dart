import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nesd/nes/cartridge/cartridge_factory.dart';
import 'package:nesd/ui/file_picker/file_system/filesystem_file.dart';

import 'ui/mocks.dart';

void main() {
  test('CartridgeFactory accepts iNES mapper 23 ROMs', () {
    final rom = Uint8List(16 + 8 * 0x4000 + 16 * 0x2000)
      ..[0] = 0x4e
      ..[1] = 0x45
      ..[2] = 0x53
      ..[3] = 0x1a
      ..[4] = 0x08
      ..[5] = 0x10
      ..[6] = 0x70
      ..[7] = 0x10;

    final cartridge = CartridgeFactory(database: MockNesDatabase()).fromFile(
      const FilesystemFile(
        path: '/tmp/contra_mapper23.nes',
        name: 'contra_mapper23.nes',
        type: FilesystemFileType.file,
      ),
      rom,
    );

    expect(cartridge.mapper.id, equals(23));
    expect(cartridge.mapper.name, contains('VRC'));
  });
}
