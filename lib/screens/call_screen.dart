import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

class CallScreen extends StatefulWidget {
  final String channelName;
  final String callType;
  final String receiverId;
  final String receiverName;

  const CallScreen({
    super.key,
    required this.channelName,
    required this.callType,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  @override
  Widget build(BuildContext context) {
    // ✅ WEB PE CALL SUPPORT NAHI
    if (kIsWeb) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Call'),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                'Audio/Video calling is not supported on Web',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Please use the mobile app for calls',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ MOBILE (ANDROID / iOS) KE LIYE ACTUAL CALL UI
    return _MobileCallScreen(
      channelName: widget.channelName,
      callType: widget.callType,
      receiverId: widget.receiverId,
      receiverName: widget.receiverName,
    );
  }
}

// ─────────────────────────────────────────────
// MOBILE CALL SCREEN
// ─────────────────────────────────────────────
class _MobileCallScreen extends StatefulWidget {
  final String channelName;
  final String callType;
  final String receiverId;
  final String receiverName;

  const _MobileCallScreen({
    required this.channelName,
    required this.callType,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<_MobileCallScreen> createState() => _MobileCallScreenState();
}

class _MobileCallScreenState extends State<_MobileCallScreen> {
  RtcEngine? _engine;
  bool _isJoined = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOff = false;
  int? _remoteUid;

  // 🔴 APNA AGORA APP ID YAHAN DALO
  final String _appId = "75025175854d4113973ca5627784901e";

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    // ✅ Permissions request
    if (widget.callType == 'video') {
      await [Permission.microphone, Permission.camera].request();
    } else {
      await Permission.microphone.request();
    }

    // ✅ NEW API — createAgoraRtcEngine()
    _engine = createAgoraRtcEngine();

    await _engine?.initialize(RtcEngineContext(
      appId: _appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    // ✅ Event Handlers
    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('✅ Joined channel: ${connection.channelId}');
          if (mounted) {
            setState(() {
              _isJoined = true;
            });
          }
        },
        onUserJoined:
            (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('✅ Remote user joined: $remoteUid');
          if (mounted) {
            setState(() {
              _remoteUid = remoteUid;
            });
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint('❌ Remote user left: $remoteUid');
          if (mounted) {
            setState(() {
              _remoteUid = null;
            });
            _showCallEndedDialog();
          }
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('❌ Agora Error: $msg');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $msg')),
            );
          }
        },
      ),
    );

    // ✅ Video ya Audio enable karo
    if (widget.callType == 'video') {
      await _engine?.enableVideo();
      await _engine?.startPreview();
    } else {
      await _engine?.enableAudio();
      await _engine?.setEnableSpeakerphone(true);
    }

    // ✅ Channel join karo
    await _engine?.joinChannel(
      token: "",
      channelId: widget.channelName,
      uid: 0,
      options: ChannelMediaOptions(
        autoSubscribeAudio: true,
        autoSubscribeVideo: widget.callType == 'video',
        publishMicrophoneTrack: true,
        publishCameraTrack: widget.callType == 'video',
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  // ─── CONTROLS ───────────────────────────────

  void _toggleMute() async {
    await _engine?.muteLocalAudioStream(!_isMuted);
    if (mounted) setState(() => _isMuted = !_isMuted);
  }

  void _toggleSpeaker() async {
    await _engine?.setEnableSpeakerphone(!_isSpeakerOn);
    if (mounted) setState(() => _isSpeakerOn = !_isSpeakerOn);
  }

  void _toggleCamera() async {
    await _engine?.muteLocalVideoStream(!_isCameraOff);
    if (mounted) setState(() => _isCameraOff = !_isCameraOff);
  }

  void _switchCamera() async {
    await _engine?.switchCamera();
  }

  void _leaveCall() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    if (mounted) Navigator.pop(context);
  }

  void _showCallEndedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Call Ended'),
        content: Text('${widget.receiverName} has left the call.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _leaveCall();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ─── BUILD ──────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── BACKGROUND / VIDEO VIEW ──
            widget.callType == 'video'
                ? _buildVideoView()
                : _buildAudioView(),

            // ── TOP BAR ──
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    Text(
                      widget.receiverName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isJoined
                          ? (_remoteUid != null ? '🟢 Connected' : '📞 Calling...')
                          : '⏳ Connecting...',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            // ── BOTTOM CONTROLS ──
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: widget.callType == 'video'
                  ? _buildVideoControls()
                  : _buildAudioControls(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── VIDEO VIEW ─────────────────────────────

  Widget _buildVideoView() {
    return Stack(
      children: [
        // Remote video (full screen)
        if (_remoteUid != null && _engine != null)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine!,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(channelId: widget.channelName),
            ),
          )
        else
          Container(
            color: Colors.black87,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue,
                    child: Text(
                      widget.receiverName[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.receiverName,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 22),
                  ),
                  const SizedBox(height: 8),
                  const Text('Waiting for other person...',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),

        // Local video (small — top right)
        if (_engine != null && !_isCameraOff)
          Positioned(
            top: 60,
            right: 16,
            child: Container(
              width: 110,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: Colors.black,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── AUDIO VIEW ─────────────────────────────

  Widget _buildAudioView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0d1117), Color(0xFF0a66c2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 70,
              backgroundColor: Colors.white24,
              child: Text(
                widget.receiverName[0].toUpperCase(),
                style:
                    const TextStyle(fontSize: 56, color: Colors.white),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              widget.receiverName,
              style: const TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _remoteUid == null ? '📞 Calling...' : '🟢 Connected',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  // ─── VIDEO CONTROLS ──────────────────────────

  Widget _buildVideoControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _controlButton(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          color: _isMuted ? Colors.red : Colors.white24,
          onPressed: _toggleMute,
          label: _isMuted ? 'Unmute' : 'Mute',
        ),
        _controlButton(
          icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
          color: _isCameraOff ? Colors.red : Colors.white24,
          onPressed: _toggleCamera,
          label: _isCameraOff ? 'Cam On' : 'Cam Off',
        ),
        _controlButton(
          icon: Icons.call_end,
          color: Colors.red,
          onPressed: _leaveCall,
          label: 'End',
          size: 65,
        ),
        _controlButton(
          icon: Icons.switch_camera,
          color: Colors.white24,
          onPressed: _switchCamera,
          label: 'Flip',
        ),
      ],
    );
  }

  // ─── AUDIO CONTROLS ──────────────────────────

  Widget _buildAudioControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _controlButton(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          color: _isMuted ? Colors.red : Colors.white24,
          onPressed: _toggleMute,
          label: _isMuted ? 'Unmute' : 'Mute',
        ),
        _controlButton(
          icon: Icons.call_end,
          color: Colors.red,
          onPressed: _leaveCall,
          label: 'End',
          size: 65,
        ),
        _controlButton(
          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
          color: _isSpeakerOn ? Colors.white24 : Colors.red,
          onPressed: _toggleSpeaker,
          label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
        ),
      ],
    );
  }

  // ─── CONTROL BUTTON WIDGET ───────────────────

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
    double size = 55,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style:
                const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  // ─── DISPOSE ─────────────────────────────────

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }
}