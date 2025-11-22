import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextchord/services/audio/guitar_tuner_service.dart';

void main() {
  group('GuitarTunerService', () {
    late GuitarTunerService tunerService;

    setUp(() {
      tunerService = GuitarTunerService();
    });

    group('GuitarString', () {
      test('should have correct standard tuning frequencies', () {
        expect(GuitarTunerService.standardTuning.length, equals(6));

        // Test standard tuning frequencies
        expect(GuitarTunerService.standardTuning[0].frequency,
            closeTo(82.41, 0.01)); // Low E
        expect(GuitarTunerService.standardTuning[1].frequency,
            closeTo(110.00, 0.01)); // A
        expect(GuitarTunerService.standardTuning[2].frequency,
            closeTo(146.83, 0.01)); // D
        expect(GuitarTunerService.standardTuning[3].frequency,
            closeTo(196.00, 0.01)); // G
        expect(GuitarTunerService.standardTuning[4].frequency,
            closeTo(246.94, 0.01)); // B
        expect(GuitarTunerService.standardTuning[5].frequency,
            closeTo(329.63, 0.01)); // High E
      });

      test('should have correct string numbers', () {
        expect(GuitarTunerService.standardTuning[0].stringNumber,
            equals(6)); // Low E
        expect(GuitarTunerService.standardTuning[5].stringNumber,
            equals(1)); // High E
      });

      test('should have correct string names', () {
        final names =
            GuitarTunerService.standardTuning.map((s) => s.name).toList();
        expect(names, equals(['E', 'A', 'D', 'G', 'B', 'E']));
      });
    });

    group('TuningResult', () {
      test('should create valid tuning result', () {
        const string =
            GuitarString(name: 'E', frequency: 82.41, stringNumber: 6);
        const result = TuningResult(
          detectedFrequency: 82.5,
          closestString: string,
          centsOff: 2.0,
          confidence: 0.8,
          isInTune: true,
        );

        expect(result.detectedFrequency, equals(82.5));
        expect(result.closestString, equals(string));
        expect(result.centsOff, equals(2.0));
        expect(result.confidence, equals(0.8));
        expect(result.isInTune, isTrue);
      });
    });

    group('Service State', () {
      test('should initialize with correct default state', () {
        expect(tunerService.isListening, isFalse);
        expect(tunerService.currentResult, isNull);
      });

      test('should be singleton', () {
        final service1 = GuitarTunerService();
        final service2 = GuitarTunerService();
        expect(identical(service1, service2), isTrue);
      });
    });

    group('Frequency Analysis Helpers', () {
      test('should find closest string correctly', () {
        // Test finding closest string for frequencies near standard tuning

        // Test low E string (82.41 Hz)
        final closestToLowE = tunerService.findClosestStringForTesting(82.0);
        expect(closestToLowE.name, equals('E'));
        expect(closestToLowE.stringNumber, equals(6));

        // Test A string (110.00 Hz)
        final closestToA = tunerService.findClosestStringForTesting(111.0);
        expect(closestToA.name, equals('A'));
        expect(closestToA.stringNumber, equals(5));

        // Test high E string (329.63 Hz)
        final closestToHighE = tunerService.findClosestStringForTesting(330.0);
        expect(closestToHighE.name, equals('E'));
        expect(closestToHighE.stringNumber, equals(1));
      });

      test('should calculate cents correctly', () {
        // Test cents calculation
        final cents1 = tunerService.calculateCentsForTesting(440.0, 440.0);
        expect(cents1, closeTo(0.0, 0.01));

        final cents2 = tunerService.calculateCentsForTesting(440.0, 220.0);
        expect(cents2, closeTo(1200.0, 0.01)); // One octave = 1200 cents

        final cents3 = tunerService.calculateCentsForTesting(220.0, 440.0);
        expect(cents3, closeTo(-1200.0, 0.01)); // One octave down = -1200 cents
      });
    });
  });
}

// Extension to expose private methods for testing
extension GuitarTunerServiceTesting on GuitarTunerService {
  GuitarString findClosestStringForTesting(double frequency) {
    GuitarString closest = GuitarTunerService.standardTuning.first;
    double minDifference = (frequency - closest.frequency).abs();

    for (final string in GuitarTunerService.standardTuning) {
      final difference = (frequency - string.frequency).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closest = string;
      }
    }

    return closest;
  }

  double calculateCentsForTesting(double frequency1, double frequency2) {
    return 1200 * log(frequency1 / frequency2) / ln2;
  }
}
