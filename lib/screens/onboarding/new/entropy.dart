import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:nmobile/components/entropy/touch_entropy_collector.dart';
import 'package:nmobile/components/layout/header.dart';
import 'package:nmobile/components/layout/layout.dart';
import 'package:nmobile/components/text/label.dart';
import 'package:nmobile/components/tip/toast.dart';

class OnboardingEntropyScreen extends StatelessWidget {
  static const String routeName = '/onboarding/new/entropy';

  const OnboardingEntropyScreen({Key? key}) : super(key: key);

  void _onEntropyCollected(BuildContext context, String entropy) {
    final bytes = sha256.convert(utf8.encode(entropy)).bytes;
    final entropyHex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
    final mnemonic = bip39.entropyToMnemonic(entropyHex);
    Toast.show('Entropy collected! Mnemonic: $mnemonic');
  }

  @override
  Widget build(BuildContext context) {
    return Layout(
      headerColor: Colors.transparent,
      header: Header(title: '', backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Label('Generate Recovery Phrase',
                type: LabelType.h2, textAlign: TextAlign.start),
            const SizedBox(height: 12),
            Text(
              'Move your finger randomly in the box to generate secure entropy.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TouchEntropyCollector(
              onEntropyCollected: (e) => _onEntropyCollected(context, e),
              requiredEntropyBits: 1024,
              minDurationMs: 6000,
            ),
            const SizedBox(height: 12),
            Text(
              'Keep drawing until the progress completes.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            SafeArea(child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}
