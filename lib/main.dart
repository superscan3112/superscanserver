import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web_socket_channel/io.dart';
import 'package:network_info_plus/network_info_plus.dart';

void main() {
  runApp(MaterialApp(home: SuperScanApp()));
}

class SuperScanApp extends StatefulWidget {
  @override
  _SuperScanAppState createState() => _SuperScanAppState();
}

class _SuperScanAppState extends State<SuperScanApp> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.example.superscanserver/input');

  HttpServer? _server;
  WebSocket? _clientSocket;
  String _status = 'Initializing server...';
  String _serverAddress = '';
  int _port = 0;
  bool _isServerRunning = false;
  String _connectedDeviceName = '';
  String _lastReceivedMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startServer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _server?.close();
    _clientSocket?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      print('App is in background');
    } else if (state == AppLifecycleState.resumed) {
      print('App is in foreground');
    }
  }

  Future<void> _startServer() async {
    if (_isServerRunning) return;

    final info = NetworkInfo();
    final wifiIP = await info.getWifiIP();

    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        _port = _getRandomPort();
        _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
        _isServerRunning = true;
        setState(() {
          _serverAddress = 'ws://$wifiIP:$_port';
          _status = 'Waiting for connection...';
        });
        _server!.transform(WebSocketTransformer()).listen(_handleClient);
        break;
      } catch (e) {
        print('Failed to bind to port $_port: $e');
      }
    }

    if (!_isServerRunning) {
      setState(() {
        _status = 'Failed to start server';
      });
    }
  }

  int _getRandomPort() {
    return 1000 + Random().nextInt(9000); // Random port between 1000 and 9999
  }

  void _handleClient(WebSocket client) {
    if (_clientSocket != null) {
      client.close(1000, 'Another client is already connected');
      return;
    }

    _clientSocket = client;
    setState(() {
      _status = 'Client connected';
    });

    client.listen(
          (message) async {
        print('Received: $message');
        if (message.startsWith('DEVICE_NAME:')) {
          setState(() {
            _connectedDeviceName = message.split(':')[1];
            _status = 'Connected to $_connectedDeviceName';
          });
        } else {
          setState(() {
            _lastReceivedMessage = message;
          });
          // Simulate keyboard input
          try {
            await platform.invokeMethod('inputText', {'text': message});
          } on PlatformException catch (e) {
            print("Failed to input text: '${e.message}'.");
          }
        }
      },
      onDone: () {
        _clientSocket = null;
        setState(() {
          _status = 'Client disconnected';
          _connectedDeviceName = '';
          _lastReceivedMessage = '';
        });
      },
      onError: (error) {
        print('Error: $error');
        _clientSocket = null;
        setState(() {
          _status = 'Error occurred';
          _connectedDeviceName = '';
          _lastReceivedMessage = '';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 40),
              Text(
                'Super Scan',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold
                ),
              ),
              SizedBox(height: 40),
              if (_serverAddress.isNotEmpty)
                QrImageView(
                  data: _serverAddress,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                ),
              SizedBox(height: 40),
              Text(
                _status,
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              if (_connectedDeviceName.isNotEmpty)
                Text(
                  'Connected Device: $_connectedDeviceName',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              if (_lastReceivedMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Last Received: $_lastReceivedMessage',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}