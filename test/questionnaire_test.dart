import 'dart:convert';
import 'package:dnaolfativo/data/profile_store.dart';
import 'package:dnaolfativo/domain/questionnaire.dart';
import 'package:dnaolfativo/presentation/app.dart';
import 'package:dnaolfativo/presentation/family_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProfileStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await ProfileStore.load();
  });
  test(
    'rápido tem exatamente 2 cheiros reais em cada uma das 12 famílias',
    () async {
      await store.selectMode(QuestionnaireMode.quick);
      expect(store.questionnaire.length, 24);
      expect(store.questionnaire.map((o) => o.id).toSet().length, 24);
      for (final family in store.families) {
        expect(
          store.questionnaire.where((o) => o.primaryFamily == family).length,
          2,
          reason: family,
        );
      }
      expect(
        store.questionnaire.map((o) => o.name),
        containsAll([
          'café passado',
          'chocolate ao leite',
          'limão espremido',
          'roupa recém-lavada',
        ]),
      );
    },
  );
  test(
    'modos preservam notas, mas perfil rápido usa só os 24 itens escolhidos',
    () async {
      await store.setRating(3, 0);
      await store.selectMode(QuestionnaireMode.quick);
      expect(store.ratings[3]!.value, 0);
      expect(store.ratedCount, 0);
      expect(store.scores.every((s) => s.score == null), true);
      for (final odor in store.questionnaire) {
        await store.setRating(odor.id, 7.5);
      }
      expect(store.scores.every((s) => s.score == 75 && s.evidence >= 2), true);
      final reopened = await ProfileStore.load();
      expect(reopened.mode, QuestionnaireMode.quick);
      expect(reopened.ratedCount, 24);
      await reopened.selectMode(QuestionnaireMode.detailed);
      expect(reopened.questionnaire.length, 157);
      expect(reopened.ratedCount, 25);
      expect(reopened.scores.first.score, lessThan(75));
    },
  );
  test(
    'não sei remove nota, persiste e não altera nenhum cálculo nem evidência',
    () async {
      await store.setRating(1, 0);
      await store.markUnknown(1);
      expect(store.ratings.containsKey(1), false);
      expect(store.answeredCount, 1);
      expect(store.ratedCount, 0);
      expect(store.unknownCount, 1);
      expect(
        store.scores.every(
          (f) => f.score == null && f.evidence == 0 && f.confidence == 0,
        ),
        true,
      );
      expect(store.suggestions.any((r) => r.odor.id == 1), false);
      final reopened = await ProfileStore.load();
      expect(reopened.unknownOdors[1], store.unknownOdors[1]);
      final backup = store.backup();
      await store.clear();
      expect(store.unknownOdors, isEmpty);
      await store.importBackup(backup);
      expect(store.unknownCount, 1);
      expect(store.csv(), contains('nao_sei_o_cheiro'));
      await store.setRating(1, 5);
      expect(store.unknownCount, 0);
      expect(store.scores.first.score, 50);
      await store.markUnknown(1);
      await store.setRating(1, null);
      expect(store.answeredCount, 0);
    },
  );
  test(
    'backup antigo migra e backup contraditório é rejeitado sem apagar respostas',
    () async {
      await store.setRating(1, 8.5);
      final old = jsonDecode(store.backup()) as Map<String, dynamic>;
      old.remove('questionnaireMode');
      old.remove('unknownOdors');
      await store.importBackup(jsonEncode(old));
      expect(store.mode, QuestionnaireMode.detailed);
      expect(store.ratings[1]!.value, 8.5);
      old['unknownOdors'] = {'1': '2026-10-15T12:00:00Z'};
      expect(() => store.importBackup(jsonEncode(old)), throwsFormatException);
      expect(store.ratings[1]!.value, 8.5);
      expect(store.unknownOdors, isEmpty);
    },
  );
  testWidgets(
    'escolher rápido, marcar não sei, avançar e concluir no gráfico',
    (tester) async {
      await tester.pumpWidget(DnaApp(store: store));
      await tester.tap(find.text('Rápido · 24 cheiros'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Começar'));
      await tester.tap(find.text('Começar'));
      await tester.pumpAndSettle();
      expect(store.mode, QuestionnaireMode.quick);
      expect(find.text('1 / 2'), findsOneWidget);
      final unknownButton = find.descendant(
        of: find.byType(OdorCard).first,
        matching: find.text('Não sei o cheiro'),
      );
      await tester.ensureVisible(unknownButton);
      await tester.tap(unknownButton);
      await tester.pumpAndSettle();
      expect(store.ratings.containsKey(1), false);
      expect(store.unknownCount, 1);
      expect(find.text('Não sei o cheiro · fora dos cálculos'), findsOneWidget);
      await tester.ensureVisible(find.text('Próximo'));
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.ensureVisible(find.text('Concluir e ver meu resultado'));
      await tester.tap(find.text('Concluir e ver meu resultado'));
      await tester.pumpAndSettle();
      final chart = tester.widget<FamilyChart>(find.byType(FamilyChart));
      expect(chart.scores.length, 12);
      expect(chart.scores.every((f) => f.score == null), true);
      expect(find.text('Suas tendências por família'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'gráfico diferencia ausência, rejeição e neutralidade em tela estreita',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await store.setRating(1, 0);
        await store.setRating(29, 5);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FamilyChart(scores: store.scores),
            ),
          ),
        ),
      );
      expect(store.scores.first.score, 0);
      expect(store.scores[2].score, 50);
      expect(store.scores.where((f) => f.score == null), isNotEmpty);
      expect(find.text('Sem dados'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
