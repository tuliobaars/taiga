/* taiga example front end. Finds its root by data-mode, reads its JSON, renders a card.
   Host-safe: ASCII only, no literal markup tags (see taiga_check_assets()). */
(function () {
  'use strict';
  var LABEL = { html: 'Standalone HTML', quarto: 'Quarto', shiny: 'Shiny' };
  function esc(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
  function mount(root) {
    if (root.getAttribute('data-ready')) return;
    var node = document.getElementById(root.id + '-data');
    var data = node ? JSON.parse(node.textContent) : {};
    var mode = root.getAttribute('data-mode') || 'html';
    var items = [].concat(data.items || []);
    var title = esc(data.title || 'Hello');
    root.innerHTML = '<div class="hello-card"><span class="hello-mode"><i></i>' + LABEL[mode] + '</span>' +
      '<h1>' + title.replace(/(\S+)$/, '<b>$1</b>') + '</h1>' +
      '<ul>' + items.map(function (x) { return '<li>' + esc(x) + '</li>'; }).join('') + '</ul>' +
      (mode === 'shiny' ? '<button type="button">Send to the server</button>' : '') + '</div>';
    var btn = root.querySelector('button');
    if (btn) btn.addEventListener('click', function () {
      if (window.Shiny && window.Shiny.setInputValue) window.Shiny.setInputValue(root.id + '_msg', { kind: 'hello', at: Date.now() }, { priority: 'event' });
    });
    root.setAttribute('data-ready', '1');
  }
  function boot() { [].forEach.call(document.querySelectorAll('[data-mode].hello'), mount); }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else boot();
})();
