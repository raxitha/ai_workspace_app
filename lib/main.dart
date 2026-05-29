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

  List messages = [];

  Future<void> sendMessage() async {

    final response = await http.get(
      Uri.parse(
        "http://127.0.0.1:8000/chat?prompt=${controller.text}",
      ),
    );

    final data = jsonDecode(response.body);

    setState(() {
      messages.add({
        "role": "user",
        "text": controller.text,
      });

      messages.add({
        "role": "ai",
        "text": data["response"],
      });
    });
    controller.clear();
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

            Expanded(
              child: ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {

                  final message = messages[index];

                  return Align(
                    alignment: message["role"] == "user"
                        ? Alignment.centerRight
                        : Alignment.centerLeft,

                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(12),

                      decoration: BoxDecoration(
                        color: message["role"] == "user"
                            ? Colors.blue[100]
                            : Colors.green[100],

                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: Text(message["text"]),
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