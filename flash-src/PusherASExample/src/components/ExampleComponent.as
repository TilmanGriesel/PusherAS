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

package components
{
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.geom.Point;
	import flash.utils.Timer;
	
	import io.rocketengine.loggeras.logger.LAS;
	import io.rocketengine.loggeras.logger.interfaces.ILASLogger;
	import io.rocketengine.pusheras.Pusher;
	import io.rocketengine.pusheras.channel.PusherChannel;
	import io.rocketengine.pusheras.events.PusherConnectionStatusEvent;
	import io.rocketengine.pusheras.events.PusherEvent;
	import io.rocketengine.pusheras.vo.PusherOptions;
	
	import org.libspark.betweenas3.BetweenAS3;
	import org.libspark.betweenas3.easing.Expo;
	import org.libspark.betweenas3.tweens.ITween;
	
	/**
	 * Pusher <http://pusher.com> Example Component
	 * @author Tilman Griesel <https://github.com/TilmanGriesel>
	 */
	public class ExampleComponent extends Sprite
	{
		private static const logger:ILASLogger = LAS.getLogger(ExampleComponent);
		
		private var transmittionLockTimer:Timer = new Timer(100, 1);
		
		private var _pusher:Pusher;
		private var _mouseEventChannel:PusherChannel;
		private var _currentDragTarget:Sprite;
		private var _dragTarget_Offset:Point;
		private var _tween:ITween;
		private var _reconnectTimer:Timer;
		
		public function ExampleComponent(backgroundColor:uint)
		{	
			this.addEventListener(Event.ADDED_TO_STAGE, this_ADDED_TO_STAGE);
			this.visible = false;
		}
		
		public function initPusherConnection(appKey:String, authEndpoint:String, origin:String, secure:Boolean):void
		{
			logger.info("Connecting ...");
			
			// Setup new pusher options
			var pusherOptions:PusherOptions = new PusherOptions();
			pusherOptions.applicationKey = appKey;
			pusherOptions.auth_endpoint = authEndpoint;
			pusherOptions.origin = origin;
			pusherOptions.secure = secure;
			pusherOptions.autoPing = true;
			pusherOptions.pingPongBasedDisconnect = true;
			pusherOptions.pingInterval = 750;
			pusherOptions.pingPongTimeout = 15000;
			pusherOptions.interruptTimeout = 2500;
			
			// Create pusher client and connect to server
			_pusher = new Pusher(pusherOptions);
			_pusher.verboseLogging = false;
			// Pusher event handling
			_pusher.addEventListener(PusherEvent.CONNECTION_ESTABLISHED, pusher_CONNECTION_ESTABLISHED);
			// Pusher websocket event handling
			_pusher.addEventListener(PusherConnectionStatusEvent.WS_DISCONNECTED, pusher_WS_DISCONNECTED);
			_pusher.addEventListener(PusherConnectionStatusEvent.WS_FAILED, pusher_WS_FAILED);
			_pusher.addEventListener(PusherConnectionStatusEvent.WS_INTERRUPTED, pusher_WS_INTERRUPTED);
			
			// Connect websocket
			_pusher.connect();
			
			// Reconnect timer
			_reconnectTimer = new Timer(1000, 1);
			_reconnectTimer.addEventListener(TimerEvent.TIMER_COMPLETE, _reconnectTimer_TIMER_COMPLETE);
			_reconnectTimer.start();
		}
		
		protected function _reconnectTimer_TIMER_COMPLETE(event:TimerEvent):void
		{
			_pusher.connect();
		}
		
		protected function pusher_WS_DISCONNECTED(event:PusherConnectionStatusEvent):void
		{
			logger.error("Disconnected! " + JSON.stringify(event.data));
			
			// Draw redish background to
			// indicate the disconnect
			drawIndicatorColor(0x3F3333);
			
			// Reconnect pusher
			_reconnectTimer.reset();
			_reconnectTimer.start();
		}
		
		protected function pusher_WS_FAILED(event:PusherConnectionStatusEvent):void
		{
			logger.error("Connection Failed! " + JSON.stringify(event.data));
			
			// Draw black background to
			// indicate the failed connection
			drawIndicatorColor(0x000000);
			
			// Reconnect pusher
			_reconnectTimer.reset();
			_reconnectTimer.start();
		}
		
		protected function pusher_WS_INTERRUPTED(event:PusherConnectionStatusEvent):void
		{
			logger.warn("Connection interrupt! " + JSON.stringify(event.data));
			
			if(event.data.interrupted)
			{
				// Draw yellowish background to
				// indicate interruption
				drawIndicatorColor(0xafab37);
			}
			else
			{
				// Draw greenish background to indicate
				// that the interruption is over
				drawIndicatorColor(0x333f33);
			}
		}
		
		/**
		 * On successful connection subscribe a new channel and hear for events
		 * */
		protected function pusher_CONNECTION_ESTABLISHED(event:PusherEvent):void
		{
			logger.info("Connected!");
			
			// Stop the reconnect timer
			_reconnectTimer.stop();
			
			// Draw indicator background color
			drawIndicatorColor(0x333f33);
			
			// Subscribe to mouse event channel
			_mouseEventChannel = _pusher.subscribe('private-MouseEventChannel');
			_mouseEventChannel.addEventListener(MouseEvent.MOUSE_MOVE, mouseEventChannel_MOUSE_MOVE);
			this.visible = true;
		}
		
		protected function mouseEventChannel_MOUSE_MOVE(event:PusherEvent):void
		{
			if(_currentDragTarget == null)
				return;
			if(_tween != null) _tween.stop();
			_tween = BetweenAS3.to(_currentDragTarget, {x: event.data.x, y: event.data.y}, 1, Expo.easeOut);
			_tween.play();
		}
		
		protected function dragObejct_MOUSE_DOWN(event:MouseEvent):void
		{
			if(_tween != null) _tween.stop();
			_dragTarget_Offset = new Point(event.localX, event.localY);
			_currentDragTarget = event.currentTarget as Sprite;
			stage.addEventListener(MouseEvent.MOUSE_MOVE, stage_MOUSE_MOVE);
		}
		
		protected function stage_MOUSE_MOVE(event:MouseEvent):void
		{
			_currentDragTarget.x = this.mouseX;
			_currentDragTarget.y = this.mouseY;
			transmitPosition();
		}
		
		protected function dragObejct_MOUSE_UP(event:MouseEvent):void
		{
			stage.removeEventListener(MouseEvent.MOUSE_MOVE, stage_MOUSE_MOVE);
		}
		
		protected function this_ADDED_TO_STAGE(event:Event):void
		{
			createInterface();
		}
		
		private function createInterface():void
		{			
			var ball:Sprite = new Sprite();
			ball.graphics.beginFill(0xdc0000);
			ball.graphics.lineStyle(5, 0xdc0000, 0.3);
			ball.graphics.drawCircle(0, 0, 50);
			ball.graphics.endFill();
			ball.x = this.stage.stageWidth / 2 - ball.width / 2;
			ball.y = this.stage.stageHeight / 2 - ball.height / 2;
			ball.addEventListener(MouseEvent.MOUSE_DOWN, dragObejct_MOUSE_DOWN);
			ball.addEventListener(MouseEvent.MOUSE_UP, dragObejct_MOUSE_UP);
			this.addChild(ball);
			_currentDragTarget = ball;
		}
		
		private function drawIndicatorColor(color:uint):void
		{
			this.graphics.clear();
			this.graphics.beginFill(color);
			this.graphics.drawRect(0, 0, 640, 480);
			this.graphics.endFill();
		}
		
		protected function transmitPosition():void
		{
			if(_currentDragTarget == null)
				return;
			
			if(transmittionLockTimer.running)
				return;
			
			var pusherEvent:PusherEvent = new PusherEvent(MouseEvent.MOUSE_MOVE);
			pusherEvent.data.x = _currentDragTarget.x;
			pusherEvent.data.y = _currentDragTarget.y;
			
			if(_mouseEventChannel != null)
			{
				_mouseEventChannel.dispatchPusherEvent(pusherEvent);	
			}
			
			transmittionLockTimer.reset();
			transmittionLockTimer.start();
		}
	}
}