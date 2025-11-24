import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:troubadour/presentation/widgets/stroboscopic_tuner_display.dart';
import 'package:troubadour/services/audio/guitar_tuner_service.dart';

void main() {
  group('StroboscopicTunerDisplay', () {
    testWidgets('should render without tuning result',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StroboscopicTunerDisplay(
              tuningResult: null,
              width: 300,
              height: 120,
            ),
          ),
        ),
      );

      // Should show listening state
      expect(find.text('Listening...'), findsOneWidget);
      expect(find.text('--'), findsOneWidget);
      expect(find.text('-- Hz'), findsOneWidget);
    });

    testWidgets('should render with in-tune result',
        (WidgetTester tester) async {
      const string = GuitarString(name: 'E', frequency: 82.41, stringNumber: 6);
      const tuningResult = TuningResult(
        detectedFrequency: 82.41,
        closestString: string,
        centsOff: 0.0,
        confidence: 0.9,
        isInTune: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StroboscopicTunerDisplay(
              tuningResult: tuningResult,
              width: 300,
              height: 120,
            ),
          ),
        ),
      );

      // Should show in-tune state
      expect(find.text('E'), findsOneWidget);
      expect(find.text('82.4 Hz'), findsOneWidget);
      expect(find.text('IN TUNE'), findsOneWidget);
      expect(find.text('0¢'), findsOneWidget);
    });

    testWidgets('should render with sharp result', (WidgetTester tester) async {
      const string =
          GuitarString(name: 'A', frequency: 110.00, stringNumber: 5);
      const tuningResult = TuningResult(
        detectedFrequency: 112.0,
        closestString: string,
        centsOff: 31.2,
        confidence: 0.8,
        isInTune: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StroboscopicTunerDisplay(
              tuningResult: tuningResult,
              width: 300,
              height: 120,
            ),
          ),
        ),
      );

      // Should show sharp state
      expect(find.text('A'), findsOneWidget);
      expect(find.text('112.0 Hz'), findsOneWidget);
      expect(find.text('SHARP'), findsOneWidget);
      expect(find.text('+31¢'), findsOneWidget);
    });

    testWidgets('should render with flat result', (WidgetTester tester) async {
      const string =
          GuitarString(name: 'D', frequency: 146.83, stringNumber: 4);
      const tuningResult = TuningResult(
        detectedFrequency: 145.0,
        closestString: string,
        centsOff: -21.5,
        confidence: 0.7,
        isInTune: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StroboscopicTunerDisplay(
              tuningResult: tuningResult,
              width: 300,
              height: 120,
            ),
          ),
        ),
      );

      // Should show flat state
      expect(find.text('D'), findsOneWidget);
      expect(find.text('145.0 Hz'), findsOneWidget);
      expect(find.text('FLAT'), findsOneWidget);
      expect(find.text('-22¢'), findsOneWidget);
    });
  });

  group('CircularTuningIndicator', () {
    testWidgets('should render without tuning result',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CircularTuningIndicator(
              tuningResult: null,
              size: 100,
            ),
          ),
        ),
      );

      // Should render the widget without errors
      expect(find.byType(CircularTuningIndicator), findsOneWidget);
    });

    testWidgets('should render with tuning result',
        (WidgetTester tester) async {
      const string =
          GuitarString(name: 'G', frequency: 196.00, stringNumber: 3);
      const tuningResult = TuningResult(
        detectedFrequency: 196.5,
        closestString: string,
        centsOff: 4.4,
        confidence: 0.85,
        isInTune: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CircularTuningIndicator(
              tuningResult: tuningResult,
              size: 100,
            ),
          ),
        ),
      );

      // Should render the widget without errors
      expect(find.byType(CircularTuningIndicator), findsOneWidget);
    });
  });
}
