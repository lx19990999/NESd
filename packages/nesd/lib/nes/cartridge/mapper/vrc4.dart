import 'dart:typed_data';

import 'package:nesd/nes/cartridge/cartridge.dart';
import 'package:nesd/nes/cartridge/mapper/mapper.dart';
import 'package:nesd/nes/cartridge/mapper/vrc4_state.dart';
import 'package:nesd/nes/cpu/irq_source.dart';
import 'package:nesd/util/runtime_debug_log.dart';

class VRC4 extends Mapper {
  VRC4([super.id = 23]);

  @override
  String name = 'VRC2b/VRC4';

  @override
  int prgRomPageSize = 0x2000;

  @override
  int chrPageSize = 0x0400;

  int _prgBank0 = 0;
  int _prgBank1 = 1;
  final List<int> _chrBanks = List.generate(8, (index) => index);

  int _swapMode = 0;
  bool _wramEnabled = true;
  int _mirroring = 0;
  bool _vrc4Mode = false;
  int _vrc2Latch = 0;

  int _irqLatch = 0;
  int _irqCounter = 0;
  int _irqPrescaler = 341;
  bool _irqMode = false;
  bool _irqEnabled = false;
  bool _irqEnableAfterAck = false;
  int _debugWriteLogsRemaining = 128;
  int _debugReadLogsRemaining = 64;

  @override
  VRC4State get state => VRC4State(
    id: id,
    prgBank0: _prgBank0,
    prgBank1: _prgBank1,
    chrBanks: _chrBanks,
    swapMode: _swapMode,
    wramEnabled: _wramEnabled,
    mirroring: _mirroring,
    vrc4Mode: _vrc4Mode,
    vrc2Latch: _vrc2Latch,
    irqLatch: _irqLatch,
    irqCounter: _irqCounter,
    irqPrescaler: _irqPrescaler,
    irqMode: _irqMode,
    irqEnabled: _irqEnabled,
    irqEnableAfterAck: _irqEnableAfterAck,
  );

  @override
  set state(covariant VRC4State state) {
    _prgBank0 = state.prgBank0;
    _prgBank1 = state.prgBank1;

    for (var i = 0; i < _chrBanks.length; i++) {
      _chrBanks[i] = state.chrBanks[i];
    }

    _swapMode = state.swapMode;
    _wramEnabled = state.wramEnabled;
    _mirroring = state.mirroring;
    _vrc4Mode = state.vrc4Mode;
    _vrc2Latch = state.vrc2Latch;
    _irqLatch = state.irqLatch;
    _irqCounter = state.irqCounter;
    _irqPrescaler = state.irqPrescaler;
    _irqMode = state.irqMode;
    _irqEnabled = state.irqEnabled;
    _irqEnableAfterAck = state.irqEnableAfterAck;

    _updateState();
  }

  @override
  void reset() {
    super.reset();

    _prgBank0 = 0;
    _prgBank1 = 1;

    for (var i = 0; i < _chrBanks.length; i++) {
      _chrBanks[i] = i;
    }

    _swapMode = 0;
    _wramEnabled = true;
    _vrc4Mode = false;
    _vrc2Latch = 0;
    _mirroring = switch (cartridge.nametableLayout) {
      NametableLayout.vertical => 0,
      NametableLayout.horizontal => 1,
      NametableLayout.singleLower => 2,
      NametableLayout.singleUpper => 3,
      NametableLayout.four => 0,
    };

    _irqLatch = 0;
    _irqCounter = 0;
    _irqPrescaler = 341;
    _irqMode = false;
    _irqEnabled = false;
    _irqEnableAfterAck = false;
    _debugWriteLogsRemaining = 128;
    _debugReadLogsRemaining = 64;

    bus.clearIrq(IrqSource.mapper);

    runtimeDebugLog('mapper23_reset mode=VRC2');

    _updateState();
  }

  @override
  void step() {
    if (!_vrc4Mode || !_irqEnabled) {
      return;
    }

    if (_irqMode) {
      _clockIrqCounter();

      return;
    }

    _irqPrescaler -= 3;

    if (_irqPrescaler <= 0) {
      _irqPrescaler += 341;
      _clockIrqCounter();
    }
  }

  @override
  int cpuRead(int address, {bool disableSideEffects = false}) {
    if (!_vrc4Mode && address >= 0x6000 && address < 0x8000) {
      final value = (address >> 8 & 0xf0) | _vrc2Latch;

      if (_debugReadLogsRemaining > 0) {
        _debugReadLogsRemaining--;
        runtimeDebugLog(
          'mapper23_vrc2_read '
          'address=0x${address.toRadixString(16)} '
          'value=0x${value.toRadixString(16)} latch=$_vrc2Latch',
        );
      }

      return value;
    }

    return super.cpuRead(address, disableSideEffects: disableSideEffects);
  }

  @override
  void cpuWrite(int address, int value) {
    if (!_vrc4Mode && address >= 0x6000 && address < 0x7000) {
      _vrc2Latch = value & 0x01;
      runtimeDebugLog(
        'mapper23_vrc2_latch '
        'address=0x${address.toRadixString(16)} '
        'value=$value latch=$_vrc2Latch',
      );

      return;
    }

    super.cpuWrite(address, value);

    if (address < 0x8000) {
      return;
    }

    final register = _decodeRegister(address);

    if (register == null) {
      return;
    }

    _debugLogWrite(address, value, register);

    switch (address & 0xf000) {
      case 0x8000:
        _prgBank0 = value & 0x1f;
        _updatePrgPages();
      case 0x9000:
        _write9xxx(register, value);
      case 0xa000:
        _prgBank1 = value & 0x1f;
        _updatePrgPages();
      case 0xb000:
      case 0xc000:
      case 0xd000:
      case 0xe000:
        _writeChrBank(address, register, value);
      case 0xf000:
        _writeIrq(register, value);
    }
  }

