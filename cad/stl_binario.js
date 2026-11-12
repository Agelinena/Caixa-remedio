// Converte STL texto (ASCII, como o OpenSCAD 2021 grava) para STL binario.
// Arredonda as coordenadas a 0,0001 mm, descarta triangulos degenerados e
// recalcula as normais. Alguns fatiadores (Creality Print) recusam o ASCII.
//
// Uso (Deno):  deno run --allow-read --allow-write cad/stl_binario.js cad/stl/*.stl
// Uso (Node):  node cad/stl_binario.js cad/stl/*.stl
const fs = typeof Deno !== "undefined" ? null : await import("node:fs");
const ler = (f) => (fs ? fs.readFileSync(f, "latin1") : new TextDecoder("latin1").decode(Deno.readFileSync(f)));
const gravar = (f, b) => (fs ? fs.writeFileSync(f, b) : Deno.writeFileSync(f, b));
const args = fs ? process.argv.slice(2) : Deno.args;

const r4 = (x) => {
  const v = Math.round(x * 1e4) / 1e4;
  return Object.is(v, -0) ? 0 : v;
};

for (const f of args) {
  const txt = ler(f);
  if (!txt.trimStart().startsWith("solid") || !txt.includes("facet")) {
    console.log(`${f}: ja e binario, pulando`);
    continue;
  }
  const nums = [];
  const re = /vertex\s+(\S+)\s+(\S+)\s+(\S+)/g;
  let m;
  while ((m = re.exec(txt))) nums.push(r4(+m[1]), r4(+m[2]), r4(+m[3]));
  const tris = [];
  let ruins = 0;
  for (let i = 0; i + 8 < nums.length; i += 9) {
    const [ax, ay, az, bx, by, bz, cx, cy, cz] = nums.slice(i, i + 9);
    const ux = bx - ax, uy = by - ay, uz = bz - az;
    const vx = cx - ax, vy = cy - ay, vz = cz - az;
    let nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
    const len = Math.hypot(nx, ny, nz);
    if (!(len > 1e-9) || [ax, ay, az, bx, by, bz, cx, cy, cz].some((v) => !Number.isFinite(v))) {
      ruins++;
      continue;
    }
    tris.push([nx / len, ny / len, nz / len, ax, ay, az, bx, by, bz, cx, cy, cz]);
  }
  const buf = new ArrayBuffer(84 + tris.length * 50);
  const dv = new DataView(buf);
  const cab = "Caixa de remedios - OpenSCAD -> STL binario";
  for (let i = 0; i < cab.length; i++) dv.setUint8(i, cab.charCodeAt(i));
  dv.setUint32(80, tris.length, true);
  let o = 84;
  for (const t of tris) {
    for (const v of t) {
      dv.setFloat32(o, v, true);
      o += 4;
    }
    o += 2;
  }
  gravar(f, new Uint8Array(buf));
  console.log(`${f}: ${tris.length} triangulos, ${ruins} degenerados removidos`);
}
