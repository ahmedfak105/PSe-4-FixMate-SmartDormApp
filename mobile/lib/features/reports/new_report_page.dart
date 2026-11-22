import 'package:flutter/material.dart';
import '../../l10n/fixmate_i18n.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/photo_data.dart';
import '../../data/repositories/supabase_attachment_repository.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../navigation/app_tab.dart';
import '../bottom_tabs/bottom_tabs_cubit.dart';
import 'reports_cubit.dart';

class NewReportPage extends StatefulWidget {
  const NewReportPage({super.key});
  @override
  State<NewReportPage> createState() => _NewReportPageState();
}

class _NewReportPageState extends State<NewReportPage> {
  final _key = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  String? _category;
  List<String>? _categories;
  String? _categoriesError;
  bool _categoriesLoading = true;
  bool _saving = false;
  PhotoData? _selectedPhoto;
  String? _photoName;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    if (mounted) setState(() {
      _categoriesLoading = true;
      _categoriesError = null;
    });
    final repository = context.read<ReportsCubit>().repository;
    try {
      final categories = await repository.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _category = categories.contains(_category)
            ? _category
            : (categories.isEmpty ? null : categories.first);
        _categoriesLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _categoriesError = '$error';
        _categoriesLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_saving) return;
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final checked = PhotoData.fromBytes(await file.readAsBytes());
      if (!mounted) return;
      setState(() {
        _selectedPhoto = checked;
        _photoName = file.name;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: FixMateText('Could not select photo: $error'),
      ));
    }
  }

  Future<void> _submit() async {
    if (_saving || !_key.currentState!.validate() || _category == null) return;
    setState(() => _saving = true);
    final cubit = context.read<ReportsCubit>();
    final success = await cubit.create(
      title: _title.text,
      category: _category!,
      location: _location.text,
      description: _description.text,
    );
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    if (!success) {
      setState(() => _saving = false);
      final details = cubit.state.error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: FixMateText(details == null ? l10n.saveFailed : '${l10n.saveFailed}: $details'),
      ));
      return;
    }

    String? photoError;
    final createdId = cubit.lastCreatedReportId;
    if (_selectedPhoto != null) {
      try {
        if (createdId == null) {
          throw StateError('Could not determine the saved report ID.');
        }
        await SupabaseAttachmentRepository(Supabase.instance.client).upload(
          reportId: createdId,
          photo: _selectedPhoto!,
        );
      } catch (error) {
        // The report was ALREADY saved. Do not retry creating the report.
        photoError = '$error';
      }
    }
    if (!mounted) return;
    _title.clear();
    _location.clear();
    _description.clear();
    setState(() {
      _saving = false;
      _category = _categories?.firstOrNull;
      _selectedPhoto = null;
      _photoName = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: Duration(seconds: photoError == null ? 4 : 10),
      content: FixMateText(photoError != null
          ? 'Report #$createdId saved, but photo upload failed: $photoError. '
              'Open report details to add the photo again.'
          : 'Report saved successfully.'),
    ));
    context.read<BottomTabsCubit>().selectTab(AppTab.myReports);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String? requiredValue(String? value) =>
        (value == null || value.trim().isEmpty) ? l10n.requiredField : null;
    return Scaffold(
      appBar: AppBar(title: FixMateText(l10n.tabNewReport)),
      body: _categoriesLoading
          ? const Center(child: CircularProgressIndicator())
          : _categoriesError != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const FixMateText('Could not load categories from Supabase.'),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(_categoriesError!, textAlign: TextAlign.center),
                  ),
                  TextButton(onPressed: _loadCategories, child: FixMateText(l10n.retry)),
                ]))
              : _categories == null || _categories!.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const FixMateText('No active maintenance categories available.'),
                      TextButton(onPressed: _loadCategories, child: FixMateText(l10n.retry)),
                    ]))
                  : Form(
                      key: _key,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          TextFormField(
                            key: const Key('report_title'),
                            controller: _title,
                            decoration: InputDecoration(
                              labelText: l10n.reportTitle,
                              border: const OutlineInputBorder(),
                            ),
                            validator: requiredValue,
                            maxLength: 120,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: InputDecoration(
                              labelText: l10n.category,
                              border: const OutlineInputBorder(),
                            ),
                            items: _categories!
                                .map((name) => DropdownMenuItem(value: name, child: FixMateText(name)))
                                .toList(),
                            onChanged: (value) => setState(() => _category = value),
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const Key('report_location'),
                            controller: _location,
                            decoration: InputDecoration(
                              labelText: l10n.location,
                              border: const OutlineInputBorder(),
                            ),
                            validator: requiredValue,
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            key: const Key('report_description'),
                            controller: _description,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: l10n.description,
                              border: const OutlineInputBorder(),
                            ),
                            validator: requiredValue,
                          ),
                          const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _saving ? null : _pickPhoto,
                              icon: const Icon(Icons.add_photo_alternate_outlined),
                              label: FixMateText(_selectedPhoto == null
                                  ? 'Add photo (optional, up to 5 MB)'
                                  : 'Change selected photo'),
                            ),
                            if (_selectedPhoto != null) ...[
                              ListTile(
                                leading: const Icon(Icons.image_outlined),
                                title: FixMateText(_photoName ?? 'Selected photo'),
                                subtitle: const FixMateText('JPEG, PNG or WebP'),
                                trailing: IconButton(
                                  tooltip: fmTr(context, 'Remove selected photo'),
                                  onPressed: _saving ? null : () => setState(() {
                                    _selectedPhoto = null;
                                    _photoName = null;
                                  }),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _selectedPhoto!.bytes,
                                  height: 180,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          const SizedBox(height: 22),
                          FilledButton.icon(
                            key: const Key('submit_report'),
                            onPressed: _saving ? null : _submit,
                            icon: const Icon(Icons.send_outlined),
                            label: FixMateText(_saving ? l10n.saving : l10n.submitReport),
                          ),
                        ],
                      ),
                    ),
    );
  }
}
