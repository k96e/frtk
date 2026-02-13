class NmeaData {
  final String? time;
  final String? latitude;
  final String? longitude;
  final double? latitudeDeg;
  final double? longitudeDeg;
  final String? altitude;
  final String? satellites;
  final String? quality;
  final String? hdop;
  
  final String? rms;
  final String? latStdDev;
  final String? lonStdDev;
  final String? altStdDev;
  final String? ellipseSemiMajor;
  final String? ellipseSemiMinor;
  final String? ellipseMajorOrientation;
  final List<SatelliteInfo>? satelliteUpdates;
  final String? gsvSourceKey;
  final int? gsvTotalMessages;
  final int? gsvMessageNumber;

  NmeaData({
    this.time,
    this.latitude,
    this.longitude,
    this.latitudeDeg,
    this.longitudeDeg,
    this.altitude,
    this.satellites,
    this.quality,
    this.hdop,
    this.rms,
    this.latStdDev,
    this.lonStdDev,
    this.altStdDev,
    this.ellipseSemiMajor,
    this.ellipseSemiMinor,
    this.ellipseMajorOrientation,
    this.satelliteUpdates,
    this.gsvSourceKey,
    this.gsvTotalMessages,
    this.gsvMessageNumber,
  });
}

class SatelliteInfo {
  final String sourceKey;
  final String system;
  final int prn;
  final int? elevation;
  final int? azimuth;
  final int? snr;
  final String? signalId;
  final String uniqueKey; // Cache the key

  SatelliteInfo({
    required this.sourceKey,
    required this.system,
    required this.prn,
    this.elevation,
    this.azimuth,
    this.snr,
    this.signalId,
  }) : uniqueKey = '$sourceKey:$prn';
}

class NmeaParser {
  static NmeaData? parse(String line) {
    if (!line.startsWith("\$")) return null;

    final noChecksum = line.split('*').first;
    final fields = noChecksum.split(',');
    if (fields.isEmpty || fields[0].length < 6) return null;
    final sentenceType = fields[0].substring(3);

    if (sentenceType == "GGA") {
       return _parseGGA(line);
    } else if (sentenceType == "GST") {
       return _parseGST(line);
    } else if (sentenceType == "GSV") {
      return _parseGSV(line);
    }
    return null;
  }

  static NmeaData? _parseGSV(String line) {
    final noChecksum = line.split('*').first;
    final parts = noChecksum.split(',');
    if (parts.length < 4 || parts[0].length < 6) return null;

    final talker = parts[0].substring(1, 3);
    final totalMessages = int.tryParse(parts[1]) ?? 0;
    final messageNumber = int.tryParse(parts[2]) ?? 0;

    String? signalId;
    int satFieldsEnd = parts.length;
    final payloadCount = parts.length - 4;
    if (payloadCount > 0 && payloadCount % 4 == 1) {
      signalId = parts.last.isEmpty ? null : parts.last;
      satFieldsEnd -= 1;
    }

    final satellites = <SatelliteInfo>[];
    
    final computedSourceKey = '${talker}_${signalId ?? "0"}';
    final systemName = _talkerToSystem(talker);
    final signalName = _getSignalName(talker, signalId);

    for (int i = 4; i + 3 < satFieldsEnd; i += 4) {
      final prn = int.tryParse(parts[i]);
      if (prn == null) continue;
      satellites.add(
        SatelliteInfo(
          sourceKey: computedSourceKey,
          system: systemName,
          prn: prn,
          elevation: int.tryParse(parts[i + 1]),
          azimuth: int.tryParse(parts[i + 2]),
          snr: int.tryParse(parts[i + 3]),
          signalId: signalName,
        ),
      );
    }

    return NmeaData(
      satelliteUpdates: satellites,
      gsvSourceKey: computedSourceKey,
      gsvTotalMessages: totalMessages,
      gsvMessageNumber: messageNumber,
    );
  }

  static NmeaData? _parseGST(String line) {
      // $GNGST,075806.00,1.5,1.0,0.8,45,0.5,0.6,1.2*CS
      List<String> parts = line.split(',');
      if (parts.length > 8) {
        String rms = parts[2];
        String semiMajor = parts[3];
        String semiMinor = parts[4];
        String orientation = parts[5];
        String stdLat = parts[6];
        String stdLon = parts[7];
        String stdAlt = parts[8];
        
        if (stdAlt.contains('*')) {
          stdAlt = stdAlt.split('*')[0];
        }

        return NmeaData(
          rms: rms.isEmpty ? "--" : rms,
          latStdDev: stdLat.isEmpty ? "--" : stdLat,
          lonStdDev: stdLon.isEmpty ? "--" : stdLon,
          altStdDev: stdAlt.isEmpty ? "--" : stdAlt,
          ellipseSemiMajor: semiMajor.isEmpty ? "--" : semiMajor,
          ellipseSemiMinor: semiMinor.isEmpty ? "--" : semiMinor,
          ellipseMajorOrientation: orientation.isEmpty ? "--" : orientation,
        );
      }
      return null;
  }

