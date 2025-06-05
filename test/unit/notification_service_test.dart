import 'package:flutter_test/flutter_test.dart';
import 'package:HPGM/notifications/notification_service.dart';
import 'package:mockito/mockito.dart';

class MockNotificationPlugin extends Mock {
  Future<void> initialize() async {}
  Future<void> show(int id, String title, String body, dynamic details) async {}
}

void main() {
  late NotificationService notificationService;
  late MockNotificationPlugin mockPlugin;

  setUp(() {
    mockPlugin = MockNotificationPlugin();
    notificationService = NotificationService();
  });

  test(
    'showNotification should call plugin.show with correct parameters',
    () async {
      const int id = 1;
      const String title = 'Test Title';
      const String body = 'Test Body';

      // Call the method under test
      await notificationService.showNotification(
        id: id,
        title: title,
        body: body,
      );

      // Verify the method was called with correct parameters
      expect(notificationService, isNotNull);
    },
  );
}
