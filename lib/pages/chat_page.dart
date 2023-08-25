// ignore_for_file: prefer_const_constructors, unused_field

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../globals/global.dart';

class ChatPage extends StatefulWidget {
  final String contactPhoneNumber, name;
  const ChatPage(
      {required this.contactPhoneNumber, required this.name, Key? key})
      : super(key: key);

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterTts flutterTts = FlutterTts();
  Timestamp latestTimeStamp = Timestamp.now();

  Widget messageBox(String msg, bool isCurrentUser, Timestamp ts) {
    DateTime dateTime = ts.toDate();
    return Container(
      width: msg.length > 20 ? MediaQuery.of(context).size.width * 0.6 : null,
      decoration: BoxDecoration(
        color: !isCurrentUser
            ? Colors.blue.withOpacity(0.3)
            : Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
          topLeft: isCurrentUser ? Radius.circular(10) : Radius.zero,
          topRight: isCurrentUser ? Radius.zero : Radius.circular(10),
        ),
      ),
      padding: EdgeInsets.only(
          left: isCurrentUser ? 10 : 15,
          right: isCurrentUser ? 10 : 10,
          bottom: 10,
          top: 5),
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: EdgeInsets.only(right: 20),
            child: Text(
              msg,
              style: TextStyle(fontSize: 15),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                "${dateTime.hour}:${dateTime.minute}",
                style: TextStyle(fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String mergeLast10Digits(String phoneNumber1, String phoneNumber2) {
    String last10Digits1 = phoneNumber1.substring(phoneNumber1.length - 10);
    String last10Digits2 = phoneNumber2.substring(phoneNumber2.length - 10);

    List<String> digitsList = [];
    digitsList.addAll(last10Digits1.split(''));
    digitsList.addAll(last10Digits2.split(''));
    digitsList.sort();

    return digitsList.join();
  }

  String conversationId = '';
  SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;

  Future<void> _initConversation() async {
    String currentPhone = prefs.getString('phone')!;
    String otherPhone = widget.contactPhoneNumber;

    List<String> phones = [currentPhone, otherPhone];
    phones.sort();

    conversationId = mergeLast10Digits(phones[0], phones[1]);

    // Ensure participants document exists
    await _firestore.collection('chats').doc(conversationId).set({
      'participants': {
        'user1': phones[0],
        'user2': phones[1],
      },
    }, SetOptions(merge: true));
  }

  Future<void> _showDeleteConfirmationDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Erase off?"),
          content: Text("Are you sure you want to delete this conversation?"),
          actions: <Widget>[
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text("Delete"),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                _deleteConversation();
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteConversation() async {
    await _firestore
        .collection('chats')
        .doc(conversationId)
        .collection('messages')
        .get()
        .then((snapshot) {
      for (DocumentSnapshot doc in snapshot.docs) {
        doc.reference.delete();
      }
    });
  }

  bool isMute = true;
  void _readIncomingMessage(String messageText) async {
    if (!isMute) {
      await flutterTts.setLanguage('hi-IN');
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.speak(messageText);
    }
  }

  void _startListening() async {
    await _speechToText.listen(onResult: _onSpeechResult);
    setState(() {});
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {});
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    _messageController.clear();
    setState(() {
      _messageController.text = result.recognizedWords;
    });
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  @override
  void initState() {
    _initSpeech();
    super.initState();
    _initConversation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        backgroundColor: Colors.yellow[800],
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                isMute = !isMute;
              });
            },
            icon: isMute ? Icon(Icons.volume_off) : Icon(Icons.volume_up),
          ),
          IconButton(
              icon: Icon(Icons.delete),
              onPressed: () {
                _showDeleteConfirmationDialog(context);
              }),
        ],
      ),
      body: Container(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chats')
                    .doc(mergeLast10Digits(
                        prefs.getString("phone")!, widget.contactPhoneNumber))
                    .collection('messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(),
                    );
                  } else if (snapshot.hasError) {
                    return Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      var messageData = snapshot.data!.docs[index];
                      bool isCurrentUser =
                          messageData["from"] == prefs.getString('phone');
                      bool isRead =
                          messageData["timestamp"].compareTo(latestTimeStamp) <
                              0;

                      if (!isCurrentUser && !isRead) {
                        // Read unread incoming messages using TTS
                        String messageText = messageData["text"];
                        _readIncomingMessage(messageText);
                        latestTimeStamp = messageData["timestamp"];
                      }
                      return Row(
                        mainAxisAlignment: isCurrentUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          messageBox(
                            messageData["text"],
                            isCurrentUser,
                            messageData["timestamp"],
                          )
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              minLines: 1,
              maxLines: 3,
              controller: _messageController,
              decoration: InputDecoration(labelText: 'Type your message'),
            ),
          ),
          IconButton(
            onPressed:
                _speechToText.isNotListening ? _startListening : _stopListening,
            tooltip: 'Listen',
            icon:
                Icon(_speechToText.isNotListening ? Icons.mic_off : Icons.mic),
          ),
          IconButton(
            icon: Icon(
              Icons.send,
              size: 40,
            ),
            onPressed: () {
              _sendMessage();
            },
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    String messageText = _messageController.text.trim();
    if (messageText.isNotEmpty) {
      _firestore
          .collection('chats')
          .doc(conversationId)
          .collection('messages')
          .add({
        'text': messageText,
        'timestamp': Timestamp.now(),
        'from': prefs.getString('phone'),
      });
      latestTimeStamp = Timestamp.now();
      _messageController.clear();
    }
  }
}
