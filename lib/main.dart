import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'dart:io';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "CuisineGenie",
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
      ),
      home: const RecipeGeneratorScreen(),
    );
  }
}

class RecipeGeneratorScreen extends StatefulWidget {
  const RecipeGeneratorScreen({super.key});

  @override
  _RecipeGeneratorScreenState createState() => _RecipeGeneratorScreenState();
}

class _RecipeGeneratorScreenState extends State<RecipeGeneratorScreen>
    with SingleTickerProviderStateMixin {
  File? _image;
  final TextEditingController _promptController = TextEditingController();
  String _generatedRecipe = '';
  bool _isLoading = false;
  late AnimationController _animationController;
  final ScrollController _scrollController = ScrollController();

  final ImagePicker _picker = ImagePicker();
  late FirebaseVertexAI _vertexAI;

  @override
  void initState() {
    super.initState();
    _vertexAI = FirebaseVertexAI.instance;
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _getImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _image = File(image.path);
      });
    }
  }

  Future<void> _generateRecipe() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image of ingredients'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _generatedRecipe = '';
    });

    try {
      // Safety settings
      final safetySettings = [
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.high),
      ];

      // Generation config (model parameters)
      final generationConfig = GenerationConfig(
        maxOutputTokens: 1000,
        temperature: 0.7,
        topP: 0.8,
        topK: 40,
      );

      // Updated system instruction
      final systemInstruction = Content.system('''
You are a professional chef with extensive knowledge of global cuisines and nutrition. 
Your task is to analyze the image provided and respond accordingly:

1. If the image does not contain food ingredients, respond with:
   "No ingredients found. Please provide an image containing food ingredients."

2. If the image contains food ingredients:
   a) Carefully examine the image to identify all visible ingredients.
   b) Create a recipe that primarily uses the ingredients in the image.
   c) If essential ingredients are missing, suggest common, healthy alternatives or additions.
   d) Emphasize nutritional balance and health benefits in your recipe.
   e) Provide preparation time, cooking time, and difficulty level.
   f) Offer detailed, step-by-step instructions for preparing the dish.
   g) Suggest healthy cooking methods (e.g., grilling, steaming, baking) over less healthy options when possible.
   h) If applicable, mention any potential dietary categories the recipe fits (e.g., low-carb, vegetarian, gluten-free).
   i) Briefly explain the nutritional benefits of key ingredients or the overall dish.

Format your response as follows:
[Provide a short, catchy recipe name of one or two words]
Ingredients:
[List ingredients]
Instructions:
[List instructions]
Nutritional Information:
[Provide nutritional details]

Do not use any markdown formatting characters like ## or ** in your response.
Remember to be creative while ensuring the recipe is practical and can be prepared in a home kitchen.
    ''');

      final model = _vertexAI.generativeModel(
        model: 'gemini-1.5-pro',
        safetySettings: safetySettings,
        generationConfig: generationConfig,
        systemInstruction: systemInstruction,
      );

      final imageBytes = await _image!.readAsBytes();
      final imagePart = DataPart('image/jpeg', imageBytes);

      final textPrompt = TextPart(
          "Based on the ingredients in this image, create a gourmet, healthy recipe. ${_promptController.text}");

      final response = await model.generateContent([
        Content.multi([textPrompt, imagePart])
      ]);

      setState(() {
        _generatedRecipe = response.text ?? 'No recipe generated.';
        _isLoading = false;
        _promptController.clear(); // Clear the prompt text field
      });
      _animationController.forward(from: 0.0);

      // Scroll to the recipe after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(seconds: 1),
          curve: Curves.easeOut,
        );
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _generatedRecipe = 'Error generating recipe: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.deepOrange.shade300, Colors.orange.shade100],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildImageSelection(),
                  const SizedBox(height: 20),
                  _buildPromptInput(),
                  const SizedBox(height: 20),
                  _buildGenerateButton(),
                  const SizedBox(height: 30),
                  _buildRecipeOutput(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Text(
          'CuisineGenie',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
        Text(
          'Your personal chef',
          style: TextStyle(
            fontSize: 24,
            color: Colors.white70,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildImageSelection() {
    return GestureDetector(
      onTap: _getImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 5)
          ],
        ),
        child: _image == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text('Tap to add ingredients photo',
                      style: TextStyle(color: Colors.grey, fontSize: 18)),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(_image!, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(Icons.refresh,
                          color: Colors.white, size: 30),
                      onPressed: _getImage,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPromptInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 5)
        ],
      ),
      child: TextField(
        controller: _promptController,
        style: const TextStyle(fontSize: 16),
        decoration: const InputDecoration(
          hintText: 'Any special instructions or preferences?',
          hintStyle: TextStyle(fontSize: 16),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(20),
          prefixIcon:
              Icon(Icons.restaurant_menu, color: Colors.deepOrange, size: 30),
        ),
        maxLines: 3,
      ),
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _generateRecipe,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepOrange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
      child: _isLoading
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                SizedBox(width: 10),
                Text('Cooking up magic...', style: TextStyle(fontSize: 22)),
              ],
            )
          : const Text('Generate Gourmet Recipe',
              style: TextStyle(fontSize: 18, color: Colors.white)),
    );
  }

  Widget _buildRecipeOutput() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _animationController.value,
          child: Opacity(
            opacity: _animationController.value,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black12, blurRadius: 10, spreadRadius: 5)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Gourmet Creation',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange)),
                  const SizedBox(height: 10),
                  Text.rich(
                    TextSpan(
                      children: _parseRecipe(_generatedRecipe),
                    ),
                  ),
                  if (_generatedRecipe.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.share,
                            size: 24,
                            color: Colors.white,
                          ),
                          label: const Text('Share Recipe',
                              style:
                                  TextStyle(fontSize: 20, color: Colors.white)),
                          onPressed: () {
                            // Implement sharing functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Sharing coming soon!')),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<InlineSpan> _parseRecipe(String recipe) {
    final List<InlineSpan> spans = [];
    final lines = recipe.split('\n');

    for (final line in lines) {
      if (line.startsWith('Recipe Name:')) {
        spans.add(TextSpan(
          text: '$line\n',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'Playfair Display', // Old and stylish font
            color: Colors.black87,
          ),
        ));
      } else if (line.contains(':') && !line.contains(',')) {
        spans.add(TextSpan(
          text: '\n$line\n',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: '$line\n',
          style: const TextStyle(
            fontSize: 18,
            color: Colors.black54,
            height: 1.5,
          ),
        ));
      }
    }

    return spans;
  }
}
