import 'package:flutter/material.dart';
import '../../models/product_performance_model.dart';
import '../../services/report_service.dart';
import '../../services/store_repository.dart';
import '../../viewmodels/owner_viewmodel.dart';
import '../../widgets/agri_ui.dart';
import '../../widgets/common.dart';
import '../../widgets/product_image_placeholder.dart';

class ProductPerformanceView extends StatefulWidget {
  const ProductPerformanceView({super.key, required this.repo});
  final StoreRepository repo;

  @override
  State<ProductPerformanceView> createState() => _ProductPerformanceViewState();
}

class _ProductPerformanceViewState extends State<ProductPerformanceView> {
  late final OwnerViewModel model =
      OwnerViewModel(FirebaseReportService(widget.repo));

  @override
  void dispose() {
    model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.repo.role != 'owner') {
      return const Center(child: Text('Owner access is required.'));
    }
    return AnimatedBuilder(
      animation: model,
      builder: (context, _) {
        final report = model.report;
        return ListView(padding: const EdgeInsets.all(16), children: [
          const AgriHero(
            title: 'Product performance',
            subtitle: 'See what sells and what needs attention',
            icon: Icons.bar_chart_rounded,
            compact: true,
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final period in PerformancePeriod.values) ...[
                ChoiceChip(
                  label: Text(period.label),
                  selected: model.period == period,
                  onSelected: (_) => model.selectPeriod(period),
                ),
                const SizedBox(width: 8),
              ],
            ]),
          ),
          if (model.error != null)
            const Card(
                child: ListTile(
              leading: Icon(Icons.error_outline),
              title: Text('Unable to load product performance'),
              subtitle: Text('Check the connection and owner access.'),
            ))
          else if (model.loading)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (report != null) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
                builder: (context, constraints) => GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: constraints.maxWidth > 500 ? 2.4 : 1.3,
                      children: [
                        AgriMetricCard(
                            title: 'Units sold',
                            value: '${report.unitsSold}',
                            icon: Icons.shopping_cart_outlined),
                        AgriMetricCard(
                            title: 'Sales revenue',
                            value: peso(report.revenue),
                            icon: Icons.payments_outlined,
                            color: const Color(0xFF1963A5),
                            background: const Color(0xFFEAF3FC)),
                        AgriMetricCard(
                            title: 'Products sold',
                            value: '${report.sellingCount}',
                            icon: Icons.trending_up_outlined),
                        AgriMetricCard(
                            title: 'No sales',
                            value: '${report.unsoldCount}',
                            icon: Icons.warning_amber_outlined,
                            color: const Color(0xFFA56700),
                            background: const Color(0xFFFFF6E5)),
                      ],
                    )),
            const AgriSectionTitle('Best sellers'),
            if (report.topSellers.isEmpty)
              const Card(
                  child: ListTile(
                      title: Text('No completed sales in this period'),
                      subtitle: Text(
                          'Completed sales will appear here automatically.')))
            else
              for (var index = 0; index < report.topSellers.length; index++)
                _productCard(report.topSellers[index],
                    rank: index + 1,
                    maxUnits: report.topSellers.first.unitsSold),
            const AgriSectionTitle('Slow and unsold products'),
            if (report.slowMovers.isEmpty)
              const Card(
                  child: ListTile(
                      title: Text('No slow movers in this period'),
                      subtitle: Text(
                          'Products with fewer sales than the top seller appear here.')))
            else
              for (final product in report.slowMovers)
                _productCard(product,
                    maxUnits: report.topSellers.isEmpty
                        ? 1
                        : report.topSellers.first.unitsSold,
                    attention: true),
            const SizedBox(height: 14),
            Text(
                'Based on completed sales only. Pending customer orders are excluded. '
                'Revenue uses the selling price saved with each sale.',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
          ],
        ]);
      },
    );
  }

  Widget _productCard(ProductPerformance product,
      {required int maxUnits, int? rank, bool attention = false}) {
    final color = attention ? const Color(0xFFA56700) : const Color(0xFF087B2B);
    return Card(
        child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ProductImagePlaceholder(size: 48, imageBase64: product.imageBase64),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(product.active ? product.category : 'Archived',
                    style: Theme.of(context).textTheme.bodySmall),
              ])),
          if (rank != null)
            CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFE8F5E9),
                child: Text('$rank',
                    style: const TextStyle(
                        color: Color(0xFF087B2B),
                        fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: Text(
                  product.unitsSold == 0
                      ? 'No sales'
                      : '${product.unitsSold} ${product.unit} sold',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700))),
          Text(peso(product.revenue),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: maxUnits == 0 ? 0 : product.unitsSold / maxUnits,
          color: color,
          minHeight: 7,
          borderRadius: BorderRadius.circular(7),
        ),
        const SizedBox(height: 6),
        Text(
            '${product.transactions} transactions • ${product.stock} ${product.unit} in stock',
            style: Theme.of(context).textTheme.bodySmall),
      ]),
    ));
  }
}
