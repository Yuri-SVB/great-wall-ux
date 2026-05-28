import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../palette/palette.dart';

/// A clickable rotary wheel for choosing among the six [HueOffset] rotations.
///
/// The intended affordance for hue selection per
/// `great-wall-docs/great-wall-ux/SCOPE.md` (§"sober, but game-like" — a
/// wheel the user turns, not a dropdown). Tapping a sector — or the rotate
/// arrows — snaps to that hue; the current selection sits under the marker
/// at the top.
class HueWheel extends StatelessWidget {
  const HueWheel({
    super.key,
    required this.value,
    required this.onChanged,
    this.diameter = 120.0,
  });

  final HueOffset value;
  final ValueChanged<HueOffset> onChanged;
  final double diameter;

  static const List<HueOffset> _order = HueOffset.values;

  void _step(int direction) {
    final int i = (value.index + direction) % _order.length;
    onChanged(_order[i < 0 ? i + _order.length : i]);
  }

  void _handleTapDown(TapDownDetails details) {
    final double r = diameter / 2;
    final Offset c = Offset(r, r);
    final Offset v = details.localPosition - c;
    if (v.distance < r * 0.25) return; // ignore the hub
    // Angle measured clockwise from the top marker.
    double angle = math.atan2(v.dx, -v.dy);
    if (angle < 0) angle += 2 * math.pi;
    final int sector =
        (angle / (2 * math.pi) * _order.length).floor() % _order.length;
    onChanged(_order[sector]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          label: 'Hue: ${value.name}',
          button: true,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            child: CustomPaint(
              size: Size.square(diameter),
              painter: _HueWheelPainter(value),
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.rotate_left),
              tooltip: 'Previous hue',
              onPressed: () => _step(-1),
            ),
            Text(value.name),
            IconButton(
              icon: const Icon(Icons.rotate_right),
              tooltip: 'Next hue',
              onPressed: () => _step(1),
            ),
          ],
        ),
      ],
    );
  }
}

class _HueWheelPainter extends CustomPainter {
  _HueWheelPainter(this.selected);

  final HueOffset selected;

  @override
  void paint(Canvas canvas, Size size) {
    final double r = size.width / 2;
    final Offset c = Offset(r, r);
    final int n = HueOffset.values.length;
    final double sweep = 2 * math.pi / n;

    for (int i = 0; i < n; i++) {
      // Sector i spans clockwise from the top marker.
      final double start = -math.pi / 2 + i * sweep;
      final Paint fill = Paint()
        ..style = PaintingStyle.fill
        ..color = HSLColor.fromAHSL(
          1.0,
          (HueOffset.values[i].degrees.toDouble()) % 360.0,
          0.6,
          0.5,
        ).toColor();
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        sweep,
        true,
        fill,
      );
      if (HueOffset.values[i] == selected) {
        canvas.drawArc(
          Rect.fromCircle(center: c, radius: r - 2),
          start,
          sweep,
          true,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0
            ..color = Colors.white,
        );
      }
    }

    // Hub.
    canvas.drawCircle(c, r * 0.22, Paint()..color = Colors.black87);
  }

  @override
  bool shouldRepaint(covariant _HueWheelPainter old) => old.selected != selected;
}
