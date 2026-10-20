// Construction du DOM sans innerHTML : tout texte passe par des nœuds de texte, donc aucune injection possible depuis les données.
import { tidy } from "../lib/format.js";

const SVG_NS = "http://www.w3.org/2000/svg";

function applyAttributes(node, attributes) {
  for (const [name, value] of Object.entries(attributes ?? {})) {
    if (value === null || value === undefined || value === false) continue;
    if (name === "class") node.setAttribute("class", value);
    else if (name.startsWith("on") && typeof value === "function") node.addEventListener(name.slice(2).toLowerCase(), value);
    else node.setAttribute(name, value === true ? "" : String(value));
  }
}

function appendChildren(node, children) {
  for (const child of children.flat(Infinity)) {
    if (child === null || child === undefined || child === false) continue;
    node.append(child instanceof Node ? child : document.createTextNode(tidy(child)));
  }
}

export function h(tag, attributes, ...children) {
  const node = document.createElement(tag);
  applyAttributes(node, attributes);
  appendChildren(node, children);
  return node;
}

export function svg(tag, attributes, ...children) {
  const node = document.createElementNS(SVG_NS, tag);
  applyAttributes(node, attributes);
  appendChildren(node, children);
  return node;
}

export function clear(node) {
  node.replaceChildren();
  return node;
}

/** Largeur en pourcentage bornée, appliquée par le CSSOM (autorisé par la politique de sécurité, contrairement à un attribut style). */
export function setWidth(node, percentValue) {
  node.style.width = `${Math.min(Math.max(percentValue, 0), 100)}%`;
}

export function setLeft(node, percentValue) {
  node.style.left = `${Math.min(Math.max(percentValue, 0), 100)}%`;
}

const ICONS = {
  home: "M3 11l9-8 9 8v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z",
  stats: "M5 21V10m7 11V3m7 18v-7",
  settings: "M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm7.4-3a7.4 7.4 0 0 0-.1-1.2l2-1.5-2-3.4-2.3.9a7.5 7.5 0 0 0-2-1.2L14.5 2h-4l-.5 2.6a7.5 7.5 0 0 0-2 1.2l-2.3-.9-2 3.4 2 1.5a7.4 7.4 0 0 0 0 2.4l-2 1.5 2 3.4 2.3-.9a7.5 7.5 0 0 0 2 1.2l.5 2.6h4l.5-2.6a7.5 7.5 0 0 0 2-1.2l2.3.9 2-3.4-2-1.5c.1-.4.1-.8.1-1.2z",
  refresh: "M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5",
  danger: "M12 3l10 18H2zM12 10v5m0 3v.01",
  warning: "M12 3l10 18H2zM12 10v5m0 3v.01",
  info: "M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18zM12 11v6m0-9v.01",
};

/** Icône de trait de 24 px (décorative : le sens est toujours porté par un texte à côté). */
export function icon(name) {
  return svg("svg", { viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": "2", "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": "true" },
    svg("path", { d: ICONS[name] ?? "" }));
}
