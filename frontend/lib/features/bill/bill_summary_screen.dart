import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BillSummaryScreen extends ConsumerStatefulWidget {
  const BillSummaryScreen({super.key});

  @override
  ConsumerState<BillSummaryScreen> createState() => _BillSummaryScreenState();
}

class _BillSummaryScreenState extends ConsumerState<BillSummaryScreen> {
  // mock data ไว้ก่อนนะ
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
         children: const [
          Text('ตรงนี้จะเป็นข้อมูลบิล'),
         ],
       ),
     ),
    );
  }
}