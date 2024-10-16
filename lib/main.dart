import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_background/flutter_background.dart' as fb;
import 'package:logger/logger.dart'; // ログ用パッケージ

void main() {
  runApp(
    const MaterialApp(
      home: WalkingPhoneApp(),
    ),
  );
}

class WalkingPhoneApp extends StatefulWidget {
  const WalkingPhoneApp({super.key});

  @override
  WalkingPhoneAppState createState() => WalkingPhoneAppState();
}

class WalkingPhoneAppState extends State<WalkingPhoneApp> {
  final Logger _logger = Logger(); // ロガーインスタンス

  double _speed = 0.0;
  late StreamSubscription<Position> _positionSubscription;
  late StreamSubscription<UserAccelerometerEvent> _accelerometerSubscription;
  bool _isMovingAtWalkingSpeed = false;
  int _warningCount = 0;
  Timer? _screenTimer;
  bool _screenOnForMoreThanOneMinute = false;

  @override
  void initState() {
    super.initState();
    _initializeBackgroundTask();
    _checkLocationService(); // 新しいサービスチェック関数
    _requestLocationPermission(); // 許可をリクエストする部分を分離
    _startAccelerometer();
    _startScreenTimer();
  }

  // 背景タスクの初期化
  void _initializeBackgroundTask() async {
    const androidConfig = fb.FlutterBackgroundAndroidConfig(
      notificationTitle: "Walking Phone Alert",
      notificationText: "Monitoring your movement...",
      notificationImportance: fb.AndroidNotificationImportance.high,
      notificationIcon: fb.AndroidResource(
        name: 'background_icon',
        defType: 'drawable',
      ),
    );

    bool hasPermissions = await fb.FlutterBackground.hasPermissions;
    if (!hasPermissions) {
      bool success =
          await fb.FlutterBackground.initialize(androidConfig: androidConfig);
      if (success) {
        fb.FlutterBackground.enableBackgroundExecution();
        _logger.i("Background execution enabled.");
      }
    }
  }

  // 位置情報サービスの確認
  void _checkLocationService() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _logger.w("Location services are disabled.");
      return;
    }
    _initializeLocationService();
  }

  // 位置情報許可のリクエストと確認
  void _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _logger.w("Location permissions are denied.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _logger.e("Location permissions are permanently denied.");
      return;
    }

    _logger.i("Location permission granted.");
    _initializeLocationService();
  }

  // 位置情報サービスの初期化と監視
  void _initializeLocationService() {
    _positionSubscription = Geolocator.getPositionStream().listen(
      (Position position) {
        double speedKmh = position.speed * 3.6;
        setState(() {
          _speed = speedKmh;
        });

        _logger.i("Current speed: $_speed km/h");
        _checkConditions();
      },
      onError: (e) {
        _logger.e("Error in location stream: $e");
      },
    );
  }

  // 加速度センサーの初期化
  void _startAccelerometer() {
    _accelerometerSubscription = userAccelerometerEvents.listen(
      (event) {
        double calculatedSpeed = _calculateSpeed(event);
        _isMovingAtWalkingSpeed = calculatedSpeed > 0;

        _logger.i("Accelerometer event: ${event.toString()}");
        _checkConditions();
      },
    );
  }

  // 加速度から速度を計算
  double _calculateSpeed(UserAccelerometerEvent event) {
    return sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
  }

  // 画面タイマーの開始
  void _startScreenTimer() {
    _screenTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (timer.tick >= 60) {
          setState(() {
            _screenOnForMoreThanOneMinute = true;
          });
          _logger.i("Screen has been on for more than one minute.");
        }
      },
    );
  }

  // 条件チェック
  void _checkConditions() {
    if (_isMovingAtWalkingSpeed &&
        _speed >= 3.0 &&
        _speed <= 5.0 &&
        _screenOnForMoreThanOneMinute) {
      _showWarningScreen();
    }
  }

  // 警告画面の表示
  void _showWarningScreen() {
    setState(() {
      _warningCount++;
    });

    _logger.w("Warning count: $_warningCount");

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const WarningScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  // リソースの解放
  @override
  void dispose() {
    _positionSubscription.cancel();
    _accelerometerSubscription.cancel();
    _screenTimer?.cancel();
    fb.FlutterBackground.disableBackgroundExecution();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Speed: ${_speed.toStringAsFixed(2)} km/h\nMonitoring...',
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Warning count: $_warningCount',
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class WarningScreen extends StatelessWidget {
  const WarningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Stop using your phone while walking!',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
