import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import 'dart:html' as html;

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

  Future<void> uploadFile() async {

    // Open file picker
    FilePickerResult? result =
        await FilePicker.platform.pickFiles();

    if (result == null) {
      return;
    }

    final file =
        result.files.single;

    var request =
        http.MultipartRequest(
          "POST",
          Uri.parse(
            "http://127.0.0.1:8000/upload",
          ),
        );

    request.files.add(
      http.MultipartFile.fromBytes(
        "file",
        file.bytes!,
        filename: file.name,
      ),
    );

    var response =
        await request.send();

    if (response.statusCode == 200) {

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(

        const SnackBar(
          content: Text(
            "File uploaded successfully",
          ),
        ),
      );
    }
  }

  Future<void> showRenameDialog(
    int conversationId,
  ) async {

    final renameController =
        TextEditingController();

    showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

          title: const Text(
            "Rename Conversation",
          ),

          content: TextField(
            controller: renameController,
            decoration:
                const InputDecoration(
              hintText: "Enter title",
            ),
          ),

          actions: [

            TextButton(
              onPressed: () {

                Navigator.pop(
                  context,
                );
              },
              child: const Text(
                "Cancel",
              ),
            ),

            ElevatedButton(
              onPressed: () async {

                await renameConversation(
                  conversationId,
                  renameController.text,
                );

                Navigator.pop(
                  context,
                );
              },
              child: const Text(
                "Save",
              ),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> exportConversation() async {

    if (currentConversationId == null) {
      return;
    }

    final response = await http.get(
      Uri.parse(
        "http://127.0.0.1:8000/export/$currentConversationId",
      ),
    );

    final bytes = utf8.encode(
      response.body,
    );

    final blob = html.Blob(
      [bytes],
    );

    final url =
        html.Url.createObjectUrlFromBlob(
      blob,
    );

    final anchor =
        html.AnchorElement(
          href: url,
        )
          ..setAttribute(
            "download",
            "chat_$currentConversationId.txt",
          )
          ..click();

    html.Url.revokeObjectUrl(
      url,
    );
  }

  Future<void> renameConversation(
    int conversationId,
    String title,
  ) async {

    await http.put(
      Uri.parse(
        "http://127.0.0.1:8000/conversation/$conversationId?title=${Uri.encodeComponent(title)}",
      ),
    );

    loadConversations();
  }

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
        title: Text(
          "AI Workspace • ${selectedModel.toUpperCase()}",
        ),
        actions: [

          IconButton(

            icon: const Icon(
              Icons.download,
            ),

            onPressed:
                exportConversation,
          ),
        ],
      ),

      drawer: Drawer(
        child: ListView(
          children: [

            DrawerHeader(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                mainAxisAlignment:
                    MainAxisAlignment.end,

                children: const [

                  Icon(
                    Icons.smart_toy,
                    size: 40,
                  ),

                  SizedBox(height: 10),

                  Text(
                    "AI Workspace",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
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

                onLongPress: () {

                  showModalBottomSheet(

                    context: context,

                    builder: (context) {

                      return Column(

                        mainAxisSize:
                            MainAxisSize.min,

                        children: [

                          ListTile(

                            leading:
                                const Icon(Icons.edit),

                            title:
                                const Text("Rename"),

                            onTap: () {

                              Navigator.pop(
                                context,
                              );

                              showRenameDialog(
                                conversation["id"],
                              );
                            },
                          ),

                          ListTile(

                            leading:
                                const Icon(Icons.delete),

                            title:
                                const Text("Delete"),

                            onTap: () async {

                              Navigator.pop(
                                context,
                              );

                              await deleteConversation(
                                conversation["id"],
                              );
                            },
                          ),
                        ],
                      );
                    },
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

                    DropdownMenuItem(
                      value: "qwen3",
                      child: Text("Qwen3"),
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

           Row(
            children: [

              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: "Ask something...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              IconButton(
                onPressed: sendMessage,
                icon: const Icon(
                  Icons.send,
                ),
              ),
              ElevatedButton.icon(
                onPressed: uploadFile,
                icon: const Icon(
                  Icons.upload_file,
                ),
                label: const Text(
                  "Upload Knowledge",
                ),
              )
            ],
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
                          ? Colors.blue.shade600
                          : Colors.grey.shade200,

                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(
                            message["role"] == "user" ? 18 : 4,
                          ),
                          bottomRight: Radius.circular(
                            message["role"] == "user" ? 4 : 18,
                          ),
                        ),
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