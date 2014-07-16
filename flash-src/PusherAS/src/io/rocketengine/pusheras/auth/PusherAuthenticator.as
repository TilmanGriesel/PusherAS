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

package io.rocketengine.pusheras.auth
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.HTTPStatusEvent;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	
	import io.rocketengine.loggeras.logger.LAS;
	import io.rocketengine.loggeras.logger.interfaces.ILASLogger;
	import io.rocketengine.pusheras.events.PusherAuthenticationEvent;

	public class PusherAuthenticator extends EventDispatcher
	{
		private static const logger:ILASLogger = LAS.getLogger(PusherAuthenticator);
		
		public function PusherAuthenticator()
		{
		}
		
		public function authenticate(socketID:String, endPoint:String, channelName:String):void
		{
			logger.info('authenticate socket connection (socketID:' + socketID + ',endpoint:' + endPoint + ',channelName:' + channelName + ')...');
			
			var urlLoader:URLLoader = new URLLoader();
			var urlRequest:URLRequest = new URLRequest(endPoint);
			var postVars:URLVariables = new URLVariables();
			postVars.socket_id = socketID;
			postVars.channel_name = channelName;
			
			urlRequest.data = postVars;	
			urlRequest.method = URLRequestMethod.POST;
			
			configureListeners(urlLoader);
			
			try {
				urlLoader.load(urlRequest);
			} catch (error:Error) {
				logger.error('unable to load authentication request! (' + error.message + ')');
			}
		}
		
		private function configureListeners(dispatcher:IEventDispatcher):void {
			dispatcher.addEventListener(Event.COMPLETE, urlLoader_COMPLETE);
			dispatcher.addEventListener(Event.OPEN, urlLoader_OPEN);
			dispatcher.addEventListener(ProgressEvent.PROGRESS, urlLoader_PROGRESS);
			dispatcher.addEventListener(SecurityErrorEvent.SECURITY_ERROR, urlLoader_SECURITY_ERROR);
			dispatcher.addEventListener(HTTPStatusEvent.HTTP_STATUS, urlLoader_HTTP_STATUS);
			dispatcher.addEventListener(IOErrorEvent.IO_ERROR, urlLoader_IO_ERROR);
		}
		
		private function urlLoader_COMPLETE(event:Event):void {
			var loader:URLLoader = URLLoader(event.target);
			
			if(loader.hasOwnProperty('data') == true)
			{
				var decodedData:Object = JSON.parse(loader.data);
				
				if(decodedData.hasOwnProperty('auth'))
				{
					var authString:String = decodedData.auth;
					logger.info('authentication successful (auth: ' + authString + ')');
					this.dispatchEvent(new PusherAuthenticationEvent(PusherAuthenticationEvent.SUCCESSFUL, authString));	
				}
				else
				{
					logger.warn('authentication failed! Property "auth" not found in response data!');
					this.dispatchEvent(new PusherAuthenticationEvent(PusherAuthenticationEvent.FAILED));
				}
			}
			else
			{
				logger.warn('authentication failed! Property "data" not found in response data!');
				this.dispatchEvent(new PusherAuthenticationEvent(PusherAuthenticationEvent.FAILED));	
			}
				
			loader.close();
		}
		
		private function urlLoader_OPEN(event:Event):void {
			// empty
		}
		
		private function urlLoader_HTTP_STATUS(event:HTTPStatusEvent):void {
			// empty
		}
		
		private function urlLoader_PROGRESS(event:ProgressEvent):void {
			// empty
		}
		
		private function urlLoader_SECURITY_ERROR(event:SecurityErrorEvent):void {
			logger.warn('security error! (' + event + ')');
			
			this.dispatchEvent(new PusherAuthenticationEvent(PusherAuthenticationEvent.FAILED));
			
			// close connection
			var loader:URLLoader = URLLoader(event.target);
			loader.close();
		}
		
		private function urlLoader_IO_ERROR(event:IOErrorEvent):void {
			logger.warn('io error! (' + event + ')');
			
			this.dispatchEvent(new PusherAuthenticationEvent(PusherAuthenticationEvent.FAILED));
			
			// close connection
			var loader:URLLoader = URLLoader(event.target);
			loader.close();
		}
	}
}