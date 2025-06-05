// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:HPGM/bee_counter/bee_counter_model.dart';
// import 'package:HPGM/bee_counter/server_video_service.dart';
// import 'package:HPGM/bee_counter/bee_counter_results_screen.dart';
// import 'package:HPGM/Services/bee_analysis_service.dart';
// import 'package:video_player/video_player.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:http/http.dart' as http;
// import 'dart:async';

// class BeeVideoAnalysisScreen extends StatefulWidget {
//   final String hiveId;

//   const BeeVideoAnalysisScreen({Key? key, required this.hiveId})
//     : super(key: key);

//   @override
//   _BeeVideoAnalysisScreenState createState() => _BeeVideoAnalysisScreenState();
// }

// class _BeeVideoAnalysisScreenState extends State<BeeVideoAnalysisScreen> {
//   final ServerVideoService _serverVideoService = ServerVideoService();
//   final BeeAnalysisService _beeAnalysisService = BeeAnalysisService();
//   bool _isLoading = false;
//   String _statusMessage = '';
//   List<ServerVideo> _videos = [];
//   ServerVideo? _selectedVideo;
//   BeeCount? _analysisResult;
//   VideoPlayerController? _videoController;
//   bool _isVideoInitialized = false;
//   String? _downloadedVideoPath;
//   double _downloadProgress = 0.0;
//   bool _isAnalyzing = false;
//   bool _isRefreshing = false;
//   Timer? _autoRefreshTimer;

//   // Define theme colors
//   final Color _primaryColor = Color(0xFFFFB74D); // Amber accent
//   final Color _secondaryColor = Color(0xFF4CAF50); // Green
//   final Color _backgroundColor = Color(0xFFF5F5F5); // Light grey background
//   final Color _cardColor = Colors.white;
//   final Color _textColor = Color(0xFF424242); // Dark grey
//   final Color _accentColor = Color(0xFFFF9800); // Orange
//   final Color _enteringColor = Color(0xFF4CAF50); // Green for entering bees
//   final Color _exitingColor = Color(0xFFE57373); // Red for exiting bees

//   @override
//   void initState() {
//     super.initState();
//     _fetchVideos();

//     // Set up auto-refresh timer (every 5 minutes)
//     _autoRefreshTimer = Timer.periodic(Duration(minutes: 5), (timer) {
//       if (!_isLoading && !_isAnalyzing && !_isRefreshing) {
//         _refreshLatestVideo();
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _videoController?.dispose();
//     _autoRefreshTimer?.cancel();
//     _serverVideoService.dispose();
//     super.dispose();
//   }

//   // Fetch only the latest video
//   Future<void> _fetchVideos() async {
//     if (_isRefreshing) return;

//     setState(() {
//       _isLoading = true;
//       _isRefreshing = true;
//       _statusMessage = 'Fetching latest video...';
//     });

//     try {
//       final videos = await _serverVideoService.fetchVideosFromServer(
//         widget.hiveId,
//       );

//       // Debug the videos received
//       print('Received ${videos.length} videos from service');

//       // Filter out videos with invalid URLs
//       final validVideos =
//           videos.where((video) {
//             final isValid =
//                 video.url.isNotEmpty &&
//                 (video.url.startsWith('http://') ||
//                     video.url.startsWith('https://'));

//             if (!isValid) {
//               print('Invalid video URL: ${video.url}');
//             }

//             return isValid;
//           }).toList();

//       print('Found ${validVideos.length} valid videos');

//       setState(() {
//         _videos = validVideos;
//         _isLoading = false;
//         _statusMessage = validVideos.isEmpty ? 'No video found' : '';

//         // Reset selected video
//         _selectedVideo = null;

//         // Select the video if available
//         if (validVideos.isNotEmpty) {
//           _selectedVideo = validVideos.first;
//           print('Selected video: ${_selectedVideo!.id}, URL: ${_selectedVideo!.url}');

//           // Download and prepare the video for playback
//           _prepareVideoForPlayback(_selectedVideo!);
//         }
//       });
//     } catch (e) {
//       print('Error fetching videos: $e');
//       setState(() {
//         _isLoading = false;
//         _statusMessage = 'Error fetching videos: $e';
//       });
//     } finally {
//       setState(() {
//         _isRefreshing = false;
//       });
//     }
//   }

//   // This function is now the same as _fetchVideos since we only get the latest
//   Future<void> _fetchLatestVideo() async {
//     _fetchVideos();
//   }

//   // Refresh only the latest video
//   Future<void> _refreshLatestVideo() async {
//     if (_isRefreshing) return;

//     setState(() {
//       _isRefreshing = true;
//     });

