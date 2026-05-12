import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BillReceiptScreen extends ConsumerStatefulWidget {
  const BillReceiptScreen({super.key});

  @override
  ConsumerState<BillReceiptScreen> createState() => _BillReceiptScreenState();
}

class _BillReceiptScreenState extends ConsumerState<BillReceiptScreen> {
  // Mock data — เน้นรายการอาหาร
  final mockBill = {
    'title': 'งานเลี้ยงรุ่น',
    'items': [
      {
        'name': 'ผัดไทย',
        'category': 'Thai Entrée',
        'price': 180.0,
        'icon': Icons.restaurant,
        'iconColor': Colors.blue,
        'sharedBy': 2,
      },
      {
        'name': 'ส้มตำ',
        'category': 'สลัด',
        'price': 120.0,
        'icon': Icons.eco,
        'iconColor': Colors.grey,
        'sharedBy': 1,
      },
      {
        'name': 'ต้มยำกุ้ง',
        'category': 'ซุปเผ็ด',
        'price': 320.0,
        'icon': Icons.soup_kitchen,
        'iconColor': Colors.red,
        'sharedBy': 3,
      },
    ],
    'taxPercent': 10.0,
  };

  @override
  Widget build(BuildContext context) {
    final items = mockBill['items'] as List;
    final taxPercent = mockBill['taxPercent'] as double;

    // คำนวณยอด
    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + (item['price'] as double),
    );
    final tax = subtotal * (taxPercent / 100);
    final finalTotal = subtotal + tax;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // === Header ===
            _buildHeader(),

            // === Scrollable Content ===
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Total Amount Center
                    _buildTotalAmount(finalTotal, items.length),
                    const SizedBox(height: 32),

                    // Items List
                    ...items.map((item) => _buildItemCard(item)).toList(),
                    const SizedBox(height: 24),

                    // Summary Box
                    _buildSummary(subtotal, tax, finalTotal, taxPercent),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // === Settle Button (ติดล่าง) ===
            _buildSettleButton(),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════
  // Header (← Title ⋮)
  // ════════════════════════════════
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A56DB)),
            onPressed: () {
              // TODO: navigate back
            },
          ),
          Expanded(
            child: Text(
              mockBill['title'] as String,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A56DB),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: more options
            },
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════
  // Total Amount (ตรงกลาง)
  // ════════════════════════════════
  Widget _buildTotalAmount(double total, int itemCount) {
    return Column(
      children: [
        Text(
          'ยอดรวมทั้งหมด',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '฿${total.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A56DB),
          ),
        ),
        const SizedBox(height: 12),
        // Badge นับรายการ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.receipt,
                size: 14,
                color: Color(0xFF1A56DB),
              ),
              const SizedBox(width: 6),
              Text(
                '$itemCount รายการ',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A56DB),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════
  // Item Card (รายการอาหารแต่ละจาน)
  // ════════════════════════════════
  Widget _buildItemCard(dynamic item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon ของอาหาร
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (item['iconColor'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item['icon'] as IconData,
              color: item['iconColor'] as Color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // ชื่อ + ประเภท
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item['category'] as String,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // ราคา + จำนวนคนแชร์
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '฿${(item['price'] as double).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A56DB),
                ),
              ),
              const SizedBox(height: 6),
              _buildSharedByBadge(item['sharedBy'] as int),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════
  // Shared By Badge (👥 3)
  // ════════════════════════════════
  Widget _buildSharedByBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people,
            size: 12,
            color: Colors.grey.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════
  // Summary Box (Subtotal + Tax + Final)
  // ════════════════════════════════
  Widget _buildSummary(double subtotal, double tax, double finalTotal, double taxPercent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow('ยอดก่อนภาษี', subtotal, isBold: false),
          const SizedBox(height: 10),
          _buildSummaryRow(
            'ภาษี & บริการ (${taxPercent.toInt()}%)',
            tax,
            isBold: false,
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 12),
          _buildSummaryRow('ยอดสุทธิ', finalTotal, isBold: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {required bool isBold}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? Colors.black : Colors.grey.shade700,
          ),
        ),
        Text(
          '฿${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isBold ? 22 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? const Color(0xFF1A56DB) : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════
  // Settle Button (ปุ่มล่างสุด)
  // ════════════════════════════════
  Widget _buildSettleButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () {
            // TODO: ไปหน้าชำระเงิน
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F5BD5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'คำนวณและชำระเงิน',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