  static NmeaData? _parseGGA(String line) {
      // $GNGGA,075806.00,3723.2475,N,12158.3416,W,1,08,0.9,545.4,M,46.9,M,,*47
      List<String> parts = line.split(',');

      if (parts.length > 9) {
        String timeStr = parts[1];
        String rawLat = parts[2];
        String latDir = parts[3];
        String rawLon = parts[4];
        String lonDir = parts[5];
        String quality = parts[6];
        String sats = parts[7];
        String hdop = parts[8];
        String alt = parts[9];

        String? parsedTime;
        if (timeStr.length >= 6) {
          String hh = timeStr.substring(0, 2);
          String mm = timeStr.substring(2, 4);
          String ss = timeStr.substring(4, 6);
          parsedTime = "$hh:$mm:$ss";
        }
          
        String parsedQuality = _getQualityText(quality);
        String parsedSatellites = sats.isEmpty ? "0" : sats;
        String parsedHdop = hdop.isEmpty ? "--" : hdop;
        
        String? parsedLatitude;
        String? parsedLongitude;
        double? latVal;
        double? lonVal;
        String? parsedAltitude;
        if (quality != '0' && rawLat.isNotEmpty && rawLon.isNotEmpty) {
          double lat = _nmeaToDecimal(rawLat);
          if (latDir == 'S') lat = -lat;

          double lon = _nmeaToDecimal(rawLon);
          if (lonDir == 'W') lon = -lon;

          latVal = lat;
          lonVal = lon;

          parsedLatitude = "${lat.abs().toStringAsFixed(7)}° $latDir";
          parsedLongitude = "${lon.abs().toStringAsFixed(7)}° $lonDir";
          parsedAltitude = alt.isEmpty ? "--" : "$alt m";
        }
        
        return NmeaData(
          time: parsedTime,
          latitude: parsedLatitude,
          longitude: parsedLongitude,
          latitudeDeg: latVal,
          longitudeDeg: lonVal,
          altitude: parsedAltitude,
          satellites: parsedSatellites,
          quality: parsedQuality,
          hdop: parsedHdop,
        );
      }
      return null;
  }

  static String _getQualityText(String quality) {
    switch (quality) {
      case '0':
        return '无效';
      case '1':
        return 'GPS';
      case '2':
        return 'DGPS';
      case '4':
        return 'RTK固定解';
      case '5':
        return 'RTK浮点解';
      default:
        return '未知';
    }
  }

  static String? _getSignalName(String talker, String? signalId) {
    if (signalId == null || signalId.isEmpty) return null;

    switch (talker) {
      case 'GP': // GPS
        switch (signalId) {
          case '1': return 'L1 C/A';
          case '2': return 'L1 P(Y)';
          case '3': return 'L1 M';
          case '4': return 'L2 P(Y)';
          case '5': return 'L2C-M';
          case '6': return 'L2C-L';
          case '7': return 'L5 I';
          case '8': return 'L5 Q';
        }
        break;
      case 'GL': // GLONASS
        switch (signalId) {
          case '1': return 'G1 C/A';
          case '2': return 'G1 P';
          case '3': return 'G2 C/A';
          case '4': return 'G2a P';
        }
        break;
      case 'GA': // Galileo
        switch (signalId) {
          case '1': return 'E5a';
          case '2': return 'E5b';
          case '3': return 'E5a+b'; 
          case '4': return 'E6-A';
          case '5': return 'E6-B';
          case '6': return 'E6-C';
          case '7': return 'E1';
        }
        break;
      case 'GB': // BeiDou
      case 'BD':
        switch (signalId) {
          case '1': return 'B1I';
          case '2': return 'B2I';
          case '3': return 'B3I';
          case '4': return 'B1Q';
          case '5': return 'B1C';
          case '6': return 'B1A';
          case '7': return 'B2a'; 
          case '8': return 'B2b';
          case '9': return 'B2a+b';
          case 'A': return 'B3A';
          case 'B': return 'B3Q';
          case 'C': return 'B3C';
        }
        break;
       case 'GQ': // QZSS
        switch (signalId) {
          case '1': return 'L1 C/A';
          case '2': return 'L1 S';
          case '3': return 'L1 C';
          case '4': return 'L2 C';
          case '5': return 'L5';
          case '6': return 'L5 S';
        }
        break;
       case 'GI': // NavIC
        switch (signalId) { 
           case '1': return 'L5';
           case '2': return 'S';
        }
        break;
    }
    return signalId;
  }

  static String _talkerToSystem(String talker) {
    switch (talker) {
      case 'GP':
        return 'GPS';
      case 'GA':
        return 'Galileo';
      case 'GB':
      case 'BD':
        return 'BeiDou';
      case 'GL':
        return 'GLONASS';
      case 'GQ':
        return 'QZSS';
      case 'GI':
        return 'NavIC';
      case 'GN':
        return 'GNSS';
      default:
        return talker;
    }
  }

  static double _nmeaToDecimal(String nmeaPos) {
    if (nmeaPos.isEmpty) return 0.0;
    try {
      double pos = double.parse(nmeaPos);
      int degrees = (pos / 100).floor();
      double minutes = pos - (degrees * 100);
      return degrees + (minutes / 60);
    } catch (e) {
      return 0.0;
    }
  }
}
