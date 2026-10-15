import 'dart:io';
import 'dart:ui' as ui;
import 'package:dnaolfativo/data/profile_store.dart';
import 'package:dnaolfativo/presentation/app.dart';
import 'package:dnaolfativo/presentation/perfume_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProfileStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = await ProfileStore.load();
  });
  testWidgets(
    'catálogo acessível sem responder e detalhe não modifica pesquisa',
    (tester) async {
      await tester.pumpWidget(DnaApp(store: store));
      await tester.ensureVisible(find.text('Explorar os 150 perfumes'));
      await tester.tap(find.text('Explorar os 150 perfumes'));
      await tester.pumpAndSettle();
      expect(find.text('150 de 150 perfumes'), findsOneWidget);
      expect(store.ratings, isEmpty);
      await tester.ensureVisible(
        find.text('Ver perfil completo e fontes').first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver perfil completo e fontes').first);
      await tester.pumpAndSettle();
      expect(find.text('Famílias olfativas em destaque'), findsOneWidget);
      expect(find.text('Perfil do perfume'), findsOneWidget);
      expect(find.textContaining('Marcante'), findsWidgets);
      expect(find.textContaining('Cítrico'), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(store.ratings, isEmpty);
      expect(store.unknownOdors, isEmpty);
      expect(store.perfumeRanking, isEmpty);
      expect(find.text('Descubra seu DNA Olfativo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('busca ignora acentos e mantém foco durante digitação', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PerfumeCatalogPage(
          perfumes: store.perfumes,
          families: store.families,
        ),
      ),
    );
    final field = find.byType(TextField);
    await tester.showKeyboard(field);
    for (final text in ['a', 'ar', 'armani si']) {
      tester.testTextInput.enterText(text);
      await tester.pump();
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        true,
      );
    }
    expect(find.text('1 de 150 perfumes'), findsOneWidget);
    expect(find.text('Sì'), findsOneWidget);
    tester.testTextInput.enterText('perfume-inexistente');
    await tester.pump();
    expect(
      find.text(
        'Nenhum perfume encontrado. Tente outro nome ou limpe os filtros.',
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Limpar filtros'));
    await tester.tap(find.text('Limpar filtros'));
    await tester.pump();
    expect(find.text('150 de 150 perfumes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('filtros por marca e família combinam e podem ser limpos', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PerfumeCatalogPage(
          perfumes: store.perfumes,
          families: store.families,
        ),
      ),
    );
    var dropdowns = tester
        .widgetList<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .toList();
    dropdowns[1].onChanged!('Chanel');
    await tester.pump();
    expect(find.text('5 de 150 perfumes'), findsOneWidget);
    dropdowns = tester
        .widgetList<DropdownButtonFormField<String>>(
          find.byType(DropdownButtonFormField<String>),
        )
        .toList();
    dropdowns[0].onChanged!('Cítrico');
    await tester.pump();
    final expected = store.perfumes
        .where((p) => p.brand == 'Chanel' && (p.weights['Cítrico'] ?? 0) > 0)
        .length;
    expect(find.text('$expected de 150 perfumes'), findsOneWidget);
    await tester.ensureVisible(find.text('Limpar filtros'));
    await tester.tap(find.text('Limpar filtros'));
    await tester.pump();
    expect(find.text('150 de 150 perfumes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('catálogo permite alcançar o último dos 150 e abrir seu perfil', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PerfumeCatalogPage(
          perfumes: store.perfumes,
          families: store.families,
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Y'),
      700,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 110,
    );
    await tester.tap(find.text('Y'));
    await tester.pumpAndSettle();
    expect(find.text('Perfil do perfume'), findsOneWidget);
    expect(find.text('Y'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('captura catálogo móvel com famílias e detalhes', (tester) async {
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
          home: PerfumeCatalogPage(
            perfumes: store.perfumes,
            families: store.families,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('artifacts/screenshots').create(recursive: true);
        await File(
          'artifacts/screenshots/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('07-catalogo-perfumes');
    await tester.ensureVisible(find.text('Ver perfil completo e fontes').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver perfil completo e fontes').first);
    await tester.pumpAndSettle();
    await capture('08-perfil-perfume');
    expect(tester.takeException(), isNull);
  });
}
