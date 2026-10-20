// Graphiques en SVG, selon les règles de visualisation : une teinte, barres fines à bout arrondi, grille discrète, étiquettes seulement
// sur les extrêmes. Sur téléphone il n'y a pas de survol : une colonne se touche, et son détail s'écrit sous le graphique.
import { svg } from "./dom.js";
import { ceiling } from "../lib/format.js";

const WIDTH = 328;
const MAX_BAR = 22;

/** Barre arrondie de 4 px en haut, droite à la base. */
function barPath(x, y, width, height) {
  const r = Math.min(4, width / 2, height);
  return `M${x},${y + height}V${y + r}Q${x},${y} ${x + r},${y}H${x + width - r}Q${x + width},${y} ${x + width},${y + r}V${y + height}Z`;
}

function gridLines(levels, yOf, left = 0) {
  return levels.map((level, index) => svg("line", { class: index === 0 ? "axis" : "grid", x1: left, x2: WIDTH, y1: yOf(level), y2: yOf(level) }));
}

/**
 * Colonnes cliquables. items : { label, sub?, value (null = pas de donnée), light, tooltip, emphasis? }.
 * @param {object} options { items, max, height, average?, axisLabel?, onSelect(item|null) }
 */
export function columnChart({ items, max, height = 96, average = null, axisFormat = (v) => String(v), onSelect = () => {}, labelEvery = 1, tick = null, left = 26, showEmpty = true }) {
  const top = 18;
  const labelRoom = 30;
  const top2 = top + height;
  const plotWidth = WIDTH - left;
  const slot = plotWidth / items.length;
  const barWidth = Math.min(MAX_BAR, slot - 6);
  const yOf = (value) => top + height * (1 - Math.min(Math.max(value, 0), max) / max);
  const levels = [0, max / 2, max];
  const root = svg("svg", { class: "chart", viewBox: `0 0 ${WIDTH} ${top2 + labelRoom}`, role: "group", "aria-label": "Graphique en colonnes" });

  levels.forEach((level) => root.append(svg("text", { x: left - 6, y: yOf(level) + 4, "text-anchor": "end" }, axisFormat(level))));
  root.append(...gridLines([0, max / 2, max], yOf, left));

  const tallest = items.reduce((best, item, index) => (item.value !== null && (best === -1 || item.value > items[best].value) ? index : best), -1);
  const selectable = [];
  items.forEach((item, index) => {
    const x = left + index * slot;
    const group = svg("g", { role: "button", tabindex: "0", "aria-pressed": "false", "aria-label": item.tooltip });
    const cx = x + slot / 2;
    if (item.value === null) {
      if (showEmpty) group.append(svg("rect", { class: "bar-gone", x: cx - barWidth / 2, y: top2 - 2, width: barWidth, height: 2 }));
    } else {
      const barHeight = Math.max(height * (Math.min(item.value, max) / max), 2);
      group.append(svg("path", { class: item.light ? "bar-light" : "bar-solid", d: barPath(cx - barWidth / 2, top2 - barHeight, barWidth, barHeight) }));
      if (item.emphasis || index === tallest) group.append(svg("text", { class: "strong", x: cx, y: top2 - barHeight - 5, "text-anchor": "middle" }, item.valueLabel ?? String(Math.round(item.value))));
    }
    if (index % labelEvery === 0) {
      group.append(svg("text", { class: item.emphasis ? "strong" : "", x: cx, y: top2 + 14, "text-anchor": "middle" }, item.label));
      if (item.sub) group.append(svg("text", { class: item.emphasis ? "strong" : "", x: cx, y: top2 + 27, "text-anchor": "middle" }, item.sub));
    }
    group.append(svg("rect", { class: "hit", x, y: 0, width: slot, height: top2 + labelRoom }));
    const select = () => {
      selectable.forEach((other) => other.setAttribute("aria-pressed", "false"));
      group.setAttribute("aria-pressed", "true");
      onSelect(item);
    };
    group.addEventListener("click", select);
    group.addEventListener("keydown", (event) => { if (event.key === "Enter" || event.key === " ") { event.preventDefault(); select(); } });
    selectable.push(group);
    root.append(group);
  });

  if (average !== null) {
    root.append(svg("line", { class: "avg", x1: left, x2: WIDTH, y1: yOf(average), y2: yOf(average) }));
    const text = tick ?? `moy. ${Math.round(average)}`;
    const width = text.length * 6 + 10;
    root.append(svg("rect", { class: "pill", x: WIDTH - width, y: yOf(average) - 17, width, height: 15, rx: 3 }));
    root.append(svg("text", { x: WIDTH - 5, y: yOf(average) - 6, "text-anchor": "end" }, text));
  }
  return root;
}

