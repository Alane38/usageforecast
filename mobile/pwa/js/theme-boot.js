// Appliqué avant le premier affichage (script bloquant, sans module) pour éviter un clignotement : sombre par défaut.
(function () {
  var theme = "dark";
  try {
    var saved = JSON.parse(localStorage.getItem("cub.prefs") || "null");
    if (saved && (saved.theme === "light" || saved.theme === "auto")) theme = saved.theme;
  } catch (error) { /* stockage inaccessible : le sombre par défaut convient */ }
  if (theme !== "dark") document.documentElement.setAttribute("data-theme", theme);
})();
