// =====================================================================
//  CAIXA DE REMEDIOS INTELIGENTE - 7 dias, fileira unica
//  ESP32 + reed switch por tampa + LED por dia
//  Tudo em mm. Mude os parametros abaixo e exporte (F6 -> STL).
//
//  Escolha o que exportar na variavel "part":
//    "body"      corpo (compartimentos + bay da eletronica)
//    "lids"      as 7 tampas deitadas, prontas para imprimir
//    "base"      tampa de baixo (fecha a bay, segura o ESP32)
//    "assembly"  tudo montado (so para visualizar)
// =====================================================================

part = "assembly";

// ---------- Compartimentos ----------
n   = 7;      // numero de dias
cw  = 18;     // largura interna de cada compartimento
cd  = 30;     // profundidade interna
ch  = 20;     // altura interna
wall = 1.6;   // parede entre compartimentos e laterais
fw   = 4.0;   // parede frontal (abriga o reed)
bw   = 1.6;   // parede traseira

// ---------- Bay da eletronica (embaixo) ----------
bay_h    = 22;   // altura interna
ceil_t   = 2;    // espessura entre bay e compartimentos
bay_wall = 2;    // parede da bay

// ---------- Componentes (AJUSTE se medir diferente) ----------
reed_d   = 2.2;  // diametro do vidro do reed
reed_len = 14;   // comprimento do vidro
reed_tol = 0.4;
mag_d    = 5;    // diametro do ima
mag_t    = 1;    // espessura de UM ima
mag_stack = 1;   // quantos imas empilhados (use 2 se o sensor falhar)
mag_tol  = 0.25;
led_d      = 5;    // 5 ou 3 mm (MEDIR o seu LED!)
led_flange = 5.9;  // aro do LED: 5mm -> 5.9 | 3mm -> 3.8
led_z      = 11.5; // altura do LED na frente
pin_d    = 1.75;   // dobradica: pedaco de filamento 1.75 mm
usb_w = 17; usb_h = 9; usb_z = 12.3; // furo USB-C (cabo com capa)
btn_d = 7;       // furo do botao (parede lateral direita)

// ---------- Derivados ----------
pitch   = cw + wall;
L       = n*cw + (n+1)*wall;
Wd      = fw + cd + bw;
z_cell0 = bay_h + ceil_t;
H       = z_cell0 + ch;
reed_y  = 2.0;
reed_z  = H - 2.2;
lid_gap = 0.15;
lid_t   = 2.4;
z_lid0  = H + lid_gap;
y_h     = Wd + 2.5;       // eixo da dobradica
z_h     = z_lid0 + 2.25;
hr      = 3;
plate_t = 2.4;
post_r  = 2.7;
post_pos = [[5,5.5],[L-5,5.5],[5,Wd-5.5],[L-5,Wd-5.5]];
bx0 = 10;                 // inicio do ESP32 dentro da bay
rail_h = 9;               // suporte do ESP32 (pinos para baixo)

function xc(i) = wall + i*pitch + cw/2;

// ================= CORPO =================
module hinge_block(i){
  translate([i*pitch,0,0])
  hull(){
    translate([0,y_h,z_h]) rotate([0,90,0]) cylinder(r=hr,h=wall,$fn=32);
    translate([0,Wd-bw,H-6]) cube([wall,bw+0.4,6]);
  }
}

module cell_details(i){
  x = xc(i);
  rl = reed_len + reed_tol;
  // canaleta do reed (aberta por cima para encaixar o vidro)
  translate([x-rl/2,reed_y,reed_z]) rotate([0,90,0]) cylinder(d=reed_d+0.4,h=rl,$fn=24);
  translate([x-rl/2,reed_y-(reed_d+0.2)/2,reed_z]) cube([rl,reed_d+0.2,H-reed_z+0.1]);
  // furos para os fios do reed descerem ate a bay
  for(s=[-1,1]) translate([x+s*8.6,reed_y,bay_h-0.1]) cylinder(d=1.6,h=reed_z-bay_h+0.1,$fn=16);
  // furo do LED na frente + rebaixo para o aro
  translate([x,-0.01,led_z]) rotate([-90,0,0]) cylinder(d=led_d+0.3,h=bay_wall+0.02,$fn=32);
  translate([x,bay_wall-1.0,led_z]) rotate([-90,0,0]) cylinder(d=led_flange+0.5,h=1.1,$fn=32);
}

module posts(){
  for(p=post_pos) translate([p[0],p[1],0]) difference(){
    cylinder(r=post_r,h=bay_h+0.5,$fn=24);
    translate([0,0,-0.01]) cylinder(d=2.5,h=12,$fn=20);   // parafuso M3 autoatarraxante
  }
}

