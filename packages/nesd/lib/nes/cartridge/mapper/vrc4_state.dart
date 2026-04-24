import 'package:binarize/binarize.dart';
import 'package:nesd/exception/invalid_serialization_version.dart';
import 'package:nesd/nes/cartridge/mapper/mapper_state.dart';

class VRC4State extends MapperState {
  const VRC4State({
    required this.prgBank0,
    required this.prgBank1,
    required this.chrBanks,
    required this.swapMode,
    required this.wramEnabled,
    required this.mirroring,
    required this.vrc4Mode,
    required this.vrc2Latch,
    required this.irqLatch,
    required this.irqCounter,
    required this.irqPrescaler,
    required this.irqMode,
    required this.irqEnabled,
    required this.irqEnableAfterAck,
    super.id = 23,
  });

  factory VRC4State.deserialize(PayloadReader reader) {
    final version = reader.get(uint8);

    return switch (version) {
      0 => VRC4State._version0(reader),
      1 => VRC4State._version1(reader),
      _ => throw InvalidSerializationVersion('VRC4', version),
    };
  }

  factory VRC4State._version0(PayloadReader reader) {
    return VRC4State(
      prgBank0: reader.get(uint8),
      prgBank1: reader.get(uint8),
      chrBanks: [for (var i = 0; i < 8; i++) reader.get(uint16)],
      swapMode: reader.get(uint8),
      wramEnabled: reader.get(boolean),
      mirroring: reader.get(uint8),
      vrc4Mode: true,
      vrc2Latch: 0,
      irqLatch: reader.get(uint8),
      irqCounter: reader.get(uint8),
      irqPrescaler: reader.get(uint16),
      irqMode: reader.get(boolean),
      irqEnabled: reader.get(boolean),
      irqEnableAfterAck: reader.get(boolean),
    );
  }

  factory VRC4State._version1(PayloadReader reader) {
    return VRC4State(
      prgBank0: reader.get(uint8),
      prgBank1: reader.get(uint8),
      chrBanks: [for (var i = 0; i < 8; i++) reader.get(uint16)],
      swapMode: reader.get(uint8),
      wramEnabled: reader.get(boolean),
      mirroring: reader.get(uint8),
      vrc4Mode: reader.get(boolean),
      vrc2Latch: reader.get(uint8),
      irqLatch: reader.get(uint8),
      irqCounter: reader.get(uint8),
      irqPrescaler: reader.get(uint16),
      irqMode: reader.get(boolean),
      irqEnabled: reader.get(boolean),
      irqEnableAfterAck: reader.get(boolean),
    );
  }

  final int prgBank0;
  final int prgBank1;
  final List<int> chrBanks;
  final int swapMode;
  final bool wramEnabled;
  final int mirroring;
  final bool vrc4Mode;
  final int vrc2Latch;
  final int irqLatch;
  final int irqCounter;
  final int irqPrescaler;
  final bool irqMode;
  final bool irqEnabled;
  final bool irqEnableAfterAck;

  @override
  void serialize(PayloadWriter writer) {
    super.serialize(writer);

    writer
      ..set(uint8, 1)
      ..set(uint8, prgBank0)
      ..set(uint8, prgBank1);

    for (final bank in chrBanks) {
      writer.set(uint16, bank);
    }

    writer
      ..set(uint8, swapMode)
      ..set(boolean, wramEnabled)
      ..set(uint8, mirroring)
      ..set(boolean, vrc4Mode)
      ..set(uint8, vrc2Latch)
      ..set(uint8, irqLatch)
      ..set(uint8, irqCounter)
      ..set(uint16, irqPrescaler)
      ..set(boolean, irqMode)
      ..set(boolean, irqEnabled)
      ..set(boolean, irqEnableAfterAck);
  }
}
