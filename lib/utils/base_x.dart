import 'dart:convert' show Codec, Converter;
import 'dart:math' show log;
import 'dart:typed_data' show Uint8List;

class BaseXDecoder extends Converter<String, Uint8List> {
  String alphabet;
  late Uint8List _baseMap;

  BaseXDecoder(this.alphabet) {
    _baseMap = Uint8List(256);
    _baseMap.fillRange(0, _baseMap.length, 255);
    for (var i = 0; i < alphabet.length; i++) {
      var xc = alphabet.codeUnitAt(i);
      if (_baseMap[xc] != 255) {
        throw FormatException('${alphabet[i]} is ambiguous');
      }
      _baseMap[xc] = i;
    }
  }

  @override
  Uint8List convert(String input) {
    if (input.isEmpty) {
      return Uint8List(0);
    }
    var psz = 0;

    /// Skip leading spaces.
    if (input[psz] == ' ') {
      return Uint8List(0);
    }

    /// Skip and count leading '1's.
    var zeroes = 0;
    var length = 0;
    while (input[psz] == alphabet[0]) {
      zeroes++;
      psz++;
    }

    /// Allocate enough space in big-endian base256 representation.
    var size = (((input.length - psz) * (log(alphabet.length) / log(256))) + 1).toInt();
    var b256 = Uint8List(size);

    /// Process the characters.
    while (psz < input.length && input[psz].isNotEmpty) {
      /// Decode character
      var carry = _baseMap[input[psz].codeUnitAt(0)];

      /// Invalid character
      if (carry == 255) {
        return Uint8List(0);
      }
      var i = 0;
      for (var it3 = size - 1; (carry != 0 || i < length) && (it3 != -1); it3--, i++) {
        carry += (alphabet.length * b256[it3]);
        b256[it3] = (carry % 256);
        carry = (carry ~/ 256);
      }
      if (carry != 0) {
        throw FormatException('Non-zero carry');
      }
      length = i;
      psz++;
    }

    /// Skip trailing spaces.
    if (psz < input.length && input[psz] == ' ') {
      return Uint8List(0);
    }

    /// Skip leading zeroes in b256.
    var it4 = size - length;
    while (it4 != size && b256[it4] == 0) {
      it4++;
    }
    var vch = Uint8List(zeroes + (size - it4));
    if (zeroes != 0) {
      vch.fillRange(0, zeroes, 0x00);
    }
    var j = zeroes;
    while (it4 != size) {
      vch[j++] = b256[it4++];
    }
    return vch;
  }
}

class BaseXEncoder extends Converter<Uint8List, String> {
  final String alphabet;

  BaseXEncoder(this.alphabet);

  @override
  String convert(Uint8List bytes) {
    if (bytes.isEmpty) {
      return '';
    }

    var zeroes = 0;
    var length = 0;
    var begin = 0;
    var end = bytes.length;
    while (begin != end && bytes[begin] == 0) {
      begin++;
      zeroes++;
    }

    /// Allocate enough space in big-endian base58 representation.
    var size = ((end - begin) * (log(256) / log(alphabet.length)) + 1).toInt();
    var b58 = Uint8List(size);

    /// Process the bytes.
    while (begin != end) {
      var carry = bytes[begin];

      /// Apply "b58 = b58 * 256 + ch".
      var i = 0;
      for (var it1 = size - 1; (carry != 0 || i < length) && (it1 != -1); it1--, i++) {
        carry += (256 * b58[it1]);
        b58[it1] = (carry % alphabet.length);
        carry = (carry ~/ alphabet.length);
      }
      if (carry != 0) {
        throw FormatException('Non-zero carry');
      }
      length = i;
      begin++;
    }

    /// Skip leading zeroes in base58 result.
    var it2 = size - length;
    while (it2 != size && b58[it2] == 0) {
      it2++;
    }

    /// Translate the result into a string.
    var str = ''.padLeft(zeroes, alphabet[0]);
    for (; it2 < size; ++it2) {
      str += alphabet[b58[it2]];
    }
    return str;
  }
}

class BaseXCodec extends Codec<Uint8List, String> {
  String alphabet;
  late BaseXEncoder _encoder;
  late BaseXDecoder _decoder;

  BaseXCodec(this.alphabet);

  @override
  Converter<Uint8List, String> get encoder {
    _encoder = BaseXEncoder(alphabet);
    return _encoder;
  }

  @override
  Converter<String, Uint8List> get decoder {
    _decoder = BaseXDecoder(alphabet);
    return _decoder;
  }
}
