import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Local source limits bound decoding; the server's upload limits stay unchanged.
/// Decode at the provider's working resolution, then encode without EXIF/GPS.
class InspectionImageOptimizer {
  static const maxSourceBytes = 40 * 1024 * 1024;
  static const maxSourcePixels = 64 * 1000 * 1000;
  static const maxUploadBytes = 10 * 1024 * 1024;
  static const maxEdge = 2048;
  static const minEdge = 256;

  Future<Uint8List> prepare(XFile file) async {
    if (await file.length() > maxSourceBytes) {
      throw const FormatException(
        'Fotoğraf güvenli işleme boyutunu aşıyor. Daha düşük çözünürlükte bir fotoğraf seçin.',
      );
    }
    return prepareBytes(await file.readAsBytes());
  }

  Future<Uint8List> prepareBytes(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > maxSourceBytes) {
      throw const FormatException(
        'Fotoğraf boş veya güvenli işleme boyutunu aşıyor.',
      );
    }
    // The format allowlist applies before any platform decoder fallback.
    if (!_supported(bytes)) {
      throw const FormatException(
        'Geçerli bir JPG, PNG veya WEBP fotoğraf seçin.',
      );
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? decoded;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      if (width * height > maxSourcePixels) {
        throw const FormatException(
          'Fotoğraf güvenli işleme çözünürlüğünü aşıyor. Daha düşük çözünürlükte bir fotoğraf seçin.',
        );
      }
      if (math.min(width, height) < minEdge) {
        throw const FormatException(
          'Fotoğrafın kısa kenarı en az 256 piksel olmalıdır.',
        );
      }
      final scale = math.min(1.0, maxEdge / math.max(width, height));
      final targetWidth = (width * scale).round();
      final targetHeight = (height * scale).round();
      if (math.min(targetWidth, targetHeight) < minEdge) {
        throw const FormatException(
          'Çok geniş panorama yerine araç bölgesini gösteren bir fotoğraf seçin.',
        );
      }
      // Flutter's codec applies EXIF orientation and preserves the aspect ratio.
      codec = await descriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      if (codec.frameCount != 1) {
        throw const FormatException(
          'Hareketli görsel yerine tek bir fotoğraf seçin.',
        );
      }
      decoded = (await codec.getNextFrame()).image;
      final rgba = await decoded.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (rgba == null) throw const FormatException('Fotoğraf okunamadı.');
      final result = await compute(_encodeJpeg, (
        bytes: rgba.buffer.asUint8List(rgba.offsetInBytes, rgba.lengthInBytes),
        width: decoded.width,
        height: decoded.height,
      ));
      if (result.isEmpty || result.length > maxUploadBytes) {
        throw const FormatException(
          'Fotoğraf yükleme boyutuna küçültülemedi. Başka bir fotoğraf seçin.',
        );
      }
      return result;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Fotoğraf okunamadı. Geçerli bir JPG, PNG veya WEBP fotoğraf seçin.',
      );
    } finally {
      decoded?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  static bool _supported(Uint8List bytes) =>
      (bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff) ||
      (bytes.length >= 8 &&
          listEquals(bytes.sublist(0, 8), [137, 80, 78, 71, 13, 10, 26, 10])) ||
      (bytes.length >= 12 &&
          listEquals(bytes.sublist(0, 4), [82, 73, 70, 70]) &&
          listEquals(bytes.sublist(8, 12), [87, 69, 66, 80]));
}

Uint8List _encodeJpeg(({Uint8List bytes, int width, int height}) input) {
  final source = img.Image.fromBytes(
    width: input.width,
    height: input.height,
    bytes: input.bytes.buffer,
    bytesOffset: input.bytes.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  // Composite transparent input onto white, rather than inventing black damage.
  final opaque = img.Image(
    width: input.width,
    height: input.height,
    numChannels: 3,
  );
  img.fill(opaque, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(opaque, source);
  return img.encodeJpg(opaque, quality: 90);
}
