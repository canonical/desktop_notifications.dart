import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:desktop_notifications/desktop_notifications.dart';
import 'package:test/test.dart';

class MockNotification {
  final String appName;
  final int replacesId;
  final String appIcon;
  final String summary;
  final String body;
  final List<String> actions;
  final Map<String, DBusValue> hints;
  final int expireTimeoutMs;

  const MockNotification(this.appName, this.replacesId, this.appIcon,
      this.summary, this.body, this.actions, this.hints, this.expireTimeoutMs);
}

class MockNotificationsObject extends DBusObject {
  // Active notifications.
  final notifications = <int, MockNotification>{};

  // Next ID to assign to the next notification.
  var _nextId = 1;

  MockNotificationsObject();

  @override
  DBusObjectPath get path => DBusObjectPath('/org/freedesktop/Notifications');

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != 'org.freedesktop.Notifications') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    switch (methodCall.name) {
      case 'GetServerInformation':
        return DBusMethodSuccessResponse([
          DBusString('name'),
          DBusString('vendor'),
          DBusString('0.1'), // Version.
          DBusString('1.2') // Spec version.
        ]);

      case 'GetCapabilities':
        return DBusMethodSuccessResponse([
          DBusArray(DBusSignature('s'),
              [DBusString('actions'), DBusString('body'), DBusString('sound')])
        ]);

      case 'Notify':
        var appName = (methodCall.values[0] as DBusString).value;
        var replacesId = (methodCall.values[1] as DBusUint32).value;
        var appIcon = (methodCall.values[2] as DBusString).value;
        var summary = (methodCall.values[3] as DBusString).value;
        var body = (methodCall.values[4] as DBusString).value;
        var actions = (methodCall.values[5] as DBusArray)
            .children
            .map((value) => (value as DBusString).value)
            .toList();
        var hints = (methodCall.values[6] as DBusDict).children.map((key,
                value) =>
            MapEntry((key as DBusString).value, (value as DBusVariant).value));
        var expireTimeoutMs = (methodCall.values[7] as DBusInt32).value;
        var id = _nextId;
        _nextId++;
        notifications[id] = MockNotification(appName, replacesId, appIcon,
            summary, body, actions, hints, expireTimeoutMs);
        return DBusMethodSuccessResponse([DBusUint32(id)]);

      case 'CloseNotification':
        var id = (methodCall.values[0] as DBusUint32).value;
        notifications.remove(id);
        return DBusMethodSuccessResponse([]);

      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }
}

class MockNotificationsServer extends DBusServer {
  late DBusAddress clientAddress;
  late MockNotificationsObject _object;
  Map<int, MockNotification> get notifications => _object.notifications;

  Future<void> start() async {
    clientAddress =
        await listenAddress(DBusAddress.unix(dir: Directory.systemTemp));

    var c = DBusClient(clientAddress);
    await c.requestName('org.freedesktop.Notifications');
    _object = MockNotificationsObject();
    await c.registerObject(_object);
  }

  void emitActionInvoked(int id, String actionKey) {
    _object.emitSignal('org.freedesktop.Notifications', 'ActionInvoked',
        [DBusUint32(id), DBusString(actionKey)]);
  }

  void emitNotificationClosed(int id, int reason) {
    _object.emitSignal('org.freedesktop.Notifications', 'NotificationClosed',
        [DBusUint32(id), DBusUint32(reason)]);
  }
}