/**
 * Courbe de 24 h : ligne de 2 px, lavis léger, valeur finale étiquetée sur une pastille, repère tactile.
 * points : [{ t (ms), value }] ; spanMs : durée de l'axe horizontal.
 */
export function lineChart({ points, spanMs, now, height = 110, onCursor = () => {} }) {
  const left = 30;
  const top = 12;
  const bottom = top + height;
  const maxValue = Math.max(...points.map((point) => point.value), 0);
  const max = maxValue <= 15 ? 20 : maxValue <= 40 ? 50 : 100;
  const xOf = (time) => left + (WIDTH - left - 8) * (1 - (now - time) / spanMs);
  const yOf = (value) => top + height * (1 - Math.min(Math.max(value, 0), max) / max);
  const root = svg("svg", { class: "chart", viewBox: `0 0 ${WIDTH} ${bottom + 20}`, role: "img", "aria-label": "Courbe de la session sur 24 heures" });

  [0, max / 2, max].forEach((level) => {
    root.append(svg("line", { class: level === 0 ? "axis" : "grid", x1: left, x2: WIDTH, y1: yOf(level), y2: yOf(level) }));
    root.append(svg("text", { x: left - 6, y: yOf(level) + 4, "text-anchor": "end" }, `${level}`));
  });

  const segments = [];
  points.forEach((point, index) => {
    const previous = points[index - 1];
    const breaks = previous && (point.t - previous.t > 30 * 60 * 1000 || previous.value - point.value > 5);   // trou de données ou remise à zéro
    if (!previous || breaks) segments.push([]);
    segments.at(-1).push(point);
  });
  for (const segment of segments.filter((part) => part.length >= 2)) {
    const line = segment.map((point, index) => `${index === 0 ? "M" : "L"}${xOf(point.t).toFixed(1)},${yOf(point.value).toFixed(1)}`).join("");
    root.append(svg("path", { class: "wash", d: `${line}L${xOf(segment.at(-1).t).toFixed(1)},${bottom}L${xOf(segment[0].t).toFixed(1)},${bottom}Z` }));
    root.append(svg("path", { class: "line", d: line }));
  }

  const last = points.at(-1);
  if (last) {
    const x = xOf(last.t);
    const y = yOf(last.value);
    root.append(svg("circle", { class: "end-ring", cx: x, cy: y, r: 6 }), svg("circle", { class: "end-dot", cx: x, cy: y, r: 4 }));
    const labelX = Math.min(x - 28, WIDTH - 30);
    const labelY = Math.min(Math.max(y - 14, top + 8), bottom - 8);
    root.append(svg("rect", { class: "pill", x: labelX - 19, y: labelY - 9, width: 38, height: 18, rx: 4 }));
    root.append(svg("text", { class: "strong", x: labelX, y: labelY + 4, "text-anchor": "middle" }, `${Math.round(last.value)} %`));
  }

  const cursor = svg("line", { class: "cursor", y1: top, y2: bottom, visibility: "hidden" });
  root.append(cursor);
  const hit = svg("rect", { class: "hit", x: left, y: 0, width: WIDTH - left, height: bottom + 20 });
  const move = (event) => {
    const box = root.getBoundingClientRect();
    const x = ((event.clientX - box.left) / box.width) * WIDTH;
    const time = now - spanMs * (1 - (x - left) / (WIDTH - left - 8));
    const nearest = points.reduce((best, point) => (!best || Math.abs(point.t - time) < Math.abs(best.t - time) ? point : best), null);
    if (!nearest) return;
    cursor.setAttribute("x1", xOf(nearest.t));
    cursor.setAttribute("x2", xOf(nearest.t));
    cursor.setAttribute("visibility", "visible");
    onCursor(nearest);
  };
  hit.addEventListener("pointerdown", move);
  hit.addEventListener("pointermove", (event) => { if (event.buttons || event.pointerType === "touch") move(event); });
  root.append(hit);

  [0, 12, 24].forEach((hoursAgo) => {
    const x = xOf(now - hoursAgo * 3600000);
    if (x >= left - 2) root.append(svg("text", { x, y: bottom + 15, "text-anchor": hoursAgo === 24 ? "start" : hoursAgo === 0 ? "end" : "middle" }, hoursAgo === 0 ? "maintenant" : `−${hoursAgo} h`));
  });
  return root;
}
