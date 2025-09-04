class Translation {
  double left;
  double top;
  double right;
  double bottom;
  String text;

  Translation({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.text,
  });

  factory Translation.fromJson(Map<String, dynamic> json) {
    return Translation(
      left: json['left'],
      top: json['top'],
      right: json['right'],
      bottom: json['bottom'],
      text: json['text'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'left': left,
      'top': top,
      'right': right,
      'bottom': bottom,
      'text': text,
    };
  }
}