class Drink {
  final String id;
  final String name;
  final String category;
  final double price;
  final String imageUrl;
  final bool isPopular;
  final bool isInStock;
  final List<CustomizationOption>
  customizations; // <-- NEW: List of customizations

  Drink({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.imageUrl,
    this.isPopular = false,
    this.isInStock = true,
    this.customizations = const [], // Default to empty list
  });
}

// --- NEW MODEL FOR CUSTOMIZATIONS ---
class CustomizationOption {
  final String id; // e.g., "extra_shot"
  final String name; // e.g., "Extra Shot"
  final double price; // e.g., 0.50
  final List<String> choices; // e.g., ["Yes", "No"]

  CustomizationOption({
    required this.id,
    required this.name,
    required this.price,
    required this.choices,
  });
}
