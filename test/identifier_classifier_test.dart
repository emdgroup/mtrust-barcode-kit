import 'package:flutter_test/flutter_test.dart';
import 'package:mtrust_barcode_kit/mtrust_barcode_kit.dart';

DetectedText _text(
  String text, {
  double centerX = 0,
  double centerY = 0,
  double confidence = 0.9,
  int blockIndex = 0,
  int lineIndex = 0,
}) {
  return DetectedText(
    text: text,
    confidence: confidence,
    cornerPoints: [
      CornerPoint(x: centerX - 5, y: centerY - 5),
      CornerPoint(x: centerX + 5, y: centerY - 5),
      CornerPoint(x: centerX + 5, y: centerY + 5),
      CornerPoint(x: centerX - 5, y: centerY + 5),
    ],
    blockIndex: blockIndex,
    lineIndex: lineIndex,
  );
}

void main() {
  group('IdentifierClassifier heuristics', () {
    final classifier = IdentifierClassifier();

    test('plain English word scores low', () {
      final result = classifier.classify(_text('hello'));
      expect(result.confidence, lessThan(0.3));
    });

    test('alphanumeric mixed token scores high', () {
      final result = classifier.classify(_text('AB12-K734'));
      expect(result.confidence, greaterThan(0.6));
    });

    test('pure digit token scores moderately (no letter mix)', () {
      final result = classifier.classify(_text('123456'));
      // No digit/letter mix, but high digit ratio.
      expect(result.confidence, greaterThan(0.0));
      expect(result.featureBreakdown['digitLetterMix'], 0);
    });

    test('single-letter-prefix serial number scores high', () {
      final result = classifier.classify(_text('K123456789'));
      expect(result.confidence, greaterThan(0.6));
    });

    test('dot-separated numeric part number scores high', () {
      final result = classifier.classify(_text('1.06482.1000'));
      expect(result.confidence, greaterThan(0.6));
    });
  });

  group('IdentifierClassifier min length', () {
    test('token shorter than default minLength scores zero', () {
      final classifier = IdentifierClassifier();
      // Would otherwise score highly (digit+letter mix, separator-like
      // transitions), but is only 3 characters long.
      final result = classifier.classify(_text('A1B'));
      expect(result.excludedByMinLength, isTrue);
      expect(result.confidence, 0);
    });

    test('token at or above minLength is scored normally', () {
      final classifier = IdentifierClassifier();
      final result = classifier.classify(_text('K123456789'));
      expect(result.excludedByMinLength, isFalse);
      expect(result.confidence, greaterThan(0.6));
    });

    test('minLength can be lowered to allow shorter identifiers', () {
      final classifier = IdentifierClassifier(
        IdentifierClassifierConfig(minLength: 1),
      );
      final result = classifier.classify(_text('A1B'));
      expect(result.excludedByMinLength, isFalse);
      expect(result.confidence, greaterThan(0));
    });
  });

  group('IdentifierClassifier negative list', () {
    test('token in negative list is capped', () {
      final classifier = IdentifierClassifier(
        IdentifierClassifierConfig(
          negativeWordList: {'return'},
          negativeListConfidenceCap: 0.1,
        ),
      );
      final result = classifier.classify(_text('RETURN'));
      expect(result.excludedByNegativeList, isTrue);
      expect(result.confidence, lessThanOrEqualTo(0.1));
    });
  });

  group('IdentifierClassifier context labels', () {
    test('inline label + value is boosted and value extracted', () {
      final classifier = IdentifierClassifier(
        IdentifierClassifierConfig(contextLabels: ['LOT']),
      );
      final result = classifier.classify(_text('LOT: AB1234-7'));
      expect(result.token, 'AB1234-7');
      expect(result.matchedContextLabel, isTrue);
      expect(result.matchedLabelText, 'LOT');
      expect(result.confidence, greaterThan(0.8));
    });

    test('label-only line registers as a label with zero confidence', () {
      final classifier = IdentifierClassifier(
        IdentifierClassifierConfig(contextLabels: ['LOT']),
      );
      final result = classifier.classify(_text('LOT'));
      expect(result.isContextLabel, isTrue);
      expect(result.confidence, 0);
    });

    test(
      'value line near a previously seen label is boosted via proximity',
      () {
        final classifier = IdentifierClassifier(
          IdentifierClassifierConfig(
            contextLabels: ['LOT'],
            proximityThresholdPx: 100,
          ),
        );
        final now = DateTime(2024);

        final labelResult = classifier.classify(
          _text('LOT'),
          now: now,
        );
        expect(labelResult.isContextLabel, isTrue);

        final withoutLabel = IdentifierClassifier(
          IdentifierClassifierConfig(
            contextLabels: ['LOT'],
            proximityThresholdPx: 100,
          ),
        ).classify(_text('QZ981X', centerY: 30));

        final valueResult = classifier.classify(
          _text('QZ981X', centerY: 30),
          now: now.add(const Duration(milliseconds: 200)),
        );

        expect(valueResult.matchedContextLabel, isTrue);
        expect(valueResult.matchedLabelText, 'LOT');
        expect(valueResult.confidence, greaterThan(withoutLabel.confidence));
      },
    );

    test('value far away from label is not boosted', () {
      final classifier = IdentifierClassifier(
        IdentifierClassifierConfig(
          contextLabels: ['LOT'],
          proximityThresholdPx: 50,
        ),
      );
      final now = DateTime(2024);

      classifier.classify(_text('LOT'), now: now);
      final farResult = classifier.classify(
        _text('QZ981X', centerY: 1000),
        now: now.add(const Duration(milliseconds: 200)),
      );

      expect(farResult.matchedContextLabel, isFalse);
    });

    test('label expires after contextWindowDuration', () {
      final classifier = IdentifierClassifier(
        IdentifierClassifierConfig(
          contextLabels: ['LOT'],
          proximityThresholdPx: 100,
          contextWindowDuration: const Duration(seconds: 1),
        ),
      );
      final now = DateTime(2024);

      classifier.classify(_text('LOT'), now: now);
      final expiredResult = classifier.classify(
        _text('QZ981X', centerY: 30),
        now: now.add(const Duration(seconds: 5)),
      );

      expect(expiredResult.matchedContextLabel, isFalse);
    });
  });
}
