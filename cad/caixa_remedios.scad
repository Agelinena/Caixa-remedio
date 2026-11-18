// =====================================================================
//  CAIXA DE REMEDIOS INTELIGENTE - 7 dias, fileira unica  (v3)
//  ESP32 + reed switch por tampa + LED por dia. Sem parafusos e sem pino:
//  tudo encaixa.
//  Tudo em mm. OpenSCAD 2021.01.
//
//  O que mudou da v2 (depois da primeira impressao):
//   - dobradica de encaixe: eixo impresso na tampa + grampo em C no corpo
//     (nao precisa mais do pino de filamento)
//   - tampa com saia que entra justa no compartimento (sem folga lateral)
//     e trava frontal com rampa de entrada e degrau de retencao
//   - reed DEITADO (horizontal, ao longo de x) num canal no topo da parede
//     frontal, rente a borda da tampa; as pernas descem por canais abertos
//     na frente ate a bay. Ima na tampa, deslocado para uma ponta do vidro
//   - ESP32 encostado no USB-C: a ponta da placa entra num rasgo da propria
//     parede, trilhos laterais justos, batentes e gancho na outra ponta
//
//  part =
//    "body"       corpo, ja virado para imprimir (de cabeca para baixo)
//    "base"       tampa de baixo (encaixe de pressao)
//    "lids"       as 7 tampas, topo na mesa, em 2 fileiras
//    "lid1"       so a primeira tampa (peca de teste)
//    "assembly"   tudo montado (visualizar)
//    "open"       montado com tampas abertas
//    "components" caixa de cabeca para baixo, sem base, com os componentes
//    "comp_cut"   corte num compartimento: reed, ima, tampa, LED
//    "reed_front" frente de um compartimento: reed deitado e canais das pernas
//    "ghost"      caixa transparente com todos os componentes
//    "cut"        corte para ver o interior
//    "a_body" "a_base" "a_lids" "a_lids_open"   pecas na posicao de montagem
//    "chk_*"      conferencias de colisao (devem dar vazio)
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
fw   = 5.4;   // parede frontal (reed deitado no topo dela)
bw   = 1.6;   // parede traseira

// ---------- Bay da eletronica ----------
bay_h    = 27;  // altura interna (cabe jumper Dupont nos pinos do ESP32)
ceil_t   = 2;   // piso dos compartimentos = teto da bay
bay_wall = 2;   // paredes laterais e traseira da bay
bay_fw   = 3;   // parede frontal da bay (LEDs)

// ---------- Reed (deitado no topo da parede frontal) e ima ----------
reed_gd   = 2.2;   // diametro do vidro (anuncio)
reed_gl   = 14;    // comprimento do vidro (anuncio)
reed_y    = 2.9;   // centro do vidro na espessura da parede frontal
reed_cw   = 2.4;   // largura do canal do vidro
reed_sink = 0.1;   // topo do vidro abaixo do topo do corpo
reed_bend = 2.0;   // distancia do vidro ate a dobra da perna (nao dobrar rente ao vidro)
reed_lw   = 1.4;   // canal das pernas (aberto na frente)
mag_dx    = 4.5;   // ima deslocado do centro do vidro (centro = ponto morto). AJUSTAR NO TESTE
mag_d     = 5;     // ima disco
mag_t     = 1;
mag_stack = 1;     // 2 = dois imas empilhados
mag_tol   = 0.15;

// ---------- LED ----------
led_d      = 5;     // ASSUMIDO (3 ou 5 mm)
led_flange = 5.9;   // 5mm -> 5.9 | 3mm -> 3.8
led_z      = 12;
led_bezel  = 3.5;   // "viseira" na frente; 0 desliga

// ---------- Tampa ----------
lid_gap = 0.15;   // folga tampa x topo do corpo
lid_t   = 3;
tab     = 5;      // aba para o dedo
apr_t   = 1.4;    // aba frontal (flexiona na trava)
snap_b  = 0.55;   // ressalto da trava da tampa
snap_g  = 0.7;    // canaleta da trava no corpo
sk_h    = 2.4;    // saia que entra no compartimento
sk_t    = 1.2;
sk_gap  = 0.15;   // folga saia x parede (aperto lateral da tampa)
dias = ["DOM","SEG","TER","QUA","QUI","SEX","SAB"];

