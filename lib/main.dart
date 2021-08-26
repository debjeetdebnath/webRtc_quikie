import 'dart:convert';
// import 'dart:html';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sdp_transform/sdp_transform.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'WebRTC '),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _offer = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer _localRenderer = new RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = new RTCVideoRenderer();

  final sdpController = TextEditingController();

  Future webViewMethod() async {
    print('In Microphone permission method');
    await Permission.microphone.request();
    webViewMethodForCamera();

  }

  Future webViewMethodForCamera() async{
    print('In Camera permission method');
    await Permission.camera.request();
  }

  @override
  dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    sdpController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    initRenderer();
    _createPeerConnecion().then((pc) {
      _peerConnection = pc;
    });
    // _getUserMedia();
    super.initState();
  }

  initRenderer() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  _createPeerConnecion() async {
    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    _localStream = await _getUserMedia();

    RTCPeerConnection pc =
    await createPeerConnection(configuration, offerSdpConstraints);

    pc.addStream(_localStream!);

    pc.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMlineIndex,
        }));
      }
    };

    pc.onIceConnectionState = (e) {
      print(e);
    };

    pc.onAddStream = (stream) {
      print('addStream: ' + stream.id);
      _remoteRenderer.srcObject = stream;
    };

    return pc;
  }

  _getUserMedia() async {
    final Map<String, dynamic> constraints = {
      'audio': false,
      'video': {
        'facingMode': 'user',
      },
    };

    MediaStream stream = await navigator.mediaDevices.getUserMedia(constraints);

    _localRenderer.srcObject = stream;

    return stream;
  }

  void _createOffer() async {
    RTCSessionDescription description =
    await _peerConnection!.createOffer({'offerToReceiveVideo': 1});
    var session = parse(description.sdp.toString());
    print(json.encode(session));
    _offer = true;

    _peerConnection!.setLocalDescription(description);
  }

  void _createAnswer() async {
    RTCSessionDescription description =
    await _peerConnection!.createAnswer({'offerToReceiveVideo': 1});

    var session = parse(description.sdp.toString());
    print(json.encode(session));
    _peerConnection!.setLocalDescription(description);
  }

  void _setRemoteDescription() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');

    String sdp = write(session, null);

    RTCSessionDescription description =
    new RTCSessionDescription(sdp, _offer ? 'answer' : 'offer');
    print(description.toMap());

    await _peerConnection!.setRemoteDescription(description);
  }

  void _addCandidate() async {
    String jsonString = sdpController.text;
    dynamic session = await jsonDecode('$jsonString');
    print(session['candidate']);
    dynamic candidate =
    new RTCIceCandidate(session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection!.addCandidate(candidate);
  }

  SizedBox videoRenderers() => SizedBox(
      height: 210,
      child: Row(children: [
        Flexible(
          child: new Container(
              key: new Key("local"),
              margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: new BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_localRenderer)),
        ),
        Flexible(
          child: new Container(
              key: new Key("remote"),
              margin: new EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
              decoration: new BoxDecoration(color: Colors.black),
              child: new RTCVideoView(_remoteRenderer)),
        )
      ]));

  Row offerAndAnswerButtons() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
        new ElevatedButton(
          onPressed: _createOffer,
          child: Text('Offer'),
          // color: Colors.amber,
        ),
        ElevatedButton(
          onPressed: _createAnswer,
          child: Text('Answer'),
          style: ElevatedButton.styleFrom(primary: Colors.amber),
        ),
      ]);

  Row sdpCandidateButtons() =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: <Widget>[
        ElevatedButton(
          onPressed: _setRemoteDescription,
          child: Text('Set Remote Desc'),
          // color: Colors.amber,
        ),
        ElevatedButton(
          onPressed: _addCandidate,
          child: Text('Add Candidate'),
          // color: Colors.amber,
        )
      ]);

  Padding sdpCandidatesTF() => Padding(
    padding: const EdgeInsets.all(16.0),
    child: TextField(
      controller: sdpController,
      keyboardType: TextInputType.multiline,
      maxLines: 4,
      maxLength: TextField.noMaxLength,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Container(
            child: Container(
                child: Column(
                  children: [
                    videoRenderers(),
                    offerAndAnswerButtons(),
                    sdpCandidatesTF(),
                    sdpCandidateButtons(),
                  ],
                ))
        ));
  }
}
// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   // This widget is the root of your application.
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'WebRTC',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//         visualDensity: VisualDensity.adaptivePlatformDensity,
//       ),
//       home: MyHomePage(title: 'WebRTC'),
//     );
//   }
// }
//
// class MyHomePage extends StatefulWidget {
//   MyHomePage({required this.title});
//
//   final String title;
//
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   final _localRenderer = new RTCVideoRenderer();
//   final _remoteRender = RTCVideoRenderer();
//
//   late MediaStream _localStream;
//   Future webViewMethod() async {
//     print('In Microphone permission method');
//     await Permission.microphone.request();
//     webViewMethodForCamera();
//
//   }
//
//   Future webViewMethodForCamera() async{
//     print('In Camera permission method');
//     await Permission.camera.request();
//   }
//
//   @override
//   dispose() {
//     _localStream.dispose();
//     _localRenderer.dispose();
//     _remoteRender.dispose();
//     super.dispose();
//   }
//
//   @override
//   void initState() {
//     webViewMethod();
//     initRenderers();
//     _getUserMedia();
//     super.initState();
//   }
//
//   initRenderers() async {
//     await _localRenderer.initialize();
//     await _remoteRender.initialize();
//   }
//
//   _getUserMedia() async {
//     final Map<String, dynamic> mediaConstraints = {
//       'audio': true,
//       'video': {
//         'mandatory': {
//           'minWidth':
//               '1920',
//           'minHeight': '720',
//           'minFrameRate': '30',
//         },
//         'facingMode': 'user',
//         'optional': [],
//       },
//     };
//
//     _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
//
//     _localRenderer.srcObject = _localStream;
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.title),
//         centerTitle: true,
//       ),
//     body: SafeArea(
//       child: Column(
//         children: <Widget> [
//           Flexible(
//             child: RTCVideoView(
//               _localRenderer,
//               mirror: true,
//             ),
//           ),
//           Flexible(
//             child: RTCVideoView(
//               _remoteRender,
//               mirror: true,
//             ),
//           )
//         ],
//       ),
//     ),
//     );
//   }
// }
//
//
// // body: new Stack(
// // children: <Widget>[
// // Align(
// // alignment:Alignment.topLeft,
// // child: Container(
// // width: 0.45*MediaQuery.of(context).size.width,
// // height: 0.4*MediaQuery.of(context).size.height,
// // child:  RTCVideoView(
// // _localRenderer,
// // mirror: true,)
// // ),
// // ),
// // ],
// // ),
// // body: OrientationBuilder(
// //   builder: (context, orientation) {
// //       return Container(
// //         margin: EdgeInsets.fromLTRB(0.0, 5.0, 250.0, 320.0),
// //         width: 0.5*MediaQuery.of(context).size.width,
// //         height: 0.5*MediaQuery.of(context).size.height,
// //         child: RTCVideoView(_localRenderer, mirror: true),
// //         // decoration: BoxDecoration(color: Colors.black54),
// //       );
// //   },
// // ),