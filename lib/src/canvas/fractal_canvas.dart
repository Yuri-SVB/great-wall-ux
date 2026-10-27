import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../audio/sound_board.dart';
import '../gestures/pan_zoom_controller.dart';
import '../gestures/select_mode.dart';
import '../palette/palette.dart';
import '../render/brightness_controller.dart';
import '../render/screen_exposure.dart';
import '../stages/stage.dart';
import 'canvas_painter.dart';
import 'escape_count_source.dart';
import 'island_fill.dart';
import 'path_fill.dart';
import 'overlay.dart';
import 'viewport.dart';
import 'viewport_math.dart';

/// Asset key for the fractal colour shader. Package-qualified so it resolves
/// when great_wall_ux is consumed as a dependency.
const String _shaderAsset = 'packages/great_wall_ux/shaders/fractal.frag';

/// Auto exposure eases to each frame's fit over this long (ease-out), so
/// panning and zooming re-expose the view without visible pumping. A new fit
/// restarts the ease from wherever the values are.
const Duration kAutoExposureEase = Duration(milliseconds: 500);

/// Fits closer than this (in offset, and in log2 of the slope) to the one being
/// eased to, or to the current values, start no new ease.
const double _kExposureSame = 0.01;

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
/// `L` + scroll adjusts the brightness offset and `G` + scroll its slope
/// (tacit, never-displayed controls).
///
/// With the [BrightnessController]'s auto exposure on, the canvas fits offset
/// and slope to every raster it receives ([screenExposure]) and eases toward
/// the fit ([kAutoExposureEase]).
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

