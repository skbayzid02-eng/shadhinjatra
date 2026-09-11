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
    return MaterialApp(
      title: 'Shadhin Jatra User',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Shadhin Jatra API Status'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _apiStatus = 'Checking status...';
  bool _isLoading = false;

  Future<void> _checkApiStatus() async {
    setState(() {
      _isLoading = true;
      _apiStatus = 'Checking status...';
    });
    
    try {
      final response = await http.get(Uri.parse('https://shadhinjatra.test/api/status'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _apiStatus = 'Success: ${data['message']}\nVersion: ${data['version']}';
        });
      } else {
        setState(() {
          _apiStatus = 'Error: Received status code ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _apiStatus = 'Error connecting to API:\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _checkApiStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'API Status:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _isLoading 
                  ? const CircularProgressIndicator() 
                  : Text(
                      _apiStatus,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _checkApiStatus,
        tooltip: 'Refresh Status',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
