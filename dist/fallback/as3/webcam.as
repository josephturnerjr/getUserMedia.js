/* JS-Webcam | 2013-FEB-09 | https://github.com/Digigizmo/JS-Webcam
* // Myles Jubb (@Digigizmo)
*
* Rewritten AS3 webcam forked from 
*   => https://github.com/sshilko/jQuery-AS3-Webcam
*
* ------------------------------------------------------------
*/

package {
	
	import flash.net.URLRequest;
	import flash.system.Security;
	import flash.system.SecurityPanel;
	import flash.external.ExternalInterface;
	import flash.display.Sprite;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.media.Sound;
	import flash.display.BitmapData;
	import flash.events.*;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.*;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.display.StageQuality;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import com.adobe.images.JPGEncoder;
	import Base64;
	
	public class webcam extends Sprite {
		
		private var settings:Object = {
			bandwidth    : 0,         // max bytes per second - zero prioritises quality
			quality      : 100,       // image & video quality [0-100]
			framerate    : 14,        // frames per second
			mirror       : false,     // flip video horizontally
			smoothing    : false,     // Boolean
			deblocking   : 0,         // Number
			wrapper      : 'webcam',  // JS wrapper name
			width 		 : 640,         // embedded object width
			height 		 : 480,         // embedded object height
			shutterSound : '',        // optional sound file to load
			mode         : "callback"
		}
		private static var interval = null;
		private static var stream = null;
	
		private var cam:Camera      = null; 
		private var cur:String      = '0';  // current cam id
		private var vid:Video       = null; // Displayed on stage
		private var camvid:Video       = null; // Camera resolution for capture
		private var img:BitmapData  = null;
		private var b64:String      = '';   // last saved image
		private var snd:Sound       = null;
		
		public function webcam():void {
			flash.system.Security.allowDomain("*");
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.quality   = StageQuality.BEST;
			stage.align     = StageAlign.TOP_LEFT; // centre
			settings        = merge(settings, this.loaderInfo.parameters);
			cam = Camera.getCamera();
			
			if(cam != null) {
				if(cam.muted){
                    Security.showSettings(SecurityPanel.PRIVACY);
                }else{
                    triggerEvent('swfReady');
                }
				if(ExternalInterface.available){
					loadCamera();
					ExternalInterface.addCallback('capture'      , capture	);
					ExternalInterface.addCallback('save'         , save         );
					ExternalInterface.addCallback('play'         , playCam      );
					ExternalInterface.addCallback('pause'        , pauseCam     );
					ExternalInterface.addCallback('setCamera'    , setCamera    );
					ExternalInterface.addCallback('getCameraList', getCameras);
					ExternalInterface.addCallback('getResolution', getResolution);
					ExternalInterface.addCallback('chooseCamera' , chooseCamera );
					ExternalInterface.addCallback('stream'	   , starttimer   );
					if(settings.shutterSound!='')
						snd = new Sound(new URLRequest(settings.shutterSound));
				} else {
					
				}
			} else { 
				error('CAMNOTFOUND');
			}
		} 
		
		private function loadCamera(name:String = '0'):void {
			cam = Camera.getCamera(name);
			cam.addEventListener(StatusEvent.STATUS, cameraStatusListener);
			cam.setMode(1280, 960, settings.framerate);
			cam.setQuality(settings.bandwidth, settings.quality);
			vid = new Video(stage.stageWidth, stage.stageHeight);
			ExternalInterface.call("console.log", vid.width, vid.height);
            
			vid.smoothing = settings.smoothing;
			vid.deblocking = settings.deblocking;
			vid.attachCamera(cam);
			if(!!settings.mirror){
				vid.scaleX = -1;
				vid.x = vid.width + vid.x;
			}
			stage.addChild(vid);
            // Hidden video for camera capture
			camvid = new Video(cam.width, cam.height);
			camvid.smoothing = settings.smoothing;
			camvid.deblocking = settings.deblocking;
			camvid.attachCamera(cam);
		}
		
		private function cameraStatusListener(evt:StatusEvent):void {
			if(!cam.muted)
                triggerEvent('swfReady');
			else
                error('CAMDISABLED');
		}
		
		private function triggerEvent(func:String, param:Object = null):Boolean {
			return ExternalInterface.call(settings.wrapper + "." + func, param);
		}
		
		private function error(flag:String = '0'):Boolean {
			return triggerEvent('onError', {'flag':flag});
		}
		
		/*private function clientReadyListener(event:TimerEvent):void {
			if(!!triggerEvent('isClientReady')){
				Timer(event.target).stop();
				ExternalInterface.addCallback('capture'      ,	capture	);
				ExternalInterface.addCallback('save'         , save         );
				ExternalInterface.addCallback('play'         , playCam      );
				ExternalInterface.addCallback('pause'        , pauseCam     );
				ExternalInterface.addCallback('setCamera'    , setCamera    );
				ExternalInterface.addCallback('getCameraList'   , getCameras   );
				ExternalInterface.addCallback('getResolution', getResolution);
				ExternalInterface.addCallback('chooseCamera' , chooseCamera );
				ExternalInterface.addCallback('stream'	   , starttimer   );
			}
		}*/
		public function starttimer():void {
			var asdf:Timer = new Timer(2000);
			asdf.addEventListener(TimerEvent.TIMER, wstream);
			asdf.start();
			
		}
		public function getResolution():Object {
			return { 
				camera : { width: cam.width           , height: cam.height            },
				window : { width: settings.width	  , height: settings.height 	  },
				stage  : { width: stage.stageWidth    , height: stage.stageHeight     }
			};
		}
		
		public function getCameras():Array {
			return Camera.names;
		}
		
		public function setCamera(id:String):Boolean {
			pauseCam();
			loadCamera(id.toString());
			if(!!cam) cur = id.toString();
			return !!cam;
		}
		
		public function chooseCamera():Boolean {
			Security.showSettings(SecurityPanel.CAMERA);
			return true;
		}
		
		public function playCam():Boolean {
			return setCamera(cur);
		}
		
		public function pauseCam():Boolean {
			vid.attachCamera(null);
			return true;
		}
		
		public function capture():Boolean {
			var resMode:String = 'window';
			var c:Object = getResolution()['camera'];
			
			if (null != cam) {
				if (null != img) {
					return false;
				}
				img = new BitmapData(c.width, c.height);
				if ("stream" == settings.mode) {
					wstream(null);
					return true;
				}
				_capture();
				return true;
			}
			return false;
		}
		
		private function _capture():void {
			if (null != interval) {
				clearInterval(interval);
			}
            img.draw(camvid);
		}
		public function save(file:String):Object{
			if ("stream" == settings.mode) {
				return true;
			} else if (null != img) {
				if ("callback" == settings.mode) {
					for (var i:Number = 0; i < img.height; ++i) {
						
						var pictrow:String = "";
						for(var j:Number = 0; j < img.width; j++)
						{
							pictrow += img.getPixel(j, i);
							pictrow += ";";
						}
						triggerEvent("onSave", pictrow);
					}
				} else if ("save" == settings.mode) {
                    var e:JPGEncoder = new JPGEncoder(settings.quality);
                    var data:ByteArray = e.encode(img);
                    img = null;
                    var string:String = 'data:image/jpeg;base64,' + Base64.encodeByteArray(data);
                    return string;
				} else {
					ExternalInterface.call('webcam.debug', "error", "Unsupported storage mode.");
				}
				
				img = null;
				return true;
			}
			return false;
			
			/*
			if(resMode!='stage' && resMode!='window') resMode = 'camera';
			var c:Object = getResolution()['camera'];
			var r:Object = getResolution()[resMode];
			var m:Matrix = new Matrix();
			var f:Number = !!settings.mirror ? -1 : 1;
			img = new BitmapData(r.width, r.height);
			if(c.width!=r.width || c.height!=r.height){
				var imgT:BitmapData = new BitmapData(c.width, c.height);
				m.scale(f * r.width / c.width, r.height / c.height);       
			} else {
				m.scale(f * 1, 1);
			}
			if(!!settings.mirror) 
				m.translate(r.width, 0);
			img.draw(vid, m);
			if(snd!=null) snd.play();
			pauseCam();
			var byteArray:ByteArray = new JPGEncoder(settings.quality).encode(img);
			var string:String = 'data:image/jpeg;base64,' + Base64.encodeByteArray(byteArray);
			return b64 = string;
			*/
		}
		
		public function wstream(mtx:Matrix):void{
			var pictrow:String = "";
			
			if (null != stream) {
				clearInterval(stream);
			}
			
			img.draw(vid, mtx);
			
			for(var i:Number = 0; i < img.height; i++)
			{
				for(var j:Number = 0; j < img.width; j++)
				{
					pictrow += img.getPixel(j, i);
					pictrow += ";";
				}
				triggerEvent('onSave', pictrow);
			}
			
			stream = setInterval(wstream, 10);
			/*for(var i = 0; i < img.height; i++)
			{
				color = img.getPixel(rowcount, i);
				picture += color + ";";
				if(i>img.width)
				{
					rowcount = i / img.width;
				}
			}*/
			/*
			for (var i = 0; i < r.height; ++i) {
				var row = "";
				for (var j=0; j < r.width; ++j) {
					row+= img.getPixel(j, i);
					row+= ";";
				}
				triggerEvent('onSave', row);
			}*/
		}
		
		public static function merge(base:Object, overwrite:Object):Object {
			for(var key:String in overwrite) 
				if(overwrite.hasOwnProperty(key)){
					// lazy data type fix
					if(!isNaN(overwrite[key])) base[key] = parseInt(overwrite[key]);
					else if(overwrite[key]==='true') base[key] = true;
					else if(overwrite[key]==='false') base[key] = false;
					else base[key] = overwrite[key];
				}
			return base;
		}
	}
}
