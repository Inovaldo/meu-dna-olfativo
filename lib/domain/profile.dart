import 'dart:math';

class Odor {
  final int id;
  final String name, primaryFamily;
  final Map<String, double> weights;
  const Odor(this.id, this.name, this.primaryFamily, this.weights);
  factory Odor.fromJson(Map<String, dynamic> j) => Odor(
    j['id'] as int,
    j['name'] as String,
    j['primaryFamily'] as String,
    (j['weights'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    ),
  );
}

class Rating {
  final double value;
  final DateTime updatedAt;
  Rating(this.value, this.updatedAt) {
    if (!value.isFinite ||
        value < 0 ||
        value > 10 ||
        value * 2 != (value * 2).roundToDouble()) {
      throw const FormatException('Nota deve ser de 0 a 10, em passos de 0,5.');
    }
  }
  Map<String, dynamic> toJson() => {
    'value': value,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class FamilyScore {
  final String family;
  final double? affinity;
  final int evidence;
  final double coverage, confidence;
  double? get score => affinity == null ? null : 50 + 50 * affinity!;
  const FamilyScore(
    this.family,
    this.affinity,
    this.evidence,
    this.coverage,
    this.confidence,
  );
}

class Recommendation {
  final Odor odor;
  final double? prediction;
  final double confidence;
  final List<String> reasons;
  const Recommendation(
    this.odor,
    this.prediction,
    this.confidence,
    this.reasons,
  );
}

List<FamilyScore> calculate(
  List<Odor> odors,
  List<String> families,
  Map<int, Rating> ratings,
) => families.map((f) {
  double weight = 0, sum = 0;
  int n = 0, total = 0;
  for (final o in odors) {
    final w = o.weights[f] ?? 0;
    if (w <= 0) continue;
    total++;
    final r = ratings[o.id];
    if (r == null) continue;
    n++;
    weight += w;
    sum += w * (r.value - 5) / 5;
  }
  final coverage = total == 0 ? 0.0 : n / total;
  return FamilyScore(
    f,
    weight == 0 ? null : sum / weight,
    n,
    coverage,
    min(1.0, n / 8) * sqrt(coverage),
  );
}).toList();

List<Recommendation> recommend(
  List<Odor> odors,
  List<FamilyScore> scores,
  Map<int, Rating> ratings, {
  Map<int, Rating>? evidenceRatings,
}) {
  final result = <Recommendation>[];
  for (final o in odors.where((o) => !ratings.containsKey(o.id))) {
    double sum = 0, denominator = 0, available = 0;
    for (final f in scores.where((f) => f.affinity != null)) {
      final w = o.weights[f.family] ?? 0;
      sum += w * f.affinity! * f.confidence;
      denominator += w * f.confidence;
      available += w;
    }
    final reasons = odors
        .where(
          (a) =>
              ((evidenceRatings ?? ratings)[a.id]?.value ?? 0) > 5 &&
              scores.any(
                (f) =>
                    (o.weights[f.family] ?? 0) > 0 &&
                    (a.weights[f.family] ?? 0) > 0,
              ),
        )
        .map((a) => a.name)
        .take(2)
        .toList();
    result.add(
      Recommendation(
        o,
        denominator == 0 ? null : (5 + 5 * sum / denominator).clamp(0, 10),
        available == 0 ? 0 : denominator / available,
        reasons,
      ),
    );
  }
  final counts = <String, int>{};
  for (final o in odors.where((o) => ratings.containsKey(o.id))) {
    counts.update(o.primaryFamily, (n) => n + 1, ifAbsent: () => 1);
  }
  result.sort((a, b) {
    var c = (b.prediction ?? -1).compareTo(a.prediction ?? -1);
    if (c == 0) c = b.confidence.compareTo(a.confidence);
    if (c == 0) {
      c = (counts[a.odor.primaryFamily] ?? 0).compareTo(
        counts[b.odor.primaryFamily] ?? 0,
      );
    }
    if (c == 0) c = a.odor.name.compareTo(b.odor.name);
    return c;
  });
  return result;
}
