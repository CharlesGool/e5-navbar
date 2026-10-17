// 底部导航 (Bottom Bar, id navbar): all nine pages in the screen's bottom bar
// instead of five.  The bar is built by the screen's own mobile.js
// (navigation(): the five nav_slot pages), so this patches mobile.js with
// patch.js: navigation() then asks GET /mode and shows all nine when it says
// so; while it does, the screen's own 高级 -> 底部导航 (the five) is left out of
// the 高级 list (patch.js, in the page: settings.uc is not changed).  An image
// update brings an unpatched mobile.js: the notification poll
// patches it again, and the screen restarts once after each patch.  With the
// app removed, /mode is gone and the bar has its five again.
//
// LuCI's tab 服务 -> 信息屏应用 -> 底部导航 (the five) is pointed at this app's
// page (luci/navigation.js): with the app it says the five do nothing, the
// five one click away.  Only files of its own are added (luci/menu.json as
// menu.d/luci-app-zz-e5-navbar.json: LuCI reads menu.d in name order and the
// screen's luci-app-t551m-screen.json sets that tab, so this name comes
// after it); the screen's own page stays as it is, and the page shows it
// again when the app is gone.
//
//   GET  /mode            {all}, for the patched mobile.js
//   GET  /status          the setting and the patch
//   POST /mode            {"all": true|false}
//   POST /unpatch         mobile.js as it came, the screen restarted
//   GET  /notifications   (none: only the patch check, once a minute)

'use strict';

import { readfile, writefile, rename, stat } from 'fs';

const DIR = '/etc/e5-infoscreen/plugins/navbar';
const JS = '/usr/share/e5-infoscreen/www/mobile.js';
const CFG = 'e5-plugin-navbar';
const BLOCK_AT = '    function navigation() {';
const ITEMS_OLD = '        const items = navDefaults.map((fallback, i) => {';
const ITEMS_NEW = '        let items = navDefaults.map((fallback, i) => {';
const KEY_OLD = "        const key = items.join(',');";
const KEY_NEW = "        const navAll = e5NavbarAll();\n" +
	"        if (navAll) items = [0, 1, 2, 3, 4, 5, 6, 7, 8];\n" +
	"        document.body.classList.toggle('nav-all', navAll);\n" +
	"        const key = items.join(',');";
const LUCI = [
	[ 'luci/navigation.js', '/www/luci-static/resources/view/e5-navbar/navigation.js' ],
	[ 'luci/menu.json', '/usr/share/luci/menu.d/luci-app-zz-e5-navbar.json' ],
	[ 'luci/acl.json', '/usr/share/rpcd/acl.d/luci-app-e5-navbar.json' ]
];
const BEGIN = '    /* BEGIN e5-navbar';
const END = '    /* END e5-navbar */\n';

