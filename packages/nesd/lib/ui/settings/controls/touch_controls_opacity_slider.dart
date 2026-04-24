import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nesd/ui/common/focus_on_hover.dart';
import 'package:nesd/ui/common/settings_tile.dart';
import 'package:nesd/ui/settings/controls/touch_controls_opacity.dart';

class TouchControlsOpacitySlider extends ConsumerWidget {
  const TouchControlsOpacitySlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opacity = ref.watch(touchControlsOpacityProvider);
    final controller = ref.read(touchControlsOpacityProvider.notifier);

    return FocusOnHover(
      child: SettingsTile(
        title: const Text('Touch Controls Opacity'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Slider(
            value: opacity,
            min: 0.15,
            divisions: 17,
            label: '${(opacity * 100).round()}%',
            onChanged: controller.setOpacity,
          ),
        ),
      ),
    );
  }
}
