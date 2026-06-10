import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';  // ✅ YEH LINE ADD KARO
import 'dart:io';
import 'call_screen.dart';  // ✅ Yeh line add karo
import 'package:flutter/foundation.dart' show kIsWeb;


class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;
  
  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isUploading = false;
  
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;
  
  String get _chatId {
    if (_currentUserId == null) return '';
    List<String> ids = [_currentUserId!, widget.receiverId];
    ids.sort();
    return ids.join('_');
  }
  
  // Pick Image from Camera or Gallery
  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    
    if (image != null) {
      await _uploadFile(File(image.path), 'image');
    }
  }
  
  // Pick Video
  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    
    if (result != null) {
      File videoFile = File(result.files.single.path!);
      await _uploadFile(videoFile, 'video');
    }
  }
  
  // Upload File to Firebase Storage
  Future<void> _uploadFile(File file, String type) async {
    setState(() => _isUploading = true);
    
    try {
      // Generate unique filename
      String fileName = '${DateTime.now().millisecondsSinceEpoch}_${_currentUserId}';
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_media')
          .child(_chatId)
          .child('$type')
          .child(fileName);
      
      // Upload file
      TaskSnapshot uploadTask = await storageRef.putFile(file);
      String downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Save message to Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
        'type': type, // 'image' or 'video'
        'url': downloadUrl,
        'senderId': _currentUserId,
        'receiverId': widget.receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false,
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }
  
  // Send Text Message
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (_currentUserId == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(_chatId)
          .collection('messages')
          .add({
        'type': 'text',
        'text': _messageController.text.trim(),
        'senderId': _currentUserId,
        'receiverId': widget.receiverId,
        'timestamp': FieldValue.serverTimestamp(),
        'seen': false,
      });
      
      _messageController.clear();
      
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending message: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  // Show Bottom Sheet for Media Options
  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera, color: Colors.blue),
              title: Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.green),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.video_library, color: Colors.orange),
              title: Text('Choose Video'),
              onTap: () {
                Navigator.pop(context);
                _pickVideo();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning, size: 64, color: Colors.orange),
              SizedBox(height: 16),
              Text('Please login again'),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Text(
                widget.receiverName[0].toUpperCase(),
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 10),
            Text(widget.receiverName),
          ],
        ),
        centerTitle: false,
        actions: kIsWeb
    ? []  // ✅ Web par call button show nahi hoga
    : [   // ✅ Mobile par call button show hoga
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CallScreen(
                  channelName: _chatId,
                  callType: 'audio',
                  receiverId: widget.receiverId,
                  receiverName: widget.receiverName,
                ),
              ),
            );
          },
          icon: Icon(Icons.call, color: Colors.blue),
        ),
        IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CallScreen(
                  channelName: _chatId,
                  callType: 'video',
                  receiverId: widget.receiverId,
                  receiverName: widget.receiverName,
                ),
              ),
            );
          },
          icon: Icon(Icons.videocam, color: Colors.blue),
        ),
      ],
      ),  

      body: Column(
        children: [
          // Messages List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                
                final messages = snapshot.data!.docs;
                
                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Say hi to ${widget.receiverName}!',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final messageData = messages[index].data() as Map<String, dynamic>;
                        final isMe = messageData['senderId'] == _currentUserId;
                        final messageType = messageData['type'] ?? 'text';
                        
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 4),
                            padding: messageType == 'text' 
                                ? EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                                : EdgeInsets.zero,
                            decoration: BoxDecoration(
                              gradient: isMe && messageType == 'text'
                                  ? LinearGradient(
                                      colors: [Colors.blue.shade400, Colors.blue.shade700],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: isMe && messageType == 'text' 
                                  ? null 
                                  : messageType == 'text' 
                                      ? Colors.grey.shade200 
                                      : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                messageType == 'text' ? 20 : 12
                              ),
                            ),
                            child: _buildMessageContent(messageData, isMe, messageType),
                          ),
                        );
                      },
                    ),
                    if (_isUploading)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Uploading media...', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          
          // Message Input Bar with Media Button
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 5,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Media Button
                IconButton(
                  onPressed: _showMediaOptions,
                  icon: Icon(Icons.attach_file, color: Colors.blue),
                ),
                
                // Text Field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        prefixIcon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                
                // Send Button
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade700],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Build Message Content based on type
  Widget _buildMessageContent(Map<String, dynamic> messageData, bool isMe, String type) {
    switch (type) {
      case 'image':
        return GestureDetector(
          onTap: () {
            // Full screen image viewer
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenImage(imageUrl: messageData['url']),
              ),
            );
          },
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: CachedNetworkImageProvider(messageData['url']),
                fit: BoxFit.cover,
              ),
            ),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: EdgeInsets.all(4),
                child: Text(
                  _formatTime(messageData['timestamp']),
                  style: TextStyle(fontSize: 10, color: Colors.white, shadows: [
                    Shadow(blurRadius: 4, color: Colors.black),
                  ]),
                ),
              ),
            ),
          ),
        );
        
      case 'video':
        return GestureDetector(
          onTap: () {
            // Video player screen
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(videoUrl: messageData['url']),
              ),
            );
          },
          child: Stack(
            children: [
              Container(
                width: 250,
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: NetworkImage(messageData['url']),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.play_circle_filled,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Text(
                    _formatTime(messageData['timestamp']),
                    style: TextStyle(fontSize: 10, color: Colors.white, shadows: [
                      Shadow(blurRadius: 4, color: Colors.black),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        );
        
      default: // text
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              messageData['text'],
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 4),
            Text(
              _formatTime(messageData['timestamp']),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : Colors.grey.shade600,
              ),
            ),
          ],
        );
    }
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

// Full Screen Image Viewer
class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  const FullScreenImage({required this.imageUrl});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

// Video Player Screen
class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerScreen({required this.videoUrl});
  
  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : CircularProgressIndicator(),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}