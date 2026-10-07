/// Generates a Bakong KHQR payment string, following the public
/// EMVCo Merchant-Presented QR structure that Bakong's KHQR is built on
/// (see: https://bakong.nbc.gov.kh/download/KHQR/integration/
/// "KHQR Content Guideline"). Tag-Length-Value (TLV) encoded, CRC16
/// checksum at the end.
///
/// ⚠️ IMPORTANT — for this QR to actually be scannable and receive real
/// money in a bank app, [bakongAccountId] MUST be a real Bakong account
/// ID (the "khqr@bank" style handle Bakong gives you after you register,
/// for free, at https://bakong.nbc.gov.kh). Until then, this generates a
/// structurally valid KHQR string for demo/prototype purposes — most
/// wallet apps will show "invalid merchant" if the account doesn't exist.
class KhqrGenerator {
  static const currencyCodeUsd = '840';
  static const currencyCodeKhr = '116';

  /// Builds the full KHQR string. [amount] uses 2 decimal places.
  /// [currency] is either 'USD' or 'KHR'.
  static String generate({
    required String bakongAccountId,
    required String merchantName,
    String merchantCity = 'Phnom Penh',
    required double amount,
    String currency = 'USD',
    String? billNumber,
  }) {
    final buffer = StringBuffer();

    void addTag(String tag, String value) {
      final length = value.length.toString().padLeft(2, '0');
      buffer.write('$tag$length$value');
    }

    // 00: Payload Format Indicator
    addTag('00', '01');
    // 01: Point of Initiation Method — "12" = dynamic (amount is fixed here)
    addTag('01', '12');

    // 29: Merchant Account Info — sub-tag 00 holds the Bakong account ID.
    final sub00 =
        '00${bakongAccountId.length.toString().padLeft(2, '0')}$bakongAccountId';
    addTag('29', sub00);

    // 52: Merchant Category Code (default: misc/retail = 5999)
    addTag('52', '5999');
    // 53: Transaction Currency (ISO 4217 numeric)
    addTag('53',
        currency.toUpperCase() == 'KHR' ? currencyCodeKhr : currencyCodeUsd);
    // 54: Transaction Amount
    addTag('54', amount.toStringAsFixed(2));
    // 58: Country Code
    addTag('58', 'KH');
    // 59: Merchant Name (max 25 chars per spec)
    final name =
        merchantName.length > 25 ? merchantName.substring(0, 25) : merchantName;
    addTag('59', name);
    // 60: Merchant City
    addTag('60', merchantCity);

    // 62: Additional Data Field Template (optional — Bill Number sub-tag 01)
    if (billNumber != null && billNumber.isNotEmpty) {
      final sub01 =
          '01${billNumber.length.toString().padLeft(2, '0')}$billNumber';
      addTag('62', sub01);
    }

    // 63: CRC — tag+length prefix is included in the checksum input,
    // the checksum value itself is appended after computing.
    buffer.write('6304');
    final crc = _crc16Ccitt(buffer.toString());
    buffer.write(crc);

    return buffer.toString();
  }

  /// CRC-16/CCITT-FALSE (poly 0x1021, init 0xFFFF) — the checksum
  /// algorithm mandated by the EMVCo QR / KHQR specification.
  static String _crc16Ccitt(String data) {
    int crc = 0xFFFF;
    for (int i = 0; i < data.length; i++) {
      crc ^= (data.codeUnitAt(i) << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }
}
