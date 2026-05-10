import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'bill_provider.dart';
import 'bill_service.dart';

// Editable row that holds user-tweaked values before bulk-saving.
class _EditableItem {
  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  _EditableItem({
    required String nameVal,
    required int quantityVal,
    required double unitPriceVal,
  })  : name = TextEditingController(text: nameVal),
        quantity = TextEditingController(text: quantityVal.toString()),
        unitPrice = TextEditingController(
          text: unitPriceVal.toStringAsFixed(2),
        );

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
  static const primaryBlue = Color(0xFF4E54C8);
  static const bgLight = Color(0xFFF6F8FD);
  static const cardWhite = Colors.white;
  static const textDark = Color(0xFF2C3246);
  static const textGray = Color(0xFF8E95A9);
  static const inputFill = Color(0xFFF2F4FC);
  static const inputBorder = Color(0xFFDCDFEA);
  static const errorRed = Color(0xFFD94848);

  final _picker = ImagePicker();
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  List<_EditableItem> _items = [];
  bool _scanning = false;
  bool _saving = false;
  String? _error;
  File? _pickedImage;

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickAndScan(ImageSource source) async {
    setState(() {
      _scanning = true;
      _error = null;
    });

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) {
        setState(() => _scanning = false);
        return;
      }

      final imageFile = File(picked.path);
      setState(() => _pickedImage = imageFile);

      // ML Kit on-device OCR
      final inputImage = InputImage.fromFile(imageFile);
      final recognised = await _textRecognizer.processImage(inputImage);
      final rawText = recognised.text;

      if (rawText.trim().isEmpty) {
        setState(() {
          _error = 'No text detected. Try a clearer image.';
          _scanning = false;
        });
        return;
      }

      // Send raw OCR text to backend LLM parser
      final parsed = await ref.read(billServiceProvider).runOcr(
            billId: widget.billId,
            rawText: rawText,
          );

      for (final item in _items) {
        item.dispose();
      }
      setState(() {
        _items = parsed
            .map(
              (json) => _EditableItem(
                nameVal: json['name'] as String? ?? '',
                quantityVal: (json['quantity'] as num?)?.toInt() ?? 1,
                unitPriceVal: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
              ),
            )
            .toList();
        _scanning = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Scan failed: $e';
        _scanning = false;
      });
    }
  }

  void _removeItem(int index) {
    _items[index].dispose();
    setState(() => _items.removeAt(index));
  }

  Future<void> _confirm() async {
    if (_items.isEmpty) return;

    final validItems = _items
        .map((i) => i.toJson())
        .where((j) =>
            (j['name'] as String).isNotEmpty &&
            (j['unit_price'] as double) > 0)
        .toList();

    if (validItems.isEmpty) {
      setState(() => _error = 'No valid items to add.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(billItemsProvider(widget.billId).notifier)
          .addItemsBulk(validItems);
      if (mounted) context.go('/bill/${widget.billId}/invite');
    } catch (e) {
      setState(() {
        _error = 'Failed to save items: $e';
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryBlue),
          onPressed: () => context.go('/bill/${widget.billId}/items'),
        ),
        title: const Text(
          'Scan Receipt',
          style: TextStyle(
            color: textDark,
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
                  _buildPickerCard(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: errorRed, fontSize: 13),
                    ),
                  ],
                  if (_items.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildReviewHeader(),
                    const SizedBox(height: 12),
                    ..._buildItemRows(),
                    _buildAddManualRow(),
                  ],
                ],
              ),
            ),
          ),
          if (_items.isNotEmpty) _buildConfirmBar(),
        ],
      ),
    );
  }

  Widget _buildPickerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardWhite,
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
                  color: primaryBlue,
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
                        color: textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'ML Kit reads text on-device, then our AI structures it.',
                      style: TextStyle(color: textGray, fontSize: 12),
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
          _scanning
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
                            color: primaryBlue,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Reading receipt…',
                          style: TextStyle(color: textGray, fontSize: 13),
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
      icon: Icon(icon, color: primaryBlue, size: 18),
      label: Text(
        label,
        style: const TextStyle(
          color: primaryBlue,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: primaryBlue),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
            color: textDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Spacer(),
        Text(
          '${_items.length} items',
          style: const TextStyle(color: textGray, fontSize: 13),
        ),
      ],
    );
  }

  List<Widget> _buildItemRows() {
    return List.generate(_items.length, (i) {
      final item = _items[i];
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardWhite,
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
            Expanded(
              flex: 4,
              child: _editCell(item.name, hint: 'Item name'),
            ),
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
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d*\.?\d{0,2}'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _removeItem(i),
              child: const Icon(
                Icons.close,
                color: textGray,
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
        color: inputFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: inputBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(fontSize: 13, color: textDark),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: textGray, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildAddManualRow() {
    return TextButton.icon(
      onPressed: () {
        setState(() {
          _items.add(_EditableItem(
            nameVal: '',
            quantityVal: 1,
            unitPriceVal: 0.0,
          ));
        });
      },
      icon: const Icon(Icons.add, color: primaryBlue, size: 18),
      label: const Text(
        'Add row',
        style: TextStyle(color: primaryBlue, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildConfirmBar() {
    return Container(
      decoration: const BoxDecoration(
        color: cardWhite,
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
            backgroundColor: primaryBlue,
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
                  'Add ${_items.length} item${_items.length == 1 ? '' : 's'}',
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
