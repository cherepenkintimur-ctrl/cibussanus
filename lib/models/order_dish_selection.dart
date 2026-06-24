import 'dish.dart';

class OrderDishSelection {
  final Dish dish;
  int quantity;

  OrderDishSelection({
    required this.dish,
    this.quantity = 1,
  });

  double get total => dish.price * quantity;
}
