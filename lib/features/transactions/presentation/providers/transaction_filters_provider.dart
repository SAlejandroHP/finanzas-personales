import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TransactionFilters {
  final String? status;
  final String? accountId;
  final String? categoryId;
  final double? minAmount;
  final double? maxAmount;
  final DateTimeRange? dateRange;

  TransactionFilters({
    this.status,
    this.accountId,
    this.categoryId,
    this.minAmount,
    this.maxAmount,
    this.dateRange,
  });

  TransactionFilters copyWith({
    String? status,
    String? accountId,
    String? categoryId,
    double? minAmount,
    double? maxAmount,
    DateTimeRange? dateRange,
  }) {
    return TransactionFilters(
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      dateRange: dateRange ?? this.dateRange,
    );
  }

  void reset() {
    // This will be handled by the provider state reset
  }
}

final transactionFiltersProvider = StateProvider<TransactionFilters>((ref) => TransactionFilters());
