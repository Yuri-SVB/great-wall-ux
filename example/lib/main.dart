// Minimal host app. Wires great_wall_ux into a Flutter shell using the stub
// EscapeCountSource — replace with the FFI binding to great-wall-core to see
// the actual Burning Ship raster.
//
// Demonstrates the locked surface: the GPU colour pipeline, the rotary hue
// wheel, and L+scroll brightness (a tacit control with no on-screen value).

import 'package:flutter/material.dart';
import 'package:great_wall_ux/great_wall_ux.dart';

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'great_wall_ux example',
      // Adopt the Great Wall chrome typography (Ubuntu Mono) throughout.
      theme: GreatWallTypography.themed(ThemeData.dark()),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();
  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  // Synthetic test data so the colour pipeline is visible without the Rust
  // FFI binding. Swap for the real great-wall-core source when wired.
  final EscapeCountSource _source = const DemoEscapeCountSource();
  final PanZoomController _controller = PanZoomController(
    initial: const FractalViewport(
      centreRe: -0.5,
      centreIm: 0.0,
      halfExtent: 2.0,
      widthPx: 1,
      heightPx: 1,
      devicePixelRatio: 1.0,
    ),
  );
  final BrightnessController _brightness = BrightnessController();
  HueOffset _hue = kDefaultHue;

  @override
  void dispose() {
    _controller.dispose();
    _brightness.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Great Wall — fractal canvas')),
      body: Row(
        children: <Widget>[
          Expanded(
            child: FractalCanvas(
              source: _source,
              controller: _controller,
              palette: Palette.forHue(_hue),
              brightness: _brightness,
              stage: Stage.stage1,
              semanticLabel: 'Fractal canvas',
              onSelect: (FractalSelection _) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Point selected')),
                );
              },
            ),
          ),
          SizedBox(
            width: 180,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  HueWheel(
                    value: _hue,
                    onChanged: (HueOffset h) => setState(() => _hue = h),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Hold L and scroll to adjust brightness',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _brightness.reset,
                    child: const Text('Reset brightness'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
