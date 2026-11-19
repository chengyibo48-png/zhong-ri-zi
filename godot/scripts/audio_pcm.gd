extends RefCounted
## Pure PCM synthesis. Desktop workers and the web time-slice use identical math.
const RATE:int=44100
const RULES=preload("res://scripts/source_audio_rules.gd")
var voices:Array=[]
var rng:=RandomNumberGenerator.new()
var mixed:PackedFloat64Array
var bytes:PackedByteArray
var frames:int=0
var voice_index:int=0
var cursor:int=0
var last:int=0
var packed:int=0
var prepared:bool=false
var encoding:bool=false
var noise:bool=false
var a1:float=0;var a2:float=0;var b0:float=0;var b1:float=0;var b2:float=0
var x1:float=0;var x2:float=0;var y1:float=0;var y2:float=0
func _init(source:Array=[],seed_value:int=1)->void:
	voices=source.duplicate(true);rng.seed=seed_value
	var duration:float=0
	for voice:Dictionary in voices:duration=maxf(duration,float(voice.end))
	frames=roundi(duration*RATE);mixed.resize(frames);bytes.resize(frames*2)
func step(budget_us:int=2000)->bool:
	var deadline:int=Time.get_ticks_usec()+budget_us
	while voice_index<voices.size():
		var voice:Dictionary=voices[voice_index]
		if not prepared:
			cursor=roundi(float(voice.start)*RATE);last=mini(frames,roundi(float(voice.end)*RATE));noise=str(voice.wave)=="noise";prepared=true
			x1=0;x2=0;y1=0;y2=0
			if noise:
				var omega:float=TAU*float(voice.filter)/RATE;var cosine:float=cos(omega);var alpha:float=sin(omega)/(2.0*pow(10.0,float(voice.get("q",1.0))/20.0));var a0:float=1+alpha
				a1=-2*cosine/a0;a2=(1-alpha)/a0;b0=(1-cosine)/2/a0;b1=(1-cosine)/a0;b2=b0
		while cursor<last:
			var seconds:float=float(cursor)/RATE;var tone:float=0
			if noise:
				var x:float=rng.randf_range(-1,1)*float(voice.noise);tone=b0*x+b1*x1+b2*x2-a1*y1-a2*y2;x2=x1;x1=x;y2=y1;y1=tone
			else:
				tone=sin(RULES.phase(voice,seconds))
				if str(voice.wave)=="triangle":tone=asin(tone)*2/PI
			mixed[cursor]+=tone*RULES.envelope(voice,seconds);cursor+=1
			if cursor%128==0 and Time.get_ticks_usec()>=deadline:return false
		voice_index+=1;prepared=false
	while packed<frames:
		var pcm:int=clampi(roundi(clampf(mixed[packed],-1,1)*32767),-32767,32767)
		bytes[packed*2]=pcm&255;bytes[packed*2+1]=(pcm>>8)&255;packed+=1
		if packed%256==0 and Time.get_ticks_usec()>=deadline:return false
	return true
