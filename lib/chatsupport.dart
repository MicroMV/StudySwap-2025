import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class StudySwapChatScreen extends StatefulWidget {
  @override
  _StudySwapChatScreenState createState() => _StudySwapChatScreenState();
}

class _StudySwapChatScreenState extends State<StudySwapChatScreen> {
  final TextEditingController _controller = TextEditingController();

  static const String GEMINI_API_KEY =
      'AIzaSyCveCHfTZ689q3BsNNChyEF08VtNZXvAKw';

  final List<Map<String, String>> messages = [
    {
      "role": "system",
      "content":
          "You are StudySwap's customer support agent. Help users borrow, sell, lend, buy, or swap school items. Always give clear, realistic, platform-specific advice.",
    },
  ];

  final List<Map<String, String>> chatDisplay = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      chatDisplay.add({
        "role": "assistant",
        "content":
            "Hello, this is StudySwap's AI chat support. How can I help you today? For your privacy, this conversation will not be stored.",
      });
      setState(() {});
    });
  }

  // Fallback responses for common questions
  String? getFallbackResponse(String userInput) {
    final lowerInput = userInput.toLowerCase();

    if (lowerInput.contains('borrow') || lowerInput.contains('lend')) {
      return "You can borrow or lend items through the StudySwap marketplace. Browse available items or list your own! Make sure to communicate clearly about return dates and item condition.";
    } else if (lowerInput.contains('sell') || lowerInput.contains('buy')) {
      return "Post items for sale or browse items other students are selling. Make sure to set fair prices and provide clear photos and descriptions!";
    } else if (lowerInput.contains('swap')) {
      return "You can swap items with other students! Browse available items and propose a swap. Make sure both parties agree on the exchange terms.";
    } else if (lowerInput.contains('help') || lowerInput.contains('support')) {
      return "I'm here to help with StudySwap! You can ask about buying, selling, borrowing, lending, or swapping school items. What would you like to know?";
    }
    return null;
  }

  /// Sends user message to AI API and displays response
  Future<void> sendMessage(String userInput) async {
    if (userInput.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    messages.add({"role": "user", "content": userInput});
    chatDisplay.add({"role": "user", "content": userInput});
    _controller.clear();

    // Check for fallback response first
    final fallback = getFallbackResponse(userInput);
    if (fallback != null) {
      messages.add({"role": "assistant", "content": fallback});
      chatDisplay.add({"role": "assistant", "content": fallback});
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Build Gemini API URL
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$GEMINI_API_KEY',
      );

      // Format messages for Gemini
      String systemPrompt = messages[0]['content']!;

      // Build conversation history (skip system message at index 0)
      List<Map<String, dynamic>> contents = [];
      for (int i = 1; i < messages.length; i++) {
        final msg = messages[i];
        contents.add({
          'role': msg['role'] == 'assistant' ? 'model' : 'user',
          'parts': [
            {'text': msg['content']},
          ],
        });
      }

      print('Sending to Gemini API...');
      print('Message count: ${contents.length}');

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': contents,
              'systemInstruction': {
                'parts': [
                  {'text': systemPrompt},
                ],
              },
              'generationConfig': {'temperature': 0.7, 'maxOutputTokens': 500},
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          final botReply = data['candidates'][0]['content']['parts'][0]['text'];
          messages.add({"role": "assistant", "content": botReply});
          chatDisplay.add({"role": "assistant", "content": botReply});
        } else {
          throw Exception('Invalid response format');
        }
      } else if (response.statusCode == 400) {
        print('Error body: ${response.body}');
        chatDisplay.add({
          "role": "assistant",
          "content": "Invalid request. Please try rephrasing your question.",
        });
      } else if (response.statusCode == 429) {
        chatDisplay.add({
          "role": "assistant",
          "content": "Rate limit reached. Please wait a moment and try again.",
        });
      } else {
        throw Exception('API error: ${response.statusCode}');
      }
    } on TimeoutException catch (_) {
      print('Error: Timeout');
      chatDisplay.add({
        "role": "assistant",
        "content":
            "Request timed out. Please check your connection and try again.",
      });
    } on SocketException catch (_) {
      print('Error: No internet connection');
      chatDisplay.add({
        "role": "assistant",
        "content": "No internet connection. Please check your network.",
      });
    } on FormatException catch (e) {
      print('Error: Format exception - $e');
      chatDisplay.add({
        "role": "assistant",
        "content": "Received an invalid response. Please try again.",
      });
    } catch (e) {
      print('Error: $e');
      chatDisplay.add({
        "role": "assistant",
        "content": "Sorry, I couldn't process that. Please try again.",
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  /// Builds a chat bubble widget for displaying messages
  Widget chatBubble(Map<String, String> msg) {
    final isUser = msg['role'] == 'user';
    final bubbleColor = isUser
        ? Colors.blue[400]
        : Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[800]
        : Colors.grey[200];
    final textColor = isUser
        ? Colors.white
        : Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Row(
      mainAxisAlignment: isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.07),
                blurRadius: 4,
                offset: Offset(1, 2),
              ),
            ],
          ),
          child: Text(
            msg['content'] ?? "",
            style: TextStyle(fontSize: 16, color: textColor),
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
        ),
      ],
    );
  }

  /// Builds the main chat support screen UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 1,
        title: Row(
          children: [
            Icon(Icons.support_agent, color: Colors.blue[700]),
            SizedBox(width: 8),
            Text(
              'StudySwap Support',
              style: TextStyle(color: Colors.blue[700]),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: false,
                padding: EdgeInsets.only(top: 16, bottom: 2),
                itemCount: chatDisplay.length,
                itemBuilder: (ctx, i) => chatBubble(chatDisplay[i]),
              ),
            ),
            if (_isLoading)
              Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: LinearProgressIndicator(),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_isLoading,
                      maxLines: 5,
                      minLines: 1,
                      maxLength: 500,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      decoration: InputDecoration(
                        hintText: "Ask about StudySwap...",
                        hintStyle: TextStyle(
                          color: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.color?.withOpacity(0.5),
                        ),
                        fillColor: Theme.of(context).cardColor,
                        filled: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        counterText: '',
                      ),
                      onSubmitted: (value) => sendMessage(value),
                    ),
                  ),
                  SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.blue[600],
                    radius: 24,
                    child: IconButton(
                      color: Colors.white,
                      icon: Icon(Icons.send, size: 22),
                      onPressed: _isLoading
                          ? null
                          : () => sendMessage(_controller.text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
