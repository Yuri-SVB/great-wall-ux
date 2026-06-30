import 'package:flutter_test/flutter_test.dart';
import 'package:great_wall_ux/great_wall_ux.dart';

void main() {
  group('LeafArea', () {
    test('value equality includes the canonical path', () {
      const LeafArea a = LeafArea(
        reMin: -0.5, reMax: -0.4, imMin: 0.1, imMax: 0.2, path: 'OlRd',
      );
      const LeafArea sameGeom = LeafArea(
        reMin: -0.5, reMax: -0.4, imMin: 0.1, imMax: 0.2, path: 'OlRd',
      );
      const LeafArea otherPath = LeafArea(
        reMin: -0.5, reMax: -0.4, imMin: 0.1, imMax: 0.2, path: 'OlRu',
      );
      expect(a, equals(sameGeom));
      expect(a.hashCode, equals(sameGeom.hashCode));
      expect(a, isNot(equals(otherPath)));
    });
  });

  group('LeafAreasResult', () {
    test('leaves variant carries the list and is not tooMany', () {
      const LeafArea leaf = LeafArea(
        reMin: 0, reMax: 1, imMin: 0, imMax: 1, path: 'Ol',
      );
      const LeafAreasResult r = LeafAreasResult.leaves(<LeafArea>[leaf]);
      expect(r.tooMany, isFalse);
      expect(r.leaves, hasLength(1));
      expect(r.leaves.single.path, 'Ol');
    });

    test('tooMany variant has an empty list and reports the cap', () {
      const LeafAreasResult r = LeafAreasResult.tooMany(20);
      expect(r.tooMany, isTrue);
      expect(r.leaves, isEmpty);
      expect(r.maxLeaves, 20);
    });
  });

  group('LeafAreasRequest', () {
    const FractalViewport vp = FractalViewport(
      centreRe: 0.0,
      centreIm: 0.0,
      halfExtent: 2.0,
      widthPx: 400,
      heightPx: 400,
      devicePixelRatio: 1.0,
    );

    test('applies default scan step and cap', () {
      const LeafAreasRequest req = LeafAreasRequest(
        viewport: vp,
        stage: Stage.stage1,
        stageParameters: null,
        numBits: 32,
      );
      expect(req.scanStep, kDefaultLeafAreaScanStep);
      expect(req.maxLeaves, kDefaultMaxLeafAreas);
    });

    test('value equality covers all fields', () {
      const LeafAreasRequest a = LeafAreasRequest(
        viewport: vp, stage: Stage.stage1, stageParameters: null, numBits: 32,
      );
      const LeafAreasRequest b = LeafAreasRequest(
        viewport: vp, stage: Stage.stage1, stageParameters: null, numBits: 32,
      );
      const LeafAreasRequest c = LeafAreasRequest(
        viewport: vp, stage: Stage.stage1, stageParameters: null, numBits: 16,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('StubLeafAreaSource', () {
    test('returns an empty leaf list', () async {
      const FractalViewport vp = FractalViewport(
        centreRe: 0.0,
        centreIm: 0.0,
        halfExtent: 2.0,
        widthPx: 64,
        heightPx: 64,
        devicePixelRatio: 1.0,
      );
      const LeafAreaSource source = StubLeafAreaSource();
      final LeafAreasResult r = await source.leafAreas(
        const LeafAreasRequest(
          viewport: vp,
          stage: Stage.stage1,
          stageParameters: null,
          numBits: 32,
        ),
      );
      expect(r.tooMany, isFalse);
      expect(r.leaves, isEmpty);
    });
  });
}
