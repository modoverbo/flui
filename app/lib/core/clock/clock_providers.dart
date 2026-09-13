import 'package:flui/core/clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock_providers.g.dart';

@Riverpod(keepAlive: true)
Clock clock(Ref ref) => const SystemClock();

@Riverpod(keepAlive: true)
Sleep sleep(Ref ref) => realSleep;
