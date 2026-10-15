import 'profile.dart';

const perfumeAlgorithmVersion = '1.0.0';

class PerfumeSource {
  final String title, url, accessedAt, type;
  const PerfumeSource(this.title, this.url, this.accessedAt, this.type);
  factory PerfumeSource.fromJson(Map<String, dynamic> json) => PerfumeSource(
    json['title'],
    json['url'],
    json['accessedAt'],
    json['type'],
  );
}

class Perfume {
  final String id, brand, name, concentration, profileSummary;
  final Map<String, double> weights;
  final List<PerfumeSource> sources;
  const Perfume({
    required this.id,
    required this.brand,
    required this.name,
    required this.concentration,
    required this.profileSummary,
    required this.weights,
    required this.sources,
  });
  factory Perfume.fromJson(Map<String, dynamic> json) => Perfume(
    id: json['id'],
    brand: json['brand'],
    name: json['name'],
    concentration: json['concentration'],
    profileSummary: json['profileSummary'],
    weights: (json['weights'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    ),
    sources: (json['sources'] as List)
        .map((s) => PerfumeSource.fromJson(s))
        .toList(),
  );
  List<String> get mainFamilies {
    final entries = weights.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c == 0 ? a.key.compareTo(b.key) : c;
      });
    return entries.take(3).map((e) => e.key).toList();
  }
}

class PerfumeMatch {
  final Perfume perfume;
  final double? score;
  final double confidence, coverage;
  final List<String> positiveFamilies, negativeFamilies;
  const PerfumeMatch({
    required this.perfume,
    required this.score,
    required this.confidence,
    required this.coverage,
    required this.positiveFamilies,
    required this.negativeFamilies,
  });
  String get explanation => score == null
      ? 'Ainda faltam respostas nas famílias deste perfume.'
      : positiveFamilies.isEmpty
      ? negativeFamilies.isEmpty
            ? 'As notas relacionadas indicam neutralidade; ainda não há uma preferência positiva clara.'
            : 'É uma comparação relativa entre os perfumes da base; há famílias que você tende a evitar.'
      : 'Combina com sua afinidade por ${positiveFamilies.join(' e ')}.';
}

/// Absolute, confidence-shrunk affinity index, not a probability of liking.
/// Missing family information contributes no signal, never aversion.
/// Full perfume weight stays in the denominator: a single known accord cannot
/// erase large unknown or disliked facets of a perfume.
List<PerfumeMatch> rankPerfumes(
  List<Perfume> perfumes,
  List<FamilyScore> scores, {
  int limit = 20,
}) {
  if (limit <= 0 ||
      !scores.any((f) => f.affinity != null && f.confidence > 0)) {
    return [];
  }
  final byFamily = {for (final s in scores) s.family: s};
  final result = <PerfumeMatch>[];
  for (final perfume in perfumes) {
    double total = 0, known = 0, confidenceMass = 0, signal = 0;
    final positives = <(String, double)>[], negatives = <(String, double)>[];
    for (final entry in perfume.weights.entries.where((e) => e.value > 0)) {
      final w = entry.value;
      total += w;
      final f = byFamily[entry.key];
      if (f?.affinity == null || f!.confidence <= 0) continue;
      known += w;
      confidenceMass += w * f.confidence;
      final contribution = w * f.affinity! * f.confidence;
      signal += contribution;
      if (contribution > 0) positives.add((entry.key, contribution));
      if (contribution < 0) negatives.add((entry.key, -contribution));
    }
    int compare((String, double) a, (String, double) b) {
      final c = b.$2.compareTo(a.$2);
      return c == 0 ? a.$1.compareTo(b.$1) : c;
    }

    positives.sort(compare);
    negatives.sort(compare);
    result.add(
      PerfumeMatch(
        perfume: perfume,
        score: known == 0 || total == 0
            ? null
            : (50 + 50 * signal / total).clamp(0, 100),
        confidence: total == 0 ? 0 : confidenceMass / total,
        coverage: total == 0 ? 0 : known / total,
        positiveFamilies: positives.take(2).map((e) => e.$1).toList(),
        negativeFamilies: negatives.take(2).map((e) => e.$1).toList(),
      ),
    );
  }
  result.sort((a, b) {
    // Evidence-backed comparisons precede exploratory, unknown profiles.
    var c = (b.score ?? -1).compareTo(a.score ?? -1);
    if (c == 0) c = b.confidence.compareTo(a.confidence);
    if (c == 0) c = b.coverage.compareTo(a.coverage);
    if (c == 0) c = a.perfume.brand.compareTo(b.perfume.brand);
    if (c == 0) c = a.perfume.name.compareTo(b.perfume.name);
    if (c == 0) c = a.perfume.concentration.compareTo(b.perfume.concentration);
    if (c == 0) c = a.perfume.id.compareTo(b.perfume.id);
    return c;
  });
  return result.take(limit).toList();
}
