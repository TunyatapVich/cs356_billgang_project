import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BillSummaryScreen extends ConsumerStatefulWidget {
  const BillSummaryScreen({super.key});

  @override
  ConsumerState<BillSummaryScreen> createState() => _BillSummaryScreenState();
}

class _BillSummaryScreenState extends ConsumerState<BillSummaryScreen> {
  final mockBill = {
    'title': 'งานเลี้ยงรุ่น',
    'totalAmount': 2500.0,
    'people': [
      {
        'name': 'ชยานันต์',
        'foodTotal': 350.0,
        'alcoholTotal': 0.0,
      },
      {
        'name': 'เวฟ',
        'foodTotal': 350.0,
        'alcoholTotal': 200.0,
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สรุปบิล'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ชื่อบิล
            Text(
              mockBill['title'] as String,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // ยอดรวม
            Text(
              'ยอดรวม ${mockBill['totalAmount']} บาท',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),

            // หัวข้อ
            const Text(
              'รายการแต่ละคน',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // List ของคนแบบ card
            Expanded(
              child: ListView.builder(
                itemCount: (mockBill['people'] as List).length,
                itemBuilder: (context, index) {
                  final person = (mockBill['people'] as List)[index];
                  final foodTotal = person['foodTotal'] as double;
                  final alcoholTotal = person['alcoholTotal'] as double;
                  final grandTotal = foodTotal + alcoholTotal;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6.0),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Avatar
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              person['name'][0],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),

                          // ข้อมูลคน
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  person['name'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'อาหาร $foodTotal  เหล้า $alcoholTotal',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ยอดรวมของแต่ละคน
                          Text(
                            '฿$grandTotal',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}