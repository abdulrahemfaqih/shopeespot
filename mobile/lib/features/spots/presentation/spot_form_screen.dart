import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../app/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../domain/category.dart';
import '../domain/peak_range.dart';
import '../domain/spot.dart';
import 'location_picker_screen.dart';
import 'spots_providers.dart';
import 'widgets/category_selector.dart';
import 'widgets/peak_range_editor.dart';
import 'widgets/spot_peak_hours_section.dart';

class SpotFormScreen extends ConsumerStatefulWidget {
  const SpotFormScreen({
    super.key,
    this.spot,
    required this.initialLatitude,
    required this.initialLongitude,
  });

  final Spot? spot;
  final double initialLatitude;
  final double initialLongitude;

  @override
  ConsumerState<SpotFormScreen> createState() => _SpotFormScreenState();
}

class _SpotFormScreenState extends ConsumerState<SpotFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late Category _category;
  late double _latitude;
  late double _longitude;
  late List<PeakRange> _peakHours;
  bool _isSubmitting = false;

  bool get _isEditing => widget.spot != null;

  @override
  void initState() {
    super.initState();
    final spot = widget.spot;
    _nameController = TextEditingController(text: spot?.name ?? '');
    _notesController = TextEditingController(text: spot?.notes ?? '');
    _category = spot?.category ?? Category.shopeefood;
    _latitude = spot?.latitude ?? widget.initialLatitude;
    _longitude = spot?.longitude ?? widget.initialLongitude;
    _peakHours = List<PeakRange>.from(spot?.peakHours ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(spotRepositoryProvider);
      final name = _nameController.text.trim();
      final notes = _notesController.text.trim();

      if (_isEditing) {
        await repo.updateSpot(
          id: widget.spot!.id,
          name: name,
          category: _category,
          latitude: _latitude,
          longitude: _longitude,
          notes: notes,
          peakHours: _peakHours,
        );
      } else {
        await repo.createSpot(
          name: name,
          category: _category,
          latitude: _latitude,
          longitude: _longitude,
          notes: notes,
          peakHours: _peakHours,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan spot. Coba lagi.')),
        );
      }
    }
  }

  Future<void> _onAddPeakRange() async {
    final result = await showModalBottomSheet<PeakRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PeakRangeEditor(),
    );
    if (result != null) {
      setState(() => _peakHours.add(result));
    }
  }

  Future<void> _onEditPeakRange(PeakRange range) async {
    final result = await showModalBottomSheet<PeakRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PeakRangeEditor(initialRange: range),
    );
    if (result != null) {
      setState(() {
        final index = _peakHours.indexOf(range);
        if (index != -1) {
          _peakHours[index] = result;
        }
      });
    }
  }

  Future<void> _onPickLocation() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialPosition: LatLng(_latitude, _longitude),
          category: _category,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  InputDecoration _inputDecoration(String hint, AppTokens tokens) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(tokens.radiusSm),
      borderSide: BorderSide(color: tokens.border, width: tokens.borderWidth),
    );
    return InputDecoration(
      hintText: hint,
      counterText: '',
      contentPadding: EdgeInsets.all(tokens.space12),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(
          color: tokens.actionFill,
          width: tokens.borderWidth,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.surface,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit spot' : 'Spot baru'),
        backgroundColor: tokens.surface,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(tokens.space16),
          children: [
            Text(
              'Nama spot',
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
            SizedBox(height: tokens.space4),
            TextFormField(
              controller: _nameController,
              maxLength: 80,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration('Nama tempat atau resto', tokens),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Nama spot wajib diisi';
                }
                if (value.trim().length > 80) {
                  return 'Nama maksimal 80 karakter';
                }
                return null;
              },
            ),
            SizedBox(height: tokens.space16),
            Text(
              'Kategori',
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
            SizedBox(height: tokens.space8),
            CategorySelector(
              selectedCategory: _category,
              onChanged: (cat) => setState(() => _category = cat),
            ),
            SizedBox(height: tokens.space16),
            SpotPeakHoursSection(
              peakHours: _peakHours,
              onAdd: _onAddPeakRange,
              onEdit: _onEditPeakRange,
              onRemove: (range) => setState(() => _peakHours.remove(range)),
            ),
            SizedBox(height: tokens.space16),
            Text(
              'Catatan lapangan',
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
            SizedBox(height: tokens.space4),
            TextFormField(
              controller: _notesController,
              maxLength: 500,
              maxLines: 3,
              decoration: _inputDecoration(
                'Contoh: Parkir di samping gang, pesanan cepat siap',
                tokens,
              ),
              validator: (value) {
                if (value != null && value.trim().length > 500) {
                  return 'Catatan maksimal 500 karakter';
                }
                return null;
              },
            ),
            SizedBox(height: tokens.space16),
            Text(
              'Lokasi',
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
                color: tokens.textSecondary,
              ),
            ),
            SizedBox(height: tokens.space4),
            Text(
              '${_latitude.toStringAsFixed(6)}, ${_longitude.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 13.0, color: tokens.textSecondary),
            ),
            SizedBox(height: tokens.space8),
            AppButton.outline(
              label: 'Atur posisi di peta',
              onPressed: _onPickLocation,
            ),
            SizedBox(height: tokens.space24),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.space16),
          child: AppButton.primary(
            label: 'Simpan',
            isFullWidth: true,
            onPressed: _isSubmitting ? null : _onSave,
          ),
        ),
      ),
    );
  }
}
