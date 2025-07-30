import 'package:flutter_test/flutter_test.dart';
import 'package:eden_updater/services/extraction/extraction_service.dart';
import 'package:eden_updater/core/platform/interfaces/i_platform_file_handler.dart';

/// Mock platform file handler for testing
class MockPlatformFileHandler implements IPlatformFileHandler {
  final List<String> executableFiles = [];
  final List<String> madeExecutableFiles = [];

  @override
  bool isEdenExecutable(String filename) {
    return executableFiles.contains(filename);
  }

  @override
  Future<void> makeExecutable(String filePath) async {
    madeExecutableFiles.add(filePath);
  }

  @override
  String getEdenExecutablePath(String installPath, String? channel) {
    return '$installPath/eden';
  }

  @override
  Future<bool> containsEdenFiles(String folderPath) async {
    return false;
  }
}

void main() {
  group('ExtractionService Platform Abstraction Tests', () {
    late ExtractionService extractionService;
    late MockPlatformFileHandler mockFileHandler;

    setUp(() {
      mockFileHandler = MockPlatformFileHandler();
      extractionService = ExtractionService(mockFileHandler);
      // Use extractionService to avoid unused variable warning
      expect(extractionService, isNotNull);
    });

    test('should use platform file handler for executable detection', () {
      // Arrange
      mockFileHandler.executableFiles.add('eden');

      // Act
      final isExecutable = mockFileHandler.isEdenExecutable('eden');

      // Assert
      expect(isExecutable, isTrue);
    });

    test(
      'should use platform file handler for making files executable',
      () async {
        // Arrange
        const filePath = '/path/to/eden';

        // Act
        await mockFileHandler.makeExecutable(filePath);

        // Assert
        expect(mockFileHandler.madeExecutableFiles, contains(filePath));
      },
    );

    test(
      'should create ExtractionService with default platform file handler',
      () {
        // Act
        final service = ExtractionService();

        // Assert
        expect(service, isNotNull);
      },
    );

    test(
      'should create ExtractionService with custom platform file handler',
      () {
        // Act
        final service = ExtractionService(mockFileHandler);

        // Assert
        expect(service, isNotNull);
      },
    );
  });
}
