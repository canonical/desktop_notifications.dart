import 'dart:async';
import 'dart:typed_data';
import 'package:dbus/dbus.dart';

/// Contains information reported by the notifications server.
class NotificationsServerInformation {
  /// Name of the server.
  final String name;

  /// The vendor of the sever.
  final String vendor;

  /// The version of the server.
  final String version;

  /// The notifications specification version this server implements.
  final String specVersion;

  const NotificationsServerInformation(
      this.name, this.vendor, this.version, this.specVersion);

  @override
  String toString() {
    return "NotificationsServerInformation(name: '$name', vendor: '$vendor', version: '$version', specVersion: '$specVersion')";
  }
}

/// Categories of notifications.
class NotificationCategory {
  /// Name of this category.
  final String name;

  const NotificationCategory(this.name);

  factory NotificationCategory.device() => NotificationCategory('device');
  factory NotificationCategory.deviceAdded() =>
      NotificationCategory('device.added');
  factory NotificationCategory.deviceError() =>
      NotificationCategory('device.error');
  factory NotificationCategory.deviceRemoved() =>
      NotificationCategory('device.removed');
  factory NotificationCategory.email() => NotificationCategory('email');
  factory NotificationCategory.emailArrived() =>
      NotificationCategory('email.arrived');
  factory NotificationCategory.emailBounced() =>
      NotificationCategory('email.bounced');
  factory NotificationCategory.im() => NotificationCategory('im');
  factory NotificationCategory.imError() => NotificationCategory('imError');
  factory NotificationCategory.imReceived() =>
      NotificationCategory('imReceived');
  factory NotificationCategory.network() => NotificationCategory('network');
  factory NotificationCategory.networkConnected() =>
      NotificationCategory('network.connected');
  factory NotificationCategory.networkDisconnected() =>
      NotificationCategory('network.disconnected');
  factory NotificationCategory.networkError() =>
      NotificationCategory('network.error');
}

/// Urgency of a notification
enum NotificationUrgency { low, normal, critical }

/// A hint about how to display this notification.
class NotificationHint {
  /// Unique key for this hint.
  final String key;

  /// The value of this hint.
  final DBusValue value;

  /// Creates a custom notification hint.
  const NotificationHint(this.key, this.value);

  /// This notification should have its action IDs intepreted as icon names.
  factory NotificationHint.actionIcons() {
    return NotificationHint('action-icons', DBusBoolean(true));
  }

  /// This notification is of type [category].
  factory NotificationHint.category(NotificationCategory category) {
    return NotificationHint('category', DBusString(category.name));
  }

  /// This notification is from the application with the desktop file [name].desktop.
  factory NotificationHint.desktopEntry(String name) {
    return NotificationHint('desktop-entry', DBusString(name));
  }

  /// This notification should show use the supplied raw image data for its icon.
  /// [data] is the raw data for the image.
  /// [width] and [height] are the width and height of the image in pixels.
  /// [rowStride] is the number of bytes per row in [data].
  /// [hasAlpha] is true if the image has an alpha channel.
  /// [bitsPerSample] is the number of bits in each color sample.
  /// [channels] is the number of channels in the image (e.g. 3 for RGB, 4 for RGBA).
  factory NotificationHint.imageData(int width, int height, Uint8List data,
      {int rowStride = -1,
      bool hasAlpha = false,
      int bitsPerSample = 8,
      int channels = 3}) {
    if (rowStride < 0) {
      rowStride = ((width * channels * bitsPerSample) / 8).ceil();
    }
    return NotificationHint(
        'image-data',
        DBusStruct([
          DBusInt32(width),
          DBusInt32(height),
          DBusInt32(rowStride),
          DBusBoolean(hasAlpha),
          DBusInt32(bitsPerSample),
          DBusInt32(channels),
          DBusArray(DBusSignature('y'), data.map((d) => DBusByte(d)))
        ]));
  }

  /// This notification should use the image at [path] as the icon.
  factory NotificationHint.imagePath(String path) {
    return NotificationHint('image-path', DBusString(path));
  }

  /// This notification should not be removed when its action is invoked. It will be removed when explicitly removed by this client or the user.
  factory NotificationHint.resident() {
    return NotificationHint('resident', DBusBoolean(true));
  }

  /// This notification should play the sound file at [path] when shown.
  factory NotificationHint.soundFile(String path) {
    return NotificationHint('sound-file', DBusString(path));
  }