// ---------- Dobradica de encaixe ----------
hr      = 3;      // raio externo do grampo e dos bracos
rod_d   = 3.2;    // eixo impresso na tampa
rod_gap = 0.15;   // folga eixo x grampo (gira livre)
mouth   = 2.7;    // boca do grampo (menor que o eixo: clica)
clip_w  = 8;      // largura do grampo
arm_w   = 2.4;    // bracos da tampa
arm_gap = 0.3;

// ---------- Base ----------
plate_t = 2;
lip_h   = 3.5;
lip_gap = 0.25;
snap_z  = 2.2;    // altura do ressalto de encaixe
bsnap_b = 0.5;    // ressalto da base
bsnap_g = 0.6;    // canaleta no corpo

// ---------- Placas (ASSUMIDO: medir e ajustar) ----------
esp_l = 51.5; esp_w = 28.3; esp_t = 1.6; esp_so = 5;   // ESP32 DevKit V1 30 pinos
esp_in = 0.8;     // quanto a ponta do lado do USB entra no rasgo da parede
usbc_out = 1.0;   // quanto o conector USB-C passa da borda da placa (ASSUMIDO)
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
z_h     = H - hr;                 // grampo rente ao topo
lw      = pitch - 0.4;
zg      = H - 2.6;                // canaleta da trava da tampa
z_rc    = H - reed_sink - reed_gd/2;   // centro do vidro do reed
x_leg   = reed_gl/2 + reed_bend;       // posicao das pernas (relativa ao centro)
buz_z   = bay_h - buz_d/2 - 1.4;
esp_x0  = bay_wall - esp_in;
esp_y0  = Wd - bay_wall - 0.15 - esp_w;
esp_zt  = bay_h - esp_so;         // face de cima da placa (componentes para o teto)
rtc_x0  = esp_x0 + esp_l + 0.3 + 6;
rtc_y0  = Wd - bay_wall - 0.3 - rtc_w;
aux_x0  = rtc_x0 + rtc_l + 0.3 + 13;
aux_y0  = Wd - bay_wall - 0.3 - aux_w;
usb_yc  = esp_y0 + esp_w/2;
usb_zc  = esp_zt + 1.6;
arm_x   = clip_w/2 + arm_gap;     // inicio dos bracos da tampa (x relativo)

function xc(i) = wall + i*pitch + cw/2;

module rrect(l,w,h,r=2){
  linear_extrude(h) offset(r) translate([r,r]) square([l-2*r,w-2*r]);
}
// perfil (y,z) extrudado ao longo de x
module prof_x(x0,len,pts){
  translate([x0,0,0]) rotate([90,0,90]) linear_extrude(len) polygon(pts);
}
module xcyl(x0,y,z,r,len){ translate([x0,y,z]) rotate([0,90,0]) cylinder(r=r,h=len); }

// ================= BERCO DE PLACA (RTC e 595; pendurado no teto da bay) =================
module cradle0(len,wid,thick,so,clw){
  c0 = so + thick + 0.2;
  for(x=[0,len-4]) for(y=[0,wid-4]) translate([x,y,bay_h-so]) cube([4,4,so]);
  for(x=[0,len-4]) for(y=[-1.3,wid+0.3]) translate([x,y,bay_h-so-thick]) cube([4,1,so+thick]);
  for(y=[0.3,wid-0.3-clw]){
    translate([-1.9,y,bay_h-c0-2]) cube([1.6,clw,c0+2]);
    hull(){
      translate([-0.31,y,bay_h-c0-2]) cube([0.01,clw,2]);
      translate([0.7,y,bay_h-c0-0.9]) cube([0.01,clw,0.4]);
    }
  }
  translate([len+0.3,wid/2-3,bay_h-c0-2.2]) cube([1.2,6,c0+2.2]);
  hull(){
    translate([len+0.3,wid/2-3,bay_h-c0-2]) cube([0.01,6,2]);
    translate([len-0.5,wid/2-3,bay_h-c0-0.9]) cube([0.01,6,0.4]);
  }
}
module cradle(x0,y0,len,wid,thick,so,clw=3,flip=false){
  translate([x0+(flip?len:0),y0,0]) mirror([flip?1:0,0,0]) cradle0(len,wid,thick,so,clw);
}

