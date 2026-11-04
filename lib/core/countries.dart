/// Countries for the phone field. Ghana is the default and needs exactly 10 digits
/// typed the local way (024 123 4567), which becomes +233 24 123 4567.
///
/// [digits] is how many digits people type locally; [dropZero] means the local
/// leading 0 is dropped after the country code (Ghana, Nigeria, UK...).
class Country {
  const Country(this.name, this.flag, this.code, this.digits, {this.dropZero = true, this.example = ''});
  final String name, flag, code, example;
  final int digits;
  final bool dropZero;

  /// "+233" plus the national number, or null if the local number doesn't fit.
  String? toE164(String typed) {
    final d = typed.replaceAll(RegExp(r'\D'), '');
    if (d.length != digits) return null;
    if (dropZero) {
      if (!d.startsWith('0')) return null;
      return '+$code${d.substring(1)}';
    }
    return '+$code$d';
  }

  String get hint => example.isEmpty ? '$digits digits' : example;
}

const ghana = Country('Ghana', '🇬🇭', '233', 10, example: '024 123 4567');

const countries = <Country>[
  ghana,
  Country('Nigeria', '🇳🇬', '234', 11, example: '080 1234 5678'),
  Country('Togo', '🇹🇬', '228', 8, dropZero: false, example: '90 12 34 56'),
  Country("Côte d'Ivoire", '🇨🇮', '225', 10, dropZero: false, example: '07 12 34 56 78'),
  Country('Burkina Faso', '🇧🇫', '226', 8, dropZero: false, example: '70 12 34 56'),
  Country('Kenya', '🇰🇪', '254', 10, example: '0712 345678'),
  Country('South Africa', '🇿🇦', '27', 10, example: '071 234 5678'),
  Country('United Kingdom', '🇬🇧', '44', 11, example: '07123 456789'),
  Country('United States', '🇺🇸', '1', 10, dropZero: false, example: '201 555 0123'),
];
