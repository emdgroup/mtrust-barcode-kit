import 'dart:math' as math;

import 'package:mtrust_barcode_kit/src/pigeon.dart';

/// Configuration for [IdentifierClassifier].
///
/// There are no built-in defaults for [contextLabels] or [negativeWordList]:
/// both are domain/locale specific, so callers must supply whatever makes
/// sense for their labels (e.g. `['LOT', 'REF', 'S/N', 'SN', 'PN', 'BATCH']`)
/// and, optionally, a list of real words that should never be treated as an
/// identifier even if they otherwise score highly.
class IdentifierClassifierConfig {
  /// Creates a new [IdentifierClassifierConfig].
  IdentifierClassifierConfig({
    this.contextLabels = const [],
    this.negativeWordList = const {},
    Map<String, double>? featureWeights,
    this.proximityThresholdPx = 150,
    this.contextWindowDuration = const Duration(seconds: 3),
    this.contextLabelBoost = 0.6,
    this.negativeListConfidenceCap = 0.15,
    this.minLength = 4,
  }) : featureWeights = {...defaultFeatureWeights, ...?featureWeights};

  /// Labels (e.g. `LOT`, `REF`, `S/N`, `PN`, `BATCH`) that identify nearby
  /// text as an identifier value. Matching is case-insensitive and ignores
  /// a single trailing `:`, `#`, or `-` on the detected token.
  final List<String> contextLabels;

  /// Tokens (case-insensitive) that should never be treated as an
  /// identifier, regardless of how they score - e.g. common words that
  /// might otherwise look "unusual" enough to score highly.
  final Set<String> negativeWordList;

  /// Per-feature weight overrides. See [defaultFeatureWeights] for the
  /// available feature keys and their default weights. Unspecified keys
  /// fall back to the defaults; all weights are expected to sum to
  /// approximately `1.0` for the composite score to stay within `0..1`
  /// before label-boost/negative-list adjustments, but this isn't enforced.
  final Map<String, double> featureWeights;

  /// Maximum distance, in the same pixel units as [DetectedText.cornerPoints]
  /// (i.e. full camera-texture pixel space), between a token's centroid and
  /// a recently seen label's centroid for the token to be considered
  /// "near" that label.
  final double proximityThresholdPx;

  /// How long a seen label stays "active" for proximity matching, to
  /// tolerate the camera holding on a label across multiple detection
  /// frames before drifting to the value.
  final Duration contextWindowDuration;

  /// How much a context-label match (inline or proximity-based) closes the
  /// gap between the base heuristic score and `1.0`. `1.0` means a strong
  /// label match alone can drive the score to (near) certainty; `0.0`
  /// disables label boosting entirely.
  final double contextLabelBoost;

  /// Confidence scores are capped at this value when the token matches
  /// [negativeWordList], regardless of how "identifier-like" it otherwise
  /// scores.
  final double negativeListConfidenceCap;

  /// Tokens shorter than this are never treated as identifiers - their
  /// confidence is forced to `0` regardless of how they otherwise score.
  /// Real lot/product/serial numbers are rarely shorter than a handful of
  /// characters, so this filters out short noise (stray letters/digits,
  /// short common words) without needing a dictionary. Set to `1` (or `0`)
  /// to disable this filter entirely.
  final int minLength;

  /// Default per-feature weights, summing to `1.0`. See
  /// [IdentifierClassifier] feature functions for what each key measures.
  static const Map<String, double> defaultFeatureWeights = {
    'hasDigit': 0.15,
    'digitLetterMix': 0.10,
    'charClassTransitions': 0.15,
    'unnaturalPhonotactics': 0.20,
    'internalSeparator': 0.15,
    'lengthScore': 0.10,
    'digitRatio': 0.15,
  };
}

/// The result of scoring a single token extracted from a [DetectedText]
/// event.
class ScoredToken {
  /// Creates a new [ScoredToken].
  const ScoredToken({
    required this.detection,
    required this.token,
    required this.confidence,
    required this.featureBreakdown,
    required this.matchedContextLabel,
    required this.isContextLabel,
    required this.excludedByNegativeList,
    this.excludedByMinLength = false,
    this.matchedLabelText,
  });