void main() {
  test('get server information', () async {
    var server = MockNotificationsServer();
    await server.start();

    // Get server information.
    var client = NotificationsClient(bus: DBusClient(server.clientAddress));
    var info = await client.getServerInformation();
    expect(info.name, equals('name'));
    expect(info.vendor, equals('vendor'));
    expect(info.version, equals('0.1'));
    expect(info.specVersion, equals('1.2'));
    await client.close();
  });

  test('get capabilities', () async {
    var server = MockNotificationsServer();
    await server.start();

    // Get server capabilities.
    var client = NotificationsClient(bus: DBusClient(server.clientAddress));
    var capabilities = await client.getCapabilities();
    expect(capabilities, equals(['actions', 'body', 'sound']));
    await client.close();
  });

  test('notify - simple', () async {
    var server = MockNotificationsServer();
    await server.start();

    // Send a simple notification.
    var client = NotificationsClient(bus: DBusClient(server.clientAddress));
    var notification = await client.notify('Hello World!');

    expect(server.notifications, contains(notification.id));
    var n = server.notifications[notification.id]!;
    expect(n.appName, equals(''));
    expect(n.replacesId, equals(0));
    expect(n.appIcon, equals(''));
    expect(n.summary, equals('Hello World!'));
    expect(n.body, equals(''));
    expect(n.actions, isEmpty);
    expect(n.hints, isEmpty);
    expect(n.expireTimeoutMs, equals(-1));

    await client.close();
  });

  test('notify - complex', () async {
    var server = MockNotificationsServer();
    await server.start();

    // Send a complex notification.
    var client = NotificationsClient(bus: DBusClient(server.clientAddress));
    var notification = await client.notify('Hello World!',
        body: 'BODY',
        appName: 'APP_NAME',
        appIcon: 'APP_ICON',
        expireTimeoutMs: 42,
        replacesId: 999,
        hints: [
          NotificationHint('KEY1', DBusString('VALUE1')),
          NotificationHint('KEY2', DBusUint32(2))
        ],
        actions: [
          NotificationAction('KEY1', 'LABEL1'),
          NotificationAction('KEY2', 'LABEL2')
        ]);

    expect(server.notifications, contains(notification.id));
    var n = server.notifications[notification.id]!;
    expect(n.appName, equals('APP_NAME'));
    expect(n.replacesId, equals(999));
    expect(n.appIcon, equals('APP_ICON'));
    expect(n.summary, equals('Hello World!'));
    expect(n.body, equals('BODY'));
    expect(n.actions, equals(['KEY1', 'LABEL1', 'KEY2', 'LABEL2']));
    expect(
        n.hints, equals({'KEY1': DBusString('VALUE1'), 'KEY2': DBusUint32(2)}));
    expect(n.expireTimeoutMs, equals(42));

    await client.close();
  });

  test('notification expired', () async {
    var server = MockNotificationsServer();
    await server.start();

    // Send a simple notification and wait for it to be closed.
    var client = NotificationsClient(bus: DBusClient(server.clientAddress));
    var notification = await client.notify('Hello World!');
    expect(notification.closeReason,
        completion(equals(NotificationClosedReason.expired)));

    // Close the notification.
    server.emitNotificationClosed(notification.id, 1);
  });

  test('notification dismissed', () async {
    var server = MockNotificationsServer();
    await server.start();

    // Send a simple notification and wait for it to be closed.
    var client = NotificationsClient(bus: DBusClient(server.clientAddress));
    var notification = await client.notify('Hello World!');
    expect(notification.closeReason,
        completion(equals(NotificationClosedReason.dismissed)));

    // Close the notification.
    server.emitNotificationClosed(notification.id, 2);
  });

  test('notification closed', () async {
    var server = MockNotificationsServer();
    await server.start();

    // Send a simple notification and wait for it to be closed.
    var client = NotificationsClient(bus: DBusClient(server.clientAddress));
    var notification = await client.notify('Hello World!');
    expect(notification.closeReason,
        completion(equals(NotificationClosedReason.closed)));

    // Close the notification.
    server.emitNotificationClosed(notification.id, 3);
  });

  test('notification action', () async {
    var server = MockNotificationsServer();
    await server.start();

    // Send a simple notification and wait for it to be closed.
    var client = NotificationsClient(bus: DBusClient(server.clientAddress));
    var notification = await client
        .notify('Hello World!', actions: [NotificationAction('KEY', 'LABEL')]);
    expect(notification.action, completion(equals('KEY')));

    // Close the notification.
    server.emitActionInvoked(notification.id, 'KEY');
  });

  test('close notification', () async {
    var server = MockNotificationsServer();
    await server.start();

    // Send, then close a simple notification.
    var client = NotificationsClient(bus: DBusClient(server.clientAddress));
    var notification = await client.notify('Hello World!');
    await notification.close();

    expect(server.notifications, isEmpty);

    await client.close();
  });
}
