import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dnaolfativo/data/profile_store.dart';
import 'package:dnaolfativo/domain/perfume.dart';
import 'package:dnaolfativo/domain/profile.dart';
import 'package:dnaolfativo/domain/questionnaire.dart';
import 'package:dnaolfativo/presentation/app.dart';
import 'package:dnaolfativo/presentation/perfume_ranking.dart';
import 'package:dnaolfativo/presentation/report.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Perfume specimen(String id, Map<String, double> weights) => Perfume(
  id: id,
  brand: 'Marca',
  name: id,
  concentration: 'Eau de Parfum',
  profileSummary: 'Teste sintético',
  weights: weights,
  sources: const [],
);
FamilyScore evidence(
  String family,
  double? affinity, [
  double confidence = 1,
]) => FamilyScore(
  family,
  affinity,
  affinity == null ? 0 : 8,
  affinity == null ? 0 : 1,
  affinity == null ? 0 : confidence,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProfileStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await ProfileStore.load();
  });
  test(
    'catálogo real tem 150 versões únicas, 30 marcas, 12 famílias e fontes',
    () {
      expect(store.perfumes.length, 150);
      expect(store.perfumes.map((p) => p.id).toSet().length, 150);
      expect(store.perfumes.map((p) => p.brand).toSet().length, 30);
      expect(
        store.perfumes
            .map((p) => '${p.brand}|${p.name}|${p.concentration}')
            .toSet()
            .length,
        150,
      );
      for (final p in store.perfumes) {
        expect(p.weights.keys.toSet(), store.families.toSet());
        expect(
          p.weights.values.every((w) => w.isFinite && w >= 0 && w <= 3),
          true,
        );
        expect(p.weights.values.any((w) => w > 0), true);
        expect(p.sources, isNotEmpty);
        expect(
          p.sources.every(
            (s) =>
                Uri.parse(s.url).scheme == 'https' &&
                s.accessedAt == '2026-10-15',
          ),
          true,
        );
        expect(
          '${p.brand}${p.name}${p.profileSummary}'.contains('\uFFFD'),
          false,
        );
      }
    },
  );
  test(
    'sem respostas ou só desconhecidos não inventa ranking pessoal',
    () async {
      expect(store.perfumeRanking, isEmpty);
      await store.markUnknown(1);
      expect(store.perfumeRanking, isEmpty);
      await store.setRating(1, 0);
      expect(store.perfumeRanking.length, 20);
      await store.clear();
      expect(store.perfumeRanking, isEmpty);
    },
  );
  test(
    'preferências e rejeições entram na soma com resultado independente',
    () {
      final citrus = specimen('citrus', {'Cítrico': 3});
      final sweet = specimen('sweet', {'Gourmand': 3});
      final mixed = specimen('mixed', {'Cítrico': 3, 'Gourmand': 3});
      final scores = [evidence('Cítrico', 1), evidence('Gourmand', -1)];
      final ranking = rankPerfumes([sweet, mixed, citrus], scores);
      expect(ranking.map((r) => r.perfume.id), ['citrus', 'mixed', 'sweet']);
      expect(ranking.map((r) => r.score), [100, 50, 0]);
      expect(ranking[1].positiveFamilies, ['Cítrico']);
      expect(ranking[1].negativeFamilies, ['Gourmand']);
      expect(ranking[1].explanation, contains('Cítrico'));
    },
  );
  test('confiança atenua e família ausente não vira rejeição', () {
    final citrus = specimen('citrus', {'Cítrico': 3});
    expect(
      rankPerfumes([citrus], [evidence('Cítrico', 1, .1)]).single.score,
      55,
    );
    final partlyKnown = specimen('partial', {'Cítrico': 1, 'Gourmand': 3});
    final result = rankPerfumes(
      [partlyKnown],
      [evidence('Cítrico', 1), evidence('Gourmand', null)],
    ).single;
    expect(result.score, 62.5);
    expect(result.coverage, .25);
    expect(result.negativeFamilies, isEmpty);
    final unknown = rankPerfumes(
      [
        specimen('unknown', {'Floral': 3}),
      ],
      [evidence('Cítrico', 1)],
    ).single;
    expect(unknown.score, isNull);
    expect(unknown.explanation, contains('faltam respostas'));
  });
  test(
    'neutralidade explícita e desempate determinístico sem favorecer ordem de entrada',
    () {
      final a = specimen('a', {'Cítrico': 3}),
          b = specimen('b', {'Cítrico': 3});
      final scores = [evidence('Cítrico', 0)];
      final first = rankPerfumes([b, a], scores),
          second = rankPerfumes([a, b], scores);
      expect(first.map((r) => r.perfume.id), second.map((r) => r.perfume.id));
      expect(
        first.every((r) => r.score == 50 && r.positiveFamilies.isEmpty),
        true,
      );
    },
  );
  test(
    'ranking real tem 20 sem duplicar, muda com perfil e respeita limites',
    () {
      final citrus = [
        for (final f in store.families) evidence(f, f == 'Cítrico' ? 1 : -.5),
      ];
      final gourmand = [
        for (final f in store.families) evidence(f, f == 'Gourmand' ? 1 : -.5),
      ];
      final first = rankPerfumes(store.perfumes, citrus),
          second = rankPerfumes(store.perfumes, gourmand);
      expect(first.length, 20);
      expect(first.map((r) => r.perfume.id).toSet().length, 20);
      expect(first.first.perfume.id, isNot(second.first.perfume.id));
      for (final result in [...first, ...second]) {
        expect(result.score!, inInclusiveRange(0, 100));
        expect(result.confidence, inInclusiveRange(0, 1));
      }
      expect(rankPerfumes(store.perfumes, citrus, limit: 150).length, 150);
    },
  );
  test(
    'ranking segue a versão escolhida, exporta e vai para PDF offline',
    () async {
      await store.setRating(3, 8.5); // Not in the quick selection.
      expect(store.perfumeRanking.length, 20);
      await store.selectMode(QuestionnaireMode.quick);
      expect(store.perfumeRanking, isEmpty);
      await store.setRating(85, 9);
      final data = jsonDecode(store.backup());
      expect((data['perfumeRecommendations'] as List).length, 20);
      expect(data['perfumeAlgorithmVersion'], '1.0.0');
      final bytes = await createReport(store);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      await Directory('artifacts').create();
      await File('artifacts/relatorio-perfumes.pdf').writeAsBytes(bytes);
    },
  );
  testWidgets(
    'resultado oferece atalho e 20 perfumes com fontes e explicações',
    (tester) async {
      await tester.runAsync(() async {
        await store.setRating(85, 9);
        await store.setRating(56, 1);
      });
      await tester.pumpWidget(DnaApp(store: store));
      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ver meus 20 perfumes'));
      await tester.tap(find.text('Ver meus 20 perfumes'));
      await tester.pumpAndSettle();
      expect(find.text('20 perfumes para experimentar'), findsOneWidget);
      expect(find.byType(PerfumeRanking), findsOneWidget);
      expect(find.text('Perfil e fonte'), findsNWidgets(20));
      expect(find.textContaining('Ranking exploratório:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('captura do ranking em tela móvel, com notas sintéticas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      await (FontLoader(
        'NotoSans',
      )..addFont(rootBundle.load('assets/report.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await store.selectMode(QuestionnaireMode.quick);
      for (final odor in store.questionnaire) {
        await store.setRating(
          odor.id,
          ['Cítrico', 'Aquático', 'Verde'].contains(odor.primaryFamily)
              ? 9
              : odor.primaryFamily == 'Gourmand'
              ? 2
              : 5,
        );
      }
    });
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'NotoSans',
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff235f53),
            ),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: PerfumeRanking(
                matches: store.perfumeRanking,
                catalogSize: store.perfumes.length,
                ratedCount: store.ratedCount,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      await Directory('artifacts/screenshots').create(recursive: true);
      await File(
        'artifacts/screenshots/06-ranking-perfumes.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      img.dispose();
    });
    expect(tester.takeException(), isNull);
  });
}
