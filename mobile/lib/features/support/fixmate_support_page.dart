import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../settings/locale_cubit.dart';

import '../../l10n/fixmate_i18n.dart';

enum SupportSection { contacts, help, about }

/// Role-independent support hub: all content is available without privileged
/// Supabase queries, so it is safe on a public sign-in screen.
class FixMateSupportPage extends StatefulWidget {
  const FixMateSupportPage({
    super.key,
    this.initialSection = SupportSection.help,
  });
  final SupportSection initialSection;

  @override
  State<FixMateSupportPage> createState() => _FixMateSupportPageState();
}

class _FixMateSupportPageState extends State<FixMateSupportPage> {
  late SupportSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: FixMateText('Copied to clipboard'),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const FixMateText('Support center'),
      actions: const [FixMateLanguageButton()],
    ),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: ListView(padding: const EdgeInsets.all(18), children: [
        SegmentedButton<SupportSection>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: SupportSection.contacts,
              icon: Icon(Icons.contact_mail_outlined),
              label: FixMateText('Contacts')),
            ButtonSegment(
              value: SupportSection.help,
              icon: Icon(Icons.help_outline),
              label: FixMateText('Help')),
            ButtonSegment(
              value: SupportSection.about,
              icon: Icon(Icons.info_outline),
              label: FixMateText('About')),
          ],
          selected: {_section},
          onSelectionChanged: (value) =>
            setState(() => _section = value.single),
        ),
        const SizedBox(height: 20),
        switch (_section) {
          SupportSection.contacts => _contacts(context),
          SupportSection.help => _help(context),
          SupportSection.about => _about(context),
        },
      ]),
    )),
  );

  Widget _heading(BuildContext context, String title, IconData icon) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(fmTr(context, title),
            style: Theme.of(context).textTheme.titleLarge)),
        ]),
      );

  Widget _contacts(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(context, 'Dormitory contacts', Icons.contact_phone_outlined),
      const FixMateText('Contact your dormitory administration for building-specific assistance.'),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FixMateText('Kauno kolegija accommodation services',
            style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const FixMateText('The contact below is published by Kauno kolegija; FixMate is not its official support channel.'),
          const SizedBox(height: 14),
          const SelectableText('apgyvendinimas@kaunokolegija.lt'),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _copy('apgyvendinimas@kaunokolegija.lt'),
            icon: const Icon(Icons.copy_outlined),
            label: const FixMateText('Copy email')),
          const SizedBox(height: 12),
          const FixMateText('Official accommodation information'),
          const SizedBox(height: 6),
          const SelectableText('https://kaunokolegija.lt/english/dormitories/'),
          OutlinedButton.icon(
            onPressed: () => _copy('https://kaunokolegija.lt/english/dormitories/'),
            icon: const Icon(Icons.link_outlined),
            label: const FixMateText('Copy website')),
        ],
      ))),
      const SizedBox(height: 16),
      const FixMateText('Use this app for routine maintenance requests. For emergencies, contact the relevant emergency services.'),
    ],
  );

  Widget _help(BuildContext context) {
    const questions = <(String, String)>[
      ('How do I report a problem?',
       'Open New Report, select a category, describe the issue and submit it.'),
      ('How can I follow my report?',
       'Open My Reports, then choose a report to see its current status and details.'),
      ('Can I add a photo?',
       'You can attach a photo when submitting a report or from its details when available.'),
      ('How do I change my profile?',
       'Open Profile and choose Edit personal information. Account roles cannot be changed there.'),
      ('How do I reset my password?',
       'On the sign-in screen, select Forgot password and use the link sent to your email.'),
      ('What do the statuses mean?',
       'New means the report was submitted; In progress means work has started; Resolved means the work is complete.'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading(context, 'Help and frequently asked questions',
            Icons.help_outline),
        for (final item in questions)
          Card(child: ExpansionTile(
            title: FixMateText(item.$1),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [Align(alignment: Alignment.centerLeft,
              child: FixMateText(item.$2))],
          )),
      ],
    );
  }

  Widget _about(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading(context, 'About FixMate', Icons.info_outline),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.home_repair_service_outlined,
            size: 48, color: Color(0xFF127F76)),
          const SizedBox(height: 12),
          FixMateText('Smart dorm maintenance',
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          const FixMateText('FixMate helps residents report dormitory maintenance issues and follow their progress.'),
        ],
      ))),
      const SizedBox(height: 12),
      const _AboutRole('Residents',
          'Residents submit reports and follow updates.',
          Icons.home_outlined),
      const _AboutRole('Maintenance staff',
          'Maintenance staff claim assigned work and update progress.',
          Icons.handyman_outlined),
      const _AboutRole('Moderators',
          'Moderators review new submissions.',
          Icons.fact_check_outlined),
      const _AboutRole('Administrators',
          'Administrators oversee reports, people and categories.',
          Icons.admin_panel_settings_outlined),
      const SizedBox(height: 14),
      _heading(context, 'Data privacy', Icons.shield_outlined),
      const FixMateText('Your account can only access information permitted by its role.'),
      const SizedBox(height: 12),
      const FixMateText('Version'),
      const Text('0.1.0'),
    ],
  );
}

