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

package io.rocketengine.pusheras.events
{
	import flash.events.Event;

	/**
	 * Pusher <http://pusher.com> PusherConnectionStatusEvent
	 * @author Tilman Griesel <https://github.com/TilmanGriesel>
	 */
	public class PusherConnectionStatusEvent extends Event
	{
		// constants
		static public const WS_ESTABLISHED:String = "PusherConnectionStatusEvent.WS_ESTABLISHED";
		static public const WS_DISCONNECTED:String = "PusherConnectionStatusEvent.WS_DISCONNECTED";
		static public const WS_FAILED:String = "PusherConnectionStatusEvent.WS_FAILED";
		static public const WS_INTERRUPTED:String = "PusherConnectionStatusEvent.WS_INTERRUPTED";
		
		// vars
		private var _event:String;
		private var _data:Object;
		
		public function PusherConnectionStatusEvent(type:String, bubbles:Boolean = false, cancelable:Boolean = false):void 
		{
			super(type, bubbles, cancelable);
			
			_event = type;
			_data = new Object();
		}
		
		override public function clone():Event 
		{ 
			return new PusherConnectionStatusEvent(this.type, this.bubbles, this.cancelable);
		} 
		
		public function get event():String
		{
			return this._event;
		}
		
		public function set event(value:String):void
		{
			this._event = value;
		}
		
		public function get data():Object
		{
			return this._data;
		}
		
		public function set data(value:Object):void
		{
			this._data = value;
		}
	}
}