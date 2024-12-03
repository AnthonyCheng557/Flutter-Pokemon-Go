import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PromptWrapper extends StatefulWidget {
  final Widget child;
  const PromptWrapper({super.key, required this.child});

  @override
  //_
  PromptWrapperState createState() => PromptWrapperState();
}

class PromptWrapperState extends State<PromptWrapper> {
  final storage = const FlutterSecureStorage();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCredentialPrompt();
  }

  Future<void> _initializeCredentialPrompt() async {
    //check to see if the credentials is already in the storage
    String? username = await storage.read(key: 'username');
    String? password = await storage.read(key: 'password');

    if (username != null && password != null) {
      //skip if so
      setState(() {
        _initialized = true;
        //print info
        print(username.toString());
        print(password.toString());
      });
    } else {
      //otherwise continue to ask for the info
      _showPrompt();
    }
  }

  Future<void> _showPrompt() async {
    String username = '';
    String password = '';

    //show prompt once widgets is built
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Please enter your Redis Credentials'),
            content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        onChanged: (value) {
                          username = value;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'Enter Username',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (value) {
                          password = value;
                        },
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          hintText: 'Enter Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  if (username.isEmpty || password.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('All fields must be filled'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  //saave the values
                  await storage.write(key: 'username', value: username);
                  await storage.write(key: 'password', value: password);

                  //print the values
                  final printUsername = await storage.read(key: 'username');
                  final printPassword = await storage.read(key: 'password');

                  print(printUsername.toString());
                  print(printPassword.toString());

                  if (mounted) {
                    setState(() {
                      _initialized = true;
                    });
                  }
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );

      //set initialized to true after dialog clsoes
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    //load until info is given
    if (!_initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    //show the main app now
    return widget.child;
  }
}

