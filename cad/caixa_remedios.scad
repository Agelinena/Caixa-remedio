// =====================================================================
//  CAIXA DE REMEDIOS INTELIGENTE - 7 dias, fileira unica  (v2, so encaixes)
//  ESP32 + reed switch por tampa + LED por dia. Sem parafusos.
//  Tudo em mm. OpenSCAD 2021.01.
//
//  part =
//    "body"       corpo, ja virado para imprimir (de cabeca para baixo)
//    "base"       tampa de baixo (encaixe de pressao)
//    "lids"       as 7 tampas, topo na mesa, em 2 fileiras
//    "lid1"       so a primeira tampa (peca de teste)
//    "assembly"   tudo montado (visualizar)
//    "open"       montado com as tampas abertas
//    "a_body" "a_base" "a_lids"   pecas na posicao de montagem
//    "cut"        corte para ver o interior
//
//  Medidas marcadas ASSUMIDO nao foram medidas na peca real: confira.
// =====================================================================

part = "assembly";
ang  = 95;      // angulo usado nas vistas/conferencias de tampa aberta
$fn = 32;

// ---------- Compartimentos ----------
n    = 7;     // numero de dias
cw   = 20;    // largura interna
cd   = 30;    // profundidade interna
ch   = 20;    // altura interna
wall = 1.6;   // paredes laterais e entre compartimentos
fw   = 5.4;   // parede frontal (abriga o reed em pe)
bw   = 1.6;   // parede traseira

// ---------- Bay da eletronica ----------
bay_h    = 27;  // altura interna (cabe jumper Dupont nos pinos do ESP32)
ceil_t   = 2;   // piso dos compartimentos = teto da bay
bay_wall = 2;   // paredes laterais e traseira da bay
bay_fw   = 3;   // parede frontal da bay (LEDs)

// ---------- Reed e ima ----------
reed_y    = 2.9;   // centro do rasgo do reed na parede frontal
reed_sx   = 3.9;   // rasgo: vidro (2,2) + fio de volta ao lado
reed_sy   = 2.7;
reed_cap  = 0.6;   // pele que fecha o rasgo por cima
mag_d     = 5;     // ima disco
mag_t     = 1;
mag_stack = 1;     // 2 = dois imas empilhados
mag_tol   = 0.15;

// ---------- LED ----------
led_d      = 5;     // ASSUMIDO (3 ou 5 mm)
led_flange = 5.9;   // 5mm -> 5.9 | 3mm -> 3.8
led_z      = 12;
led_bezel  = 3.5;   // "viseira" na frente; 0 desliga

// ---------- Tampa e dobradica ----------
lid_gap = 0.15;
lid_t   = 3;
tab     = 5;      // aba para o dedo
hr      = 3;      // raio da dobradica
ear_w   = 2.4;    // orelhas do corpo
pin_d   = 1.75;   // pino = filamento
dias = ["DOM","SEG","TER","QUA","QUI","SEX","SAB"];

// ---------- Base ----------
plate_t = 2;
lip_h   = 3.5;
lip_gap = 0.25;
snap_z  = 2.2;    // altura do ressalto de encaixe
snap_b  = 0.5;    // ressalto da base
snap_g  = 0.6;    // canaleta no corpo

// ---------- Placas (ASSUMIDO: medir e ajustar) ----------
esp_l = 51.5; esp_w = 28.3; esp_t = 1.6; esp_so = 5;   // ESP32 DevKit 30 pinos
rtc_l = 38;   rtc_w = 22;   rtc_t = 1.6; rtc_so = 6;   // DS3231 modelo ZS-042
aux_l = 24;   aux_w = 28;   aux_t = 1.6; aux_so = 4;   // placa perfurada do 74HC595
usb_w = 13;   usb_h = 7.5;                              // furo do plugue USB-C

