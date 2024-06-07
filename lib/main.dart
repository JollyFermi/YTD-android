import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(YouTubeDownloaderApp());
}

class YouTubeDownloaderApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YTDownloader',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(
          secondary: Colors.teal,
        ),
        useMaterial3: true,
      ),
      home: VideoDownloaderScreen(),
    );
  }
}

class VideoDownloaderScreen extends StatefulWidget {
  @override
  _VideoDownloaderScreenState createState() => _VideoDownloaderScreenState();
}

class _VideoDownloaderScreenState extends State<VideoDownloaderScreen> {
  String _videoUrl = '';
  String? _selectedDirectory;
  List<DownloadTask> _downloadTasks = [];
  bool _isDownloading = false;
  final StreamController<List<DownloadTask>> _downloadController = StreamController.broadcast();

  @override
  void dispose() {
    _downloadController.close();
    super.dispose();
  }

  Future<void> _downloadVideo() async {
    final url = _videoUrl.trim();

    if (url.isEmpty) {
      _showErrorDialog('Errore', 'Inserisci un URL valido');
      return;
    }

    final yt = YoutubeExplode();

    setState(() {
      _isDownloading = true;
    });

    try {
      var video = await yt.videos.get(url);
      var manifest = await yt.videos.streamsClient.getManifest(video.id);
      var streamInfo = manifest.muxed.withHighestBitrate();
      var stream = yt.videos.streamsClient.get(streamInfo);

      if (_selectedDirectory == null) {
        _showErrorDialog('Errore', 'Seleziona una directory di destinazione');
        setState(() {
          _isDownloading = false;
        });
        return;
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '$_selectedDirectory/${video.title}_$timestamp.mp4';
      final tempFilePath = '$_selectedDirectory/${video.title}_$timestamp.tmp';
      final tempFile = File(tempFilePath);
      var fileStream = tempFile.openWrite();

      var totalBytes = streamInfo.size.totalBytes;
      var downloadedBytes = 0;

      final task = DownloadTask(video.title, totalBytes);
      _downloadTasks.add(task);
      _downloadController.add(_downloadTasks);

      await for (var data in stream) {
        downloadedBytes += data.length;
        fileStream.add(data);

        task.progress = (downloadedBytes / totalBytes) * 100;
        _downloadController.add(_downloadTasks);
      }

      await fileStream.flush();
      await fileStream.close();

      await tempFile.rename(filePath);

      _showConfirmationDialog('Download Completato', 'Il video è stato salvato correttamente');
    } catch (e) {
      _showErrorDialog('Errore di Download', 'Impossibile scaricare il video: $e');
    } finally {
      yt.close();
      setState(() {
        _isDownloading = false;
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmationDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _selectDirectory() async {
    String? directory = await FilePicker.platform.getDirectoryPath();
    if (directory != null) {
      setState(() {
        _selectedDirectory = directory;
      });
    }
  }

  void _clearDownloadHistory() {
    setState(() {
      _downloadTasks.clear();
    });
    _downloadController.add(_downloadTasks);
  }

  void _navigateToDownloads() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DownloadScreen(
          downloadController: _downloadController,
          clearHistoryCallback: _clearDownloadHistory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.white, // colore di sfondo bianco
      foregroundColor: Colors.blue, // colore del testo azzurro
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30.0),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('YTDownloader'),
      ),
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            Container(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.menu),
                    title: Text('Menu'),
                  ),
                  Divider(),
                ],
              ),
            ),
            ListTile(
              title: Text('Download'),
              onTap: () {
                Navigator.pop(context);
                _navigateToDownloads();
              },
              leading: Icon(Icons.download),
            ),
          ],
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30.0),
                        border: Border.all(color: Colors.grey),
                      ),
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _videoUrl = value;
                          });
                        },
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search or paste link here...',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _downloadVideo,
                    style: buttonStyle,
                    child: Text('Start ➔'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _selectDirectory,
                style: buttonStyle,
                icon: Icon(Icons.folder_open),
                label: Text('Seleziona Directory di Salvataggio'),
              ),
              SizedBox(height: 20),
              _selectedDirectory != null
                  ? Text('Directory selezionata: $_selectedDirectory')
                  : SizedBox.shrink(),
              SizedBox(height: 20),
              _isDownloading
                  ? CircularProgressIndicator()
                  : ElevatedButton.icon(
                onPressed: _downloadVideo,
                style: buttonStyle,
                icon: Icon(Icons.download),
                label: Text('Scarica Video'),
              ),
              Spacer(),
              Text.rich(
                TextSpan(
                  text: 'sviluppato da: ',
                  children: [
                    TextSpan(
                      text: 'Marco Giorgi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16), // Padding to separate the text from the bottom
            ],
          ),
        ),
      ),
    );
  }
}

class DownloadScreen extends StatelessWidget {
  final StreamController<List<DownloadTask>> downloadController;
  final VoidCallback clearHistoryCallback;

  DownloadScreen({required this.downloadController, required this.clearHistoryCallback});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Downloads in corso'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<DownloadTask>>(
              stream: downloadController.stream,
              initialData: [],
              builder: (context, snapshot) {
                var downloadTasks = snapshot.data ?? [];
                return ListView.builder(
                  itemCount: downloadTasks.length,
                  itemBuilder: (context, index) {
                    var task = downloadTasks[index];
                    return ListTile(
                      title: Text(task.title),
                      subtitle: LinearProgressIndicator(
                        value: task.progress / 100,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          ElevatedButton(
            onPressed: clearHistoryCallback,
            child: Text('Pulisci History Download'),
          ),
        ],
      ),
    );
  }
}

class DownloadTask {
  final String title;
  final int totalBytes;
  double progress;

  DownloadTask(this.title, this.totalBytes) : progress = 0;
}
