import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_v2/tflite_v2.dart';
import 'package:device_preview/device_preview.dart';
import 'js_predictor_stub.dart'
if (dart.library.js) 'js_predictor_web.dart';

void main() {
  final isWeb = kIsWeb;
  final isReleaseMode = kReleaseMode;
  runApp(
    isWeb && !isReleaseMode
        ? DevicePreview(
      enabled: true,
      builder: (context) => const MyApp(),
    )
        : const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      useInheritedMediaQuery: true,
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      title: 'Food Classifier',
      theme: ThemeData.dark(),
      home: const ImageClassifier(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ImageClassifier extends StatefulWidget {
  const ImageClassifier({super.key});

  @override
  State<ImageClassifier> createState() => _ImageClassifierState();
}

class _ImageClassifierState extends State<ImageClassifier> {
  Uint8List? _imageBytes;
  String _prediction = "";
  bool _isLoading = false;
  List<String> foodItems = [];
  List<String> foodCalories = [];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _loadTFLiteModel();
    _loadLabelsAndCalories();
  }

  Future<void> _loadTFLiteModel() async {
    await Tflite.loadModel(
      model: "assets/trained_food_2/desi_fast_model.tflite",
      labels: "assets/trained_food_2/desi_fast_labels.txt",
    );
  }

  Future<void> _loadLabelsAndCalories() async {
    final labelsData = await rootBundle.loadString('assets/trained_food_2/desi_fast_labels.txt');
    final caloriesData = await rootBundle.loadString('assets/trained_food_2/desi_fast_calories.txt');

    setState(() {
      foodItems = labelsData.split("\n");
      foodCalories = caloriesData.split("\n");
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();

    setState(() {
      _imageBytes = bytes;
      _isLoading = true;
    });

    if (kIsWeb) {
      final base64Image = "data:image/jpeg;base64,${base64Encode(bytes)}";
      await _classifyImageForWeb(base64Image);
    } else {
      await _classifyMobileImage(File(pickedFile.path));
    }

    setState(() => _isLoading = false);
  }

  Future<void> _classifyMobileImage(File file) async {
    var recognitions = await Tflite.runModelOnImage(
      path: file.path,
      imageMean: 127.5,
      imageStd: 127.5,
      numResults: 5,
      threshold: 0.1,
    );

    if (recognitions != null && recognitions.isNotEmpty) {
      setState(() {
        _prediction = recognitions.map((result) {
          String label = result['label'].trim();
          int index = foodItems.indexOf(label);
          String cal = (index != -1) ? foodCalories[index] : "Unknown Calories";
          return "$label - $cal";
        }).join("\n");
      });
    } else {
      setState(() {
        _prediction = "No Prediction";
      });
    }
  }

  Future<void> _classifyImageForWeb(String base64Image) async {
    try {
      List<dynamic> predictions = await predictWithJS(base64Image);
      print("Predictions: $predictions");

      if (predictions.isEmpty) {
        setState(() => _prediction = "No Prediction");
        return;
      }

      // Get top prediction
      int topIndex = predictions.indexWhere((e) => e == predictions.reduce((a, b) => a > b ? a : b));
      String label = foodItems[topIndex];
      String calories = (topIndex < foodCalories.length) ? foodCalories[topIndex] : "Unknown Calories";

      setState(() {
        _prediction = "$label - $calories";
      });
    } catch (e) {
      print("Prediction error: $e");
      setState(() => _prediction = "Prediction Failed");
    }
  }


  @override
  void dispose() {
    if (!kIsWeb) {
      Tflite.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = const SizedBox(height: 150);
    if (_imageBytes != null) {
      imageWidget = Image.memory(_imageBytes!, height: 150);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Food Classifier'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(5),
          child: Column(
            children: [
              imageWidget,
              const SizedBox(height: 10),
              const Text("Select an image to classify"),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    child: const Text("Gallery"),
                  ),
                  if (!kIsWeb)
                    ElevatedButton(
                      onPressed: () => _pickImage(ImageSource.camera),
                      child: const Text("Camera"),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isLoading) const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text("Prediction", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(_prediction, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
