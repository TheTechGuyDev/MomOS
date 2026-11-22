import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'profile_service.dart';

@JS('momosPushStatus')
external JSString _status();

@JS('momosEnablePush')
external JSPromise<JSString> _enable(JSString vapidKey);

@JS('momosTakeInbox')
external JSString _takeInbox();

@JS('momosVibrate')
external void _vibrate(JSAny pattern);

/// Web push notifications for reminders and family events.
class PushService {
  static const vapidPublicKey =
      'BIM1nLVM9OG0xJMK7XBnunbwQCdwEGuEKNDeW3vL7eVkZiaxCsNRWwQH-dxrTzGwwsBk8zdqo5Ouh9Nr06SqOwI';

  /// 'unsupported' | 'needs-install' | 'default' | 'granted' | 'denied'
  static String status() {
    try {
      return _status().toDart;
    } catch (_) {
      return 'unsupported';
    }
  }

  static bool get isIos => RegExp('iPad|iPhone|iPod').hasMatch(web.window.navigator.userAgent);

  /// Returns null on success, or a friendly error message.
  static Future<String?> enable() async {
    final res = (await _enable(vapidPublicKey.toJS).toDart).toDart;
    if (res.startsWith('error:')) {
      final code = res.substring(6);
      switch (code) {
        case 'needs-install':
          return 'On iPhone, first add MomOS to your Home Screen (Share → Add to Home Screen), then open it from there.';
        case 'unsupported':
          return 'This browser does not support notifications. Try Chrome on Android or the Home Screen app on iPhone.';
        case 'denied':
          return 'Notifications are blocked. Allow them for this site in your browser settings, then try again.';
        default:
          return 'Could not turn on notifications ($code).';
      }
    }
    final sub = jsonDecode(res) as Map<String, dynamic>;
    final keys = Map<String, dynamic>.from(sub['keys'] as Map);
    await supa.rpc('save_push_subscription', params: {
      'p_endpoint': sub['endpoint'],
      'p_p256dh': keys['p256dh'],
      'p_auth': keys['auth'],
      'p_ua': web.window.navigator.userAgent,
    });
    return null;
  }

  /// Messages the service worker sent while the app was open.
  static List<Map<String, dynamic>> takeInbox() {
    try {
      final list = jsonDecode(_takeInbox().toDart) as List;
      return list.map((e) => Map<String, dynamic>.from(jsonDecode(e as String) as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static void vibrate(List<int> pattern) {
    try {
      _vibrate(pattern.map((e) => e.toJS).toList().toJS);
    } catch (_) {}
  }

  static Future<int> sendTest({String level = 'gentle'}) async {
    final r = await supa.functions.invoke('send-notifications', body: {'test': true, 'level': level});
    final d = r.data is String ? jsonDecode(r.data as String) : r.data;
    return (d['sent'] ?? 0) as int;
  }
}
