enum Type{
  cash(id: 0, name: 'Наличные'),
  card(id: 1, name: 'Карта');

  const Type({required this.id, required this.name});
  final int id;
  final String name;
}