// ignore_for_file: prefer_const_constructors

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:voicelines/globals/global.dart';
import 'package:voicelines/pages/chat_page.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  List<Contact> _contacts = [];
  List<String> _appUsers = [];

  @override
  void initState() {
    super.initState();
    _getAppUsers();
    _getContacts();
  }

  Future<void> _getAppUsers() async {
    List<String> appUsers = [];
    QuerySnapshot<Map<String, dynamic>> querySnapshot =
        await FirebaseFirestore.instance.collection('users').get();
    querySnapshot.docs.forEach((doc) {
      appUsers.add(doc.data()['phone'].toString());
    });
    setState(() {
      _appUsers = appUsers;
    });
  }

  Future<void> _getContacts() async {
    await requestContactsPermission();
    Iterable<Contact> contacts =
        await ContactsService.getContacts(withThumbnails: false);

    List<String> formattedAppUsers =
        _appUsers.map((phoneNumber) => _getLast10Digits(phoneNumber)).toList();

    List<Contact> phoneContacts = contacts
        .where((contact) =>
            contact.phones!.isNotEmpty &&
            contact.displayName != null &&
            contact.displayName!.isNotEmpty)
        .toList();

    List<Contact> appContacts = [];
    phoneContacts.forEach((contact) {
      for (var phone in contact.phones!) {
        if (formattedAppUsers.contains(_getLast10Digits(phone.value!))) {
          String displayName = contact.displayName ?? "No Name";
          String phoneNumber = _getLast10Digits(phone.value!);
          Contact customContact = Contact(
            displayName: displayName,
            phones: [Item(value: phoneNumber)],
          );
          appContacts.add(customContact);
          break;
        }
      }
    });

    setState(() {
      _contacts = appContacts;
      loading = false;
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

  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Contacts",
              style: TextStyle(),
            ),
            IconButton(
                onPressed: () {
                  setState(() {
                    loading = true;
                  });
                  _getAppUsers();
                  _getContacts();
                },
                icon: Icon(Icons.replay_outlined))
          ],
        ),
        backgroundColor: Colors.yellow[800],
      ),
      body: loading
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                ),
                CircularProgressIndicator(),
                SizedBox(
                  height: 20,
                ),
                Text("Refreshing Contacts"),
              ],
            )
          : Container(
              child: Column(
                children: [
                  Expanded(
                    child: _contacts.isNotEmpty
                        ? ListView.builder(
                            itemCount: _contacts.length,
                            itemBuilder: (BuildContext context, int index) {
                              Contact contact = _contacts[index];
                              if (prefs.getString("phone") ==
                                  _getLast10Digits(
                                      contact.phones!.first.value!)) {
                                return Container();
                              }
                              return InkWell(
                                onTap: () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => ChatPage(
                                                contactPhoneNumber:
                                                    _getLast10Digits(contact
                                                        .phones!.first.value!),
                                                name: contact.displayName!,
                                              )));
                                },
                                child: Container(
                                  margin: EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10)),
                                  child: ListTile(
                                    title: Text(contact.displayName!),
                                    subtitle: Text(_getLast10Digits(
                                        contact.phones!.first.value!)),
                                  ),
                                ),
                              );
                            },
                          )
                        : Center(
                            child: Text(
                                "None of your contacts are using voicelines"),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
