import 'models.dart';

/// FR-A4: start from a typical item list so setup takes minutes, not an hour.
/// Prices are rough Berekuso/Ashesi-area guesses - the owner edits them.
final Map<String, List<Item>> templates = {
  'Rice & provisions seller': [
    Item(id: 'rice5', name: 'Rice (5 kg bag)', unit: 'bag', cost: 92, price: 115, reorder: 6),
    Item(id: 'rice25', name: 'Rice (25 kg bag)', unit: 'bag', cost: 430, price: 500, reorder: 2),
    Item(id: 'oil', name: 'Cooking oil (1 L)', unit: 'bottle', cost: 32, price: 40, reorder: 4),
    Item(id: 'paste', name: 'Tomato paste (tin)', unit: 'tin', cost: 9, price: 12, reorder: 10),
    Item(id: 'sugar', name: 'Sugar (1 kg)', unit: 'pack', cost: 14, price: 18, reorder: 5),
    Item(id: 'eggs', name: 'Eggs', unit: 'crate', cost: 62, price: 75, reorder: 2),
  ],
  'Food vendor / chop bar': [
    Item(id: 'jollof', name: 'Jollof rice', unit: 'plate', cost: 15, price: 25, perishable: true),
    Item(id: 'waakye', name: 'Waakye', unit: 'plate', cost: 12, price: 20, perishable: true),
    Item(id: 'friedrice', name: 'Fried rice', unit: 'plate', cost: 16, price: 25, perishable: true),
    Item(id: 'kelewele', name: 'Kelewele', unit: 'portion', cost: 5, price: 10, perishable: true),
    Item(id: 'sobolo', name: 'Sobolo', unit: 'bottle', cost: 3, price: 7, reorder: 10, perishable: true),
    Item(id: 'water', name: 'Sachet water (bag)', unit: 'bag', cost: 8, price: 12, reorder: 5),
  ],
  'Campus snack shop': [
    Item(id: 'pie', name: 'Meat pie', unit: 'piece', cost: 6, price: 10, perishable: true),
    Item(id: 'yoghurt', name: 'Yoghurt', unit: 'cup', cost: 5, price: 8, reorder: 10, perishable: true),
    Item(id: 'biscuits', name: 'Biscuits', unit: 'pack', cost: 3, price: 5, reorder: 15),
    Item(id: 'noodles', name: 'Indomie', unit: 'pack', cost: 4, price: 6, reorder: 20),
    Item(id: 'drink', name: 'Soft drink', unit: 'bottle', cost: 7, price: 10, reorder: 12),
  ],
  'Start from scratch': [],
};