// ================= BERCO DO ESP32 =================
// Ponta do USB no rasgo da parede esquerda; trilho na frente; parede traseira
// da bay faz o outro trilho; 2 batentes no teto e gancho flexivel na ponta da antena.
module esp_cradle(){
  zb = esp_zt - esp_t;                              // face de baixo da placa
  x1 = esp_x0 + esp_l;                              // ponta da antena
  // trilho da frente (comprimento todo)
  translate([bay_wall,esp_y0-0.15-1.2,zb-0.8]) cube([x1-bay_wall,1.2,bay_h-zb+0.8]);
  // reforco do trilho de tras (encosta na parede): so ate a altura da placa
  // batentes no teto, entre a fileira de pinos e o modulo (ASSUMIDO livre)
  for(y=[3.7,esp_w-3.7]) translate([x1-2.5,esp_y0+y,esp_zt]) cylinder(d=2,h=esp_so+0.01,$fn=16);
  // gancho flexivel na ponta da antena (prende pela face de baixo)
  c0 = esp_so + esp_t + 0.2;
  translate([x1+0.3,esp_y0+esp_w/2-3,bay_h-c0-2.2]) cube([1.2,6,c0+2.2]);
  hull(){
    translate([x1+0.3,esp_y0+esp_w/2-3,bay_h-c0-2]) cube([0.01,6,2]);
    translate([x1-0.6,esp_y0+esp_w/2-3,bay_h-c0-0.9]) cube([0.01,6,0.4]);
  }
}

// ================= CORPO =================
// grampo em C da dobradica, boca para tras; preso so por baixo (o arco de cima flexiona)
module clip(i){
  x0 = xc(i) - clip_w/2;
  difference(){
    union(){
      xcyl(x0,y_h,z_h,hr,clip_w);
      translate([x0,y_h-2.2,z_h-hr-0.6]) cube([clip_w,4.4,1.0]);       // pe sobre a prateleira
    }
    xcyl(x0-1,y_h,z_h,rod_d/2+rod_gap,clip_w+2);
    translate([x0-1,y_h,z_h-mouth/2]) cube([clip_w+2,hr+1,mouth]);
    // chanfro de entrada da boca
    prof_x(x0-1,clip_w+2,[[y_h+1.3,z_h-mouth/2],[y_h+hr+0.2,z_h-mouth/2-1.0],
                          [y_h+hr+0.2,z_h+mouth/2+1.0],[y_h+1.3,z_h+mouth/2]]);
  }
}

module body_solid(){
  rrect(L,Wd,H);
  // prateleira atras: base dos grampos e batente da tampa aberta
  prof_x(0,L,[[Wd-0.01,z_h-hr-0.5],[Wd+2*hr+1,z_h-hr-0.5],[Wd+2*hr+1,z_h-hr-3],[Wd-0.01,z_h-hr-10]]);
  for(i=[0:n-1]) clip(i);
  if(led_bezel>0) for(i=[0:n-1]) hull(){
    translate([xc(i),-led_bezel,led_z]) rotate([-90,0,0]) cylinder(d=led_d+3.6,h=led_bezel);
    translate([xc(i)-(led_d+3.6)/2,-0.01,led_z]) cube([led_d+3.6,0.01,(led_d+3.6)/2+led_bezel]);
  }
  if(full) translate([L-0.01,btn_y,btn_z]) rotate([0,90,0]) cylinder(d=4,h=0.4);
}

module reed_cut(i){
  x = xc(i);
  // canal do vidro, aberto em cima (a tampa cobre)
  translate([x-reed_gl/2-0.3,reed_y-reed_cw/2,z_rc-reed_gd/2-0.15]) cube([reed_gl+0.6,reed_cw,H-z_rc+reed_gd/2+0.2]);
  // canal raso das pernas ate a dobra
  for(s=[-1,1]) translate([s>0?x+reed_gl/2:x-x_leg-reed_lw/2,reed_y-0.6,z_rc-0.6]) cube([x_leg+reed_lw/2-reed_gl/2,1.2,H-z_rc+0.61]);
  // pernas descem por canais abertos na frente ate a bay
  for(s=[-1,1]) translate([x+s*x_leg-reed_lw/2,-0.01,bay_h-4]) cube([reed_lw,reed_y+0.6+0.01,H-bay_h+4.01]);
  for(s=[-1,1]) translate([x+s*x_leg-reed_lw/2,-0.01,bay_h-4]) cube([reed_lw,bay_fw+0.1,4.01]);
}

module body_cuts(){
  translate([bay_wall,bay_fw,-0.01]) cube([L-2*bay_wall,Wd-bay_fw-bay_wall,bay_h+0.01]);
  for(i=[0:n-1]) translate([wall+i*pitch,fw,z_cell0]) cube([cw,cd,ch+0.01]);
  for(i=[0:n-1]){
    reed_cut(i);
    x = xc(i);
    translate([x,-led_bezel-0.01,led_z]) rotate([-90,0,0]) cylinder(d=led_d+0.2,h=bay_fw+led_bezel+0.02);
    translate([x,bay_fw-1,led_z]) rotate([-90,0,0]) cylinder(d=led_flange+0.4,h=1.01);
  }
  // canaleta da trava das tampas: rampa longa embaixo, degrau curto em cima
  prof_x(-0.01,L+0.02,[[-0.01,zg-1.1],[snap_g,zg+0.15],[snap_g,zg+0.35],[-0.01,zg+0.7]]);
  prof_x(-0.01,L+0.02,[[-0.01,H+0.01],[0.5,H+0.01],[-0.01,H-0.5]]);
  // canaletas do encaixe da base
  prof_x(bay_wall,L-2*bay_wall,[[bay_fw+0.01,snap_z-0.9],[bay_fw-bsnap_g,snap_z],[bay_fw+0.01,snap_z+0.9]]);
  prof_x(bay_wall,L-2*bay_wall,[[Wd-bay_wall-0.01,snap_z-0.9],[Wd-bay_wall+bsnap_g,snap_z],[Wd-bay_wall-0.01,snap_z+0.9]]);
  if(full){
    // USB-C (cantos arredondados)
    translate([-0.01,usb_yc,usb_zc]) rotate([0,90,0]) linear_extrude(bay_wall+0.02)
      offset(1.5) square([usb_h-3,usb_w-3],center=true);
    // rasgo da parede onde entra a ponta do ESP32
    translate([esp_x0-0.2,esp_y0-0.15,esp_zt-esp_t-0.15]) cube([esp_in+0.2+0.01,esp_w+0.3,esp_t+0.3]);
    // lingueta do botao
    translate([L-bay_wall-0.01,btn_y-pad_w/2-0.6,pad_z0-0.6]) cube([bay_wall-pad_t+0.01,pad_w+1.2,pad_len+0.6]);
    for(y=[btn_y-pad_w/2-0.6,btn_y+pad_w/2]) translate([L-bay_wall-0.02,y,pad_z0-0.6]) cube([bay_wall+0.5,0.6,pad_len+0.6]);
    translate([L-bay_wall-0.02,btn_y-pad_w/2-0.6,pad_z0-0.6]) cube([bay_wall+0.5,pad_w+1.2,0.6]);
    for(p=[[0,0],[3,0],[-3,0],[0,3],[0,-3]]) translate([L-bay_wall-0.01,buz_y+p[0],buz_z+p[1]]) rotate([0,90,0]) cylinder(d=2,h=bay_wall+0.02,$fn=16);
  }
}

module body_inside(){
  esp_cradle();
  cradle(rtc_x0,rtc_y0,rtc_l+0.3,rtc_w,rtc_t,rtc_so,clw=2.5,flip=true);
  cradle(aux_x0,aux_y0,aux_l+0.3,aux_w,aux_t,aux_so);
  translate([L-pad_t-0.6,btn_y,btn_z]) rotate([0,90,0]) cylinder(d=3,h=0.61);
  xw = L - bay_wall - 0.3;
  xb = L - pad_t - 0.7 - btn_h;
  translate([xb-1.6,btn_y-4.6,btn_z+3.15]) cube([xw-xb+1.6,9.2,bay_h-btn_z-3.15]);
  for(s=[-1,1]) translate([xb+1.5,btn_y+(s>0?3.05:-4.6),pad_z0]) cube([xw-xb-1.5,1.55,btn_z+3.15-pad_z0+0.01]);
  translate([xb-1.6,btn_y-2.2,pad_z0]) cube([1.5,4.4,btn_z+3.15-pad_z0+0.01]);
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
module skirt(){
  // U: frente + laterais, aberta atras (a traseira colidiria ao abrir)
  y0 = fw + sk_gap; y1 = Wd - bw - 2;
  xo = cw/2 - sk_gap;
  // laterais (chanfro de entrada de 0,5 mm para dentro)
  hull(){
    translate([-xo,y0,z_lid0-sk_h+0.5]) cube([sk_t,y1-y0,sk_h-0.5+0.01]);
    translate([-xo+0.5,y0+0.5,z_lid0-sk_h]) cube([sk_t-0.5,y1-y0-0.5,0.5]);
  }
  hull(){
    translate([xo-sk_t,y0,z_lid0-sk_h+0.5]) cube([sk_t,y1-y0,sk_h-0.5+0.01]);
    translate([xo-sk_t,y0+0.5,z_lid0-sk_h]) cube([sk_t-0.5,y1-y0-0.5,0.5]);
  }
  // frente
  hull(){
    translate([-xo,y0,z_lid0-sk_h+0.5]) cube([2*xo,sk_t,sk_h-0.5+0.01]);
    translate([-xo+0.5,y0+0.5,z_lid0-sk_h]) cube([2*xo-1,sk_t-0.5,0.5]);
  }
}

module lid(i=0){
  xl = (i==0)   ? -(xc(0)-0.2)       : -lw/2;
  xr = (i==n-1) ? L-0.2-xc(n-1)      :  lw/2;
  difference(){
    union(){
      translate([xl,-tab,z_lid0]) cube([xr-xl,tab+y_h+hr,lid_t]);
      // aba frontal com ressalto da trava (rampa longa embaixo, degrau em cima)
      translate([xl,-0.3-apr_t,zg-1.4]) cube([xr-xl,apr_t,z_lid0-zg+1.41]);
      prof_x(xl+1.5,xr-xl-3,[[-0.31,zg-1.0],[-0.3+snap_b,zg+0.2],[-0.3+snap_b,zg+0.3],[-0.31,zg+0.55]]);
      skirt();
      // bracos e eixo da dobradica
      for(s=[-1,1]) hull(){
        translate([s>0?arm_x:-arm_x-arm_w,y_h,z_h]) rotate([0,90,0]) cylinder(r=hr,h=arm_w);
        translate([s>0?arm_x:-arm_x-arm_w,y_h-hr,z_lid0]) cube([arm_w,2*hr,0.1]);
      }
      xcyl(-arm_x-0.5,y_h,z_h,rod_d/2,2*arm_x+1);
    }
    // bolsao do ima (por baixo, em cima do vidro, deslocado para uma ponta)
    translate([mag_dx,reed_y,z_lid0-0.01]) cylinder(d=mag_d+mag_tol,h=mag_t*mag_stack+0.2);
    translate([0,Wd/2,z_lid0+lid_t-0.4]) linear_extrude(0.5)
      text(dias[i%7],size=5,halign="center",valign="center",font="Liberation Sans:style=Bold");
  }
}
module lid_open(i,a){
  translate([0,y_h,z_h]) rotate([-a,0,0]) translate([0,-y_h,-z_h]) lid(i);
}

// ================= BASE =================
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
        prof_x(f*L-bl/2,bl,[[y0+0.01,plate_t+snap_z-0.8],[y0-bsnap_b,plate_t+snap_z],[y0+0.01,plate_t+snap_z+0.8]]);
        prof_x(f*L-bl/2,bl,[[y1-0.01,plate_t+snap_z-0.8],[y1+bsnap_b,plate_t+snap_z],[y1-0.01,plate_t+snap_z+0.8]]);
      }
      if(full) translate([L-pad_t-0.7-btn_h,btn_y-2.5,plate_t-0.01]) cube([3.5,5,btn_z-3.25]);
    }
    translate([-0.01,Wd/2-7,plate_t-0.9]) cube([1.6,14,0.91]);
  }
}

// ================= COMPONENTES (so para visualizar; medidas ASSUMIDAS) =================
module c_esp(){
  x0=esp_x0; y0=esp_y0; zt=esp_zt;
  color("#1f4fa8") translate([x0,y0,zt-esp_t]) cube([esp_l,esp_w,esp_t]);           // placa
  color("#c8c8c8") translate([x0+esp_l-25.5,y0+(esp_w-18)/2,zt]) cube([25.5,18,3.1]); // modulo WROOM
  color("#9a9a9a") translate([x0-usbc_out,usb_yc-4.5,zt]) cube([7.5,9,3.2]);        // USB-C
  for(y=[2.5,esp_w-5.5]) color("#222") translate([x0+3,y0+y,zt]) cube([3.5,3,1.5]); // EN/BOOT
  for(s=[0,1]){
    yr = y0 + (s==0 ? 1.45 : esp_w-1.45);
    color("#111") translate([x0+5,yr-1.25,zt-esp_t-2.5]) cube([15*2.54,2.5,2.5]);   // barra de pinos
    for(k=[0:14]) color("#d4af37") translate([x0+5+1.27+k*2.54,yr,zt-esp_t-8.5]) cylinder(d=0.64,h=8.5,$fn=8);
  }
}
module c_rtc(){
  x0=rtc_x0; y0=rtc_y0; zt=bay_h-rtc_so;
  color("#2a6db0") translate([x0,y0,zt-rtc_t]) cube([rtc_l,rtc_w,rtc_t]);
  color("#111") translate([x0+12,y0+5,zt]) cube([10,7.5,2.4]);                       // DS3231
  color("#b0b0b0") translate([x0+rtc_l/2,y0+rtc_w/2,zt-rtc_t-3.2]) cylinder(d=20,h=3.2,$fn=48); // CR2032
  color("#111") translate([x0+rtc_l-2.5,y0+3,zt-rtc_t-2.5]) cube([2.5,6*2.54,2.5]);
}
module c_aux(){
  x0=aux_x0; y0=aux_y0; zt=bay_h-aux_so;
  color("#b58a4a") translate([x0,y0,zt-aux_t]) cube([aux_l,aux_w,aux_t]);           // placa perfurada
  color("#111") translate([x0+(aux_l-6.4)/2,y0+(aux_w-19.5)/2,zt-aux_t-3.3]) cube([6.4,19.5,3.3]); // 74HC595
  for(k=[0:6]) color("#c33") translate([x0+3+k*2.54,y0+2,zt-aux_t-2.5]) cube([1.6,6,1.6]);   // resistores
}
module c_led(i){
  x = xc(i);
  color("#ff3b30",0.9){
    translate([x,-led_bezel+0.4,led_z]) rotate([-90,0,0]) cylinder(d=led_d,h=bay_fw+led_bezel-1.4);
    translate([x,-led_bezel+0.4,led_z]) sphere(d=led_d);
    translate([x,bay_fw-1,led_z]) rotate([-90,0,0]) cylinder(d=led_flange,h=1);
  }
  for(dx=[-1.27,1.27]) color("#bbb") translate([x+dx,bay_fw,led_z]) rotate([-90,0,0]) cylinder(d=0.5,h=8,$fn=8);
}
module c_reed(i){
  x = xc(i);
  color("#bfefff",0.75) translate([x-reed_gl/2,reed_y,z_rc]) rotate([0,90,0]) cylinder(d=reed_gd,h=reed_gl);
  color("#555") translate([x-3,reed_y,z_rc]) rotate([0,90,0]) cylinder(d=0.6,h=6,$fn=8);   // laminas
  color("#bbb") for(s=[-1,1]){
    translate([s>0?x+reed_gl/2:x-x_leg,reed_y,z_rc]) rotate([0,90,0]) cylinder(d=0.5,h=reed_bend,$fn=8);
    translate([x+s*x_leg,reed_y,z_rc-15.5+reed_bend]) cylinder(d=0.5,h=15.5-reed_bend,$fn=8);
  }
  // fio emendado ate a bay
  color("#d22") for(s=[-1,1]) translate([x+s*x_leg,reed_y,bay_h-6]) cylinder(d=0.8,h=z_rc-15.5+reed_bend-bay_h+6.5,$fn=8);
}
module c_magnet(i,a=0){
  translate([xc(i),0,0]) translate([0,y_h,z_h]) rotate([-a,0,0]) translate([0,-y_h,-z_h])
    color("#7a7a7a") translate([mag_dx,reed_y,z_lid0]) cylinder(d=mag_d,h=mag_t*mag_stack);
}
module c_buzzer(){ color("#111") translate([L-bay_wall-0.4-6.5,buz_y,buz_z]) rotate([0,90,0]) cylinder(d=buz_d,h=7.5,$fn=48); }
module c_button(){
  xb = L - pad_t - 0.7 - btn_h;
  color("#333") translate([xb,btn_y-3,btn_z-3]) cube([btn_h-1.5,6,6]);
  color("#111") translate([xb+btn_h-1.5,btn_y,btn_z]) rotate([0,90,0]) cylinder(d=3.5,h=1.5);
}
module c_usb_cable(){
  color("#444",0.6) translate([-25,usb_yc-6,usb_zc-3.25]) cube([25-bay_wall+1.0+1.1,12,6.5]);
}
module components(lids_a=0){
  if(full){ c_esp(); c_rtc(); c_aux(); c_buzzer(); c_button(); }
  for(i=[0:n-1]){ c_led(i); c_reed(i); c_magnet(i,lids_a); }
}

