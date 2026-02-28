import 'models/drink.dart';

final List<Drink> dummyDrinks = [
  // Cold Drinks
  Drink(id: 'd1', name: 'Iced Americano', category: 'cold', price: 2.50, imageUrl: 'https://i.imgur.com/2vKf6gU.jpeg'),
  Drink(id: 'd2', name: 'Cold Brew Latte', category: 'cold', price: 3.50, imageUrl: 'https://i.imgur.com/J9p3R0Q.jpeg'),
  Drink(id: 'd3', name: 'Iced Tea', category: 'cold', price: 2.00, imageUrl: 'https://i.imgur.com/E3N8U2g.jpeg'),
  Drink(id: 'd4', name: 'Lemonade Mint', category: 'cold', price: 2.75, imageUrl: 'https://i.imgur.com/3aL5s0h.jpeg'),

  // Ice (Blended) Drinks
  Drink(id: 'd5', name: 'Mocha Frappe', category: 'ice', price: 4.50, imageUrl: 'https://i.imgur.com/k6PzHd3.jpeg'),
  Drink(id: 'd6', name: 'Strawberry Smoothie', category: 'ice', price: 4.00, imageUrl: 'https://i.imgur.com/5sL5Q6U.jpeg'),
  Drink(id: 'd7', name: 'Mango Tango', category: 'ice', price: 4.25, imageUrl: 'https://i.imgur.com/8yG9sJt.jpeg'),
  Drink(id: 'd8', name: 'Vanilla Bean Blizzard', category: 'ice', price: 4.75, imageUrl: 'https://i.imgur.com/uQ2p5rW.jpeg'),
];