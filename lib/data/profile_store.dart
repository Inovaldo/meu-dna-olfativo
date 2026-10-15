import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/profile.dart';
import '../domain/questionnaire.dart';
import '../domain/perfume.dart';

class ProfileStore extends ChangeNotifier {
  final SharedPreferences prefs;
  final List<Odor> odors;
  final List<String> families;
  final int catalogVersion;
  final List<Perfume> perfumes;
  final int perfumeCatalogVersion;
  final Map<int, Rating> _ratings = {};
  final Map<int, DateTime> _unknown = {};
  Map<int, DateTime> get unknownOdors => Map.unmodifiable(_unknown);
  QuestionnaireMode _mode = QuestionnaireMode.detailed;
  QuestionnaireMode get mode => _mode;
  List<Odor> get questionnaire => questionnaireOdors(odors, mode);
  Map<int, Rating> get activeRatings => {
    for (final o in questionnaire)
      if (_ratings.containsKey(o.id)) o.id: _ratings[o.id]!,
  };
  int get ratedCount => activeRatings.length;
  int get unknownCount =>
      questionnaire.where((o) => _unknown.containsKey(o.id)).length;
  int get answeredCount => ratedCount + unknownCount;
  Map<int, Rating> get ratings => Map.unmodifiable(_ratings);
  Future<void> _pending = Future.value();
  ProfileStore(
    this.prefs,
    this.odors,
    this.families,
    this.catalogVersion,
    this.perfumes,
    this.perfumeCatalogVersion,
  );
  static Future<ProfileStore> load() async {
    final j =
        jsonDecode(await rootBundle.loadString('assets/odores_157.json'))
            as Map<String, dynamic>;
    final perfumeJson =
        jsonDecode(await rootBundle.loadString('assets/perfumes_150.json'))
            as Map<String, dynamic>;
    final store = ProfileStore(
      await SharedPreferences.getInstance(),
      (j['odors'] as List).map((o) => Odor.fromJson(o)).toList(),
      List<String>.from(j['families']),
      j['version'],
      (perfumeJson['perfumes'] as List)
          .map((p) => Perfume.fromJson(p))
          .toList(),
      perfumeJson['version'],
    );
    final saved = store.prefs.getString('profile_v1');
    if (saved != null) store._restore(store._parseBackup(saved));
    return store;
  }

  // Keep coverage relative to the full catalog so a quick test does not inflate confidence.
  List<FamilyScore> get scores => calculate(odors, families, activeRatings);
  List<PerfumeMatch> get perfumeRanking => rankPerfumes(perfumes, scores);
  List<Recommendation> get suggestions => recommend(
    odors,
    scores,
    ratings,
    evidenceRatings: activeRatings,
  ).where((r) => !_unknown.containsKey(r.odor.id)).toList();
  Future<void> selectMode(QuestionnaireMode mode) {
    _mode = mode;
    return _save();
  }

  Future<void> markUnknown(int id) {
    if (!odors.any((o) => o.id == id)) {
      throw const FormatException('Cheiro desconhecido');
    }
    _ratings.remove(id);
    _unknown[id] = DateTime.now().toUtc();
    return _save();
  }

  Future<void> setRating(int id, double? value) {
    if (!odors.any((o) => o.id == id)) {
      throw const FormatException('Cheiro desconhecido');
    }
    final rating = value == null ? null : Rating(value, DateTime.now().toUtc());
    _unknown.remove(id);
    if (value == null) {
      _ratings.remove(id);
    } else {
      _ratings[id] = rating!;
    }
    return _save();
  }

  Future<void> clear() async {
    _ratings.clear();
    _unknown.clear();
    _mode = QuestionnaireMode.detailed;
    await _save();
    for (final key in [
      'questionnaire_page',
      'questionnaire_page_quick',
      'questionnaire_page_detailed',
    ]) {
      if (!await prefs.remove(key)) {
        throw StateError('Não foi possível limpar o progresso da pesquisa');
      }
    }
  }

  Future<void> _save() {
    final snapshot = backup();
    notifyListeners();
    final write = _pending.then((_) async {
      if (!await prefs.setString('profile_v1', snapshot)) {
        throw StateError('Não foi possível salvar');
      }
    });
    _pending = write.catchError((Object _) {});
    return write;
  }

