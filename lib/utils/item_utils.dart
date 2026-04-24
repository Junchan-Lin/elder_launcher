String formatItemId(String id) {
  if (id.contains('|')) {
    return id.split('|')[0];
  }
  return id;
}
