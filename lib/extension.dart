import 'dart:io';
import 'dart:typed_data';

extension RandomAccessFileX on RandomAccessFile {
  bool isEOF() {
    return positionSync() == lengthSync();
  }

  int readUint16() {
    Uint8List bytes = readSync(2);
    return bytes.buffer.asByteData().getUint16(0, Endian.little);
  }

  int readUint32() {
    Uint8List bytes = readSync(4);
    return bytes.buffer.asByteData().getUint32(0, Endian.little);
  }

  double readDoubleSync() {
    Uint8List bytes = readSync(8);
    return bytes.buffer.asByteData().getFloat64(0, Endian.little);
  }

  List<int> readSyncChunk(int length) {
    Uint8List bytes = readSync(length);
    return bytes.map((byte) => byte).toList();
  }
}
