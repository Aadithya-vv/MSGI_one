import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Entry navigation callbacks only; they carry no identity or authorization.
final exploreDemoActionProvider = Provider<VoidCallback?>((ref) => null);
final appEntryActionProvider = Provider<VoidCallback?>((ref) => null);