class _AboutRole extends StatelessWidget {
  const _AboutRole(this.heading, this.description, this.icon);
  final String heading;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: FixMateText(heading),
      subtitle: FixMateText(description),
    ),
  );
}

class FixMateSupportMenu extends StatelessWidget {
  const FixMateSupportMenu({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<SupportSection>(
    key: const Key('app_support_menu'),
    tooltip: fmTr(context, 'Support center'),
    icon: const Icon(Icons.help_outline),
    onSelected: (section) => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FixMateSupportPage(initialSection: section),
      ),
    ),
    itemBuilder: (_) => const [
      PopupMenuItem(
        value: SupportSection.contacts,
        child: Row(children: [
          Icon(Icons.contact_phone_outlined),
          SizedBox(width: 12),
          FixMateText('Contacts'),
        ]),
      ),
      PopupMenuItem(
        value: SupportSection.help,
        child: Row(children: [
          Icon(Icons.help_outline),
          SizedBox(width: 12),
          FixMateText('Help'),
        ]),
      ),
      PopupMenuItem(
        value: SupportSection.about,
        child: Row(children: [
          Icon(Icons.info_outline),
          SizedBox(width: 12),
          FixMateText('About'),
        ]),
      ),
    ],
  );
}

enum _UtilityChoice { english, lithuanian, contacts, help, about }

/// One compact app-bar menu keeps language and support available on phones
/// without overflowing a narrow maintenance/admin toolbar.
class FixMateUtilityMenu extends StatelessWidget {
  const FixMateUtilityMenu({super.key});

  @override
  Widget build(BuildContext context) => PopupMenuButton<_UtilityChoice>(
    key: const Key('app_utilities_menu'),
    tooltip: fmTr(context, 'Support center'),
    icon: const Icon(Icons.more_vert),
    onSelected: (choice) {
      if (choice == _UtilityChoice.english ||
          choice == _UtilityChoice.lithuanian) {
        context.read<LocaleCubit>().setLocale(
            Locale(choice == _UtilityChoice.english ? 'en' : 'lt'));
        return;
      }
      final section = switch (choice) {
        _UtilityChoice.contacts => SupportSection.contacts,
        _UtilityChoice.about => SupportSection.about,
        _ => SupportSection.help,
      };
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FixMateSupportPage(initialSection: section),
      ));
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: _UtilityChoice.english,
        child: Row(children: [
          Icon(Icons.language), SizedBox(width: 12), Text('English')])),
      PopupMenuItem(value: _UtilityChoice.lithuanian,
        child: Row(children: [
          Icon(Icons.language), SizedBox(width: 12), Text('Lietuvių')])),
      PopupMenuDivider(),
      PopupMenuItem(value: _UtilityChoice.contacts,
        child: Row(children: [
          Icon(Icons.contact_phone_outlined), SizedBox(width: 12),
          FixMateText('Contacts')])),
      PopupMenuItem(value: _UtilityChoice.help,
        child: Row(children: [
          Icon(Icons.help_outline), SizedBox(width: 12),
          FixMateText('Help')])),
      PopupMenuItem(value: _UtilityChoice.about,
        child: Row(children: [
          Icon(Icons.info_outline), SizedBox(width: 12),
          FixMateText('About')])),
    ],
  );
}
