// ignore_for_file: unrelated_type_equality_checks

import 'package:contacts_service/contacts_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voicelines/pages/auth_page.dart';
import 'package:voicelines/pages/contact_page.dart';

import '../globals/global.dart';
import 'chat_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String currentUserPhone;
  List<Contact> _contacts = [];

  @override
  void initState() {
    super.initState();
    currentUserPhone = prefs.getString('phone')!;
    _getContacts();
  }

  Future<void> _getContacts() async {
    await requestContactsPermission();
    Iterable<Contact> contacts =
        await ContactsService.getContacts(withThumbnails: false);

    List<Contact> phoneContacts = contacts
        .where((contact) =>
            contact.phones!.isNotEmpty &&
            contact.displayName != null &&
            contact.displayName!.isNotEmpty)
        .toList();

    setState(() {
      _contacts = phoneContacts;
    });
  }

  String _getLast10Digits(String phoneNumber) {
    if (phoneNumber.length >= 10) {
      return phoneNumber.substring(phoneNumber.length - 10);
    } else {
      return phoneNumber;
    }
  }

  Future<void> requestContactsPermission() async {
    final PermissionStatus status = await Permission.contacts.request();
    if (status.isGranted) {
    } else if (status.isDenied) {
      // Handle denied permission
      print('Contacts permission denied.');
    } else if (status.isPermanentlyDenied) {
      // Handle permanently denied permission
      print('Contacts permission permanently denied.');
    }
  }

  String _getContactDisplayName(String phoneNumber) {
    for (var contact in _contacts) {
      if (contact.phones!.isNotEmpty &&
          _getLast10Digits(contact.phones!.first.value.toString()) ==
              _getLast10Digits(phoneNumber)) {
        return contact.displayName ?? phoneNumber;
      }
    }

    return phoneNumber;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Voiceline",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: () async {
                FirebaseAuth _auth = FirebaseAuth.instance;
                try {
                  await _auth.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => AuthPage()),
                  );
                } catch (e) {
                  print("Error during logout: $e");
                }
              },
              icon: Icon(
                Icons.logout,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.yellow[800],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chats')
            .where('participants.user1', isEqualTo: currentUserPhone)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          List<QueryDocumentSnapshot> conversations = snapshot.data!.docs;
          Stream<QuerySnapshot> secondStream = _firestore
              .collection('chats')
              .where('participants.user2', isEqualTo: currentUserPhone)
              .snapshots();

          return StreamBuilder<QuerySnapshot>(
            stream: secondStream,
            builder: (context, snapshot2) {
              if (!snapshot2.hasData) {
                return Center(child: CircularProgressIndicator());
              }
              conversations.addAll(snapshot2.data!.docs);
              Set<String> uniquePontactPhoneNumber = {};
              for (int i = 0; i < conversations.length; i++) {
                uniquePontactPhoneNumber.add(conversations[i]['participants']
                            ['user1'] ==
                        currentUserPhone
                    ? conversations[i]['participants']['user2']
                    : conversations[i]['participants']['user1']);
              }
              List<String> uniqueContactPhoneNumbersList =
                  uniquePontactPhoneNumber.toList();
              return ListView.builder(
                itemCount: uniqueContactPhoneNumbersList.length,
                itemBuilder: (context, index) {
                  String contactPhoneNumber =
                      uniqueContactPhoneNumbersList[index];
                  String displayName =
                      _getContactDisplayName(contactPhoneNumber);
                  return Container(
                    margin: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      title: Text(displayName),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              contactPhoneNumber: contactPhoneNumber,
                              name: displayName,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.yellow[800],
          child: Icon(
            Icons.contacts,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ContactPage()),
            );
          }),
    );
  }
}
