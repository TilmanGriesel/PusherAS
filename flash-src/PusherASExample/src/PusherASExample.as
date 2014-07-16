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

package
{
	import flash.display.Sprite;
	import flash.events.Event;
	
	import components.ExampleComponent;
	
	import io.rocketengine.loggeras.logger.LAS;
	import io.rocketengine.loggeras.logger.interfaces.ILASLogger;
	import io.rocketengine.loggeras.logger.targets.LASTraceTarget;
	
	/**
	 * Pusher <http://pusher.com> Example Application
	 * @author Tilman Griesel <https://github.com/TilmanGriesel>
	 */
	[SWF(width=1280,height=480)]
	public class PusherASExample extends Sprite
	{	
		private static const logger:ILASLogger = LAS.getLogger(PusherASExample);
		
		private static const APP_KEY:String = 'f1063b8b6ddXXXXXXXXX';
		private static const AUTH_ENDPOINT:String = 'https://myserver/auth.php';
		private static const ORIGIN:String = 'http://localhost/';
		private static const SECURE:Boolean = true;
		
		public function PusherASExample()
		{
			LAS.addTarget(new LASTraceTarget());
			logger.info("Initialized ...");
			
			stage.stageWidth = 1280;
			stage.stageHeight = 480;
			
			this.addEventListener(Event.ADDED_TO_STAGE, this_ADDED_TO_STAGE);
		}
		
		protected function this_ADDED_TO_STAGE(event:Event):void
		{
			var comp1:ExampleComponent = new ExampleComponent(0x33333F);
			comp1.initPusherConnection(APP_KEY, AUTH_ENDPOINT, ORIGIN, SECURE);
			comp1.x = 0;
			this.addChild(comp1);
			
			var comp2:ExampleComponent = new ExampleComponent(0x33333C);
			comp2.initPusherConnection(APP_KEY, AUTH_ENDPOINT, ORIGIN, SECURE);
			comp2.x = 640;
			this.addChild(comp2);
		}
	}
}