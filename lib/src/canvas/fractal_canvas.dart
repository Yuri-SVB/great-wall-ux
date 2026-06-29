import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/sound_board.dart';
import '../gestures/pan_zoom_controller.dart';
import '../gestures/select_mode.dart';
import '../palette/palette.dart';
import '../render/brightness_controller.dart';
import '../stages/stage.dart';
import 'canvas_painter.dart';
import 'escape_count_source.dart';
import 'overlay.dart';
import 'viewport.dart';
import 'viewport_math.dart';

/// Asset key for the fractal colour shader. Package-qualified so it resolves
/// when great_wall_ux is consumed as a dependency.
const String _shaderAsset = 'packages/great_wall_ux/shaders/fractal.frag';

/// The fractal canvas widget — the central surface of the UX library.
///
/// Renders an escape-count raster supplied by `great-wall-core` (through an
/// [EscapeCountSource]) via a GPU fragment shader that applies the fixed log
/// transform, the [Palette] lookup, and the brightness falloff. Overlays for
/// markers, crosshairs, and — in debug mode only — bisection rectangles are
/// composited on top.
///
/// Gesture handling unifies pointer, touch, mouse, and trackpad through
/// Flutter's gesture arena. Tap dispatches a select-mode event. Scroll zooms;
/// `L` + scroll adjusts brightness (a tacit, never-displayed control).
///
/// Keyboard shortcuts are intentionally *not* handled here: a consuming app
/// owns keyboard focus and routes shortcuts itself (the wallet app binds
/// `V` + Up/Down to [SoundBoard] volume, for instance). The library's job is
/// to render and to expose the controllers the host drives.
///
/// Accessibility: the canvas is a single opaque interactive node with no
/// inner content description, deliberately.
class FractalCanvas extends StatefulWidget {
  const FractalCanvas({
    super.key,
    required this.source,
    required this.controller,
    required this.palette,
    required this.stage,
    this.brightness,
    this.stageParameters,
    this.maxIterations = 256,
    this.overlays = CanvasOverlays.empty,
    this.onSelect,
    this.sounds,
    this.debugBisectionOverlay = false,
    this.semanticLabel,
    this.backPressure = const BackPressureConfig(),
  }) : assert(
          stage == Stage.stage2 || stageParameters == null,
          'stage1 does not take StageParameters',
        );

  final EscapeCountSource source;
  final PanZoomController controller;
  final Palette palette;
  final Stage stage;

  /// Brightness offset controller. If null, the widget owns an internal one
  /// reset to the session default; the offset is never persisted either way.
  final BrightnessController? brightness;

  final StageParameters? stageParameters;
  final int maxIterations;
  final CanvasOverlays overlays;
  final ValueChanged<FractalSelection>? onSelect;

  /// Optional UI sound board. When supplied, a tap on the canvas plays the
  /// [UiSound.click] cue (the "sonoplasty for clicking"). Selection-outcome
  /// cues (select/confirm/deny) are dispatched by the consuming app from its
  /// [onSelect] handler, where the decode result is known.
  final SoundBoard? sounds;

  final bool debugBisectionOverlay;
  final String? semanticLabel;
  final BackPressureConfig backPressure;

  @override
  State<FractalCanvas> createState() => _FractalCanvasState();
}

/// Render back-pressure: low-res then refine. See `TECH_STACK.md`
/// §"Locked sub-decisions / Render back-pressure".
@immutable
class BackPressureConfig {
  const BackPressureConfig({
    this.lowResDivisor = 2,
    this.fullResDelay = const Duration(milliseconds: 80),
  });
  final int lowResDivisor;
  final Duration fullResDelay;
}

class _FractalCanvasState extends State<FractalCanvas> {
  ui.FragmentShader? _shader;
  ui.Image? _countsImage;
  ui.Image? _paletteImage;
  EscapeCountRequest? _inFlight;
  Timer? _refineTimer;
  int _requestSeq = 0;
  int _repaintTick = 0;

