import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();

  bool isLoading = false;

  List messages = [];

  Future<void> sendMessage() async {

    // Don't send empty message
    if (controller.text.trim().isEmpty) {
      return;
    }

    // Store user message before API call
    final userMessage = controller.text;

    // Clear textfield immediately
    controller.clear();

    // Show loading indicator
    setState(() {

      isLoading = true;

      // Add user message instantly to UI
      messages.add({
        "role": "user",
        "text": userMessage,
      });
    });

    try {

      // Call backend API
      final response = await http.get(

        Uri.parse(
          "http://127.0.0.1:8000/chat?prompt=$userMessage",
        ),
      );

      // Convert JSON string → Dart object
      final data = jsonDecode(response.body);

      setState(() {

        // Add AI response
        messages.add({
          "role": "ai",
          "text": data["response"],
        });
      });

      // Auto scroll to bottom
      Future.delayed(
        const Duration(milliseconds: 100),
        () {

          scrollController.animateTo(
            scrollController.position.maxScrollExtent,

            duration: const Duration(milliseconds: 300),

            curve: Curves.easeOut,
          );
        },
      );

    } catch (e) {

      // If API fails
      setState(() {

        messages.add({
          "role": "ai",
          "text": "Error: Could not get response",
        });
      });

    } finally {

      // Stop loading spinner
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadHistory() async {

  final response = await http.get(
    Uri.parse("http://127.0.0.1:8000/history"),
  );

  final data = jsonDecode(response.body);

  setState(() {
    messages = data;
  });
}

 @override
void initState() {
  super.initState();

  loadHistory();
}

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Workspace"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [

            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: "Ask something...",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: sendMessage,
              child: const Text("Send"),
            ),

            const SizedBox(height: 20),

            if (isLoading)
              const CircularProgressIndicator(),

            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {

                  final message = messages[index];

                  return Align(

                    // If role is user → right side
                    // else AI → left side
                    alignment: message["role"] == "user"
                        ? Alignment.centerRight
                        : Alignment.centerLeft,

                    child: Container(

                      // Max width of bubble
                      constraints: const BoxConstraints(
                        maxWidth: 300,
                      ),

                      // Space outside bubble
                      margin: const EdgeInsets.symmetric(
                        vertical: 6,
                      ),

                      // Space inside bubble
                      padding: const EdgeInsets.all(14),

                      decoration: BoxDecoration(

                        // Different colors for user & AI
                        color: message["role"] == "user"
                            ? Colors.blue
                            : Colors.grey[300],

                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: Text(

                        // Actual message text
                        message["text"],

                        style: TextStyle(

                          // White text for user bubble
                          // Black for AI bubble
                          color: message["role"] == "user"
                              ? Colors.white
                              : Colors.black,

                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}