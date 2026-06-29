// Minimal host app. Wires great_wall_ux into a Flutter shell using the stub
// EscapeCountSource — replace with the FFI binding to great-wall-core to see
// the actual Burning Ship raster.
//
// Demonstrates the locked surface: the GPU colour pipeline, the rotary hue
// wheel, L+scroll brightness (a tacit control with no on-screen value), and
// V+Up/Down sound-cue volume (level 0 == muted).

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
  final SoundBoard _sounds = SoundBoard();
  HueOffset _hue = kDefaultHue;
  int _volume = kMaxVolumeLevel;
  int _stages = 4;

  @override
  void dispose() {
    _controller.dispose();
    _brightness.dispose();
    _sounds.dispose();
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
              sounds: _sounds,
              onVolumeChanged: (int level) => setState(() => _volume = level),
              onSelect: (FractalSelection _) {
                // The canvas already played the click cue; the app plays the
                // outcome cue once it knows the decode result. The demo
                // source has no decode, so we treat every tap as a commit.
                _sounds.play(UiSound.select);
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
                  StageCountSlider(
                    value: _stages,
                    onChanged: (int n) => setState(() => _stages = n),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Hold L and scroll to adjust brightness.\n'
                    'Hold V and press Up/Down to change volume.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(
                    onPressed: _brightness.reset,
                    child: const Text('Reset brightness'),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _sounds.toggleMute();
                      _volume = _sounds.volumeLevel;
                    }),
                    icon: Icon(
                      _volume == 0 ? Icons.volume_off : Icons.volume_up,
                    ),
                    label: Text(
                      _volume == 0 ? 'Muted' : 'Volume $_volume/$kMaxVolumeLevel',
                    ),
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
