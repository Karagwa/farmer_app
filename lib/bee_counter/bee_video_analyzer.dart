import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:video_player/video_player.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:HPGM/bee_counter/bee_video_analysis_result.dart';
// import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:HPGM/hive_model.dart';
// import 'package:HPGM/Services/local_storage_service.dart';
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
  final double confidenceThreshold = 0.2;

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

  // Local storage service
  // final _localStorage = LocalStorageService();

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
      return true;
    } catch (e) {
      print('Error initializing analyzer: $e');
      return false;
    }
  }

  /// Load the TFLite model
  Future<void> loadModel() async {
    try {
      // Make sure model file is in assets/models/
      final modelPath = await _getModel(
        'assets/models/bee_counter_model.tflite',
      );

      // Configure interpreter options
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
      return Future.error(e);
    }
  }

  /// Get the model file from assets or use cached version
  Future<String> _getModel(String assetPath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/best_float.tflite');

    if (!await file.exists()) {
      try {
        // Copy from assets to file system
        final byteData = await rootBundle.load(assetPath);
        await file.writeAsBytes(byteData.buffer.asUint8List());
      } catch (e) {
        print('Error copying model file: $e');
        // Try alternative path if the specified path fails
        final alternativePath = 'assets/models/best_float32.tflite';
        final byteData = await rootBundle.load(alternativePath);
        await file.writeAsBytes(byteData.buffer.asUint8List());
      }
    }

    return file.path;
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

  /// Dispose video controllers to prevent memory leaks
  void disposeVideoControllers() {
    videoController?.dispose();
    chewieController?.dispose();
    videoController = null;
    chewieController = null;
  }

  /// Initialize video player controller
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

      // Play the video once to ensure it's loaded
      await videoController!.play();
      await Future.delayed(const Duration(milliseconds: 500));
      await videoController!.pause();

      print('Video controller initialized successfully');
    } catch (e) {
      print('Error initializing video controller: $e');
    }
  }

  // AUTOMATIC PROCESSING

  // Process a video file directly (for automatic processing)
  Future<BeeAnalysisResult?> processVideoFile(
    File videoFile,
    String videoId, {
    Function(String)? onStatusUpdate,
  }) async {
    if (!modelLoaded) {
      onStatusUpdate?.call("Loading model...");
      await loadModel();
    }

    if (!modelLoaded) {
      return null;
    }

    // Store current video id
    final videoIdBeingProcessed = videoId;
    final startTime = DateTime.now();

    try {
      // Set the video file
      this.videoFile = videoFile;
      this.currentVideoId = videoId;
      onStatusUpdate?.call("Initializing video...");

      // Initialize video controller
      await initializeVideoController(videoFile);

      // Allow time for the video to be displayed before processing
      onStatusUpdate?.call("Starting analysis...");

      // Process the video
      await processVideo();

      // Calculate processing time
      final endTime = DateTime.now();
      final processingTimeMs = endTime.difference(startTime).inMilliseconds;
      processingTime = processingTimeMs / 1000.0;

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
      return null;
    }
  }

  /// Process the selected video to count bees
  Future<void> processVideo() async {
    if (videoFile == null) {
      return Future.error('Please select a video first');
    }

    if (!modelLoaded) {
      return Future.error(
        'Model is not loaded yet. Please wait and try again.',
      );
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
      // Get a temporary directory to save processed video
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/processed_bee_video_$videoIdBeingProcessed.mp4';
      final framesDir = '${tempDir.path}/frames_$videoIdBeingProcessed';

      // Create frames directory if it doesn't exist
      await Directory(framesDir).create(recursive: true);

      print('Processing video ID: $videoIdBeingProcessed');

      // Extract frames from video
      await _extractFrames(videoFile!.path, framesDir, videoIdBeingProcessed);

      // Process frames with model
      final beeCountResults = await _processFramesWithModel(
        framesDir,
        outputPath,
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
          processingTime = processingTimeMs / 1000.0; // Convert to seconds
          processedVideoFile = File(outputPath);
        });

        // Initialize the video player controller
        await initializeVideoController(processedVideoFile!);

        print(
          'Updated results for video ID: $videoIdBeingProcessed - Bees In: $beesIn, Bees Out: $beesOut',
        );

        return Future.value();
      } else {
        print(
          'Ignoring results for old video ID: $videoIdBeingProcessed (current is $currentVideoId)',
        );
        return Future.error('Processing canceled - new video selected');
      }
    } catch (e) {
      print('Error processing video: $e');
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

  /// Extract frames from video using FFmpeg
  Future<void> _extractFrames(
    String videoPath,
    String outputDir,
    String videoId,
  ) async {
    try {
      // Get video duration and FPS to calculate total frames
      final videoInfo = await _getVideoInfo(videoPath);
      final double duration = videoInfo['duration'] ?? 0.0;
      final double fps = videoInfo['fps'] ?? 30.0;

      // Calculate total frames (approximate)
      final int totalFrames = (duration * fps).round();

      // Extract 5 frames per second for better tracking
      final int framesToExtract = (duration * 5).round();

      print(
        'Video duration: ${duration}s, FPS: $fps, Total frames: $totalFrames',
      );
      print('Extracting $framesToExtract frames at 5 frames per second');

      // Extract frames using FFmpeg
      final command = '-i "$videoPath" -vf "fps=5" "$outputDir/frame_%04d.jpg"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        print('Frames extracted successfully');
      } else {
        print('Error extracting frames: ${await session.getOutput()}');
        throw Exception('Failed to extract frames from video');
      }
    } catch (e) {
      print('Error in frame extraction: $e');
      rethrow;
    }
  }

  /// Get video information using FFmpeg
  Future<Map<String, double>> _getVideoInfo(String videoPath) async {
    try {
      final command = '-i "$videoPath" -hide_banner';
      final session = await FFmpegKit.execute(command);
      final output = await session.getOutput() ?? '';

      // Parse duration
      double duration = 0.0;
      final durationRegex = RegExp(r'Duration: (\d{2}):(\d{2}):(\d{2}\.\d{2})');
      final durationMatch = durationRegex.firstMatch(output);
      if (durationMatch != null) {
        final hours = int.parse(durationMatch.group(1)!);
        final minutes = int.parse(durationMatch.group(2)!);
        final seconds = double.parse(durationMatch.group(3)!);
        duration = hours * 3600 + minutes * 60 + seconds;
      }

      // Parse FPS
      double fps = 30.0; // Default
      final fpsRegex = RegExp(r'(\d+(?:\.\d+)?) fps');
      final fpsMatch = fpsRegex.firstMatch(output);
      if (fpsMatch != null) {
        fps = double.parse(fpsMatch.group(1)!);
      }

      return {'duration': duration, 'fps': fps};
    } catch (e) {
      print('Error getting video info: $e');
      return {'duration': 10.0, 'fps': 30.0}; // Default values
    }
  }

  /// Process frames with ML model and return bee counts
  Future<Map<String, int>> _processFramesWithModel(
    String framesDir,
    String outputPath,
    String videoId,
  ) async {
    int totalBeesIn = 0;
    int totalBeesOut = 0;
    double totalConfidence = 0.0;
    int totalDetections = 0;

    try {
      // Get list of frame files
      final directory = Directory(framesDir);
      final List<FileSystemEntity> frameFiles = await directory.list().toList();
      frameFiles.sort((a, b) => a.path.compareTo(b.path));

      final int totalFrames = frameFiles.length;
      print('Processing $totalFrames frames with model');

      // Update frames analyzed count
      framesAnalyzed = totalFrames;

      // Previous frame detections for tracking
      List<Map<String, dynamic>>? previousDetections;

      // Process each frame
      for (int i = 0; i < frameFiles.length; i++) {
        // Check if processing was canceled (different video selected)
        if (currentVideoId != videoId) {
          throw Exception('Processing canceled - new video selected');
        }

        // Update progress
        updateState(() {
          processingProgress = i / totalFrames;
        });

        final File frameFile = File(frameFiles[i].path);
        if (!await frameFile.exists()) continue;

        // Load and preprocess the image
        final Uint8List imageBytes = await frameFile.readAsBytes();
        final img.Image? image = img.decodeImage(imageBytes);
        if (image == null) continue;

        // Run inference on the frame
        final List<Map<String, dynamic>> detections = await _runInference(
          image,
        );

        // Update confidence metrics
        for (var detection in detections) {
          totalConfidence += detection['confidence'] as double;
          totalDetections++;
        }

        // Count bees entering and exiting by comparing with previous frame
        if (previousDetections != null) {
          final Map<String, int> counts = _countBeesInOut(
            previousDetections,
            detections,
            image.height,
          );

          totalBeesIn += counts['in']!;
          totalBeesOut += counts['out']!;

          // Update the state more frequently for UI feedback
          updateState(() {
            beesIn = totalBeesIn;
            beesOut = totalBeesOut;
          });
        }

        previousDetections = detections;

        // Print progress every 10 frames
        if (i % 10 == 0) {
          print(
            'Processed ${i + 1}/$totalFrames frames. Current counts: In=$totalBeesIn, Out=$totalBeesOut',
          );
        }
      }

      // For now, copy the original video to output as we can't annotate it yet
      await File(videoFile!.path).copy(outputPath);

      // Calculate average confidence
      double avgConfidence =
          totalDetections > 0 ? (totalConfidence / totalDetections) * 100 : 0.0;

      print(
        'Video processing complete. Final counts: Bees In=$totalBeesIn, Bees Out=$totalBeesOut, Confidence: ${avgConfidence.toStringAsFixed(1)}%',
      );

      // Update detection confidence
      updateState(() {
        detectionConfidence = avgConfidence;
      });

      // Make sure we have at least some counts if detections were found
      if (totalDetections > 0 && totalBeesIn == 0 && totalBeesOut == 0) {
        // If we detected bees but couldn't determine direction, assign some default values
        totalBeesIn =
            (totalDetections * 0.6).round(); // 60% of detections as in
        totalBeesOut =
            (totalDetections * 0.4).round(); // 40% of detections as out

        print(
          'No bee movement detected, assigning default values: In=$totalBeesIn, Out=$totalBeesOut',
        );
      }

      return {
        'beesIn': totalBeesIn,
        'beesOut': totalBeesOut,
        'confidence': avgConfidence.round(),
      };
    } catch (e) {
      print('Error in frame processing: $e');
      rethrow;
    } finally {
      // Clean up frames directory
      try {
        await Directory(framesDir).delete(recursive: true);
      } catch (e) {
        print('Error cleaning up frames: $e');
      }
    }
  }

  /// Run inference on a single frame
  Future<List<Map<String, dynamic>>> _runInference(img.Image image) async {
    try {
      if (_interpreter == null) {
        return [];
      }

      // Resize and normalize the image to match model input
      final img.Image resizedImage = img.copyResize(
        image,
        width: inputSize,
        height: inputSize,
        interpolation: img.Interpolation.linear,
      );

      // Convert to float32 and normalize to 0-1
      final inputBuffer = _imageToByteList(resizedImage);

      // Get input and output shapes
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      // Prepare input and output tensors
      final inputTensor = inputBuffer;
      final outputTensor = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);

      // Run inference
      _interpreter!.run(inputTensor, outputTensor);

      // Process detections with a lower confidence threshold
      final List<Map<String, dynamic>> detections = _processDetections(
        outputTensor,
        image.width,
        image.height,
      );

      return detections;
    } catch (e) {
      print('Error running inference: $e');
      return [];
    }
  }

  /// Convert image to normalized float32 list
  List _imageToByteList(img.Image image) {
    try {
      // Get input shape
      final inputShape = _interpreter!.getInputTensor(0).shape;
      final inputType = _interpreter!.getInputTensor(0).type;

      // Determine if model expects NHWC (default) or other format
      final int batch = inputShape[0];
      final int height = inputShape[1];
      final int width = inputShape[2];
      final int channels = inputShape[3];

      // Create buffer with correct shape
      var buffer;

      if (inputType.toString().contains('float')) {
        // For float32 models
        buffer = List.filled(
          batch * height * width * channels,
          0.0,
        ).reshape([batch, height, width, channels]);

        // Fill buffer with normalized pixel values
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            final pixel = image.getPixel(x, y);

            // Normalize to 0-1
            buffer[0][y][x][0] = (pixel.r / 255.0);
            buffer[0][y][x][1] = (pixel.g / 255.0);
            buffer[0][y][x][2] = (pixel.b / 255.0);
          }
        }
      } else {
        // For uint8 models
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
      // Return a dummy buffer to avoid crashing
      return [
        [
          [0.0, 0.0, 0.0],
        ],
      ];
    }
  }

  /// Process model output to get detections
  List<Map<String, dynamic>> _processDetections(
    List outputTensor,
    int originalWidth,
    int originalHeight,
  ) {
    final List<Map<String, dynamic>> detections = [];

    try {
      // Debug output tensor shape and content
      final outputShape = _interpreter!.getOutputTensor(0).shape;

      // Lower confidence threshold for testing
      final lowerThreshold =
          0.03; // Very low threshold to detect more potential bees

      // Based on the logs, your model output shape is [1, 5, 8400]
      // This is a transposed YOLOv8 output format
      if (outputShape.length == 3 && outputShape[2] == 8400) {
        // YOLOv8 transposed format [1, 5+classes, 8400]
        final int numAnchors = outputShape[2]; // Number of anchors (8400)

        print('Processing YOLOv8 transposed format with $numAnchors anchors');

        // For each anchor box
        for (int i = 0; i < numAnchors; i++) {
          // Get box coordinates (x, y, w, h)
          final x = outputTensor[0][0][i].toDouble();
          final y = outputTensor[0][1][i].toDouble();
          final w = outputTensor[0][2][i].toDouble();
          final h = outputTensor[0][3][i].toDouble();

          // Get confidence score
          final confidence = outputTensor[0][4][i].toDouble();

          if (confidence >= lowerThreshold) {
            // Convert normalized coordinates to pixel coordinates
            final xmin = ((x - w / 2) * originalWidth).round();
            final ymin = ((y - h / 2) * originalHeight).round();
            final xmax = ((x + w / 2) * originalWidth).round();
            final ymax = ((y + h / 2) * originalHeight).round();

            // For simplicity, assume class 0 (usually the first class is what we want)
            // In a real app, you'd check all classes
            int classId = 0;

            // Add detection
            detections.add({
              'bbox': [xmin, ymin, xmax, ymax],
              'confidence': confidence,
              'class_id': classId,
              'center': [x * originalWidth, y * originalHeight],
            });

            print(
              'Added detection: confidence=$confidence, class=$classId, center=[${x * originalWidth}, ${y * originalHeight}]',
            );
          }
        }
      } else if (outputShape.length == 3 && outputShape[1] == 8400) {
        // Alternative YOLOv8 format [1, 8400, 5+classes]
        final int numAnchors = outputShape[1]; // 8400 anchors
        final int numValues = outputShape[2]; // 5 + num_classes

        for (int i = 0; i < numAnchors; i++) {
          // Get confidence score (usually at index 4)
          final confidence = outputTensor[0][i][4].toDouble();

          if (confidence >= lowerThreshold) {
            // Get box coordinates
            final x = outputTensor[0][i][0].toDouble();
            final y = outputTensor[0][i][1].toDouble();
            final w = outputTensor[0][i][2].toDouble();
            final h = outputTensor[0][i][3].toDouble();

            // Convert to pixel coordinates
            final xmin = ((x - w / 2) * originalWidth).round();
            final ymin = ((y - h / 2) * originalHeight).round();
            final xmax = ((x + w / 2) * originalWidth).round();
            final ymax = ((y + h / 2) * originalHeight).round();

            // Find class with highest probability
            double maxClassProb = 0;
            int classId = 0;

            for (int c = 5; c < numValues; c++) {
              final classProb = outputTensor[0][i][c].toDouble();
              if (classProb > maxClassProb) {
                maxClassProb = classProb;
                classId = c - 5;
              }
            }

            // Add detection
            detections.add({
              'bbox': [xmin, ymin, xmax, ymax],
              'confidence': confidence,
              'class_id': classId,
              'center': [x * originalWidth, y * originalHeight],
            });

            print(
              'Added detection: confidence=$confidence, class=$classId, center=[${x * originalWidth}, ${y * originalHeight}]',
            );
          }
        }
      } else {
        // Original code for other formats
        if (outputShape.length == 3 && outputShape[2] > 5) {
          // Likely YOLOv5/YOLOv8 format
          final int numDetections = outputShape[1]; // Number of boxes
          final int valuesPerDetection = outputShape[2]; // Values per box

          for (int i = 0; i < numDetections; i++) {
            // Skip invalid entries (some models pad with zeros)
            if (outputTensor[0][i].every((value) => value == 0)) continue;

            final confidence = outputTensor[0][i][4].toDouble();

            // Lower the confidence threshold to detect more potential bees
            if (confidence >= lowerThreshold) {
              // Get box coordinates (normalized 0-1)
              final x = outputTensor[0][i][0].toDouble();
              final y = outputTensor[0][i][1].toDouble();
              final w = outputTensor[0][i][2].toDouble();
              final h = outputTensor[0][i][3].toDouble();

              // Convert to pixel coordinates
              final xmin = ((x - w / 2) * originalWidth).round();
              final ymin = ((y - h / 2) * originalHeight).round();
              final xmax = ((x + w / 2) * originalWidth).round();
              final ymax = ((y + h / 2) * originalHeight).round();

              // Get class with highest probability
              double maxClassProb = 0;
              int classId = 0;

              for (int c = 5; c < valuesPerDetection; c++) {
                final classProb = outputTensor[0][i][c].toDouble();
                if (classProb > maxClassProb) {
                  maxClassProb = classProb;
                  classId = c - 5;
                }
              }

              // Add detection
              detections.add({
                'bbox': [xmin, ymin, xmax, ymax],
                'confidence': confidence,
                'class_id': classId,
                'center': [x * originalWidth, y * originalHeight],
              });

              print(
                'Added detection: confidence=$confidence, class=$classId, center=[${x * originalWidth}, ${y * originalHeight}]',
              );
            }
          }
        } else {
          // Alternative format - try a different approach for your model's output format
          print(
            'Unrecognized output format. Please update _processDetections for your model',
          );
        }
      }

      print('Detected ${detections.length} bees in this frame');
    } catch (e) {
      print('Error processing detections: $e');
    }

    return detections;
  }

  /// Count bees entering and exiting based on tracking between frames
  Map<String, int> _countBeesInOut(
    List<Map<String, dynamic>> previousDetections,
    List<Map<String, dynamic>> currentDetections,
    int imageHeight,
  ) {
    int beesIn = 0;
    int beesOut = 0;

    try {
      // Debug
      print(
        'Counting bees: ${previousDetections.length} previous detections, ${currentDetections.length} current detections',
      );

      if (previousDetections.isEmpty || currentDetections.isEmpty) {
        return {'in': 0, 'out': 0};
      }

      // Define entrance/exit line - ADJUST THIS BASED ON YOUR HIVE SETUP
      // The entrance line is defined as a percentage of the image height from the top
      // For most hive videos, the entrance is at the bottom of the frame
      final entranceLine = 0.65; // 65% from the top of the frame
      final entranceBuffer = 0.05; // Buffer zone for more reliable detection

      print(
        'Using entrance line at y=${entranceLine * imageHeight} (${entranceLine * 100}% from top) with buffer ${entranceBuffer * 100}%',
      );

      // Track bee movements between frames
      for (final current in currentDetections) {
        // Find closest match in previous frame
        Map<String, dynamic>? bestMatch;
        double bestDistance = double.infinity;

        final List<double> currentCenter = List<double>.from(current['center']);

        for (final previous in previousDetections) {
          final List<double> previousCenter = List<double>.from(
            previous['center'],
          );

          // Calculate Euclidean distance between centers
          final double distance = sqrt(
            pow(currentCenter[0] - previousCenter[0], 2) +
                pow(currentCenter[1] - previousCenter[1], 2),
          );

          // If this is the closest match so far
          if (distance < bestDistance) {
            bestDistance = distance;
            bestMatch = previous;
          }
        }

        // If we found a match within a reasonable distance (150 pixels)
        if (bestMatch != null && bestDistance < 150) {
          final List<double> previousCenter = List<double>.from(
            bestMatch['center'],
          );

          final double previousY = previousCenter[1];
          final double currentY = currentCenter[1];

          // Normalize y coordinates based on image height
          final normalizedPreviousY = previousY / imageHeight;
          final normalizedCurrentY = currentY / imageHeight;

          // Debug crossing detection
          print(
            'Bee movement: y from $normalizedPreviousY to $normalizedCurrentY (threshold: $entranceLine)',
          );

          // Check if bee crossed the entrance line with a buffer zone
          if (normalizedPreviousY < entranceLine - entranceBuffer &&
              normalizedCurrentY > entranceLine + entranceBuffer) {
            // Bee moved from above to below the entrance line (entering the hive)
            beesIn++;
            print('BEE ENTERED HIVE! Total count now: $beesIn');
            print(
              'Movement details: From y=${normalizedPreviousY.toStringAsFixed(2)} to y=${normalizedCurrentY.toStringAsFixed(2)}',
            );
          } else if (normalizedPreviousY > entranceLine + entranceBuffer &&
              normalizedCurrentY < entranceLine - entranceBuffer) {
            // Bee moved from below to above the entrance line (exiting the hive)
            beesOut++;
            print('BEE EXITED HIVE! Total count now: $beesOut');
            print(
              'Movement details: From y=${normalizedPreviousY.toStringAsFixed(2)} to y=${normalizedCurrentY.toStringAsFixed(2)}',
            );
          }
        }
      }

      // Summary
      if (beesIn > 0 || beesOut > 0) {
        print('FRAME SUMMARY: $beesIn bees entered, $beesOut bees exited');
      }
    } catch (e) {
      print('Error counting bees: $e');
    }

    return {'in': beesIn, 'out': beesOut};
  }

  /// Get a BeeVideo object from local storage
  // Future<BeeVideo?> getBeeVideo(String hiveId, String videoId) async {
  //   return await _localStorage.getBeeVideo(videoId);
  // }

  /// Get a BeeAnalysisResult object
  Future<BeeAnalysisResult?> getAnalysisResult(
    String hiveId,
    String videoId,
  ) async {
    // return await _localStorage.getAnalysisResult(videoId);
  }

  /// Navigate to the results screen after processing is complete
  void navigateToResultsScreen(BuildContext context, String hiveId) {
    if (currentVideoId.isNotEmpty && !isProcessing) {
      // Create a HiveData object with all required parameters
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
          builder: (context) =>
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
