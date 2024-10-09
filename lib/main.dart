import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_background/flutter_background.dart' as fb;
import 'package:logging/logging.dart';

void main() {
  // ログの設定を行う
  _setupLogging();

  runApp(
    const MaterialApp(
      home: WalkingPhoneApp(),
    ),
  );
}

// ログ設定関数
void _setupLogging() {
  // すべてのログレベル（ALL）を記録
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord record) {
    // ここでログの表示方法をカスタマイズ
    // 例: コンソールに表示、またはファイルに保存
    debugPrint(
        '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
  });
}

class WalkingPhoneApp extends StatefulWidget {
  const WalkingPhoneApp({super.key});

  @override
  WalkingPhoneAppState createState() => WalkingPhoneAppState();
}

class WalkingPhoneAppState extends State<WalkingPhoneApp> {
  final Logger _logger = Logger('WalkingPhoneAppState'); // ロガーインスタンス
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

  // 背景タスクの初期化
  void _initializeBackgroundTask() async {
    const androidConfig = fb.FlutterBackgroundAndroidConfig(
      notificationTitle: "Walking Phone Alert",
      notificationText: "あなたの移動を監視中...",
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
        _logger.info('バックグラウンド実行が有効化されました');
      } else {
        _logger.warning('バックグラウンド実行の有効化に失敗しました');
      }
    }
  }

  // 位置情報サービスの初期化
  void _initializeLocationService() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _logger.severe('位置情報サービスが無効です');
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _logger.warning('位置情報の許可が拒否されました');
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _logger.severe('位置情報の許可が永久に拒否されています');
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
      _logger.info('現在の速度: ${speedKmh.toStringAsFixed(2)} km/h');
    });
  }

  void _startAccelerometer() {
    _accelerometerSubscription = userAccelerometerEventStream().listen((event) {
      double calculatedSpeed = _calculateSpeed(event);
      _logger
          .info('Calculated Accelerometer Speed: $calculatedSpeed'); // デバッグ用ログ

      setState(() {
        _isMovingAtWalkingSpeed = calculatedSpeed > 0;
      });

      _checkConditions();
    });
  }

  double _calculateSpeed(UserAccelerometerEvent event) {
    double magnitude =
        sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    return magnitude;
  }

  void _startScreenTimer() {
    _screenTimer?.cancel(); // タイマーをリセット
    _screenOnForMoreThanOneMinute = false; // 初期状態をリセット
    _screenTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timer.tick >= 60) {
        setState(() {
          _screenOnForMoreThanOneMinute = true;
        });
      }
    });
  }

  void _checkConditions() {
    if (_isMovingAtWalkingSpeed &&
        _speed >= 3.0 &&
        _speed <= 5.0 &&
        _screenOnForMoreThanOneMinute) {
      // 速度が3~5km/hかつ画面が1分以上点灯している場合に警告
      _showWarningScreen();
    } else if (_speed >= 1.0 && _speed < 3.0) {
      // 速度が1~3km/hの場合は警告を出さない
      return;
    } else if (_speed >= 3.0 &&
        _speed <= 5.0 &&
        !_screenOnForMoreThanOneMinute) {
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
              'Is Moving at Walking Speed: $_isMovingAtWalkingSpeed', // 移動状態を表示
              style: const TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Warning count: $_warningCount', // 警告回数の表示
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
