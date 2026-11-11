/* DirectoR teaser: 30 s, 120 BPM (beat = 0.5 s), for QuantSkill's stage engine (dev/video/stage/stage.js).
   Cut to the form of QuantSkill's teaser score (music.py teaser()): filtered intro 0-4, drop at 4,
   whooshes at 7.5 / 9.5 / 14 / 22, break 18-20, lift 20-26, final hit at 26.
   Colours: DirectoR's own tokens (director.css --a1 #6366f1, --a2 #a855f7, --a3 #ec4899, --grad). */
(function () {
  'use strict';
  var S = Stage, E = S.E, prog = S.prog, el = S.el;
  var FPS = 60;
  window.DURATION = 30;
  var MK = window.MARKS || {};
  function M(shot, name, dflt) { var m = MK[shot] || {}; return m[name] != null ? m[name] / FPS : (dflt || 0); }

  /* DirectoR's gradient for type (stage.css stays QuantSkill's; this adds one class) */
  var st = document.createElement('style');
  st.textContent = '.dgrad{background:linear-gradient(120deg,#6366f1 0%,#a855f7 48%,#ec4899 100%);-webkit-background-clip:text;background-clip:text;color:transparent;padding:0 .04em .08em;margin:0 -.04em -.08em}'
    + '.pill.dr{background:rgba(12,12,17,.86);border:1px solid rgba(168,85,247,.35);box-shadow:0 20px 60px -10px rgba(168,85,247,.45)}'
    + '.mono{font-family:"SF Mono","JetBrains Mono",ui-monospace,Menlo,monospace;letter-spacing:0}';
  document.head.appendChild(st);

  /* backdrop: DirectoR's near-black with its three glows */
  S.bg({ t0: 0, t1: 30, theme: 'dark', glows: [
    { c: 'rgba(99,102,241,.55)', x: 300, y: 180, s: 1.1, o: .55, ph: 0 },
    { c: 'rgba(168,85,247,.5)', x: 1620, y: 260, s: 1.0, o: .5, ph: 2 },
    { c: 'rgba(236,72,153,.32)', x: 1000, y: 1020, s: 1.2, o: .42, ph: 4 }] });

  function pill(t0, t1, txt, y) {
    return S.custom({ t0: t0, t1: t1, z: 80, build: function (e) { var p = el('div', 'pill dr', txt); p.style.top = (y || 930) + 'px'; e.appendChild(p); },
      update: function (e, lt) { var q = prog(lt, 0, 0.35, 'out5'), o = 1 - prog(lt, t1 - t0 - 0.15, t1 - t0, 'in');
        e.firstChild.style.transform = 'translateX(-50%) translateY(' + ((1 - q) * 30) + 'px) scale(' + (0.94 + 0.06 * q) + ')'; e.style.opacity = q * o; } });
  }
  function cut(shot, t0, t1, o) {
    o = o || {};
    var pose = o.pose || [[0, { s: 1.045, o: 1 }], [0.35, { s: 1, o: 1 }, 'out5']];
    return S.clip({ shot: shot, t0: t0, t1: t1, mode: o.mode || 'window', w: o.mode === 'full' ? 1920 : (o.w || 1560), speed: o.speed || 1,
      from: (o.from || 0) * FPS, url: '<b>DirectoR</b>&nbsp;&nbsp;127.0.0.1:3838', cam: o.cam, pose: pose, fadeIn: o.fadeIn, fadeOut: o.fadeOut, z: o.z, dark: true });
  }

  /* ------------------------------------------------ 0-4  "Your app deserves a launch film." (DirectoR's own headline) */
  S.text({ t0: 0, t1: 3.98, size: 'xl', cls: 'on-dark', lines: [[['Your ', ''], ['app ', ''], ['deserves', '']], [['a ', ''], ['launch ', 'dgrad'], ['film.', 'dgrad']]],
    times: [0.02, 0.5, 1.0, 2.0, 2.5, 3.0], anim: 'slam', dur: 0.3, out: 'scale', outDur: 0.22 });
  S.punch([0.02, 0.5, 1.0, 2.0, 2.5, 3.0], 0.016, 0.3);

  /* ------------------------------------------------ 4-7.5  paste a folder, Create film */
  S.flash(4.0, 0.35, '#fff', 0.85); S.punch([4.0], 0.05, 0.5);
  var focus = M('lib', 'focus', 1.4);
  cut('lib', 4.0, 7.5, { from: focus - 0.55, speed: 1.2,
    pose: [[0, { s: .84, y: 150, rx: 22, o: 1 }], [1.1, { s: 1, y: 0, rx: 0 }, 'out5'], [3.5, { s: 1.03, y: 0, rx: 0 }, 'lin']],
    cam: [[0, { s: 1.0, x: .5, y: .5 }], [1.2, { s: 1.32, x: .52, y: .58 }, 'io'], [3.5, { s: 1.38, x: .6, y: .6 }, 'io']] });
  pill(5.2, 7.4, 'Paste a link. Or a folder. Or a zip.', 960);

  /* ------------------------------------------------ 7.5-9.5  autopilot */
  cut('auto', 7.5, 9.5, { from: 0.2, speed: 2.3, mode: 'full', cam: [[0, { s: 1.3, x: .5, y: .52 }], [2, { s: 1.42, x: .5, y: .52 }, 'io']] });
  pill(7.65, 9.5, 'Direct it for me.');

  /* ------------------------------------------------ 9.5-11.5  the scout */
  cut('source', 9.5, 11.5, { from: 0.3, speed: 1.4, mode: 'full', cam: [[0, { s: 1.18, x: .35, y: .5 }], [2, { s: 1.3, x: .35, y: .62 }, 'io']] });
  pill(9.65, 11.5, 'It scouts your app.');

  /* ------------------------------------------------ 11.5-14  the story and its live preview */
  var play = M('story', 'play', 1.2);
  cut('story', 11.5, 14.0, { from: play - 0.25, speed: 1.0, w: 1600,
    pose: [[0, { s: .92, ry: -12, x: 40 }], [0.6, { s: .97, ry: -5, x: 0 }, 'out5'], [2.5, { s: 1, ry: 0 }, 'lin']],
    cam: [[0, { s: 1.0, x: .5, y: .5 }], [0.8, { s: 1.42, x: .74, y: .48 }, 'io'], [2.5, { s: 1.5, x: .74, y: .48 }, 'lin']] });
  pill(11.65, 14.0, 'Writes the script. Previews it live.');

  /* ------------------------------------------------ 14-16  real footage */
  cut('shots', 14.0, 16.0, { from: M('shots', 'sweep', 1.0) - 0.2, speed: 1.2, mode: 'full', cam: [[0, { s: 1.35, x: .32, y: .42 }], [2, { s: 1.45, x: .32, y: .42 }, 'lin']] });
  pill(14.15, 16.0, 'Records real footage. 60 fps.');

  /* ------------------------------------------------ 16-18  score */
  cut('sound', 16.0, 18.0, { from: M('sound', 'mood', 1.0) - 0.7, speed: 1.2, mode: 'full', cam: [[0, { s: 1.3, x: .72, y: .5 }], [2, { s: 1.42, x: .72, y: .5 }, 'lin']] });
  pill(16.15, 17.95, 'Scores it. Original music.');

  /* ------------------------------------------------ 18-20  break */
  S.text({ t0: 18.0, t1: 19.98, size: 'lg', cls: 'on-dark', y: 500, lines: [[['Under ', 'muted'], ['60 seconds.', 'dgrad']]],
    times: [18.02, 18.5], anim: 'rise', dur: 0.45, out: 'up', outDur: 0.25 });
  S.text({ t0: 18.9, t1: 19.98, size: 'sm', cls: 'on-dark', y: 660, lines: [[['Launch \u00b7 Teaser \u00b7 Feature tour \u00b7 Social \u00b7 Calm demo', 'muted']]], stagger: 0.04, dur: 0.35, out: 'up', outDur: 0.2 });

  /* ------------------------------------------------ 20-22  the look */
  cut('look', 20.0, 22.0, { from: M('look', 'bg', 1.0) - 0.6, speed: 1.3, w: 1560,
    pose: [[0, { s: .9, ry: 14, x: -40 }], [0.6, { s: .96, ry: 5, x: 0 }, 'out5'], [2, { s: 1, ry: 0 }, 'lin']] });
  pill(20.15, 22.0, '16:9 \u00b7 9:16 \u00b7 1:1 \u00b7 4:5. Any look.');

  /* ------------------------------------------------ 22-24  render */
  cut('export', 22.0, 24.0, { from: M('export', 'render', 1.0) - 0.35, speed: 1.75, mode: 'full', cam: [[0, { s: 1.15, x: .62, y: .6 }], [2, { s: 1.28, x: .75, y: .78 }, 'io']] });
  pill(22.15, 24.0, 'MP4, captions, SRT, poster.');

  /* ------------------------------------------------ 24-26  what it can film */
  S.text({ t0: 24.0, t1: 25.98, size: 'lg', cls: 'on-dark', lines: [[['Shiny', ''], ['  \u00b7  ', 'muted'], ['Streamlit', ''], ['  \u00b7  ', 'muted'], ['Quarto', '']], [['Any ', ''], ['website.', 'dgrad']]],
    times: [24.0, 24.25, 24.5, 24.75, 25.0, 25.3, 25.5], anim: 'slam', dur: 0.2, out: 'fade', outDur: 0.12 });
  S.punch([24.0, 24.5, 25.0, 25.5], 0.018, 0.25);

  /* ------------------------------------------------ 26-30  end card */
  var LOGO = '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8.5h16v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z"/><path d="m4 8.5 1.2-4a1.5 1.5 0 0 1 1.8-1l12.6 3.6-1.1 3.9"/><path d="m8.6 4.4 2.6 4M13.6 5.8l2.6 4"/><path d="m10.5 12.5 4 2.25-4 2.25z" fill="#fff"/></svg>';
  S.custom({ t0: 26.0, t1: 30, z: 70, build: function (e) {
    var lg = el('div', 'logo', LOGO); lg.style.position = 'absolute'; lg.style.left = '885px'; lg.style.top = '250px';
    lg.style.background = 'linear-gradient(120deg,#6366f1 0%,#a855f7 48%,#ec4899 100%)'; lg.style.boxShadow = '0 30px 80px -20px rgba(168,85,247,.7)'; e.appendChild(lg);
  }, update: function (e, lt) {
    var lg = e.firstChild, q = prog(lt, 0, 0.7, 'back');
    lg.style.transform = 'scale(' + (0.3 + 0.7 * q) + ') rotate(' + ((1 - q) * -25) + 'deg)';
    lg.style.opacity = Math.min(1, lt * 5) * (1 - prog(lt, 3.4, 4, 'in'));
  } });
  S.text({ t0: 26.25, t1: 30, size: 'xl', cls: 'on-dark', y: 540, lines: [[['DirectoR', '']]], by: 'char', stagger: 0.035, dur: 0.5, out: 'fade', outDur: 0.6 });
  S.text({ t0: 26.9, t1: 30, size: 'md', cls: 'on-dark', y: 690, lines: [[['Launch films ', 'dgrad'], ['for your apps.', '']]], stagger: 0.12, dur: 0.6, out: 'fade', outDur: 0.6 });
  S.text({ t0: 27.6, t1: 30, size: 'eyebrow', cls: 'muted', y: 800, lines: [[['Paste a link. Get a film.   \u00b7   ', ''], ['DirectoR::run_app()', 'mono']]], stagger: 0.02, dur: 0.5, anim: 'blur', out: 'fade', outDur: 0.6 });
  S.flash(26.0, 0.4, '#fff', 0.3);
  S.punch([26.0], 0.04, 0.6);
})();
