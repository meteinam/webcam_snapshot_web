import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MaterialApp(
    home: CameraAutoCapturePage(),
    debugShowCheckedModeBanner: false,
  ));
}

class CameraAutoCapturePage extends StatefulWidget {
  const CameraAutoCapturePage({super.key});

  @override
  State<CameraAutoCapturePage> createState() => _CameraAutoCapturePageState();
}

class _CameraAutoCapturePageState extends State<CameraAutoCapturePage> {
  CameraController? _controller;
  Timer? _timer;
  List<XFile> _capturedImages = [];
  bool _isCapturing = false;
  String? _errorMessage;
  List<CameraDescription> _cameras = [];
  List<String> _capturedBase64Images = [];

  @override
  void initState() {
    super.initState();
    _loadBase64ListFromLocal();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _errorMessage = "Kamera bulunamadı. Lütfen bir kamera bağlayın.";
        });
        return;
      }
      _controller = CameraController(_cameras[0], ResolutionPreset.medium);
      await _controller!.initialize();
      setState(() {
        _isCapturing = true;
        _errorMessage = null;
      });
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => _captureFrame());
    } catch (e) {
      String message = e.toString();
      if (message.contains('notReadable')) {
        message = "Kamera erişilemiyor. Lütfen tarayıcıdan kamera izni verin, başka bir uygulamanın kamerayı kullanmadığından emin olun ve uygulamayı HTTPS üzerinden çalıştırın.";
      }
      setState(() {
        _errorMessage = "Kamera başlatılamadı: $message";
      });
    }
  }

  Future<void> _captureFrame() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final image = await _controller!.takePicture();
      setState(() {
        _capturedImages.add(image);
      });
      await _convertAndStoreBase64(image);
      print("Fotoğraf çekildi!");
    } catch (e) {
      print("Fotoğraf çekilemedi: $e");
    }
  }

  Future<void> _convertAndStoreBase64(XFile image) async {
    final bytes = await image.readAsBytes();
    final base64Str = base64Encode(bytes);
    print("Base64 String: $base64Str");
    setState(() {
      _capturedBase64Images.add(base64Str);
    });
    await _saveBase64ListToLocal();
  }

  Future<void> _saveBase64ListToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('captured_images_base64', _capturedBase64Images);
  }

  Future<void> _loadBase64ListFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('captured_images_base64') ?? [];
    setState(() {
      _capturedBase64Images = list;
    });
  }

  void _stopCapturing() {
    _timer?.cancel();
    _controller?.dispose();
    setState(() {
      _isCapturing = false;
    });
  }

  @override
  void dispose() {
    _stopCapturing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kamera Otomatik Fotoğraf Çekme")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            if (_controller != null && _controller!.value.isInitialized)
              SizedBox(
                width: 400,
                height: 300,
                child: CameraPreview(_controller!),
              )
            else if (_errorMessage == null)
              const Text("Kamera kapalı"),
            const SizedBox(height: 20),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isCapturing ? null : _initCamera,
                  child: const Text("Start"),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isCapturing ? _stopCapturing : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Stop"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _capturedImages.length,
                itemBuilder: (context, index) {
                  return kIsWeb
                      ? Image.network(_capturedImages[index].path, fit: BoxFit.cover)
                      : Image.file(File(_capturedImages[index].path), fit: BoxFit.cover);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
