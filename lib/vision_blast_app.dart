import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';

class VisionBlastApp extends StatelessWidget {
  const VisionBlastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision Blast',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Colors.blueAccent,
          secondary: Colors.redAccent,
        ),
      ),
      home: const CameraScreen(),
    );
  }
}
