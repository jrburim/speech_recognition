import 'package:flutter/material.dart';
import 'package:speech_recognition/speech_recognition.dart';

void main() {
  runApp(new MyApp());
}

const languages = const [
  const Language('Francais', 'fr_FR'),
  const Language('English', 'en_US'),
  const Language('Pусский', 'ru_RU'),
  const Language('Italiano', 'it_IT'),
  const Language('Español', 'es_ES'),
  const Language('Portugues', 'pt_BR'),
];

class Language {
  final String name;
  final String code;

  const Language(this.name, this.code);
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late SpeechRecognition _speech;

  bool _speechRecognitionAvailable = false;
  bool _isListening = false;

  String transcription = '';

  //String _currentLocale = 'en_US';
  Language selectedLang = languages.first;

  @override
  initState() {
    super.initState();
    activateSpeechRecognizer();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  void activateSpeechRecognizer() {
    print('_MyAppState.activateSpeechRecognizer... ');
    _speech = new SpeechRecognition();
    _speech.setAvailabilityHandler(onSpeechAvailability);
    _speech.setCurrentLocaleHandler(onCurrentLocale);
    _speech.setRecognitionStartedHandler(onRecognitionStarted);
    _speech.setRecognitionResultHandler(onRecognitionResult);
    _speech.setRecognitionCompleteHandler(onRecognitionComplete);
    _speech.setErrorHandler(errorHandler);
    _speech
        .activate()
        .then((res) => setState(() => _speechRecognitionAvailable = res));
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      home: new Scaffold(
        appBar: new AppBar(
          title: new Text('SpeechRecognition'),
          actions: [
            new PopupMenuButton<Language>(
              onSelected: _selectLangHandler,
              itemBuilder: (BuildContext context) => _buildLanguagesWidgets,
            )
          ],
        ),
        body: new Padding(
            padding: new EdgeInsets.all(8.0),
            child: new Center(
              child: new Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  new Expanded(
                      child: new Container(
                          padding: const EdgeInsets.all(8.0),
                          color: Colors.grey.shade200,
                          child: new Text(transcription))),
                  _buildButton(
                    onPressed: () {
                      if (_speechRecognitionAvailable && !_isListening) start();
                    },
                    label: _isListening
                        ? 'Listening...'
                        : 'Listen (${selectedLang.code})',
                  ),
                  _buildButton(
                    onPressed: () {
                      if (_speechRecognitionAvailable && !_isListening)
                        startAudio();
                    },
                    label: _isListening
                        ? 'Processing Audio...'
                        : 'Process audio (${selectedLang.code})',
                  ),
                  _buildButton(
                    onPressed: () {
                      if (_isListening) cancel();
                    },
                    label: 'Cancel',
                  ),
                  _buildButton(
                    onPressed: () {
                      if (_isListening) stop();
                    },
                    label: 'Stop',
                  ),
                ],
              ),
            )),
      ),
    );
  }

  List<CheckedPopupMenuItem<Language>> get _buildLanguagesWidgets => languages
      .map((l) => new CheckedPopupMenuItem<Language>(
            value: l,
            checked: selectedLang == l,
            child: new Text(l.name),
          ))
      .toList();

  void _selectLangHandler(Language lang) {
    setState(() => selectedLang = lang);
  }

  Widget _buildButton(
          {required String label, required VoidCallback onPressed}) =>
      new Padding(
          padding: new EdgeInsets.all(12.0),
          child: new RaisedButton(
            color: Colors.cyan.shade600,
            onPressed: onPressed,
            child: new Text(
              label,
              style: const TextStyle(color: Colors.white),
            ),
          ));

  void start() => _speech
      .listen(locale: selectedLang.code)
      .then((result) => print('_MyAppState.start => result $result'));

  void startAudio() {
    var audioPath =
        "/Users/admin/Desktop/AudioDev/AUDIO-2019-06-17-08-27-48.m4a";
    _speech
        .listenAudio(audioPath: audioPath, locale: selectedLang.code)
        .then((result) => print('_MyAppState.startAudio => result $result'));
  }

  void cancel() =>
      _speech.cancel().then((result) => setState(() => _isListening = result));

  void stop() => _speech.stop().then((result) {
        setState(() => _isListening = result);
      });

  void onSpeechAvailability(bool result) =>
      setState(() => _speechRecognitionAvailable = result);

  void onCurrentLocale(String locale) {
    print('_MyAppState.onCurrentLocale... $locale');
    setState(
        () => selectedLang = languages.firstWhere((l) => l.code == locale));
  }

  void onRecognitionStarted() => setState(() => _isListening = true);

  void onRecognitionResult(RecognitionInfo result) {
    setState(() => transcription = result.text);
  }

  void onRecognitionComplete(RecognitionInfo result) {
    setState(() {
      _isListening = false;
      transcription = result.text;
    });
  }

  void errorHandler() => activateSpeechRecognizer();
}
