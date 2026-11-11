/* Taiga bench: a minimal stand-in for shiny.js on the client.
   It lets the apps' own scripts register their input/output bindings and custom message handlers,
   injects server-rendered output HTML (produced by the apps' real renderUI code in webR) into the
   matching containers, and exposes window.bench so capture scripts can put the page in a state by
   calling the apps' *own* message handlers. It is not a Shiny client: there is no server. */
(function () {
  'use strict';
  var handlers = {}, inputs = [], outputBindings = [], inputBindings = [];
  function InputBinding() {}
  InputBinding.prototype = { find: function () { return []; }, getValue: function () {}, subscribe: function () {}, unsubscribe: function () {},
    receiveMessage: function () {}, getRatePolicy: function () { return null; }, getId: function (el) { return el.id; }, initialize: function () {} };
  function OutputBinding() {}
  OutputBinding.prototype = { find: function () { return []; }, renderValue: function () {}, renderError: function () {}, clearError: function () {},
    getId: function (el) { return el.id; }, onValueError: function () {}, showProgress: function () {} };
  window.Shiny = window.Shiny || {
    InputBinding: InputBinding, OutputBinding: OutputBinding, version: 'bench',
    inputBindings: { register: function (b, name) { inputBindings.push({ b: b, name: name }); }, setPriority: function () {} },
    outputBindings: { register: function (b, name) { outputBindings.push({ b: b, name: name }); } },
    addCustomMessageHandler: function (type, fn) { handlers[type] = fn; },
    setInputValue: function (name, value) { inputs.push({ name: name, value: value }); },
    onInputChange: function (name, value) { inputs.push({ name: name, value: value }); },
    bindAll: function () {}, unbindAll: function () {}, initializeInputs: function () {},
    shinyapp: { isConnected: function () { return true; }, $inputValues: {} },
    renderContent: function (el, content) { el.innerHTML = typeof content === 'string' ? content : (content.html || ''); },
    renderHtml: function (html, el) { el.innerHTML = html; }
  };
  function sliders(scope) {
    if (!window.jQuery || !jQuery.fn.ionRangeSlider) return;
    jQuery((scope || document).querySelectorAll('input.js-range-slider')).each(function () {
      if (!jQuery(this).data('ionRangeSlider')) jQuery(this).ionRangeSlider();
    });
  }
  window.bench = {
    handlers: handlers, inputs: inputs, outputBindings: outputBindings, inputBindings: inputBindings,
    /* inject server-rendered HTML into #id (like uiOutput) */
    fill: function (id, html) { var el = document.getElementById(id); if (!el) return false; el.innerHTML = html; sliders(el); return true; },
    /* load outputs/<state>/<id>.html for every shiny-html-output on the page */
    load: function (base) {
      return fetch(base + '/index.json').then(function (r) { return r.ok ? r.json() : null; }).catch(function () { return null; }).then(function (have) {
      var els = Array.prototype.slice.call(document.querySelectorAll('.shiny-html-output[id], .shiny-text-output[id]'))
        .filter(function (el) { return !have || have.indexOf(el.id) >= 0; });
      return Promise.all(els.map(function (el) {
        return fetch(base + '/' + el.id + '.html').then(function (r) { return r.ok ? r.text() : ''; }).then(function (h) { if (h.trim()) { el.innerHTML = h; sliders(el); } }).catch(function () {});
      })); });
    },
    send: function (type, msg) { if (!handlers[type]) throw new Error('no handler for ' + type); return handlers[type](msg); },
    /* bind the registered input bindings once (their find/subscribe), like Shiny does at start */
    bindInputs: function () {
      inputBindings.forEach(function (ib) { try { (ib.b.find(document) || []).forEach(function (el) { ib.b.subscribe(el, function () {}); }); } catch (e) { console.warn('bench: binding', ib.name, e); } });
    },
    sliders: sliders,
    /* show one pane of a hidden tabsetPanel */
    tab: function (tabsetId, value) {
      var ul = document.getElementById(tabsetId); if (!ul) return;
      var tsid = ul.getAttribute('data-tabsetid');
      document.querySelectorAll('.tab-content[data-tabsetid="' + tsid + '"] > .tab-pane').forEach(function (p) { p.classList.toggle('active', p.getAttribute('data-value') === value); p.classList.toggle('show', p.getAttribute('data-value') === value); });
      ul.querySelectorAll('a[data-value]').forEach(function (a) { a.classList.toggle('active', a.getAttribute('data-value') === value); a.parentNode.classList.toggle('active', a.getAttribute('data-value') === value); });
    }
  };
  document.addEventListener('DOMContentLoaded', function () { sliders(document); });
})();