  BrightnessController? _internalBrightness;
  BrightnessController get _brightness =>
      widget.brightness ?? (_internalBrightness ??= BrightnessController());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onViewportChanged);
    _brightness.addListener(_onUniformChanged);
    _loadShader();
    _rebuildPalette();
  }

  @override
  void didUpdateWidget(FractalCanvas old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onViewportChanged);
      widget.controller.addListener(_onViewportChanged);
    }
    if (old.brightness != widget.brightness) {
      (old.brightness ?? _internalBrightness)?.removeListener(_onUniformChanged);
      _brightness.addListener(_onUniformChanged);
    }
    // Compare by id so a consumer that rebuilds with a fresh-but-equal
    // Palette object does not thrash the LUT texture.
    if (old.palette.id != widget.palette.id) {
      _rebuildPalette();
    }
    if (old.stage != widget.stage ||
        old.stageParameters != widget.stageParameters ||
        old.maxIterations != widget.maxIterations) {
      _scheduleRender(immediate: true);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onViewportChanged);
    (widget.brightness ?? _internalBrightness)?.removeListener(_onUniformChanged);
    _internalBrightness?.dispose();
    _refineTimer?.cancel();
    _shader?.dispose();
    _countsImage?.dispose();
    _paletteImage?.dispose();
    super.dispose();
  }

  Future<void> _loadShader() async {
    final ui.FragmentProgram program =
        await ui.FragmentProgram.fromAsset(_shaderAsset);
    if (!mounted) return;
    setState(() => _shader = program.fragmentShader());
  }

  Future<void> _rebuildPalette() async {
    final ui.Image image = await buildPaletteImage(widget.palette);
    if (!mounted) {
      image.dispose();
      return;
    }
    setState(() {
      _paletteImage?.dispose();
      _paletteImage = image;
      _repaintTick++;
    });
  }

  void _onViewportChanged() => _scheduleRender();

  // Brightness change: repaint with a new uniform, but do NOT recompute
  // escape counts — that is the whole point of colouring on the GPU.
  void _onUniformChanged() => setState(() => _repaintTick++);

  void _scheduleRender({bool immediate = false}) {
    final FractalViewport vp = widget.controller.viewport;
    final int divisor = math.max(1, widget.backPressure.lowResDivisor);
    final FractalViewport low = vp.copyWith(
      widthPx: math.max(1, vp.widthPx ~/ divisor),
      heightPx: math.max(1, vp.heightPx ~/ divisor),
    );
    _kick(low);
    _refineTimer?.cancel();
    _refineTimer = Timer(
      immediate ? Duration.zero : widget.backPressure.fullResDelay,
      () => _kick(vp),
    );
  }

  Future<void> _kick(FractalViewport vp) async {
    final int seq = ++_requestSeq;
    final EscapeCountRequest req = EscapeCountRequest(
      viewport: vp,
      stage: widget.stage,
      stageParameters: widget.stageParameters,
      maxIterations: widget.maxIterations,
    );
    if (req == _inFlight) return;
    _inFlight = req;
    final EscapeCountRaster r = await widget.source.escapeCounts(req);
    if (!mounted || seq != _requestSeq) return;
    final ui.Image image = await packEscapeCounts(
      widthPx: r.widthPx,
      heightPx: r.heightPx,
      counts: r.counts,
      maxIterations: widget.maxIterations,
    );
    if (!mounted || seq != _requestSeq) {
      image.dispose();
      return;
    }
    setState(() {
      _countsImage?.dispose();
      _countsImage = image;
      _repaintTick++;
    });
  }

  ui.FragmentShader? _configuredShader(double widthPx, double heightPx) {
    final ui.FragmentShader? sh = _shader;
    final ui.Image? counts = _countsImage;
    final ui.Image? palette = _paletteImage;
    if (sh == null || counts == null || palette == null) return null;

    final double zoom =
        kReferenceHalfExtent / widget.controller.viewport.halfExtent;
    sh.setFloat(0, widthPx);
    sh.setFloat(1, heightPx);
    sh.setFloat(2, widget.maxIterations.toDouble());
    sh.setFloat(3, kBrightnessFalloffBase);
    sh.setFloat(4, _brightness.offset);
    sh.setFloat(5, zoom);
    sh.setImageSampler(0, counts);
    sh.setImageSampler(1, palette);
    return sh;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 1.0;
        final int wpx = constraints.maxWidth.floor();
        final int hpx = constraints.maxHeight.floor();
        if (wpx > 0 &&
            hpx > 0 &&
            (wpx != widget.controller.viewport.widthPx ||
                hpx != widget.controller.viewport.heightPx ||
                dpr != widget.controller.viewport.devicePixelRatio)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.controller.resize(widthPx: wpx, heightPx: hpx, dpr: dpr);
          });
        }

        return Semantics(
          label: widget.semanticLabel,
          container: true,
          explicitChildNodes: false,
          enabled: widget.onSelect != null,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: widget.onSelect == null ? null : _handleTap,
            onScaleStart: (_) {},
            onScaleUpdate: _handleScale,
            child: Listener(
              onPointerSignal: _handlePointerSignal,
              child: CustomPaint(
                painter: FractalCanvasPainter(
                  viewport: widget.controller.viewport,
                  shader: _configuredShader(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  ),
                  overlays: widget.overlays,
                  debugBisectionOverlay: widget.debugBisectionOverlay,
                  repaintTick: _repaintTick,
                ),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(TapUpDetails details) {
    widget.sounds?.play(UiSound.click);
    final ViewportMath m = ViewportMath(widget.controller.viewport);
    final Offset p = details.localPosition;
    final (double re, double im) = m.pixelToCoord(p.dx, p.dy);
    widget.onSelect?.call(
      FractalSelection(re: re, im: im, pixelX: p.dx, pixelY: p.dy),
    );
  }

  void _handleScale(ScaleUpdateDetails details) {
    if (details.scale != 1.0) {
      widget.controller.zoomBy(
        details.scale,
        fx: details.localFocalPoint.dx,
        fy: details.localFocalPoint.dy,
      );
    }
    if (details.focalPointDelta != Offset.zero) {
      widget.controller.panByPixels(
        details.focalPointDelta.dx,
        details.focalPointDelta.dy,
      );
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final bool lHeld =
        HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.keyL);
    if (lHeld) {
      // Tacit brightness adjustment. Scroll up brightens the lit band.
      _brightness.adjustBySteps(event.scrollDelta.dy < 0 ? 1.0 : -1.0);
    } else {
      final double factor = event.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1;
      widget.controller.zoomBy(
        factor,
        fx: event.localPosition.dx,
        fy: event.localPosition.dy,
      );
    }
  }
}
