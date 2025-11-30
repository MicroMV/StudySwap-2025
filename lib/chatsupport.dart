import 'package:flutter/material.dart';

class StudySwapChatScreen extends StatefulWidget {
  @override
  _StudySwapChatScreenState createState() => _StudySwapChatScreenState();
}

class _StudySwapChatScreenState extends State<StudySwapChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> chatDisplay = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      chatDisplay.add({
        "role": "assistant",
        "content":
            "Hello! 👋 I'm your StudySwap support assistant.\n\nI can help you with:\n• Buying and selling school items\n• Borrowing and lending materials\n• Swapping items with students\n• App features and navigation\n• Safety tips for transactions\n\nWhat can I help you with today?",
      });
      setState(() {});
    });
  }

  // Comprehensive StudySwap knowledge base
  String getResponse(String userInput) {
    final lowerInput = userInput.toLowerCase();

    // Greetings
    if (lowerInput.contains('hi') ||
        lowerInput.contains('hello') ||
        lowerInput.contains('hey') ||
        lowerInput == 'h') {
      return "Hi there! 😊 Welcome to StudySwap support. How can I help you today?";
    }

    // Thank you
    if (lowerInput.contains('thank') || lowerInput.contains('thanks')) {
      return "You're welcome! Is there anything else you'd like to know about StudySwap?";
    }

    // Borrow/Lend
    if (lowerInput.contains('borrow') || lowerInput.contains('lend')) {
      return "📚 **Borrowing & Lending on StudySwap:**\n\n1. Go to Home or Browse screen\n2. Filter by 'Borrow'\n3. Tap an item to see details\n4. Contact the owner via chat\n5. Agree on return date\n6. Meet at a safe location\n\n**Tips:**\n• Check item condition before borrowing\n• Return items on time\n• Communicate clearly about return dates\n\nNeed help finding specific items?";
    }

    // Sell/Buy
    if (lowerInput.contains('sell') ||
        lowerInput.contains('buy') ||
        lowerInput.contains('price')) {
      return "💰 **Buying & Selling on StudySwap:**\n\n**To Sell:**\n1. Tap the '+' button\n2. Take clear photos\n3. Choose 'Sell' action\n4. Set your price\n5. Add description\n6. Post your item\n\n**To Buy:**\n1. Browse items marked 'Sell'\n2. Check photos and price\n3. Chat with seller\n4. Meet in safe location\n5. Inspect before paying\n\n**Pricing Tips:**\n• New items: 60-80% of retail\n• Like New: 50-70%\n• Good: 30-50%\n• Used: 20-40%\n\nWant more pricing advice?";
    }

    // Swap/Trade
    if (lowerInput.contains('swap') ||
        lowerInput.contains('trade') ||
        lowerInput.contains('exchange')) {
      return "🔄 **Swapping on StudySwap:**\n\n1. Find items marked 'Swap'\n2. Browse what they're offering\n3. Propose your item for trade\n4. Both agree on the exchange\n5. Meet to swap items\n6. Check condition before swapping\n7. Complete the transaction\n\n**Swap Tips:**\n• Items should be similar value\n• Both parties must agree\n• Inspect items before swapping\n• Meet in public places\n\nLooking for something to swap?";
    }

    // Post/Upload/Add items
    if (lowerInput.contains('post') ||
        lowerInput.contains('list') ||
        lowerInput.contains('add item') ||
        lowerInput.contains('upload') ||
        lowerInput.contains('create offer')) {
      return "📝 **How to Post Items:**\n\n1. Tap the '+' floating button (bottom right)\n2. Take or upload photos (up to 5)\n3. Choose category:\n   • School Uniforms\n   • Bags\n   • Shoes\n   • Pens & Stationery\n   • Art Materials\n   • Papers\n   • Others\n4. Select action: Borrow, Sell, or Swap\n5. Add title and description\n6. Set price (if selling)\n7. Choose condition (New/Like New/Good/Fair/Used)\n8. Post your item!\n\n**Photo Tips:**\n• Use good lighting\n• Show all angles\n• Include any defects\n• Clear, focused images\n\nNeed help with descriptions?";
    }

    // How to use/start/tutorial
    if (lowerInput.contains('how to') ||
        lowerInput.contains('start') ||
        lowerInput.contains('use') ||
        lowerInput.contains('guide') ||
        lowerInput.contains('tutorial')) {
      return "🚀 **Getting Started with StudySwap:**\n\n**Browse Items:**\n• Home screen shows nearby offers\n• Use Browse screen for all items\n• Filter by Borrow/Sell/Swap\n• Search by keywords\n\n**Contact Sellers:**\n• Tap any item for details\n• Use in-app chat to message\n• Arrange meetup details\n\n**Post Your Items:**\n• Tap '+' button\n• Follow posting steps\n• Manage your offers in Profile\n\n**Stay Safe:**\n• Meet in public campus areas\n• Check items before exchanging\n• Use app chat for records\n\nWhat would you like to do first?";
    }

    // Safety/Security
    if (lowerInput.contains('safe') ||
        lowerInput.contains('security') ||
        lowerInput.contains('scam') ||
        lowerInput.contains('fraud') ||
        lowerInput.contains('danger')) {
      return "🛡️ **Safety Guidelines:**\n\n**Meeting Up:**\n• Choose public, well-lit campus locations\n• Daytime meetings preferred\n• Bring a friend if unsure\n• Tell someone where you're going\n\n**Transaction Safety:**\n• Inspect items thoroughly\n• Test items before buying\n• Count money in person\n• Never share bank details\n\n**Communication:**\n• Use in-app chat (keeps records)\n• Be clear about terms\n• Report suspicious behavior\n• Trust your instincts\n\n**Red Flags:**\n• Requests to pay before meeting\n• Pushy or aggressive behavior\n• Refusing to meet in public\n• Prices too good to be true\n\nStay safe and report concerns!";
    }

    // Search/Find items
    if (lowerInput.contains('search') || lowerInput.contains('find')) {
      return "🔍 **Finding Items:**\n\n**Search Bar:**\n• Type keywords (e.g., \"uniform\", \"calculator\")\n• Auto-refreshes results\n• Clear button to reset\n\n**Filters:**\n• Action: All/Borrow/Sell/Swap\n• Category: Uniforms, Bags, Shoes, etc.\n• Condition: New to Used\n• Distance: Shows nearby first\n\n**Browse Screen:**\n• Grid view of all items\n• Filter button (top right)\n• Tap any card for details\n\n**Tips:**\n• Use specific keywords\n• Check multiple categories\n• Browse nearby offers first\n\nWhat are you looking for?";
    }

    // Categories
    if (lowerInput.contains('category') ||
        lowerInput.contains('categories') ||
        lowerInput.contains('what can i')) {
      return "📂 **Available Categories:**\n\n🎓 **School Uniforms**\n   Shirts, pants, PE uniforms, ties\n\n🎒 **Bags**\n   Backpacks, tote bags, laptop bags\n\n👟 **Shoes**\n   School shoes, sneakers, sports shoes\n\n✏️ **Pens & Stationery**\n   Pens, pencils, notebooks, folders\n\n🎨 **Art Materials**\n   Paint, brushes, canvas, art supplies\n\n📄 **Papers & Books**\n   Textbooks, workbooks, notes, reviewers\n\n📦 **Others**\n   Any other school-related items\n\nWhich category interests you?";
    }

    // Features/What can it do
    if (lowerInput.contains('feature') ||
        lowerInput.contains('can it') ||
        lowerInput.contains('what does')) {
      return "✨ **StudySwap Features:**\n\n📍 **Location-Based**\n• See nearby offers with distance\n• Connect with students nearby\n\n💬 **In-App Chat**\n• Message users directly\n• Arrange meetups safely\n• Keep conversation records\n\n🔍 **Smart Search**\n• Keyword search\n• Multiple filters\n• Real-time results\n\n📸 **Photo Uploads**\n• Up to 5 photos per item\n• Show item condition\n\n🏷️ **Item Management**\n• Edit your listings\n• Mark as sold/unavailable\n• Delete old posts\n\n🔔 **Notifications**\n• New messages\n• Transaction updates\n\nWhich feature interests you most?";
    }

    // Profile/Account
    if (lowerInput.contains('account') ||
        lowerInput.contains('profile') ||
        lowerInput.contains('my offers') ||
        lowerInput.contains('my items')) {
      return "👤 **Your Profile & Offers:**\n\n**Access Profile:**\n• Tap profile icon (top right)\n• Select 'Profile' or 'My Offers'\n\n**Manage Offers:**\n• View all your listings\n• Edit: Change details/photos\n• Hide: Mark unavailable\n• Delete: Remove permanently\n\n**Track Status:**\n• Active offers (visible to all)\n• Unavailable (hidden from others)\n• Completed transactions\n\n**Profile Settings:**\n• Update display name\n• Change profile photo\n• View transaction history\n\nNeed help managing your listings?";
    }

    // Edit/Delete items
    if (lowerInput.contains('edit') ||
        lowerInput.contains('delete') ||
        lowerInput.contains('remove') ||
        lowerInput.contains('change')) {
      return "⚙️ **Managing Your Items:**\n\n**To Edit:**\n1. Go to 'My Offers'\n2. Tap ⋮ menu on your item\n3. Select 'Edit'\n4. Update details\n5. Save changes\n\n**To Hide:**\n1. Open 'My Offers'\n2. Tap ⋮ menu\n3. Select 'Hide'\n4. Item marked 'Unavailable'\n\n**To Delete:**\n1. Go to 'My Offers'\n2. Tap ⋮ menu\n3. Select 'Delete'\n4. Confirm deletion\n⚠️ This cannot be undone\n\n**To Reactivate:**\n• Hidden items can be shown again\n• Use 'Show' from menu\n\nWhat would you like to do?";
    }

    // Chat/Message
    if (lowerInput.contains('chat') ||
        lowerInput.contains('message') ||
        lowerInput.contains('contact')) {
      return "💬 **Using In-App Chat:**\n\n**Start a Chat:**\n1. Tap any item you're interested in\n2. Scroll to bottom\n3. Tap 'Chat with [Name]' button\n4. Type your message\n\n**Chat Features:**\n• Real-time messaging\n• See when user is online\n• Share details about meetup\n• Keep conversation records\n\n**Best Practices:**\n• Be polite and clear\n• Ask specific questions\n• Agree on meetup details\n• Confirm before meeting\n\n**Safety:**\n• Keep all communication in-app\n• Don't share personal phone numbers\n• Report inappropriate messages\n\nNeed help with messaging?";
    }

    // Problems/Issues/Errors
    if (lowerInput.contains('problem') ||
        lowerInput.contains('issue') ||
        lowerInput.contains('error') ||
        lowerInput.contains('not working') ||
        lowerInput.contains('broken')) {
      return "🔧 **Troubleshooting:**\n\n**Common Issues:**\n\n📱 **App Not Loading:**\n• Check internet connection\n• Close and reopen app\n• Update to latest version\n\n📸 **Photos Not Uploading:**\n• Check storage permissions\n• Try smaller file sizes\n• Use different photos\n\n🔍 **Can't Find Items:**\n• Clear search filters\n• Check category selection\n• Try different keywords\n\n💬 **Chat Not Working:**\n• Refresh the app\n• Check internet connection\n• Try logging out/in\n\n**Still Having Issues?**\nDescribe your specific problem and I'll help you solve it!";
    }

    // Report/Flag
    if (lowerInput.contains('report') ||
        lowerInput.contains('flag') ||
        lowerInput.contains('suspicious')) {
      return "🚩 **Reporting Issues:**\n\n**Report a User:**\n• Tap profile → 3 dots\n• Select 'Report User'\n• Choose reason\n• Submit report\n\n**Report an Item:**\n• Open item details\n• Tap flag icon\n• Select violation type\n• Submit report\n\n**What to Report:**\n• Scams or fraud\n• Inappropriate content\n• Fake listings\n• Harassment\n• Prohibited items\n\n**Your Safety:**\n• Reports are anonymous\n• We review within 24 hours\n• Serious violations = account ban\n\nYour safety is our priority!";
    }

    // Payment/Money
    if (lowerInput.contains('payment') ||
        lowerInput.contains('pay') ||
        lowerInput.contains('money') ||
        lowerInput.contains('cash')) {
      return "💵 **Payment Guidelines:**\n\n**Accepted Methods:**\n• Cash (in-person only)\n• GCash or mobile wallets\n• Bank transfer (after meeting)\n\n**Safety Rules:**\n• Never pay before seeing item\n• Count cash in person\n• Get receipt if possible\n• Bring exact change\n\n**What NOT to Do:**\n❌ Never pay upfront\n❌ Don't share bank PINs\n❌ Avoid wire transfers to strangers\n❌ Don't use unsecured methods\n\n**For Sellers:**\n• Count money before handing item\n• Check bills are genuine\n• Confirm payment received\n\nStay safe with payments!";
    }

    // Distance/Location/Nearby
    if (lowerInput.contains('distance') ||
        lowerInput.contains('location') ||
        lowerInput.contains('nearby') ||
        lowerInput.contains('near me')) {
      return "📍 **Location & Distance:**\n\n**How It Works:**\n• App uses your device location\n• Shows distance to each item\n• Displays nearby offers first\n\n**Privacy:**\n• Exact location not shared\n• Others see approximate distance\n• You control location permissions\n\n**Finding Nearby Items:**\n• Home screen: 'Nearby Offers'\n• Sorted by closest first\n• Distance shown on each card\n\n**Permissions:**\n• Enable location in settings\n• Required for distance feature\n• Can disable anytime\n\nHaving location issues?";
    }

    // Default response for unknown queries
    return "I'm not sure I understand that question. 🤔\n\nI can help you with:\n• **Buying, Selling, Swapping** items\n• **Posting** your own items\n• **Using app features**\n• **Safety tips**\n• **Troubleshooting** issues\n• **Managing your account**\n\nCould you rephrase your question, or ask about one of these topics?";
  }

  /// Sends user message and gets response
  void sendMessage(String userInput) {
    if (userInput.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    chatDisplay.add({"role": "user", "content": userInput});
    _controller.clear();

    // Simulate slight delay for realistic feel
    Future.delayed(const Duration(milliseconds: 500), () {
      final response = getResponse(userInput);

      chatDisplay.add({"role": "assistant", "content": response});

      setState(() {
        _isLoading = false;
      });
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
                          borderSide: BorderSide(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(
                            color: Colors.blue.shade600,
                            width: 2,
                          ),
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
