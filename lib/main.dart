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
      bool success =
      await fb.FlutterBackground.initialize(androidConfig: androidConfig);
      if (success) {
        fb.FlutterBackground.enableBackgroundExecution();
      }
    }
  }

  void _initializeLocationService() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    _positionSubscription =
        Geolocator.getPositionStream().listen((Position position) {
          double speedKmh = position.speed * 3.6;
          setState(() {
            _speed = speedKmh;
          });

          _checkConditions();
        });
  }

  void _startAccelerometer() {
    _accelerometerSubscription = userAccelerometerEventStream().listen((event) {
      double calculatedSpeed = _calculateSpeed(event);
      if (calculatedSpeed > 0) {
        _isMovingAtWalkingSpeed = true;
      } else {
        _isMovingAtWalkingSpeed = false;
      }

      _checkConditions();
    });
  }

  double _calculateSpeed(UserAccelerometerEvent event) {
    double magnitude =
    sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    return magnitude;
  }

  void _startScreenTimer() {
    // 画面が1分以上点灯しているかを確認するためのタイマーを開始
    _screenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timer.tick >= 60) {
        setState(() {
          _screenOnForMoreThanOneMinute = true;
        });
      }
    });
  }

  void _checkConditions() {
    if (_speed >= 3.0 && _speed <= 5.0 && _screenOnForMoreThanOneMinute) {
      // 速度が3~5km/hかつ画面が1分以上点灯している場合に警告
      _showWarningScreen();
    } else if (_speed >= 1.0 && _speed < 3.0) {
      // 速度が1~3km/hの場合は警告を出さない
      return;
    } else if (_speed >= 3.0 && _speed <= 5.0 && !_screenOnForMoreThanOneMinute) {
      // 速度が3~5km/hだが、画面が1分以上点灯していない場合も警告を出さない
      return;
    }
  }

  void _showWarningScreen() {
    setState(() {
      _warningCount++; // 警告が表示されるたびにカウントを増やす
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
    _screenTimer?.cancel(); // タイマーもキャンセル
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
              'Warning count: $_warningCount', // 警告が表示された回数を表示
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
