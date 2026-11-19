import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../app_state.dart';
import '../monetization/billing_service.dart';
import '../l10n/tx.dart';
import '../l10n/l10n.dart';
import 'theme.dart';

class PaywallPage extends StatelessWidget {
  const PaywallPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final billing = state.billing;
    return Scaffold(
      appBar: AppBar(title: const Tx('Maqam Tuner Pro')),
      body: ListenableBuilder(
        listenable: Listenable.merge([state, billing]),
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Tx(
                'The tuner stays free: all three tuning systems, every oud tuning, '
                'guitar, violin, reference tones and the main scales. '
                'There are never ads while you are tuning.',
                style: TextStyle(color: Palette.muted),
              ),
              const SizedBox(height: 20),
              if (state.isPro)
                _info(
                  billing.hasPro
                      ? 'Pro is active. Thank you!'
                      : L10n.i.fmt('Pro is unlocked until {0}.', [
                          _fmt(state.rewardedUntil!),
                        ]),
                ),
              _card(
                title: 'Pro',
                bullets: const [
                  'All scales: Saba, Sikah, Nahawand, Hicaz, Kürdi and more',
                  'Ukulele, bass, mandolin and cello presets',
                  'Custom tunings with quarter-tone notes',
                  'No ads anywhere',
                ],
                children: [
                  _buy(
                    billing,
                    BillingService.proLifetimeId,
                    'Pro, pay once',
                    best: true,
                  ),
                  _buy(billing, BillingService.proYearlyId, 'Pro, yearly'),
                ],
              ),
              const SizedBox(height: 14),
              _card(
                title: 'Remove ads',
                bullets: const [
                  'One payment, no subscription',
                  'Keeps the free features free',
                ],
                children: [
                  _buy(billing, BillingService.removeAdsId, 'Pay once'),
                ],
              ),
              const SizedBox(height: 14),
              if (!state.isPro)
                OutlinedButton.icon(
                  onPressed: state.ads.rewardedAvailable
                      ? () async {
                          final ok = await state.claimRewardedPro();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Tx(
                                  ok
                                      ? 'Pro unlocked for 24 hours.'
                                      : 'No reward earned.',
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.play_circle_outline),
                  label: Tx(
                    state.ads.rewardedAvailable
                        ? 'Watch an ad for 24 h of Pro'
                        : 'Ad for 24 h of Pro is loading…',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: billing.restore,
                child: const Tx('Restore purchases'),
              ),
              if (billing.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Tx(
                    billing.message!,
                    style: const TextStyle(color: Palette.brass),
                  ),
                ),
              if (!billing.storeAvailable)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Tx(
                    'Google Play billing is not available right now. '
                    'Purchases work in builds installed from Google Play.',
                    style: TextStyle(color: Palette.muted, fontSize: 13),
                  ),
                ),
              const SizedBox(height: 8),
              const Tx(
                'The yearly plan renews automatically until cancelled in Google Play > '
                'Payments & subscriptions. There is no free-trial trap and no hidden charge.',
                style: TextStyle(color: Palette.muted, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} '
      '${d.day}/${d.month}';

  Widget _info(String text) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Palette.ok.withAlpha(30),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Tx(text),
  );

  Widget _card({
    required String title,
    required List<String> bullets,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tx(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final b in bullets)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check, size: 18, color: Palette.ok),
                  const SizedBox(width: 8),
                  Expanded(child: Tx(b)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buy(
    BillingService billing,
    String id,
    String label, {
    bool best = false,
  }) {
    final ProductDetails? p = billing.products[id];
    final price = p?.price ?? '—';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FilledButton(
        onPressed: (p == null || billing.busy) ? null : () => billing.buy(id),
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          backgroundColor: best ? Palette.brass : Palette.line,
          foregroundColor: best ? Palette.bg : Palette.ivory,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Tx('${L10n.i.t(label)} · $price'),
        ),
      ),
    );
  }
}
