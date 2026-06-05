import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/app_settings_providers.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../app/providers/client_wallet_providers.dart';
import '../../../domain/entities/wallet_card.dart';
import '../../../domain/value_objects/card_status.dart';
import '../../../presentation/layouts/section_shell.dart';

class ClientCardsScreen extends ConsumerWidget {
  const ClientCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(clientWalletCardsProvider);
    final settings =
        ref.watch(appSettingsControllerProvider).valueOrNull ??
        const AppSettings(selectedMode: null);

    return SectionShell(
      title: 'My Cards',
      child: cards.when(
        data: (cards) {
          if (cards.isEmpty) {
            return const Center(
              child: Text(
                'There are no cards in the wallet. Import a card received from a business.',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (settings.clientCardsViewMode == ClientCardsViewMode.grid) {
            return GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) =>
                  _WalletGridCard(card: cards[index]),
            );
          }

          return ListView.separated(
            itemCount: cards.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _WalletPass(card: cards[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Could not load wallet: $error')),
      ),
    );
  }
}

class _WalletGridCard extends StatelessWidget {
  const _WalletGridCard({required this.card});

  final WalletCard card;

  @override
  Widget build(BuildContext context) {
    final colors = _cardColors(card);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push('/client/cards/${card.walletCardId}'),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            boxShadow: [
              BoxShadow(
                color: colors.last.withValues(alpha: 0.24),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_businessIcon(card), color: Colors.white, size: 32),
                    const SizedBox(width: 10),
                    Expanded(child: _BusinessHeader(card: card, compact: true)),
                    const SizedBox(width: 8),
                    _StatusBadge(status: card.status),
                  ],
                ),
                const Spacer(),
                Text(
                  card.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                _PassInfo(label: _detailLabel(card), value: _detailValue(card)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WalletPass extends StatelessWidget {
  const _WalletPass({required this.card});

  final WalletCard card;

  @override
  Widget build(BuildContext context) {
    final colors = _cardColors(card);

    return AspectRatio(
      aspectRatio: 1.68,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push('/client/cards/${card.walletCardId}'),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.30),
                  blurRadius: 26,
                  offset: const Offset(0, 14),
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_businessIcon(card), color: Colors.white, size: 38),
                      const SizedBox(width: 12),
                      Expanded(child: _BusinessHeader(card: card)),
                      const SizedBox(width: 8),
                      _StatusBadge(status: card.status),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    card.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _PassInfo(
                          label: _detailLabel(card),
                          value: _detailValue(card),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _PassInfo(
                        label: 'Valid',
                        value: _dateOrDash(card.validUntil),
                        alignEnd: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BusinessHeader extends StatelessWidget {
  const _BusinessHeader({required this.card, this.compact = false});

  final WalletCard card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          card.businessName ?? card.businessId,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style:
              (compact
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.headlineSmall)
                  ?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
        ),
        if ((card.businessDomain ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            card.businessDomain!.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (compact
                        ? Theme.of(context).textTheme.labelMedium
                        : Theme.of(context).textTheme.titleMedium)
                    ?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                    ),
          ),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final CardStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
      ),
      child: Text(
        _statusLabel(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PassInfo extends StatelessWidget {
  const _PassInfo({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

List<Color> _cardColors(WalletCard card) {
  if (card.status != CardStatus.active) {
    return const [Color(0xFF58616B), Color(0xFF171C22)];
  }
  if (card.businessAccentColor != null) {
    final accent = Color(card.businessAccentColor!);
    return [
      Color.lerp(accent, Colors.white, 0.16)!,
      accent,
      Color.lerp(accent, Colors.black, 0.48)!,
    ];
  }
  if (card.cardType == 'loyalty') {
    return const [Color(0xFFE0B943), Color(0xFF8A6418), Color(0xFF2B2110)];
  }
  return const [Color(0xFF16705F), Color(0xFF0B3B34), Color(0xFF061B18)];
}

IconData _businessIcon(WalletCard card) {
  return switch (card.businessSymbol) {
    'robotics' => Icons.precision_manufacturing,
    'dance' => Icons.music_note,
    'swimming' => Icons.pool,
    'fitness' => Icons.fitness_center,
    'beauty' => Icons.spa,
    'coffee' => Icons.local_cafe,
    'restaurant' => Icons.restaurant,
    'education' => Icons.school,
    'medical' => Icons.medical_services,
    'auto' => Icons.directions_car,
    'retail' => Icons.shopping_bag,
    _ => card.cardType == 'loyalty' ? Icons.loyalty : Icons.card_membership,
  };
}

String _detailLabel(WalletCard card) {
  if (card.cardType == 'loyalty') {
    return card.entriesRemaining == null ? 'Type' : 'Progress';
  }
  return 'Entries';
}

String _detailValue(WalletCard card) {
  if (card.cardType == 'loyalty') {
    if (card.entriesRemaining == null || card.entriesTotal == null) {
      return 'Loyalty';
    }
    final current = card.entriesTotal! - card.entriesRemaining!;
    return '$current/${card.entriesTotal}';
  }
  if (card.entriesRemaining == null) {
    return '-';
  }
  return card.entriesTotal == null
      ? card.entriesRemaining.toString()
      : '${card.entriesRemaining}/${card.entriesTotal}';
}

String _dateOrDash(DateTime? value) {
  if (value == null) {
    return '-';
  }
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _statusLabel(CardStatus status) {
  return switch (status) {
    CardStatus.active => 'active',
    CardStatus.expired => 'expired',
    CardStatus.suspended => 'suspended',
    CardStatus.cancelled => 'cancelled',
    CardStatus.draft => 'draft',
    CardStatus.revoked => 'revoked',
  };
}
