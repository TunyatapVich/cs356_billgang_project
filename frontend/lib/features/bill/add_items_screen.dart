import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/screen_app_bar.dart';
import 'bill_provider.dart';
import 'bill_service.dart';

class AddItemsScreen extends ConsumerStatefulWidget {
  const AddItemsScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<AddItemsScreen> createState() => _AddItemsScreenState();
}

class _AddItemsScreenState extends ConsumerState<AddItemsScreen> {
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
      setState(() => _addError = e.toString().replaceFirst('Exception: ', ''));
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

  Future<void> _changeQuantity(BillItem item, int newQty) async {
    if (newQty < 1) return;
    try {
      await ref.read(billServiceProvider).updateItem(
        billId: widget.billId,
        itemId: item.id,
        quantity: newQty,
      );
      ref.invalidate(billItemsProvider(widget.billId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsState = ref.watch(billItemsProvider(widget.billId));

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: ScreenAppBar(
        title: 'Items',
        backHref: '/',
        action: TextButton(
          onPressed: () => context.go('/bill/${widget.billId}/assign'),
          child: const Text(
            'Done',
            style: TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: itemsState.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primaryBlue),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load items: $e',
                    style: const TextStyle(color: AppColors.errorRed),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (items) => items.isEmpty ? _buildEmptyState() : _buildItemList(items),
            ),
          ),
          _buildAddPanel(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.dimBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long, color: AppColors.primaryBlue, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'No items yet',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add items below or scan a receipt.',
            style: TextStyle(color: AppColors.textGray, fontSize: 14),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.go('/bill/${widget.billId}/ocr'),
            icon: const Icon(Icons.document_scanner_outlined, color: AppColors.primaryBlue),
            label: const Text(
              'Scan Receipt',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primaryBlue),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(List<BillItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      itemCount: items.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: () => context.go('/bill/${widget.billId}/ocr'),
              icon: const Icon(
                Icons.document_scanner_outlined,
                color: AppColors.primaryBlue,
                size: 18,
              ),
              label: const Text(
                'Scan Receipt',
                style: TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          );
        }

        final item = items[index - 1];
        return _buildItemRow(item);
      },
    );
  }

  Widget _buildItemRow(BillItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'x${item.quantity}  ·  ฿${item.unitPrice.toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.textGray, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(
                '฿${item.lineTotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Minus button
              InkWell(
                onTap: () => _changeQuantity(item, item.quantity - 1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.bgLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: const Icon(Icons.remove, size: 16, color: AppColors.textDark),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              // Plus button
              InkWell(
                onTap: () => _changeQuantity(item, item.quantity + 1),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.bgLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: const Icon(Icons.add, size: 16, color: AppColors.textDark),
                ),
              ),
              const SizedBox(width: 12),
              // Trash button
              InkWell(
                onTap: () => _deleteItem(item.id),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline, size: 16, color: AppColors.errorRed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddPanel() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Add Item',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // Item name input
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: TextField(
              controller: _nameController,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                hintText: 'Item name',
                hintStyle: TextStyle(color: AppColors.textGray, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Quantity and Price row
          Row(
            children: [
              Expanded(flex: 3, child: _qtyStepper()),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.inputFill,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.inputBorder),
                  ),
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      hintText: 'Price (฿)',
                      hintStyle: TextStyle(color: AppColors.textGray, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_addError != null) ...[
            const SizedBox(height: 8),
            Text(
              _addError!,
              style: const TextStyle(color: AppColors.errorRed, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _adding ? null : _addItem,
              icon: const Icon(Icons.add, size: 18),
              label: _adding
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Add Item',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyStepper() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16, color: AppColors.primaryBlue),
            padding: EdgeInsets.zero,
            onPressed: () {
              final current = int.tryParse(_qtyController.text) ?? 1;
              if (current > 1) {
                setState(() => _qtyController.text = (current - 1).toString());
              }
            },
          ),
          Expanded(
            child: TextField(
              controller: _qtyController,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16, color: AppColors.primaryBlue),
            padding: EdgeInsets.zero,
            onPressed: () {
              final current = int.tryParse(_qtyController.text) ?? 1;
              setState(() => _qtyController.text = (current + 1).toString());
            },
          ),
        ],
      ),
    );
  }
}
