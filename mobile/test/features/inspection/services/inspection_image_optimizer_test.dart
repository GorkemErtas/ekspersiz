import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mobile/features/inspection/services/inspection_image_optimizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final optimizer = InspectionImageOptimizer();
  const fixtures = 'test/fixtures/inspection';

  void expectUpload(Uint8List bytes, int width, int height) {
    expect(bytes.length, lessThanOrEqualTo(10 * 1024 * 1024));
    final decoded = img.decodeJpg(bytes)!;
    expect((decoded.width, decoded.height), (width, height));
    expect(decoded.exif.isEmpty, isTrue);
  }

  test(
    '48 MP JPEG under 10 MiB is resized and exported for FastAPI contract test',
    () async {
      final result = await optimizer.prepare(XFile('$fixtures/48mp.jpg'));
      expectUpload(result, 2048, 1536);
      final directory = Directory('build/inspection-image-contract')
        ..createSync(recursive: true);
      File('${directory.path}/detail.jpg').writeAsBytesSync(result);
      final overview = await optimizer.prepare(XFile('$fixtures/still.webp'));
      expectUpload(overview, 640, 320);
      File('${directory.path}/overview.jpg').writeAsBytesSync(overview);
    },
  );

  test(
    'PNG larger than upload limit is optimized rather than rejected',
    () async {
      final source = img.Image(width: 2000, height: 1800, numChannels: 3);
      img.fill(source, color: img.ColorRgb8(180, 90, 40));
      final bytes = img.encodePng(source, level: 0);
      expect(bytes.length, greaterThan(10 * 1024 * 1024));
      expectUpload(await optimizer.prepareBytes(bytes), 2000, 1800);
    },
  );

  for (var orientation = 1; orientation <= 8; orientation++) {
    test(
      'EXIF orientation $orientation is baked in, metadata stripped, aspect preserved',
      () async {
        final original = File(
          '$fixtures/orientation-$orientation.jpg',
        ).readAsBytesSync();
        final expected = img.bakeOrientation(img.decodeJpg(original)!);
        final result = await optimizer.prepareBytes(original);
        expectUpload(result, expected.width, expected.height);
        final actual = img.decodeJpg(result)!;
        // Check all quadrants so mirrored EXIF orientations are covered as well.
        for (final x in [expected.width ~/ 4, expected.width * 3 ~/ 4]) {
          for (final y in [expected.height ~/ 4, expected.height * 3 ~/ 4]) {
            final a = actual.getPixel(x, y);
            final e = expected.getPixel(x, y);
            expect(a.r, closeTo(e.r, 8));
            expect(a.b, closeTo(e.b, 8));
          }
        }
      },
    );
  }

  test('transparent PNG composites onto white', () async {
    final source = img.Image(width: 320, height: 320, numChannels: 4);
    final result = img.decodeJpg(
      await optimizer.prepareBytes(img.encodePng(source)),
    )!;
    expect(result.getPixel(100, 100).r, greaterThan(250));
  });

  test(
    'animated PNG and WEBP are not flattened into acceptable photos',
    () async {
      for (final name in ['animated.png', 'animated.webp']) {
        await expectLater(
          optimizer.prepare(XFile('$fixtures/$name')),
          throwsFormatException,
        );
      }
    },
  );

  test('empty, unsupported, corrupt and tiny inputs are rejected', () async {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([71, 73, 70, 56]),
      Uint8List.fromList([255, 216, 255, 0, 0]),
      img.encodePng(img.Image(width: 255, height: 300)),
      img.encodePng(img.Image(width: 4096, height: 256)),
    ]) {
      await expectLater(optimizer.prepareBytes(bytes), throwsFormatException);
    }
  });

  test('source byte bound is checked before reading the file', () async {
    await expectLater(
      optimizer.prepare(_OversizedFile()),
      throwsFormatException,
    );
  });

  test(
    'source pixel bound rejects oversized headers before allocating pixels',
    () async {
      // JPEG dimensions are in the SOF marker; payload remains a tiny fixture.
      final bytes = File('$fixtures/orientation-1.jpg').readAsBytesSync();
      for (var i = 2; i < bytes.length - 8; i++) {
        if (bytes[i] == 255 && bytes[i + 1] == 192) {
          final view = ByteData.sublistView(bytes);
          view.setUint16(i + 5, 9000);
          view.setUint16(i + 7, 9000);
          break;
        }
      }
      await expectLater(optimizer.prepareBytes(bytes), throwsFormatException);
    },
  );
}

class _OversizedFile extends XFile {
  _OversizedFile() : super('unused');
  @override
  Future<int> length() async => InspectionImageOptimizer.maxSourceBytes + 1;
  @override
  Future<Uint8List> readAsBytes() =>
      throw StateError('Must not read oversized source');
}
