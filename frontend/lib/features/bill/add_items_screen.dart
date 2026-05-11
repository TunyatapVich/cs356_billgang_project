import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'bill_provider.dart';

class AddItemsScreen extends ConsumerStatefulWidget {
  const AddItemsScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<AddItemsScreen> createState() => _AddItemsScreenState();
}

class _AddItemsScreenState extends ConsumerState<AddItemsScreen> {
  static const primaryBlue = Color(0xFF4E54C8);
  static const bgLight = Color(0xFFF6F8FD);
  static const cardWhite = Colors.white;
  static const textDark = Color(0xFF2C3246);
  static const textGray = Color(0xFF8E95A9);
  static const inputFill = Color(0xFFF2F4FC);
  static const inputBorder = Color(0xFFDCDFEA);
  static const errorRed = Color(0xFFD94848);

  final _nameController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _priceController = TextEditingController();

  String? _addError;
  bool _adding = false;

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final name = _nameController.text.trim();
    final qty = int.tryParse(_qtyController.text.trim());
    final price = double.tryParse(_priceController.text.trim());

    if (name.isEmpty || qty == null || qty < 1 || price == null || price < 0) {
      setState(() => _addError = 'Fill in a valid name, quantity, and price');
      return;
    }

    setState(() {
      _addError = null;
      _adding = true;
    });

    try {
      await ref
          .read(billItemsProvider(widget.billId).notifier)
          .addItem(name: name, quantity: qty, unitPrice: price);
      _nameController.clear();
      _qtyController.text = '1';
      _priceController.clear();
    } catch (e) {
      setState(() => _addError = e.toString());
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      await ref
          .read(billItemsProvider(widget.billId).notifier)
          .deleteItem(itemId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsState = ref.watch(billItemsProvider(widget.billId));

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: bgLight,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryBlue),
          onPressed: () => context.go('/bills'),
        ),
        title: const Text(
          'Add Items',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/bill/${widget.billId}/invite'),
            child: const Text(
              'Done',
              style: TextStyle(
                color: primaryBlue,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: itemsState.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Failed to load items: $e',
                  style: const TextStyle(color: errorRed),
                ),
              ),
              data: (items) => items.isEmpty
                  ? _buildEmptyState()
                  : _buildItemList(items),
            ),
          ),
          _buildAddPanel(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.receipt_long, color: primaryBlue, size: 48),
        const SizedBox(height: 16),
        const Text(
          'No items yet',
          style: TextStyle(
            color: textDark,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Add items below or scan a receipt.',
          style: TextStyle(color: textGray, fontSize: 13),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.go('/bill/${widget.billId}/ocr'),
          icon: const Icon(Icons.document_scanner_outlined, color: primaryBlue),
          label: const Text(
            'Scan Receipt',
            style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: primaryBlue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildItemList(List<BillItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      itemCount: items.length + 1, // +1 for the scan button header
      itemBuilder: (_, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: OutlinedButton.icon(
              onPressed: () => context.go('/bill/${widget.billId}/ocr'),
              icon: const Icon(
                Icons.document_scanner_outlined,
                color: primaryBlue,
                size: 18,
              ),
              label: const Text(
                'Scan Receipt',
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: primaryBlue),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          );
        }

        final item = items[index - 1];
        return _ItemCard(
          item: item,
          onDelete: () => _deleteItem(item.id),
        );
      },
    );
  }

  Widget _buildAddPanel() {
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
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Item',
            style: TextStyle(
              color: textDark,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildNameRow(),
          const SizedBox(height: 10),
          _buildQtyPriceRow(),
          if (_addError != null) ...[
            const SizedBox(height: 8),
            Text(
              _addError!,
              style: const TextStyle(color: errorRed, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _adding ? null : _addItem,
              child: _adding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Add Item',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameRow() {
    return _inputField(
      controller: _nameController,
      hint: 'Item name',
    );
  }

  Widget _buildQtyPriceRow() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _inputField(
            controller: _qtyController,
            hint: 'Qty',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
          child: _inputField(
            controller: _priceController,
            hint: 'Unit price',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: inputBorder),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: textGray, fontSize: 14),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onDelete});
  final BillItem item;
  final VoidCallback onDelete;

  static const primaryBlue = _AddItemsScreenState.primaryBlue;
  static const cardWhite = _AddItemsScreenState.cardWhite;
  static const textDark = _AddItemsScreenState.textDark;
  static const textGray = _AddItemsScreenState.textGray;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: item.isPending
              ? cardWhite.withValues(alpha: 0.7)
              : cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE4E6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fastfood_outlined,
                  color: primaryBlue, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            color: textDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isPending)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: primaryBlue,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'x${item.quantity}  ·  ฿${item.unitPrice.toStringAsFixed(2)}',
                    style: const TextStyle(color: textGray, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '฿${item.lineTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                color: primaryBlue,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