// ---------- Botao (tatil 6x6, altura total 5: ASSUMIDO) e buzzer 12 mm ----------
btn_h  = 5;
btn_y  = 9.5;
btn_z  = 8;
pad_w  = 9;  pad_z0 = 4.5; pad_len = 16.5; pad_t = 1.0;
buz_d  = 12; buz_y = 26;

// ---------- Derivados ----------
full    = n >= 7;                 // false nas pecas de teste: sem eletronica
pitch   = cw + wall;
L       = n*cw + (n+1)*wall;
Wd      = fw + cd + bw;
z_cell0 = bay_h + ceil_t;
H       = z_cell0 + ch;
z_lid0  = H + lid_gap;
y_h     = Wd + hr + 0.5;          // eixo da dobradica
z_h     = H - hr;                 // orelhas ficam rentes ao topo
lw      = pitch - 0.4;
kw      = pitch - ear_w - 0.6;
zg      = H - 2.6;                // canaleta da trava da tampa
buz_z   = bay_h - buz_d/2 - 1.4;
esp_x0  = bay_wall + 2.1;
esp_y0  = Wd - bay_wall - 0.3 - esp_w;
rtc_x0  = esp_x0 + esp_l + 0.3 + 3.9;
rtc_y0  = Wd - bay_wall - 0.3 - rtc_w;
aux_x0  = rtc_x0 + rtc_l + 0.3 + 15.5;
aux_y0  = Wd - bay_wall - 0.3 - aux_w;
usb_yc  = esp_y0 + esp_w/2;
usb_zc  = bay_h - esp_so + 1.6;

function xc(i) = wall + i*pitch + cw/2;

module rrect(l,w,h,r=2){
  linear_extrude(h) offset(r) translate([r,r]) square([l-2*r,w-2*r]);
}
// perfil (y,z) extrudado ao longo de x
module prof_x(x0,len,pts){
  translate([x0,0,0]) rotate([90,0,90]) linear_extrude(len) polygon(pts);
}

// ================= BERCO DE PLACA (encaixe, pendurado no teto da bay) =================
// placa ocupa x 0..len, y 0..wid. Garras fixas em x=0, gancho flexivel em x=len.
module cradle0(len,wid,thick,so,clw){
  c0 = so + thick + 0.2;                    // profundidade da face de baixo da placa
  // apoios nos 4 cantos
  for(x=[0,len-4]) for(y=[0,wid-4]) translate([x,y,bay_h-so]) cube([4,4,so]);
  // guias laterais
  for(x=[0,len-4]) for(y=[-1.3,wid+0.3]) translate([x,y,bay_h-so-thick]) cube([4,1,so+thick]);
  // garras fixas
  for(y=[0.3,wid-0.3-clw]){
    translate([-1.9,y,bay_h-c0-2]) cube([1.6,clw,c0+2]);
    hull(){
      translate([-0.31,y,bay_h-c0-2]) cube([0.01,clw,2]);
      translate([0.7,y,bay_h-c0-0.9]) cube([0.01,clw,0.4]);
    }
  }
  // gancho flexivel
  translate([len+0.3,wid/2-3,bay_h-c0-2.2]) cube([1.2,6,c0+2.2]);
  hull(){
    translate([len+0.3,wid/2-3,bay_h-c0-2]) cube([0.01,6,2]);
    translate([len-0.5,wid/2-3,bay_h-c0-0.9]) cube([0.01,6,0.4]);
  }
}
module cradle(x0,y0,len,wid,thick,so,clw=3,flip=false){
  translate([x0+(flip?len:0),y0,0]) mirror([flip?1:0,0,0]) cradle0(len,wid,thick,so,clw);
}

// ================= CORPO =================
module ear(i){
  w  = (i==0||i==n) ? 2.0 : ear_w;
  x0 = (i==0) ? 0 : (i==n) ? L-w : i*pitch + wall/2 - w/2;
  hull(){
    translate([x0,y_h,z_h]) rotate([0,90,0]) cylinder(r=hr,h=w);
    translate([x0,Wd-0.01,z_h-hr-0.7]) cube([w,hr+2,0.2]);
  }
}