//     try {
//       final latestVideo = await _serverVideoService.fetchLatestVideoFromServer(
//         widget.hiveId,
//       );

//       if (latestVideo != null) {
//         // Check if this is a new video compared to our current latest
//         bool isNewVideo = true;
//         if (_selectedVideo != null && _selectedVideo!.id == latestVideo.id) {
//           isNewVideo = false;
//         }

//         if (isNewVideo) {
//           print('New latest video detected: ${latestVideo.id}');
//           setState(() {
//             // Add to videos list if not already there
//             if (!_videos.any((v) => v.id == latestVideo.id)) {
//               _videos.insert(0, latestVideo);
//             }

//             _selectedVideo = latestVideo;
//           });

//           // Download and prepare the video for playback
//           await _prepareVideoForPlayback(latestVideo);
//         } else {
//           print('Latest video unchanged: ${latestVideo.id}');
//         }
//       }
//     } catch (e) {
//       print('Error refreshing latest video: $e');
//     } finally {
//       setState(() {
//         _isRefreshing = false;
//       });
//     }
//   }

//   Future<void> _prepareVideoForPlayback(ServerVideo video) async {
//     setState(() {
//       _isVideoInitialized = false;
//       _downloadProgress = 0.0;
//       _statusMessage = 'Downloading video for playback...';
//     });

//     try {
//       // Download the video
//       final videoPath = await _beeAnalysisService.downloadVideo(video.url);

//       if (videoPath == null) {
//         setState(() {
//           _statusMessage = 'Failed to download video';
//         });
//         return;
//       }

//       _downloadedVideoPath = videoPath;

//       // Initialize the video player
//       await _initializeVideoPlayer(videoPath);

//       setState(() {
//         _statusMessage = '';
//       });
//     } catch (e) {
//       print('Error preparing video for playback: $e');
//       setState(() {
//         _statusMessage = 'Error preparing video: $e';
//       });
//     }
//   }

//   Future<void> _initializeVideoPlayer(String videoPath) async {
//     // Dispose of the old controller if it exists
//     await _videoController?.dispose();

//     // Create a new controller
//     _videoController = VideoPlayerController.file(File(videoPath));

//     try {
//       // Initialize the controller
//       await _videoController!.initialize();

//       // Set looping
//       await _videoController!.setLooping(true);

//       // Update the UI
//       setState(() {
//         _isVideoInitialized = true;
//       });
//     } catch (e) {
//       print('Error initializing video player: $e');
//       setState(() {
//         _statusMessage = 'Error initializing video: $e';
//       });
//     }
//   }

//   Future<void> _analyzeVideo() async {
//     if (_selectedVideo == null) {
//       setState(() {
//         _statusMessage = 'No video selected';
//       });
//       return;
//     }

//     setState(() {
//       _isLoading = true;
//       _isAnalyzing = true;
//       _statusMessage = 'Analyzing video...';
//       _analysisResult = null;
//     });

//     try {
//       print(
//         'Starting analysis of video: ${_selectedVideo!.id}, URL: ${_selectedVideo!.url}',
//       );

//       final result = await _serverVideoService.processServerVideo(
//         _selectedVideo!,
//         onStatusUpdate: (status) {
//           setState(() {
//             _statusMessage = status;
//           });
//         },
//       );

//       setState(() {
//         _isLoading = false;
//         _isAnalyzing = false;
//         _analysisResult = result;

