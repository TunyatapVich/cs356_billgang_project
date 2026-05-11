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
    'foodTotal': 700.0,
    'alcoholTotal': 200.0,
    'people': [
      {
        'name': 'ชยานันต์',
        'foodTotal': 350.0,
        'alcoholTotal': 0.0,
        'isPaid': true,
      },
      {
        'name': 'เวฟ',
        'foodTotal': 350.0,
        'alcoholTotal': 200.0,
        'isPaid': false,
      },
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === Header ===
              _buildHeader(),
              const SizedBox(height: 20),

              // === Total Balance Card ===
              _buildBalanceCard(),
              const SizedBox(height: 28),

              // === Section Title ===
              _buildSectionTitle(),
              const SizedBox(height: 12),

              // === People List ===
              ...((mockBill['people'] as List).map((person) {
                return _buildPersonCard(person);
              }).toList()),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════
  // Header (ชื่อบิล + ปุ่ม back)
  // ════════════════════════════════
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              mockBill['title'] as String,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'สรุปบิลทั้งหมด',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        // Avatar
        CircleAvatar(
          radius: 22,
          backgroundColor: Colors.blue.shade100,
          child: const Icon(
            Icons.person,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════
  // Balance Card (กล่องสรุปยอดใหญ่)
  // ════════════════════════════════
  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // แถวบน: Total + icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ยอดรวมทั้งบิล',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '฿${(mockBill['totalAmount'] as double).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A56DB),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF1A56DB),
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // แถวล่าง: ค่าอาหาร + ค่าเหล้า
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ค่าอาหาร',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '฿${(mockBill['foodTotal'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A56DB),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ค่าเหล้า',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '฿${(mockBill['alcoholTotal'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A56DB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════
  // Section Title (รายการแต่ละคน + ดูใบเสร็จ)
  // ════════════════════════════════
  Widget _buildSectionTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'รายการแต่ละคน',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: () {
            // TODO: ไปหน้า receipt
          },
          child: const Text(
            'ดูใบเสร็จ',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF1A56DB),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════
  // Person Card (การ์ดของแต่ละคน)
  // ════════════════════════════════
  Widget _buildPersonCard(dynamic person) {
    final foodTotal = person['foodTotal'] as double;
    final alcoholTotal = person['alcoholTotal'] as double;
    final grandTotal = foodTotal + alcoholTotal;
    final isPaid = person['isPaid'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                person['name'][0],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ข้อมูลคน
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      person['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusBadge(isPaid),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'อาหาร $foodTotal • เหล้า $alcoholTotal',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // ยอดรวม
          Text(
            '฿${grandTotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isPaid ? Colors.grey.shade700 : const Color(0xFF1A56DB),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════
  // Status Badge ([จ่ายแล้ว] / [รอจ่าย])
  // ════════════════════════════════
  Widget _buildStatusBadge(bool isPaid) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPaid ? Colors.blue.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPaid ? 'จ่ายแล้ว' : 'รอจ่าย',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isPaid ? const Color(0xFF1A56DB) : Colors.red.shade700,
        ),
      ),
    );
  }
}


















// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';

// class BillSummaryScreen extends ConsumerStatefulWidget {
//   const BillSummaryScreen({super.key});

//   @override
//   ConsumerState<BillSummaryScreen> createState() => _BillSummaryScreenState();
// }

// class _BillSummaryScreenState extends ConsumerState<BillSummaryScreen> {
//   final mockBill = {
//     'title': 'งานเลี้ยงรุ่น',
//     'totalAmount': 2500.0,
//     'people': [
//       {
//         'name': 'ชยานันต์',
//         'foodTotal': 350.0,
//         'alcoholTotal': 0.0,
//       },
//       {
//         'name': 'เวฟ',
//         'foodTotal': 350.0,
//         'alcoholTotal': 200.0,
//       },
//     ],
//   };

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('สรุปบิล'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               mockBill['title'] as String,
//               style: const TextStyle(
//                 fontSize: 28,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 8),

//             Text(
//               'ยอดรวม ${mockBill['totalAmount']} บาท',
//               style: const TextStyle(
//                 fontSize: 16,
//                 color: Colors.grey,
//               ),
//             ),

//             const SizedBox(height: 24),
//             const Divider(),
//             const SizedBox(height: 8),

//             const Text(
//               'รายการแต่ละคน',
//               style: TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//             const SizedBox(height: 12),

//             Expanded(
//               child: ListView.builder(
//                 itemCount: (mockBill['people'] as List).length,
//                 itemBuilder: (context, index) {
//                   final person = (mockBill['people'] as List)[index];
//                   final foodTotal = person['foodTotal'] as double;
//                   final alcoholTotal = person['alcoholTotal'] as double;
//                   final grandTotal = foodTotal + alcoholTotal;

//                   return Card(
//                     margin: const EdgeInsets.symmetric(vertical: 6.0),
//                     elevation: 2,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: Padding(
//                       padding: const EdgeInsets.all(16.0),
//                       child: Row(
//                         children: [
//                           CircleAvatar(
//                             radius: 24,
//                             backgroundColor: Colors.blue.shade100,
//                             child: Text(
//                               person['name'][0],
//                               style: const TextStyle(
//                                 fontSize: 18,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                           const SizedBox(width: 16),

//                           Expanded(
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   person['name'],
//                                   style: const TextStyle(
//                                     fontSize: 16,
//                                     fontWeight: FontWeight.bold,
//                                   ),
//                                 ),
//                                 const SizedBox(height: 4),
//                                 Text(
//                                   'อาหาร $foodTotal  เหล้า $alcoholTotal',
//                                   style: const TextStyle(
//                                     fontSize: 13,
//                                     color: Colors.grey,
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),

//                           Text(
//                             '฿$grandTotal',
//                             style: const TextStyle(
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.blue,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }