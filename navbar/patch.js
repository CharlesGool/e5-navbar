    /* BEGIN e5-navbar (the navbar app, /etc/e5-infoscreen/plugins/navbar) */
    // All nine pages in the bottom bar instead of the five nav_slot ones, as
    // the navbar app's GET /mode says ({all: true}): asked when the bar is
    // built and every 30 s (navigation() runs only on a settings change), the
    // bar rebuilt when the answer changes.  Without the app: the five again.
    let navbarAll = false, navbarAt = -Infinity;
    function e5NavbarAll() {
        if (performance.now() - navbarAt > 25000) {
            navbarAt = performance.now();
            fetch('/api/plugins/navbar/mode', { cache: 'no-store' })
                .then((r) => r.ok ? r.json() : null)
                .then((r) => {
                    const all = !!(r && r.all);
                    if (all !== navbarAll) { navbarAll = all; navKey = ''; navigation(); }
                })
                .catch(() => {});
        }
        return navbarAll;
    }
    setInterval(e5NavbarAll, 30000);
    // nine to a row: a little less room around each button and its label
    (function () {
        const style = document.createElement('style');
        style.textContent =
            'body.nav-all #mobile-nav{gap:1px;padding-left:2px;padding-right:2px}' +
            'body.nav-all #mobile-nav button{border-radius:8px}' +
            'body.nav-all #mobile-nav button svg{width:19px;height:19px}' +
            'body.nav-all #mobile-nav button span{font-size:calc(9px * var(--ui-scale, 1));white-space:nowrap;overflow:hidden;max-width:100%}';
        document.head.appendChild(style);
    })();
    /* END e5-navbar */
