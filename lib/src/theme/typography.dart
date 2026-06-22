import 'package:flutter/material.dart';

/// Typography token for the chrome that surrounds the fractal canvas.
///
/// The chrome uses **Ubuntu Mono**, a monospace face that carries the
/// terminal / "hackery" aesthetic called for by
/// `great-wall-docs/great-wall-ux/SCOPE.md` (§"sober, but game-like" and
/// §"Assets and theming — iconography and typography tokens for the
/// chrome"). The font ships inside this package; consumers reference it
/// through [fontFamily] so the bundled asset resolves without re-declaring
/// it in their own pubspec.
///
/// This token themes chrome only. The fractal canvas itself draws no text;
/// it is an opaque interactive node by design (SCOPE.md §Accessibility).
class GreatWallTypography {
  const GreatWallTypography._();

  /// Package-qualified family name for the bundled Ubuntu Mono font.
  ///
  /// The `packages/<package>/<family>` form resolves both from inside this
  /// library and from a consuming package (e.g. `great-wallet/app` or the
  /// `example/` shell), so callers never need the per-`TextStyle` `package:`
  /// argument.
  static const String fontFamily = 'packages/great_wall_ux/UbuntuMono';

  /// Returns [base] with every text style switched to Ubuntu Mono.
  static TextTheme applyTo(TextTheme base) =>
      base.apply(fontFamily: fontFamily);

  /// Returns [base] themed with Ubuntu Mono across both the regular and
  /// primary text themes — the one call a consuming app makes to adopt the
  /// Great Wall chrome typography "throughout".
  static ThemeData themed(ThemeData base) => base.copyWith(
        textTheme: applyTo(base.textTheme),
        primaryTextTheme: applyTo(base.primaryTextTheme),
      );
}
