import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../data/profile_store.dart';

Future<Uint8List> createReport(ProfileStore s) async {
  final font = pw.Font.ttf(await rootBundle.load('assets/report.ttf'));
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: font),
  );
  final now = DateTime.now();
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      footer: (c) =>
          pw.Text('Meu DNA Olfativo • ${c.pageNumber}/${c.pagesCount}'),
      build: (_) => [
        pw.Header(level: 0, text: 'Meu DNA Olfativo'),
        pw.Text(
          '${now.day}/${now.month}/${now.year} • Algoritmo 1.0.0 • ${s.ratedCount} notas nesta versão',
        ),
        pw.Text(
          '${s.questionnaire.length} cheiros na versão escolhida • ${s.unknownCount} desconhecidos fora dos cálculos',
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Afinidades estimadas. Método heurístico sem validação científica. Confiança não é probabilidade de gostar.',
        ),
        pw.Header(level: 1, text: 'Seu mapa'),
        pw.Text(
          'Afinidade estimada: 0 a 100. 50 indica neutralidade. Sem dados não significa rejeição.',
        ),
        pw.SizedBox(height: 12),
        for (final f in s.scores)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              children: [
                pw.SizedBox(
                  width: 94,
                  child: pw.Text(
                    f.family,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
                pw.SizedBox(
                  width: 270,
                  height: 10,
                  child: pw.Stack(
                    children: [
                      pw.Container(
                        width: 270,
                        height: 10,
                        color: PdfColors.grey200,
                      ),
                      if (f.score != null)
                        pw.Container(
                          width: 270 * f.score! / 100,
                          height: 10,
                          color: PdfColors.teal700,
                        ),
                      pw.Positioned(
                        left: 135,
                        top: 0,
                        child: pw.Container(
                          width: 1,
                          height: 10,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Text(
                  f.score == null
                      ? 'Sem dados'
                      : f.score!.toStringAsFixed(1).replaceAll('.', ','),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        pw.SizedBox(height: 12),
        pw.TableHelper.fromTextArray(
          headers: [
            'Família',
            'Afinidade /100',
            'Evidências',
            'Cobertura',
            'Confiança',
          ],
          data: [
            for (final f in s.scores)
              [
                f.family,
                f.score?.toStringAsFixed(1).replaceAll('.', ',') ?? 'Sem dados',
                '${f.evidence}',
                '${(f.coverage * 100).round()}%',
                '${(f.confidence * 100).round()}%',
              ],
          ],
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
        pw.Header(level: 1, text: 'Descobertas'),
        pw.Text(
          s.ratedCount < 8
              ? 'Sugestões exploratórias: avalie ao menos 8 cheiros.'
              : 'Afinidades estimadas, sujeitas a novas avaliações.',
        ),
        for (final r in s.suggestions.take(10))
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(
              '${r.odor.name}: ${r.prediction?.toStringAsFixed(1) ?? 'explorar'}',
            ),
          ),
        pw.Header(level: 1, text: '20 perfumes para experimentar'),
        pw.Text(
          'Ranking entre ${s.perfumes.length} perfumes internacionais. Índice de afinidade, não probabilidade. Perfis e pesos editoriais; experimente na pele. Algoritmo de perfumes 1.0.0.',
        ),
        if (s.perfumeRanking.isEmpty)
          pw.Text('Avalie cheiros para gerar seu ranking personalizado.'),
        if (s.ratedCount < 8 && s.perfumeRanking.isNotEmpty)
          pw.Text('Ranking exploratório: ainda há poucas respostas.'),
        for (var i = 0; i < s.perfumeRanking.length; i++) ...[
          pw.SizedBox(height: 10),
          pw.Text(
            '${i + 1}. ${s.perfumeRanking[i].perfume.brand} · ${s.perfumeRanking[i].perfume.name} · ${s.perfumeRanking[i].perfume.concentration}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.Text(
            s.perfumeRanking[i].score == null
                ? 'Ainda sem evidências para comparação'
                : 'Afinidade: ${s.perfumeRanking[i].score!.toStringAsFixed(1).replaceAll('.', ',')} / 100 · confiança ${(s.perfumeRanking[i].confidence * 100).round()}%',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            s.perfumeRanking[i].explanation,
            style: const pw.TextStyle(fontSize: 10),
          ),
          if (s.perfumeRanking[i].negativeFamilies.isNotEmpty)
            pw.Text(
              'Atenção: ${s.perfumeRanking[i].negativeFamilies.join(', ')}.',
              style: const pw.TextStyle(fontSize: 10),
            ),
          pw.Text(
            'Fonte: ${s.perfumeRanking[i].perfume.sources.first.url}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
        pw.Header(level: 1, text: 'Suas avaliações'),
        for (final o in s.questionnaire.where(
          (o) => s.ratings.containsKey(o.id),
        ))
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Text(
              '${o.name}: ${s.ratings[o.id]!.value.toStringAsFixed(1).replaceAll('.', ',')}',
            ),
          ),
        if (s.unknownCount > 0)
          pw.Header(level: 1, text: 'Não sei o cheiro — fora dos cálculos'),
        for (final o in s.questionnaire.where(
          (o) => s.unknownOdors.containsKey(o.id),
        ))
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Text(o.name),
          ),
      ],
    ),
  );
  return doc.save();
}
