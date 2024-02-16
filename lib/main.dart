import 'dart:async';
import 'dart:io';
// import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

Future<void> main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras[1];

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: TakePictureScreen(
        // Pass the appropriate camera to the TakePictureScreen widget.
        camera: firstCamera,
      ),
    ),
  );
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({
    super.key,
    required this.camera,
  });

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.medium,
    );

    // Next, initialize the controller. This returns a Future.
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a picture')),
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        // Provide an onPressed callback.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;

            // Attempt to take a picture and get the file `image`
            // where it was saved.
            final image = await _controller.takePicture();

            if (!mounted) return;

            // If the picture was taken, display it on a new screen.
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DisplayPictureScreen(
                  // Pass the automatically generated path to
                  // the DisplayPictureScreen widget.
                  imagePath: image.path,
                ),
              ),
            );
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: FaceMeshWidget(imagePath: imagePath),
    );
  }
}

class FaceMeshWidget extends StatefulWidget {
  const FaceMeshWidget({super.key, required this.imagePath});

  final String imagePath;

  @override
  State<FaceMeshWidget> createState() => _FaceMeshWidgetState();
}

class _FaceMeshWidgetState extends State<FaceMeshWidget> {
  final FaceDetector = GoogleMlKit.vision.faceDetector(FaceDetectorOptions(
    enableLandmarks: true,
    enableContours: true,
  ));
  List<Face> _faces = [];
  ui.Image? _image;
  ui.Image? _pngImage;

  @override
  void initState() {
    super.initState();
    loadPngImage(); // Load the PNG image when the widget is initialized
  }

  Future<void> loadPngImage() async {
    final ByteData data = await rootBundle.load('pic/heart.png');
    final Uint8List bytes = data.buffer.asUint8List();
    _pngImage = await decodeImageFromList(bytes);
  }

  Future<ui.Image> loadImage() async {
    final data = await File(widget.imagePath).readAsBytes();
    return await decodeImageFromList(data);
  }

  Future<void> detectFaces() async {
    final inputImage = InputImage.fromFilePath(widget.imagePath);
    _faces = await FaceDetector.processImage(inputImage);
    _image = await loadImage();
    // if (mounted) {
    //   setState(() {
    //     _faces = _faces;
    //   });
    // }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
        future: detectFaces(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CustomPaint(
              painter: FacePainter(image: _image!, faces: _faces, pngImage: _pngImage!),
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        }
    );
  }
}

class FacePainter extends CustomPainter {
  final ui.Image image;
  final List<Face> faces;
  final ui.Image pngImage;

  FacePainter({required this.image, required this.faces, required this.pngImage});

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return image != oldDelegate.image || faces != oldDelegate.faces;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.red;

    canvas.drawImage(image, Offset.zero, paint);

    for (var i = 0; i < faces.length; i++) {
      final Rect faceRect = faces[i].boundingBox;

      final double offsetY = 0; // Adjust the vertical offset here
      final double increasedSize = 1.00; // You can adjust this factor as needed
      final Rect destinationRect = Rect.fromPoints(
        // Offset(faceRect.left * increasedSize, faceRect.top + offsetY),
        // Offset(faceRect.right , faceRect.bottom * increasedSize + offsetY),
        Offset(faceRect.left , faceRect.top * increasedSize + offsetY),
        Offset(faceRect.right , faceRect.bottom * increasedSize + offsetY),
      );

      canvas.drawImageRect(
        pngImage,
        Rect.fromPoints(Offset(0, 0), Offset(pngImage.width.toDouble(), pngImage.height.toDouble())),
        destinationRect,
        paint,
      );
    }
  }
}