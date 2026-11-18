import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/entities.dart';
import '../models/product_performance_model.dart';
import '../services/report_service.dart';

enum PerformancePeriod {
  today('Today'),
  last7Days('Last 7 days'),
  last30Days('Last 30 days'),
  thisMonth('This month');

  const PerformancePeriod(this.label);
  final String label;

  DateTime start(DateTime now) => switch (this) {
        PerformancePeriod.today => DateTime(now.year, now.month, now.day),
        PerformancePeriod.last7Days =>
          DateTime(now.year, now.month, now.day - 6),
        PerformancePeriod.last30Days =>
          DateTime(now.year, now.month, now.day - 29),
        PerformancePeriod.thisMonth => DateTime(now.year, now.month),
      };

  DateTime end(DateTime now) => DateTime(now.year, now.month, now.day + 1);
}

class OwnerViewModel extends ChangeNotifier {
  OwnerViewModel(this.service, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _productsSubscription = service.watchProducts().listen(
      (products) {
        _products = products;
        _recalculate();
      },
      onError: _onError,
    );
    _watchSales();
  }

  final ReportService service;
  final DateTime Function() _clock;
  StreamSubscription<List<Product>>? _productsSubscription;
  StreamSubscription<List<Sale>>? _salesSubscription;
  List<Product>? _products;
  List<Sale>? _sales;
  ProductPerformanceReport? report;
  PerformancePeriod period = PerformancePeriod.last30Days;
  Object? error;

  bool get loading => report == null && error == null;

  void selectPeriod(PerformancePeriod value) {
    if (period == value) return;
    period = value;
    report = null;
    error = null;
    _sales = null;
    notifyListeners();
    _watchSales();
  }

  void _watchSales() {
    _salesSubscription?.cancel();
    final now = _clock();
    _salesSubscription =
        service.watchSales(period.start(now), period.end(now)).listen((sales) {
      _sales = sales;
      _recalculate();
    }, onError: _onError);
  }

  void _recalculate() {
    if (_products == null || _sales == null) return;
    report = ProductPerformanceReport.fromRecords(_products!, _sales!);
    error = null;
    notifyListeners();
  }

  void _onError(Object failure) {
    error = failure;
    report = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _productsSubscription?.cancel();
    _salesSubscription?.cancel();
    super.dispose();
  }
}
