enum Category {
  shopeefood('shopeefood', 'ShopeeFood'),
  spx('spx', 'SPX');

  const Category(this.value, this.label);

  final String value;
  final String label;

  static Category fromString(String raw) {
    if (raw.trim().toLowerCase() == 'spx') {
      return Category.spx;
    }
    return Category.shopeefood;
  }
}
