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
  final MockNotificationsServer server;

  MockNotificationsObject(this.server)
      : super(DBusObjectPath('/org/freedesktop/Notifications'));

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface != 'org.freedesktop.Notifications') {
      return DBusMethodErrorResponse.unknownInterface();
    }

    switch (methodCall.name) {
      case 'GetServerInformation':
        return DBusMethodSuccessResponse([
          DBusString(server.name),
          DBusString(server.vendor),
          DBusString(server.version),
          DBusString(server.specVersion)
        ]);

      case 'GetCapabilities':
        return DBusMethodSuccessResponse(
            [DBusArray.string(server.capabilities)]);

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
        var id = server._nextId;
        server._nextId++;
        server.notifications[id] = MockNotification(appName, replacesId,
            appIcon, summary, body, actions, hints, expireTimeoutMs);
        return DBusMethodSuccessResponse([DBusUint32(id)]);

      case 'CloseNotification':
        var id = (methodCall.values[0] as DBusUint32).value;
        server.notifications.remove(id);
        return DBusMethodSuccessResponse([]);

      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }
}

class MockNotificationsServer extends DBusClient {
  late final MockNotificationsObject _root;

  final List<String> capabilities;
  final String name;
  final String specVersion;
  final String vendor;
  final String version;

  // Active notifications.
  final notifications = <int, MockNotification>{};

  // Next ID to assign to the next notification.
  var _nextId = 1;

  MockNotificationsServer(DBusAddress clientAddress,
      {this.capabilities = const [],
      this.name = '',
      this.specVersion = '',
      this.vendor = '',
      this.version = ''})
      : super(clientAddress) {
    _root = MockNotificationsObject(this);
  }

  Future<void> start() async {
    await requestName('org.freedesktop.Notifications');
    await registerObject(_root);
  }

  void emitActionInvoked(int id, String actionKey) {
    _root.emitSignal('org.freedesktop.Notifications', 'ActionInvoked',
        [DBusUint32(id), DBusString(actionKey)]);
  }

  void emitNotificationClosed(int id, int reason) {
    _root.emitSignal('org.freedesktop.Notifications', 'NotificationClosed',
        [DBusUint32(id), DBusUint32(reason)]);
  }
}