//         if (result != null) {
//           _statusMessage = 'Analysis complete';
//           print(
//             'Analysis complete: ${result.beesEntering} bees entering, ${result.beesExiting} bees exiting',
//           );
//         } else {
//           _statusMessage = 'Analysis failed. Please check logs for details.';
//           print('Analysis failed');
//         }
//       });
//     } catch (e) {
//       print('Error analyzing video: $e');
//       setState(() {
//         _isLoading = false;
//         _isAnalyzing = false;
//         _statusMessage = 'Error analyzing video: $e';
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Bee Video Analysis'),
//         backgroundColor: _primaryColor,
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: Icon(Icons.history),
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => BeeCountResultsScreen(
//                     hiveId: widget.hiveId,
//                     date: DateTime.now(),
//                   ),
//                 ),
//               );
//             },
//             tooltip: 'View History',
//           ),
//         ],
//       ),
//       backgroundColor: _backgroundColor,
//       body: RefreshIndicator(
//         onRefresh: () => _fetchVideos(),
//         child: SingleChildScrollView(
//           physics: AlwaysScrollableScrollPhysics(),
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               _buildHeader(),
//               const SizedBox(height: 16),
//               _buildVideoSelectionCard(),
//               const SizedBox(height: 16),
//               if (_isVideoInitialized && _videoController != null)
//                 _buildVideoPlayerCard(),
//               if (_isLoading) _buildLoadingIndicator(),
//               if (!_isLoading && _statusMessage.isNotEmpty) _buildStatusMessage(),
//               if (_selectedVideo != null && !_isLoading)
//                 _buildSelectedVideoCard(),
//               if (_analysisResult != null) ...[
//                 const SizedBox(height: 16),
//                 _buildAnalysisResultsCard(),
//               ],
//               // Add some extra space at the bottom for better scrolling
//               const SizedBox(height: 50),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader() {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
//       decoration: BoxDecoration(
//         color: _primaryColor,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Row(
//         children: [
//           Icon(
//             Icons.analytics_outlined,
//             color: Colors.white,
//             size: 36,
//           ),
//           const SizedBox(width: 16),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Bee Activity Analysis',
//                   style: TextStyle(
//                     color: Colors.white,
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   'Monitor bee movement in and out of your hive',
//                   style: TextStyle(
//                     color: Colors.white.withOpacity(0.9),
//                     fontSize: 14,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildVideoSelectionCard() {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       color: _cardColor,
//       child: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(
//                   Icons.video_library,
//                   color: _primaryColor,
//                   size: 24,
//                 ),
//                 const SizedBox(width: 12),
//                 Text(
//                   'Latest Video',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: _textColor,
//                   ),
//                 ),
//                 Spacer(),
//                 Container(
//                   decoration: BoxDecoration(
//                     color: _primaryColor.withOpacity(0.2),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: IconButton(
//                     icon: Icon(Icons.refresh, color: _primaryColor),
//                     onPressed: _isRefreshing ? null : _fetchVideos,
//                     tooltip: 'Refresh video',
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 24),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 icon: const Icon(Icons.update),
//                 label: const Text('Get Latest Video'),
//                 onPressed: _isRefreshing ? null : _fetchVideos,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _secondaryColor,
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//               ),
//             ),
//             if (_selectedVideo != null) ...[
//               const SizedBox(height: 12),
//               const Divider(),
//               const SizedBox(height: 12),
//               Text(
//                 'Selected Video:',
//                 style: TextStyle(
//                   fontSize: 16,
//                   color: _textColor.withOpacity(0.7),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 _selectedVideo!.timestamp != null
//                   ? _formatDateTime(_selectedVideo!.timestamp!)
//                   : 'Unknown date',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.bold,
//                   color: _textColor,
//                 ),
//               ),
//             ],
//             const SizedBox(height: 16),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 icon: const Icon(Icons.analytics),
//                 label: const Text('Analyze Video'),
//                 onPressed: _selectedVideo != null && !_isAnalyzing ? _analyzeVideo : null,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _accentColor,
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 12),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   disabledBackgroundColor: Colors.grey.shade400,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Future<void> _initializeMockVideoPlayer() async {
//     // Dispose of the old controller if it exists
//     await _videoController?.dispose();

//     try {
//       // Create a placeholder video file
//       final directory = await getTemporaryDirectory();
//       final placeholderPath = '${directory.path}/placeholder.mp4';

//       // Check if we already have a placeholder file
//       final placeholderFile = File(placeholderPath);
//       if (!await placeholderFile.exists()) {
//         // Create a simple placeholder file
//         await placeholderFile.writeAsBytes([0, 0, 0, 0]);
//       }

//       // Create a new controller with the placeholder
//       _videoController = VideoPlayerController.file(placeholderFile);

//       // Initialize the controller
//       await _videoController!.initialize().catchError((e) {
//         print('Error initializing mock video player: $e');
//         // If initialization fails, we'll show a message instead of the player
//         setState(() {
//           _isVideoInitialized = false;
//           _statusMessage = 'Mock video unavailable in offline mode';
//         });
//         return false;
//       });

//       // Set looping
//       await _videoController!.setLooping(true);

//       // Update the UI
//       setState(() {
//         _isVideoInitialized = true;
//       });
//     } catch (e) {
//       print('Error creating mock video player: $e');
//       setState(() {
//         _isVideoInitialized = false;
//         _statusMessage = 'Mock video unavailable in offline mode';
//       });
//     }
//   }

//   Widget _buildVideoPlayerCard() {
//     // Check if this is a mock video
//     final bool isMockVideo = _selectedVideo != null && _selectedVideo!.id.startsWith('mock_');

//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       color: _cardColor,
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(
//                   isMockVideo ? Icons.video_library : Icons.play_circle_filled,
//                   color: _primaryColor,
//                   size: 24,
//                 ),
//                 const SizedBox(width: 12),
//                 Text(
//                   isMockVideo ? 'Mock Video Preview' : 'Video Preview',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: _textColor,
//                   ),
//                 ),
//                 Spacer(),
//                 if (!isMockVideo)
//                   IconButton(
//                     icon: Icon(
//                       _videoController!.value.isPlaying
//                           ? Icons.pause
//                           : Icons.play_arrow,
//                       color: _primaryColor,
//                     ),
//                     onPressed: () {
//                       setState(() {
//                         _videoController!.value.isPlaying
//                             ? _videoController!.pause()
//                             : _videoController!.play();
//                       });
//                     },
//                   ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             if (isMockVideo)
//               Container(
//                 height: 200,
//                 width: double.infinity,
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade300,
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(
//                         Icons.videocam_off,
//                         size: 48,
//                         color: Colors.grey.shade600,
//                       ),
//                       SizedBox(height: 16),
//                       Text(
//                         'Mock Video (Offline Mode)',
//                         style: TextStyle(
//                           color: Colors.grey.shade700,
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       SizedBox(height: 8),
//                       Text(
//                         'Video preview not available in offline mode',
//                         style: TextStyle(
//                           color: Colors.grey.shade600,
//                           fontSize: 14,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               )
//             else
//               AspectRatio(
//                 aspectRatio: _videoController!.value.aspectRatio,
//                 child: Stack(
//                   alignment: Alignment.center,
//                   children: [
//                     VideoPlayer(_videoController!),
//                     if (_isAnalyzing)
//                       Container(
//                         color: Colors.black.withOpacity(0.5),
//                         child: Center(
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             children: [
//                               CircularProgressIndicator(
//                                 valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
//                               ),
//                               SizedBox(height: 16),
//                               Text(
//                                 'Analyzing Video...',
//                                 style: TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             if (!isMockVideo) ...[
//               const SizedBox(height: 8),
//               VideoProgressIndicator(
//                 _videoController!,
//                 allowScrubbing: true,
//                 colors: VideoProgressColors(
//                   playedColor: _primaryColor,
//                   bufferedColor: _primaryColor.withOpacity(0.3),
//                   backgroundColor: Colors.grey.shade300,
//                 ),
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildLoadingIndicator() {
//     return Center(
//       child: Card(
//         elevation: 4,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//         color: _cardColor,
//         child: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             children: [
//               CircularProgressIndicator(
//                 valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
//                 value: _downloadProgress > 0 ? _downloadProgress : null,
//               ),
//               const SizedBox(height: 16),
//               Text(
//                 _statusMessage,
//                 style: TextStyle(
//                   color: _textColor,
//                   fontSize: 16,
//                 ),
//                 textAlign: TextAlign.center,
//               ),
//               if (_downloadProgress > 0) ...[
//                 const SizedBox(height: 8),
//                 Text(
//                   '${(_downloadProgress * 100).toStringAsFixed(1)}%',
//                   style: TextStyle(
//                     color: _primaryColor,
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildStatusMessage() {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       color: _cardColor,
//       child: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Row(
//           children: [
//             Icon(
//               _statusMessage.contains('Error') ? Icons.error : Icons.info,
//               color: _statusMessage.contains('Error') ? Colors.red : _primaryColor,
//               size: 24,
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Text(
//                 _statusMessage,
//                 style: TextStyle(
//                   color: _textColor,
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSelectedVideoCard() {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       color: _cardColor,
//       child: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(
//                   Icons.videocam,
//                   color: _primaryColor,
//                   size: 24,
//                 ),
//                 const SizedBox(width: 12),
//                 Text(
//                   'Selected Video',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: _textColor,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 16),
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: _backgroundColor,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Column(
//                 children: [
//                   _buildInfoRow(
//                     'Video ID',
//                     _shortenId(_selectedVideo!.id),
//                     Icons.video_file,
//                   ),
//                   const Divider(height: 24),
//                   _buildInfoRow(
//                     'Timestamp',
//                     _selectedVideo!.timestamp != null
//                         ? _formatDateTime(_selectedVideo!.timestamp!)
//                         : 'Unknown',
//                     Icons.access_time,
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildInfoRow(String title, String value, IconData icon, {int maxLines = 1}) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Icon(
//           icon,
//           color: _secondaryColor,
//           size: 20,
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: TextStyle(
//                   color: _textColor.withOpacity(0.7),
//                   fontSize: 14,
//                   fontWeight: FontWeight.w500,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 value,
//                 style: TextStyle(
//                   color: _textColor,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w500,
//                 ),
//                 overflow: TextOverflow.ellipsis,
//                 maxLines: maxLines,
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildAnalysisResultsCard() {
//     final netChange = _analysisResult!.netChange;
//     final netChangeColor = netChange >= 0 ? _enteringColor : _exitingColor;
//     final netChangeIcon = netChange >= 0 ? Icons.arrow_upward : Icons.arrow_downward;

//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       color: _cardColor,
//       child: Padding(
//         padding: const EdgeInsets.all(20),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(
//                   Icons.analytics,
//                   color: _primaryColor,
//                   size: 24,
//                 ),
//                 const SizedBox(width: 12),
//                 Text(
//                   'Analysis Results',
//                   style: TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: _textColor,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 20),

//             // Summary cards
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildSummaryCard(
//                     'Bees Entering',
//                     '${_analysisResult!.beesEntering}',
//                     Icons.login,
//                     _enteringColor,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: _buildSummaryCard(
//                     'Bees Exiting',
//                     '${_analysisResult!.beesExiting}',
//                     Icons.logout,
//                     _exitingColor,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),
//             Row(
//               children: [
//                 Expanded(
//                   child: _buildSummaryCard(
//                     'Net Change',
//                     '${netChange >= 0 ? "+" : ""}${_analysisResult!.netChange}',
//                     netChangeIcon,
//                     netChangeColor,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: _buildSummaryCard(
//                     'Total Activity',
//                     '${_analysisResult!.totalActivity}',
//                     Icons.sync,
//                     _secondaryColor,
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 20),
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: _backgroundColor,
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: _buildInfoRow(
//                 'Analysis Timestamp',
//                 _formatDateTime(_analysisResult!.timestamp.toLocal()),
//                 Icons.calendar_today,
//               ),
//             ),

//             const SizedBox(height: 24),
//             SizedBox(
//               width: double.infinity,
//               child: ElevatedButton.icon(
//                 icon: const Icon(Icons.bar_chart),
//                 label: const Text('View All Results for This Day'),
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => BeeCountResultsScreen(
//                         hiveId: widget.hiveId,
//                         date: _analysisResult!.timestamp,
//                       ),
//                     ),
//                   );
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _secondaryColor,
//                   foregroundColor: Colors.white,
//                   padding: const EdgeInsets.symmetric(vertical: 14),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
//     return Container(
//       padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.1),
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: color.withOpacity(0.3), width: 1),
//       ),
//       child: Column(
//         children: [
//           Icon(
//             icon,
//             color: color,
//             size: 28,
//           ),
//           const SizedBox(height: 8),
//           Text(
//             value,
//             style: TextStyle(
//               color: color,
//               fontSize: 24,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             title,
//             style: TextStyle(
//               color: _textColor.withOpacity(0.8),
//               fontSize: 14,
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   // Separate method to build the dropdown to handle the overflow issue
//   Widget _buildVideoDropdown() {
//     if (_videos.isEmpty) {
//       return Container(
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(8),
//           border: Border.all(color: Colors.grey.shade400),
//         ),
//         child: DropdownButtonFormField<String>(
//           decoration: InputDecoration(
//             labelText: 'No Videos Available',
//             border: InputBorder.none,
//             contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           ),
//           items: [],
//           onChanged: null,
//         ),
//       );
//     }

//     return Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey.shade400),
//       ),
//       child: DropdownButtonFormField<ServerVideo>(
//         decoration: InputDecoration(
//           labelText: 'Select Video',
//           border: InputBorder.none,
//           contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//         ),
//         value: _selectedVideo,
//         isExpanded: true,
//         menuMaxHeight: 300,
//         icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
//         items: _videos.map((video) {
//           final formattedDate =
//               video.timestamp != null
//                   ? _formatDateTime(video.timestamp!)
//                   : 'Unknown date';

//           return DropdownMenuItem<ServerVideo>(
//             value: video,
//             child: Text(
//               'Video ${_shortenId(video.id)} - $formattedDate',
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(fontSize: 14, color: _textColor),
//             ),
//           );
//         }).toList(),
//         onChanged: (value) {
//           setState(() {
//             _selectedVideo = value;
//             if (value != null) {
//               _prepareVideoForPlayback(value);
//             }
//           });
//         },
//       ),
//     );
//   }

//   // Helper method to format date time in a more compact way
//   String _formatDateTime(DateTime dateTime) {
//     return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
//   }

//   // Helper method to shorten long IDs
//   String _shortenId(String id) {
//     if (id.length > 8) {
//       return '${id.substring(0, 8)}...';
//     }
//     return id;
//   }
// }