// ================= IMPRESSAO =================
module body_print(){ translate([0,Wd,H]) rotate([180,0,0]) body(); }
module lid_print(i){ translate([0,y_h+hr,z_lid0+lid_t]) rotate([180,0,0]) lid(i); }
module lids_print(){
  for(i=[0:n-1]) translate([(i<4?i:i-4)*(lw+3)+xc(0),(i<4?0:tab+y_h+hr+4),0]) lid_print(i);
}
module lids_all(a=0){ for(i=[0:n-1]) translate([xc(i),0,0]) lid_open(i,a); }

// ================= SELECAO =================
if(part=="body") body_print();
else if(part=="base") base();
else if(part=="lids") lids_print();
else if(part=="lid1") translate([xc(0),0,0]) lid_print(0);
else if(part=="a_body") body();
else if(part=="a_base") translate([0,0,-plate_t]) base();
else if(part=="a_lids") lids_all(0);
else if(part=="a_lids_open") lids_all(ang);
else if(part=="open"){ body(); translate([0,0,-plate_t]) base(); for(i=[0:n-1]) translate([xc(i),0,0]) lid_open(i,i%2==0?ang:0); }
else if(part=="components"){        // de cabeca para baixo, sem base
  translate([0,Wd,H]) rotate([180,0,0]){
    color("#e8e2d0") body(); color("#d9d2bd") lids_all(0); components(0);
  }
}
else if(part=="ghost"){
  color("#e8e2d0",0.25) body(); color("#d9d2bd",0.25) lids_all(0); components(0); c_usb_cable();
}
else if(part=="comp_cut"){          // corte no centro do ima do 2o dia
  intersection(){
    union(){ color("#e8e2d0") body(); color("#d9d2bd") translate([xc(1),0,0]) lid(1); components(0); }
    translate([xc(1)+mag_dx,-20,-5]) cube([40,90,80]);
  }
}
else if(part=="reed_front"){
  components(0);
  color("#e8e2d0",0.35) intersection(){ body(); translate([xc(1)-12,-10,bay_h-6]) cube([24,15.4,H-bay_h+8]); }
}
else if(part=="cut") difference(){
  union(){ body(); translate([0,0,-plate_t]) base(); lids_all(0); }
  translate([-1,-10,-5]) cube([xc(0)+1,80,80]);
}
else if(part=="chk_lids") intersection(){ body(); lids_all(0); }
else if(part=="chk_open") intersection(){ body(); lids_all(ang); }
else if(part=="chk_base") intersection(){ body(); translate([0,0,-plate_t-0.02]) base(); }
else if(part=="chk_esp")  intersection(){ body(); c_esp(); }
else if(part=="chk_comp") intersection(){ body(); components(0); }
else { body(); translate([0,0,-plate_t]) base(); lids_all(0); }
