PusherAS
========

Pusher.com ActionScript3 Client Library using the native AS3 event system.


###Example Script Demo:
![alt tag](http://rocketengine.io/download/pusheras_ex_demo.gif)

###Usage:
To define the pusher connection, create a new ```PusherOptions``` instance.
The ```PusherOptions``` provides several keys to define the pusher setup, disconnect / interrupt handling.
To display log messages from the PusherAS, include the  ```LoggerAS``` library from https://github.com/rocketengineio/LoggerAS into your project.
```javascript
public function PusherASExample()
{
    // Setup the LoggerAS logging framework
    LAS.addTarget(new LASTraceTarget());
    
    // Create pusher options
    var pusherOptions:PusherOptions = new PusherOptions();
    pusherOptions.applicationKey = '7eb5f11xxxxxxxxxxx';
    pusherOptions.auth_endpoint = 'http://myserver.com/auth';
    pusherOptions.origin = 'http://myapp.com';
    pusherOptions.secure = true;
    pusherOptions.autoPing = true;
    pusherOptions.pingPongBasedDisconnect = true;
    pusherOptions.pingInterval = 750;
    pusherOptions.pingPongTimeout = 15000;
    pusherOptions.interruptTimeout = 2500;
    
    // Create pusher client and connect to server
    _pusher = new Pusher(pusherOptions);
    _pusher.verboseLogging = true;
    // Pusher event handling
    _pusher.addEventListener(PusherEvent.CONNECTION_ESTABLISHED, pusher_CONNECTION_ESTABLISHED);
    // Pusher websocket event handling
    _pusher.addEventListener(PusherConnectionStatusEvent.WS_DISCONNECTED, pusher_WS_DISCONNECTED);
    _pusher.addEventListener(PusherConnectionStatusEvent.WS_FAILED, pusher_WS_FAILED);
    _pusher.addEventListener(PusherConnectionStatusEvent.WS_INTERRUPTED, pusher_WS_INTERRUPTED);
    _pusher.connect();
}
```
PusherConnectionStatusEvent.WS_DISCONNECTED will be dispatched if the socket disconnects, or if pingPongBasedDisconnect is enabled, the pingPongTimeout is reached.
```javascript
protected function pusher_WS_DISCONNECTED(event:PusherConnectionStatusEvent):void
{
    logger.error("Disconnected! " + JSON.stringify(event.data));
}
```
PusherConnectionStatusEvent.WS_FAILED will be dispatched if the socket failes for some reason.
(IOError, SecurityError) 
```javascript
protected function pusher_WS_FAILED(event:PusherConnectionStatusEvent):void
{
    logger.error("Connection Failed! " + JSON.stringify(event.data));
}
```
PusherConnectionStatusEvent.WS_INTERRUPTED will be dispatched if the socket detected a interrupt change based on ping pong timeouts. Define this timeout with ```interruptTimeout```. ```event.data.interrupted``` is true if the connections is interrupted and false if the interruption is over.
```javascript
protected function pusher_WS_INTERRUPTED(event:PusherConnectionStatusEvent):void
{
    logger.warn("Connection interrupted: " + event.data.interrupted);
}
```	
PusherEvent.CONNECTION_ESTABLISHED will be dispatched if the pusher connection is sucessfully established.
```javascript
protected function pusher_CONNECTION_ESTABLISHED(event:PusherEvent):void
{
    // Subscribe to a test channel and add a event listener to it.
    var testChannel:PusherChannel = _pusher.subscribe('test_channel');
    testChannel.addEventListener('MY_EVENT', testChannel_MY_EVENT);
}
```
Channels are able to dispatch custom events, based on ```PusherEvent```.
```javascript
protected function testChannel_MY_EVENT(event:PusherEvent):void
{
    trace('Event arrived on test_channel: ' + event.toJSON());
}
```	

For a detailed example please checkout:

https://github.com/rocketengineio/PusherAS/tree/master/flash-src/PusherASExample/src

Documents
-------
* [Publisher API Overview](http://pusher.com/docs/publisher_api_guide)
* [The Pusher Protocol](http://pusher.com/docs/pusher_protocol)


Copyright (c) 2014 Tilman Griesel - http://rocketengine.io
