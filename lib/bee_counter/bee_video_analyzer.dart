import 'dart:io';
import 'dart:math';
// import 'dart:typed_data';
// import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:chewie/chewie.dart';
import 'package:image/image.dart' as img;
import 'package:HPGM/bee_counter/bee_video_analysis_result.dart';
import 'package:HPGM/hive_model.dart';
import 'package:HPGM/bee_counter/bee_counter_results_screen.dart';

// Create a global instance that can be accessed from anywhere
BeeVideoAnalyzer? globalAnalyzer;

class BeeVideoAnalyzer {
  final ImagePicker _picker = ImagePicker();

  // Video related properties
  File? videoFile;
  File? processedVideoFile;
  VideoPlayerController? videoController;
  ChewieController? chewieController;

  // Processing state
  bool isProcessing = false;
  bool modelLoaded = false;
  double processingProgress = 0.0;

  // Model related properties
  Interpreter? _interpreter;
  final int inputSize = 640; // Adjust based on your model's input size
  final double confidenceThreshold =
      0.15; // Lower threshold to detect more bees

  // Bee counting stats
  int beesIn = 0;
  int beesOut = 0;

  // Additional metrics for BeeAnalysisResult
  int get netChange => beesIn - beesOut;
  int get totalActivity => beesIn + beesOut;
  double detectionConfidence = 0.0;
  double processingTime = 0.0;
  int framesAnalyzed = 0;
  String modelVersion = "1.0.0";

  // Track the current video ID to ensure that the results are for the correct video
  String currentVideoId = '';

  // Callback for updating UI state
  final Function(void Function()) updateState;

  BeeVideoAnalyzer({required this.updateState}) {
    // Set this instance as the global analyzer
    globalAnalyzer = this;
  }

  /// Initialize the analyzer and load the model
  Future<bool> initialize() async {
    try {
      await loadModel();
      return modelLoaded;
    } catch (e) {
      print('Error initializing analyzer: $e');
      return false;
    }
  }

  /// Load the TFLite model - REQUIRED for processing
  Future<void> loadModel() async {
    try {
      print('Loading TFLite model...');

      // Try to find the model file
      final modelPath = await _getModel();

      if (modelPath == null) {
        throw Exception(
          'No TFLite model file found. Please add your model to assets/models/',
        );
      }

      // Configure interpreter options for better performance
      final options = InterpreterOptions()..threads = 4;

      _interpreter = await Interpreter.fromFile(
        File(modelPath),
        options: options,
      );

      print(
        'Model loaded successfully. Input shape: ${_interpreter!.getInputTensor(0).shape}',
      );
      print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');

      updateState(() {
        modelLoaded = true;
      });
    } catch (e) {
      print('Error loading model: $e');
      updateState(() {
        modelLoaded = false;
      });
      throw Exception('Failed to load ML model: $e');
    }
  }

  /// Get the model file from assets
  Future<String?> _getModel() async {
    final appDir = await getApplicationDocumentsDirectory();
    final possiblePaths = [
      'assets/models/bee_counter_model.tflite',
      'assets/models/best_float.tflite',
      'assets/models/best_float32.tflite',
      'assets/bee_model.tflite',
    ];

    for (final assetPath in possiblePaths) {
      try {
        final fileName = assetPath.split('/').last;
        final file = File('${appDir.path}/$fileName');

        if (!await file.exists()) {
          // Try to copy from assets
          final byteData = await rootBundle.load(assetPath);
          await file.writeAsBytes(byteData.buffer.asUint8List());
        }

        if (await file.exists()) {
          print('Found model at: ${file.path}');
          return file.path;
        }
      } catch (e) {
        print('Could not load model from $assetPath: $e');
        continue;
      }
    }

    print('No model file found in any location');
    return null;
  }

  /// Generate a unique ID for each video
  String get _generateVideoId {
    return 'video_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
  }

  /// Pick a video from camera or gallery
  Future<void> pickVideo(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
      );

