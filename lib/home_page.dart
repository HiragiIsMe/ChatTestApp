import 'package:firstapp/main.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'detail_chat_page.dart';
import 'url.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _token;
  List<dynamic> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchChats();
  }

  Future<void> _loadTokenAndFetchChats() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token'); 

    if (token != null) {
      setState(() {
        _token = token;
      });

      await _fetchChats(token);
    } else {
      print('Token tidak ditemukan');
    }
  }

  Future<void> _fetchChats(String token) async {
    final response = await http.get(
      Uri.parse(Url.getconversationUrl),
      headers: {
        'Authorization': 'Bearer $token', 
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        _chats = jsonDecode(response.body)['chats']; 
      });
      print('Berhasil mendapatkan data chats');
    } else {
      print('Gagal mendapatkan data chats. Status code: ${response.statusCode}');
    }
  }

  Future<void> _refreshChats() async {
    if (_token != null) {
      await _fetchChats(_token!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Page'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => MyApp()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshChats,
        child: _chats.isEmpty
            ? Center(child: Text('Tidak ada percakapan'))
            : ListView.builder(
                itemCount: _chats.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text('${_chats[index]['username']}'),
                    subtitle: Text(_chats[index]['last_message'] ?? 'Tidak ada pesan'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailChatPage(
                            conversationId: _chats[index]['id'],
                          ),
                        ),
                      ).then((_) {
                        _refreshChats();
                      });
                    },
                  );
                },
              ),
      ),
    );
  }
}
