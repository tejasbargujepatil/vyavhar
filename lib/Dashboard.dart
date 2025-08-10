import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vyapar/sales_notifier.dart';
import 'package:vyapar/purchase_notifier.dart';
import 'package:vyapar/db_helper.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
  final DBHelper dbHelper = DBHelper();
  Map<String, double> yearlySales = {};
  Map<String, double> monthlySales = {};
  Map<String, double> monthlyExpenses = {};
  Map<String, double> invoiceStatus = {};
  double yearlyExpenses = 0;
  int employeeCount = 0;
  double stockValue = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int touchedIndex = -1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
    fetchDashboardData();
    Provider.of<PurchaseNotifier>(context, listen: false).refresh();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> fetchDashboardData() async {
    final db = await dbHelper.database;
    DateTime now = DateTime.now();
    String currentYear = now.year.toString();

    final salesData = await db.rawQuery('SELECT date, amount FROM sales');
    yearlySales.clear();
    monthlySales.clear();
    for (var row in salesData) {
      final date = DateTime.parse(row['date'] as String);
      final year = DateFormat('yyyy').format(date);
      final month = DateFormat('MMM yyyy').format(date);
      yearlySales[year] = (yearlySales[year] ?? 0) + (row['amount'] as double);
      monthlySales[month] = (monthlySales[month] ?? 0) + (row['amount'] as double);
    }

    final expenseData = await db.rawQuery('SELECT date, amount FROM expenses');
    monthlyExpenses.clear();
    yearlyExpenses = 0;
    for (var row in expenseData) {
      final date = DateTime.parse(row['date'] as String);
      final month = DateFormat('MMM yyyy').format(date);
      monthlyExpenses[month] = (monthlyExpenses[month] ?? 0) + (row['amount'] as double);
      if (date.year.toString() == currentYear) {
        yearlyExpenses += (row['amount'] as double);
      }
    }

    final invoiceData = await db.rawQuery('SELECT status, total_amount FROM invoices');
    invoiceStatus.clear();
    for (var row in invoiceData) {
      final status = row['status'] as String? ?? 'Unknown';
      final amount = row['total_amount'] is num ? (row['total_amount'] as num).toDouble() : 0.0;
      invoiceStatus[status] = (invoiceStatus[status] ?? 0) + amount;
    }

    final employeeResult = await db.rawQuery('SELECT COUNT(*) as count FROM employees');
    employeeCount = employeeResult.first['count'] as int? ?? 0;

    final stockData = await db.rawQuery('SELECT quantity, buy_price FROM inventory');
    stockValue = 0;
    for (var row in stockData) {
      final qty = row['quantity'] as int? ?? 0;
      final price = row['buy_price'] is num ? (row['buy_price'] as num).toDouble() : 0.0;
      stockValue += qty * price;
    }

    setState(() {});
  }

  Map<String, double> predictFutureData(Map<String, double> historicalData, int monthsAhead) {
    final Map<String, double> predictions = {};
    final sortedKeys = historicalData.keys.toList()
      ..sort((a, b) => DateFormat('MMM yyyy').parse(a).compareTo(DateFormat('MMM yyyy').parse(b)));
    final values = sortedKeys.map((k) => historicalData[k]!).toList();
    final n = values.length;
    if (n < 2) return {};

    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += values[i];
      sumXY += i * values[i];
      sumXX += i * i;
    }
    final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;

    final lastDate = DateFormat('MMM yyyy').parse(sortedKeys.last);
    for (int i = 1; i <= monthsAhead; i++) {
      final futureDate = DateTime(lastDate.year, lastDate.month + i);
      final futureMonth = DateFormat('MMM yyyy').format(futureDate);
      final predictedValue = intercept + slope * (n + i - 1);
      predictions[futureMonth] = predictedValue > 0 ? predictedValue : 0;
    }
    return predictions;
  }

  Widget buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, color.withOpacity(0.1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
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

  Widget buildBarChart(Map<String, double> data, String title, Color barColor) {
    final keys = data.keys.toList();
    final values = data.values.toList();
    final maxY = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) * 1.3 : 1000.0;
    return Card(
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: MediaQuery.of(context).size.width > 600 ? 300 : 250,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barGroups: List.generate(keys.length, (index) {
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: values[index],
                            width: 20,
                            gradient: LinearGradient(
                              colors: [barColor, barColor.withOpacity(0.7)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: maxY,
                              color: Colors.grey[200],
                            ),
                          ),
                        ],
                      );
                    }),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            int idx = value.toInt();
                            if (idx < 0 || idx >= keys.length) return Container();
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              angle: 45 * 3.1415926535 / 180,
                              child: Text(
                                keys[idx],
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              NumberFormat.compact().format(value),
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 5,
                      checkToShowHorizontalLine: (value) => true,
                    ),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                        getTooltipItem: (group, groupIdx, rod, rodIdx) {
                          return BarTooltipItem(
                            '₹${NumberFormat.currency(locale: 'en_IN', symbol: '').format(rod.toY)}',
                            GoogleFonts.poppins(color: Colors.white),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildPieChart() {
    final total = invoiceStatus.values.fold(0.0, (sum, value) => sum + value);
    final sections = invoiceStatus.entries.map((entry) {
      final percentage = total > 0 ? (entry.value / total * 100).toStringAsFixed(1) : '0.0';
      final color = entry.key == 'Invoiced' ? Colors.green[600] : Colors.orange[600];
      return PieChartSectionData(
        value: entry.value,
        color: color,
        title: '$percentage%',
        radius: touchedIndex == invoiceStatus.keys.toList().indexOf(entry.key) ? 80 : 70,
        titleStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Invoice Status",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: MediaQuery.of(context).size.width > 600 ? 280 : 220,
                child: PieChart(
                  PieChartData(
                    sections: sections.isNotEmpty
                        ? sections
                        : [
                            PieChartSectionData(
                              value: 1,
                              color: Colors.grey[300],
                              title: 'No Data',
                              radius: 70,
                              titleStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
                            ),
                          ],
                    sectionsSpace: 3,
                    centerSpaceRadius: 50,
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            touchedIndex = -1;
                            return;
                          }
                          touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: invoiceStatus.entries.map((entry) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: entry.key == 'Invoiced' ? Colors.green[600] : Colors.orange[600],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.key}: ₹${NumberFormat.currency(locale: 'en_IN', symbol: '').format(entry.value)}',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildLineChart() {
    final sortedSalesKeys = monthlySales.keys.toList()
      ..sort((a, b) => DateFormat('MMM yyyy').parse(a).compareTo(DateFormat('MMM yyyy').parse(b)));
    final sortedExpensesKeys = monthlyExpenses.keys.toList()
      ..sort((a, b) => DateFormat('MMM yyyy').parse(a).compareTo(DateFormat('MMM yyyy').parse(b)));
    
    final futureSales = predictFutureData(monthlySales, 3);
    final futureExpenses = predictFutureData(monthlyExpenses, 3);
    final allSales = {...monthlySales, ...futureSales};
    final allExpenses = {...monthlyExpenses, ...futureExpenses};
    final allKeys = allSales.keys.toList()
      ..sort((a, b) => DateFormat('MMM yyyy').parse(a).compareTo(DateFormat('MMM yyyy').parse(b)));
    
    final salesSpots = allKeys.asMap().entries.map((entry) {
      final index = entry.key;
      final month = entry.value;
      return FlSpot(index.toDouble(), allSales[month] ?? 0);
    }).toList();
    
    final expensesSpots = allKeys.asMap().entries.map((entry) {
      final index = entry.key;
      final month = entry.value;
      return FlSpot(index.toDouble(), allExpenses[month] ?? 0);
    }).toList();
    
    final maxY = [
      ...salesSpots.map((e) => e.y),
      ...expensesSpots.map((e) => e.y),
    ].fold<double>(0.0, (prev, el) => el > prev ? el : prev) * 1.3;

    // Fallback for maxY to prevent zero or very small values
    final safeMaxY = maxY <= 0 ? 1000.0 : maxY;
    final horizontalInterval = safeMaxY / 5 > 0 ? safeMaxY / 5 : 200.0;

    return Card(
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey[50]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Income vs. Expenditure (with Forecast)",
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: MediaQuery.of(context).size.width > 600 ? 320 : 260,
                child: allKeys.isEmpty
                    ? Center(
                        child: Text(
                          'No data available',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      )
                    : LineChart(
                        LineChartData(
                          lineBarsData: [
                            LineChartBarData(
                              spots: salesSpots,
                              isCurved: true,
                              gradient: LinearGradient(
                                colors: [Colors.green[600]!, Colors.green[400]!],
                              ),
                              barWidth: 3,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.green,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green[100]!.withOpacity(0.3),
                                    Colors.green[100]!.withOpacity(0.0)
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                            LineChartBarData(
                              spots: expensesSpots,
                              isCurved: true,
                              gradient: LinearGradient(
                                colors: [Colors.red[600]!, Colors.red[400]!],
                              ),
                              barWidth: 3,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.red,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.red[100]!.withOpacity(0.3),
                                    Colors.red[100]!.withOpacity(0.0)
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= allKeys.length) return Container();
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    angle: 45 * 3.1415926535 / 180,
                                    child: Text(
                                      allKeys[idx],
                                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    NumberFormat.compact().format(value),
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
                                  );
                                },
                              ),
                            ),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: horizontalInterval,
                            checkToShowHorizontalLine: (value) => true,
                          ),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              tooltipBgColor: Colors.blueGrey.withOpacity(0.9),
                              getTooltipItems: (touchedSpots) {
                                return touchedSpots.map((spot) {
                                  final month = allKeys[spot.x.toInt()];
                                  return LineTooltipItem(
                                    '$month\n₹${NumberFormat.currency(locale: 'en_IN', symbol: '').format(spot.y)}',
                                    GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                                  );
                                }).toList();
                              },
                            ),
                          ),
                          maxY: safeMaxY,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[600]!, Colors.green[400]!],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Sales', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red[600]!, Colors.red[400]!],
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Expenses', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPurchases = context.watch<PurchaseNotifier>().value;
    final totalSales = context.watch<SalesNotifier>().value;
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth < 600 ? 1 : screenWidth < 900 ? 2 : 4;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        // title: Text(
        //   "Business Dashboard",
        //   style: GoogleFonts.poppins(
        //     fontSize: 24,
        //     fontWeight: FontWeight.w700,
        //     color: Colors.white,
        //   ),
        // ),
        backgroundColor: const Color(0xFF1E3A8A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: fetchDashboardData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white),
            onPressed: () {},
            tooltip: 'Help',
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: RefreshIndicator(
          onRefresh: fetchDashboardData,
          color: const Color(0xFF3B82F6),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: screenWidth < 600 ? 3 : 2,
                    children: [
                      buildStatCard(
                        "Active Employees",
                        employeeCount.toString(),
                        Icons.people,
                        Colors.blue[600]!,
                      ),
                      buildStatCard(
                        "Stock-in-Hand",
                        "₹${NumberFormat.currency(locale: 'en_IN', symbol: '').format(stockValue)}",
                        Icons.inventory,
                        Colors.orange[600]!,
                      ),
                      buildStatCard(
                        "Yearly Expenses",
                        "₹${NumberFormat.currency(locale: 'en_IN', symbol: '').format(yearlyExpenses)}",
                        Icons.account_balance_wallet,
                        Colors.red[600]!,
                      ),
                      buildStatCard(
                        "Total Sales",
                        "₹${NumberFormat.currency(locale: 'en_IN', symbol: '').format(totalSales)}",
                        Icons.trending_up,
                        Colors.green[600]!,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (screenWidth < 600)
                    Column(
                      children: [
                        buildBarChart(yearlySales, "Yearly Sales Trend", Colors.blue[600]!),
                        const SizedBox(height: 24),
                        buildPieChart(),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: buildBarChart(yearlySales, "Yearly Sales Trend", Colors.blue[600]!)),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: buildPieChart()),
                      ],
                    ),
                  const SizedBox(height: 24),
                  if (screenWidth < 600)
                    Column(
                      children: [
                        buildBarChart(monthlySales, "Monthly Sales Trend", Colors.green[600]!),
                        const SizedBox(height: 24),
                        buildBarChart(monthlyExpenses, "Expenses Overview", Colors.red[600]!),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: buildBarChart(monthlySales, "Monthly Sales Trend", Colors.green[600]!)),
                        const SizedBox(width: 20),
                        Expanded(child: buildBarChart(monthlyExpenses, "Expenses Overview", Colors.red[600]!)),
                      ],
                    ),
                  const SizedBox(height: 24),
                  buildLineChart(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
































































































































// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:vyapar/sales_notifier.dart';
// import 'package:vyapar/purchase_notifier.dart';
// import 'db_helper.dart';

// class Dashboard extends StatefulWidget {
//   const Dashboard({super.key});

//   @override
//   State<Dashboard> createState() => _DashboardState();
// }

// class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
//   final DBHelper dbHelper = DBHelper();
//   Map<String, double> yearlySales = {};
//   Map<String, double> monthlySales = {};
//   Map<String, double> monthlyExpenses = {};
//   Map<String, double> invoiceStatus = {};
//   double yearlyExpenses = 0;
//   int employeeCount = 0;
//   double stockValue = 0;
//   late AnimationController _animationController;
//   late Animation<double> _fadeAnimation;
//   int touchedIndex = -1; // For pie chart interactivity

//   @override
//   void initState() {
//     super.initState();
//     _animationController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );
//     _fadeAnimation = CurvedAnimation(
//       parent: _animationController,
//       curve: Curves.easeInOut,
//     );
//     _animationController.forward();
//     fetchDashboardData();
//     Provider.of<PurchaseNotifier>(context, listen: false).refresh();
//   }

//   @override
//   void dispose() {
//     _animationController.dispose();
//     super.dispose();
//   }

//   Future<void> fetchDashboardData() async {
//     final db = await dbHelper.database;
//     DateTime now = DateTime.now();
//     String currentYear = now.year.toString();

//     // Fetch sales data
//     final salesData = await db.rawQuery('SELECT date, amount FROM sales');
//     yearlySales.clear();
//     monthlySales.clear();
//     for (var row in salesData) {
//       final date = DateTime.parse(row['date'] as String);
//       final year = DateFormat('yyyy').format(date);
//       final month = DateFormat('MMM yyyy').format(date);
//       yearlySales[year] = (yearlySales[year] ?? 0) + (row['amount'] as double);
//       monthlySales[month] = (monthlySales[month] ?? 0) + (row['amount'] as double);
//     }

//     // Fetch expenses data
//     final expenseData = await db.rawQuery('SELECT date, amount FROM expenses');
//     monthlyExpenses.clear();
//     yearlyExpenses = 0;
//     for (var row in expenseData) {
//       final date = DateTime.parse(row['date'] as String);
//       final month = DateFormat('MMM yyyy').format(date);
//       monthlyExpenses[month] = (monthlyExpenses[month] ?? 0) + (row['amount'] as double);
//       if (date.year.toString() == currentYear) {
//         yearlyExpenses += (row['amount'] as double);
//       }
//     }

//     // Fetch invoice status
//     final invoiceData = await db.rawQuery('SELECT status, total_amount FROM invoices');
//     invoiceStatus.clear();
//     for (var row in invoiceData) {
//       final status = row['status'] as String? ?? 'Unknown';
//       final amount = row['total_amount'] is num ? (row['total_amount'] as num).toDouble() : 0.0;
//       invoiceStatus[status] = (invoiceStatus[status] ?? 0) + amount;
//     }

//     // Fetch employee count
//     final employeeResult = await db.rawQuery('SELECT COUNT(*) as count FROM employees');
//     employeeCount = employeeResult.first['count'] as int? ?? 0;

//     // Fetch stock value
//     final stockData = await db.rawQuery('SELECT quantity, buy_price FROM inventory');
//     stockValue = 0;
//     for (var row in stockData) {
//       final qty = row['quantity'] as int? ?? 0;
//       final price = row['buy_price'] is num ? (row['buy_price'] as num).toDouble() : 0.0;
//       stockValue += qty * price;
//     }

//     setState(() {});
//   }

//   // Simple linear regression for forecasting
//   Map<String, double> predictFutureData(Map<String, double> historicalData, int monthsAhead) {
//     final Map<String, double> predictions = {};
//     final sortedKeys = historicalData.keys.toList()
//       ..sort((a, b) => DateFormat('MMM yyyy').parse(a).compareTo(DateFormat('MMM yyyy').parse(b)));
//     final values = sortedKeys.map((k) => historicalData[k]!).toList();
//     final n = values.length;
//     if (n < 2) return {};

//     // Calculate slope and intercept for linear regression
//     double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
//     for (int i = 0; i < n; i++) {
//       sumX += i;
//       sumY += values[i];
//       sumXY += i * values[i];
//       sumXX += i * i;
//     }
//     final slope = (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX);
//     final intercept = (sumY - slope * sumX) / n;

//     // Predict future months
//     final lastDate = DateFormat('MMM yyyy').parse(sortedKeys.last);
//     for (int i = 1; i <= monthsAhead; i++) {
//       final futureDate = DateTime(lastDate.year, lastDate.month + i);
//       final futureMonth = DateFormat('MMM yyyy').format(futureDate);
//       final predictedValue = intercept + slope * (n + i - 1);
//       predictions[futureMonth] = predictedValue > 0 ? predictedValue : 0;
//     }
//     return predictions;
//   }

//   Widget buildStatCard(String label, String value, IconData icon, Color color) {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(icon, color: color, size: 24),
//                 const SizedBox(width: 8),
//                 Text(
//                   label,
//                   style: GoogleFonts.poppins(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w500,
//                     color: Colors.grey[600],
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Text(
//               value,
//               style: GoogleFonts.poppins(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black87,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget buildBarChart(Map<String, double> data, String title, Color barColor) {
//     final keys = data.keys.toList();
//     final values = data.values.toList();
//     final maxY = values.isNotEmpty ? values.reduce((a, b) => a > b ? a : b) * 1.2 : 1000.0;
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: GoogleFonts.poppins(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black87,
//               ),
//             ),
//             const SizedBox(height: 16),
//             SizedBox(
//               height: 250,
//               child: BarChart(
//                 BarChartData(
//                   alignment: BarChartAlignment.spaceAround,
//                   maxY: maxY,
//                   barGroups: List.generate(keys.length, (index) {
//                     return BarChartGroupData(
//                       x: index,
//                       barRods: [
//                         BarChartRodData(
//                           toY: values[index],
//                           width: 16,
//                           color: barColor,
//                           borderRadius: BorderRadius.circular(4),
//                         ),
//                       ],
//                     );
//                   }),
//                   titlesData: FlTitlesData(
//                     bottomTitles: AxisTitles(
//                       sideTitles: SideTitles(
//                         showTitles: true,
//                         reservedSize: 40,
//                         getTitlesWidget: (value, meta) {
//                           int idx = value.toInt();
//                           if (idx < 0 || idx >= keys.length) return Container();
//                           return SideTitleWidget(
//                             axisSide: meta.axisSide,
//                             angle: 45 * 3.1415926535 / 180,
//                             child: Text(
//                               keys[idx],
//                               style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                     leftTitles: AxisTitles(
//                       sideTitles: SideTitles(
//                         showTitles: true,
//                         reservedSize: 40,
//                         getTitlesWidget: (value, meta) {
//                           return Text(
//                             NumberFormat.compact().format(value),
//                             style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
//                           );
//                         },
//                       ),
//                     ),
//                     rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//                     topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//                   ),
//                   gridData: const FlGridData(show: true, drawVerticalLine: false),
//                   borderData: FlBorderData(show: false),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget buildPieChart() {
//     final total = invoiceStatus.values.fold(0.0, (sum, value) => sum + value);
//     final sections = invoiceStatus.entries.map((entry) {
//       final percentage = total > 0 ? (entry.value / total * 100).toStringAsFixed(1) : '0.0';
//       final color = entry.key == 'Invoiced' ? Colors.green[600] : Colors.orange[600];
//       return PieChartSectionData(
//         value: entry.value,
//         color: color,
//         title: '$percentage%',
//         radius: touchedIndex == invoiceStatus.keys.toList().indexOf(entry.key) ? 70 : 60,
//         titleStyle: GoogleFonts.poppins(
//           fontSize: 14,
//           fontWeight: FontWeight.bold,
//           color: Colors.white,
//         ),
//       );
//     }).toList();

//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               "Invoice Status",
//               style: GoogleFonts.poppins(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black87,
//               ),
//             ),
//             const SizedBox(height: 16),
//             SizedBox(
//               height: MediaQuery.of(context).size.width > 600 ? 250 : 200, // Responsive height
//               child: PieChart(
//                 PieChartData(
//                   sections: sections.isNotEmpty ? sections : [
//                     PieChartSectionData(
//                       value: 1,
//                       color: Colors.grey[300],
//                       title: 'No Data',
//                       radius: 60,
//                       titleStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.black54),
//                     ),
//                   ],
//                   sectionsSpace: 2,
//                   centerSpaceRadius: 40,
//                   pieTouchData: PieTouchData(
//                     touchCallback: (FlTouchEvent event, pieTouchResponse) {
//                       setState(() {
//                         if (!event.isInterestedForInteractions ||
//                             pieTouchResponse == null ||
//                             pieTouchResponse.touchedSection == null) {
//                           touchedIndex = -1;
//                           return;
//                         }
//                         touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
//                       });
//                     },
//                   ),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//             // Legend
//             Wrap(
//               spacing: 16,
//               children: invoiceStatus.entries.map((entry) {
//                 return Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Container(
//                       width: 16,
//                       height: 16,
//                       color: entry.key == 'Invoiced' ? Colors.green[600] : Colors.orange[600],
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       '${entry.key}: ₹${NumberFormat.currency(locale: 'en_IN', symbol: '').format(entry.value)}',
//                       style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
//                     ),
//                   ],
//                 );
//               }).toList(),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget buildLineChart() {
//     final sortedSalesKeys = monthlySales.keys.toList()
//       ..sort((a, b) => DateFormat('MMM yyyy').parse(a).compareTo(DateFormat('MMM yyyy').parse(b)));
//     final sortedExpensesKeys = monthlyExpenses.keys.toList()
//       ..sort((a, b) => DateFormat('MMM yyyy').parse(a).compareTo(DateFormat('MMM yyyy').parse(b)));
    
//     // Predict future data
//     final futureSales = predictFutureData(monthlySales, 3);
//     final futureExpenses = predictFutureData(monthlyExpenses, 3);
//     final allSales = {...monthlySales, ...futureSales};
//     final allExpenses = {...monthlyExpenses, ...futureExpenses};
//     final allKeys = allSales.keys.toList()
//       ..sort((a, b) => DateFormat('MMM yyyy').parse(a).compareTo(DateFormat('MMM yyyy').parse(b)));
    
//     final salesSpots = allKeys.asMap().entries.map((entry) {
//       final index = entry.key;
//       final month = entry.value;
//       return FlSpot(index.toDouble(), allSales[month] ?? 0);
//     }).toList();
    
//     final expensesSpots = allKeys.asMap().entries.map((entry) {
//       final index = entry.key;
//       final month = entry.value;
//       return FlSpot(index.toDouble(), allExpenses[month] ?? 0);
//     }).toList();
//     final maxY = [
//   ...salesSpots.map((e) => e.y),
//   ...expensesSpots.map((e) => e.y),
// ].fold<double>(0.0, (prev, el) => el > prev ? el : prev) * 1.2;

//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       child: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               "Income vs. Expenditure (with Forecast)",
//               style: GoogleFonts.poppins(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black87,
//               ),
//             ),
//             const SizedBox(height: 16),
//             SizedBox(
//               height: MediaQuery.of(context).size.width > 600 ? 300 : 250, // Responsive height
//               child: LineChart(
//                 LineChartData(
//                   lineBarsData: [
//                     LineChartBarData(
//                       spots: salesSpots,
//                       isCurved: true,
//                       color: Colors.green[600],
//                       barWidth: 2,
//                       dotData: FlDotData(show: true),
//                       belowBarData: BarAreaData(
//                         show: true,
//                         color: Colors.green[100]!.withOpacity(0.3),
//                       ),
//                     ),
//                     LineChartBarData(
//                       spots: expensesSpots,
//                       isCurved: true,
//                       color: Colors.red[600],
//                       barWidth: 2,
//                       dotData: FlDotData(show: true),
//                       belowBarData: BarAreaData(
//                         show: true,
//                         color: Colors.red[100]!.withOpacity(0.3),
//                       ),
//                     ),
//                   ],
//                   titlesData: FlTitlesData(
//                     bottomTitles: AxisTitles(
//                       sideTitles: SideTitles(
//                         showTitles: true,
//                         reservedSize: 40,
//                         getTitlesWidget: (value, meta) {
//                           final idx = value.toInt();
//                           if (idx < 0 || idx >= allKeys.length) return Container();
//                           return SideTitleWidget(
//                             axisSide: meta.axisSide,
//                             angle: 45 * 3.1415926535 / 180,
//                             child: Text(
//                               allKeys[idx],
//                               style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                     leftTitles: AxisTitles(
//                       sideTitles: SideTitles(
//                         showTitles: true,
//                         reservedSize: 40,
//                         getTitlesWidget: (value, meta) {
//                           return Text(
//                             NumberFormat.compact().format(value),
//                             style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700]),
//                           );
//                         },
//                       ),
//                     ),
//                     rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//                     topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//                   ),
//                   gridData: const FlGridData(show: true),
//                   borderData: FlBorderData(show: false),
//                   lineTouchData: LineTouchData(
//                     touchTooltipData: LineTouchTooltipData(
//                       tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
//                       getTooltipItems: (touchedSpots) {
//                         return touchedSpots.map((spot) {
//                           final month = allKeys[spot.x.toInt()];
//                           return LineTooltipItem(
//                             '$month\n₹${NumberFormat.currency(locale: 'en_IN', symbol: '').format(spot.y)}',
//                             GoogleFonts.poppins(color: Colors.white),
//                           );
//                         }).toList();
//                       },
//                     ),
//                   ),
//                   maxY: maxY,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//             // Legend
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Row(
//                   children: [
//                     Container(width: 16, height: 16, color: Colors.green[600]),
//                     const SizedBox(width: 8),
//                     Text('Sales', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
//                   ],
//                 ),
//                 const SizedBox(width: 16),
//                 Row(
//                   children: [
//                     Container(width: 16, height: 16, color: Colors.red[600]),
//                     const SizedBox(width: 8),
//                     Text('Expenses', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[700])),
//                   ],
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final totalPurchases = context.watch<PurchaseNotifier>().value;
//     final screenWidth = MediaQuery.of(context).size.width;
//     final totalSales = context.watch<SalesNotifier>().value;
//     final crossAxisCount = screenWidth < 600 ? 1 : screenWidth < 900 ? 2 : 3;

//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F7FA),
//       appBar: AppBar(
//         title: Text(
//           "Business Dashboard",
//           style: GoogleFonts.poppins(
//             fontSize: 22,
//             fontWeight: FontWeight.w600,
//             color: Colors.white,
//           ),
//         ),
//         backgroundColor: const Color(0xFF2C3E50),
//         elevation: 0,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.help, color: Colors.white),
//             onPressed: () {},
//           ),
//         ],
//       ),
//       body: FadeTransition(
//         opacity: _fadeAnimation,
//         child: RefreshIndicator(
//           onRefresh: fetchDashboardData,
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   GridView.count(
//                     shrinkWrap: true,
//                     physics: const NeverScrollableScrollPhysics(),
//                     crossAxisCount: crossAxisCount,
//                     crossAxisSpacing: 16,
//                     mainAxisSpacing: 16,
//                     children: [
//                       buildStatCard(
//                         "Active Employees",
//                         employeeCount.toString(),
//                         Icons.people,
//                         Colors.blue[600]!,
//                       ),
//                       buildStatCard(
//                         "Stock-in-Hand Value",
//                         "₹${NumberFormat.currency(locale: 'en_IN', symbol: '').format(stockValue)}",
//                         Icons.inventory,
//                         Colors.orange[600]!,
//                       ),
//                       buildStatCard(
//                         "Yearly Expenses",
//                         "₹${NumberFormat.currency(locale: 'en_IN', symbol: '').format(yearlyExpenses)}",
//                         Icons.account_balance_wallet,
//                         Colors.red[600]!,
//                       ),
//                       buildStatCard(
//                         "Total Sales",
//                         "₹${NumberFormat.currency(locale: 'en_IN', symbol: '').format(totalSales)}",
//                         Icons.trending_up,
//                         Colors.blueGrey[600]!,
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
//                   if (screenWidth < 600)
//                     Column(
//                       children: [
//                         buildBarChart(yearlySales, "Yearly Sales Trend", Colors.blue[600]!),
//                         const SizedBox(height: 16),
//                         buildPieChart(),
//                       ],
//                     )
//                   else
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Expanded(child: buildBarChart(yearlySales, "Yearly Sales Trend", Colors.blue[600]!)),
//                         const SizedBox(width: 16),
//                         Expanded(child: buildPieChart()),
//                       ],
//                     ),
//                   const SizedBox(height: 16),
//                   if (screenWidth < 600)
//                     Column(
//                       children: [
//                         buildBarChart(monthlySales, "Monthly Sales Trend", Colors.green[600]!),
//                         const SizedBox(height: 16),
//                         buildBarChart(monthlyExpenses, "Expenses Overview", Colors.red[600]!),
//                       ],
//                     )
//                   else
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Expanded(child: buildBarChart(monthlySales, "Monthly Sales Trend", Colors.green[600]!)),
//                         const SizedBox(width: 16),
//                         Expanded(child: buildBarChart(monthlyExpenses, "Expenses Overview", Colors.red[600]!)),
//                       ],
//                     ),
//                   const SizedBox(height: 16),
//                   buildLineChart(),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }















