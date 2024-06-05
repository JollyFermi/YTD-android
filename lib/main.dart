import 'dart:io';
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
      title: 'YouTube Downloader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
  bool _isDownloading = false;
  String _progress = '';

  Future<void> _downloadVideo() async {
    final url = _videoUrl.trim();

    if (url.isEmpty) {
      _showErrorDialog('Errore', 'Inserisci un URL valido');
      return;
    }

    final yt = YoutubeExplode();

    try {
      setState(() {
        _isDownloading = true;
      });

      var video = await yt.videos.get(url);
      var manifest = await yt.videos.streamsClient.getManifest(video.id);
      var streamInfo = manifest.muxed.withHighestBitrate();
      var stream = yt.videos.streamsClient.get(streamInfo);

      if (_selectedDirectory == null) {
        _showErrorDialog('Errore', 'Seleziona una directory di destinazione');
        return;
      }

      // Aggiungi un timestamp al nome del file per renderlo univoco
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '$_selectedDirectory/${video.title}_$timestamp.mp4';
      final file = File(filePath);
      var fileStream = file.openWrite();

      var totalBytes = streamInfo.size.totalBytes;
      var downloadedBytes = 0;

      await for (var data in stream) {
        downloadedBytes += data.length;
        fileStream.add(data);

        setState(() {
          _progress = ((downloadedBytes / totalBytes) * 100).toStringAsFixed(2) + '%';
        });
      }

      await fileStream.flush();
      await fileStream.close();

      _showConfirmationDialog('Download Completato', 'Il video è stato salvato correttamente');
    } catch (e) {
      _showErrorDialog('Errore di Download', 'Impossibile scaricare il video: $e');
    } finally {
      yt.close();
      setState(() {
        _isDownloading = false;
        _progress = '';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('YouTube Downloader'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              onChanged: (value) {
                setState(() {
                  _videoUrl = value;
                });
              },
              decoration: InputDecoration(
                labelText: 'URL del Video',
                hintText: 'Inserisci l\'URL del video da scaricare',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _selectDirectory,
              child: Text('Seleziona Directory di Salvataggio'),
            ),
            SizedBox(height: 20),
            _selectedDirectory != null
                ? Text('Directory selezionata: $_selectedDirectory')
                : SizedBox.shrink(),
            SizedBox(height: 20),
            _isDownloading
                ? Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text('Download in corso: $_progress'),
              ],
            )
                : ElevatedButton(
              onPressed: _downloadVideo,
              child: Text('Scarica Video'),
            ),
          ],
        ),
      ),
    );
  }
}
