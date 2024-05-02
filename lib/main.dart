import 'dart:io';
import 'dart:typed_data';

import 'extension.dart';

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    print('Usage: dart main.dart <file.ndf>');
    return;
  }

  String file = arguments[0];
  if (!File(file).existsSync()) {
    print('File not found: $file');
    return;
  }

  Map<String, dynamic> nox = readNox(file);
  print('Start time: ${nox['start']}');
  print('End time: ${nox['end']}');
  print('Data length: ${nox['data'].length}');
  // ... 추가 처리 ...
}

Map<String, dynamic> readNox(String file) {
  Map<String, dynamic> nox = {
    'file': file,
    't': [],
    'data': [],
    'start': [],
    'end': [],
    'gap': [],
    'samplingRateDouble': []
  };

  RandomAccessFile f = File(file).openSync(mode: FileMode.read);
  Uint8List header = f.readSync(4);

  if (header[0] != 78 || header[1] != 79 || header[2] != 88 || header[3] != 3) {
    f.closeSync();
    throw Exception('Not an NDF file, should start with NOX');
  }

  while (!f.isEOF()) {
    int typ = f.readUint16();
    int len = f.readUint32();

    switch (typ) {
      case 144:
        nox['field144Pos'] = f.positionSync();
        nox['field144'] = f.readDoubleSync();
        break;
      case 1:
        List<int> d = f.readSyncChunk(len ~/ 2);
        nox['hash'] = String.fromCharCodes(d);
        break;
      case 512:
        List<int> d = f.readSyncChunk(len ~/ 2);
        String dateStr = String.fromCharCodes(d);
        nox['start'].add(DateTime.parse(dateStr).millisecondsSinceEpoch / 1000);
        if (nox['start'].length > 1) {
          nox['gap'].add((nox['start'].last - nox['end'].last) * 24 * 3600);
        }
        break;
      case 256:
        nox['header_pos'] = f.positionSync();
        List<int> d = f.readSyncChunk(len ~/ 2);
        nox['header_uint16'] = d;
        nox['header'] = String.fromCharCodes(d.where((i) => i != 0));
        // ... XML 파싱 코드 ...
        break;
      case 513:
        switch (nox['Format']) {
          case 'Byte':
            List<int> d = f.readSyncChunk(len);
            nox['data'].addAll(muLaw2Linear(d).map((e) => e * nox['Scale'] + nox['Offset']));
            break;
          case 'ByteMuLaw':
            List<int> d = f.readSyncChunk(len);
            nox['data'].addAll(muLaw2Linear(d).map((e) => e * nox['Scale'] + nox['Offset']));
            break;
          case 'Int16':
            List<int> d = f.readSyncChunk(len ~/ 2);
            nox['data'].addAll(d.map((e) => e * nox['Scale'] + nox['Offset']));
            break;
          case 'Int32':
            List<int> d = f.readSyncChunk(len ~/ 4);
            nox['data'].addAll(d.map((e) => e * nox['Scale'] + nox['Offset']));
            break;
          default:
            throw Exception('Unsupported format ${nox['Format']}');
        }
        if (len > 0) {
          nox['t'].addAll(List.generate(nox['data'].length - nox['t'].length, (i) => nox['start'].last + i / 24 / 3600 / nox['SamplingRate']));
          nox['end'].add(nox['t'].last);
        } else {
          print('Length 0');
        }
        break;
      case 514:
        nox['samplingRateDoublePos'] = f.positionSync();
        nox['samplingRateDouble'].add(f.readDoubleSync());
        break;
      default:
        nox['field${typ}'] = f.readSyncChunk(len);
        print('Unknown type $typ, len $len');
    }
  }

  f.closeSync();
  return nox;
}

List<double> muLaw2Linear(List<int> data) {
  const int muLawBias = 0x84;
  const double muLawClip = 32635.0;
  const List<double> muLawTable = [
    -32124.0, -31100.0, -30076.0, -29052.0, -28028.0, -27004.0, -25980.0,
    -24956.0, -23932.0, -22908.0, -21884.0, -20860.0, -19836.0, -18812.0,
    -17788.0, -16764.0, -15996.0, -15228.0, -14460.0, -13692.0, -12924.0,
    -12156.0, -11388.0, -10620.0, -9852.0, -9084.0, -8316.0, -7548.0,
    -6780.0, -6012.0, -5244.0, -4476.0, -3708.0, -2940.0, -2172.0, -1404.0,
    -636.0, 132.0, 900.0, 1668.0, 2436.0, 3204.0, 3972.0, 4740.0, 5508.0,
    6276.0, 7044.0, 7812.0, 8580.0, 9348.0, 10116.0, 10884.0, 11652.0,
    12420.0, 13188.0, 13956.0, 14724.0, 15492.0, 16260.0, 17028.0, 17796.0,
    18564.0, 19332.0, 20100.0, 20868.0, 21636.0, 22404.0, 23172.0, 23940.0,
    24708.0, 25476.0, 26244.0, 27012.0, 27780.0, 28548.0, 29316.0, 30084.0,
    30852.0, 31620.0
  ];

  return data.map((e) {
    int mu = (e & 0xFF).toSigned(8);
    int sign = (mu & 0x80) >> 7;
    int position = (mu & 0x7F) ^ muLawBias;
    double value;

    if (position >= muLawTable.length) {
      value = muLawClip;
    } else {
      value = muLawTable[position];
    }

    return (sign != 0 ? -value : value);
  }).toList();
}