enum Riwayah {
  hafs('hafs', 'hafs-kufi', 6236);

  const Riwayah(this.id, this.numbering, this.totalAyahs);

  final String id;
  final String numbering;
  final int totalAyahs;

  void validateAyah(int id) {
    RangeError.checkValueInInterval(id, 1, totalAyahs, 'ayahId');
  }
}
