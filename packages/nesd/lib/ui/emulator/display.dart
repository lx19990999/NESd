import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:nesd/nes/region.dart';
import 'package:nesd/ui/emulator/display_controller.dart';
import 'package:nesd/ui/emulator/emulator_painters.dart';
import 'package:nesd/ui/emulator/nes_controller.dart';
import 'package:nesd/ui/settings/settings.dart';

class FrameBufferStreamBuilder extends HookConsumerWidget {
  const FrameBufferStreamBuilder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nes = ref.watch(nesStateProvider);

    if (nes == null) {
      return const SizedBox();
    }

    final controller = ref.watch(displayFrameControllerProvider);

    final frameState = useValueListenable(controller);

    return switch (frameState) {
      TextureDisplayFrameState(:final textureId, :final width, :final height) =>
        DisplayBuilder.texture(
          textureId: textureId,
          imageWidth: width,
          imageHeight: height,
        ),
      ImageDisplayFrameState(:final image) => DisplayBuilder.image(
        image: image,
      ),
      _ => const ColoredBox(color: Colors.black),
    };
  }
}

class DisplayBuilder extends ConsumerWidget {
  const DisplayBuilder._({
    required this.image,
    required this.textureId,
    required this.imageWidth,
    required this.imageHeight,
    super.key,
  });

  factory DisplayBuilder.image({required ui.Image image, Key? key}) {
    return DisplayBuilder._(
      key: key,
      image: image,
      textureId: null,
      imageWidth: image.width,
      imageHeight: image.height,
    );
  }

  factory DisplayBuilder.texture({
    required int textureId,
    required int imageWidth,
    required int imageHeight,
    Key? key,
  }) {
    return DisplayBuilder._(
      key: key,
      image: null,
      textureId: textureId,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  final ui.Image? image;

  final int imageWidth;
  final int imageHeight;

  final int? textureId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final nes = ref.watch(nesStateProvider);

    return LayoutBuilder(
      builder: (_, constraints) {
        final region = nes?.region ?? Region.ntsc;
        final pixelAspectRatio = _calculatePixelAspectRatio(
          settings,
          constraints,
          region,
        );
        final imageAspectRatio = imageWidth / imageHeight;
        final aspectRatio = imageAspectRatio * pixelAspectRatio;

        final effectiveImageWidth = (aspectRatio * imageHeight).round();

        final maxScale = min(
          constraints.maxWidth / effectiveImageWidth,
          constraints.maxHeight / imageHeight,
        );

        final scale = min(
          maxScale,
          _calculateScale(
            settings,
            constraints.maxWidth,
            constraints.maxHeight,
            effectiveImageWidth,
            imageHeight,
          ),
        );

        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        final screenSize = Size(
          effectiveImageWidth.toDouble(),
          imageHeight.toDouble(),
        );

        late final Rect screenRect;
        late final double screenScaleX;
        late final double screenScaleY;
        final portrait = canvasSize.height > canvasSize.width;

        if (settings.stretch) {
          final scaledSize = screenSize * maxScale;
          final center = portrait
              ? Offset(canvasSize.width / 2, scaledSize.height / 2)
              : canvasSize.center(Offset.zero);
          final topLeft =
              center - Offset(scaledSize.width / 2, scaledSize.height / 2);

          screenRect = topLeft & scaledSize;
          screenScaleX = maxScale;
          screenScaleY = maxScale;
        } else {
          final scaledSize = screenSize * scale;
          final center = portrait
              ? Offset(canvasSize.width / 2, scaledSize.height / 2)
              : canvasSize.center(Offset.zero);
          final topLeft =
              center - Offset(scaledSize.width / 2, scaledSize.height / 2);

          screenRect = topLeft & scaledSize;
          screenScaleX = scale;
          screenScaleY = scale;
        }

        final baseLayer = textureId != null
            ? SizedBox.expand(
                child: Texture(
                  textureId: textureId!,
                  filterQuality: FilterQuality.none,
                ),
              )
            : CustomPaint(
                painter: CpuFramePainter(image: image!),
                child: const SizedBox.expand(),
              );

        final overlayLayer = CustomPaint(
          painter: EmulatorOverlayPainter(
            xScale: screenScaleX,
            yScale: screenScaleY,
            showBorder: settings.showBorder,
            paused: nes?.paused ?? false,
            fastForward: nes?.fastForward ?? false,
            rewind: nes?.rewind ?? false,
            crossHairPosition:
                nes?.bus.cartridge.databaseEntry?.hasZapper == true
                ? nes?.bus.zapperPosition
                : null,
          ),
          child: const SizedBox.expand(),
        );

        final screen = SizedBox(
          width: screenRect.width,
          height: screenRect.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: baseLayer),
              overlayLayer,
            ],
          ),
        );

        final child = Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(child: ColoredBox(color: Colors.black)),
            Positioned(
              left: screenRect.left,
              top: screenRect.top,
              width: screenRect.width,
              height: screenRect.height,
              child: screen,
            ),
          ],
        );

        return ConstrainedBox(
          constraints: constraints,
          child: ClipRect(
            child: MouseRegion(
              onHover: (event) {
                final displayPosition =
                    event.localPosition - screenRect.topLeft;
                final nesPosition = Offset(
                  displayPosition.dx / screenScaleX,
                  displayPosition.dy / screenScaleY,
                );

                if (!screenSize.contains(nesPosition)) {
                  nes?.bus.zapperPosition = null;
                } else {
                  nes?.bus.zapperPosition = nesPosition;
                }
              },
              child: GestureDetector(
                onTapDown: (details) {
                  final displayPosition =
                      details.localPosition - screenRect.topLeft;
                  final nesPosition = Offset(
                    displayPosition.dx / screenScaleX,
                    displayPosition.dy / screenScaleY,
                  );

                  if (!screenSize.contains(nesPosition)) {
                    return;
                  }

                  nes?.bus.zapperPosition = nesPosition;
                  nes?.bus.zapperPull();
                },
                onTapUp: (details) {
                  final displayPosition =
                      details.localPosition - screenRect.topLeft;
                  final nesPosition = Offset(
                    displayPosition.dx / screenScaleX,
                    displayPosition.dy / screenScaleY,
                  );

                  if (screenSize.contains(nesPosition)) {
                    nes?.bus.zapperPosition = nesPosition;
                  }

                  nes?.bus.zapperRelease();
                },
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  double _calculateScale(
    Settings settings,
    double width,
    double height,
    int imageWidth,
    int imageHeight,
  ) {
    return switch (settings.scaling) {
      .x1 => 1.0,
      .x2 => 2.0,
      .x3 => 3.0,
      .x4 => 4.0,
      .autoInteger => max(
        0.5,
        min(width ~/ imageWidth, height ~/ imageHeight),
      ).toDouble(),
      .autoSmooth => 1000,
    };
  }

  double _calculatePixelAspectRatio(
    Settings settings,
    BoxConstraints constraints,
    Region region,
  ) {
    return switch (settings.pixelAspectRatio) {
      .auto => switch (region) {
        .ntsc => 8 / 7,
        .pal => 11 / 8,
      },
      .ntsc => 8 / 7,
      .pal => 11 / 8,
      .square => 1,
      .stretch => constraints.maxWidth / constraints.maxHeight,
      .custom => settings.customPixelAspectRatio,
    };
  }
}
