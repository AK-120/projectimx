import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:cloud_firestore/cloud_firestore.dart';

class ScannerScreen extends StatefulWidget {
  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  CameraController? _cameraController;
  bool isDetecting = false;
  FaceDetector? _faceDetector;
  bool isLoading = true;
  Timer? _timer;
  int _remainingTime = 10; // 10 seconds timer
  bool _isFaceDetected = false;
  bool showBlackScreen = false; // Controls the black screen display
  String? _matchedUser; // Holds the matched user's information
  

  final String _serverUrl =
      'https://projectimx-face-embedding.hf.space/generate-embedding'; // Replace with your server URL
  List<double>? _embeddings;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadFaceDetector();
    _startTimer();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front);

    _cameraController = CameraController(frontCamera, ResolutionPreset.high);
    await _cameraController!.initialize();

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });

    // Start face detection automatically
    _startFaceDetection();
  }

  Future<void> _loadFaceDetector() async {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: true,
        enableLandmarks: true,
      ),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        _timer?.cancel();
        if (!_isFaceDetected) {
          setState(() {
            _matchedUser = "No match found"; // Display "No match found"
          });
        }
      }
    });
  }

  void _startFaceDetection() {
    // Periodically check for faces every 1 second
    Timer.periodic(Duration(seconds: 1), (timer) async {
      if (!isDetecting) {
        await _captureAndDetect();
      }
    });
  }

  Future<void> _captureAndDetect() async {
    if (_isFaceDetected) return; // Skip detection if a face is already detected

    isDetecting = true;

    try {
      final image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);
      List<Face> faces = await _faceDetector!.processImage(inputImage);

      if (faces.isNotEmpty) {
        setState(() {
          _isFaceDetected = true;
          showBlackScreen = true; // Display black screen
          _matchedUser =
              "Detecting..."; // Reset matched user on new face detection
        });

        // Crop the face image
        File faceImage = await _cropFace(image.path, faces.first.boundingBox);

        // Send to Hugging Face server for embeddings
        List<double> embeddings = await _fetchEmbeddingsFromServer(faceImage);

        // Match the embeddings with the database
        String matchedUser = await _matchEmbeddingsWithDatabase(embeddings);

        setState(() {
          _matchedUser = matchedUser.isNotEmpty
              ? "$matchedUser"
              : "No match found";
        });
      }
    } catch (e) {
      print('Error: $e');
    } finally {
      if (!_isFaceDetected) isDetecting = false; // Continue detecting
    }
  }

  Future<File> _cropFace(String imagePath, Rect boundingBox) async {
    final imageBytes = await File(imagePath).readAsBytes();
    img.Image? image = img.decodeImage(imageBytes);

    if (image == null) return File(imagePath);

    img.Image croppedFace = img.copyCrop(
      image,
      boundingBox.left.toInt(),
      boundingBox.top.toInt(),
      boundingBox.width.toInt(),
      boundingBox.height.toInt(),
    );

    final directory = Directory.systemTemp;
    final croppedFilePath = '${directory.path}/cropped_face.jpg';
    File croppedFile = File(croppedFilePath)
      ..writeAsBytesSync(img.encodeJpg(croppedFace));

    return croppedFile;
  }

  Future<List<double>> _fetchEmbeddingsFromServer(File faceImage) async {
    try {
      // Convert the image to base64
      List<int> imageBytes = await faceImage.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      // Prepare the JSON body
      final Map<String, dynamic> payload = {
        "image": base64Image, // Pass the image in base64 format
      };

      // Send the POST request with JSON body
      final response = await http.post(
        Uri.parse(_serverUrl),
        headers: {
          "Content-Type": "application/json", // Ensure correct content type
        },
        body: jsonEncode(payload), // Convert the payload to JSON
      );

      // Check the response
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<double>.from(data['embedding']);
      } else {
        throw Exception(
            'Failed to fetch embeddings: ${response.statusCode}\n${response.body}');
      }
    } catch (e) {
      print('Error: $e');
      throw Exception('Error fetching embeddings');
    }
  }

  Future<String> _matchEmbeddingsWithDatabase(List<double> embeddings) async {
    final usersCollection = FirebaseFirestore.instance.collection('users');
    final snapshot = await usersCollection.get();

    String matchedUser = "No match found"; // Default value when no match found
    double bestMatchScore = double.infinity; // Start with a very high score

    for (var doc in snapshot.docs) {
      final userEmbedding = List<double>.from(doc['embedding']);
      final userName = doc['name'];
      final userDepartment = doc['department'];
      final userType = doc['user_type'];
      final userId = doc['id'];
      final Semester = doc['Semester']; // Assuming 'image' is the field for the user

      double similarityScore =
          _calculateCosineSimilarity(embeddings, userEmbedding);

      // Setting a threshold for a "good enough" match
      if (similarityScore < bestMatchScore && similarityScore > 0.7) {
        bestMatchScore = similarityScore;
        matchedUser = "$userName, Department: $userDepartment, $userType";
        await _recordAttendance(userId, userName, userDepartment, userType);
      }
    }

    return matchedUser;
  }

  double _calculateCosineSimilarity(
      List<double> embeddings1, List<double> embeddings2) {
    double dotProduct = 0.0;
    double magnitude1 = 0.0;
    double magnitude2 = 0.0;

    for (int i = 0; i < embeddings1.length; i++) {
      dotProduct += embeddings1[i] * embeddings2[i];
      magnitude1 += embeddings1[i] * embeddings1[i];
      magnitude2 += embeddings2[i] * embeddings2[i];
    }

    magnitude1 = sqrt(magnitude1);
    magnitude2 = sqrt(magnitude2);

    if (magnitude1 == 0 || magnitude2 == 0) {
      return 0.0;
    }

    return dotProduct / (magnitude1 * magnitude2);
  }

  Future<void> _recordAttendance(String userId, String userName,
      String userDepartment, String userType) async {
    final now = DateTime.now();
    final formattedDate = "${now.year}-${now.month}-${now.day}";
    final formattedTime = "${now.hour}:${now.minute}:${now.second}";

    final attendanceCollection =
        FirebaseFirestore.instance.collection('attendance');

    // Check if an attendance record already exists for this user on the current date
    final existingRecord = await attendanceCollection
        .where('id', isEqualTo: userId)
        .where('date', isEqualTo: formattedDate)
        .get();

    if (existingRecord.docs.isEmpty) {
      await attendanceCollection.add({
        'id': userId,
        'name': userName,
        'department': userDepartment,
        'user_type': userType,
        'date': formattedDate,
        'time_in': formattedTime,
        'time_out': null,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else {
      final docId = existingRecord.docs.first.id;
      final existingData = existingRecord.docs.first.data();

      if (existingData['time_out'] == null) {
        await attendanceCollection.doc(docId).update({
          'time_out': formattedTime,
        });
      }
    }
  }

  /// Helper function to clean up resources
  void _disposeResources() {
    _cameraController?.dispose();
    _faceDetector?.close();
    _timer?.cancel();
  }

  @override
  void dispose() {
    _disposeResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Face Detection')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                if (!showBlackScreen) CameraPreview(_cameraController!),
                if (showBlackScreen || _matchedUser != null)
                  Container(
                    color: Colors.black,
                    child: Center(
                      child: _matchedUser == "Detecting..."
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  strokeWidth: 5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                                SizedBox(height: 20),
                                Text(
                                  'Loading...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _matchedUser ?? '',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                    ),
                  ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Column(
                    children: [
                      if (_remainingTime > 0 && !_isFaceDetected)
                        Text(
                          'Detecting... $_remainingTime seconds left',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                      if (_isFaceDetected)
                        Icon(Icons.check_circle, color: Colors.green, size: 50),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
