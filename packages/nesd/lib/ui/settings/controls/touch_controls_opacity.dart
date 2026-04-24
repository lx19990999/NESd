import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nesd/ui/settings/shared_preferences.dart';

const _touchControlsOpacityKey = 'touchControlsOpacity';

final touchControlsOpacityProvider =
    NotifierProvider<TouchControlsOpacityController, double>(
      TouchControlsOpacityController.new,
    );

class TouchControlsOpacityController extends Notifier<double> {
  @override
  double build() {
    final preferences = ref.watch(sharedPreferencesProvider);
    final stored = preferences.getDouble(_touchControlsOpacityKey) ?? 1.0;

    return stored.clamp(0.15, 1.0);
  }

  void setOpacity(double opacity) {
    final next = opacity.clamp(0.15, 1.0);

    state = next;
    ref
        .read(sharedPreferencesProvider)
        .setDouble(_touchControlsOpacityKey, next);
  }
}
