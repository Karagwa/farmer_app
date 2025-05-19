import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:HPGM/bee_counter/bee_video_analysis_screen.dart';
import 'package:HPGM/models/video_file.dart';

void main() {
  testWidgets('BeeVideoAnalysisScreen shows correct UI elements', (
    WidgetTester tester,
  ) async {
    // Create mock video data
    final mockVideo = VideoFile(
      id: 'mock_video_1',
      filePath: 'path/to/video.mp4',
      size: 1024,
      thumbnail: null,
      timestamp: DateTime.now(),
      analysisStatus: 'pending',
    );

    // Build our app and trigger a frame
    await tester.pumpWidget(
      MaterialApp(
        home: BeeVideoAnalysisScreen(
          hiveId: 'test_hive_1',
          // Adjust parameters based on your actual BeeVideoAnalysisScreen constructor
          // selectedVideo: mockVideo,
        ),
      ),
    );

    // Verify that the widget appears
    expect(find.byType(BeeVideoAnalysisScreen), findsOneWidget);
  });
}