class _FractalCanvasState extends State<FractalCanvas>
    with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  ui.Image? _countsImage;
  ui.Image? _paletteImage;
  EscapeCountRequest? _inFlight;
  Timer? _refineTimer;
  int _requestSeq = 0;
  int _repaintTick = 0;

  /// The raster behind [_countsImage], kept so canonical islands can be flood
  /// filled over the exact escape counts being drawn (see `island_fill.dart`),
  /// together with the viewport it was rendered for — which is the reduced-size
  /// one during the low-res pass, and fixes where the island's seeds land.
  EscapeCountRaster? _raster;
  FractalViewport? _rasterViewport;

  ui.Image? _islandMask;
  List<CanvasIsland> _islandCells = const <CanvasIsland>[];
  int _maskSeq = 0;

  /// The landmark path's highlights over [_raster] (`path_fill.dart`).
  ui.Image? _pathMask;
  int _pathSeq = 0;

  BrightnessController? _internalBrightness;
  BrightnessController get _brightness =>
      widget.brightness ?? (_internalBrightness ??= BrightnessController());

  /// Auto exposure: the ease's start and end, as offset and log2 slope, and the
  /// ticker running it. [_wasAuto] tracks the mode so a switch-on fits the
  /// raster already in hand.
  late final Ticker _exposureTicker = createTicker(_onExposureTick);
  double _fromOffset = 0;
  double _fromLog2Slope = 0;
  double _targetOffset = 0;
  double _targetLog2Slope = 0;
  bool _wasAuto = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onViewportChanged);
    _brightness.addListener(_onUniformChanged);
    _wasAuto = _brightness.autoExposure;
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
      _exposureTicker.stop();
      _wasAuto = _brightness.autoExposure;
      _fitExposure();
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
    // A new island set (the host's `E` reveal, a fresh selection) re-floods
    // against the raster already in hand — no re-render needed. Compared by
    // element, not by list identity: a host that rebuilds its overlay list each
    // frame while holding the same islands must not re-fill on every rebuild.
    if (!listEquals(old.overlays.islands, widget.overlays.islands)) {
      _rebuildIslandMask();
    }
    if (!identical(old.overlays.path, widget.overlays.path)) {
      _rebuildPathMask();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onViewportChanged);
    (widget.brightness ?? _internalBrightness)?.removeListener(_onUniformChanged);
    _internalBrightness?.dispose();
    _exposureTicker.dispose();
    _refineTimer?.cancel();
    _shader?.dispose();
    _countsImage?.dispose();
    _paletteImage?.dispose();
    _islandMask?.dispose();
    _pathMask?.dispose();
    super.dispose();
  }

  /// Load the colour shader. A failure is reported through [FlutterError]
  /// (the canvas keeps painting black) rather than left as an unhandled async
  /// error, so hosts and tests can see it.
  Future<void> _loadShader() async {
    final ui.FragmentProgram program;
    try {
      program = await ui.FragmentProgram.fromAsset(_shaderAsset);
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'great_wall_ux',
          context: ErrorDescription('loading the fractal shader'),
        ),
      );
      return;
    }
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
  // escape counts — that is the whole point of colouring on the GPU. A switch
  // of auto exposure starts (fitting the current raster) or stops the easing.
  void _onUniformChanged() {
    final bool auto = _brightness.autoExposure;
    if (auto != _wasAuto) {
      _wasAuto = auto;
      if (auto) {
        _fitExposure();
      } else {
        _exposureTicker.stop();
      }
    }
    setState(() => _repaintTick++);
  }

  /// Fit the screen exposure to the current raster and ease to it, when auto
  /// exposure is on. The fit gives the half-brightness count `h`; the offset
  /// that puts it there is `h − log2(B) − 2·log2(z)` at the zoom the raster was
  /// rendered for.
  void _fitExposure() {
    final EscapeCountRaster? r = _raster;
    final FractalViewport? vp = _rasterViewport;
    if (!_brightness.autoExposure || r == null || vp == null) return;
    final ScreenExposure? fit =
        screenExposure(r.counts, r.widthPx, r.heightPx, r.maxIterations);
    if (fit == null) return;
    final double zoom = kReferenceHalfExtent / vp.halfExtent;
    final double offset =
        fit.h - _log2(kBrightnessFalloffBase) - 2 * _log2(zoom);
    final double log2Slope = _log2(fit.s);
    // The refine pass usually fits what the low-res pass did: keep easing.
    final bool sameTarget = (offset - _targetOffset).abs() < _kExposureSame &&
        (log2Slope - _targetLog2Slope).abs() < _kExposureSame;
    if (_exposureTicker.isActive && sameTarget) return;
    _fromOffset = _brightness.offset;
    _fromLog2Slope = _log2(_brightness.slope);
    _targetOffset = offset;
    _targetLog2Slope = log2Slope;
    _exposureTicker.stop();
    if ((offset - _fromOffset).abs() < _kExposureSame &&
        (log2Slope - _fromLog2Slope).abs() < _kExposureSame) {
      return;
    }
    _exposureTicker.start();
  }

  /// One frame of the ease: offset and log2 slope along an ease-out from where
  /// they were to the fit, over [kAutoExposureEase].
  void _onExposureTick(Duration elapsed) {
    final double t = math.min(
      1.0,
      elapsed.inMicroseconds / kAutoExposureEase.inMicroseconds,
    );
    final double e = Curves.easeOut.transform(t);
    if (t >= 1.0) _exposureTicker.stop();
    _brightness.setExposure(
      offset: _fromOffset + (_targetOffset - _fromOffset) * e,
      slope: math
          .pow(2.0, _fromLog2Slope + (_targetLog2Slope - _fromLog2Slope) * e)
          .toDouble(),
    );
  }

  static double _log2(double x) => math.log(x) / math.ln2;

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
      _raster = r;
      _rasterViewport = vp;
      _repaintTick++;
    });
    _fitExposure();
    // Islands are re-filled per raster, so the highlight always matches the
    // fractal on screen: low-res during interaction, crisp after the refine.
    unawaited(_rebuildIslandMask());
    unawaited(_rebuildPathMask());
  }

  /// Re-derive the canonical-island highlight from the current raster.
  ///
  /// The fill is synchronous and bounded by the raster (4-connected, marks on
  /// push); only the upload to a [ui.Image] is async, so a stale pass is
  /// dropped on [_maskSeq] rather than clobbering a newer one.
  Future<void> _rebuildIslandMask() async {
    final EscapeCountRaster? r = _raster;
    final FractalViewport? vp = _rasterViewport;
    final List<CanvasIsland> islands = widget.overlays.islands;
    final int seq = ++_maskSeq;

    if (r == null || vp == null || islands.isEmpty) {
      if (_islandMask == null && _islandCells.isEmpty) return;
      setState(() {
        _islandMask?.dispose();
        _islandMask = null;
        _islandCells = const <CanvasIsland>[];
        _repaintTick++;
      });
      return;
    }

    final IslandFillResult fill = fillIslands(
      raster: r,
      rasterViewport: vp,
      islands: islands,
    );

    ui.Image? image;
    if (!fill.isEmpty) {
      image = await packIslandMask(
        widthPx: fill.widthPx,
        heightPx: fill.heightPx,
        mask: fill.mask,
      );
    }
    if (!mounted || seq != _maskSeq) {
      image?.dispose();
      return;
    }
    setState(() {
      _islandMask?.dispose();
      _islandMask = image;
      _islandCells = fill.unfilled;
      _repaintTick++;
    });
  }

  /// Re-derive the landmark path's highlights from the current raster, as
  /// [_rebuildIslandMask] does for islands.
  Future<void> _rebuildPathMask() async {
    final EscapeCountRaster? r = _raster;
    final FractalViewport? vp = _rasterViewport;
    final CanvasPath? path = widget.overlays.path;
    final int seq = ++_pathSeq;

    if (r == null || vp == null || path == null) {
      if (_pathMask == null) return;
      setState(() {
        _pathMask?.dispose();
        _pathMask = null;
        _repaintTick++;
      });
      return;
    }

    final Uint8List mask = fillPath(raster: r, rasterViewport: vp, path: path);
    final ui.Image image = await packIslandMask(
      widthPx: r.widthPx,
      heightPx: r.heightPx,
      mask: mask,
    );
    if (!mounted || seq != _pathSeq) {
      image.dispose();
      return;
    }
    setState(() {
      _pathMask?.dispose();
      _pathMask = image;
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
    sh.setFloat(6, _brightness.slope);
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
                  islandMask: _islandMask,
                  islandCells: _islandCells,
                  pathMask: _pathMask,
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
    final HardwareKeyboard kb = HardwareKeyboard.instance;
    final double up = event.scrollDelta.dy < 0 ? 1.0 : -1.0;
    if (kb.isLogicalKeyPressed(LogicalKeyboardKey.keyL)) {
      // Tacit brightness adjustment. Scroll up brightens the lit band.
      _brightness.adjustBySteps(up);
    } else if (kb.isLogicalKeyPressed(LogicalKeyboardKey.keyG)) {
      // Tacit slope adjustment. Scroll up spreads the falloff (more shades).
      _brightness.adjustSlopeBySteps(up);
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
