import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_background/flutter_background.dart' as fb;

void main() {
  runApp(const _WalkingPhoneApp());
}

class _WalkingPhoneApp extends StatefulWidget {
  const _WalkingPhoneApp();

  @override
  _WalkingPhoneAppState createState() => _WalkingPhoneAppState();
}

class _WalkingPhoneAppState extends State<_WalkingPhoneApp> {
  double _speed = 0.0;
  late StreamSubscription<Position> _positionSubscription;
  late StreamSubscription<UserAccelerometerEvent> _accelerometerSubscription;
  bool _isMovingAtWalkingSpeed = false;

  @override
  void initState() {
    super.initState();
    _initializeBackgroundTask();
    _initializeLocationService();
    _startAccelerometer();
  }

  void _initializeBackgroundTask() async {
    // 正しい定数名を使用する
    const androidConfig = fb.FlutterBackgroundAndroidConfig(
      notificationTitle: "Walking Phone Alert",
      notificationText: "Monitoring your movement...",
      notificationImportance:
          fb.AndroidNotificationImportance.high, // 例: 'default' の代わりに 'high'
      notificationIcon: fb.AndroidResource(
        name: 'background_icon',
        defType: 'drawable',
      ),
    );

    // 背景タスクの初期化
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
      double speedKmh = position.speed * 3.6; // m/sからkm/hへ変換
      setState(() {
        _speed = speedKmh;
      });

      if (_speed >= 2.0 && _speed <= 5.0) {
        _isMovingAtWalkingSpeed = true;
      } else {
        _isMovingAtWalkingSpeed = false;
      }

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

  void _checkConditions() {
    if (_isMovingAtWalkingSpeed) {
      _showWarningScreen();
    }
  }

  void _showWarningScreen() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => const WarningScreen(),
      fullscreenDialog: true,
    ));
  }

  @override
  void dispose() {
    _positionSubscription.cancel();
    _accelerometerSubscription.cancel();
    fb.FlutterBackground.disableBackgroundExecution();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Speed: ${_speed.toStringAsFixed(2)} km/h\nMonitoring...',
          style: const TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
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