void main() {
  test('get server information', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    addTearDown(() async {
      await server.close();
    });

    var notifications = MockNotificationsServer(clientAddress,
        name: 'name', vendor: 'vendor', version: '0.1', specVersion: '1.2');
    await notifications.start();
    addTearDown(() async {
      await notifications.close();
    });

    // Get server information.
    if (true) {
      var client = NotificationsClient(bus: DBusClient(clientAddress));
      addTearDown(() async {
        await client.close();
      });
      var info = await client.getServerInformation();
      expect(info.name, equals('name'));
      expect(info.vendor, equals('vendor'));
      expect(info.version, equals('0.1'));
      expect(info.specVersion, equals('1.2'));
    }
  });

  test('get capabilities', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    addTearDown(() async {
      await server.close();
    });

    var notifications = MockNotificationsServer(clientAddress,
        capabilities: ['actions', 'body', 'sound']);
    await notifications.start();
    addTearDown(() async {
      await notifications.close();
    });

    // Get server capabilities.
    var client = NotificationsClient(bus: DBusClient(clientAddress));
    addTearDown(() async {
      await client.close();
    });
    var capabilities = await client.getCapabilities();
    expect(capabilities, equals(['actions', 'body', 'sound']));
  });

  test('notify - simple', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    addTearDown(() async {
      await server.close();
    });

    var notifications = MockNotificationsServer(clientAddress);
    await notifications.start();
    addTearDown(() async {
      await notifications.close();
    });

    // Send a simple notification.
    var client = NotificationsClient(bus: DBusClient(clientAddress));
    addTearDown(() async {
      await client.close();
    });
    var notification = await client.notify('Hello World!');

    expect(notifications.notifications, contains(notification.id));
    var n = notifications.notifications[notification.id]!;
    expect(n.appName, equals(''));
    expect(n.replacesId, equals(0));
    expect(n.appIcon, equals(''));
    expect(n.summary, equals('Hello World!'));
    expect(n.body, equals(''));
    expect(n.actions, isEmpty);
    expect(n.hints, isEmpty);
    expect(n.expireTimeoutMs, equals(-1));
  });

  test('notify - complex', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    addTearDown(() async {
      await server.close();
    });

    var notifications = MockNotificationsServer(clientAddress);
    await notifications.start();
    addTearDown(() async {
      await notifications.close();
    });

    // Send a complex notification.
    var client = NotificationsClient(bus: DBusClient(clientAddress));
    addTearDown(() async {
      await client.close();
    });
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

    expect(notifications.notifications, contains(notification.id));
    var n = notifications.notifications[notification.id]!;
    expect(n.appName, equals('APP_NAME'));
    expect(n.replacesId, equals(999));
    expect(n.appIcon, equals('APP_ICON'));
    expect(n.summary, equals('Hello World!'));
    expect(n.body, equals('BODY'));
    expect(n.actions, equals(['KEY1', 'LABEL1', 'KEY2', 'LABEL2']));
    expect(
        n.hints, equals({'KEY1': DBusString('VALUE1'), 'KEY2': DBusUint32(2)}));
    expect(n.expireTimeoutMs, equals(42));
  });

  test('notification expired', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    addTearDown(() async {
      await server.close();
    });

    var notifications = MockNotificationsServer(clientAddress);
    await notifications.start();
    addTearDown(() async {
      await notifications.close();
    });

    // Send a simple notification and wait for it to be closed.
    var client = NotificationsClient(bus: DBusClient(clientAddress));
    addTearDown(() async {
      await client.close();
    });
    var notification = await client.notify('Hello World!');
    expect(notification.closeReason,
        completion(equals(NotificationClosedReason.expired)));

    // Close the notification.
    notifications.emitNotificationClosed(notification.id, 1);
  });

  test('notification dismissed', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    addTearDown(() async {
      await server.close();
    });

    var notifications = MockNotificationsServer(clientAddress);
    await notifications.start();
    addTearDown(() async {
      await notifications.close();
    });

    // Send a simple notification and wait for it to be closed.
    var client = NotificationsClient(bus: DBusClient(clientAddress));
    addTearDown(() async {
      await client.close();
    });
    var notification = await client.notify('Hello World!');
    expect(notification.closeReason,
        completion(equals(NotificationClosedReason.dismissed)));

    // Close the notification.
    notifications.emitNotificationClosed(notification.id, 2);
  });

  test('notification closed', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    addTearDown(() async {
      await server.close();
    });

    var notifications = MockNotificationsServer(clientAddress);
    await notifications.start();
    addTearDown(() async {
      await notifications.close();
    });

    // Send a simple notification and wait for it to be closed.
    var client = NotificationsClient(bus: DBusClient(clientAddress));
    addTearDown(() async {
      await client.close();
    });
    var notification = await client.notify('Hello World!');
    expect(notification.closeReason,
        completion(equals(NotificationClosedReason.closed)));

    // Close the notification.
    notifications.emitNotificationClosed(notification.id, 3);
  });

  test('notification action', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    addTearDown(() async {
      await server.close();
    });

    var notifications = MockNotificationsServer(clientAddress);
    await notifications.start();
    addTearDown(() async {
      await notifications.close();
    });

    // Send a simple notification and wait for it to be closed.
    var client = NotificationsClient(bus: DBusClient(clientAddress));
    addTearDown(() async {
      await client.close();
    });
    var notification = await client
        .notify('Hello World!', actions: [NotificationAction('KEY', 'LABEL')]);
    expect(notification.action, completion(equals('KEY')));

    // Close the notification.
    notifications.emitActionInvoked(notification.id, 'KEY');
  });

  test('close notification', () async {
    var server = DBusServer();
    var clientAddress =
        await server.listenAddress(DBusAddress.unix(dir: Directory.systemTemp));
    addTearDown(() async {
      await server.close();
    });

    var notifications = MockNotificationsServer(clientAddress);
    await notifications.start();
    addTearDown(() async {
      await notifications.close();
    });

    // Send, then close a simple notification.
    var client = NotificationsClient(bus: DBusClient(clientAddress));
    addTearDown(() async {
      await client.close();
    });
    var notification = await client.notify('Hello World!');
    await notification.close();

    expect(notifications.notifications, isEmpty);
  });
}
