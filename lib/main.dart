import 'dart:async';
import 'dart:developer';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

var tag_id = '';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const DefaultTabController(length: 2, child: MyHomePage(title: 'Fridge Tracker!'),)
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  ValueNotifier<dynamic> result = ValueNotifier(null);
  final myController = TextEditingController();
  Future<List> getProducts() async {
    final response = await http.get(Uri.parse(
        'http://10.0.2.2:5000/api/products'));
    if (response.statusCode == 200) {
      final List result = json.decode(response.body);
      return result.toList();
    } else {
      throw Exception('Failed to load data');
    }
  }
  Future<List> getTracked() async {
    final response = await http.get(Uri.parse(
        'http://10.0.2.2:5000/api/trackProducts'));
    if (response.statusCode == 200) {
      final List result = json.decode(response.body);
      return result.toList();
    } else {
      throw Exception('Failed to load data');
    }
  }
  late Future<List> futureProducts = getProducts();
  late Future<List> futureTracked = getTracked();
  late Future<bool> nfc = NfcManager.instance.isAvailable();
  void _tagRead(String name) {
    tag_id = '';
    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      result.value = tag.data;
      if((result.value).toString() != null){
        String data = (result.value).toString().substring(21, 49);
        data.split(',').forEach((element) =>
        {
          tag_id += int.parse(element).toRadixString(16) + ":"
        });
        tag_id = tag_id.substring(0, tag_id.length - 1);
        NfcManager.instance.stopSession();
        http.post(
          Uri.parse('http://10.0.2.2:5000//api/scanProducts'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, String>{
            'name': name,
            'tag_id': tag_id
          }),
        );
      }
    }

    );
  }
  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    myController.dispose();
    super.dispose();
  }

  void _addProduct(String text) {
    http.post(
      Uri.parse('http://10.0.2.2:5000/api/products'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'name': text,
      }),
    );
  }
  Future<void> _pullRefresh() async {
    setState(() {
      futureProducts = getProducts();
      futureTracked = getTracked();
    });
    // why use freshNumbers var? https://stackoverflow.com/a/52992836/2301224
  }
  void _fetchData(BuildContext context,String name, [bool mounted = true]) async {
    // show the loading dialog
    showDialog(
      // The user CANNOT close this dialog  by pressing outsite it
        barrierDismissible: false,
        context: context,
        builder: (_) {
          return Dialog(
            // The background color
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // The loading indicator
                  CircularProgressIndicator(),
                  SizedBox(
                    height: 15,
                  ),
                  // Some text
                  Text('Scanning ' + name + '...')
                ],
              ),
            ),
          );
        });
    // once: true` only scans one tag!
    await Future.delayed(const Duration(seconds: 5), () {
      _tagRead(name); // Prints after 1 second.
    });
    // Close the dialog programmatically
    // We use "mounted" variable to get rid of the "Do not use BuildContexts across async gaps" warning
    if (!mounted) return;
    Navigator.of(context).pop();
  }
    @override
    Widget build(BuildContext context) {
      // This method is rerun every time setState is called, for instance as done
      // by the _incrementCounter method above.
      //
      // The Flutter framework has been optimized to make rerunning build methods
      // fast, so that you can just rebuild anything that needs updating rather
      // fast, so that you can just rebuild anything that needs updating rather
      // than having to individually change instances of widgets.
      return Scaffold(
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
          appBar: AppBar(
            // Here we take the value from the MyHomePage object that was created by
            // the App.build method, and use it to set our appbar title.
            title: Text(widget.title),
            bottom: const TabBar(
              tabs: [
                Tab(text: "Products"),
                Tab(text: "Track"),
              ],
            ),
          ),
          body: TabBarView(
            children: <Widget>[
              FutureBuilder(
                future: futureProducts,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _pullRefresh,
                              child: ListView.builder(
                                  itemCount: snapshot.data?.length,
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                      onTap: (() =>
                                      {
                                        _fetchData(context,snapshot.data?[index])
                                      }),
                                      child:
                                      Card(
                                          child: ListTile(
                                            title: Text(snapshot.data?[index]),
                                          ),
                                      ),

                                    );
                                  }),
                            ),
                          ),
                          TextField(
                              controller: myController,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Add item',
                                suffixIcon: IconButton(
                                  icon: Icon(Icons.add),
                                  onPressed: (() =>
                                  {
                                    if(myController.text != "")
                                      {
                                        setState(() {
                                          _addProduct(myController.text);
                                          myController.text = "";
                                          futureProducts = getProducts();
                                        })
                                      }
                                  }),
                                ),
                              )
                          ),

                        ],
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Text('${snapshot.error}');
                  }

                  // By default, show a loading spinner.
                  return const CircularProgressIndicator();
                },
              ),
              FutureBuilder(
                future: futureTracked,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _pullRefresh,
                              child: ListView.builder(
                                  itemCount: snapshot.data?.length,
                                  itemBuilder: (context, index) {
                                    return Card(
                                        child: ListTile(
                                            title: Text(
                                                snapshot.data?[index]['name']),
                                            subtitle: Text(snapshot
                                                .data?[index]['date']),
                                        ));

                                  }),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Text('${snapshot.error}');
                  }

                  // By default, show a loading spinner.
                  return const CircularProgressIndicator();
                },
              ),
            ],
          ));
    }
  }
