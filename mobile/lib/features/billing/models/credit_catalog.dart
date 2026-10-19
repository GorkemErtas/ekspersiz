import 'package:intl/intl.dart';

class StorePrice {
  const StorePrice(this.amount, this.currency, this.label);
  final double amount;
  final String currency;
  final String label;
  String format(double value) => NumberFormat.currency(
    locale: 'tr_TR',
    name: currency,
    symbol: currency == 'TRY' ? 'TL' : currency,
    decimalDigits: 2,
  ).format(value);
}

class CreditProduct {
  CreditProduct.fromJson(Map<String, dynamic> json)
    : id = json['productId'] as String,
      resource = json['resource'] as String,
      quantity = (json['quantity'] as num).toInt(),
      business = json['business'] == true,
      referencePrice = (json['referencePrice'] as num).toDouble();
  final String id;
  final String resource;
  final int quantity;
  final bool business;
  final double referencePrice;
}

class CreditAccount {
  CreditAccount.fromJson(Map<String, dynamic> json)
    : canPurchase = json['canPurchase'] == true,
      owner = json['owner'] == true || json['canPurchase'] == true,
      usedSlots = (json['usedSlots'] as num).toInt(),
      totalSlots = (json['totalSlots'] as num).toInt(),
      balances = Map<String, dynamic>.from(json['balances'] as Map);
  final bool canPurchase;
  final bool owner;
  final int usedSlots;
  final int totalSlots;
  final Map<String, dynamic> balances;
  int available(String resource) =>
      ((balances[resource] as Map?)?['available'] as num?)?.toInt() ?? 0;
  int periodic(String resource) =>
      ((balances[resource] as Map?)?['periodic'] as num?)?.toInt() ?? 0;
}

class CreditOverview {
  CreditOverview.fromJson(Map<String, dynamic> json)
    : personal = CreditAccount.fromJson(
        Map<String, dynamic>.from(json['personal'] as Map),
      ),
      company = json['company'] is Map
          ? CreditAccount.fromJson(
              Map<String, dynamic>.from(json['company'] as Map),
            )
          : null,
      products = (json['products'] as List)
          .map(
            (v) => CreditProduct.fromJson(Map<String, dynamic>.from(v as Map)),
          )
          .toList();
  final CreditAccount personal;
  final CreditAccount? company;
  final List<CreditProduct> products;
}

/// Only compare actual store amounts in the same currency; never parse localized labels.
class PriceSavings {
  PriceSavings(StorePrice price, StorePrice single, int quantity)
    : regular = single.amount * quantity,
      amount = ((single.amount * quantity - price.amount) * 100).round() / 100,
      percent = (1 - price.amount / (single.amount * quantity)) * 100;
  final double regular;
  final double amount;
  final double percent;
  String get percentLabel => (percent - percent.round()).abs() < .005
      ? percent.round().toString()
      : percent.toStringAsFixed(2).replaceAll('.', ',');
  static PriceSavings? compare(
    StorePrice? price,
    StorePrice? single,
    int quantity,
  ) {
    if (price == null ||
        single == null ||
        price.currency != single.currency ||
        !price.amount.isFinite ||
        !single.amount.isFinite ||
        price.amount < 0 ||
        single.amount <= 0 ||
        quantity <= 1) {
      return null;
    }
    final result = PriceSavings(price, single, quantity);
    return result.amount > 0 ? result : null;
  }
}
