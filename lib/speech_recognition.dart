import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'dart:convert';

class RecognitionSegment {
  List<String> alternatives;
  String value;
  double confidence;
  double timestamp;
  double duration;

  RecognitionSegment(
      {required this.alternatives,
      required this.confidence,
      required this.duration,
      required this.timestamp,
      required this.value});

  factory RecognitionSegment.fromJson(dynamic map) {
    var arrayText = List.from(map["alternatives"]);
    List<String> alternatives = List.from(arrayText);
    return RecognitionSegment(
        alternatives: alternatives,
        value: map["value"] as String,
        confidence: map["confidence"] as double,
        timestamp: map["timestamp"] as double,
        duration: map["duration"] as double);
  }

  Map<String, dynamic> toJson() => {
        'alternatives': alternatives,
        'value': value,
        'confidence': confidence,
        'timestamp': timestamp,
        'duration': duration
      };
}

class RecognitionInfo {
  List<RecognitionSegment> segments;
  String sourceURL;
  bool isFinal;
  String text;

  RecognitionInfo(
      {required this.text,
      required this.isFinal,
      required this.sourceURL,
      required this.segments});

  factory RecognitionInfo.fromJson(dynamic map) {
    var segmentsmap = List.from(map["segments"]);
    List<RecognitionSegment> segments = segmentsmap
        .map((segmap) => RecognitionSegment.fromJson(segmap))
        .toList();
    return RecognitionInfo(
        isFinal: map["isFinal"] as bool,
        sourceURL: map["sourceURL"] as String,
        text: map["text"] as String,
        segments: segments);
  }

  Map<String, dynamic> toJson() => {
        'segments': segments,
        'sourceURL': sourceURL,
        'isFinal': isFinal,
        'text': text
      };
}

class RecognitionLanguage {
  String name;
  String code;
  bool rtl;

  RecognitionLanguage(
      {required this.name, required this.code, required this.rtl});

  factory RecognitionLanguage.fromJson(Map<String, dynamic> json) {
    return RecognitionLanguage(
      name: json['name'] as String,
      code: json['code'] as String,
      rtl: json['rtl'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'rtl': rtl,
    };
  }
}

class RecognitionSupportedLanguages {
  List<String> preferred;
  List<RecognitionLanguage> supported;

  RecognitionSupportedLanguages(
      {required this.preferred, required this.supported});

  factory RecognitionSupportedLanguages.fromJson(Map<String, dynamic> json) {
    return RecognitionSupportedLanguages(
      preferred: (json['preferred'] as List<dynamic>).cast<String>(),
      supported: (json['supported'] as List<dynamic>)
          .map((e) => RecognitionLanguage.fromJson(
              ((e as Map<dynamic, dynamic>).cast<String, dynamic>())))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferred': preferred,
      'supported': supported.map((e) => e.toJson()).toList(),
    };
  }
}

typedef void AvailabilityHandler(bool result);
typedef void StringResultHandler(String text);
typedef void RecognitionInfoHandler(RecognitionInfo result);

/// the channel to control the speech recognition
class SpeechRecognition {
  static const MethodChannel _channel =
      const MethodChannel('speech_recognition');

  static final SpeechRecognition _speech = new SpeechRecognition._internal();

  factory SpeechRecognition() => _speech;

  SpeechRecognition._internal() {
    _channel.setMethodCallHandler(_platformCallHandler);
  }

  late AvailabilityHandler availabilityHandler;

  late StringResultHandler currentLocaleHandler;
  late RecognitionInfoHandler recognitionResultHandler;

  late VoidCallback recognitionStartedHandler;

  late RecognitionInfoHandler recognitionCompleteHandler;

  late VoidCallback errorHandler;

  /// ask for speech  recognizer permission
  Future activate() => _channel.invokeMethod("speech.activate");

  /// start listening
  Future listen({required String locale}) =>
      _channel.invokeMethod("speech.listen", locale);

  Future listenAudio({required String audioPath, required String locale}) =>
      _channel.invokeMethod("speech.listenAudio", [audioPath, locale]);

  /// cancel speech
  Future cancel() => _channel.invokeMethod("speech.cancel");

  /// stop listening
  Future stop() => _channel.invokeMethod("speech.stop");

  /// stop listening
  static Future<RecognitionSupportedLanguages> supportedLanguages() async {
    var supportedMap = await _channel.invokeMethod("speech.supportedLanguages");
    Map<String, dynamic> supportedJson =
        new Map<String, dynamic>.from(supportedMap);

    return RecognitionSupportedLanguages.fromJson(supportedJson);
  }

  Future _platformCallHandler(MethodCall call) async {
    //print("_platformCallHandler call ${call.method} ${call.arguments}");
    switch (call.method) {
      case "speech.onSpeechAvailability":
        availabilityHandler(call.arguments);
        break;
      case "speech.onCurrentLocale":
        currentLocaleHandler(call.arguments);
        break;
      case "speech.onSpeech":
        var result = RecognitionInfo.fromJson(call.arguments);
        recognitionResultHandler(result);
        break;
      case "speech.onRecognitionStarted":
        recognitionStartedHandler();
        break;
      case "speech.onRecognitionComplete":
        var result = RecognitionInfo.fromJson(call.arguments);
        recognitionCompleteHandler(result);
        break;
      case "speech.onError":
        errorHandler();
        break;
      default:
        print('Unknowm method ${call.method} ');
    }
  }

  // define a method to handle availability / permission result
  void setAvailabilityHandler(AvailabilityHandler handler) =>
      availabilityHandler = handler;

  // define a method to handle recognition result
  void setRecognitionResultHandler(RecognitionInfoHandler handler) =>
      recognitionResultHandler = handler;

  // define a method to handle native call
  void setRecognitionStartedHandler(VoidCallback handler) =>
      recognitionStartedHandler = handler;

  // define a method to handle native call
  void setRecognitionCompleteHandler(RecognitionInfoHandler handler) =>
      recognitionCompleteHandler = handler;

  void setCurrentLocaleHandler(StringResultHandler handler) =>
      currentLocaleHandler = handler;

  void setErrorHandler(VoidCallback handler) => errorHandler = handler;
}
