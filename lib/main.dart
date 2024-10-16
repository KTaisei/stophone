import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_background/flutter_background.dart' as fb;

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
  double _speed = 0.0;
  double _previousMagnitude = 0.0;
  double _calculatedSpeed = 0.0; // 加速度から推定した速度
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
    _initializeLocationService();
    _startAccelerometer();
    _startScreenTimer();
  }

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
      bool success = await fb.FlutterBackground.initialize(androidConfig: androidConfig);
      if (success) {
        fb.FlutterBackground.enableBackgroundExecution();
      }
    }
  }

  void _initializeLocationService() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('位置情報サービスが無効です');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('位置情報の権限が拒否されました');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('位置情報の権限が恒久的に拒否されています');
        return;
      }

      print('位置情報サービスと権限が有効です');
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1,
        ),
      ).listen((Position position) {
        double speedKmh = position.speed * 3.6;
        setState(() {
          _speed = speedKmh;
        });

        print('位置情報取得: 緯度: ${position.latitude}, 経度: ${position.longitude}, 速度: $_speed km/h');
        _checkConditions();
      });
    } catch (e) {
      print('位置情報の初期化でエラー: $e');
    }
  }

  void _startAccelerometer() {
    _accelerometerSubscription = userAccelerometerEvents.listen((event) {
      double calculatedSpeed = _calculateSpeed(event);
      print('加速度からの推定速度: ${calculatedSpeed.toStringAsFixed(2)} m/s²');

      _isMovingAtWalkingSpeed = calculatedSpeed > 0.1; // 微小な変化を無視
      _checkConditions();
    });
  }

  double _calculateSpeed(UserAccelerometerEvent event) {
    double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    double delta = magnitude - _previousMagnitude;

    if (delta.abs() > 0.1) {
      _calculatedSpeed += delta;
    }

    _previousMagnitude = magnitude;
    return _calculatedSpeed;
  }

  void _startScreenTimer() {
    _screenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timer.tick >= 60) {
        setState(() {
          _screenOnForMoreThanOneMinute = true;
        });
      }
    });
  }

  void _checkConditions() {
    print('現在の速度: $_speed km/h, 推定速度: ${_calculatedSpeed.toStringAsFixed(2)}');

    if (_isMovingAtWalkingSpeed && _speed >= 3.0 && _speed <= 5.0 && _screenOnForMoreThanOneMinute) {
      _showWarningScreen();
    } else if (_speed >= 1.0 && _speed < 3.0) {
      return;
    } else if (_speed >= 3.0 && _speed <= 5.0 && !_screenOnForMoreThanOneMinute) {
      return;
    }
  }

  void _showWarningScreen() {
    setState(() {
      _warningCount++;
    });

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const WarningScreen(),
      fullscreenDialog: true,
    ));
  }

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
              '速度: ${_speed.toStringAsFixed(2)} km/h\n監視中...',
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              '警告回数: $_warningCount',
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
          '歩きスマホをやめてください！',
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