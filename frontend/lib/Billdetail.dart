import 'package:flutter/material.dart';

class BillDetailPage extends StatelessWidget {
  const BillDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F4F2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ), //Back
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "TRANSACTION LEDGER",
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: Color(0xFF9F9B97),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 14),

                const Text(
                  "Bill Details",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F2230),
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  "Please specify the transaction name and itemized list.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9F9B97),
                  ),
                ),

                const SizedBox(height: 28),

                const Text(
                  "BILL IDENTIFICATION",
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    color: Color(0xFF9F9B97),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EFEF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "e.g. Dinner at The Gables",
                      hintStyle: TextStyle(
                        color: Color(0xFFC6C2BE),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  "DATE OF OCCASION",
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    color: Color(0xFF9F9B97),
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1EFEF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: const [
                      Expanded(
                        child: Text(
                          "27/10/2023",
                          style: TextStyle(
                            fontSize: 22,
                            color: Color(0xFF0F2230),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: Color(0xFF0F2230),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                Row(
                  children: [
                    const Text(
                      "LINE ITEMS",
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 2,
                        color: Color(0xFF9F9B97),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1E7D6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "3 ITEMS",
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFFC59B5F),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                const ItemCard(
                  quantity: "1",
                  title: "ข้าวผัด",
                  subtitle: "SIGNATURE\nMAIN",
                  price: "240",
                ),

                const SizedBox(height: 14),

                const ItemCard(
                  quantity: "2",
                  title: "น้ำมะนาวโซด",
                  subtitle: "REFRESHMENT",
                  price: "130",
                ),

                const SizedBox(height: 14),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFFE3DED8),
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      "+   APPEND LINE ITEM",
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: Color(0xFFBDB7B0),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                const Divider(color: Color(0xFFE7E1DB)),

                const SizedBox(height: 24),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Expanded(
                      child: Text(
                        "AGGREGATE TOTAL",
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: Color(0xFF9F9B97),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      "INCL. SERVICE & TAX\n+ 17.0% Added",
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF9F9B97),
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text(
                      "370.00",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F2230),
                      ),
                    ),
                    SizedBox(width: 6),
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        "THB",
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFC59B5F),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF21313D),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Digital Receipt Capture",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                const Center(
                  child: Text(
                    "AUTOMATED INTELLIGENCE SCANNING",
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 2,
                      color: Color(0xFFD2CBC4),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final String quantity;
  final String title;
  final String subtitle;
  final String price;

  const ItemCard({
    super.key,
    required this.quantity,
    required this.title,
    required this.subtitle,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 88,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3F1),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const Text(
                "-",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFB8B1AA),
                ),
              ),
              Text(
                quantity,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0F2230),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                "+",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFB8B1AA),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0F2230),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 9,
                  height: 1.5,
                  letterSpacing: 1.4,
                  color: Color(0xFFA8A19A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              price,
              style: const TextStyle(
                fontSize: 24,
                color: Color(0xFF0F2230),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                "THB",
                style: TextStyle(
                  fontSize: 9,
                  color: Color(0xFFC0B8AF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}