import 'package:flutter/material.dart';

/// App-wide navigator key. Allows navigation from services that don't have
/// a BuildContext (e.g. notification tap handlers, background callbacks).
class NavigationService {
  static final navigatorKey = GlobalKey<NavigatorState>();
}
