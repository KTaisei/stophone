import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_background/flutter_background.dart' as fb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  runApp(const MaterialApp(home: WalkingPhoneDetectionApp()));
}

class WalkingPhoneDetectionApp extends StatefulWidget {
  const WalkingPhoneDetectionApp({super.key});

  @override
  _WalkingPhoneDetectionAppState createState() =>
      _WalkingPhoneDetectionAppState();
}

class _WalkingPhoneDetectionAppState extends State<WalkingPhoneDetectionApp> {
  final List<double> _accelMagnitudes = [];
  bool _isWalking = false;
  bool _isUsingPhoneWhileWalking = false;
  final double _sensitivity = 0.3;
  Timer? _detectionTimer;
  static const int detectionInterval = 500;
  int _warningCount = 0;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _initializeBackgroundTask();
    _startAccelerometer();
    _startDetectionTimer();
  }

  // 通知の初期化
  void _initializeNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // 通知を表示する関数
  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidNotificationDetails =
    AndroidNotificationDetails(
      'channel_id', // 通知チャンネルID
      'Channel Name', // チャンネル名
      channelDescription: '歩きスマホ警告',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails notificationDetails =
    NotificationDetails(android: androidNotificationDetails);

    await flutterLocalNotificationsPlugin.show(
      0, // 通知のID
      title,
      body,
      notificationDetails,
    );
  }

  // バックグラウンド実行の設定
  void _initializeBackgroundTask() async {
    const androidConfig = fb.FlutterBackgroundAndroidConfig(
      notificationTitle: "歩きスマホ検知中",
      notificationText: "アプリはバックグラウンドで動作中です",
      notificationImportance: fb.AndroidNotificationImportance.high,
    );

    if (!await fb.FlutterBackground.hasPermissions) {
      bool success =
      await fb.FlutterBackground.initialize(androidConfig: androidConfig);
      if (success) {
        fb.FlutterBackground.enableBackgroundExecution();
      }
    }
  }

  // 加速度センサーのデータ取得を開始
  void _startAccelerometer() {
    userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      double magnitude =
      sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      _accelMagnitudes.add(magnitude);

      if (_accelMagnitudes.length > 20) {
        _accelMagnitudes.removeAt(0);
      }
    });
  }

  // 一定間隔で歩きスマホを検知
  void _startDetectionTimer() {
    _detectionTimer =
        Timer.periodic(const Duration(milliseconds: detectionInterval), (timer) {
          _detectWalking();
          _detectPhoneUsageWhileWalking();
          setState(() {});
        });
  }

  // 歩行の検知
  void _detectWalking() {
    if (_accelMagnitudes.length < 20) return;

    double totalVariation = 0.0;
    for (int i = 1; i < _accelMagnitudes.length; i++) {
      totalVariation += (_accelMagnitudes[i] - _accelMagnitudes[i - 1]).abs();
    }
    double averageVariation = totalVariation / _accelMagnitudes.length;
    _isWalking = averageVariation > 1.9 && averageVariation < 12.0;
  }

  // 歩行中のスマホ使用検知
  void _detectPhoneUsageWhileWalking() {
    if (!_isWalking || _accelMagnitudes.length < 20) {
      _isUsingPhoneWhileWalking = false;
      return;
    }

    int fluctuationCount = 0;
    for (int i = 1; i < _accelMagnitudes.length; i++) {
      if ((_accelMagnitudes[i] - _accelMagnitudes[i - 1]).abs() >
          _sensitivity) {
        fluctuationCount++;
      }
    }

    _isUsingPhoneWhileWalking = fluctuationCount > 8;

    // 歩きスマホ検知時に通知
    if (_isUsingPhoneWhileWalking) {
      showNotification("警告", "歩きスマホをやめてください！");
      _warningCount++;
    }
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    fb.FlutterBackground.disableBackgroundExecution();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('歩きスマホ検知アプリ'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isWalking ? '歩行中' : '静止中',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 20),
            Text(
              _isUsingPhoneWhileWalking ? '歩きスマホ検知！' : 'スマホ操作なし',
              style: TextStyle(
                fontSize: 32,
                color: _isUsingPhoneWhileWalking ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '警告回数: $_warningCount',
              style: const TextStyle(fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }
}