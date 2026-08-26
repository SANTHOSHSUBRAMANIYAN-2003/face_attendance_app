import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class FaceService {
  static const platform = MethodChannel('com.nmspayroll.face/recognition');

  Future<List<double>?> getFaceEmbedding(Uint8List imageBytes) async {
    try {
      final List<dynamic>? result = await platform.invokeMethod('getFaceEmbedding', {'image': imageBytes});
      if (result != null) {
        return result.cast<double>();
      }
      return null;
    } on PlatformException catch (e) {
      print("Failed to get embedding: '${e.message}'.");
      return null;
    } catch (e) {
      print("Error calling native face service: $e");
      return null;
    }
  }

  double

  euclideanDistance(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return double.infinity;
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      double diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }
}
