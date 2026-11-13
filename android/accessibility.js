/* Accessibility behavior for the offline Android shell. */
(function () {
  'use strict';
  var active = null;
  var bootstrapRequested = false;
  var restoreRequested = false;
  var applyBootstrap = null;

  function bootstrapWhenReady() {
    if (bootstrapRequested && applyBootstrap && document.readyState === 'complete') applyBootstrap();
  }

  // Exposed synchronously for the native onPageFinished callback. An early call
  // waits for all feature setup; repeated callbacks cannot clear/replay state.
  window.__restoreNativeUiSession = function (restore) {
    if (typeof restore !== 'boolean') return false;
    if (!bootstrapRequested) {
      bootstrapRequested = true;
      restoreRequested = restore;
      bootstrapWhenReady();
    }
    return true;
  };
  window.addEventListener('load', bootstrapWhenReady, { once: true });

  // Loaded before main.js: let control/target handlers and the native default
  // run, but keep its document-level animation shortcut out of controls.
  document.addEventListener('keydown', function (event) {
    if (event.key === ' ' && event.target instanceof Element &&
        event.target.closest('button,a[href],input,select,textarea,[contenteditable]')) {
      event.stopImmediatePropagation();
    }
    // Background shortcut actions must not fire from a modal's controls.
    if (active && active.element.contains(event.target)) event.stopImmediatePropagation();
  });

  function setup() {
    var compact = window.matchMedia('(max-width: 768px)');
    var definitions = [
      ['sidebar', 'hamburgerBtn', 'sidebarCloseBtn'],
      ['equationsPanel', 'equationsBtn', 'equationsCloseBtn'],
      ['lessonsPanel', 'lessonsBtn', 'lessonsCloseBtn'],
      ['modal', 'infoBtn', 'modalCloseBtn']
    ];
    var panes = definitions.map(function (ids) {
      var element = document.getElementById(ids[0]);
      return element && {
        element: element,
        trigger: document.getElementById(ids[1]),
        close: document.getElementById(ids[2]),
        role: element.getAttribute('role'),
        modal: element.getAttribute('aria-modal'),
        visible: false
      };
    }).filter(Boolean);
    var order = [];
    var isolated = new Map();
    var initialized = false;
    var sessionReady = false;
    var replaying = false;
    var sessionKey = 'attractive-native-ui-session-v1';
    var scrollTargets = {
      sidebar: document.getElementById('sidebar'),
      equations: document.getElementById('equationsBody'),
      lessons: document.getElementById('lessonsBody'),
      about: document.querySelector('#modal .modal-content'),
      toolbar: document.querySelector('.floating-controls')
    };

    function setAttribute(element, name, value) {
      if (value === null) element.removeAttribute(name);
      else element.setAttribute(name, value);
    }

    function visible(pane) {
      var element = pane.element;
      if (element.id === 'sidebar') {
        return compact.matches ? element.classList.contains('open') : !element.classList.contains('collapsed');
      }
      return element.classList.contains(element.id === 'modal' ? 'active' : 'open');
    }

    function focus(element) {
      if (element && document.activeElement !== element) element.focus();
      var toolbar = element && element.closest('.floating-controls');
      if (toolbar) {
        // Resizing can reset this scrollport while a late action is inert.
        var left = element.offsetLeft;
        var right = left + element.offsetWidth;
        if (left < toolbar.scrollLeft) toolbar.scrollLeft = left;
        else if (right > toolbar.scrollLeft + toolbar.clientWidth) toolbar.scrollLeft = right - toolbar.clientWidth;
      }
    }

    function restoreBackground() {
      isolated.forEach(function (wasInert, element) { element.inert = wasInert; });
      isolated.clear();
    }

    function sync(resizing) {
      var previous = active;
      var previousFocus = document.activeElement;
      var opened = [];
      var closed = [];
      restoreBackground();
      panes.forEach(function (pane) {
        var now = visible(pane);
        if (now && !pane.visible) {
          order = order.filter(function (entry) { return entry !== pane; });
          order.push(pane);
          opened.push(pane);
        } else if (!now && pane.visible) {
          closed.push(pane);
        }
        pane.visible = now;
        pane.element.inert = !now;
        pane.element.setAttribute('aria-hidden', now ? 'false' : 'true');
      });
      order = order.filter(function (pane) { return pane.visible; });
      active = order.slice().reverse().find(function (pane) {
        return compact.matches || pane.element.id === 'modal';
      }) || null;
      panes.forEach(function (pane) {
        setAttribute(pane.element, 'role', pane === active ? 'dialog' : pane.role);
        setAttribute(pane.element, 'aria-modal', pane === active ? 'true' : pane.modal);
      });
      if (active) {
        Array.from(document.body.children).forEach(function (element) {
          if (element !== active.element && element.id !== 'liveAnnouncement') {
            isolated.set(element, element.inert);
            element.inert = true;
          }
        });
      }
      if (initialized && !replaying) {
        if (active && (active !== previous || opened.indexOf(active) !== -1)) {
          focus(active.close);
        } else if (!active && previous && !previous.visible) {
          focus(previous.element.id === 'sidebar' && !compact.matches
            ? document.getElementById('sidebarToggleBtn') : previous.trigger);
        } else if (!active && resizing && previous && previous.element.id === 'sidebar') {
          // Its compact Close control is display:none on the desktop layout.
          focus(document.getElementById('sidebarToggleBtn'));
        } else if (!active && !resizing && opened.length && opened[opened.length - 1].element.id !== 'sidebar') {
          focus(opened[opened.length - 1].close);
        } else if (!active && closed.some(function (pane) { return pane.element.contains(previousFocus); })) {
          var pane = closed[closed.length - 1];
          focus(pane.element.id === 'sidebar' && !compact.matches
            ? document.getElementById('sidebarToggleBtn') : pane.trigger);
        }
      }
      initialized = true;
      saveUiSession();
    }

    function sessionFocusTarget(id) {
      var element = typeof id === 'string' && id.length <= 128 && document.getElementById(id);
      if (!element || element.disabled || element.closest('[inert]') ||
          !element.getClientRects().length || getComputedStyle(element).visibility === 'hidden') return null;
      var inPane = panes.some(function (pane) { return pane.visible && pane.element.contains(element); });
      if (!inPane && !element.closest('.floating-controls')) return null;
      if (active && !active.element.contains(element)) return null;
      return element.tabIndex >= 0 ? element : null;
    }

    function saveUiSession() {
      if (!sessionReady || replaying) return;
      var scroll = {};
      Object.keys(scrollTargets).forEach(function (name) {
        var element = scrollTargets[name];
        if (element) scroll[name] = { top: element.scrollTop, left: element.scrollLeft };
      });
      var focused = document.activeElement;
      var snapshot = {
        version: 1,
        panels: order.filter(function (pane) {
          // The default desktop sidebar is not an explicitly opened cover menu.
          return pane.element.id !== 'sidebar' || pane.element.classList.contains('open');
        }).map(function (pane) { return pane.element.id; }),
        scroll: scroll,
        focus: focused && sessionFocusTarget(focused.id) ? focused.id : null
      };
      try { window.localStorage.setItem(sessionKey, JSON.stringify(snapshot)); }
      catch (_) { /* Storage may be disabled or full; the live UI still works. */ }
    }

    function readUiSession() {
      try {
        var raw = window.localStorage.getItem(sessionKey);
        if (!raw || raw.length > 4096) return null;
        var snapshot = JSON.parse(raw);
        if (!snapshot || snapshot.version !== 1 || !Array.isArray(snapshot.panels) ||
            snapshot.panels.length > panes.length ||
            new Set(snapshot.panels).size !== snapshot.panels.length ||
            !snapshot.panels.every(function (id) {
              return panes.some(function (pane) { return pane.element.id === id; });
            })) return null;
        return snapshot;
      } catch (_) { return null; }
    }

    function restoreScroll(snapshot) {
      if (!snapshot.scroll || typeof snapshot.scroll !== 'object') return;
      Object.keys(scrollTargets).forEach(function (name) {
        var element = scrollTargets[name];
        var position = snapshot.scroll[name];
        if (!element || !position) return;
        ['top', 'left'].forEach(function (axis) {
          var value = position[axis];
          if (typeof value === 'number' && Number.isFinite(value) && value >= 0 && value <= 1000000) {
            element[axis === 'top' ? 'scrollTop' : 'scrollLeft'] = value;
          }
        });
      });
    }

    applyBootstrap = function () {
      if (sessionReady) return;
      var snapshot = restoreRequested ? readUiSession() : null;
      replaying = true;
      if (!restoreRequested) {
        try { window.localStorage.removeItem(sessionKey); } catch (_) { /* Optional storage. */ }
      }
      if (snapshot) {
        snapshot.panels.forEach(function (id) {
          var pane = panes.find(function (entry) { return entry.element.id === id; });
          var alreadyOpen = pane && (id === 'sidebar'
            ? pane.element.classList.contains('open') : visible(pane));
          if (pane && pane.trigger && !alreadyOpen) {
            pane.trigger.click();
            sync(false);
          }
        });
        order = order.filter(function (pane) { return snapshot.panels.indexOf(pane.element.id) === -1; })
          .concat(snapshot.panels.map(function (id) {
            return panes.find(function (pane) { return pane.element.id === id; });
          }));
      }
      sync(false);
      if (snapshot) {
        restoreScroll(snapshot);
        var target = sessionFocusTarget(snapshot.focus);
        if (target) focus(target);
        else if (active) focus(active.close);
        else if (snapshot.panels.length) {
          var last = panes.find(function (pane) { return pane.element.id === snapshot.panels[snapshot.panels.length - 1]; });
          if (last && last.visible) focus(compact.matches || last.element.id !== 'sidebar'
            ? last.close : document.getElementById('sidebarToggleBtn'));
        }
      }
      replaying = false;
      sessionReady = true;
      saveUiSession();
    };

    function tabbable(pane) {
      return Array.from(pane.element.querySelectorAll('button,a[href],input,select,textarea,[tabindex]'))
        .filter(function (element) {
          return element.tabIndex >= 0 && !element.disabled && !element.closest('[inert]') &&
            element.getClientRects().length > 0 && getComputedStyle(element).visibility !== 'hidden';
        });
    }

    document.addEventListener('keydown', function (event) {
      if (!active) return;
      if (event.key === 'Escape') {
        event.preventDefault();
        event.stopImmediatePropagation();
        if (active.close) active.close.click();
      } else if (event.key === 'Tab') {
        var targets = tabbable(active);
        var index = targets.indexOf(document.activeElement);
        if (!targets.length) return;
        if (!active.element.contains(document.activeElement) ||
            (event.shiftKey && index <= 0) || (!event.shiftKey && index === targets.length - 1)) {
          event.preventDefault();
          event.stopImmediatePropagation();
          focus(event.shiftKey ? targets[targets.length - 1] : targets[0]);
        }
      }
    }, true);

    // Android Back closes the most recently opened pane before it leaves the app.
    // The always-present desktop sidebar is not something the person opened.
    // Returns false when nothing is open, so the shell can finish.
    window.__closeTopPaneForNativeBack = function () {
      var target = active || order.slice().reverse().find(function (pane) {
        return pane.element.id !== 'sidebar' || compact.matches;
      });
      if (!target || !target.visible || !target.close) return false;
      target.close.click();
      return true;
    };

    // Icons inside named buttons are decoration; without this TalkBack adds
    // "unlabelled graphic" after the name of the toggle buttons.
    Array.prototype.forEach.call(document.querySelectorAll('button svg'), function (icon) {
      icon.setAttribute('aria-hidden', 'true');
    });

    // The WebView scales text with the system font size. Mark large text so the
    // stylesheet can make room (compact-window.css), and track whether the
    // Lyapunov rows are showing for the lesson readout rule there.
    function markTextScale() {
      var probe = document.createElement('span');
      probe.style.cssText = 'position:absolute;visibility:hidden;font-size:10px';
      probe.textContent = 'x';
      document.body.appendChild(probe);
      var scale = parseFloat(getComputedStyle(probe).fontSize) / 10;
      probe.remove();
      document.body.classList.toggle('large-text', scale >= 1.5);
    }
    markTextScale();
    window.addEventListener('resize', markTextScale);
    var lyapunovRow = document.getElementById('lyapunovRow');
    function markLyapunov() {
      document.body.classList.toggle('no-lyapunov', !lyapunovRow || lyapunovRow.style.display === 'none');
    }
    markLyapunov();
    if (lyapunovRow) {
      new MutationObserver(markLyapunov).observe(lyapunovRow, { attributes: true, attributeFilter: ['style'] });
    }

    var stats = document.querySelector('.stats');
    if (stats) {
      stats.setAttribute('role', 'group');
      stats.setAttribute('aria-live', 'off');
    }
    var observer = new MutationObserver(function () { sync(false); });
    panes.forEach(function (pane) { observer.observe(pane.element, { attributes: true, attributeFilter: ['class'] }); });
    compact.addEventListener('change', function () { sync(true); });
    document.addEventListener('focusin', saveUiSession);
    document.addEventListener('scroll', saveUiSession, true);
    window.addEventListener('pagehide', saveUiSession);
    sync(false);
    bootstrapWhenReady();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', setup);
  else setup();
})();