      if (pickedFile != null) {
        // Dispose previous controllers if they exist
        disposeVideoControllers();

        // Generate new video ID
        final newVideoId = _generateVideoId;

        updateState(() {
          videoFile = File(pickedFile.path);
          processedVideoFile = null;
          beesIn = 0;
          beesOut = 0;
          processingProgress = 0.0;
          currentVideoId = newVideoId;
          detectionConfidence = 0.0;
          processingTime = 0.0;
          framesAnalyzed = 0;
        });

        print('Video ID: $currentVideoId');

        // Initialize the video controller with the selected video
        await initializeVideoController(videoFile!);
      }
    } catch (e) {
      print('Error picking video: $e');
      return Future.error(e);
    }
  }

  /// Dispose video controllers to prevent memory leaks and threading issues
  void disposeVideoControllers() {
    try {
      // Dispose in proper order to prevent threading issues
      chewieController?.dispose();
      chewieController = null;

      videoController?.dispose();
      videoController = null;
    } catch (e) {
      print('Error disposing video controllers: $e');
    }
  }

  /// Initialize video player controller with better error handling
  Future<void> initializeVideoController(File videoFile) async {
    try {
      // Dispose previous controllers if they exist
      disposeVideoControllers();

      videoController = VideoPlayerController.file(videoFile);
      await videoController!.initialize();

      chewieController = ChewieController(
        videoPlayerController: videoController!,
        autoPlay: false,
        looping: false,
        aspectRatio: videoController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'Error loading video: $errorMessage',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      updateState(() {});

      print('Video controller initialized successfully');
    } catch (e) {
      print('Error initializing video controller: $e');
    }
  }

  // Process a video file directly (for automatic processing)
  Future<BeeAnalysisResult?> processVideoFile(
    File videoFile,
    String videoId, {
    Function(String)? onStatusUpdate,
  }) async {
    if (!modelLoaded) {
      onStatusUpdate?.call("ML model not loaded");
      return null;
    }

    print('Starting ML video analysis for: $videoId');
    onStatusUpdate?.call("Initializing ML video analysis...");

    // Store current video id
    final videoIdBeingProcessed = videoId;
    final startTime = DateTime.now();

    try {
      // Set the video file
      this.videoFile = videoFile;
      this.currentVideoId = videoId;
      onStatusUpdate?.call("Loading video...");

      // Initialize video controller
      await initializeVideoController(videoFile);

      onStatusUpdate?.call("Running ML inference on video frames...");

      // Process the video with ML model
      await processVideo();

      // Calculate processing time
      final endTime = DateTime.now();
      final processingTimeMs = endTime.difference(startTime).inMilliseconds;
      processingTime = processingTimeMs / 1000.0;

      print(
        'ML analysis completed in ${processingTime}s: $beesIn bees in, $beesOut bees out',
      );

      // Create and return the analysis result
      return BeeAnalysisResult(
        id: videoId,
        videoId: videoId,
        beesIn: beesIn,
        beesOut: beesOut,
        netChange: netChange,
        totalActivity: totalActivity,
        detectionConfidence: detectionConfidence,
        processingTime: processingTime,
        framesAnalyzed: framesAnalyzed,
        modelVersion: modelVersion,
        timestamp: DateTime.now(),
        videoPath: processedVideoFile?.path,
      );
    } catch (e) {
      print('Error processing video file: $e');
      onStatusUpdate?.call("ML processing error: $e");
      return null;
    }
  }

  /// Process the selected video to count bees using ML model
  Future<void> processVideo() async {
    if (videoFile == null) {
      return Future.error('Please select a video first');
    }

    if (!modelLoaded || _interpreter == null) {
      return Future.error('ML model is not loaded');
    }

    if (videoController == null || !videoController!.value.isInitialized) {
      return Future.error('Video controller is not initialized');
    }

    // Store current video id
    final videoIdBeingProcessed = currentVideoId;
    final startTime = DateTime.now();

    updateState(() {
      isProcessing = true;
      processingProgress = 0.0;
      beesIn = 0;
      beesOut = 0;
      framesAnalyzed = 0;
    });

    try {
      print('Processing video ID: $videoIdBeingProcessed with ML model');

      // Process video with real ML inference
      final beeCountResults = await _processVideoWithMLModel(
        videoIdBeingProcessed,
      );

      // Calculate processing time
      final endTime = DateTime.now();
      final processingTimeMs = endTime.difference(startTime).inMilliseconds;

      // Check if this is still the current video being processed
      if (videoIdBeingProcessed == currentVideoId) {
        updateState(() {
          beesIn = beeCountResults['beesIn']!;
          beesOut = beeCountResults['beesOut']!;
          processingTime = processingTimeMs / 1000.0;
        });

        print(
          'ML results for video ID: $videoIdBeingProcessed - Bees In: $beesIn, Bees Out: $beesOut',
        );
        return Future.value();
      } else {
        print(
          'Ignoring results for old video ID: $videoIdBeingProcessed (current is $currentVideoId)',
        );
        return Future.error('Processing canceled - new video selected');
      }
    } catch (e) {
      print('Error processing video with ML: $e');
      return Future.error(e);
    } finally {
      updateState(() {
        // Only update the state if the video ID matches the current one
        if (currentVideoId == videoIdBeingProcessed) {
          isProcessing = false;
        }
      });
    }
  }

  /// Process video with actual ML model inference
  Future<Map<String, int>> _processVideoWithMLModel(String videoId) async {
    int totalBeesIn = 0;
    int totalBeesOut = 0;
    double totalConfidence = 0.0;
    int totalDetections = 0;

    try {
      if (videoController == null || !videoController!.value.isInitialized) {
        throw Exception('Video controller not initialized');
      }

      final Duration videoDuration = videoController!.value.duration;
      final double durationSeconds = videoDuration.inMilliseconds / 1000.0;

      // Sample frames at 2 FPS for processing
      final double frameInterval = 0.5; // 500ms between frames
      final int totalFramesToProcess = (durationSeconds / frameInterval).ceil();

      print(
        'Video duration: ${durationSeconds}s, processing $totalFramesToProcess frames with ML model',
      );

      framesAnalyzed = totalFramesToProcess;
      List<Map<String, dynamic>>? previousDetections;

      // Process frames by seeking to specific timestamps
      for (int i = 0; i < totalFramesToProcess; i++) {
        // Check if processing was canceled
        if (currentVideoId != videoId) {
          throw Exception('Processing canceled - new video selected');
        }

        // Calculate timestamp for this frame
        final double timestamp = i * frameInterval;
        final Duration seekPosition = Duration(
          milliseconds: (timestamp * 1000).round(),
        );

        // Skip if we've exceeded video duration
        if (seekPosition >= videoDuration) break;

        // Update progress
        updateState(() {
          processingProgress = i / totalFramesToProcess;
        });

        try {
          // Seek to the specific timestamp
          await videoController!.seekTo(seekPosition);

          // Wait for the seek to complete
          await Future.delayed(const Duration(milliseconds: 200));

          // Capture the actual video frame
          final img.Image? frameImage = await _captureVideoFrame();

          if (frameImage != null) {
            // Run ML inference on the real frame
            final List<Map<String, dynamic>> detections = await _runMLInference(
              frameImage,
            );

            // Update confidence metrics
            for (var detection in detections) {
              totalConfidence += detection['confidence'] as double;
              totalDetections++;
            }

            // Count bees based on movement between frames
            if (previousDetections != null) {
              final Map<String, int> counts = _countBeesInOut(
                previousDetections,
                detections,
                frameImage.height,
                i,
              );

              totalBeesIn += counts['in']!;
              totalBeesOut += counts['out']!;

              // Update the state for UI feedback
              updateState(() {
                beesIn = totalBeesIn;
                beesOut = totalBeesOut;
              });
            }

            previousDetections = detections;
          }
        } catch (e) {
          print('Error processing frame at ${timestamp}s: $e');
          continue;
        }

        // Print progress every 5 frames
        if (i % 5 == 0) {
          print(
            'ML processed ${i + 1}/$totalFramesToProcess frames. Current counts: In=$totalBeesIn, Out=$totalBeesOut',
          );
        }
      }

      // Calculate average confidence
      double avgConfidence =
          totalDetections > 0 ? (totalConfidence / totalDetections) * 100 : 0.0;

      print(
        'ML processing complete. Final counts: Bees In=$totalBeesIn, Bees Out=$totalBeesOut, Confidence: ${avgConfidence.toStringAsFixed(1)}%',
      );

      // Update detection confidence
      updateState(() {
        detectionConfidence = avgConfidence;
      });

      return {'beesIn': totalBeesIn, 'beesOut': totalBeesOut};
    } catch (e) {
      print('Error in ML video processing: $e');
      rethrow;
    }
  }

  /// Capture actual frame from video player
  Future<img.Image?> _captureVideoFrame() async {
    try {
      // This is a simplified frame capture - you might need to implement
      // a more sophisticated method depending on your Flutter version
      // For now, return null to indicate frame capture needs implementation

      // TODO: Implement actual video frame capture
      // This would typically involve using platform-specific code or
      // video frame extraction libraries

      print(
        'Frame capture not yet implemented - requires platform-specific code',
      );
      return null;
    } catch (e) {
      print('Error capturing video frame: $e');
      return null;
    }
  }

  /// Run ML inference on captured frame
  Future<List<Map<String, dynamic>>> _runMLInference(img.Image image) async {
    try {
      if (_interpreter == null) {
        return [];
      }

      // Resize image to model input size
      final img.Image resizedImage = img.copyResize(
        image,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );

      // Convert to model input format
      final inputBuffer = _imageToByteList(resizedImage);

      // Get model shapes
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      // Prepare output tensor
      final outputTensor = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);

      // Run inference
      _interpreter!.run(inputBuffer, outputTensor);

      // Process detections
      final List<Map<String, dynamic>> detections = _processDetections(
        outputTensor,
        image.width,
        image.height,
      );

      return detections;
    } catch (e) {
      print('Error running ML inference: $e');
      return [];
    }
  }

  /// Convert image to model input format
  List _imageToByteList(img.Image image) {
    try {
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final inputType = _interpreter!.getInputTensor(0).type;

      final int batch = inputShape[0];
      final int height = inputShape[1];
      final int width = inputShape[2];
      final int channels = inputShape[3];

      var buffer;

      if (inputType.toString().contains('float')) {
        buffer = List.filled(
          batch * height * width * channels,
          0.0,
        ).reshape([batch, height, width, channels]);

        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final pixel = image.getPixel(x, y);
            buffer[0][y][x][0] = (pixel.r / 255.0);
            buffer[0][y][x][1] = (pixel.g / 255.0);
            buffer[0][y][x][2] = (pixel.b / 255.0);
          }
        }
      } else {
        buffer = List.filled(
          batch * height * width * channels,
          0,
        ).reshape([batch, height, width, channels]);

        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final pixel = image.getPixel(x, y);
            buffer[0][y][x][0] = pixel.r;
            buffer[0][y][x][1] = pixel.g;
            buffer[0][y][x][2] = pixel.b;
          }
        }
      }

      return buffer;
    } catch (e) {
      print('Error in _imageToByteList: $e');
      return [
        [
          [[]],
        ],
      ]; // Return minimal buffer
    }
  }

  /// Process model output detections
  List<Map<String, dynamic>> _processDetections(
    List outputTensor,
    int originalWidth,
    int originalHeight,
  ) {
    final List<Map<String, dynamic>> detections = [];

    try {
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      // Handle YOLOv8 output format [1, 5+classes, 8400]
      if (outputShape.length == 3 && outputShape[2] == 8400) {
        final int numAnchors = outputShape[2];

        for (int i = 0; i < numAnchors; i++) {
          final x = outputTensor[0][0][i].toDouble();
          final y = outputTensor[0][1][i].toDouble();
          final w = outputTensor[0][2][i].toDouble();
          final h = outputTensor[0][3][i].toDouble();
          final confidence = outputTensor[0][4][i].toDouble();

          if (confidence >= confidenceThreshold) {
            detections.add({
              'bbox': [
                ((x - w / 2) * originalWidth).round(),
                ((y - h / 2) * originalHeight).round(),
                ((x + w / 2) * originalWidth).round(),
                ((y + h / 2) * originalHeight).round(),
              ],
              'confidence': confidence,
              'class_id': 0,
              'center': [x * originalWidth, y * originalHeight],
            });
          }
        }
      }

      print('ML detected ${detections.length} potential bees in this frame');
    } catch (e) {
      print('Error processing ML detections: $e');
    }

    return detections;
  }

  /// Count bees entering and exiting based on movement detection
  Map<String, int> _countBeesInOut(
    List<Map<String, dynamic>> previousDetections,
    List<Map<String, dynamic>> currentDetections,
    int imageHeight,
    int frameNumber,
  ) {
    int beesIn = 0;
    int beesOut = 0;

    try {
      if (previousDetections.isEmpty || currentDetections.isEmpty) {
        return {'in': 0, 'out': 0};
      }

      final entranceLine = 0.6; // 60% from top
      final entranceBuffer = 0.1; // 10% buffer

      // Track bee movements between frames
      for (final current in currentDetections) {
        Map<String, dynamic>? bestMatch;
        double bestDistance = double.infinity;

        final List<double> currentCenter = List<double>.from(current['center']);

        for (final previous in previousDetections) {
          final List<double> previousCenter = List<double>.from(
            previous['center'],
          );

          final double distance = sqrt(
            pow(currentCenter[0] - previousCenter[0], 2) +
                pow(currentCenter[1] - previousCenter[1], 2),
          );

          if (distance < bestDistance) {
            bestDistance = distance;
            bestMatch = previous;
          }
        }

        // Track movement if match found within reasonable distance
        if (bestMatch != null && bestDistance < 150) {
          final List<double> previousCenter = List<double>.from(
            bestMatch['center'],
          );
          final double previousY = previousCenter[1] / imageHeight;
          final double currentY = currentCenter[1] / imageHeight;

          // Check for crossing the entrance line
          if (previousY < entranceLine - entranceBuffer &&
              currentY > entranceLine + entranceBuffer) {
            beesIn++;
          } else if (previousY > entranceLine + entranceBuffer &&
              currentY < entranceLine - entranceBuffer) {
            beesOut++;
          }
        }
      }

      if (beesIn > 0 || beesOut > 0) {
        print('Frame $frameNumber: $beesIn bees entered, $beesOut bees exited');
      }
    } catch (e) {
      print('Error counting bees: $e');
    }

    return {'in': beesIn, 'out': beesOut};
  }

  /// Navigate to the results screen after processing is complete
  void navigateToResultsScreen(BuildContext context, String hiveId) {
    if (currentVideoId.isNotEmpty && !isProcessing) {
      final hive = HiveData(
        id: hiveId,
        name: 'Current Hive',
        status: 'Active',
        healthStatus: 'Healthy',
        lastChecked: DateTime.now().toIso8601String(),
        autoProcessingEnabled: false,
        weight: 25.0,
        temperature: 35.0,
        honeyLevel: 50.0,
        isConnected: true,
        isColonized: true,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  BeeCountResultsScreen(hiveId: hiveId, date: DateTime.now()),
        ),
      );
    }
  }

  /// Clean up resources
  void dispose() {
    disposeVideoControllers();
    _interpreter?.close();
  }
}