module body(){
  union(){
    difference(){
      union(){
        cube([L,Wd,H]);
        for(i=[0:n]) hinge_block(i);
      }
      // bay (aberta embaixo)
      translate([bay_wall,bay_wall,-0.01]) cube([L-2*bay_wall,Wd-2*bay_wall,bay_h+0.01]);
      // compartimentos
      for(i=[0:n-1]) translate([wall+i*pitch,fw,z_cell0]) cube([cw,cd,ch+0.01]);
      for(i=[0:n-1]) cell_details(i);
      // furo do pino da dobradica
      translate([-1,y_h,z_h]) rotate([0,90,0]) cylinder(d=pin_d+0.35,h=L+2,$fn=24);
      // USB-C (parede esquerda)
      translate([-0.01,Wd/2-usb_w/2,usb_z-usb_h/2]) cube([bay_wall+0.02,usb_w,usb_h]);
      // botao + saida do buzzer (parede direita)
      translate([L-bay_wall-0.01,10,12]) rotate([0,90,0]) cylinder(d=btn_d,h=bay_wall+0.02,$fn=32);
      for(y=[20,24,28]) translate([L-bay_wall-0.01,y,12]) rotate([0,90,0]) cylinder(d=2.5,h=bay_wall+0.02,$fn=16);
    }
    posts();
  }
}

// ================= TAMPA (1 unidade, coordenadas de montagem, centrada em x=0) =================
module lid(){
  lw = pitch - 0.4;       // largura da parte larga
  kw = cw - 0.6;          // largura da parte da dobradica
  tab = 6;                // aba para o dedo
  ms_x = mag_t*mag_stack + mag_tol;
  ms_y = mag_d + mag_tol;
  ms_z = mag_d + mag_tol;
  difference(){
    union(){
      translate([-lw/2,-tab,z_lid0]) cube([lw,tab+33,lid_t]);
      translate([-kw/2,32.9,z_lid0]) cube([kw,y_h-32.9,lid_t]);
      intersection(){
        translate([-kw/2,y_h,z_h]) rotate([0,90,0]) cylinder(r=hr,h=kw,$fn=40);
        translate([-kw/2,y_h-hr-0.1,z_lid0]) cube([kw,2*hr+0.2,10]);
      }
      // bloco do ima (ima "em pe", eixo no sentido do reed)
      translate([-(ms_x+3)/2,reed_y-ms_y/2-0.9,z_lid0]) cube([ms_x+3,ms_y+1.8,ms_z+1.2]);
    }
    // bolsao do ima, aberto por baixo
    translate([-ms_x/2,reed_y-ms_y/2,z_lid0-0.01]) cube([ms_x,ms_y,ms_z+0.01]);
    // furo do pino
    translate([-kw/2-1,y_h,z_h]) rotate([0,90,0]) cylinder(d=2.2,h=kw+2,$fn=24);
  }
}

module lids_print(){
  for(i=[0:n-1]) translate([i*22+11,7,-z_lid0]) lid();
}

// ================= BASE =================
module base(){
  difference(){
    union(){
      cube([L,Wd,plate_t]);
      difference(){
        translate([bay_wall+0.2,bay_wall+0.2,plate_t]) cube([L-2*bay_wall-0.4,Wd-2*bay_wall-0.4,1.4]);
        translate([bay_wall+1.4,bay_wall+1.4,plate_t-0.01]) cube([L-2*bay_wall-2.8,Wd-2*bay_wall-2.8,1.5]);
        for(p=post_pos) translate([p[0],p[1],plate_t-0.01]) cylinder(r=post_r+0.5,h=2,$fn=24);
      }
      // trilho central: apoia o ESP32 (pinos ficam para baixo)
      translate([bx0,Wd/2-3,plate_t]) cube([46,6,rail_h]);
    }
    for(p=post_pos) translate([p[0],p[1],-0.01]){
      cylinder(d=3.4,h=plate_t+0.02,$fn=24);
      cylinder(d1=6.4,d2=3.4,h=1.6,$fn=24);
    }
  }
}

// ================= SELECAO =================
if(part=="body") body();
else if(part=="lids") lids_print();
else if(part=="lid1") translate([0,7,-z_lid0]) lid();
else if(part=="base") base();
else if(part=="cut_front") difference(){ body(); translate([-1,-1,-1]) cube([L+2,reed_y+1,H+10]); }
else if(part=="cut_one") difference(){ body(); translate([-1,-1,-1]) cube([L+2,reed_y+1,H+10]); translate([-1,-1,-1]) cube([L+2,Wd+4,0]); }
else if(part=="body_open") { body(); }
else if(part=="a_body") body();
else if(part=="a_base") translate([0,0,-plate_t]) base();
else if(part=="a_lids") for(i=[0:n-1]) translate([xc(i),0,0]) lid();
else { body(); translate([0,0,-plate_t]) base(); for(i=[0:n-1]) translate([xc(i),0,0]) lid(); }
