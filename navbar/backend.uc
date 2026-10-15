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
			}
			return { notifications: [] };
		}
	};
};
