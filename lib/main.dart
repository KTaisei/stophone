import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

void main() {
  runApp(const WalkingPhoneApp());
}

class WalkingPhoneApp extends StatefulWidget {
  const WalkingPhoneApp({super.key});

  @override
  _WalkingPhoneAppState createState() => _WalkingPhoneAppState();
}

class _WalkingPhoneAppState extends State<WalkingPhoneApp> {
  double _speed = 0.0;
  late StreamSubscription<Position> _positionSubscription;
  late StreamSubscription<UserAccelerometerEvent> _accelerometerSubscription;
  bool _isMovingAtWalkingSpeed = false;

  @override
  void initState() {
    super.initState();
    _initializeForegroundTask();
    _initializeLocationService();
    _startAccelerometer();
  }

  void _initializeForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'walking_notification',
        channelName: 'Walking Phone Alert',
        channelDescription: 'Alerts when you are walking and using your phone.',
        channelImportance: NotificationChannelImportance.MAX,
        priority: NotificationPriority.MAX,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
    );

    FlutterForegroundTask.startService(
      notificationTitle: 'Walking Phone App',
      notificationText: 'Monitoring your speed...',
      callback: startCallback,
    );
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
    _accelerometerSubscription = userAccelerometerEvents.listen((event) {
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
    // シンプルな加速度から速度を推定するロジック
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
    return Scaffold(
      body: Center(
        child: Text(
          'Stop using your phone while walking!',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {}

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {}

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp("");
  }
}

