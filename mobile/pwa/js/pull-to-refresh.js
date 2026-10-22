// Geste « tirer pour actualiser » : un cercle suit le doigt quand la page est tout en haut, l'actualisation part au relâchement.
import { h, icon } from "./dom.js";
import { pullDistance, shouldRefresh, PULL_TRIGGER } from "../lib/pull.js";

export function enablePullToRefresh(refresh) {
  const spinner = h("div", { class: "ptr", "aria-hidden": "true" }, icon("refresh"));
  document.body.append(spinner);
  let startX = 0;
  let startY = 0;
  let tracking = false;
  let busy = false;

  const place = (distance, animated) => {
    spinner.style.transition = animated ? "transform 0.2s ease, opacity 0.2s ease" : "none";
    spinner.style.transform = `translate(-50%, ${distance - 48}px) rotate(${distance * 4}deg)`;
    spinner.style.opacity = distance > 4 ? "1" : "0";
  };

  document.addEventListener("touchstart", (event) => {
    tracking = !busy && event.touches.length === 1 && window.scrollY <= 0;
    if (tracking) [startX, startY] = [event.touches[0].clientX, event.touches[0].clientY];
  }, { passive: true });

  document.addEventListener("touchmove", (event) => {
    if (!tracking) return;
    const distance = window.scrollY > 0 ? 0 : pullDistance(event.touches[0].clientX - startX, event.touches[0].clientY - startY);
    place(distance, false);
    spinner.dataset.distance = String(distance);
    spinner.classList.toggle("ready", shouldRefresh(distance));
  }, { passive: true });

  const release = async () => {
    if (!tracking) return;
    tracking = false;
    const distance = Number(spinner.dataset.distance ?? 0);
    spinner.dataset.distance = "0";
    spinner.classList.remove("ready");
    if (!shouldRefresh(distance)) return place(0, true);
    busy = true;
    place(PULL_TRIGGER * 0.8, true);
    spinner.classList.add("spin");
    try { await refresh(); } finally {
      spinner.classList.remove("spin");
      place(0, true);
      busy = false;
    }
  };
  document.addEventListener("touchend", release);
  document.addEventListener("touchcancel", release);
}
