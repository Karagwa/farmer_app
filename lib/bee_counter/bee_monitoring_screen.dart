import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:HPGM/bee_counter/bee_counter_model.dart';
import 'package:HPGM/bee_counter/auto_video_processing_service.dart';
import 'package:HPGM/bee_counter/bee_count_database.dart';

class BeeMonitoringScreen extends StatefulWidget {
  final String hiveId;

  const BeeMonitoringScreen({
    Key? key,
    required this.hiveId,
  }) : super(key: key);

  @override
  _BeeMonitoringScreenState createState() => _BeeMonitoringScreenState();
}

class _BeeMonitoringScreenState extends State<BeeMonitoringScreen> {
  late AutoVideoProcessingService _autoService;
  List<BeeCount> _beeCounts = [];
  String _statusMessage = 'Initializing...';
  bool _serviceRunning = false;

  @override
  void initState() {
    super.initState();
    _setupAutoService();
    _loadBeeCounts();
  }

  void _setupAutoService() {
    // Create the service
    _autoService = AutoVideoProcessingService(autoStart: false);
    
    // Set up event listeners
    _autoService.onStatusUpdate = (status) {
      setState(() {
        _statusMessage = status;
      });
    };
    
    _autoService.onError = (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    };
    
    _autoService.onNewAnalysisComplete = (beeCount) {
      // Add the new count to our list and refresh UI
      setState(() {
        _beeCounts.add(beeCount);
        _beeCounts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('New analysis completed: ${beeCount.beesEntering} entering, ${beeCount.beesExiting} exiting'),
          backgroundColor: Colors.green,
        ),
      );
    };
  }

  Future<void> _loadBeeCounts() async {
    final counts = await BeeCountDatabase.instance.readBeeCountsByHiveId(widget.hiveId);
    setState(() {
      _beeCounts = counts;
      _beeCounts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });
  }

  void _toggleAutoService() {
    if (_autoService.isRunning) {
      _autoService.stopMonitoring();
    } else {
      _autoService.startMonitoring(hiveId: widget.hiveId);
    }
    
    setState(() {
      _serviceRunning = _autoService.isRunning;
    });
  }

  Future<void> _manualCheckForVideos() async {
    final success = await _autoService.manualCheckForVideos(widget.hiveId);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Service busy. Try again later.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    // Results will be handled via the onNewAnalysisComplete callback
  }

  @override
  void dispose() {
    _autoService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bee Monitoring - Hive ${widget.hiveId}'),
        actions: [
          IconButton(
            icon: Icon(_serviceRunning ? Icons.pause : Icons.play_arrow),
            onPressed: _toggleAutoService,
            tooltip: _serviceRunning ? 'Stop Auto Monitoring' : 'Start Auto Monitoring',
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: EdgeInsets.all(8),
            color: _autoService.isProcessing ? Colors.blue.shade100 : Colors.grey.shade200,
            child: Row(
              children: [
                if (_autoService.isProcessing)
                  Container(
                    width: 20,
                    height: 20,
                    margin: EdgeInsets.only(right: 8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  _serviceRunning ? 'AUTO-ON' : 'AUTO-OFF',
                  style: TextStyle(
                    color: _serviceRunning ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Bee count list
          Expanded(
            child: _beeCounts.isEmpty
                ? Center(child: Text('No bee counts available yet'))
                : ListView.builder(
                    itemCount: _beeCounts.length,
                    itemBuilder: (context, index) {
                      final beeCount = _beeCounts[index];
                      return ListTile(
                        title: Text('Video: ${beeCount.videoId?.split('_').first ?? 'Unknown'}'),
                        subtitle: Text(
                          'Entering: ${beeCount.beesEntering} | Exiting: ${beeCount.beesExiting} | '
                          'Net: ${beeCount.netChange} | ${_formatDateTime(beeCount.timestamp)}',
                        ),
                        leading: Icon(
                          beeCount.netChange > 0 
                              ? Icons.arrow_upward 
                              : (beeCount.netChange < 0 ? Icons.arrow_downward : Icons.remove),
                          color: beeCount.netChange > 0 
                              ? Colors.green 
                              : (beeCount.netChange < 0 ? Colors.red : Colors.grey),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _manualCheckForVideos,
        tooltip: 'Check for new videos now',
        child: Icon(Icons.refresh),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}