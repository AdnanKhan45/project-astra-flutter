
import 'dart:typed_data';

import 'package:image/image.dart' as imglib;
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

class AstraUtils {


  static Future<Uint8List?> convertCameraImageToJpeg(CameraImage cameraImage) async {
    try {
      imglib.Image? img;

      // --- HIGH PRIORITY: DIRECT JPEG (if plugin ever supports for stream) ---
      if (cameraImage.format.group == ImageFormatGroup.jpeg) {
        if (cameraImage.planes.isNotEmpty) {
          print('Detected ImageFormatGroup.jpeg. Returning raw bytes.');
          return cameraImage.planes[0].bytes;
        }
        print('Detected ImageFormatGroup.jpeg but no planes found.');
        return null;
      }
      // --- NEXT PRIORITY: BGRA8888 (Common on iOS) ---
      else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        if (cameraImage.planes.isNotEmpty) {
          print('Detected ImageFormatGroup.bgra8888. Converting...');
          // Create image from bytes, ensuring correct channel order
          img = imglib.Image.fromBytes(
            width: cameraImage.width,
            height: cameraImage.height,
            bytes: cameraImage.planes[0].bytes.buffer,
            order: imglib.ChannelOrder.bgra, // BGRA8888 is B-G-R-A order
          );
        } else {
          print('BGRA8888 format but no planes found.');
          return null;
        }
      }
      // --- LAST RESORT: YUV420_888 (Common on Android, less reliable on iOS for streaming) ---
      else if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        print('Detected ImageFormatGroup.yuv420_888. Attempting conversion...');
        // Ensure all planes exist for YUV conversion
        if (cameraImage.planes.length < 3) {
          print('YUV420_888 format but not all 3 planes found. Skipping frame.');
          return null; // Don't crash, just skip this problematic frame
        }

        final int width = cameraImage.width;
        final int height = cameraImage.height;
        final Uint8List yPlane = cameraImage.planes[0].bytes;
        final Uint8List uPlane = cameraImage.planes[1].bytes;
        final Uint8List vPlane = cameraImage.planes[2].bytes;

        final int yRowStride = cameraImage.planes[0].bytesPerRow;
        final int uvRowStride = cameraImage.planes[1].bytesPerRow;
        final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1; // Safely get or default

        // Create a new image to populate
        img = imglib.Image(width: width, height: height);

        for (int h = 0; h < height; h++) {
          for (int w = 0; w < width; w++) {
            final int yIndex = h * yRowStride + w;
            // UV values are subsampled, typically /2
            final int uvIndex = (h ~/ 2) * uvRowStride + (w ~/ 2) * uvPixelStride;

            if (yIndex >= yPlane.length || uvIndex >= uPlane.length || uvIndex >= vPlane.length) {
              // This can happen if the strides/pixel strides are misreported for the buffer size.
              // Or if there's a malformed frame.
              print('Warning: YUV plane index out of bounds. Skipping pixel.');
              continue; // Skip this pixel to prevent crash
            }

            final int Y = yPlane[yIndex];
            final int U = uPlane[uvIndex];
            final int V = vPlane[uvIndex];

            // YUV to RGB conversion (standard formula)
            int r = (Y + (V - 128) * 1.402).round().clamp(0, 255);
            int g = (Y - (U - 128) * 0.344136 - (V - 128) * 0.714136).round().clamp(0, 255);
            int b = (Y + (U - 128) * 1.772).round().clamp(0, 255);

            img.setPixelRgba(w, h, r, g, b, 255);
          }
        }
      }
      // --- OTHERWISE: Log unsupported format and return null ---
      else {
        print('Unsupported CameraImage format group: ${cameraImage.format.group}. Skipping frame.');
        return null;
      }

      if (img != null) {
        return Uint8List.fromList(imglib.encodeJpg(img, quality: 80));
      }
      return null;
    } catch (e, stackTrace) {
      print('Error converting CameraImage to JPEG in isolate: $e\n$stackTrace');
      // Important: Return null on error so the app doesn't crash from the isolate.
      return null;
    }
  }

  static Future<void> requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
      if (!status.isGranted) {
        throw Exception('Camera permission denied');
      }
    }
  }

  static Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    final requestStatus = await Permission.microphone.request();
    return requestStatus.isGranted;
  }
}