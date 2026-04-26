import 'package:flutter/material.dart';
import 'Billdetail.dart';

class BillList extends StatelessWidget {
  const BillList({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EE),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1E2430),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BillDetailPage()),
          );
        },
      ),

      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Text(
                      "Active\nSettlements",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                        color: Color(0xFF1E2430),
                      ),
                    ),
                  ),
                  Row(
                    children: const [
                      Text(
                        "VIEW\nARCHIVE",
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFC8A26B),
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.north_east,
                        size: 16,
                        color: Color(0xFFC8A26B),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 25),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F2EE),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.restaurant_outlined,
                            color: Color(0xFFC8A26B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                "Omakase Dinner\nCelebration",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E2430),
                                  height: 1.2,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                "5 People • May 12, 2024",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF9C9AA1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    const Divider(color: Color(0xFFF0ECE8)),
                    const SizedBox(height: 18),

                    Row(
                      children: [
                        const Text(
                          "฿ 18,500",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2430),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F1E6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "WAITING",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFC8A26B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// class BillDetailPage extends StatelessWidget {
//   const BillDetailPage({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Bill Detail"),
//       ),
//       body: const Center(
//         child: Text(
//           "นี่คือหน้า Bill Detail",
//           style: TextStyle(fontSize: 24),
//         ),
//       ),
//     );
//   }
// }
