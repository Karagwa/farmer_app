import 'package:flutter/material.dart';
import 'package:HPGM/Services/connectivity_service.dart';

class ConnectivityBanner extends StatelessWidget {
  final Widget child;

  const ConnectivityBanner({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService().connectionStream,
      initialData: ConnectivityService().isOnline,
      builder: (context, snapshot) {
        final bool isOnline = snapshot.data ?? true;

        return Column(
          children: [
            if (!isOnline)
              Container(
                width: double.infinity,
                color: Colors.red[700],
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: SafeArea(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.wifi_off, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'No Internet Connection',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFamily: "Sans",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}
