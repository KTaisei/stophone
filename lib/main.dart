import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:background_services/background_services.dart';

class WalkingPhoneApp extends StatefulWidget {
  const WalkingPhoneApp({super.key});

  @override
  _WalkingPhoneAppState createState() => _WalkingPhoneAppState();
}

class _WalkingPhoneAppState extends State<WalkingPhoneApp> {
  double _speed = 0.0;
  StreamSubscription<UserAccelerometerEvent> _accelerometerSubscription;

  @override
  void initState() {
    super.initState();
    _accelerometerSubscription = userAccelerometerEvents.listen((event) {
      // 加速度センサーのデータから速度を計算
      // ... (速度計算ロジック)
      setState(() {
        _speed = calculatedSpeed;
      });

      if (_speed >= 2 && _speed <= 5) {
        // 速度が閾値を超えた場合、フォアグラウンドサービスに移行
        BackgroundServices.setForegroundServiceInfo(
          title: "Don't use Phone",
          // ...
        );
      }
    });

    // バックグラウンドサービスの登録
    BackgroundServices.register((message) async {
      // 定期的に実行されるバックグラウンドタスク
      // GPSデータ取得、位置情報に基づく歩行判定など
    });
  }

  @override
  void dispose() {
    super.dispose();
    _accelerometerSubscription.cancel();
    // バックグラウンドサービスの停止
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Do not use phone),
      ),
    );
  }
}


