class PhoneCountry {
  final String name;
  final String flag;
  final String dialCode;
  final List<int> groups;

  const PhoneCountry(this.name, this.flag, this.dialCode, this.groups);

  int get maxDigits => groups.fold(0, (total, group) => total + group);

  static const countries = [
    PhoneCountry('Россия', '🇷🇺', '7', [3, 3, 2, 2]),
    PhoneCountry('Казахстан', '🇰🇿', '7', [3, 3, 2, 2]),
    PhoneCountry('США', '🇺🇸', '1', [3, 3, 4]),
    PhoneCountry('Канада', '🇨🇦', '1', [3, 3, 4]),
    PhoneCountry('Великобритания', '🇬🇧', '44', [4, 3, 3]),
    PhoneCountry('Германия', '🇩🇪', '49', [3, 3, 4]),
    PhoneCountry('Франция', '🇫🇷', '33', [1, 2, 2, 2, 2]),
    PhoneCountry('Беларусь', '🇧🇾', '375', [2, 3, 2, 2]),
    PhoneCountry('Украина', '🇺🇦', '380', [2, 3, 2, 2]),
    PhoneCountry('Армения', '🇦🇲', '374', [3, 2, 2, 2]),
    PhoneCountry('Грузия', '🇬🇪', '995', [3, 2, 2, 2]),
    PhoneCountry('Турция', '🇹🇷', '90', [3, 3, 2, 2]),
    PhoneCountry('Узбекистан', '🇺🇿', '998', [2, 3, 2, 2]),
    PhoneCountry('Израиль', '🇮🇱', '972', [2, 3, 4]),
    PhoneCountry('Индия', '🇮🇳', '91', [5, 5]),
    PhoneCountry('Китай', '🇨🇳', '86', [3, 4, 4]),
    PhoneCountry('Япония', '🇯🇵', '81', [2, 4, 4]),
    PhoneCountry('Испания', '🇪🇸', '34', [3, 2, 2, 2]),
    PhoneCountry('Италия', '🇮🇹', '39', [3, 3, 4]),
    PhoneCountry('Польша', '🇵🇱', '48', [3, 3, 3]),
    PhoneCountry('Австралия', '🇦🇺', '61', [3, 3, 3]),
  ];
}