return function(ctx) {
	function count(s, part) { return length(split(s, part)) - 1; }

	function setting() {
		return (ctx.uci().get(CFG, 'settings', 'mode') ?? 'all') != 'five';
	}

	// mobile.js without our block and lines
	function strip(src) {
		let b = index(src, BEGIN), e = index(src, END);
		if (b < 0 || e < b) return null;
		src = substr(src, 0, b) + substr(src, e + length(END));
		src = join(ITEMS_OLD, split(src, ITEMS_NEW));
		return join(KEY_OLD, split(src, KEY_NEW));
	}

	function restart_screen() {
		// (detached: this request runs in the screen's own API server)
		ctx.run("setsid sh -c 'sleep 2; /etc/init.d/e5-infoscreen restart' >/dev/null 2>&1 &");
	}

	function write_js(src) {
		let tmp = JS + '.navbar-new';
		if (writefile(tmp, src) == null || !rename(tmp, JS)) {
			ctx.run(`rm -f '${tmp}'`);
			return false;
		}
		return true;
	}

	// the LuCI page and its menu file, as this version has them
	function luci_ensure() {
		let changed = false;
		for (let f in LUCI) {
			let want = readfile(`${DIR}/${f[0]}`);
			if (want == null || readfile(f[1]) == want) continue;
			ctx.run(`mkdir -p "$(dirname '${f[1]}')"`);
			writefile(f[1] + '.navbar-new', want);
			ctx.run(`chmod 644 '${f[1]}.navbar-new' && mv -f '${f[1]}.navbar-new' '${f[1]}'`);
			changed = true;
		}
		if (changed) {
			ctx.run('rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache; /etc/init.d/rpcd reload >/dev/null 2>&1');
			ctx.log('LuCI bottom bar tab: the navbar page');
		}
	}

	function luci_remove() {
		ctx.run(`rm -f '${LUCI[0][1]}' '${LUCI[1][1]}' '${LUCI[2][1]}'; rmdir /www/luci-static/resources/view/e5-navbar 2>/dev/null; ` +
			'rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache');
	}

	function patch_state() {
		let src = readfile(JS), want = readfile(`${DIR}/patch.js`);
		if (src == null || want == null) return { patched: false, error: 'missing mobile.js or patch.js' };
		if (index(src, want) >= 0 && index(src, KEY_NEW) >= 0) return { patched: true, current: true };
		if (index(src, BEGIN) >= 0) return { patched: true, current: false };
		let ok = count(src, BLOCK_AT) == 1 && count(src, ITEMS_OLD) == 1 && count(src, KEY_OLD) == 1;
		return { patched: false, patchable: ok, error: ok ? null : 'this screen version builds its bar differently' };
	}

	// mobile.js with this version of patch.js; the screen restarted when it changed
	function ensure_patch() {
		let src = readfile(JS), want = readfile(`${DIR}/patch.js`);
		if (src == null || want == null) return patch_state();
		if (index(src, want) >= 0 && index(src, KEY_NEW) >= 0) return { patched: true, current: true };
		if (index(src, BEGIN) >= 0) {
			src = strip(src);
			if (src == null) return { patched: false, error: 'cannot remove the older patch' };
		}
		if (count(src, BLOCK_AT) != 1 || count(src, ITEMS_OLD) != 1 || count(src, KEY_OLD) != 1)
			return { patched: false, error: 'this screen version builds its bar differently: not patched' };
		let parts = split(src, BLOCK_AT);
		src = parts[0] + want + BLOCK_AT + parts[1];
		src = join(ITEMS_NEW, split(src, ITEMS_OLD));
		src = join(KEY_NEW, split(src, KEY_OLD));
		if (!write_js(src))
			return { patched: false, error: 'cannot write mobile.js' };
		ctx.log('mobile.js patched (bottom bar), the screen restarts');
		restart_screen();
		return { patched: true, current: true, restarting: true };
	}

	return {
		'GET /mode': function(req) {
			return { all: setting() };
		},
		'GET /status': function(req) {
			let p = ctx.state_get('patch', 60);
			if (p == null) {
				p = ensure_patch();
				luci_ensure();
				ctx.state_put('patch', p);
			}
			return { all: setting(), patch: p };
		},
		'POST /mode': function(req) {
			let all = req.body?.all;
			if (type(all) != 'bool')
				return { status: 400, type: 'application/json', body: '{"error":"all: true or false"}' };
			if (!stat(`/etc/config/${CFG}`))
				writefile(`/etc/config/${CFG}`, '');
			let c = ctx.uci();
			if (c.get(CFG, 'settings') == null)
				c.set(CFG, 'settings', 'settings');
			c.set(CFG, 'settings', 'mode', all ? 'all' : 'five');
			c.commit(CFG);
			return { all: setting(), patch: patch_state() };
		},
		'POST /unpatch': function(req) {
			luci_remove();
			let src = readfile(JS);
			if (src == null || index(src, BEGIN) < 0)
				return { patched: false };
			src = strip(src);
			if (src == null || !write_js(src))
				return { status: 500, type: 'application/json', body: '{"error":"cannot restore mobile.js"}' };
			ctx.log('mobile.js restored (bottom bar), the screen restarts');
			restart_screen();
			ctx.forget('patch');
			return { patched: false, restarting: true };
		},
		'GET /notifications': function(req) {
			if (!ctx.state_get('checked', 60)) {
				ctx.state_put('checked', { at: time() });
				ensure_patch();
				luci_ensure();
			}
			return { notifications: [] };
		}
	};
};
