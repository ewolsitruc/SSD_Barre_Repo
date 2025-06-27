import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

class TestFunctionPage extends StatefulWidget {
  @override
  _TestFunctionPageState createState() => _TestFunctionPageState();
}

class _TestFunctionPageState extends State<TestFunctionPage> {
  String _result = '';

  Future<void> _callFunction() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendDirectMessage');
      final result = await callable.call(<String, dynamic>{
        'recipientUid': 'CA4bHCHQ0bbQYnwI0jMwnnJg6Am2',
        'content': 'Hello from emulator test!',
      });
      setState(() {
        _result = 'Function result: ${result.data}';
      });
    } catch (e) {
      setState(() {
        _result = 'Function call error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Test Function')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _callFunction,
              child: Text('Send Test Message'),
            ),
            SizedBox(height: 20),
            Text(_result),
          ],
        ),
      ),
    );
  }
}