  void _write9xxx(int register, int value) {
    switch (register) {
      case 0:
      case 1:
      case 2:
      case 3:
        _mirroring = _vrc4Mode ? (value & 0x03) : (value & 0x01);
        _updateMirroring();
        if (_vrc4Mode && register == 2) {
          _swapMode = (value >> 1) & 0x01;
          _wramEnabled = (value & 0x01) == 0x01;
          _updatePrgPages();
          _updateWram();
        }
    }
  }

  void _writeChrBank(int address, int register, int value) {
    final region = ((address >> 12) & 0x0f) - 0x0b;
    final bankIndex = region * 2 + (register >> 1);
    final current = _chrBanks[bankIndex];

    _chrBanks[bankIndex] = switch (register & 0x01) {
      0 => (current & 0x1f0) | (value & 0x0f),
      _ =>
        ((_vrc4Mode ? (value & 0x1f) : (value & 0x0f)) << 4) | (current & 0x0f),
    };

    _updateChrPages();
  }

  void _writeIrq(int register, int value) {
    _setVrc4Mode();

    switch (register) {
      case 0:
        _irqLatch = (_irqLatch & 0xf0) | (value & 0x0f);
      case 1:
        _irqLatch = ((value & 0x0f) << 4) | (_irqLatch & 0x0f);
      case 2:
        _irqMode = (value & 0x04) != 0;
        _irqEnableAfterAck = (value & 0x01) != 0;
        _irqEnabled = (value & 0x02) != 0;
        _irqPrescaler = 341;
        bus.clearIrq(IrqSource.mapper);

        if (_irqEnabled) {
          _irqCounter = _irqLatch;
        }
      case 3:
        bus.clearIrq(IrqSource.mapper);
        _irqEnabled = _irqEnableAfterAck;
    }
  }

  int? _decodeRegister(int address) {
    final low = address & 0x0f;

    return switch (low) {
      0x0 || 0x1 || 0x2 || 0x3 => low,
      0x4 => 1,
      0x8 => 2,
      0xc => 3,
      _ => null,
    };
  }

  void _debugLogWrite(int address, int value, int register) {
    if (_debugWriteLogsRemaining <= 0) {
      return;
    }

    _debugWriteLogsRemaining--;

    runtimeDebugLog(
      'mapper23_write '
      'addr=0x${address.toRadixString(16)} '
      'reg=$register value=0x${value.toRadixString(16)} '
      'mode=${_vrc4Mode ? 'VRC4' : 'VRC2'} '
      'prg0=$_prgBank0 prg1=$_prgBank1 mirroring=$_mirroring',
    );
  }

  void _setVrc4Mode() {
    if (_vrc4Mode) {
      return;
    }

    _vrc4Mode = true;
    runtimeDebugLog('mapper23_switch mode=VRC4');
    _updateMirroring();
    _updateWram();
  }

  void _clockIrqCounter() {
    if (_irqCounter == 0xff) {
      _irqCounter = _irqLatch;
      bus.triggerIrq(IrqSource.mapper);
    } else {
      _irqCounter = (_irqCounter + 1) & 0xff;
    }
  }

  void _updateState() {
    _updatePrgPages();
    _updateChrPages();
    _updateMirroring();
    _updateWram();
  }

  void _updatePrgPages() {
    switch (_swapMode) {
      case 0:
        mapCpu(0x8000, 0x9fff, _prgBank0);
        mapCpu(0xa000, 0xbfff, _prgBank1);
        mapCpu(0xc000, 0xdfff, -2);
        mapCpu(0xe000, 0xffff, -1);
      case 1:
        mapCpu(0x8000, 0x9fff, -2);
        mapCpu(0xa000, 0xbfff, _prgBank1);
        mapCpu(0xc000, 0xdfff, _prgBank0);
        mapCpu(0xe000, 0xffff, -1);
    }
  }

  void _updateChrPages() {
    for (var i = 0; i < _chrBanks.length; i++) {
      final from = i * 0x0400;
      final to = from + 0x03ff;

      mapPpu(from, to, _chrBanks[i]);
    }
  }

  void _updateMirroring() {
    if (_vrc4Mode) {
      nametableLayout = switch (_mirroring & 0x03) {
        0 => NametableLayout.vertical,
        1 => NametableLayout.horizontal,
        2 => NametableLayout.singleLower,
        _ => NametableLayout.singleUpper,
      };

      return;
    }

    nametableLayout = switch (_mirroring & 0x01) {
      0 => NametableLayout.horizontal,
      _ => NametableLayout.vertical,
    };
  }

  void _updateWram() {
    if (!_vrc4Mode) {
      mapCpu(
        0x6000,
        0x7fff,
        0,
        source: Uint8List(0),
        access: MemoryAccess.none,
      );

      return;
    }

    if (!_wramEnabled) {
      mapCpu(
        0x6000,
        0x7fff,
        0,
        source: Uint8List(0),
        access: MemoryAccess.none,
      );

      return;
    }

    if (cartridge.hasBattery && cartridge.prgSaveRam.isNotEmpty) {
      mapCpu(0x6000, 0x7fff, 0, type: CpuMemoryType.prgSaveRam);

      return;
    }

    if (cartridge.prgRam.isNotEmpty) {
      mapCpu(0x6000, 0x7fff, 0, type: CpuMemoryType.prgRam);
    }
  }
}
