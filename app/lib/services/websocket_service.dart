import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../config/app_config.dart';
import '../models/location.dart';
import '../utils/logger.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _shouldReconnect = false;
  String? _authToken;

  final _locationController = StreamController<PetLocation>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  Stream<PetLocation> get locationStream => _locationController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  bool get isConnected => _channel != null;

  Future<void> connect(String token, List<String> petIds) async {
    _authToken = token;
    _shouldReconnect = true;
    await _connect(petIds);
  }

  Future<void> _connect(List<String> petIds) async {
    try {
      final wsUrl = Uri.parse(
        '${AppConfig.wsUrl}/location?token=$_authToken&pets=${petIds.join(",")}',
      );
      _channel = WebSocketChannel.connect(wsUrl);

      _channel!.stream.listen(
        _onMessage,
        onError: (Object e) {
          AppLogger.error('WebSocket error: $e');
          _connectionController.add(false);
          if (_shouldReconnect) _scheduleReconnect(petIds);
        },
        onDone: () {
          AppLogger.info('WebSocket closed');
          _connectionController.add(false);
          if (_shouldReconnect) _scheduleReconnect(petIds);
        },
      );

      _connectionController.add(true);
      _startHeartbeat();
      AppLogger.info('WebSocket connected');
    } catch (e) {
      AppLogger.error('WebSocket connect error: $e');
      _connectionController.add(false);
      if (_shouldReconnect) _scheduleReconnect(petIds);
    }
  }

  void _onMessage(dynamic message) {
    try {
      final data = json.decode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      if (type == 'location') {
        final location =
            PetLocation.fromJson(data['data'] as Map<String, dynamic>);
        _locationController.add(location);
      }
    } catch (e) {
      AppLogger.error('WebSocket message parse error: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _channel?.sink.add(json.encode({'type': 'ping'}));
    });
  }

  void _scheduleReconnect(List<String> petIds) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_shouldReconnect) _connect(petIds);
    });
  }

  Future<void> disconnect() async {
    _shouldReconnect = false;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _locationController.close();
    _connectionController.close();
  }
}
