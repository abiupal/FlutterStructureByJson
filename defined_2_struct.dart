import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:typed_data';

class Define2struct {
  int lastReadBytes = 0;
  late Map<String, dynamic> _defined; //構造体定義

  //構造体定義を読み込み
  Future<String> _loadJsonDefined(final String jsonFile) async {
    String jsonString = await rootBundle.loadString(jsonFile);
    return jsonString;
  }

  String _getStructFormat(
      final String endian, final String datatype, final int bytesize) {
    String targetFormat = endian;
    String format = '';
    int formatSize = bytesize;

    //データ型からフォーマット文字とデータ件数を算出
    if ('char' == datatype) {
      format = 'c';
    } else if ('unsigned char' == datatype) {
      format = 'B';
    } else if ('short' == datatype) {
      format = 'h';
      formatSize = formatSize ~/ 2;
    } else if ('unsigned short' == datatype) {
      format = 'H';
      formatSize = formatSize ~/ 2;
    } else if ('long' == datatype) {
      format = 'l';
      formatSize = formatSize ~/ 4;
    } else if ('unsigned long' == datatype) {
      format = 'L';
      formatSize = formatSize ~/ 4;
    } else if ('long long' == datatype) {
      format = 'q';
      formatSize = formatSize ~/ 8;
    } else if ('unsigned long long' == datatype) {
      format = 'Q';
      formatSize = formatSize ~/ 8;
    } else if ('float' == datatype) {
      format = 'f';
      formatSize = formatSize ~/ 4;
    } else if ('double' == datatype) {
      format = 'd';
      formatSize = formatSize ~/ 8;
    } else if ('int' == datatype) {
      format = 'i';
      formatSize = formatSize ~/ 4;
    } else if ('unsigned int' == datatype) {
      format = 'I';
      formatSize = formatSize ~/ 4;
    } else {
      throw Exception('Unknown datatype:$datatype');
    }

    //データ件数分のフォーマットを生成
    for (var i = 0; i < formatSize; i++) {
      targetFormat += format;
    }
    return targetFormat;
  }

  dynamic _unpack(final String format, final ByteData data) {
    //エンディアン指定
    Endian e = (format[0] == '<') ? Endian.little : Endian.big;
    dynamic value;
    int dataLength = format.length - 1;
    switch (format[1]) {
      case 'c':
        value = '';
        break;
      case 'B':
        value = Uint8List(dataLength);
        break;
      case 'h':
        value = Int16List(dataLength);
        break;
      case 'H':
        value = Uint16List(dataLength);
        break;
      case 'l':
      case 'i':
        value = Int32List(dataLength);
        break;
      case 'L':
      case 'I':
        value = Uint32List(dataLength);
        break;
      case 'q':
        value = Int64List(dataLength);
        break;
      case 'Q':
        value = Uint64List(dataLength);
        break;
      case 'f':
        value = Float32List(dataLength);
        break;
      case 'd':
        value = Float64List(dataLength);
        break;
    }
    for (var i = 1; i < (format.length); i++) {
      final int index = i - 1;
      switch (format[i]) {
        case 'c':
          value += String.fromCharCode(data.getInt8(index));
          break;
        case 'B':
          value[index] = (data.getUint8(index));
          break;
        case 'h':
          value[index] = (data.getInt16(index, e));
          break;
        case 'H':
          value[index] = (data.getUint16(index, e));
          break;
        case 'l':
        case 'i':
          value[index] = (data.getInt32(index, e));
          break;
        case 'L':
        case 'I':
          value[index] = (data.getUint32(index, e));
          break;
        case 'q':
          value[index] = (data.getInt64(index, e));
          break;
        case 'Q':
          value[index] = (data.getUint64(index, e));
          break;
        case 'f':
          value[index] = (data.getFloat32(index, e));
          break;
        case 'd':
          value[index] = (data.getFloat64(index, e));
          break;
      }
    }
    return value;
  }

  // JSON形式をマッピング
  void _setDefinedString(final String jsonString) async {
    Map<String, dynamic> jsonData = await json.decode(jsonString);
    _defined = jsonData;
  }

  //------------------------------------------------------------------
  // コンストラクタ
  Define2struct(final String jsonName) {
    String jsonFile = 'assets/$jsonName.json';
    _loadJsonDefined(jsonFile).then((value) => _setDefinedString(value));
  }
  // 構造体定義メンバの一覧
  List<dynamic> getOrderList(final String targetKey) {
    return _defined[targetKey]['_order'];
  }

  // 構造体定義の取得
  dynamic getValue(final String targetKey, final String member) {
    return _defined[targetKey]['_members'][member]['_value'];
  }

  void read(
      final String targetKey, final ByteBuffer bytesData, final int offset,
      {final int pointerBytesize = 0}) {
    // 構造体定義
    // 対象キー(target_key)
    // 構造体定義メンバの情報(byteサイズ/データ型/グループ先頭からのオフセット)
    // 構造体定義のメンバの順序
    final String endian = _defined['_Endian'];
    final Map<String, dynamic> targetDef = _defined[targetKey]['_members'];
    final List<dynamic> targetOrder = getOrderList(targetKey);

    // value に読込み
    lastReadBytes = 0;
    for (final String valueKey in targetOrder) {
      //メンバ変数の情禹歩を取得
      Map<String, dynamic> info = targetDef[valueKey];
      int bytesize = 0;
      if (valueKey[0] == '*') {
        //可変長の場合、引数指定
        bytesize = (pointerBytesize - lastReadBytes);
      } else {
        bytesize = info['_bytesize'];
      }
      //メンバ変数の情報を、Pythonのstructに従う文字列を生成
      final String format =
          _getStructFormat(endian, info['_datatype'], bytesize);
      //formatの内容に従い、値を取得
      dynamic value = _unpack(
          format, bytesData.asByteData(offset + lastReadBytes, bytesize));
      //取り出した値を保持
      _defined[targetKey]['_members'][valueKey]['_value'] = value;

      //読み込みバイト数を加算
      lastReadBytes += bytesize;
    }
  }
}
