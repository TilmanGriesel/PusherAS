// The MIT License (MIT)
//
// Copyright (c) 2014 Tilman Griesel - <http://rocketengine.io> <http://github.com/TilmanGriesel>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//	
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//		
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//	SOFTWARE.

// Inspired by web-socket-js <https://github.com/gimite/web-socket-js>
// Copyright: Hiroshi Ichikawa <http://gimite.net/en/>
// License: New BSD License

package io.rocketengine.websocket.proxies
{
	import com.adobe.crypto.SHA1;
	import com.sociodox.utils.Base64;
	
	import flash.events.Event;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.OutputProgressEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.net.SecureSocket;
	import flash.net.Socket;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.Timer;
	
	import io.rocketengine.loggeras.logger.LAS;
	import io.rocketengine.loggeras.logger.interfaces.ILASLogger;
	import io.rocketengine.websocket.interfaces.IWSocket;
	import io.rocketengine.websocket.utils.WebsocketUtil;
	import io.rocketengine.websocket.vo.FlashWebsocketErrorCodes;
	import io.rocketengine.websocket.vo.FlashWebsocketFrame;
	import io.rocketengine.websocket.vo.FlashWebsocketState;
	
	public class FlashWebsocketProxy implements IWSocket
	{
		//--------------------------------------------------------------------------
		//
		//  Class Properties
		//
		//--------------------------------------------------------------------------
		
		private static const logger:ILASLogger = LAS.getLogger(FlashWebsocketProxy);
		
		private static const WEB_SOCKET_GUID:String = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
		
		private static const ASCII_CR:uint = 0x0d;
		private static const ASCII_NL:uint = 0x0a;
		
		private static const OPCODE_CONTINUATION:int = 0x00;
		private static const OPCODE_TEXT:int = 0x01;
		private static const OPCODE_BINARY:int = 0x02;
		private static const OPCODE_CLOSE:int = 0x08;
		private static const OPCODE_PING:int = 0x09;
		private static const OPCODE_PONG:int = 0x0a;
		
		private static const SCHEME_WS:String = 'ws';
		private static const SCHEME_WSS:String = 'wss';
		
		private static var SOCKET_TIMEOUT:Number = 5000;
		private static var PING_PONG_TIMEOUT:Number = 7500;
		private static var PING_INTERVAL:Number = 750;
		private static var INTERRUPT_THRESHOLD:Number = 2000;
		
		//--------------------------------------------------------------------------
		//
		//  Instance Properties
		//
		//--------------------------------------------------------------------------
		
		private var _dataSocket:Socket;
		private var _rawSocket:Socket;
		private var _sslSocket:SecureSocket;
		private var _state:int;
		
		private var _scheme:String;
		private var _host:String;
		private var _port:int;
		private var _path:String;
		private var _origin:String = '*';
		private var _expectedDigest:String;
		
		private var _buffer:ByteArray;
		private var _headerState:int = 0;
		
		// Callbacks
		private var _initCallback:Function;
		private var _openCallback:Function;
		private var _messageCallback:Function;
		private var _closedCallback:Function;
		private var _failedCallback:Function;
		private var _interruptCallback:Function;
	
		private var _pingTimeoutTimer:Timer;
		private var _pingTimer:Timer;
		private var _interruptTimer:Timer;
		private var _interrupted:Boolean;
		
		private var _autoPingEnabled:Boolean;
		private var _pingPongBasedDisonnect:Boolean;
		
		private var _verboseLogging:Boolean;
		
		private var _isInitialized:Boolean;
		private var _isRegistered:Boolean;
		
		//--------------------------------------------------------------------------
		//
		//  Initialization
		//
		//--------------------------------------------------------------------------
		
		public function FlashWebsocketProxy()
		{
		}
		
		/**
		 * Main intialization
		 */
		private function initialize(autopPing:Boolean, pingPongBasedDisconnect:Boolean, pingInterval:Number, pingPongTimeout:Number, interruptThreshold:Number):void
		{
			// define init state
			_state = FlashWebsocketState.CLOSED;
			
			// create buffer
			_buffer = new ByteArray();
			
			// create socket
			_rawSocket = new Socket();
			
			// create TLS socket
			try {_sslSocket = new SecureSocket();}
			catch(e:Error){ logger.warn('Failed to create secure socket!'); };
			
			// setup ping pong
			PING_INTERVAL = pingInterval;
			PING_PONG_TIMEOUT = pingPongTimeout;
			INTERRUPT_THRESHOLD = interruptThreshold;
			_autoPingEnabled = autopPing;
			_pingPongBasedDisonnect = pingPongBasedDisconnect;
			_pingTimeoutTimer = new Timer(PING_PONG_TIMEOUT, 1);
			_pingTimeoutTimer.addEventListener(TimerEvent.TIMER_COMPLETE, _pingTimeoutTimer_TIMER_COMPLETE);
			_interruptTimer = new Timer(INTERRUPT_THRESHOLD, 1);
			_interruptTimer.addEventListener(TimerEvent.TIMER_COMPLETE, _interruptTimer_TIMER_COMPLETE);
			
			// define init state
			_state = FlashWebsocketState.INITIALIZED;
			_isInitialized = true;
			if(_initCallback !== null) _initCallback(this);
			
		}
		
		//--------------------------------------------------------------------------
		//
		//  API
		//
		//--------------------------------------------------------------------------
		
		public function init(... args):void
		{
			initialize.apply(initialize, args);
		}
		
		/**
		 * Connect to websocket
		 */
		public function connect(url:String):void
		{
			if(!_isInitialized)
				throw new Error('FlashWebsocketProxy is not initialized! Call init() first.');
			
			if(_dataSocket != null && _dataSocket.connected)
			{
				logger.info('Closing previous socket connection...');
				closeConnection();
			}
			
			// extract and save connection data from url
			extractURL(url);
			logger.debug('connecting to: ', _host, ':', _port, '...');
			
			if(_host == null || _port == 0)
			{
				logger.error('Connect failed! invalid url');
			}
			else if(_state == FlashWebsocketState.INITIALIZED || _state == FlashWebsocketState.CLOSED)
			{
				buildOnConnection();
			}
			else
			{
				logger.error('Unable to connect! invalid state:', _state);
			}
		}
		
		/**
		 * Send data
		 */
		public function send(data:String):void
		{
			sendMessage(data);
		}
		
		/**
		 * Close connection
		 */
		public function close():void
		{
			closeConnection();
		}
		
		public function registerCallbacks(onInit:Function, onOpen:Function, onMessage:Function, onClose:Function, onFail:Function, onInterrupt:Function):void
		{
			// save callbacks
			_initCallback = onInit;
			_openCallback = onOpen;
			_messageCallback = onMessage;
			_closedCallback = onClose;
			_failedCallback = onFail;
			_interruptCallback = onInterrupt;
			_isRegistered = true;
		}
		
		public function unregisterCallbacks():void
		{
			_initCallback = null;
			_openCallback = null;
			_messageCallback = null;
			_closedCallback = null;
			_failedCallback = null;
			_interruptCallback = null;
			_isRegistered = false;	
		}
		
		public function dispose():void
		{	
			if(_dataSocket != null && _dataSocket.connected)
			{
				_dataSocket.close();
			}
			
			unregisterCallbacks();
			unregisterSocketEventListeners(_dataSocket);
			
			if(_pingTimer != null)
			{
				_pingTimer.removeEventListener(TimerEvent.TIMER, _pingTimer_TIMER);
				_pingTimer.stop();
				_pingTimer = null;
			}
			
			if(_pingTimeoutTimer != null)
			{
				_pingTimeoutTimer.stop();
				_pingTimeoutTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, _pingTimeoutTimer_TIMER_COMPLETE);
				_pingTimeoutTimer = null;
			}
			
			if(_interruptTimer != null)
			{
				_interruptTimer.stop();
				_interruptTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, _interruptTimer_TIMER_COMPLETE);
				_interruptTimer = null;
			}
			
			_dataSocket = null;
			_rawSocket = null;
			_sslSocket = null;
			_scheme = null;
			_host = null;
			_port = 0;
			_path = null;
			_origin = null;
			_expectedDigest = null;
			
			_buffer = null;
			_headerState = 0;
		}
		
		public function get verboseLogging():Boolean
		{
			return _verboseLogging;
		}
		
		public function set verboseLogging(value:Boolean):void
		{
			_verboseLogging = value;
		}
		
		//--------------------------------------------------------------------------
		//
		//  Eventhandling
		//
		//--------------------------------------------------------------------------
		
		//--------------------------------------------------------------------------
		//  Socket
		//--------------------------------------------------------------------------
		
		protected function _dataSocket_CONNECT(event:Event):void
		{
			logger.info('CONNECT');
			
			// start websocket handshake
			sendHandshake();
			
			if(_autoPingEnabled)
			{
				_pingTimer = new Timer(PING_INTERVAL, 0);
				_pingTimer.addEventListener(TimerEvent.TIMER, _pingTimer_TIMER);
				_pingTimer.start();	
			}
		}
		
		protected function _pingTimer_TIMER(event:TimerEvent):void
		{
			sendPingWithTS();
		}
		
		protected function _dataSocket_SOCKET_DATA(event:ProgressEvent):void
		{
			if(_verboseLogging) logger.debug('SOCKET DATA - bytesTotal:', event.bytesTotal, ', bytesLoaded:',  event.bytesLoaded);
			processSocketData();	
		}
		
		protected function _dataSocket_OUTPUT_PROGRESS(event:OutputProgressEvent):void
		{
			if(_verboseLogging) logger.debug('OUTPUT PROGRESS - bytesTotal:', event.bytesTotal, ', bytesPending:', event.bytesPending);
		}
		
		protected function _dataSocket_CLOSE(event:Event):void
		{
			logger.info('Data Socket Close');
			closeConnection(true, FlashWebsocketErrorCodes.CLOSED, "Data socket closed");
		}
		
		protected function _dataSocket_ERROR(event:IOErrorEvent):void
		{
			logger.error('Data Socket IO Error:', event.errorID);
			if(_failedCallback != null) _failedCallback(this, event.errorID, 'IOErrorEvent');
		}
		
		protected function _dataSocket_SECURITY_ERROR(event:SecurityErrorEvent):void
		{
			logger.error('Data Socket Security Error:', event.errorID);
			if(_failedCallback != null)  _failedCallback(this, event.errorID, 'SecurityErrorEvent');
		}
		
		//--------------------------------------------------------------------------
		//  Ping Timeout
		//--------------------------------------------------------------------------
		
		protected function _pingTimeoutTimer_TIMER_COMPLETE(event:TimerEvent):void
		{
			logger.error('Connection timed out! closing ...');
			closeConnection(true, FlashWebsocketErrorCodes.PING_PONG_TIMEOUT, "Connection timed out! Ping pong timeout: " + PING_PONG_TIMEOUT);
		}
		
		//--------------------------------------------------------------------------
		//  Interrupt Timeout
		//--------------------------------------------------------------------------
		
		protected function _interruptTimer_TIMER_COMPLETE(event:TimerEvent):void
		{
			if(!_interrupted)
			{
				_interruptCallback(this, true);	
				_interrupted = true;
			}
		}
		
		//--------------------------------------------------------------------------
		//
		//  Class Methods
		//
		//--------------------------------------------------------------------------
		
		//--------------------------------------------------------------------------
		//  Connection
		//--------------------------------------------------------------------------
		
		/**
		 * Main method to build up the socket connection
		 */
		private function buildOnConnection():void
		{
			if(_dataSocket != null && _dataSocket.connected)
			{
				logger.error('data socket is already connected! aborting...');
				return;
			}
			
			// define connecting state
			_state = FlashWebsocketState.CONNECTING;
			if(_scheme == SCHEME_WSS)
			{
				logger.info('using secure TLS socket');
				_dataSocket = _sslSocket;
			}
			else
			{
				logger.info('using non-secure socket');
				_dataSocket = _rawSocket
			}
			
			if(registerSocketEventListeners(_dataSocket))
			{
				_dataSocket.timeout = SOCKET_TIMEOUT;
				try
				{
					// connect socket
					_dataSocket.connect(_host, _port);			
				}
				catch(e:Error)
				{
					logger.error('failed to connect socket! Message:', e.message, 'id:', e.errorID);
				}	
			}
			else
			{
				if(_failedCallback !== null) _failedCallback(this, -1, 'unable to register socket listeners');
			}
		}
		
		/**
		 * Main method to close the socket connection
		 */
		private function closeConnection(fireCallback:Boolean = false, code:int = -1, message:String = "none"):void
		{
			if(_pingTimer != null)
			{
				_pingTimer.removeEventListener(TimerEvent.TIMER, _pingTimer_TIMER);
				_pingTimer.reset();
				_pingTimer.stop();
				_pingTimer = null;
			}
			
			if(_pingTimeoutTimer != null)
			{
				_pingTimeoutTimer.reset();
				_pingTimeoutTimer.stop();	
			}
			
			if(_interruptTimer != null)
			{
				_interruptTimer.reset();
				_interruptTimer.stop();	
			}
			
			// unregister listeners
			unregisterSocketEventListeners(_dataSocket);
			// reset header state
			_headerState = 0;
			// set socket state to open
			_state = FlashWebsocketState.CLOSED;
			
			if(_dataSocket && _dataSocket.connected)
			{
				// close socket connection
				_dataSocket.close();				
			}
			
			// inform callback about the state change
			if(fireCallback) _closedCallback(this, code, message);
		}
		
		//--------------------------------------------------------------------------
		//  Handshake
		//--------------------------------------------------------------------------
		
		/**
		 * Send protocol handshake request
		 */
		private function sendHandshake():void
		{
			var hostValue:String = _host;
			var key:String = generateKey();
			
			// calculate expected digest
			_expectedDigest = SHA1.hashToBase64(key + WEB_SOCKET_GUID);
			
			// build request
			var request:String =
				'GET ' +  _path + ' HTTP/1.1\r\n' +
				'Host: ' + hostValue + '\r\n' +
				'Upgrade: websocket\r\n' +
				'Connection: Upgrade\r\n' +
				'Sec-WebSocket-Key: ' + key + '\r\n' +
				'Origin: ' + _origin + '\r\n' +
				'Sec-WebSocket-Version: 13\r\n\r\n';
			
			
			if(_verboseLogging) logger.debug('request header:\n' + request);
			_dataSocket.writeUTFBytes(request);
			_dataSocket.flush();
		}
		
		//--------------------------------------------------------------------------
		//  Socket Data Handling
		//--------------------------------------------------------------------------
		
		/**
		 * Process socket data and check for handshake or for text data
		 */
		private function processSocketData():void
		{
			var pos:int = _buffer.length;
			_dataSocket.readBytes(_buffer, pos);
			
			for (; pos < _buffer.length; ++pos)
			{
				// if headerState is smaller than four we determine the header information
				// by searching for \r\n and validate handshake after that
				if (_headerState < 4)
				{
					if(getWebsocketHeader(pos))
					{
						logger.info('OPEN');
						// remove buffer and reset position
						_buffer = WebsocketUtil.removeBufferBefore(pos + 1, _buffer);
						pos = -1;
						// set socket state to open
						_state = FlashWebsocketState.OPEN;
						// fire callback
						if(_openCallback != null) _openCallback(this);
					}
				}
				else
				{
					var frame:FlashWebsocketFrame = parseFrame();
					
					// if frame is not null
					if (frame)
					{
						// remove buffer and reset position
						_buffer = WebsocketUtil.removeBufferBefore(frame.length, _buffer);
						pos = -1;
						
						switch(frame.opcode)
						{
							// on text data
							case OPCODE_TEXT:
							{
								var text_data:String = readUTFBytes(frame.payload, 0, frame.payload.length);
								if(_verboseLogging) logger.debug('received text data: [' + text_data + ']');
								_messageCallback(this, text_data);
								break;
							}
							case OPCODE_PING:
							{
								if(_verboseLogging) logger.debug('Received ping');
								if(_pingPongBasedDisonnect)
								{
									_pingTimeoutTimer.reset();
									_pingTimeoutTimer.start();
								}
								
								_interruptTimer.reset();
								_interruptTimer.start();
								if(_interrupted) _interruptCallback(this, false);
								_interrupted = false;
								
								sendPong(frame.payload);
								break;
							}
							case OPCODE_PONG:
							{
								if(_verboseLogging) logger.debug('Received pong');
								if(_pingPongBasedDisonnect)
								{
									_pingTimeoutTimer.reset();
									_pingTimeoutTimer.start();	
								}
								
								_interruptTimer.reset();
								_interruptTimer.start();
								if(_interrupted) _interruptCallback(this, false);
								_interrupted = false;
								
								processPong(frame.payload);
								break;
							}
							case OPCODE_CLOSE:
							{
								logger.info('Recieved closing frame');
								break;
							}
							default:
							{
								logger.warn('Recieved unhandled opcode:', frame.opcode);
								break;
							}
						}
					}
				}
			}
		}
		
		//--------------------------------------------------------------------------
		//  Parse Websocket Header
		//--------------------------------------------------------------------------
		
		/**
		 * Get websocket header from buffer
		 */
		private function getWebsocketHeader(pos:int):Boolean
		{
			// if header state is zero or two and current buffer byte equals cartridge return
			// we increment the header state
			if((_headerState == 0 || _headerState == 2) && _buffer[pos] == ASCII_CR)
			{
				++_headerState;		
			}
				// if header state is one or three and current buffer byte equals new line
				// we increment the header state
			else if(_headerState == 1 || _headerState == 3 && _buffer[pos] == ASCII_NL)
			{
				++_headerState;
			}
			else
			{
				_headerState = 0;
			}
			
			// if header state is 4 (what means that we received the sequence "\r\n\r\n") we
			// can validate the header information and set the connection to connected if all test passed.
			if (_headerState == 4) {
				
				var headerStr:String = readUTFBytes(_buffer, 0, pos + 1);
				logger.debug("Response Header:\n" + headerStr);
				if (!validateHandshake(headerStr)) return false;
				return true;
			}
			else
			{
				return false;
			}
		}
		
		//--------------------------------------------------------------------------
		//  Handshake Validation
		//--------------------------------------------------------------------------
		
		/**
		 * Websocket handshake validation
		 */
		private function validateHandshake(headerStr:String):Boolean
		{
			logger.debug('Validating handshake...');
			
			// get lines
			var lines:Array = headerStr.split(/\r\n/);
			
			// check if first line is a valid handhsake
			if (!lines[0].match(/^HTTP\/1.1 101 /))
			{
				handleConnectionError('bad response: ' + lines[0]);
				return false;
			}
			
			// define objects to store handshake header
			var header:Object = {};
			var lowerHeader:Object = {};
			
			// iterate trough lines and store key value pairs in header objects
			for (var i:int = 1; i < lines.length; ++i)
			{
				// skip empty lines
				if (lines[i].length == 0) continue;
				// validate line
				var m:Array = lines[i].match(/^(\S+): (.*)$/);
				if (!m)
				{
					handleConnectionError("failed to parse response header line: " + lines[i]);
					return false;
				}
				// store header data to object
				header[m[1].toLowerCase()] = m[2];
				// store lower header data to object
				lowerHeader[m[1].toLowerCase()] = m[2].toLowerCase();
			}
			
			// verify upgrade
			if (lowerHeader['upgrade'] != 'websocket')
			{
				handleConnectionError('invalid Upgrade: ' + header['Upgrade']);
				return false;
			}
			
			// verify connection
			if (lowerHeader['connection'] != 'upgrade')
			{
				handleConnectionError("invalid Connection: " + header["Connection"]);
				return false;
			}
			
			// verify websocket accept
			if (!lowerHeader['sec-websocket-accept'])
			{
				handleConnectionError(
					'The WebSocket server speaks old WebSocket protocol, ' +
					'which is not supported by peregrineWS. ' +
					'It requires WebSocket protocol HyBi 10. ' +
					'Try newer version of the server if available.');
				return false;
			}
			
			// verify reply digest
			var replyDigest:String = header["sec-websocket-accept"];
			if (replyDigest != _expectedDigest)
			{
				handleConnectionError("digest doesn't match: " + replyDigest + " != " + _expectedDigest);
				return false;
			}
			
			logger.debug('Handshake validated.');
			return true;
		}
		
		//--------------------------------------------------------------------------
		//  Frame Parsing
		//--------------------------------------------------------------------------
		
		/**
		 * Parses and returns websocket frame from buffer
		 */
		private function parseFrame():FlashWebsocketFrame
		{	
			var frame:FlashWebsocketFrame = new FlashWebsocketFrame();
			var hlength:uint = 0;
			var plength:uint = 0;
			
			hlength = 2;
			
			if (_buffer.length < hlength)
			{
				return null;
			}
			
			frame.fin = (_buffer[0] & 0x80) != 0;
			frame.rsv = (_buffer[0] & 0x70) >> 4;
			frame.opcode  = _buffer[0] & 0x0f;
			
			// Payload unmasking is not implemented because masking frames from server
			// is not allowed. This field is used only for error checking.
			frame.mask = (_buffer[1] & 0x80) != 0;
			plength = _buffer[1] & 0x7f;
			
			if (plength == 126)
			{	
				hlength = 4;
				if (_buffer.length < hlength)
				{
					return null;
				}
				_buffer.endian = Endian.BIG_ENDIAN;
				_buffer.position = 2;
				plength = _buffer.readUnsignedShort();
				
			}
			else if (plength == 127)
			{
				hlength = 10;
				if (_buffer.length < hlength)
				{
					return null;
				}
				_buffer.endian = Endian.BIG_ENDIAN;
				_buffer.position = 2;
				// Protocol allows 64-bit length, but we only handle 32-bit
				var big:uint = _buffer.readUnsignedInt(); // Skip high 32-bits
				plength = _buffer.readUnsignedInt(); // Low 32-bits
				if (big != 0) {
					logger.error("Frame length exceeds 4294967295. Bailing out!");
					return null;
				}
			}
			
			if (_buffer.length < hlength + plength)
			{
				return null;
			}
			
			frame.length = hlength + plength;
			frame.payload = new ByteArray();
			_buffer.position = hlength;
			_buffer.readBytes(frame.payload, 0, plength);
			return frame;
		}
		
		//--------------------------------------------------------------------------
		//  Send Data
		//--------------------------------------------------------------------------
		
		/**
		 * Send message (string) to server
		 */
		public function sendMessage(data:String):int
		{
			var dataBytes:ByteArray = new ByteArray();
			dataBytes.writeUTFBytes(data);
			
			if (_state == FlashWebsocketState.OPEN)
			{
				var frame:FlashWebsocketFrame = new FlashWebsocketFrame();
				frame.opcode = OPCODE_TEXT;
				frame.payload = dataBytes;
				if (sendFrame(frame))
				{
					return -1;
				}
				else
				{
					return dataBytes.length;
				}
			}
			else
			{
				logger.error('socket is not open! current state: ', _state);
			}
			return -1;
		}
		
		/**
		 * Send message (ByteArray) to server
		 */
		public function sendByteArrayMessage(dataBytes:ByteArray):int
		{
			if (_state == FlashWebsocketState.OPEN)
			{
				var frame:FlashWebsocketFrame = new FlashWebsocketFrame();
				frame.opcode = OPCODE_TEXT;
				frame.payload = dataBytes;
				if (sendFrame(frame))
				{
					return -1;
				}
				else
				{
					return dataBytes.length;
				}
			}
			else
			{
				logger.error('socket is not open! current state: ', _state);
			}
			return -1;
		}
		
		//--------------------------------------------------------------------------
		//  Send Frame
		//--------------------------------------------------------------------------
		
		/**
		 * Send given websocket frame to server
		 */
		private function sendFrame(frame:FlashWebsocketFrame):Boolean
		{
			// return if websocket is not open
			if(_state != FlashWebsocketState.OPEN)
			{
				return false;	
			}
			
			// determine payload length
			var plength:uint = frame.payload.length;
			
			// Generates a mask.
			var mask:ByteArray = new ByteArray();
			for (var i:int = 0; i < 4; i++)
			{
				mask.writeByte(randomInt(0, 255));
			}
			
			var header:ByteArray = new ByteArray();
			// FIN + RSV + opcode
			header.writeByte((frame.fin ? 0x80 : 0x00) | (frame.rsv << 4) | frame.opcode);
			if (plength <= 125) {
				header.writeByte(0x80 | plength);  // Masked + length
			} else if (plength > 125 && plength < 65536) {
				header.writeByte(0x80 | 126);  // Masked + 126
				header.writeShort(plength);
			} else if (plength >= 65536 && plength < 4294967296) {
				header.writeByte(0x80 | 127);  // Masked + 127
				header.writeUnsignedInt(0);  // zero high order bits
				header.writeUnsignedInt(plength);
			} else {
				logger.error("Send frame size too large");
			}
			header.writeBytes(mask);
			
			var maskedPayload:ByteArray = new ByteArray();
			maskedPayload.length = frame.payload.length;
			for (i = 0; i < frame.payload.length; i++) {
				maskedPayload[i] = mask[i % 4] ^ frame.payload[i];
			}
			
			try {
				_dataSocket.writeBytes(header);
				_dataSocket.writeBytes(maskedPayload);
				_dataSocket.flush();
			} catch (ex:Error) {
				logger.error("Error while sending frame: " + ex.message);
				return false;
			}
			return true;
		}
		
		//--------------------------------------------------------------------------
		//  PING PONG
		//--------------------------------------------------------------------------
		
		/**
		 * Send ping frame to server
		 */
		private function sendPing(payload:ByteArray):Boolean
		{
			var frame:FlashWebsocketFrame = new FlashWebsocketFrame();
			frame.opcode = OPCODE_PING;
			frame.payload = payload;
			return sendFrame(frame);
		}
		
		/**
		 * Send pong frame to server
		 */
		private function sendPong(payload:ByteArray):Boolean
		{
			var frame:FlashWebsocketFrame = new FlashWebsocketFrame();
			frame.opcode = OPCODE_PONG;
			frame.payload = payload;
			return sendFrame(frame);
		}
		
		/**
		 * Send ping frame with timestamp payload to server
		 */
		private function sendPingWithTS():void
		{
			var date:Date = new Date();
			var time:Number = date.time;
			var payload:ByteArray = new ByteArray();
			payload.writeDouble(time);
			sendPing(payload);
		}
		
		/**
		 * Proceed pong frame from server
		 */
		private function processPong(payload:ByteArray):void
		{
		}
		
		//--------------------------------------------------------------------------
		//  Connection Error
		//--------------------------------------------------------------------------
		
		private function handleConnectionError(message:String):void
		{
			logger.error('Connection error:', message);
			_failedCallback(this, -1, message);
			// close connection
			closeConnection();
		}
		
		//--------------------------------------------------------------------------
		//  Helper
		//--------------------------------------------------------------------------
		
		/**
		 * Extract and save connection data from url
		 */
		private function extractURL(url:String):void
		{
			var m:Array = url.match(/^(\w+):\/\/([^\/:|\?]+)(:(\d+))?(\/.*)?(\?.*)?$/);
			
			if(m)
			{
				this._scheme = m[1];
				this._host = m[2];
				var defaultPort:int = this._scheme == "wss" ? 443 : 80;
				this._port = parseInt(m[4]) || defaultPort;
				this._path = (m[5] || "/") + (m[6] || "");				
			}
			else
			{
				logger.error("SYNTAX ERROR: invalid url: " + url);				
			}
		}
		
		/**
		 * Generate key for socket connection
		 */
		private function generateKey():String {
			var vals:ByteArray = new ByteArray();
			vals.length = 16;
			for (var i:int = 0; i < vals.length; ++i) {
				vals[i] = randomInt(0, 127);
			}
			return Base64.encode(vals);
		}
		
		/**
		 * Generate random number between the min and max parameter
		 */
		private function randomInt(min:uint, max:uint):uint {
			return min + Math.floor(Math.random() * (Number(max) - min + 1));
		}
		
		/**
		 * Read UTF bytes from buffer
		 */
		private function readUTFBytes(buffer:ByteArray, start:int, numBytes:int):String {
			buffer.position = start;
			var data:String = "";
			for(var i:int = start; i < start + numBytes; ++i) {
				// Workaround of a bug of ByteArray#readUTFBytes() that bytes after "\x00" is discarded.
				if (buffer[i] == 0x00) {
					data += buffer.readUTFBytes(i - buffer.position) + "\x00";
					buffer.position = i + 1;
				}
			}
			data += buffer.readUTFBytes(start + numBytes - buffer.position);
			return data;
		}
		
		//--------------------------------------------------------------------------
		//  System
		//--------------------------------------------------------------------------
		
		/**
		 * Register socket event listeners
		 */
		private function registerSocketEventListeners(target:IEventDispatcher):Boolean
		{
			if(target != null)
			{
				target.addEventListener(IOErrorEvent.IO_ERROR, _dataSocket_ERROR, false, 0, true);
				target.addEventListener(SecurityErrorEvent.SECURITY_ERROR, _dataSocket_SECURITY_ERROR, false, 0, true);
				target.addEventListener(Event.CLOSE, _dataSocket_CLOSE, false, 0, true);
				target.addEventListener(Event.CONNECT, _dataSocket_CONNECT, false, 0, true);
				target.addEventListener(OutputProgressEvent.OUTPUT_PROGRESS, _dataSocket_OUTPUT_PROGRESS, false, 0, true);
				target.addEventListener(ProgressEvent.SOCKET_DATA, _dataSocket_SOCKET_DATA, false, 0, true);
				return true;
			}
			else
			{
				logger.error('Unable to register socket event listeners! data socket is NULL');
			}
			
			return false;
		}
		
		/**
		 * Unregister socket event listeners
		 */
		private function unregisterSocketEventListeners(target:IEventDispatcher):void
		{
			if(target)
			{
				target.removeEventListener(IOErrorEvent.IO_ERROR, _dataSocket_ERROR);
				target.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, _dataSocket_SECURITY_ERROR);		
				target.removeEventListener(Event.CONNECT, _dataSocket_CONNECT);
				target.removeEventListener(ProgressEvent.SOCKET_DATA, _dataSocket_SOCKET_DATA);
				target.removeEventListener(OutputProgressEvent.OUTPUT_PROGRESS, _dataSocket_OUTPUT_PROGRESS);
				target.removeEventListener(Event.CLOSE, _dataSocket_CLOSE);	
			}
			else
			{
				logger.error('unable to unregister socket event listeners! data socket is NULL');
			}
		}
	}
}