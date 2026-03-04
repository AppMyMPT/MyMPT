import 'package:flutter/material.dart';
import 'package:my_mpt/data/models/call.dart';
import 'package:my_mpt/core/utils/calls_util.dart';
import 'package:my_mpt/core/utils/date_formatter.dart';
import 'package:my_mpt/presentation/widgets/calls/calls_header.dart';
import 'package:my_mpt/presentation/widgets/calls/call_timeline_tile.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  static const _numeratorColor = Color(0xFFFF8C00);
  static const _denominatorColor = Color(0xFF4FC3F7);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final bg = theme.scaffoldBackgroundColor;
    final cardBg = cs.surface;
    final shadowColor = isDark ? Colors.black.withValues(alpha: 0.45) : Colors.black.withValues(alpha: 0.04);

    final List<Call> callsData = CallsUtil.getCalls();
    final weekType = DateFormatter.getWeekType(DateTime.now());
    final accentColor = weekType == 'Знаменатель' ? _denominatorColor : _numeratorColor;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CallsHeader(),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 30,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  children: List.generate(callsData.length, (index) {
                    final call = callsData[index];
                    final isLast = index == callsData.length - 1;
                    final isCurrent = CallsUtil.isCallCurrent(call.startTime, call.endTime);
                    final nextCall = !isLast ? callsData[index + 1] : null;
                    final isBreakCurrent = nextCall != null &&
                        CallsUtil.isBreakCurrent(call.endTime, nextCall.startTime);
                    return CallTimelineTile(
                      period: call.period,
                      startTime: call.startTime,
                      endTime: call.endTime,
                      description: call.description,
                      showConnector: !isLast,
                      isCurrent: isCurrent,
                      currentAccentColor: accentColor,
                      isBreakCurrent: isBreakCurrent,
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
