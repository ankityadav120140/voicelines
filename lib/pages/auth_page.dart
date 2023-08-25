// ignore_for_file: avoid_unnecessary_containers, prefer_const_constructors, use_build_context_synchronously, prefer_const_literals_to_create_immutables

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:country_calling_code_picker/picker.dart';
import 'package:voicelines/globals/global.dart';
import 'package:voicelines/pages/home_page.dart';

final _formKey = GlobalKey<FormState>();
final FirebaseAuth auth = FirebaseAuth.instance;

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late TextEditingController phone;
  late TextEditingController otp;
  Country? _selectedCountry;
  String VerificationID = "";

  void _onPressedShowDialog() async {
    final country = await showCountryPickerDialog(
      context,
    );
    if (country != null) {
      setState(() {
        _selectedCountry = country;
      });
    }
  }

  void _onPressedShowBottomSheet() async {
    final country = await showCountryPickerSheet(
      context,
    );
    if (country != null) {
      setState(() {
        _selectedCountry = country;
      });
    }
  }

  Future<void> _sendVerificationCode(String phoneNumber) async {
    FirebaseAuth _auth = FirebaseAuth.instance;
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-retrieval of verification code completed.
        // Sign in with the received credentials.
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (e.code == 'invalid-phone-number') {
          print('The provided phone number is not valid.');
        } else {
          print('Verification failed. Code: ${e.code}');
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        // Save the verification ID and resend token for later use
        // For now, just print them to the console
        print('Verification code sent to $phoneNumber');
        print('Verification ID: $verificationId');
        print('Resend token: $resendToken');
        prefs.setString(
            'phone', phoneNumber.substring(phoneNumber.length - 10));
        setState(() {
          _progress = false;
          _otpSent = true;
          VerificationID = verificationId;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        print('Auto retrieval timeout: $verificationId');
      },
    );
  }

  @override
  void initState() {
    initCountry();
    phone = TextEditingController(text: "");
    otp = TextEditingController(text: "");
    super.initState();
  }

  void initCountry() async {
    final country = await getDefaultCountry(context);
    setState(() {
      _selectedCountry = country;
    });
  }

  bool _otpSent = false;
  bool _progress = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Log in"),
        backgroundColor: Colors.yellow[800],
      ),
      body: _progress
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(
                    height: 20,
                  ),
                  Text("Please Wait")
                ],
              ),
            )
          : Container(
              padding: EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    child: Text(
                      _otpSent ? "Enter OTP" : "Enter phone number :",
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    child: _otpSent
                        ? TextFormField(
                            controller: otp,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter valid OTP';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              labelText: 'OTP',
                            ),
                          )
                        : GestureDetector(
                            onTap: _onPressedShowBottomSheet,
                            child: _selectedCountry == null
                                ? Container(
                                    child: Text(
                                      "Coutry code",
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Image.asset(
                                        _selectedCountry!.flag,
                                        package: countryCodePackageName,
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.1,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Container(
                                        child: Text(
                                          _selectedCountry!.callingCode,
                                          style: TextStyle(fontSize: 17),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.5,
                                        child: Form(
                                          key: _formKey,
                                          child: TextFormField(
                                            maxLength: 10,
                                            autofocus: true,
                                            controller: phone,
                                            keyboardType: TextInputType.phone,
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Please enter your Phone Number';
                                              }
                                              return null;
                                            },
                                            decoration: InputDecoration(
                                              labelText: "Phone Number",
                                              hintText: "0000000000",
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  Container(
                    height: 50,
                    margin: EdgeInsets.symmetric(horizontal: 40),
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_otpSent) {
                          final AuthCredential credential =
                              PhoneAuthProvider.credential(
                                  verificationId: VerificationID,
                                  smsCode: otp.text);
                          final User user =
                              (await auth.signInWithCredential(credential))
                                  .user!;
                          print('User signed in successfully: ${user.uid}');

                          final FirebaseFirestore _firestore =
                              FirebaseFirestore.instance;
                          QuerySnapshot<Map<String, dynamic>>
                              existingUserSnapshot = await _firestore
                                  .collection('users')
                                  .where('phone',
                                      isEqualTo: prefs.getString("phone"))
                                  .get();
                          if (existingUserSnapshot.size == 0) {
                            await _firestore
                                .collection('users')
                                .add({'phone': prefs.getString("phone")});
                            print(
                                'Phone number added to Firestore: ${prefs.getString("phone")}');
                          } else {
                            print(
                                'Phone number already exists in Firestore: ${prefs.getString("phone")}');
                          }
                          Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => HomePage()),
                              (route) => false);
                        } else {
                          setState(() {
                            _progress = true;
                          });
                          if (_formKey.currentState!.validate()) {
                            String phoneNumber = phone.text.trim();
                            phoneNumber =
                                "${_selectedCountry!.callingCode}$phoneNumber";
                            print("PHONE NUMBER :: $phoneNumber");
                            _sendVerificationCode(phoneNumber);
                          }
                        }
                      },
                      child: Text(
                        _otpSent ? 'Verify OTP' : 'Generate OTP',
                        style: TextStyle(
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
