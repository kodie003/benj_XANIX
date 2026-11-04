import 'package:flutter/material.dart';

import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import '../poddy/poddy.dart';

/// About and Privacy. Written as plain lists of sections so the team can update the
/// wording as benj grows: change the text here and bump [infoUpdated].
const infoUpdated = '4 November 2026';

/// "About · Privacy" links, at the bottom of the sign-up screen and in Settings.
class InfoFooter extends StatelessWidget {
  const InfoFooter({super.key});

  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        TextButton(onPressed: () => openInfo(context, about: true), child: const Text('About')),
        const Text('·'),
        TextButton(onPressed: () => openInfo(context, about: false), child: const Text('Privacy')),
      ]);
}

void openInfo(BuildContext context, {required bool about}) => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => about ? const InfoScreen(title: 'About benj', sections: aboutSections) : const InfoScreen(title: 'Privacy', sections: privacySections, showDate: true)),
    );

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key, required this.title, required this.sections, this.showDate = false});
  final String title;
  final List<(String, String)> sections;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
        const Center(child: BenjLogo(height: 44)),
        if (showDate) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Last updated $infoUpdated. We will update this page as benj grows.', style: text.bodySmall, textAlign: TextAlign.center)),
        for (final (heading, body) in sections) ...[
          const SizedBox(height: 18),
          Text(heading, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(body, style: text.bodyLarge?.copyWith(height: 1.45)),
        ],
        const SizedBox(height: 24),
        const Center(child: SupportLink(prefix: 'Write to us: ')),
      ]),
    );
  }
}

const aboutSections = <(String, String)>[
  (
    'What benj does',
    'benj tells a small shop owner what to restock, how much, and when, before they run out. '
        'It turns the stock records you already keep into a low-stock warning and a weekly buying list.',
  ),
  (
    'Who it is for',
    'Small, single-outlet shops selling countable goods (bags, packs, cartons, crates), starting with shops near Ashesi University in Berekuso.',
  ),
  (
    'How it works',
    'You log what you sell, count or buy. benj works out how fast each product sells, warns you before it runs out, '
        'and suggests how much to buy for the week, adjusted for exams, breaks and events. It shows you how close its forecasts were, so you can judge it.',
  ),
  (
    'Who we are',
    'benj is built by a student team at Ashesi University for the XANIX Challenge 2026: '
        'Selikem Avle (team lead), Josephine Yeboah-Kodie, Moyinoluwa Afolabi, Bright Boateng and Emmanuella Afefa Bamezon. '
        'It is an early version that we are testing with shop owners and improving as we go.',
  ),
  ('Credits', poddyCredit),
  ('Contact', 'Questions, ideas or problems? Email $supportEmail.'),
];

const privacySections = <(String, String)>[
  (
    'In short',
    'Your shop records belong to you. Only you can see them. We do not sell them, show you ads, or share them with anyone else. '
        'You can delete your account and all your records at any time.',
  ),
  (
    'What we collect',
    'Your account: your phone number or email address, and your password (stored securely by Google Firebase; we never see it). '
        'If you use Google, your Google name and email.\n'
        'Your shop: the business name, and anything you add in Settings (your name, location, phone, restock day).\n'
        'Your stock records: your products and prices, what you sell, count and buy, with the time, and how you entered it and how many seconds it took.\n'
        'Your calendar events.\n'
        'To keep sign-in safe, Google Firebase may also process technical details such as your IP address and browser.',
  ),
  (
    'What we do not collect',
    'No contacts, no location tracking, no photos, no advertising IDs and no analytics trackers. '
        'Phone numbers are not checked by SMS yet, and we do not send you SMS.',
  ),
  (
    'Why we use it',
    'To give you low-stock warnings, buying lists, stock charts and forecasts. '
        'The time and seconds per log help us learn whether benj is quick enough to use every day; we use them to improve benj.',
  ),
  (
    'Your consent',
    'When you create an account you tick a box agreeing that benj can keep your stock records. '
        "This follows Ghana's Data Protection Act, 2012 (Act 843), which says personal data should be processed with consent and for a clear purpose.",
  ),
  (
    'Where it is stored',
    'In Google Firebase (Cloud Firestore), on Google servers in the United States. The app itself is served by Vercel. '
        'Data is encrypted while it travels between your phone and these services.',
  ),
  (
    'Who can see it',
    'Only you, through your account: our security rules block everyone else. '
        'The benj team can reach the stored data through the Firebase console to fix problems or reset a forgotten password; we only do this when needed. '
        'Google (Firebase) and Vercel process data for us to run the app.',
  ),
  (
    'How long we keep it',
    'As long as you have an account. Settings > Delete account erases your shop, products, logs, events and your login straight away.',
  ),
  (
    'Your rights',
    'Under Act 843 you can ask to see the data we hold about you, ask us to correct it, or ask us to delete it. '
        'You can correct most of it yourself in the app, and delete everything with Delete account.',
  ),
  (
    'Registration',
    "Ghana's Data Protection Act requires organisations that process personal data to register with the Data Protection Commission. "
        'benj is a student prototype in testing; the team will complete registration before benj is offered to the public.',
  ),
  (
    'Questions',
    'Email $supportEmail. You can also use it to ask for a copy of your data, to correct it, or to have it deleted.',
  ),
];

/// "Email benj.support@gmail.com" that opens the phone's email app.
class SupportLink extends StatelessWidget {
  const SupportLink({super.key, this.prefix = '', this.subject = 'benj'});
  final String prefix, subject;

  @override
  Widget build(BuildContext context) => Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (prefix.isNotEmpty) Text(prefix, style: Theme.of(context).textTheme.bodyMedium),
        TextButton(
          onPressed: () => launchUrl(Uri(scheme: 'mailto', path: supportEmail, query: 'subject=${Uri.encodeComponent(subject)}')),
          child: const Text(supportEmail),
        ),
      ]);
}
