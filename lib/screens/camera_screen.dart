import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart'; // To access the globally defined cameras list

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  
  // Protanomaly compensation: -1.0 (left, max comp) to 0.0 (center, no effect) to +1.0 (right)
  double _protanSeverity = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      if (cameras.isEmpty) {
        debugPrint('No cameras found.');
        return;
      }
      
      // Select the first back camera
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      try {
        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      } on CameraException catch (e) {
        debugPrint('Camera exception: ${e.code}\n${e.description}');
      }
    }
  }

  // Handle lifecycle changes to manage camera resources
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
      _isCameraInitialized = false;
      if (mounted) {
        setState(() {});
      }
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  // Generates the Protanomaly Daltonization color matrix for ColorFiltered.
  //
  // Algorithm: Viénot 1999 / Brettel 1997 Daltonization for Protan.
  //
  // For Protanopia (full red-cone deficiency), the perceived red channel
  // is effectively zeroed out. Daltonization compensates by boosting the
  // original red information into the green and blue output channels so
  // that red-green contrast becomes visible as a luminance/blue contrast.
  //
  // Full-compensation matrix (t = 1.0):
  //   R_out = R
  //   G_out = G + 0.7 * R   (shift 70% of red into green)
  //   B_out = B + 0.7 * R   (shift 70% of red into blue)
  //
  // Slider → t mapping:
  //   slider = -1.0 (left,  -100%) → t = 1.0  (max compensation)
  //   slider =  0.0 (center,  0%) → t = 0.0  (no effect / identity)
  //   slider = +1.0 (right, +100%) → t = -1.0 (inverted, for testing)
  List<double> _getColorMatrix() {
    // t in [-1, 1]: negative = compensation, positive = inverse/simulation
    final double t = -_protanSeverity;

    // Redistribution weight (Viénot 1999 empirical value)
    //const double rw = 0.7;
    const double rw = 0.9;

    // rG and rB can be negative (inverse mode) – ColorFiltered handles that fine
    final double rG = t * rw;
    final double rB = t * rw;

    // 5x4 ColorFilter matrix, row-major:
    //   each row = [R_coeff, G_coeff, B_coeff, A_coeff, offset]
    return <double>[
      1,   0,  0,  0, 0,  // R_out = 1*R
      rG,  1,  0,  0, 0,  // G_out = rG*R + 1*G
      rB,  0,  1,  0, 0,  // B_out = rB*R + 1*B
      0,   0,  0,  1, 0,  // A_out = 1*A
    ];
  }


  @override
  Widget build(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.blueAccent),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // The camera preview wrapped in our dynamic ColorFiltered widget
          ColorFiltered(
            colorFilter: ColorFilter.matrix(_getColorMatrix()),
            child: CameraPreview(_controller!),
          ),

          // Control Overlays
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildProtanSlider(),
                ],
              ),
            ),
          ),
          
          // App Title at top
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Vision Blast',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtanSlider() {
    final int pct = (_protanSeverity * 100).toInt();
    final String label = pct > 0 ? '+$pct%' : '$pct%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Protan Comp',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Row(
          children: [
            const Text('-100', style: TextStyle(color: Colors.white38, fontSize: 11)),
            Expanded(
              child: Slider(
                value: _protanSeverity,
                min: -1.0,
                max: 1.0,
                divisions: 20,
                activeColor: Colors.orangeAccent,
                inactiveColor: Colors.white24,
                onChanged: (val) => setState(() => _protanSeverity = val),
              ),
            ),
            const Text('+100', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ],
    );
  }

}