  /// This notification should play the sound from the sound theme with [name] when shown.
  factory NotificationHint.soundName(String name) {
    return NotificationHint('sound-name', DBusString(name));
  }

  /// This notification should not trigger any any sounds that would normally play for notifications.
  factory NotificationHint.suppressSound() {
    return NotificationHint('suppress-sound', DBusBoolean(true));
  }

  /// This notification should be transient and by-pass the server's persistent capability.
  factory NotificationHint.transient() {
    return NotificationHint('transient', DBusBoolean(true));
  }

  /// This notification should be placed at the given [x] and [y] co-ordinates.
  factory NotificationHint.location(int x, int y) {
    return NotificationHint(
        '*location', DBusStruct([DBusByte(x), DBusByte(y)]));
  }

  /// This notification should have the given [urgency] level.
  factory NotificationHint.urgency(NotificationUrgency urgency) {
    var urgencyValue = -1;
    if (urgency == NotificationUrgency.low) {
      urgencyValue = 0;
    } else if (urgency == NotificationUrgency.normal) {
      urgencyValue = 1;
    } else if (urgency == NotificationUrgency.critical) {
      urgencyValue = 2;
    }
    return NotificationHint('urgency', DBusByte(urgencyValue));
  }
}

/// An action the user can perform on a notification.
class NotificationAction {
  /// Unique key for this action.
  final String key;

  /// Label to show to the user.
  final String label;

  /// Creates a new notification action.
  const NotificationAction(this.key, this.label);
}

/// The reason a notification was closed.
enum NotificationClosedReason { expired, dismissed, closed, unknown }

/// A notification that was created by this client.
class Notification {
  /// The client this notification is part of.
  final NotificationsClient client;

  /// Id number assigned to this notification.
  final int id;

  /// The action that was chosen by the user.
  Future<String> get action => _actionCompleter.future;

  /// The reason the notification was closed.
  Future<NotificationClosedReason> get closeReason => _closeCompleter.future;

  final _actionCompleter = Completer<String>();
  final _closeCompleter = Completer<NotificationClosedReason>();

  /// Creates a new notification object.
  /// You should not need to use this constructor directly and instead use a value returned from [NotificationsClient.notify].
  /// Creating a notification from an ID may be required if you had no manage a notification created by other code.
  Notification(this.client, this.id) {
    // Subscribe signals here in case this wasn't created by our client.
    client._subscribeSignals();
    client._notifications[id] = this;
  }

  /// Closes this notification.
  Future<void> close() async {
    await client._object.callMethod(
        'org.freedesktop.Notifications', 'CloseNotification', [DBusUint32(id)]);
  }
}

/// A client that connects to the notifications server.
class NotificationsClient {
  /// The bus this client is connected to.
  final DBusClient _bus;
  final bool _closeBus;

  late final DBusRemoteObject _object;

// Signal subscriptions.
  StreamSubscription? _actionInvokedSubscription;
  StreamSubscription? _notificationClosedSubscription;

  // Notifications in progress.
  final _notifications = <int, Notification>{};

  /// Creates a new notification client. If [bus] is provided connect to the given D-Bus server.
  NotificationsClient({DBusClient? bus})
      : _bus = bus ?? DBusClient.session(),
        _closeBus = bus == null {
    _object = DBusRemoteObject(_bus, 'org.freedesktop.Notifications',
        DBusObjectPath('/org/freedesktop/Notifications'));
  }

  /// Sends a notification with a [summary] and optional [body].
  ///
  /// [appName] is a human readable name for the application that generated the notification, e.g. 'Firefox Browser'.
  /// [appIcon] is either a URI (e.g. 'file:///usr/share/icons/firefox.png') or an icon theme name (e.g. 'web-browser').
  /// [expireTimeoutMs] specified the expiration timeout in milliseconds with -1 used for the system default and 0 for no expiration.
  /// [replacesId] is the ID of an existing notification this notification replaces.
  /// [actions] is a list of actions the user can perform on this notification.
  /// [hints] is a list of hints about how the notification should be shown.
  ///
  /// Returns an object representing the notification.
  Future<Notification> notify(String summary,
      {String body = '',
      String appName = '',
      String appIcon = '',
      int expireTimeoutMs = -1,
      int replacesId = 0,
      List<NotificationHint> hints = const [],
      List<NotificationAction> actions = const []}) async {
    _subscribeSignals();

    var actionsValues = <DBusValue>[];
    for (var action in actions) {
      actionsValues.add(DBusString(action.key));
      actionsValues.add(DBusString(action.label));
    }
    var hintsValues = <DBusValue, DBusValue>{};
    for (var hint in hints) {
      if (hint.key == '*location') {
        var locationValues = (hint.value as DBusStruct).children;
        hintsValues[DBusString('x')] = DBusVariant(locationValues.elementAt(0));
        hintsValues[DBusString('y')] = DBusVariant(locationValues.elementAt(1));
      } else {
        hintsValues[DBusString(hint.key)] = DBusVariant(hint.value);
      }
    }
    var result =
        await _object.callMethod('org.freedesktop.Notifications', 'Notify', [
      DBusString(appName),
      DBusUint32(replacesId),
      DBusString(appIcon),
      DBusString(summary),
      DBusString(body),
      DBusArray(DBusSignature('s'), actionsValues),
      DBusDict(DBusSignature('s'), DBusSignature('v'), hintsValues),
      DBusInt32(expireTimeoutMs)
    ]);
    var id = (result.returnValues[0] as DBusUint32).value;

    return Notification(this, id);
  }