  /// The original OCR detection this token was extracted from.
  final DetectedText detection;

  /// The specific token (typically a whitespace-delimited substring of
  /// [DetectedText.text], or the full trimmed text if a label/value split
  /// applied) that [confidence] applies to.
  final String token;

  /// Composite identifier-likeness confidence, `0..1`.
  final double confidence;

  /// Per-feature raw contributions (post-weighting), for debugging/tuning.
  final Map<String, double> featureBreakdown;

  /// Whether this token was boosted by a nearby (or inline) context label
  /// match.
  final bool matchedContextLabel;

  /// The label text that matched, if [matchedContextLabel] is true.
  final String? matchedLabelText;

  /// True if [token] itself is one of
  /// [IdentifierClassifierConfig.contextLabels] (i.e. this detection is the
  /// label, not a value candidate).
  final bool isContextLabel;

  /// True if [token] matched [IdentifierClassifierConfig.negativeWordList].
  final bool excludedByNegativeList;

  /// True if `token.length` was below [IdentifierClassifierConfig.minLength].
  final bool excludedByMinLength;
}

class _ActiveLabel {
  _ActiveLabel(this.label, this.centroid, this.timestamp);
  final String label;
  final _Point centroid;
  final DateTime timestamp;
}

class _Point {
  const _Point(this.x, this.y);
  final double x;
  final double y;

