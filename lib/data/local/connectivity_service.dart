
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance =
      ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Stream<bool> get connectionStream =>
      _connectionController.stream;

  // فحص حالة الاتصال الحالية
  Future<bool> checkConnection() async {
    final results = await _connectivity.checkConnectivity();

    _isConnected = _hasNetwork(results);

    return _isConnected;
  }

  // بدء مراقبة تغير الاتصال
  Future<void> startMonitoring() async {
    await checkConnection();

    await _subscription?.cancel();

    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        final connected = _hasNetwork(results);

        if (_isConnected != connected) {
          _isConnected = connected;

          if (!_connectionController.isClosed) {
            _connectionController.add(connected);
          }
        }
      },
      onError: (_) {
        _isConnected = false;

        if (!_connectionController.isClosed) {
          _connectionController.add(false);
        }
      },
    );
  }

  // التأكد من وجود نوع اتصال بالشبكة
  bool _hasNetwork(List<ConnectivityResult> results) {
    return results.any(
      (result) =>
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn,
    );
  }

  // إيقاف مراقبة الاتصال
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  // إغلاق الخدمة نهائياً
  Future<void> close() async {
    await dispose();
    await _connectionController.close();
  }
}
