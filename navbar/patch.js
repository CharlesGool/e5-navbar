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
                    if (all !== navbarAll) {
                        navbarAll = all; navKey = ''; navigation();
                        // 高级, if already read: its 底部导航 out or back in
                        try {
                            if (typeof stCats != 'undefined' && Array.isArray(stCats)) {
                                e5NavbarCats(stCats);
                                if (stTop()?.view == 'menu') stRender();
                            }
                        } catch (e) {}
                    }
                })
                .catch(() => {});
        }
        return navbarAll;
    }
    setInterval(e5NavbarAll, 30000);
    // a setting changed on the screen (高级 or the app's page): asked again now,
    // and the bar rebuilt at once instead of within 30 s
    window.e5NavbarRefresh = function () { navbarAt = -Infinity; e5NavbarAll(); };
    // With all nine the screen's own 高级 -> 底部导航 (its five nav_slot ones,
    // category "navigation") sets nothing that shows: out of the 高级 list
    // while all nine show, back in its place with five.  The list as app.js
    // reads it (pageRead('/api/settings')), changed in place.
    let navbarHidden = null;
    function e5NavbarCats(cats) {
        try {
            const i = cats.findIndex((c) => c && c.id === 'navigation');
            if (navbarAll && i >= 0) {
                navbarHidden = { cat: cats[i], at: i };
                cats.splice(i, 1);
            } else if (!navbarAll && i < 0 && navbarHidden) {
                cats.splice(Math.min(navbarHidden.at, cats.length), 0, navbarHidden.cat);
                navbarHidden = null;
            }
        } catch (e) {}
        return cats;
    }
    // (app.js comes after this file: its pageRead is there once the page has loaded)
    window.addEventListener('DOMContentLoaded', () => {
        try {
            // (高级's save: the bar's setting -- navbar_mode where the system shows it,
            // mode in the app's own category -- rebuilds the bar now)
            const post = window.stPost;
            if (typeof post == 'function') window.stPost = async function (v, body) {
                const r = await post.apply(this, arguments);
                try {
                    const cat = v && v.cat && v.cat.id;
                    if (r && r.ok && body && (body.id === 'navbar_mode' || (cat === 'plugin:navbar' && body.id === 'mode')))
                        window.e5NavbarRefresh();
                } catch (e) {}
                return r;
            };
            const read = window.pageRead;
            if (typeof read != 'function') return;
            window.pageRead = function (path) {
                const p = read.apply(this, arguments);
                if (path !== '/api/settings') return p;
                return p.then((r) => {
                    if (r && Array.isArray(r.categories)) e5NavbarCats(r.categories);
                    return r;
                });
            };
        } catch (e) {}
    });
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
