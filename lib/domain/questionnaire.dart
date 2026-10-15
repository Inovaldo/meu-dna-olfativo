import 'profile.dart';

enum QuestionnaireMode { quick, detailed }

// Two familiar examples per primary family, selected from the original catalog.
// IDs, names and weights remain unchanged. The full catalog stays available.
const quickOdorIds = <int>[
  1, 2, // wood, pencil
  16, 20, // incense, scented candle
  29, 30, // soap, clean laundry
  42, 50, // rose, bouquet
  56, 59, // coffee, milk chocolate
  71, 72, // cut grass, crushed leaves
  85, 86, // lemon, orange peel
  97, 98, // rain, sea breeze
  113, 114, // chamomile tea, mint tea
  121, 125, // strawberry, pineapple
  134, 136, // pepper, cinnamon
  146, 153, // wet earth, potted soil
];

List<Odor> questionnaireOdors(List<Odor> catalog, QuestionnaireMode mode) =>
    mode == QuestionnaireMode.detailed
    ? catalog
    : [for (final id in quickOdorIds) catalog.firstWhere((o) => o.id == id)];
