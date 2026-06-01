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

  int? currentConversationId;

  List conversations = [];

  List messages = [];

  String selectedModel = "llama3";

  Future<void> sendMessage() async {

    // Don't send empty message
    if (controller.text.trim().isEmpty) {
      return;
    }

    if (currentConversationId == null) {
      await createConversation();
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
          "http://127.0.0.1:8000/chat?conversation_id=$currentConversationId&prompt=${Uri.encodeComponent(userMessage)}&model=$selectedModel"
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

  Future<void> loadConversations() async {

    final response = await http.get(
      Uri.parse(
        "http://127.0.0.1:8000/conversations",
      ),
    );

    final data = jsonDecode(response.body);

    setState(() {
      conversations = data;
    });
  }

  Future<void> loadMessages(
  int conversationId,
  ) async {

    final response = await http.get(
      Uri.parse(
        "http://127.0.0.1:8000/messages/$conversationId",
      ),
    );

    final data = jsonDecode(
      response.body,
    );

    setState(() {

      currentConversationId =
          conversationId;

      messages = data;
    });
  }

  Future<void> createConversation() async {

    final response = await http.post(
      Uri.parse(
        "http://127.0.0.1:8000/conversation",
      ),
    );

    final data = jsonDecode(response.body);

    setState(() {
      currentConversationId =
          data["conversation_id"];
      messages = [];
    });
    loadConversations();
  }

  Future<void> deleteConversation(
    int conversationId,
  ) async {

    await http.delete(
      Uri.parse(
        "http://127.0.0.1:8000/conversation/$conversationId",
      ),
    );

    loadConversations();
  }

//   Future<void> loadHistory() async {

//   final response = await http.get(
//     Uri.parse("http://127.0.0.1:8000/history"),
//   );

//   final data = jsonDecode(response.body);

//   setState(() {
//     messages = data;
//   });
// }

 @override
void initState() {
  super.initState();
  loadConversations();
}

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("AI Workspace"),
      ),

      drawer: Drawer(
        child: ListView(
          children: [

            const DrawerHeader(
              child: Text(
                "Conversations",
              ),
            ),

            ListTile(

              leading: const Icon(
                Icons.add,
              ),

              title: const Text(
                "New Chat",
              ),

              onTap: () {

                createConversation();

                Navigator.pop(
                  context,
                );
              },
            ),

            ...conversations.map((conversation) {

              return ListTile(

                title: Text(
                  conversation["title"],
                ),

                onTap: () {

                  loadMessages(
                    conversation["id"],
                  );

                  Navigator.pop(
                    context,
                  );
                },

                onLongPress: () async {

                  await deleteConversation(
                    conversation["id"],
                  );
                },
              );
            }).toList(),
          ],
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [

            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),

                child: DropdownButton<String>(

                  value: selectedModel,

                  isExpanded: true,

                  underline: const SizedBox(),

                  items: const [

                    DropdownMenuItem(
                      value: "llama3",
                      child: Text("Llama 3"),
                    ),

                    DropdownMenuItem(
                      value: "mistral",
                      child: Text("Mistral"),
                    ),
                  ],

                  onChanged: (value) {

                    setState(() {

                      selectedModel = value!;
                    });
                  },
                ),
              ),
            ),

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