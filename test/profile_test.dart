import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dnaolfativo/data/profile_store.dart';
import 'package:dnaolfativo/domain/profile.dart';
import 'package:dnaolfativo/presentation/app.dart';
import 'package:dnaolfativo/presentation/report.dart';
import 'package:dnaolfativo/domain/questionnaire.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProfileStore s;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    s = await ProfileStore.load();
  });
  test('catálogo real, IDs e pesos válidos', () {
    expect(s.odors.length, 157);
    expect(s.families.length, 12);
    expect(s.odors.map((o) => o.id).toSet().length, 157);
    for (final o in s.odors) {
      expect(o.name.contains('\uFFFD'), false);
      expect(o.weights.keys.toSet(), s.families.toSet());
      expect(o.weights.values.every((w) => w >= 0 && w <= 3), true);
    }
  });
  test('null não conta e mapa sem dados', () {
    expect(s.ratings, isEmpty);
    expect(s.scores.every((f) => f.score == null && f.evidence == 0), true);
    expect(s.suggestions.every((r) => r.prediction == null), true);
  });
  test('0 conta, 5 é neutro e 7,5 preserva precisão', () async {
    final id = s.odors.first.id;
    await s.setRating(id, 0);
    expect(s.scores.first.score, 0);
    expect(s.scores.first.evidence, 1);
    await s.setRating(id, 5);
    expect(s.scores.first.score, 50);
    expect(s.scores.first.evidence, 1);
    await s.setRating(id, 7.5);
    expect(s.ratings[id]!.value, 7.5);
    expect(s.scores.first.score, 75);
    await s.setRating(id, null);
    expect(s.scores.first.score, isNull);
  });
  test('fórmula ponderada e confiança exatas', () {
    final odors = [
      const Odor(1, 'a', 'F', {'F': 3}),
      const Odor(2, 'b', 'F', {'F': 1}),
      const Odor(3, 'c', 'F', {'F': 2}),
    ];
    final scores = calculate(
      odors,
      ['F'],
      {1: Rating(10, DateTime(2026)), 2: Rating(0, DateTime(2026))},
    );
    expect(scores.single.score, 75);
    expect(scores.single.evidence, 2);
    expect(scores.single.coverage, closeTo(2 / 3, 1e-12));
    expect(scores.single.confidence, closeTo(0.2041241452, 1e-9));
    expect(
      recommend(odors, scores, {
        1: Rating(10, DateTime(2026)),
        2: Rating(0, DateTime(2026)),
      }).single.prediction,
      7.5,
    );
  });
  test('ranking exclui avaliados, determinístico, limites', () async {
    for (final o in s.odors.take(30)) {
      await s.setRating(o.id, o.id.isEven ? 10 : 0);
    }
    expect(s.suggestions.every((r) => !s.ratings.containsKey(r.odor.id)), true);
    expect(
      s.suggestions.map((r) => r.odor.id),
      s.suggestions.map((r) => r.odor.id),
    );
    expect(
      s.scores.every(
        (f) => f.score == null || f.score! >= 0 && f.score! <= 100,
      ),
      true,
    );
    expect(
      s.suggestions.every(
        (r) =>
            r.prediction == null || r.prediction! >= 0 && r.prediction! <= 10,
      ),
      true,
    );
  });
  test('persistência, import/export, limpar e IDs futuros', () async {
    await s.setRating(1, 7.5);
    final backup = s.backup();
    final restored = await ProfileStore.load();
    expect(restored.ratings[1]!.value, 7.5);
    expect(restored.ratings[1]!.updatedAt, s.ratings[1]!.updatedAt);
    await s.clear();
    expect(s.ratings, isEmpty);
    await s.importBackup(backup);
    expect(s.ratings[1]!.value, 7.5);
    expect(s.csv(), contains('7.5'));
    final j = jsonDecode(backup);
    j['ratings']['999'] = {'value': 8.5, 'updatedAt': '2026-01-01T00:00:00Z'};
    await s.importBackup(jsonEncode(j));
    expect(s.ratings[999]!.value, 8.5);
  });
  test('backup inválido é atômico e nota inválida rejeitada', () async {
    await s.setRating(1, 8.5);
    expect(() => Rating(7.3, DateTime.now()), throwsFormatException);
    expect(() => s.importBackup('{"schemaVersion":2}'), throwsFormatException);
    expect(s.ratings[1]!.value, 8.5);
    expect(
      () => s.importBackup(
        '{"schemaVersion":1,"ratings":{"1":{"value":11,"updatedAt":"2026-01-01"}}}',
      ),
      throwsFormatException,
    );
    expect(s.ratings[1]!.value, 8.5);
  });
  test('PDF offline real e multipágina', () async {
    for (final o in s.odors) {
      await s.setRating(o.id, 7.5);
    }
    final bytes = await createReport(s);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    await Directory('artifacts').create();
    await File('artifacts/relatorio-validacao.pdf').writeAsBytes(bytes);
  });
  testWidgets('slider sem nota, 0,5 e limpeza', (t) async {
    double? value;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (c, set) => OdorCard(
              odor: s.odors.first,
              value: value,
              onChanged: (v) => set(() => value = v),
            ),
          ),
        ),
      ),
    );
    expect(value, isNull);
    expect(find.text('Não avaliei'), findsOneWidget);
    final slider = t.widget<Slider>(find.byType(Slider));
    expect(slider.divisions, 20);
    slider.onChanged!(7.5);
    await t.pump();
    expect(value, 7.5);
    expect(find.text('Nota 7,5'), findsOneWidget);
    await t.tap(find.text('Limpar nota'));
    await t.pump();
    expect(value, isNull);
    await t.tap(find.byIcon(Icons.add_circle_outline));
    await t.pump();
    expect(value, 5.5);
  });
  testWidgets('navegação, busca, mapa reativo e confirmação de reset', (
    t,
  ) async {
    await t.pumpWidget(DnaApp(store: s));
    await t.ensureVisible(find.text('Começar'));
    await t.tap(find.text('Começar'));
    await t.pumpAndSettle();
    expect(find.byType(Slider), findsNWidgets(12));
    await t.enterText(find.byType(TextField), 'madeira recém-cortada');
    await t.pumpAndSettle();
    expect(find.byType(Slider), findsOneWidget);
    t.widget<Slider>(find.byType(Slider)).onChanged!(8.5);
    await t.pumpAndSettle();
    await t.tap(find.text('Mapa'));
    await t.pumpAndSettle();
    expect(find.text('85,0 / 100'), findsOneWidget);
    await t.tap(find.byTooltip('Configurações'));
    await t.pumpAndSettle();
    await t.tap(find.text('Limpar tudo'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(s.ratings, isNotEmpty);
    await t.tap(find.text('Limpar tudo'));
    await t.pumpAndSettle();
    await t.tap(find.text('Confirmar'));
    await t.pumpAndSettle();
    expect(s.ratings, isEmpty);
  });
  testWidgets('capturas reais da UI Flutter em tela móvel', (t) async {
    t.view.physicalSize = const Size(412, 915);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.runAsync(() async {
      await (FontLoader(
        'NotoSans',
      )..addFont(rootBundle.load('assets/report.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final key = GlobalKey();
    await t.pumpWidget(
      RepaintBoundary(
        key: key,
        child: DnaApp(store: s),
      ),
    );
    await t.pumpAndSettle();
    Future<void> capture(String name) async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage();
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      await Directory('artifacts/screenshots').create(recursive: true);
      await File(
        'artifacts/screenshots/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      img.dispose();
    }

    await t.runAsync(() => capture('01-inicio'));
    await t.tap(find.text('Rápido · 24 cheiros'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Começar'));
    await t.tap(find.text('Começar'));
    await t.pumpAndSettle();
    await t.runAsync(() => capture('02-questionario'));
    await t.runAsync(() => s.setRating(1, 8.5));
    await t.tap(find.text('Mapa'));
    await t.pumpAndSettle();
    await t.runAsync(() => capture('03-mapa'));
    await t.tap(find.text('Descobertas'));
    await t.pumpAndSettle();
    await t.runAsync(() => capture('04-descobertas'));
    await t.runAsync(() async {
      await s.selectMode(QuestionnaireMode.quick);
      for (var i = 0; i < s.questionnaire.length; i++) {
        await s.setRating(
          s.questionnaire[i].id,
          [3.0, 4.5, 6.0, 7.5, 9.0, 10.0][(i ~/ 2) % 6],
        );
      }
      await s.markUnknown(16);
    });
    t.view.physicalSize = const Size(412, 1550);
    await t.tap(find.text('Mapa'));
    await t.pumpAndSettle();
    await t.runAsync(() => capture('05-resultado-rapido'));
    expect(t.takeException(), isNull);
  });
}
