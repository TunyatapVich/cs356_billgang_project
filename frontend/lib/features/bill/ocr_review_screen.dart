import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_colors.dart';
import 'bill_provider.dart';

// Holds TextEditingControllers for one editable row.
class _EditableItem {
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  _EditableItem({
    required String nameVal,
    required int quantityVal,
    required double unitPriceVal,
  }) : name = TextEditingController(text: nameVal),
       quantity = TextEditingController(text: quantityVal.toString()),
       unitPrice = TextEditingController(text: unitPriceVal.toStringAsFixed(2));

  void dispose() {
    name.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }

  Map<String, dynamic> toJson() => {
    'name': name.text.trim(),
    'quantity': int.tryParse(quantity.text.trim()) ?? 1,
    'unit_price': double.tryParse(unitPrice.text.trim()) ?? 0.0,
  };
}

class OcrReviewScreen extends ConsumerStatefulWidget {
  const OcrReviewScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends ConsumerState<OcrReviewScreen> {
  final _picker = ImagePicker();

  // Pure UI state — not derived from the provider
  File? _pickedImage;
  List<_EditableItem> _editableItems = [];
  bool _saving = false;

  @override
  void dispose() {
    _clearEditableItems();
    super.dispose();
  }

  void _clearEditableItems() {
    for (final item in _editableItems) {
      item.dispose();
    }
    _editableItems = [];
  }

  // Sync editable rows from freshly parsed provider items.
  void _syncEditableItems(List<Map<String, dynamic>> parsed) {
    _clearEditableItems();
    _editableItems = parsed
        .map(
          (json) => _EditableItem(
            nameVal: json['name'] as String? ?? '',
            quantityVal: (json['quantity'] as num?)?.toInt() ?? 1,
            unitPriceVal: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
          ),
        )
        .toList();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      final imageFile = File(picked.path);
      if (!mounted) return;
      setState(() {
        _pickedImage = imageFile;
        _clearEditableItems();
      });
      await ref.read(ocrProvider.notifier).scan(widget.billId, imageFile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open image: $e')));
    }
  }

  void _removeItem(int index) {
    _editableItems[index].dispose();
    setState(() => _editableItems.removeAt(index));
  }

  Future<void> _confirm() async {
    if (_editableItems.isEmpty || _saving) return;

    final validItems = _editableItems
        .map((i) => i.toJson())
        .where(
          (j) =>
              (j['name'] as String).isNotEmpty &&
              (j['unit_price'] as double) > 0,
        )
        .toList();

    if (validItems.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref
          .read(billItemsProvider(widget.billId).notifier)
          .addItemsBulk(validItems);
      if (mounted) context.go('/bill/${widget.billId}/items');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocrState = ref.watch(ocrProvider);

    // Sync editable rows once scan completes.
    ref.listen<OcrState>(ocrProvider, (prev, next) {
      if (next.status == OcrScanStatus.done &&
          prev?.status != OcrScanStatus.done) {
        setState(() => _syncEditableItems(next.items));
      }
    });

    final isScanning = ocrState.status == OcrScanStatus.scanning;
    final isDone = ocrState.status == OcrScanStatus.done;
    final canAddManualRow = isDone || ocrState.status == OcrScanStatus.error;
    final hasItems = _editableItems.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.bgLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryBlue),
          onPressed: () => context.go('/bill/${widget.billId}/items'),
        ),
        title: const Text(
          'Scan Receipt',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPickerCard(isScanning),
                  if (ocrState.error != null) ...[
                    const SizedBox(height: 12),
                    _buildErrorBanner(ocrState.error!),
                  ],
                  if (isDone && !hasItems && ocrState.error == null) ...[
                    const SizedBox(height: 20),
                    _buildNoItemsFound(),
                  ],
                  if (hasItems) ...[
                    const SizedBox(height: 24),
                    _buildReviewHeader(),
                    const SizedBox(height: 12),
                    ..._buildItemRows(),
                  ],
                  if (canAddManualRow) _buildAddManualRow(),
                ],
              ),
            ),
          ),
          if (hasItems) _buildConfirmBar(),
        ],
      ),
    );
  }

  Widget _buildPickerCard(bool isScanning) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4E6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Receipt Scanner',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'ML Kit reads text on-device, then our AI structures it.',
                      style: TextStyle(color: AppColors.textGray, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_pickedImage != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                _pickedImage!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ],
          const SizedBox(height: 16),
          isScanning
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Reading receipt…',
                          style: TextStyle(
                            color: AppColors.textGray,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: _sourceButton(
                        icon: Icons.camera_alt_outlined,
                        label: 'Camera',
                        onTap: () => _pickAndScan(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _sourceButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        onTap: () => _pickAndScan(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _sourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.primaryBlue, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.primaryBlue),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }

  Widget _buildReviewHeader() {
    return Row(
      children: [
        const Text(
          'Parsed Items',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          '${_editableItems.length} items',
          style: const TextStyle(color: AppColors.textGray, fontSize: 13),
        ),
      ],
    );
  }

  List<Widget> _buildItemRows() {
    return List.generate(_editableItems.length, (i) {
      final item = _editableItems[i];
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(flex: 4, child: _editCell(item.name, hint: 'Item name')),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _editCell(
                item.quantity,
                hint: 'Qty',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _editCell(
                item.unitPrice,
                hint: 'Price',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _removeItem(i),
              child: const Icon(
                Icons.close,
                color: AppColors.textGray,
                size: 18,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _editCell(
    TextEditingController controller, {
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontSize: 13, color: AppColors.textDark),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textGray, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.errorRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoItemsFound() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            color: AppColors.textGray,
            size: 36,
          ),
          SizedBox(height: 10),
          Text(
            'No items detected',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Try a clearer photo, or add items manually below.',
            style: TextStyle(color: AppColors.textGray, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAddManualRow() {
    return TextButton.icon(
      onPressed: () {
        setState(() {
          _editableItems.add(
            _EditableItem(nameVal: '', quantityVal: 1, unitPriceVal: 0.0),
          );
        });
      },
      icon: const Icon(Icons.add, color: AppColors.primaryBlue, size: 18),
      label: const Text(
        'Add row',
        style: TextStyle(
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildConfirmBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          onPressed: _saving ? null : _confirm,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  'Add ${_editableItems.length} item${_editableItems.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }
}
