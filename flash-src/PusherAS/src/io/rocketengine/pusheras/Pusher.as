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

package io.rocketengine.pusheras
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import io.rocketengine.loggeras.logger.LAS;
	import io.rocketengine.loggeras.logger.interfaces.ILASLogger;
	import io.rocketengine.pusheras.channel.PusherChannel;
	import io.rocketengine.pusheras.events.PusherChannelEvent;
	import io.rocketengine.pusheras.events.PusherConnectionStatusEvent;
	import io.rocketengine.pusheras.events.PusherEvent;
	import io.rocketengine.pusheras.utils.PusherConstants;
	import io.rocketengine.pusheras.vo.PusherOptions;
	import io.rocketengine.pusheras.vo.PusherStatus;
	import io.rocketengine.pusheras.vo.WebsocketStatus;
	import io.rocketengine.websocket.interfaces.IWSocket;
	import io.rocketengine.websocket.proxies.FlashWebsocketProxy;
	
	/**
	 * Pusher <http://pusher.com> ActionScript3 Client Library
	 * @author Tilman Griesel <https://github.com/TilmanGriesel>
	 */
	public class Pusher extends EventDispatcher
	{
		private static const logger:ILASLogger = LAS.getLogger(Pusher);
		
		private static const VERSION:String = '0.1.6';
		
		private var _verboseLogging:Boolean = false;
		
		// pusheras vars
		private var _pusherOptions:PusherOptions;
		private var _pusherStatus:PusherStatus;
		
		// websocket vars
		private var _websocket:FlashWebsocketProxy;
		private var _websocketStatus:WebsocketStatus;
		
		// channel bucket
		protected var _channelBucket:Vector.<PusherChannel>;
		
		/**
		 * @param options all required options for the pusher connection
		 * */
		public function Pusher(options:PusherOptions)
		{
			logger.info('construct');
			
			// parameter check
			if(options == null)
				throw new Error('Options cannot be null');
			
			// store options
			_pusherOptions = options;
			
			// create small storage object for the websocket and pusher status
			_websocketStatus = new WebsocketStatus();
			_pusherStatus = new PusherStatus();
			
			// create channel bucket
			_channelBucket = new Vector.<PusherChannel>;
			this.addEventListener(PusherEvent.CONNECTION_ESTABLISHED, this_CONNECTION_ESTABLISHED);
		}

		public function connect():void
		{
			logger.info('Connecting...');
			// connect to websocket server
			connectWebsocket();
		}
		
		/**
		 * inital websocket connection
		 * */
		private function connectWebsocket():void
		{
			// check for websocket status storage object
			if(_websocketStatus == null)
				throw new Error('websocket status cannot be null');

			// check for pusher status storage object
			if(_pusherStatus == null)
				throw new Error('pusher status cannot be null');
			
			// check if connection attempt is already in progress
			if(_websocketStatus.connecting)
			{
				logger.warn('Already attempting a connection. Aborting...');
				return;
			}
			
			// check if websocket is already connected
			if(_websocketStatus.connected)
			{
				logger.warn('Connection is already established. Aborting connection attempt...');
				return;
			}
			
			logger.info('Environment check successfully completed.');
			
			// update status
			_pusherStatus.connecting = true;
			_websocketStatus.connecting = true;
			
			// get pusher url
			var pusherURL:String;
			if(_pusherOptions.secure)
			{
				pusherURL = _pusherOptions.pusherSecureURL;
			}
			else
			{
				pusherURL = _pusherOptions.pusherURL;
			}
			
			// Initialize websocket
			_websocket = new FlashWebsocketProxy();
			_websocket.verboseLogging = _verboseLogging;
			_websocket.init(_pusherOptions.autoPing, _pusherOptions.pingPongBasedDisconnect, _pusherOptions.pingInterval, _pusherOptions.pingPongTimeout, _pusherOptions.interruptTimeout);
			_websocket.registerCallbacks(onWSInit, onWSOpen, onWSMessage, onWSClose, onFail, onWSInterrupt);
			_websocket.connect(pusherURL);
		}
		
		private function onWSInit(sender:IWSocket = null):void
		{
			logger.info("Websocket initialized");
		}
		
		private function onWSOpen(sender:IWSocket = null):void
		{	
			logger.info("Websocket open");
			// store status
			_websocketStatus.connected = true;
		}
		
		private function onWSMessage(sender:IWSocket = null, msg:String = ''):void
		{
			if(_verboseLogging) logger.debug('receiving << [', msg, ']');
			
			// try to parse new pusher event from websocket message
			try
			{
				var pusherEvent:PusherEvent = PusherEvent.parse(unescape(msg));				
			}
			catch(e:Error)
			{
				logger.error('Websocket message parsing error: ' + e.message + ' | message: ' + unescape(msg));
				return;
			}
			
			// look in the channel bucket if channel subscribed and dispatch event on it
			if(pusherEvent.channel != null)
			{
				for(var i:int = 0; i < _channelBucket.length; i++)
				{
					var channel:PusherChannel = _channelBucket[i] as PusherChannel;
					if(channel.name == pusherEvent.channel)
					{
						channel.dispatchEvent(pusherEvent);
					}
				}
			}
			else
			{
				// redispatch pusher event
				this.dispatchEvent(pusherEvent);
			}		
		}
		
		private function onWSClose(sender:IWSocket = null, code:int = -1, msg:String = ''):void
		{
			logger.warn('Websocket closed', code, msg);
			
			_websocketStatus.connected = false;
			_websocketStatus.connecting = false;
			_websocketStatus.socketID = null;
			
			var evt:PusherConnectionStatusEvent = new PusherConnectionStatusEvent(PusherConnectionStatusEvent.WS_DISCONNECTED);
			evt.data.code = code;
			evt.data.msg = msg;
			this.dispatchEvent(evt);
		}
		
		private function onFail(sender:IWSocket = null, code:int = -1, msg:String = ''):void
		{
			logger.error('Websocket failed', code, msg);
			
			_websocketStatus.connected = false;
			_websocketStatus.connecting = false;
			_websocketStatus.socketID = null;
			
			var evt:PusherConnectionStatusEvent = new PusherConnectionStatusEvent(PusherConnectionStatusEvent.WS_FAILED);
			evt.data.code = code;
			evt.data.msg = msg;
			this.dispatchEvent(evt);
		}
		
		private function onWSInterrupt(sender:IWSocket = null, value:Boolean = false):void
		{
			if(value) logger.warn('Websocket interrupted!');
			else logger.info('Websocket ok!');
			
			var evt:PusherConnectionStatusEvent = new PusherConnectionStatusEvent(PusherConnectionStatusEvent.WS_INTERRUPTED);
			evt.data.interrupted = value;
			this.dispatchEvent(evt);
		}
		
		protected function this_CONNECTION_ESTABLISHED(event:PusherEvent):void
		{
			logger.info('Websocket connection established. socket id: ' + event.data.socket_id);
			
			this.dispatchEvent(new PusherConnectionStatusEvent(PusherConnectionStatusEvent.WS_ESTABLISHED));
			
			_pusherStatus.connected = true;
			if(event.data.hasOwnProperty('socket_id'))
			{
				_websocketStatus.socketID = event.data.socket_id;
			}
		}
		
		/**
		 * Subscribes a pusher channel with the given name.
		 * add native event listeners to it
		 * @param channelName The name of your channel
		 * @return a channel instance for event listening and dispatching
		 */	
		public function subscribe(channelName:String):PusherChannel
		{
			// check the pusher connection
			if(_pusherStatus.connected == false)
				throw new Error('cannot subscribe "' + channelName + '" because the pusher service is not connected!');
			
			// pusher channel implentation
			var pusherChannel:PusherChannel;
			
			// define channel type
			if(channelName.indexOf(PusherConstants.CHANNEL_NAME_PRIVATE_PREFIX) != -1)
			{
				logger.info('subscribing private channel "' + channelName + '"...'); 
				pusherChannel = new PusherChannel(PusherChannel.PRIVATE, channelName, dispatchPusherEvent, true, _websocketStatus.socketID, _pusherOptions.auth_endpoint);
			}
			else
			{
				logger.info('subscribing public channel "' + channelName + '"...'); 
				pusherChannel = new PusherChannel(PusherChannel.PUBLIC, channelName, dispatchPusherEvent);
			}
			
			// add internal channel event listeners
			pusherChannel.addEventListener(PusherChannelEvent.SETUP_COMPLETE, pusherChannel_SETUP_COMPLETE);
			
			// initialize channel (perform auth request etc.)
			pusherChannel.init();
			return pusherChannel;
		}
		
		/**
		 * subscribe channel after setup complete event
		 * */
		protected function pusherChannel_SETUP_COMPLETE(event:Event):void
		{
			// get channel
			var pusherChannel:PusherChannel = event.target as PusherChannel;
			
			// create new channel object
			_channelBucket.push(pusherChannel);
			
			// create new pusher event
			var pusherEvent:PusherEvent = new PusherEvent(PusherEvent.SUBSCRIBE);
			pusherEvent.data.channel = pusherChannel.name;
			pusherEvent.data.auth = _pusherOptions.applicationKey + ':' + pusherChannel.authenticationSignature;
			
			// dispatch event to pusher service
			dispatchPusherEvent(pusherEvent);
		}
		
		/**
		 * Remove and unsubscribe channel
		 * */
		public function unsubscribe(channelName:String):void
		{
			// create new pusher event
			var pusherEvent:PusherEvent = new PusherEvent(PusherEvent.UNSUBSCRIBE);
			pusherEvent.data.channel = channelName;
			
			// search for channel in bucket
			for(var i:int = 0; i < _channelBucket.length; i++)
			{
				var channel:PusherChannel = _channelBucket[i] as PusherChannel;
				if(channel.name == pusherEvent.channel)
				{
					// remove channel from bucket
					_channelBucket.splice(i, 1);
				}
			}
		}
		
		/**
		 * dispatch event to pusher service
		 * **/
		public function dispatchPusherEvent(event:PusherEvent):void
		{
			// check websocket connection
			if(_websocketStatus.connected == false)
			{
				logger.error('Websocket is not connected... Cannot dispatch event!');
			}
			
			if(_verboseLogging) logger.info('sending >> [', event.toJSON(), ']');
			_websocket.send(event.toJSON());
		}
		
		public function get pusherStatus():PusherStatus
		{
			return _pusherStatus;
		}

		public function get verboseLogging():Boolean
		{
			return _verboseLogging;
		}

		public function set verboseLogging(value:Boolean):void
		{
			_verboseLogging = value;
		}

	}
}
