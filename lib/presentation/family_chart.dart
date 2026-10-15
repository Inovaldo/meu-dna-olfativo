import 'package:flutter/material.dart';
import '../domain/profile.dart';

const familyVisuals = <String, (String, IconData, Color)>{
  'Amadeirado': ('Madeira', Icons.forest_outlined, Color(0xff946539)),
  'Ambarado': (
    'Âmbar',
    Icons.local_fire_department_outlined,
    Color(0xffb47713),
  ),
  'Almiscarado': (
    'Limpeza e conforto',
    Icons.dry_cleaning_outlined,
    Color(0xff627e89),
  ),
  'Floral': ('Flores', Icons.local_florist_outlined, Color(0xffb54b83)),
  'Gourmand': ('Doces e café', Icons.coffee_outlined, Color(0xff966143)),
  'Verde': ('Folhas e grama', Icons.grass, Color(0xff488147)),
  'Cítrico': (
    'Limão e laranja',
    Icons.brightness_5_outlined,
    Color(0xffa08219),
  ),
  'Aquático': ('Chuva e mar', Icons.water_outlined, Color(0xff2589b6)),
  'Aromático': ('Ervas e chás', Icons.spa_outlined, Color(0xff55836d)),
  'Frutado': ('Frutas', Icons.apple_outlined, Color(0xffcc6552)),
  'Especiado': ('Temperos', Icons.whatshot_outlined, Color(0xffb15939)),
  'Terroso': ('Terra', Icons.landscape_outlined, Color(0xff86714f)),
};

/// All families share an absolute 0..100 scale; absence is never drawn as zero.
class FamilyChart extends StatelessWidget {
  final List<FamilyScore> scores;
  const FamilyChart({super.key, required this.scores});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suas tendências por família',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Afinidade estimada de 0 a 100. A marca central indica neutralidade (50). Cada família é independente.',
          ),
          const SizedBox(height: 20),
          for (final f in scores) _FamilyRow(score: f),
          const SizedBox(height: 8),
          const Text(
            'Sem dados = faltam avaliações. Uma barra maior indica maior afinidade, não uma porcentagem do seu perfil.',
          ),
        ],
      ),
    ),
  );
}

class _FamilyRow extends StatelessWidget {
  final FamilyScore score;
  const _FamilyRow({required this.score});
  @override
  Widget build(BuildContext context) {
    final f = score;
    final (label, icon, color) = familyVisuals[f.family]!;
    final description = f.score == null
        ? 'Sem dados'
        : '${f.score!.toStringAsFixed(1).replaceAll('.', ',')} / 100';
    return Semantics(
      label:
          '${f.family}, $label: $description, ${f.evidence} avaliações relacionadas',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 23),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${f.family} · $label',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  f.score == null ? 'Sem dados' : f.score!.round().toString(),
                ),
              ],
            ),
            const SizedBox(height: 7),
            LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                height: 12,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    if (f.score != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width:
                              constraints.maxWidth *
                              f.score!.clamp(0, 100) /
                              100,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    Positioned(
                      left: constraints.maxWidth / 2,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 2,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
