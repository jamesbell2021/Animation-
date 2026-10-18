// Background skylines for each sector, built from polylines in local coordinates
// (origin at the element's base centre, y UP). The game flips y when drawing.
const Landmarks = (() => {
  const P = Math.PI;
  const rect = (cx, y0, w, h) => [[cx - w / 2, y0], [cx + w / 2, y0], [cx + w / 2, y0 + h], [cx - w / 2, y0 + h], [cx - w / 2, y0]];
  const line = (x0, y0, x1, y1) => [[x0, y0], [x1, y1]];
  function arc(cx, cy, r, a0, a1, n = 12, ry = r) {
    const pts = [];
    for (let i = 0; i <= n; i++) { const a = a0 + (a1 - a0) * i / n; pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * ry]); }
    return pts;
  }
  function dome(cx, y0, r, ry = r) { return arc(cx, y0, r, 0, P, 14, ry); }
  function windows(L, cx, y0, w, h, cols, rows, rnd) {
    const cw = w / (cols + 1), rh = h / (rows + 1);
    for (let r = 1; r <= rows; r++) for (let c = 1; c <= cols; c++) {
      if (rnd && rnd() < 0.3) continue;
      const x = cx - w / 2 + c * cw, y = y0 + r * rh;
      L.push(line(x - 1.5, y, x + 1.5, y));
    }
  }
  function battlements(L, x0, x1, y, h, step) {
    const pts = [[x0, y]];
    let up = false;
    for (let x = x0; x < x1; x += step) { up = !up; pts.push([x, y + (up ? h : 0)]); pts.push([Math.min(x1, x + step), y + (up ? h : 0)]); }
    L.push(pts);
  }
  function spire(L, cx, y0, w, h) { L.push([[cx - w / 2, y0], [cx, y0 + h], [cx + w / 2, y0]]); }
  function tree(L, cx, h) {
    L.push(line(cx, 0, cx, h * 0.6));
    L.push(arc(cx, h * 0.55, h * 0.45, 0.15, P - 0.15, 10, h * 0.35));
    L.push(line(cx - h * 0.4, h * 0.6, cx + h * 0.4, h * 0.6));
  }
  function crane(L, cx, w, h) {           // Harland & Wolff gantry crane
    L.push([[cx - w / 2 - 6, 0], [cx - w / 2 + 4, h], [cx - w / 2 + 14, 0]]);
    L.push([[cx + w / 2 - 14, 0], [cx + w / 2 - 4, h], [cx + w / 2 + 6, 0]]);
    L.push(rect(cx, h - 8, w + 10, 10));
    for (let x = cx - w / 2 + 10; x < cx + w / 2 - 10; x += 16) L.push([[x, h - 8], [x + 8, h + 2], [x + 16, h - 8]]);
    L.push(rect(cx - w * 0.15, h + 2, 14, 9));
    L.push(line(cx - w * 0.15, h - 8, cx - w * 0.15, h * 0.45));
    L.push(rect(cx - w * 0.15, h * 0.45 - 6, 6, 6));
  }
  function stickFigureHorse(L, cx, y0, s) { // the quadriga horses, very roughly
    L.push([[cx - 6 * s, y0], [cx - 5 * s, y0 + 6 * s], [cx + 3 * s, y0 + 7 * s], [cx + 6 * s, y0 + 11 * s], [cx + 8 * s, y0 + 9 * s]]);
    L.push(line(cx + 3 * s, y0 + 7 * s, cx + 3 * s, y0));
  }

  const CITY = {
    belfast(add) {
      add(170, 150, L => { crane(L, 0, 110, 92); }, 'GOLIATH');
      add(290, 170, L => { crane(L, 0, 120, 106); }, 'SAMSON');
      add(470, 110, L => {                                      // City Hall
        L.push(rect(0, 0, 110, 28)); windows(L, 0, 0, 110, 28, 7, 2);
        [-48, 48].forEach(x => { L.push(rect(x, 28, 12, 20)); L.push(dome(x, 48, 6)); });
        L.push(rect(0, 28, 36, 10)); L.push(dome(0, 38, 20, 22)); L.push(rect(0, 60, 6, 8)); L.push(line(0, 68, 0, 76));
      }, 'CITY HALL');
      add(620, 110, L => {                                      // Albert Clock, with its lean
        const lean = 0.05;
        const pts = [[-7, 0], [-7 + 60 * lean, 60], [-4 + 60 * lean, 60], [0 + 76 * lean, 78], [4 + 60 * lean, 60], [7 + 60 * lean, 60], [7, 0]];
        L.push(pts); L.push(arc(50 * lean, 50, 4.5, 0, 2 * P, 10)); L.push(line(50 * lean, 50, 50 * lean + 2.5, 52.5));
      }, 'ALBERT CLOCK');
      add(820, 150, L => { L.push(rect(0, 0, 60, 70)); windows(L, 0, 0, 60, 70, 4, 6); L.push(line(0, 70, 0, 90)); }, 'OBEL');
    },
    edinburgh(add) {
      add(240, 220, L => {                                      // the Castle on its rock
        L.push([[-110, 0], [-90, 18], [-70, 30], [-50, 48], [-20, 55], [20, 58], [50, 50], [80, 38], [100, 20], [110, 0]]);
        battlements(L, -60, 60, 58, 5, 8);
        L.push(rect(-30, 58, 24, 26)); battlements(L, -42, -18, 84, 4, 6);
        L.push(rect(25, 58, 30, 18)); battlements(L, 10, 40, 76, 4, 6);
        L.push(rect(-30, 65, 4, 6)); L.push(rect(25, 64, 4, 5));
      }, 'THE CASTLE');
      add(520, 110, L => {                                      // Scott Monument
        L.push([[-16, 0], [-16, 30], [-10, 30], [-6, 60], [-3, 80], [0, 96], [3, 80], [6, 60], [10, 30], [16, 30], [16, 0]]);
        L.push(line(-16, 30, 16, 30)); L.push(line(-10, 30, 10, 30)); L.push(arc(0, 14, 9, 0, P, 8)); L.push(line(-6, 60, 6, 60));
      }, 'SCOTT MONUMENT');
      add(720, 110, L => { L.push(rect(0, 0, 50, 46)); windows(L, 0, 0, 50, 46, 3, 4); L.push([[-25, 46], [0, 62], [25, 46]]); L.push(rect(14, 46, 6, 26)); spire(L, 14, 72, 6, 12); }, 'ST GILES');
    },
    liverpool(add) {
      add(300, 170, L => {                                      // Royal Liver Building
        L.push(rect(0, 0, 100, 58)); windows(L, 0, 0, 100, 58, 7, 5);
        [-30, 30].forEach(x => {
          L.push(rect(x, 58, 20, 30)); L.push(arc(x, 76, 5, 0, 2 * P, 10));
          L.push(dome(x, 88, 10, 9)); L.push(line(x, 97, x, 104));
          L.push([[x - 6, 108], [x, 104], [x + 6, 108]]); L.push([[x - 4, 104], [x, 102], [x + 4, 104]]); // the Liver Bird
        });
      }, 'LIVER BUILDING');
      add(540, 190, L => {                                      // Anglican Cathedral
        L.push(rect(0, 0, 120, 44)); L.push(rect(0, 0, 40, 100)); battlements(L, -20, 20, 100, 4, 5);
        L.push(arc(-40, 20, 8, 0, P, 8)); L.push(arc(40, 20, 8, 0, P, 8)); L.push(arc(0, 60, 9, 0, P, 8)); L.push(line(-9, 60, -9, 48)); L.push(line(9, 60, 9, 48));
      }, 'CATHEDRAL');
      add(760, 130, L => { L.push(line(-3, 0, -3, 100)); L.push(line(3, 0, 3, 100)); L.push([[-14, 84], [-14, 100], [0, 110], [14, 100], [14, 84], [-14, 84]]); L.push(line(0, 110, 0, 124)); }, 'RADIO CITY');
    },
    london(add) {
      add(180, 160, L => {                                      // Tower Bridge
        [-45, 45].forEach(x => { L.push(rect(x, 0, 22, 78)); spire(L, x, 78, 22, 14); L.push(rect(x - 6, 78, 3, 6)); L.push(rect(x + 6, 78, 3, 6)); });
        L.push(line(-34, 60, 34, 60)); L.push(line(-34, 66, 34, 66)); L.push(line(-34, 18, 34, 18));
        for (let x = -30; x <= 30; x += 10) L.push(line(x, 60, x, 66));
        L.push(arc(-80, 18, 24, P * 0.5, P, 8, 44)); L.push(arc(80, 18, 24, 0, P * 0.5, 8, 44)); L.push(line(-104, 18, -56, 18)); L.push(line(56, 18, 104, 18));
      }, 'TOWER BRIDGE');
      add(420, 170, L => {                                      // St Paul's
        L.push(rect(0, 0, 100, 26)); windows(L, 0, 0, 100, 26, 8, 1);
        L.push(rect(0, 26, 56, 14)); for (let x = -24; x <= 24; x += 8) L.push(line(x, 26, x, 40));
        L.push(dome(0, 40, 30, 30)); L.push(rect(0, 70, 10, 10)); L.push(dome(0, 80, 5)); L.push(line(0, 85, 0, 94)); L.push(line(-3, 90, 3, 90));
        [-40, 40].forEach(x => { L.push(rect(x, 26, 12, 22)); L.push(dome(x, 48, 6)); });
      }, 'ST PAULS');
      add(640, 180, L => {                                      // Big Ben (the Elizabeth Tower)
        L.push(rect(0, 0, 20, 92)); L.push(arc(0, 80, 7, 0, 2 * P, 12)); L.push(line(0, 80, 0, 86)); L.push(line(0, 80, 4, 80));
        L.push([[-10, 92], [-10, 100], [0, 118], [10, 100], [10, 92]]); L.push(line(0, 118, 0, 126));
        L.push(rect(-40, 0, 60, 30)); windows(L, -40, 0, 60, 30, 5, 2); battlements(L, -70, -10, 30, 4, 6);
      }, 'BIG BEN');
      add(860, 160, L => { L.push(arc(0, 60, 52, 0, 2 * P, 28)); L.push(arc(0, 60, 44, 0, 2 * P, 28)); for (let i = 0; i < 16; i++) { const a = i / 16 * 2 * P; L.push(line(0, 60, Math.cos(a) * 52, 60 + Math.sin(a) * 52)); } L.push([[-30, 0], [0, 60], [30, 0]]); }, 'LONDON EYE', t => {
        const L = []; for (let i = 0; i < 16; i++) { const a = i / 16 * 2 * P + t * 0.08; L.push(rect(Math.cos(a) * 52, 58 + Math.sin(a) * 52, 5, 4)); } return L;
      });
    },
    paris(add) {
      add(220, 150, L => {                                      // Arc de Triomphe
        L.push(rect(0, 0, 66, 52)); L.push(line(-33, 44, 33, 44)); L.push([[-14, 0], [-14, 24], ...arc(0, 24, 14, P, 2 * P, 10).slice(1), [14, 0]]);
      }, 'ARC DE TRIOMPHE');
      add(480, 280, L => {                                      // La Tour Eiffel
        const prof = [[0, 60], [34, 42], [66, 24], [96, 9], [130, 3]];
        const side = s => prof.map(([y, w]) => [s * w, y]);
        L.push(side(-1)); L.push(side(1));
        for (const [y, w] of prof) L.push(line(-w, y, w, y));
        L.push(line(-28, 34, 28, 34)); L.push(line(-21, 66, 21, 66));
        L.push(arc(0, 20, 30, 0.35, P - 0.35, 10, 22));
        for (let i = 0; i < prof.length - 1; i++) {
          const [y0, w0] = prof[i], [y1, w1] = prof[i + 1];
          const n = i < 2 ? 2 : 1;
          for (let k = 0; k < n; k++) {
            const ya = y0 + (y1 - y0) * k / n, yb = y0 + (y1 - y0) * (k + 1) / n;
            const wa = w0 + (w1 - w0) * k / n, wb = w0 + (w1 - w0) * (k + 1) / n;
            L.push(line(-wa, ya, wb, yb)); L.push(line(wa, ya, -wb, yb));
          }
        }
        L.push(line(0, 130, 0, 148)); L.push(rect(0, 130, 6, 4));
      }, 'TOUR EIFFEL');
      add(760, 160, L => {                                      // Notre-Dame
        [-20, 20].forEach(x => { L.push(rect(x, 0, 22, 66)); windows(L, x, 36, 22, 26, 1, 2); L.push(arc(x, 50, 5, 0, P, 6)); });
        L.push(rect(0, 0, 18, 52)); L.push(arc(0, 36, 7, 0, 2 * P, 12)); L.push(arc(0, 36, 3, 0, 2 * P, 8));
        L.push(line(0, 52, 0, 60)); L.push([[12, 0], [14, 40], [14, 50], [15, 98], [16, 50], [16, 40], [18, 0]]);
      }, 'NOTRE-DAME');
    },
    amsterdam(add) {
      add(170, 130, L => { L.push([[-14, 0], [-9, 50], [9, 50], [14, 0]]); L.push(dome(0, 50, 9, 7)); L.push(rect(0, 0, 10, 14)); }, 'WINDMILL', t => {
        const L = []; for (let i = 0; i < 4; i++) { const a = i * P / 2 + t * 0.6; L.push(line(0, 55, Math.cos(a) * 38, 55 + Math.sin(a) * 38)); L.push(line(Math.cos(a) * 10, 55 + Math.sin(a) * 10, Math.cos(a) * 36 + Math.cos(a + P / 2) * 5, 55 + Math.sin(a) * 36 + Math.sin(a + P / 2) * 5)); } return L;
      });
      add(430, 190, L => {                                      // canal houses with gables
        const xs = [-80, -52, -24, 4, 32, 60];
        xs.forEach((x, i) => {
          const h = 48 + (i % 3) * 8, w = 26;
          L.push([[x - w / 2, 0], [x - w / 2, h]]); L.push([[x + w / 2, 0], [x + w / 2, h]]);
          if (i % 3 === 0) L.push([[x - w / 2, h], [x - w / 2 + 5, h], [x - w / 2 + 5, h + 6], [x - 5, h + 6], [x - 5, h + 12], [x + 5, h + 12], [x + 5, h + 6], [x + w / 2 - 5, h + 6], [x + w / 2 - 5, h], [x + w / 2, h]]);
          else if (i % 3 === 1) L.push([[x - w / 2, h], [x, h + 16], [x + w / 2, h]]);
          else L.push([[x - w / 2, h], ...arc(x, h, w / 2, P, 2 * P, 8, 12).slice(1)]);
          windows(L, x, 0, w, h, 2, 3);
        });
      }, 'CANAL HOUSES');
      add(700, 140, L => { L.push(rect(0, 0, 16, 70)); L.push(arc(0, 60, 5, 0, 2 * P, 10)); L.push(rect(0, 70, 10, 10)); L.push([[-8, 80], [-5, 90], [0, 86], [5, 90], [8, 80]]); L.push(line(0, 90, 0, 100)); }, 'WESTERKERK');
      add(880, 130, L => { L.push([[-14, 0], [-9, 50], [9, 50], [14, 0]]); L.push(dome(0, 50, 9, 7)); }, 'WINDMILL', t => {
        const L = []; for (let i = 0; i < 4; i++) { const a = i * P / 2 - t * 0.45 + 0.4; L.push(line(0, 55, Math.cos(a) * 38, 55 + Math.sin(a) * 38)); } return L;
      });
    },
    berlin(add) {
      add(240, 160, L => {                                      // Brandenburg Gate
        for (let i = 0; i < 6; i++) { const x = -45 + i * 18; L.push(rect(x, 4, 7, 50)); L.push(line(x - 5, 54, x + 5, 54)); }
        L.push(rect(0, 0, 112, 4)); L.push(rect(0, 54, 112, 12)); L.push(rect(0, 66, 60, 8));
        for (let i = 0; i < 4; i++) stickFigureHorse(L, -20 + i * 9, 74, 1);
        L.push(rect(14, 74, 10, 8)); L.push(line(19, 82, 19, 94)); L.push(arc(19, 94, 3, 0, 2 * P, 8));
      }, 'BRANDENBURG GATE');
      add(520, 190, L => {                                      // the Fernsehturm
        L.push([[-7, 0], [-3, 96], [3, 96], [7, 0]]); L.push(arc(0, 112, 15, 0, 2 * P, 20)); L.push(line(-15, 112, 15, 112)); L.push(line(-14, 106, 14, 106));
        L.push(line(0, 127, 0, 165)); L.push(line(-3, 150, 3, 150));
      }, 'FERNSEHTURM');
      add(780, 180, L => {                                      // the Reichstag
        L.push(rect(0, 0, 120, 40)); windows(L, 0, 0, 120, 40, 9, 2); [-52, 52].forEach(x => L.push(rect(x, 40, 14, 12)));
        L.push(rect(0, 40, 30, 10)); L.push(dome(0, 50, 22, 20)); for (let a = 0.3; a < P; a += 0.5) L.push(line(0, 50, Math.cos(a) * 22, 50 + Math.sin(a) * 20));
      }, 'REICHSTAG');
    },
    vienna(add) {
      add(230, 200, L => {                                      // Stephansdom
        L.push(rect(-20, 0, 70, 36)); L.push([[-55, 36], [-55, 36], [-20, 70], [15, 36]]); for (let x = -50; x < 12; x += 6) L.push(line(x, 36 + (x + 55) * 0.6, x + 5, 36));
        L.push([[28, 0], [28, 70], [31, 88], [34, 100], [36, 112], [38, 100], [41, 88], [44, 70], [44, 0]]); L.push(line(36, 112, 36, 124));
        L.push(arc(36, 60, 4, 0, P, 6)); L.push(line(32, 60, 32, 50)); L.push(line(40, 60, 40, 50));
      }, 'STEPHANSDOM');
      add(500, 180, L => { L.push(arc(0, 50, 45, 0, 2 * P, 28)); L.push([[-34, 0], [0, 50], [34, 0]]); for (let i = 0; i < 15; i++) { const a = i / 15 * 2 * P; L.push(line(0, 50, Math.cos(a) * 45, 50 + Math.sin(a) * 45)); } }, 'RIESENRAD', t => {
        const L = []; for (let i = 0; i < 15; i++) { const a = i / 15 * 2 * P - t * 0.1; L.push(rect(Math.cos(a) * 45, 46 + Math.sin(a) * 45, 7, 6)); } return L;
      });
      add(780, 160, L => {                                      // Karlskirche
        L.push(rect(0, 0, 90, 28)); for (let x = -30; x <= 30; x += 10) L.push(line(x, 0, x, 28)); L.push([[-40, 28], [0, 42], [40, 28]]);
        L.push(rect(0, 42, 34, 12)); L.push(dome(0, 54, 24, 26)); L.push(rect(0, 80, 8, 8)); L.push(line(0, 88, 0, 96));
        [-62, 62].forEach(x => { L.push(rect(x, 0, 10, 56)); L.push(rect(x, 56, 14, 5)); L.push(line(x, 61, x, 70)); });
      }, 'KARLSKIRCHE');
    },
    rome(add) {
      add(230, 180, L => {                                      // the Colosseum, with its broken side
        const w = 160, tiers = [0, 18, 36];
        for (const y of tiers) {
          const xEnd = y < 36 ? w / 2 : w / 2 - 44;
          L.push(line(-w / 2, y, xEnd, y));
          for (let x = -w / 2 + 8; x < xEnd - 6; x += 14) { L.push([[x, y + 3], ...arc(x + 5, y + 10, 5, P, 2 * P, 6).slice(0, 4), [x + 10, y + 3]]); L.push(line(x, y + 3, x, y + 10)); L.push(line(x + 10, y + 3, x + 10, y + 10)); }
        }
        L.push(line(-w / 2, 0, -w / 2, 54)); L.push([[-w / 2, 54], [-w / 2 + 40, 54], [-w / 2 + 50, 48], [-w / 2 + 62, 54], [-w / 2 + 80, 50], [-w / 2 + 100, 54], [-w / 2 + 116, 46], [w / 2 - 44, 36]]);
        L.push(line(w / 2, 0, w / 2, 36)); L.push([[w / 2 - 44, 36], [w / 2 - 30, 40], [w / 2 - 20, 30], [w / 2 - 8, 36], [w / 2, 36]]);
      }, 'COLOSSEUM');
      add(530, 200, L => {                                      // St Peter's
        L.push(rect(0, 0, 130, 30)); for (let x = -55; x <= 55; x += 11) L.push(line(x, 0, x, 30)); L.push(rect(0, 30, 130, 6)); L.push([[-30, 36], [0, 48], [30, 36]]);
        L.push(rect(0, 36, 50, 18)); for (let x = -20; x <= 20; x += 8) L.push(line(x, 36, x, 54)); L.push(dome(0, 54, 34, 34)); L.push(rect(0, 88, 12, 10)); L.push(dome(0, 98, 6)); L.push(line(0, 104, 0, 112)); L.push(line(-3, 108, 3, 108));
      }, 'ST PETERS');
      add(760, 90, L => { tree(L, -30, 60); tree(L, 10, 72); tree(L, 50, 56); }, 'PINES');
      add(900, 90, L => { L.push(rect(0, 0, 50, 40)); windows(L, 0, 0, 50, 40, 3, 3); L.push([[-25, 40], [0, 50], [25, 40]]); }, 'VILLA');
    },
    athens(add) {
      add(360, 300, L => {                                      // the Acropolis and the Parthenon
        L.push([[-150, 0], [-130, 22], [-100, 40], [-60, 52], [0, 56], [60, 54], [100, 44], [130, 28], [150, 0]]);
        L.push(rect(0, 56, 120, 6)); L.push(rect(0, 62, 110, 4));
        for (let i = 0; i < 8; i++) { const x = -49 + i * 14; L.push(rect(x, 66, 5, 26)); L.push(line(x - 4, 92, x + 4, 92)); }
        L.push(rect(0, 92, 112, 6)); L.push([[-56, 98], [-20, 112], [-8, 106], [10, 114], [40, 100]]);
        L.push(rect(-90, 40, 30, 14)); L.push(line(-90, 54, -84, 60));
      }, 'ACROPOLIS');
      add(720, 120, L => { L.push([[-70, 0], [-40, 40], [-10, 70], [10, 70], [40, 40], [70, 0]]); L.push(rect(0, 70, 14, 10)); L.push(dome(0, 80, 5)); L.push(line(0, 85, 0, 92)); }, 'LYCABETTUS');
      add(900, 100, L => { L.push(rect(0, 0, 60, 46)); windows(L, 0, 0, 60, 46, 4, 4); }, 'FLATS');
    }
  };

  // Deterministic filler so the same sector always looks the same.
  function mulberry(seed) { return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

  function build(key, width, seed = 1) {
    const out = [];
    const rnd = mulberry(seed * 7919 + key.length);
    const add = (x, w, fn, name, anim) => { const L = []; fn(L); out.push({ x, w, lines: L, name, anim: anim || null, heat: 0, ruined: false, burnT: 0 }); };
    (CITY[key] || CITY.belfast)(add);
    // Fill the gaps with ruined tenements and chimneys.
    const occupied = out.map(e => [e.x - e.w / 2, e.x + e.w / 2]);
    for (let x = 30; x < width - 10; x += 22 + rnd() * 30) {
      if (occupied.some(([a, b]) => x > a - 14 && x < b + 14)) continue;
      const w = 18 + rnd() * 30, h = 18 + rnd() * 48;
      const L = [];
      const pts = [[-w / 2, 0], [-w / 2, h]];
      let step = 0; const n = 2 + Math.floor(rnd() * 3);
      for (let i = 1; i <= n; i++) { const px = -w / 2 + w * i / n; pts.push([px, h - (rnd() < 0.5 ? 0 : rnd() * h * 0.5)]); step++; }
      pts.push([w / 2, 0]); L.push(pts);
      if (rnd() < 0.5) windows(L, 0, 0, w, h * 0.7, Math.max(1, Math.floor(w / 9)), Math.max(1, Math.floor(h / 12)), rnd);
      if (rnd() < 0.3) L.push(line(w * 0.3, h, w * 0.3, h + 10));
      out.push({ x, w, lines: L, name: null, anim: null, heat: 0, ruined: false, burnT: 0 });
    }
    return out;
  }
  return { build, keys: Object.keys(CITY) };
})();
