import 'package:flutter/material.dart';
import 'farm_model.dart';

class ApiaryDetailPage extends StatelessWidget {
  final Farm farm;

  const ApiaryDetailPage({super.key, required this.farm});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.brown[100],
      appBar: AppBar(
        title: Text(
          farm.name,
          style: const TextStyle(fontFamily: "Sans", fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.brown[300],
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Name', farm.name),
                const SizedBox(height: 20),
                _buildDetailRow('District', farm.district),
                const SizedBox(height: 20),
                _buildDetailRow('Address', farm.address),
                const SizedBox(height: 20),
                _buildDetailRow('Temperature', '${farm.average_temperature?.toStringAsFixed(1) ?? 'N/A'} °C'),
                const SizedBox(height: 20),
                _buildDetailRow('Weight', '${farm.average_weight?.toStringAsFixed(1) ?? 'N/A'} kg'),
                const SizedBox(height: 20),
                _buildDetailRow('Honey Level', '${farm.honeypercent?.toStringAsFixed(1) ?? 'N/A'} %'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
            fontFamily: "Sans",
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: "Sans",
          ),
        ),
      ],
    );
  }
}