  Map<String, dynamic> exportData() => {
    'schemaVersion': 1,
    'catalogVersion': catalogVersion,
    'algorithmVersion': '1.0.0',
    'perfumeAlgorithmVersion': perfumeAlgorithmVersion,
    'perfumeCatalogVersion': perfumeCatalogVersion,
    'perfumeRecommendations': [
      for (final r in perfumeRanking)
        {
          'id': r.perfume.id,
          'brand': r.perfume.brand,
          'name': r.perfume.name,
          'concentration': r.perfume.concentration,
          'affinityIndex': r.score,
          'confidence': r.confidence,
          'coverage': r.coverage,
          'positiveFamilies': r.positiveFamilies,
          'negativeFamilies': r.negativeFamilies,
        },
    ],
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'ratings': _ratings.map((k, v) => MapEntry('$k', v.toJson())),
    'questionnaireMode': mode.name,
    'unknownOdors': _unknown.map((k, v) => MapEntry('$k', v.toIso8601String())),
    'scores': [
      for (final s in scores)
        {
          'family': s.family,
          'score': s.score,
          'evidence': s.evidence,
          'coverage': s.coverage,
          'confidence': s.confidence,
        },
    ],
  };
  String backup() => const JsonEncoder.withIndent('  ').convert(exportData());
  Map<int, Rating> decodeBackup(String source) => _parseBackup(source).ratings;

  ({
    Map<int, Rating> ratings,
    Map<int, DateTime> unknown,
    QuestionnaireMode mode,
  })
  _parseBackup(String source) {
    final j = jsonDecode(source) as Map<String, dynamic>;
    if (j['schemaVersion'] != 1) {
      throw const FormatException('Versão de backup incompatível');
    }
    final result = <int, Rating>{};
    for (final e in (j['ratings'] as Map<String, dynamic>).entries) {
      final id = int.parse(e.key);
      final item = e.value as Map<String, dynamic>;
      final rating = Rating(
        (item['value'] as num).toDouble(),
        DateTime.parse(item['updatedAt']),
      );
      // Keep unknown IDs so a future catalog migration never discards answers.
      result[id] = rating;
    }
    final unknown = <int, DateTime>{};
    for (final e
        in (j['unknownOdors'] as Map<String, dynamic>? ?? {}).entries) {
      final id = int.parse(e.key);
      if (result.containsKey(id)) {
        throw const FormatException(
          'Um cheiro não pode ter nota e ser desconhecido ao mesmo tempo.',
        );
      }
      unknown[id] = DateTime.parse(e.value as String);
    }
    final modeName = j['questionnaireMode'];
    if (modeName != null && modeName != 'quick' && modeName != 'detailed') {
      throw const FormatException('Modo de questionário inválido');
    }
    return (
      ratings: result,
      unknown: unknown,
      mode: modeName == 'quick'
          ? QuestionnaireMode.quick
          : QuestionnaireMode.detailed,
    );
  }

  void _restore(
    ({
      Map<int, Rating> ratings,
      Map<int, DateTime> unknown,
      QuestionnaireMode mode,
    })
    parsed,
  ) {
    _ratings
      ..clear()
      ..addAll(parsed.ratings);
    _unknown
      ..clear()
      ..addAll(parsed.unknown);
    _mode = parsed.mode;
  }

  Future<void> importBackup(String source) {
    final parsed = _parseBackup(source);
    _restore(parsed);
    return _save();
  }

  String csv() {
    String quote(String s) => '"${s.replaceAll('"', '""')}"';
    final metadata =
        '1.0.0,$catalogVersion,${DateTime.now().toUtc().toIso8601String()}';
    return '\uFEFFtipo,id,nome,nota,atualizado,evidencias,cobertura,confianca,algoritmo,catalogo,exportado_em,status,questionario\r\n${[for (final o in odors) 'odor,${o.id},${quote(o.name)},${ratings[o.id]?.value ?? ''},${ratings[o.id]?.updatedAt.toIso8601String() ?? _unknown[o.id]?.toIso8601String() ?? ''},,,,$metadata,${_unknown.containsKey(o.id)
          ? 'nao_sei_o_cheiro'
          : ratings.containsKey(o.id)
          ? 'avaliado'
          : 'sem_resposta'},${mode.name}', for (final s in scores) 'familia,,${quote(s.family)},${s.score ?? ''},,${s.evidence},${s.coverage},${s.confidence},$metadata,,${mode.name}'].join('\r\n')}';
  }
}