  double distanceTo(_Point other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// Scores OCR text lines by how "identifier-like" (lot/product/serial
/// number-like) they are, using shape-agnostic heuristics plus optional
/// proximity to configurable context labels (e.g. `LOT`, `REF`, `S/N`).
///
/// Feed every [DetectedText] event from `BarcodeKitView.onTextDetected`
/// into [classify]; the classifier maintains its own internal sliding
/// window of recently seen labels, so no manual batching is required.
class IdentifierClassifier {
  /// Creates a new [IdentifierClassifier] with the given [config].
  IdentifierClassifier([IdentifierClassifierConfig? config])
      : config = config ?? IdentifierClassifierConfig();

  /// The configuration used by this classifier.
  final IdentifierClassifierConfig config;

  final List<_ActiveLabel> _activeLabels = [];

  static final RegExp _wordSplitRegExp = RegExp(r'\s+');

  /// Scores the given [detection]. [now] defaults to [DateTime.now] and is
  /// exposed for deterministic testing.
  ScoredToken classify(DetectedText detection, {DateTime? now}) {
    final currentTime = now ?? DateTime.now();
    _pruneExpiredLabels(currentTime);

    final centroid = _centroidOf(detection.cornerPoints);
    final text = detection.text.trim();

    final inlineMatch = _matchInlineLabel(text);
    if (inlineMatch != null) {
      final (label, remainder) = inlineMatch;
      if (centroid != null) {
        _activeLabels.add(_ActiveLabel(label, centroid, currentTime));
      }

      if (remainder.isEmpty) {
        // Label alone on this line - nothing to score as a value yet.
        return ScoredToken(
          detection: detection,
          token: text,
          confidence: 0,
          featureBreakdown: const {},
          matchedContextLabel: false,
          isContextLabel: true,
          excludedByNegativeList: false,
        );
      }

      return _scoreToken(
        detection: detection,
        token: remainder,
        matchedContextLabel: true,
        matchedLabelText: label,
        labelBoostStrength: 1,
      );
    }

    // No inline label - check if the whole line is itself just a label
    // (e.g. "LOT" alone, with the value expected on a following line).
    final asLabel = _normalizeLabelToken(text);
    if (asLabel != null) {
      if (centroid != null) {
        _activeLabels.add(_ActiveLabel(asLabel, centroid, currentTime));
      }
      return ScoredToken(
        detection: detection,
        token: text,
        confidence: 0,
        featureBreakdown: const {},
        matchedContextLabel: false,
        isContextLabel: true,
        excludedByNegativeList: false,
      );
    }

    // Regular candidate token(s): score every whitespace-delimited token
    // and keep the best-scoring one as representative for this detection.
    final tokens = text
        .split(_wordSplitRegExp)
        .where((t) => t.isNotEmpty)
        .toList();
    final candidates = tokens.isEmpty ? [text] : tokens;

    String? nearestLabel;
    var nearestBoost = 0.0;
    if (centroid != null) {
      for (final active in _activeLabels) {
        final distance = centroid.distanceTo(active.centroid);
        if (distance <= config.proximityThresholdPx) {
          final boost = 1 - (distance / config.proximityThresholdPx);
          if (boost > nearestBoost) {
            nearestBoost = boost;
            nearestLabel = active.label;
          }
        }
      }
    }

    ScoredToken? best;
    for (final candidate in candidates) {
      final scored = _scoreToken(
        detection: detection,
        token: candidate,
        matchedContextLabel: nearestLabel != null,
        matchedLabelText: nearestLabel,
        labelBoostStrength: nearestBoost,
      );
      if (best == null || scored.confidence > best.confidence) {
        best = scored;
      }
    }

    return best!;
  }

  void _pruneExpiredLabels(DateTime now) {
    _activeLabels.removeWhere(
      (active) =>
          now.difference(active.timestamp) > config.contextWindowDuration,
    );
  }

  _Point? _centroidOf(List<CornerPoint?> cornerPoints) {
    final points = cornerPoints.whereType<CornerPoint>().toList();
    if (points.isEmpty) return null;
    final sumX = points.fold<double>(0, (sum, p) => sum + p.x);
    final sumY = points.fold<double>(0, (sum, p) => sum + p.y);
    return _Point(sumX / points.length, sumY / points.length);
  }

  /// Matches a leading label at the start of [text], e.g. `"LOT: AB1234-7"`
  /// -> `('LOT', 'AB1234-7')`, or `"REF"` -> `('REF', '')` if there's nothing
  /// after it on the same line but it's not the *entire* trimmed text (rare;
  /// most single-label lines are instead caught by [_normalizeLabelToken]).
  (String, String)? _matchInlineLabel(String text) {
    for (final label in config.contextLabels) {
      final pattern = RegExp(
        '^${RegExp.escape(label)}\\s*[:#-]?\\s+(.+)\$',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(text);
      if (match != null) {
        return (label, match.group(1)!.trim());
      }
    }
    return null;
  }

  /// Returns the matching configured label if [text] (ignoring a single
  /// trailing separator) *is* one of
  /// [IdentifierClassifierConfig.contextLabels], or `null` otherwise.
  String? _normalizeLabelToken(String text) {
    final stripped = text.replaceAll(RegExp(r'[:#-]+$'), '').trim();
    for (final label in config.contextLabels) {
      if (stripped.toUpperCase() == label.toUpperCase()) {
        return label;
      }
    }
    return null;
  }

  ScoredToken _scoreToken({
    required DetectedText detection,
    required String token,
    required bool matchedContextLabel,
    required String? matchedLabelText,
    required double labelBoostStrength,
  }) {
    final features = _computeFeatures(token);
    var confidence = 0.0;
    for (final entry in features.entries) {
      final weight = config.featureWeights[entry.key] ?? 0;
      confidence += weight * entry.value;
    }
    confidence = confidence.clamp(0, 1);

    if (matchedContextLabel && config.contextLabelBoost > 0) {
      final boost = config.contextLabelBoost * labelBoostStrength;
      confidence = confidence + (1 - confidence) * boost;
    }

    final excludedByNegativeList = config.negativeWordList.contains(
      token.toLowerCase(),
    );
    if (excludedByNegativeList) {
      confidence = math.min(confidence, config.negativeListConfidenceCap);
    }

    final excludedByMinLength = token.length < config.minLength;
    if (excludedByMinLength) {
      confidence = 0;
    }

    return ScoredToken(
      detection: detection,
      token: token,
      confidence: confidence.clamp(0, 1),
      featureBreakdown: features,
      matchedContextLabel: matchedContextLabel,
      matchedLabelText: matchedLabelText,
      isContextLabel: false,
      excludedByNegativeList: excludedByNegativeList,
      excludedByMinLength: excludedByMinLength,
    );
  }

  /// Computes shape-agnostic heuristic features for [token], each `0..1`,
  /// already keyed by the same names used in
  /// [IdentifierClassifierConfig.defaultFeatureWeights].
  Map<String, double> _computeFeatures(String token) {
    return {
      'hasDigit': _hasDigitScore(token),
      'digitLetterMix': _digitLetterMixScore(token),
      'charClassTransitions': _charClassTransitionScore(token),
      'unnaturalPhonotactics': _unnaturalPhonotacticsScore(token),
      'internalSeparator': _internalSeparatorScore(token),
      'lengthScore': _lengthScore(token),
      'digitRatio': _digitRatioScore(token),
    };
  }

  /// Real words essentially never contain digits at all, so the mere
  /// presence of any digit is already a meaningful signal on its own -
  /// independent of [_digitLetterMixScore], which additionally requires a
  /// letter too and would otherwise give zero credit to purely-numeric
  /// identifiers (e.g. dot-separated part numbers like `1.06482.1000`).
  double _hasDigitScore(String token) {
    return token.contains(RegExp('[0-9]')) ? 1.0 : 0.0;
  }

  double _digitLetterMixScore(String token) {
    final hasDigit = token.contains(RegExp('[0-9]'));
    final hasLetter = token.contains(RegExp('[A-Za-z]'));
    return (hasDigit && hasLetter) ? 1.0 : 0.0;
  }

  double _charClassTransitionScore(String token) {
    if (token.length < 2) return 0;
    var transitions = 0;
    String classOf(String c) {
      if (RegExp('[0-9]').hasMatch(c)) return 'digit';
      if (RegExp('[A-Za-z]').hasMatch(c)) return 'letter';
      return 'other';
    }

    var previousClass = classOf(token[0]);
    for (var i = 1; i < token.length; i++) {
      final currentClass = classOf(token[i]);
      if (currentClass != previousClass) transitions++;
      previousClass = currentClass;
    }
    return (transitions / (token.length - 1)).clamp(0, 1);
  }

  double _unnaturalPhonotacticsScore(String token) {
    final letters = token.replaceAll(RegExp('[^A-Za-z]'), '').toUpperCase();
    // Fewer than 2 letters means there isn't enough of a letter sequence to
    // judge vowel/consonant naturalness - but a token that's mostly or
    // entirely digits/punctuation (e.g. "1.06482.1000", or a single letter
    // prefix like "K123456789") is itself strong evidence of *not* being a
    // natural-language word, so this scores as maximally "unnatural"
    // rather than neutral.
    if (letters.length < 2) return 1;

    const vowels = {'A', 'E', 'I', 'O', 'U'};
    var maxConsonantRun = 0;
    var currentConsonantRun = 0;
    var vowelCount = 0;
    for (final char in letters.split('')) {
      if (vowels.contains(char)) {
        vowelCount++;
        currentConsonantRun = 0;
      } else {
        currentConsonantRun++;
        if (currentConsonantRun > maxConsonantRun) {
          maxConsonantRun = currentConsonantRun;
        }
      }
    }

    final vowelRatio = vowelCount / letters.length;
    // Natural-language words tend to have a vowel ratio around 0.35-0.45
    // and rarely a consonant run longer than ~3.
    final vowelDeviation = (0.4 - vowelRatio).abs().clamp(0, 0.4) / 0.4;
    final consonantRunScore = (maxConsonantRun / 4).clamp(0, 1);

    return ((vowelDeviation + consonantRunScore) / 2).clamp(0, 1);
  }

  double _internalSeparatorScore(String token) {
    if (token.length < 3) return 0;
    final inner = token.substring(1, token.length - 1);
    return inner.contains(RegExp('[-./]')) ? 1.0 : 0.0;
  }

  double _lengthScore(String token) {
    // Sigmoid centered around 8 characters - short tokens (common short
    // words) score low, typical identifier lengths (5-20) score high.
    final length = token.length.toDouble();
    final x = (length - 5) / 3;
    return (1 / (1 + math.exp(-x))).clamp(0, 1);
  }

  double _digitRatioScore(String token) {
    if (token.isEmpty) return 0;
    final digitCount = token.replaceAll(RegExp('[^0-9]'), '').length;
    return (digitCount / token.length).clamp(0, 1);
  }
}
