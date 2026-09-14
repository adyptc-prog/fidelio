import 'package:flutter/material.dart';

import '../../domain/value_objects/customer_rank.dart';

IconData rankIcon(CustomerRank rank) {
  return switch (rank) {
    CustomerRank.entry => Icons.person_outline,
    CustomerRank.bronze => Icons.military_tech,
    CustomerRank.silver => Icons.workspace_premium,
    CustomerRank.gold => Icons.emoji_events,
    CustomerRank.platinum => Icons.diamond,
    CustomerRank.vip => Icons.star,
  };
}

Color rankColor(CustomerRank rank) {
  return switch (rank) {
    CustomerRank.entry => Colors.grey,
    CustomerRank.bronze => const Color(0xFFCD7F32),
    CustomerRank.silver => const Color(0xFFB0B0B8),
    CustomerRank.gold => const Color(0xFFD6AA2F),
    CustomerRank.platinum => const Color(0xFF8FA6B2),
    CustomerRank.vip => const Color(0xFF8B5BC0),
  };
}

String rankLabel(CustomerRank rank) {
  return switch (rank) {
    CustomerRank.entry => 'Entry',
    CustomerRank.bronze => 'Bronze',
    CustomerRank.silver => 'Silver',
    CustomerRank.gold => 'Gold',
    CustomerRank.platinum => 'Platinum',
    CustomerRank.vip => 'VIP',
  };
}

class CustomerRankBadge extends StatelessWidget {
  const CustomerRankBadge({required this.rank, this.iconSize = 20, super.key});

  final CustomerRank rank;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: rankLabel(rank),
      child: Icon(rankIcon(rank), color: rankColor(rank), size: iconSize),
    );
  }
}