module body_solid(){
  rrect(L,Wd,H);
  // prateleira da dobradica: base das orelhas e batente da tampa aberta
  prof_x(0,L,[[Wd-0.01,z_h-hr-0.5],[Wd+2*hr+1,z_h-hr-0.5],[Wd+2*hr+1,z_h-hr-3],[Wd-0.01,z_h-hr-10]]);
  for(i=[0:n]) ear(i);
  // viseira dos LEDs
  if(led_bezel>0) for(i=[0:n-1]) hull(){
    translate([xc(i),-led_bezel,led_z]) rotate([-90,0,0]) cylinder(d=led_d+3.6,h=led_bezel);
    translate([xc(i)-(led_d+3.6)/2,-0.01,led_z]) cube([led_d+3.6,0.01,(led_d+3.6)/2+led_bezel]);
  }
  // marca do botao por fora
  if(full) translate([L-0.01,btn_y,btn_z]) rotate([0,90,0]) cylinder(d=4,h=0.4);
}

module body_cuts(){
  // bay (aberta embaixo)
  translate([bay_wall,bay_fw,-0.01]) cube([L-2*bay_wall,Wd-bay_fw-bay_wall,bay_h+0.01]);
  // compartimentos
  for(i=[0:n-1]) translate([wall+i*pitch,fw,z_cell0]) cube([cw,cd,ch+0.01]);
  for(i=[0:n-1]){
    x = xc(i);
    // rasgo vertical do reed (fechado em cima) + saida para a bay
    translate([x-reed_sx/2,reed_y-reed_sy/2,bay_h-0.01]) cube([reed_sx,reed_sy,H-reed_cap-bay_h]);
    translate([x-reed_sx/2,reed_y-reed_sy/2,bay_h-5]) cube([reed_sx,bay_fw-reed_y+reed_sy/2+0.1,5.01]);
    // LED
    translate([x,-led_bezel-0.01,led_z]) rotate([-90,0,0]) cylinder(d=led_d+0.2,h=bay_fw+led_bezel+0.02);
    translate([x,bay_fw-1,led_z]) rotate([-90,0,0]) cylinder(d=led_flange+0.4,h=1.01);
  }
  // canaleta da trava das tampas + chanfro de entrada
  prof_x(-0.01,L+0.02,[[-0.01,zg-0.8],[snap_g,zg],[-0.01,zg+0.8]]);
  prof_x(-0.01,L+0.02,[[-0.01,H+0.01],[0.5,H+0.01],[-0.01,H-0.5]]);
  // canaletas do encaixe da base
  prof_x(bay_wall,L-2*bay_wall,[[bay_fw+0.01,snap_z-0.9],[bay_fw-snap_g,snap_z],[bay_fw+0.01,snap_z+0.9]]);
  prof_x(bay_wall,L-2*bay_wall,[[Wd-bay_wall-0.01,snap_z-0.9],[Wd-bay_wall+snap_g,snap_z],[Wd-bay_wall-0.01,snap_z+0.9]]);
  // furo do pino (cego na ultima orelha)
  translate([-1,y_h,z_h]) rotate([0,90,0]) cylinder(d=pin_d+0.35,h=L,$fn=24);
  if(full){
    // USB-C
    translate([-0.01,usb_yc-usb_w/2,usb_zc-usb_h/2]) cube([bay_wall+0.02,usb_w,usb_h]);
    // lingueta do botao: afina por dentro + rasgo em U
    translate([L-bay_wall-0.01,btn_y-pad_w/2-0.6,pad_z0-0.6]) cube([bay_wall-pad_t+0.01,pad_w+1.2,pad_len+0.6]);
    for(y=[btn_y-pad_w/2-0.6,btn_y+pad_w/2]) translate([L-bay_wall-0.02,y,pad_z0-0.6]) cube([bay_wall+0.5,0.6,pad_len+0.6]);
    translate([L-bay_wall-0.02,btn_y-pad_w/2-0.6,pad_z0-0.6]) cube([bay_wall+0.5,pad_w+1.2,0.6]);
    // saida de som do buzzer
    for(p=[[0,0],[3,0],[-3,0],[0,3],[0,-3]]) translate([L-bay_wall-0.01,buz_y+p[0],buz_z+p[1]]) rotate([0,90,0]) cylinder(d=2,h=bay_wall+0.02,$fn=16);
  }
}

