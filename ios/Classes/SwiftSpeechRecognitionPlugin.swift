import Flutter
import UIKit
import Speech

@available(iOS 10.0, *)
public class SwiftSpeechRecognitionPlugin: NSObject, FlutterPlugin, SFSpeechRecognizerDelegate {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "speech_recognition", binaryMessenger: registrar.messenger())
    let instance = SwiftSpeechRecognitionPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private var speechChannel: FlutterMethodChannel?

  private var recognitionRequest: SFSpeechRecognitionRequest?

  private var recognitionTask: SFSpeechRecognitionTask?

  private let audioEngine = AVAudioEngine()

  init(channel:FlutterMethodChannel){
    speechChannel = channel
    super.init()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    //result("iOS " + UIDevice.current.systemVersion)
    switch (call.method) {
    case "speech.activate":
      self.activateRecognition(result: result)
    case "speech.listen":
      self.startRecognition(lang: call.arguments as! String, result: result)
    case "speech.listenAudio":
        self.startRecognitionURL(url: (call.arguments as! [String])[0], lang: (call.arguments as! [String])[1], result: result)
    case "speech.cancel":
      self.cancelRecognition(result: result)
    case "speech.stop":
      self.stopRecognition(result: result)
    case "speech.supportedLanguages":
      self.supportedLanguages(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func activateRecognition(result: @escaping FlutterResult) {
    SFSpeechRecognizer.requestAuthorization { authStatus in
      OperationQueue.main.addOperation {
        switch authStatus {
        case .authorized:
          result(true)
          self.speechChannel?.invokeMethod("speech.onCurrentLocale", arguments: "\(Locale.current.identifier)")

        case .denied:
          result(false)

        case .restricted:
          result(false)

        case .notDetermined:
          result(false)
        }
        print("SFSpeechRecognizer.requestAuthorization \(authStatus.rawValue)")
      }
    }
  }

  private func startRecognition(lang: String, result: FlutterResult) {
    print("startRecognition...")
    if audioEngine.isRunning {
      audioEngine.stop()
      if let recognitionRequestBuffer = recognitionRequest as? SFSpeechAudioBufferRecognitionRequest {
          recognitionRequestBuffer.endAudio()
      }
      result(false)
    } else {
      try! start(lang: lang)
      result(true)
    }
  }
    
    private func startRecognitionURL(url: String, lang: String, result: FlutterResult) {
    print("startRecognitionURL...")
    if audioEngine.isRunning {
      audioEngine.stop()
      if let recognitionRequestBuffer = recognitionRequest as? SFSpeechAudioBufferRecognitionRequest {
          recognitionRequestBuffer.endAudio()
    }
      result(false)
    } else {
      try! startURL(url: url, lang: lang)
      result(true)
    }
}

  private func cancelRecognition(result: FlutterResult?) {
    if let recognitionTask = recognitionTask {
      recognitionTask.cancel()
      self.recognitionTask = nil
      if let r = result {
        r(false)
      }
    }
  }

  private func stopRecognition(result: FlutterResult) {
    if audioEngine.isRunning {
      audioEngine.stop()
        if let recognitionRequestBuffer = recognitionRequest as? SFSpeechAudioBufferRecognitionRequest {
            recognitionRequestBuffer.endAudio()
        }
    }
        
    result(false)
  }
    
  private func startURL(url: String, lang: String) throws {
    cancelRecognition(result: nil)
    
    recognitionRequest = SFSpeechURLRecognitionRequest(url: URL(fileURLWithPath: url))
    
    guard let recognitionRequest = recognitionRequest else {
      fatalError("Unable to created a SFSpeechURLRecognitionRequest object")
    }
    
    recognitionRequest.shouldReportPartialResults = true

    let speechRecognizer = getRecognizer(lang: lang)
    
    recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
      var isFinal = false

      if let result = result {
        print("Speech : \(result.bestTranscription.formattedString)")
        self.speechChannel?.invokeMethod("speech.onSpeech", arguments: self.recognitionRecognitionInfo(result: result, sourceURL: url))
        isFinal = result.isFinal
        if isFinal {
          self.speechChannel!.invokeMethod(
             "speech.onRecognitionComplete",
            arguments: self.recognitionRecognitionInfo(result: result, sourceURL: url)
          )
        }
      }

      if error != nil || isFinal {
        self.recognitionRequest = nil
        self.recognitionTask = nil
      }
    }
  }
    
  private func recognitionRecognitionInfo(result: SFSpeechRecognitionResult, sourceURL: String) -> NSDictionary {
    let transcriptionDics = NSMutableArray()
    for  transcription in result.transcriptions {
        transcriptionDics.add(transcription.formattedString)
    }
    
    let segmentsDics = NSMutableArray()
    if (result.isFinal) {
        for segment in result.bestTranscription.segments {
            segmentsDics.add([
                "value"    : segment.substring,
                "alternatives"    : segment.alternativeSubstrings,
                "timestamp": segment.timestamp,
                "confidence"    : NSNumber(value: segment.confidence),
                "duration"    : NSNumber(value: segment.duration)
           ]);
        }
    }

    let recognitionInfo: NSDictionary = [
        "segments" : segmentsDics,
        "sourceURL": sourceURL,
        "text"     : result.bestTranscription.formattedString,
        "isFinal"  : NSNumber(value:result.isFinal)
    ]
    
    return recognitionInfo
  }
    
  private func supportedLanguages(result: FlutterResult) {
    let currentLanguage = NSLocale.preferredLanguages.first;
    let currentLocale = NSLocale(localeIdentifier: currentLanguage.unsafelyUnwrapped);
    
    let nameDescriptor = NSSortDescriptor(key: "name", ascending: true);
    let supportedLocales = NSMutableArray();
    
    for locale in SFSpeechRecognizer.supportedLocales() {
        supportedLocales.add([
            "code": locale.identifier,
            "name": currentLocale.localizedString(forLocaleIdentifier: locale.identifier).capitalized,
            "rtl": NSLocale.characterDirection(forLanguage: locale.languageCode!) == NSLocale.LanguageDirection.rightToLeft
        ]);
    }
    
    let supportedLocalesSorted = supportedLocales.sortedArray(using: [nameDescriptor]);
    
    result([
        "supported" : supportedLocalesSorted,
        "preferred" : NSLocale.preferredLanguages
    ]);
  }

  private func start(lang: String) throws {
    cancelRecognition(result: nil)

    let audioSession = AVAudioSession.sharedInstance()
    try audioSession.setCategory(AVAudioSession.Category.record, mode: .default)
    try audioSession.setMode(AVAudioSession.Mode.measurement)
    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

    let inputNode = audioEngine.inputNode
    
    guard let recognitionRequest = recognitionRequest else {
      fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object")
    }

    recognitionRequest.shouldReportPartialResults = true

    

    let speechRecognizer = getRecognizer(lang: lang)

    recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
      var isFinal = false

      if let result = result {
        print("Speech : \(result.bestTranscription.formattedString)")
        self.speechChannel?.invokeMethod("speech.onSpeech", arguments: result.bestTranscription.formattedString)
        isFinal = result.isFinal
        if isFinal {
          self.speechChannel!.invokeMethod(
             "speech.onRecognitionComplete",
             arguments: result.bestTranscription.formattedString
          )
        }
      }

      if error != nil || isFinal {
        self.audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        self.recognitionRequest = nil
        self.recognitionTask = nil
      }
    }

    let recognitionFormat = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recognitionFormat) {
      (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
        if let recognitionRequestBuffer = recognitionRequest as? SFSpeechAudioBufferRecognitionRequest {
            recognitionRequestBuffer.append(buffer)
        }
    }

    audioEngine.prepare()
    try audioEngine.start()

    speechChannel!.invokeMethod("speech.onRecognitionStarted", arguments: nil)
  }

  private func getRecognizer(lang: String) -> Speech.SFSpeechRecognizer {
    let recognizer: SFSpeechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: lang))!;
    recognizer.delegate = self;
    return recognizer;
  }

  public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
    speechChannel?.invokeMethod("speech.onSpeechAvailability", arguments: available)
  }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
