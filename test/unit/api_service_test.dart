import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([http.Client])
import 'api_service_test.mocks.dart';

void main() {
  late MockClient mockClient;

  setUp(() {
    mockClient = MockClient();
  });

  group('API Service', () {
    test('Sample test to check mock setup', () {
      // Simple test to verify the mock is created properly
      expect(mockClient, isNotNull);
    });
  });
}