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

package io.rocketengine.pusheras.vo
{
	/**
	 * Pusher <http://pusher.com> Options Storage Object
	 * @author Tilman Griesel <https://github.com/TilmanGriesel>
	 */
	public final class PusherOptions
	{
		private var _version:String = '2.1';
		private var _protocol:String = '5';
		private var _applicationKey:String;
		private var _origin:String;
		private var _secure:Boolean = false;
		private var _host:String = 'ws.pusherapp.com';
		private var _ws_port:uint = 80;
		private var _wss_port:uint = 443;
		private var _auth_endpoint:String = '/pusher/auth';
		private var _autoPing:Boolean;
		private var _pingPongBasedDisconnect:Boolean;
		private var _pingInterval:Number = 750;
		private var _pingPongTimeout:Number = 7500;
		private var _interruptTimeout:Number = 1000;
		
		public function PusherOptions(applicationKey:String = null, origin:String = null):void 
		{ 
			this._applicationKey = applicationKey;
			this._origin = origin;
		}

		public function get version():String
		{
			return this._version;
		}
		
		public function get applicationKey():String
		{
			return this._applicationKey;
		}
		
		public function set applicationKey(value:String):void
		{
			this._applicationKey = value;
		}
		
		public function get origin():String
		{
			return this._origin;
		}
		
		public function set origin(value:String):void
		{
			this._origin = value;
		}
		
		public function get secure():Boolean
		{
			return this._secure;
		}
		
		public function set secure(value:Boolean):void
		{
			this._secure = value;
		}

		public function get host():String
		{
			return this._host;
		}
		
		public function set host(value:String):void
		{
			this._host = value;
		}
		
		public function get ws_port():uint
		{
			return this._ws_port;
		}
		
		public function set ws_port(value:uint):void
		{
			this._ws_port = value;
		}
		
		public function get wss_port():uint
		{
			return this._wss_port;
		}
		
		public function set wss_port(value:uint):void
		{
			this._wss_port = value;
		}
		
		public function get auth_endpoint():String
		{
			return this._auth_endpoint;
		}
		
		public function set auth_endpoint(value:String):void
		{
			this._auth_endpoint = value;
		}

		public function get autoPing():Boolean
		{
			return _autoPing;
		}
		
		public function set autoPing(value:Boolean):void
		{
			_autoPing = value;
		}
		
		public function get pingPongBasedDisconnect():Boolean
		{
			return _pingPongBasedDisconnect;
		}
		
		public function set pingPongBasedDisconnect(value:Boolean):void
		{
			_pingPongBasedDisconnect = value;
		}

		public function get pingInterval():Number
		{
			return _pingInterval;
		}
		
		public function set pingInterval(value:Number):void
		{
			_pingInterval = value;
		}
		
		public function get pingPongTimeout():Number
		{
			return _pingPongTimeout;
		}
		
		public function set pingPongTimeout(value:Number):void
		{
			_pingPongTimeout = value;
		}
		
		public function get interruptTimeout():Number
		{
			return _interruptTimeout;
		}
		
		public function set interruptTimeout(value:Number):void
		{
			_interruptTimeout = value;
		}
		
		// Convenience Getters
		
		public function get connectionPath():String
		{
			return	'/app/' + _applicationKey + "?client=js&version=" + _version + '&protocol=' + _protocol;
		}

		public function get pusherURL():String
		{
			return	'ws://' + _host + ":" + _ws_port + connectionPath;
		}
		
		public function get pusherSecureURL():String
		{
			return	'wss://' + _host + ":" + _wss_port + connectionPath;
		}
	}
}