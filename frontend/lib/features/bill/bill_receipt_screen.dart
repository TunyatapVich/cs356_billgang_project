import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BillReceiptScreen extends ConsumerStatefulWidget {
  final String billId;
  const BillReceiptScreen({super.key, required this.billId});

  @override
  ConsumerState<BillReceiptScreen> createState() => _BillReceiptScreenState();
}

class _BillReceiptScreenState extends ConsumerState<BillReceiptScreen> {
  final mockBill = {
    'title': 'งานเลี้ยงรุ่น',
    'date': '05/05/2026',
    'totalAmount': 2500.0,
    'people': [
      {'name': 'ชยานันต์', 'foodTotal': 350.0, 'alcoholTotal': 0.0},
      {'name': 'เวฟ', 'foodTotal': 350.0, 'alcoholTotal': 200.0},
    ],
  };

  Widget _buildSubRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _subStyle),
          Text(amount.toStringAsFixed(2), style: _subStyle),
        ],
      ),
    );
  }

  Widget _buildPersonRow(Map person) {
    final foodTotal = person['foodTotal'] as double;
    final alcoholTotal = person['alcoholTotal'] as double;
    final grandTotal = foodTotal + alcoholTotal;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(person['name'], style: _nameStyle),
              Text('฿${grandTotal.toStringAsFixed(2)}', style: _nameStyle),
            ],
          ),
          const SizedBox(height: 4),
          _buildSubRow('อาหาร', foodTotal),
          _buildSubRow('เหล้า', alcoholTotal),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final people = mockBill['people'] as List;
    final totalAmount = mockBill['totalAmount'] as double;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text('ใบเสร็จ')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                '🧾 BillGang',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mockBill['title'] as String,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                mockBill['date'] as String,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),
              const Text('- - - - - - - - - - - - - - -'),
              const SizedBox(height: 16),
              ...people.map((p) => _buildPersonRow(p as Map)),
              const Text('═══════════════════════'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ยอดรวมทั้งหมด',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '฿${totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  child: const Text('ชำระเงิน'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _nameStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.bold,
  fontFamily: 'monospace',
);

const _subStyle = TextStyle(
  fontSize: 13,
  fontFamily: 'monospace',
  color: Colors.black54,
);