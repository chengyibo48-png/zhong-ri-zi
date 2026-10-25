extends RefCounted
const TIMBRES = {
 "water":[580.0,920.0,"sine"],"hoe":[190.0,110.0,"triangle"],
 "build":[240.0,130.0,"triangle"],"chop":[210.0,90.0,"triangle"],
 "harvest":[620.0,830.0,"sine"],"gather":[620.0,830.0,"sine"],
 "seed":[430.0,660.0,"sine"],"feed":[330.0,460.0,"triangle"],
 "door":[240.0,310.0,"triangle"],"read":[380.0,420.0,"sine"],
 "trade":[730.0,910.0,"sine"],"greet":[440.0,520.0,"sine"]
}
const SCALES = [
 [261.63,293.66,329.63,392.0,440.0],[293.66,329.63,392.0,440.0,523.25],
 [220.0,261.63,293.66,329.63,392.0],[196.0,220.0,261.63,293.66,329.63]
]
static func sound(kind: String, settings: Dictionary) -> Dictionary:
 if not bool(settings.get("sound",true)):return {"activate":false,"voices":[]}
 if float(settings.get("effects",0.6)) <= 0.0 or float(settings.get("volume",0.2)) <= 0.0:return {"activate":true,"voices":[]}
 var timbre: Array = TIMBRES.get(kind,[])
 var start: float = float(timbre[0]) if not timbre.is_empty() else 783.99 if kind=="music" else 660.0 if kind=="good" else 392.0 if kind=="soft" else 510.0
 var end: float = float(timbre[1]) if not timbre.is_empty() else 880.0 if kind=="good" else 350.0
 var wave: String = str(timbre[2]) if not timbre.is_empty() else "triangle" if kind=="music" else "sine"
 return {"activate":true,"voices":[{"wave":wave,"start":0.0,"end":0.32,"frequency":[start,end,0.12],"gain":[0.0,float(settings.get("volume",0.2))*float(settings.get("effects",0.6))*0.22,0.02,0.0001,0.3]}]}

static func ambient(seconds: float, next: float, active: bool, hidden: bool, panel: bool, settings: Dictionary, season: int, wet: bool, night: bool, town: bool, indoors: bool) -> Dictionary:
 var result := {"next":next,"music":[],"ambient":[]}
 if not active or not bool(settings.get("sound",true)) or hidden or panel or seconds<next:return result
 result.next = seconds+8.0
 var volume := float(settings.get("volume",0.2))
 var music := float(settings.get("music",0.35))
 var ambience := float(settings.get("ambient",0.3))
 if music>0.0 and volume>0.0:
  for j in range(3):
   var frequency := float(SCALES[clampi(season,0,3)][(int(floor(seconds/8.0))+j*2)%5])
   result.music.append({"wave":"triangle","start":j*0.65,"end":j*0.65+1.6,"frequency":[frequency,frequency,0.0],"gain":[0.0001,maxf(0.0002,volume*music*0.09),0.04,0.0001,1.5]})
 if ambience>0.0:
  result.ambient.append({"wave":"noise","start":0.0,"end":2.0,"filter":650.0 if wet else 300.0,"noise":0.2,"q":1.0,"gain":[0.0001,volume*ambience*(0.32 if wet else 0.15)*(0.24 if indoors else 1.0),0.4,0.0001,2.0]})
  if not wet:
   result.ambient.append({"wave":"sine","start":0.3,"end":0.82,"frequency":[650.0 if night else 250.0 if town else 1150.0,720.0 if night else 320.0 if town else 1450.0,0.2],"gain":[0.0001,volume*ambience*0.035,0.35,0.0001,0.8],"gain_origin":0.0})
 return result

static func envelope(voice: Dictionary, seconds: float) -> float:
 var gains: Array = voice.gain
 var t := seconds-float(voice.get("gain_origin",voice.start))
 if t<=0.0:return float(gains[0])
 if t<float(gains[2]):return lerpf(float(gains[0]),float(gains[1]),t/float(gains[2]))
 if t>=float(gains[4]):return float(gains[3])
 if float(gains[1])<=0.0:return 0.0
 var fraction := (t-float(gains[2]))/(float(gains[4])-float(gains[2]))
 return float(gains[1])*pow(float(gains[3])/float(gains[1]),fraction)

static func phase(voice: Dictionary, seconds: float) -> float:
 var t := maxf(0.0,seconds-float(voice.start))
 var frequency: Array = voice.frequency
 var start := float(frequency[0])
 var end := float(frequency[1])
 var duration := float(frequency[2])
 if duration<=0.0 or start==end:return TAU*start*t
 var ratio := log(end/start)
 var elapsed := minf(t,duration)
 return TAU*(start*duration/ratio*(exp(ratio*elapsed/duration)-1.0)+end*maxf(0.0,t-duration))