  /// Gets the capabilities of the notifications server.
  Future<List<String>> getCapabilities() async {
    var result = await _object
        .callMethod('org.freedesktop.Notifications', 'GetCapabilities', []);
    var values = result.returnValues;
    if (values.length != 1 || values[0].signature != DBusSignature('as')) {
      throw 'GetCapabilities returned invalid result: $values';
    }
    return (values[0] as DBusArray)
        .children
        .map((child) => (child as DBusString).value)
        .toList();
  }

  /// Gets information about the notifications server.
  Future<NotificationsServerInformation> getServerInformation() async {
    var result = await _object.callMethod(
        'org.freedesktop.Notifications', 'GetServerInformation', []);
    var values = result.returnValues;
    if (values.length != 4 ||
        values[0].signature != DBusSignature('s') ||
        values[1].signature != DBusSignature('s') ||
        values[2].signature != DBusSignature('s') ||
        values[3].signature != DBusSignature('s')) {
      throw 'GetServerInformation returned invalid result: $values';
    }
    return NotificationsServerInformation(
        (values[0] as DBusString).value,
        (values[1] as DBusString).value,
        (values[2] as DBusString).value,
        (values[3] as DBusString).value);
  }

  /// Terminates all active connections. If a client remains unclosed, the Dart process may not terminate.
  Future<void> close() async {
    if (_actionInvokedSubscription != null) {
      await _actionInvokedSubscription?.cancel();
      _actionInvokedSubscription = null;
    }
    if (_notificationClosedSubscription != null) {
      await _notificationClosedSubscription?.cancel();
      _notificationClosedSubscription = null;
    }
    if (_closeBus) {
      await _bus.close();
    }
  }

  /// Subscribe to the signals for actions and notifications being closed.
  void _subscribeSignals() {
    // Ensure the signals are only subscribed once.
    if (_actionInvokedSubscription != null) {
      return;
    }

    var actionsInvokedSignals = _object.subscribeSignal(
        'org.freedesktop.Notifications', 'ActionInvoked');
    _actionInvokedSubscription = actionsInvokedSignals.listen((signal) {
      if (signal.values.length != 2 ||
          signal.values[0].signature != DBusSignature('u') ||
          signal.values[1].signature != DBusSignature('s')) {
        return;
      }

      var id = (signal.values[0] as DBusUint32).value;
      var actionKey = (signal.values[1] as DBusString).value;
      var notification = _notifications[id];
      if (notification != null) {
        notification._actionCompleter.complete(actionKey);
      }
    });

    var closedSignals = _object.subscribeSignal(
        'org.freedesktop.Notifications', 'NotificationClosed');
    _notificationClosedSubscription = closedSignals.listen((signal) {
      if (signal.values.length != 2 ||
          signal.values[0].signature != DBusSignature('u') ||
          signal.values[1].signature != DBusSignature('u')) {
        return;
      }

      var id = (signal.values[0] as DBusUint32).value;
      var reasonId = (signal.values[1] as DBusUint32).value;
      var reason = NotificationClosedReason.unknown;
      if (reasonId == 1) {
        reason = NotificationClosedReason.expired;
      } else if (reasonId == 2) {
        reason = NotificationClosedReason.dismissed;
      } else if (reasonId == 3) {
        reason = NotificationClosedReason.closed;
      }
      var notification = _notifications[id];
      if (notification != null) {
        notification._closeCompleter.complete(reason);
      }
    });
  }
}
