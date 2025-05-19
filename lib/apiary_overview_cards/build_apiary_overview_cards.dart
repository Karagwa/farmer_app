// import 'package:flutter/material.dart';
// import 'build_overview_card.dart';
// import '/farm_model.dart';

// Widget buildApiaryOverviewCards(Farm farm) {
//   // If hives is null or empty, show zeros
//   int totalHives = farm.hives?.length ?? 0;
//   int activeHives = farm.hives?.where((h) => h.isActive).length ?? 0;
//   int needsAttentionHives =
//       farm.hives?.where((h) => h.needsAttention).length ?? 0;

//   return Container(
//     padding: const EdgeInsets.all(16),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Overview',
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: 16),
//         Row(
//           children: [
//             buildOverviewCard(
//               'Total Hives',
//               totalHives.toString(),
//               Icons.hive,
//               Colors.blue,
//             ),
//             buildOverviewCard(
//               'Active Hives',
//               activeHives.toString(),
//               Icons.check_circle_outline,
//               Colors.green,
//             ),
//             buildOverviewCard(
//               'Needs Attention',
//               needsAttentionHives.toString(),
//               Icons.warning_outlined,
//               Colors.orange,
//             ),
//           ],
//         ),
//       ],
//     ),
//   );
// }
