import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:async';
import 'url.dart';

class DetailChatPage extends StatefulWidget {
  final int conversationId;

  DetailChatPage({required this.conversationId});

  @override
  _DetailChatPageState createState() => _DetailChatPageState();
}

class _DetailChatPageState extends State<DetailChatPage> {
  List<dynamic> _messages = [];
  String? _token;
  int? _currentUserId;
  final _messageController = TextEditingController();
  late WebSocketChannel _channel;
  Timer? _pingTimer;

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchMessages();
    _connectToWebSocket();
  }

  void _connectToWebSocket() {
    _channel = WebSocketChannel.connect(
      Uri.parse(Url.socketUrl),
    );

    _channel.sink.add(jsonEncode({
      "event": "pusher:subscribe",
      "data": {
        "channel": "conversation.${widget.conversationId}",
      },
    }));

    _channel.stream.listen((message) {
      final data = jsonDecode(message);

      if (data['event'] == 'message.sent') {
        final msgData = jsonDecode(data['data']);

        if (msgData['sender_id'] != _currentUserId) {
          _addMessage(msgData);
        }
      }
    });

    _startPingTimer();
  }

  void _startPingTimer() {
    const pingInterval = Duration(seconds: 15);
    _pingTimer = Timer.periodic(pingInterval, (timer) {
      _sendPing();
    });
  }

  void _sendPing() {
    _channel.sink.add(jsonEncode({
      "event": "ping",
    }));
    print('Ping sent');
  }

  Future<void> _loadTokenAndFetchMessages() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    int? userId = prefs.getInt('userId');

    if (token != null) {
      setState(() {
        _token = token;
        _currentUserId = userId;
      });
      await _fetchMessages(token);
    } else {
      print('Token tidak ditemukan');
    }
  }

  Future<void> _fetchMessages(String token) async {
    final response = await http.get(
      Uri.parse(
          '${Url.getmessageUrl}${widget.conversationId}'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      setState(() {
        _messages = jsonDecode(response.body)['data'];
      });
      print('Berhasil mendapatkan pesan');
    } else {
      print('Gagal mendapatkan pesan. Status code: ${response.statusCode}');
    }
  }

  void _addMessage(Map<String, dynamic> msgData) {
    setState(() {
      _messages.insert(0, {
        'message': msgData['message'],
        'sender_id': msgData['sender_id'],
        'created_at': msgData['created_at'],
      });
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty) {
      return;
    }

    final String messageText = _messageController.text;

    try {
      final response = await http.post(
        Uri.parse(Url.postmessageUrl),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'conversation_id': widget.conversationId,
          'sender_id': _currentUserId,
          'message': messageText,
        }),
      );

      if (response.statusCode == 200) {
        _addMessage({
          'message': messageText,
          'sender_id': _currentUserId,
          'created_at': DateTime.now().toString(),
        });
        _messageController.clear();
      } else {
        print('Gagal mengirim pesan. Status code: ${response.statusCode}');
      }
    } catch (error) {
      print('Terjadi kesalahan saat mengirim pesan: $error');
    }
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _channel.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Percakapan ${widget.conversationId}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(child: Text('Tidak ada pesan'))
                : ListView.builder(
                    reverse: true, 
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMe = message['sender_id'] == _currentUserId;

                      return AnimatedContainer(
                        duration: Duration(
                            milliseconds: 300),
                        curve: Curves.easeInOut,
                        margin:
                            EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[100] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            Text(
                              message['message'],
                              style: TextStyle(fontSize: 16),
                            ),
                            SizedBox(height: 5),
                            Text(
                              message['created_at'],
                              style: TextStyle(
                                  fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
