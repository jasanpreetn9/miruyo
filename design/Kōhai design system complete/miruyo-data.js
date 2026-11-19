(function(){
function hexLum(h){h=h.replace('#','');const v=[0,2,4].map(i=>{let c=parseInt(h.substr(i,2),16)/255;return c<=0.03928?c/12.92:Math.pow((c+0.055)/1.055,2.4)});return .2126*v[0]+.7152*v[1]+.0722*v[2];}
function dress(t){
  const c=t.color, lum=hexLum(c);
  // accent = cover colour normalised so it always reads on #090B11
  t.accent = lum<0.12 ? `color-mix(in oklch, ${c} 45%, #ffffff)` : (lum>0.6 ? `color-mix(in oklch, ${c} 80%, #000)` : c);
  t.cover = `linear-gradient(160deg, color-mix(in oklch, ${c} 72%, #fff) 0%, ${c} 42%, color-mix(in oklch, ${c} 45%, #05060a) 100%)`;
  t.glow = `0 18px 40px -14px color-mix(in oklch, ${t.accent} 70%, transparent)`;
  t.tint = `color-mix(in oklch, ${t.accent} 16%, transparent)`;
  t.isAnime = t.type==='ANIME';
  t.unit = t.isAnime?'EP':'CH';
  t.total = t.isAnime?t.eps:t.ch;
  t.countLabel = t.isAnime ? (t.eps? t.eps+' eps':'? eps') : (t.ch? t.ch+' ch':'Ongoing');
  t.badgeBg = t.isAnime?'rgba(255,106,85,.16)':'rgba(160,140,255,.18)';
  t.badgeFg = t.isAnime?'#FF8A78':'#B9A9FF';
  if(t.me){const tot=t.total||Math.max(t.me.p+12,24);t.me.pct=Math.round(t.me.p/tot*100)+'%';t.me.of=t.total?String(t.total):'?';}
  t.short = t.title.length>34 ? t.title.slice(0,32)+'…' : t.title;
  return t;
}
const anime=[
 {id:1,title:'Sousou no Frieren',en:"Frieren: Beyond Journey's End",type:'ANIME',format:'TV',eps:28,score:9.1,color:'#d9a75e',genres:['Adventure','Drama','Fantasy'],studio:'Madhouse',season:'Fall 2026',status:'Releasing',next:{ep:9,in:'2d 4h',day:'Fri',time:'23:00'},me:{s:'Watching',p:7}},
 {id:2,title:'Kusuriya no Hitorigoto',en:'The Apothecary Diaries',type:'ANIME',format:'TV',eps:24,score:8.8,color:'#4fae8a',genres:['Drama','Mystery'],studio:'OLM',season:'Fall 2026',status:'Releasing',next:{ep:14,in:'19h 12m',day:'Thu',time:'00:30'},me:{s:'Watching',p:12}},
 {id:3,title:'Dandadan',en:'Dan Da Dan',type:'ANIME',format:'TV',eps:12,score:8.4,color:'#e5487a',genres:['Action','Comedy','Supernatural'],studio:'Science SARU',season:'Fall 2026',status:'Releasing',next:{ep:3,in:'5d 1h',day:'Mon',time:'17:30'}},
 {id:4,title:'Otonari no Tenshi-sama ni Itsunomanika Dame Ningen ni Sareteita Ken 2',en:'The Angel Next Door Spoils Me Rotten 2',type:'ANIME',format:'TV',eps:12,score:7.6,color:'#f0b4cf',genres:['Romance','Slice of Life'],studio:'Project No.9',season:'Fall 2026',status:'Releasing',next:{ep:2,in:'3d 22h',day:'Sat',time:'22:00'},me:{s:'Planning',p:0}},
 {id:5,title:'Kaijuu 8-gou',en:'Kaiju No. 8',type:'ANIME',format:'TV',eps:11,score:8.0,color:'#3a8fd6',genres:['Action','Sci-Fi'],studio:'Production I.G',season:'Fall 2026',status:'Releasing',next:{ep:5,in:'1d 8h',day:'Wed',time:'23:00'},me:{s:'Paused',p:3}},
 {id:6,title:'Monogatari Series: Off & Monster Season',en:'',type:'ANIME',format:'ONA',eps:14,score:8.3,color:'#22232c',genres:['Mystery','Psychological','Supernatural'],studio:'Shaft',season:'Summer 2026',status:'Finished',me:{s:'Completed',p:14,sc:9}},
 {id:7,title:'Ore dake Level Up na Ken',en:'Solo Leveling',type:'ANIME',format:'TV',eps:13,score:8.2,color:'#6a6fe8',genres:['Action','Fantasy'],studio:'A-1 Pictures',season:'Fall 2026',status:'Releasing',next:{ep:6,in:'6d 2h',day:'Sun',time:'00:00'}},
 {id:8,title:'Chainsaw Man – Reze-hen',en:'Chainsaw Man – The Movie: Reze Arc',type:'ANIME',format:'Movie',eps:1,score:8.7,color:'#e86a2c',genres:['Action','Drama'],studio:'MAPPA',season:'Fall 2026',status:'Finished'},
 {id:9,title:'Ookami to Koushinryou: Merchant Meets the Wise Wolf',en:'Spice and Wolf',type:'ANIME',format:'TV',eps:25,score:7.9,color:'#c98a4b',genres:['Adventure','Romance'],studio:'Passione',season:'Fall 2026',status:'Releasing',next:{ep:17,in:'4h 05m',day:'Tue',time:'21:00'},me:{s:'Watching',p:15}},
 {id:10,title:'Blue Lock vs. U-20 Japan',en:'',type:'ANIME',format:'TV',eps:14,score:7.4,color:'#2a5cff',genres:['Sports'],studio:'8bit',season:'Winter 2027',status:'Not yet released',next:{ep:1,in:'92d',day:'Sat',time:'01:00'}},
 {id:11,title:'Boku no Kokoro no Yabai Yatsu',en:'The Dangers in My Heart',type:'ANIME',format:'TV',eps:13,score:8.5,color:'#f2c94c',genres:['Comedy','Romance'],studio:'Shin-Ei',season:'Winter 2027',status:'Not yet released'},
 {id:12,title:'Kimetsu no Yaiba: Mugen Jou-hen',en:'Demon Slayer: Infinity Castle',type:'ANIME',format:'Movie',eps:1,score:8.6,color:'#c43a3a',genres:['Action','Supernatural'],studio:'ufotable',season:'Spring 2027',status:'Not yet released',adult:false},
];
const manga=[
 {id:21,title:'Berserk',en:'',type:'MANGA',format:'Manga',ch:null,vol:null,score:9.3,color:'#6b5b4b',genres:['Action','Drama','Horror'],author:'Kentarou Miura',status:'Hiatus',me:{s:'Reading',p:364,v:41}},
 {id:22,title:'Vagabond',en:'',type:'MANGA',format:'Manga',ch:327,vol:37,score:9.1,color:'#d8d2c6',genres:['Action','Drama'],author:'Takehiko Inoue',status:'Hiatus',me:{s:'Completed',p:327,v:37,sc:10}},
 {id:23,title:'One Piece',en:'',type:'MANGA',format:'Manga',ch:null,score:9.0,color:'#e05a3a',genres:['Action','Adventure','Comedy'],author:'Eiichiro Oda',status:'Releasing',me:{s:'Reading',p:1121}},
 {id:24,title:'Kagurabachi',en:'',type:'MANGA',format:'Manga',ch:null,score:8.2,color:'#b9353f',genres:['Action','Supernatural'],author:'Takeru Hokazono',status:'Releasing',me:{s:'Reading',p:88}},
 {id:25,title:'Na Honjaman Level Up',en:'Solo Leveling',type:'MANGA',format:'Manga',country:'KR',ch:200,vol:14,score:8.5,color:'#4a6cff',genres:['Action','Fantasy'],author:'Chugong · DUBU',status:'Finished'},
 {id:26,title:'[Oshi no Ko]',en:'',type:'MANGA',format:'Manga',ch:166,vol:16,score:8.1,color:'#ff6fae',genres:['Drama','Mystery'],author:'Aka Akasaka · Mengo Yokoyari',status:'Finished',me:{s:'Dropped',p:120}},
 {id:27,title:'Chainsaw Man',en:'',type:'MANGA',format:'Manga',ch:null,score:8.6,color:'#f0c33c',genres:['Action','Horror'],author:'Tatsuki Fujimoto',status:'Releasing'},
 {id:28,title:'Sakamoto Days',en:'',type:'MANGA',format:'Manga',ch:null,score:8.3,color:'#2f9e8f',genres:['Action','Comedy'],author:'Yuto Suzuki',status:'Releasing'},
];
[...anime,...manga].forEach(dress);
const all=[...anime,...manga];
// Live AniList art: cover, banner, description. Cached locally; gradients stay as fallback.
const AKEY='miruyo.anilistArt.v1';
function clean(s){return (s||'').replace(/<br\s*\/?>/gi,' ').replace(/<[^>]+>/g,'').replace(/\(Source:[^)]*\)/gi,'').replace(/\s+/g,' ').trim();}
function applyArt(t,a){ if(!a) return; t.img=a.img; t.banner=a.banner; t.desc=a.desc;
  const g=t.coverGrad||(t.coverGrad=t.cover);
  if(a.img) t.cover=`url("${a.img}") center / cover no-repeat, ${g}`;
  t.bannerBg = a.banner ? `url("${a.banner}") center / cover no-repeat, ${g}` : null; }
let cache={}; try{cache=JSON.parse(localStorage.getItem(AKEY)||'{}');}catch(_){}
all.forEach(t=>applyArt(t,cache[t.id]));
const missing=all.filter(t=>!cache[t.id]);
if(missing.length && window.fetch){
  const q='query{'+missing.map(t=>`a${t.id}:Media(search:${JSON.stringify(t.title)},type:${t.type},sort:SEARCH_MATCH){coverImage{extraLarge}bannerImage description(asHtml:false)}`).join(' ')+'}';
  fetch('https://graphql.anilist.co',{method:'POST',headers:{'Content-Type':'application/json',Accept:'application/json'},body:JSON.stringify({query:q})})
    .then(r=>r.json()).then(j=>{ const d=(j&&j.data)||{}; missing.forEach(t=>{ const m=d['a'+t.id]; if(m){ cache[t.id]={img:m.coverImage&&m.coverImage.extraLarge,banner:m.bannerImage,desc:clean(m.description)}; applyArt(t,cache[t.id]); } });
      try{localStorage.setItem(AKEY,JSON.stringify(cache));}catch(_){}
      window.KD.artReady=true; window.dispatchEvent(new Event('kd-art')); }).catch(()=>{});
}
window.KD={anime,manga,all,byId:Object.fromEntries(all.map(t=>[t.id,t])),artReady:!missing.length};
window.dispatchEvent(new Event('kd-ready'));
})();
