/// Visual and interaction layer for the Great Wall fractal encoder.
///
/// See `great-wall-docs/great-wall-ux/SCOPE.md` for what this library owns
/// and `great-wall-docs/great-wall-ux/TECH_STACK.md` for the Dart/Flutter
/// decision and invariants. Both are vendored into this repo as a
/// submodule so the spec ships next to the implementation.
library;

export 'src/audio/sound_board.dart';
export 'src/canvas/escape_count_source.dart';
export 'src/canvas/fractal_canvas.dart';
export 'src/canvas/overlay.dart';
export 'src/canvas/viewport.dart';
export 'src/canvas/viewport_math.dart';
export 'src/gestures/pan_zoom_controller.dart';
export 'src/gestures/select_mode.dart';
export 'src/lifecycle/session_lifecycle.dart';
export 'src/palette/palette.dart';
export 'src/render/brightness_controller.dart';
export 'src/stages/stage.dart';
export 'src/theme/typography.dart';
export 'src/widgets/hue_wheel.dart';
export 'src/widgets/stage_count_slider.dart';
