import 'package:flutter_test/flutter_test.dart';
import 'package:HPGM/notifications/weather_data_service.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late WeatherDataService weatherService;
  late MockHttpClient mockClient;

  setUp(() {
    mockClient = MockHttpClient();
    weatherService = WeatherDataService();
  });

  test('_getMockWeatherData returns valid mock data', () {
    // This is testing a private method, so we're indirectly testing it by forcing the mock path
    final mockData = weatherService.getMockWeatherData();

    expect(mockData, isNotNull);
    expect(mockData.temperature, equals(25.5));
    expect(mockData.humidity, equals(65.0));
    expect(mockData.windSpeed, equals(12.0));
    expect(mockData.condition, equals('Partly cloudy'));
    expect(mockData.isRaining, equals(false));
    expect(mockData.timestamp, isNotNull);
  });
}
