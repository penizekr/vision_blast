import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'vision_blast_app.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error getting cameras: ${e.code}, message: ${e.description}');
  }
  runApp(const VisionBlastApp());
}
