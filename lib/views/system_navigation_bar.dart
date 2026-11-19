import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SystemNavigationBar extends StatelessWidget {
  const SystemNavigationBar({
    super.key,
    this.child = const SafeArea(top: false, child: SizedBox.shrink()),
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: child,
    );
  }
}