module body_inside(){
  // bercos
  cradle(esp_x0,esp_y0,esp_l+0.3,esp_w,esp_t,esp_so);
  cradle(rtc_x0,rtc_y0,rtc_l+0.3,rtc_w,rtc_t,rtc_so,clw=2.5,flip=true);
  cradle(aux_x0,aux_y0,aux_l+0.3,aux_w,aux_t,aux_so);
  // botao: ponto de toque na lingueta
  translate([L-pad_t-0.6,btn_y,btn_z]) rotate([0,90,0]) cylinder(d=3,h=0.61);
  // botao: bolso para a chave tatil 6x6 (entra por baixo; a base trava)
  xw = L - bay_wall - 0.3;
  xb = L - pad_t - 0.7 - btn_h;            // fundo da chave
  translate([xb-1.6,btn_y-4.6,btn_z+3.15]) cube([xw-xb+1.6,9.2,bay_h-btn_z-3.15]);
  for(s=[-1,1]) translate([xb+1.5,btn_y+(s>0?3.05:-4.6),pad_z0]) cube([xw-xb-1.5,1.55,btn_z+3.15-pad_z0+0.01]);
  translate([xb-1.6,btn_y-2.2,pad_z0]) cube([1.5,4.4,btn_z+3.15-pad_z0+0.01]);
  // clipe do buzzer
  translate([L-bay_wall-0.4-6,0,0]) difference(){
    hull(){
      translate([0,buz_y,buz_z]) rotate([0,90,0]) cylinder(d=buz_d+2.7,h=6);
      translate([0,buz_y-buz_d/2-1.35,buz_z]) cube([6,buz_d+2.7,bay_h-buz_z]);
    }
    translate([-1,buz_y,buz_z]) rotate([0,90,0]) cylinder(d=buz_d+0.3,h=8,$fn=48);
    translate([-1,buz_y-(buz_d-1)/2,buz_z-buz_d]) cube([8,buz_d-1,buz_d]);
  }
}

module body(){
  difference(){ body_solid(); body_cuts(); }
  if(full) body_inside();
}

// ================= TAMPA (posicao de montagem, x relativo ao centro do compartimento) =================
module lid(i=0){
  xl = (i==0)   ? -(xc(0)-0.2)       : -lw/2;
  xr = (i==n-1) ? L-0.2-xc(n-1)      :  lw/2;
  difference(){
    union(){
      translate([xl,-tab,z_lid0]) cube([xr-xl,tab+y_h+hr,lid_t]);
      // aba frontal com ressalto de trava
      translate([xl,-1.9,zg-1.2]) cube([xr-xl,1.6,z_lid0-zg+1.21]);
      prof_x(xl+1.5,xr-xl-3,[[-0.31,zg-0.7],[-0.3+snap_b,zg],[-0.31,zg+0.7]]);
      // articulacao
      hull(){
        translate([-kw/2,y_h,z_h]) rotate([0,90,0]) cylinder(r=hr,h=kw);
        translate([-kw/2,y_h-hr,z_lid0]) cube([kw,2*hr,0.1]);
      }
    }
    translate([-kw/2-1,y_h,z_h]) rotate([0,90,0]) cylinder(d=pin_d+0.65,h=kw+2,$fn=24);
    // bolsao do ima (por baixo, bem em cima da ponta do reed)
    translate([0,reed_y,z_lid0-0.01]) cylinder(d=mag_d+mag_tol,h=mag_t*mag_stack+0.2);
    // dia da semana em baixo-relevo
    translate([0,Wd/2,z_lid0+lid_t-0.4]) linear_extrude(0.5)
      text(dias[i%7],size=5,halign="center",valign="center",font="Liberation Sans:style=Bold");
  }
}
module lid_open(i,a){
  translate([0,y_h,z_h]) rotate([-a,0,0]) translate([0,-y_h,-z_h]) lid(i);
}

