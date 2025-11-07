import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:events_app_trueattempt/config/app_colors.dart';

/// Test Analytics Dashboard - Demo for supervisor
/// Shows various chart types with fake but realistic data
class TestAnalyticsScreen extends StatelessWidget {
  const TestAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.namaLightGray,
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: AppColors.namaNavyBlue,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Sessions',
                    '24',
                    Icons.event,
                    AppColors.namaNavyBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Attendees',
                    '1,247',
                    Icons.people,
                    AppColors.namaGoldenYellow,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Big Pie Chart - Session Attendance Overview
            _buildChartCard(
              title: 'Session Attendance Overview',
              subtitle: 'Average attendance across all sessions',
              child: SizedBox(
                height: 280,
                child: _buildAttendancePieChart(),
              ),
            ),

            const SizedBox(height: 16),

            // Two Charts Side by Side
            Row(
              children: [
                Expanded(
                  child: _buildChartCard(
                    title: 'Chat Activity',
                    subtitle: '1,234 messages',
                    child: SizedBox(
                      height: 180,
                      child: _buildChatActivityBarChart(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildChartCard(
                    title: 'Engagement',
                    subtitle: '68% active',
                    child: SizedBox(
                      height: 180,
                      child: _buildEngagementGauge(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Area Chart - Messages Over Time
            _buildChartCard(
              title: 'Messages Over Time',
              subtitle: 'Chat activity throughout the day',
              child: SizedBox(
                height: 220,
                child: _buildMessagesAreaChart(),
              ),
            ),

            const SizedBox(height: 16),

            // Line Chart - Attendance Trend
            _buildChartCard(
              title: 'Attendance Trend',
              subtitle: 'Check-ins per session',
              child: SizedBox(
                height: 220,
                child: _buildAttendanceLineChart(),
              ),
            ),

            const SizedBox(height: 16),

            // Radar Chart - Session Metrics
            _buildChartCard(
              title: 'Session Performance Metrics',
              subtitle: 'Multi-dimensional analysis',
              child: SizedBox(
                height: 280,
                child: _buildRadarChart(),
              ),
            ),

            const SizedBox(height: 16),

            // Additional Stats Cards
            _buildDetailedStatsCard(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.namaMediumGray,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.namaNavyBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.namaMediumGray,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildAttendancePieChart() {
    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        sections: [
          PieChartSectionData(
            color: AppColors.namaNavyBlue,
            value: 200,
            title: '200\nAttended',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          PieChartSectionData(
            color: AppColors.namaGoldenYellow,
            value: 100,
            title: '100\nNo-show',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.namaNavyBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatActivityBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        maxY: 500,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const titles = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
                if (value.toInt() >= 0 && value.toInt() < titles.length) {
                  return Text(
                    titles[value.toInt()],
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(toY: 340, color: AppColors.namaNavyBlue, width: 16),
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(toY: 280, color: AppColors.namaNavyBlue, width: 16),
          ]),
          BarChartGroupData(x: 2, barRods: [
            BarChartRodData(toY: 420, color: AppColors.namaNavyBlue, width: 16),
          ]),
          BarChartGroupData(x: 3, barRods: [
            BarChartRodData(toY: 310, color: AppColors.namaNavyBlue, width: 16),
          ]),
          BarChartGroupData(x: 4, barRods: [
            BarChartRodData(toY: 380, color: AppColors.namaNavyBlue, width: 16),
          ]),
        ],
      ),
    );
  }

  Widget _buildEngagementGauge() {
    return Stack(
      children: [
        PieChart(
          PieChartData(
            startDegreeOffset: -90,
            sectionsSpace: 0,
            centerSpaceRadius: 50,
            sections: [
              PieChartSectionData(
                color: AppColors.namaGoldenYellow,
                value: 68,
                title: '',
                radius: 30,
              ),
              PieChartSectionData(
                color: AppColors.namaLightGray,
                value: 32,
                title: '',
                radius: 30,
              ),
            ],
          ),
        ),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '68%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.namaNavyBlue,
                ),
              ),
              Text(
                'Active',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.namaMediumGray,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessagesAreaChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 100,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.namaLightGray,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                const times = ['9AM', '11AM', '1PM', '3PM', '5PM'];
                if (value.toInt() >= 0 && value.toInt() < times.length) {
                  return Text(
                    times[value.toInt()],
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 4,
        minY: 0,
        maxY: 400,
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 120),
              const FlSpot(1, 280),
              const FlSpot(2, 350),
              const FlSpot(3, 220),
              const FlSpot(4, 180),
            ],
            isCurved: true,
            color: AppColors.namaNavyBlue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.namaNavyBlue.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 50,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: AppColors.namaLightGray,
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                const sessions = ['S1', 'S2', 'S3', 'S4', 'S5', 'S6'];
                if (value.toInt() >= 0 && value.toInt() < sessions.length) {
                  return Text(
                    sessions[value.toInt()],
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 5,
        minY: 0,
        maxY: 250,
        lineBarsData: [
          LineChartBarData(
            spots: [
              const FlSpot(0, 180),
              const FlSpot(1, 210),
              const FlSpot(2, 195),
              const FlSpot(3, 220),
              const FlSpot(4, 200),
              const FlSpot(5, 215),
            ],
            isCurved: true,
            color: AppColors.namaGoldenYellow,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.namaGoldenYellow,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarChart() {
    return RadarChart(
      RadarChartData(
        radarShape: RadarShape.polygon,
        radarBorderData: const BorderSide(color: AppColors.namaLightGray, width: 2),
        gridBorderData: const BorderSide(color: AppColors.namaLightGray, width: 1),
        ticksTextStyle: const TextStyle(fontSize: 10, color: Colors.transparent),
        radarBackgroundColor: Colors.transparent,
        titlePositionPercentageOffset: 0.2,
        getTitle: (index, angle) {
          const titles = ['Attendance', 'Engagement', 'Chat', 'Feedback', 'Rating'];
          return RadarChartTitle(
            text: titles[index],
            angle: angle,
          );
        },
        dataSets: [
          RadarDataSet(
            fillColor: AppColors.namaNavyBlue.withOpacity(0.3),
            borderColor: AppColors.namaNavyBlue,
            borderWidth: 2,
            dataEntries: [
              const RadarEntry(value: 85), // Attendance
              const RadarEntry(value: 68), // Engagement
              const RadarEntry(value: 75), // Chat
              const RadarEntry(value: 90), // Feedback
              const RadarEntry(value: 80), // Rating
            ],
          ),
        ],
        titleTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.namaDarkGray,
        ),
      ),
    );
  }

  Widget _buildDetailedStatsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Metrics',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.namaNavyBlue,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricRow('Total Attendance', '200 / 300', '66.7%'),
          const Divider(height: 24),
          _buildMetricRow('Total Messages', '1,234', ''),
          const Divider(height: 24),
          _buildMetricRow('Users Who Chatted', '156', '78%'),
          const Divider(height: 24),
          _buildMetricRow('Avg. Messages/User', '7.9', ''),
          const Divider(height: 24),
          _buildMetricRow('Peak Activity Time', '2:30 PM', ''),
          const Divider(height: 24),
          _buildMetricRow('Average Rating', '4.2 / 5.0', '⭐⭐⭐⭐'),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, String extra) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.namaDarkGray,
          ),
        ),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.namaNavyBlue,
              ),
            ),
            if (extra.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                extra,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.namaMediumGray,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
