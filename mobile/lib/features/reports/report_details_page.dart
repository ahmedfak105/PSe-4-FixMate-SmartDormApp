import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/photo_data.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/supabase_attachment_repository.dart';
import '../../data/repositories/supabase_report_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import 'reports_cubit.dart';
import 'status_label.dart';

class ReportDetailsPage extends StatefulWidget {
  const ReportDetailsPage({super.key, required this.reportId});
  final String reportId;

  @override
  State<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends State<ReportDetailsPage> {
  SupabaseAttachmentRepository? _attachments;
  Future<List<ReportAttachment>>? _listFuture;
  final Map<String, Future<Uint8List>> _downloadFutures = {};
  bool _uploading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Offline widget tests don't require a configured Supabase client.
    if (_attachments == null &&
        context.read<ReportsCubit>().repository is SupabaseReportRepository) {
      _attachments = SupabaseAttachmentRepository(Supabase.instance.client);
      _listFuture = _attachments!.listForReport(widget.reportId);
    }
  }

  void _refreshPhotos() {
    if (_attachments == null) return;
    setState(() {
      _downloadFutures.clear();
      _listFuture = _attachments!.listForReport(widget.reportId);
    });
  }

  Future<void> _attachPhoto() async {
    if (_attachments == null || _uploading) return;
    try {
      final selected = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (selected == null) return;
      final photo = PhotoData.fromBytes(await selected.readAsBytes());
      if (!mounted) return;
      setState(() => _uploading = true);
      await _attachments!.upload(reportId: widget.reportId, photo: photo);
      if (!mounted) return;
      _refreshPhotos();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo uploaded to private Storage.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(seconds: 8),
            content: Text('Photo upload failed: $error')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Widget _photoTile(ReportAttachment entry) {
    final future = _downloadFutures.putIfAbsent(
      entry.storagePath,
      () => _attachments!.download(entry.storagePath),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: FutureBuilder<Uint8List>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return SelectableText('Photo could not be downloaded: ${snapshot.error}');
            }
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 130,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Image.memory(snapshot.data!, height: 240, fit: BoxFit.contain);
          },
        ),
      ),
    );
  }

  Widget _photoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text('Report photos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _attachPhoto,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_uploading ? 'Uploading photo...' : 'Add photo to report'),
        ),
        if (_listFuture != null)
          FutureBuilder<List<ReportAttachment>>(
            future: _listFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(children: [
                  SelectableText('Cannot load photos: ${snapshot.error}'),
                  TextButton(onPressed: _refreshPhotos, child: const Text('Retry')),
                ]);
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.data!.isEmpty) return const Text('No photos attached yet.');
              return Column(
                children: [for (final entry in snapshot.data!) _photoTile(entry)],
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<ReportsCubit, ReportsState>(builder: (context, state) {
      final matches = state.items.where((report) => report.id == widget.reportId);
      if (matches.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.reportDetails)),
          body: Center(child: Text(l10n.noReports)),
        );
      }
      final report = matches.first;
      final isDemo = context.read<ReportsCubit>().repository is InMemoryReportRepository;
      return Scaffold(
        appBar: AppBar(title: Text(l10n.reportDetails)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Text(report.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Chip(label: Text(statusLabel(report.status, l10n))),
          ListTile(title: Text(l10n.reportId), subtitle: Text(report.id)),
          ListTile(title: Text(l10n.category), subtitle: Text(report.category)),
          ListTile(title: Text(l10n.location), subtitle: Text(report.location)),
          ListTile(title: Text(l10n.description), subtitle: Text(report.description)),
          if (isDemo) ...[
            const SizedBox(height: 16),
            Text(l10n.demoNotice),
          ] else if (_attachments != null) _photoSection(),
        ]),
      );
    });
  }
}
