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
  });
}

class NmeaParser {
  static NmeaData? parse(String line) {
    if (!line.startsWith("\$")) return null;
    
    if (line.contains("GGA")) {
       return _parseGGA(line);
    } else if (line.contains("GST")) {
       return _parseGST(line);
    }
    return null;
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