// ================= BASE (tampa de baixo, encaixe de pressao) =================
module base(){
  bx = L<60 ? [0.5] : [0.25,0.5,0.75];
  bl = L<60 ? L*0.4 : 14;
  x0 = bay_wall+lip_gap; x1 = L-bay_wall-lip_gap;
  y0 = bay_fw+lip_gap;   y1 = Wd-bay_wall-lip_gap;
  difference(){
    union(){
      rrect(L,Wd,plate_t);
      difference(){
        translate([x0,y0,plate_t-0.01]) cube([x1-x0,y1-y0,lip_h+0.01]);
        translate([x0+1.6,y0+1.6,plate_t-0.02]) cube([x1-x0-3.2,y1-y0-3.2,lip_h+0.1]);
      }
      for(f=bx){
        prof_x(f*L-bl/2,bl,[[y0+0.01,plate_t+snap_z-0.8],[y0-snap_b,plate_t+snap_z],[y0+0.01,plate_t+snap_z+0.8]]);
        prof_x(f*L-bl/2,bl,[[y1-0.01,plate_t+snap_z-0.8],[y1+snap_b,plate_t+snap_z],[y1-0.01,plate_t+snap_z+0.8]]);
      }
      // pilar que trava a chave tatil por baixo
      if(full) translate([L-pad_t-0.7-btn_h,btn_y-2.5,plate_t-0.01]) cube([3.5,5,btn_z-3.25]);
    }
    // rebaixo para abrir com moeda/unha
    translate([-0.01,Wd/2-7,plate_t-0.9]) cube([1.6,14,0.91]);
  }
}

// ================= IMPRESSAO =================
module body_print(){ translate([0,Wd,H]) rotate([180,0,0]) body(); }
module lid_print(i){ translate([0,y_h+hr,z_lid0+lid_t]) rotate([180,0,0]) lid(i); }
module lids_print(){
  for(i=[0:n-1]) translate([(i<4?i:i-4)*(lw+3)+xc(0),(i<4?0:tab+y_h+hr+4),0]) lid_print(i);
}

// ================= SELECAO =================
if(part=="body") body_print();
else if(part=="base") base();
else if(part=="lids") lids_print();
else if(part=="lid1") translate([xc(0),0,0]) lid_print(0);
else if(part=="a_body") body();
else if(part=="a_base") translate([0,0,-plate_t]) base();
else if(part=="a_lids") for(i=[0:n-1]) translate([xc(i),0,0]) lid(i);
else if(part=="a_lids_open") for(i=[0:n-1]) translate([xc(i),0,0]) lid_open(i,ang);
else if(part=="open"){ body(); translate([0,0,-plate_t]) base(); for(i=[0:n-1]) translate([xc(i),0,0]) lid_open(i,i%2==0?ang:0); }
else if(part=="cut") difference(){
  union(){ body(); translate([0,0,-plate_t]) base(); for(i=[0:n-1]) translate([xc(i),0,0]) lid(i); }
  translate([-1,-10,-5]) cube([xc(0)+1,80,80]);
}
// conferencias de colisao (devem dar vazio)
else if(part=="chk_lids") intersection(){ body(); for(i=[0:n-1]) translate([xc(i),0,0]) lid(i); }
else if(part=="chk_open") intersection(){ body(); for(i=[0:n-1]) translate([xc(i),0,0]) lid_open(i,ang); }
else if(part=="chk_base") intersection(){ body(); translate([0,0,-plate_t-0.02]) base(); }
else { body(); translate([0,0,-plate_t]) base(); for(i=[0:n-1]) translate([xc(i),0,0]) lid(i); }
