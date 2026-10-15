'use strict';
'require view';
'require form';
'require rpc';
'require ui';

// LuCI 服务 -> 信息屏应用 -> 底部导航, while the navbar app is installed (its
// menu file points the tab here; the screen's view/e5-infoscreen/navigation.js
// stays as it is).  With the app the bar shows all nine pages in their order
// and the five entries set here do nothing: that is said first, the five
// stay one click away for the app's "5 个（原样）" setting.  Without the app
// (its files left behind): the screen's page as it was.

var callList = rpc.declare({ object: 'e5-infoscreen', method: 'list', expect: { apps: [] } });

// the screen's own page (view/e5-infoscreen/navigation.js, firmware 1.6.7)
function fiveForm() {
	var m = new form.Map('e5-infoscreen', '底部导航', '从左到右选择五个入口，保存后屏幕自动更新。顶部菜单仍可访问全部页面。');
	var s = m.section(form.NamedSection, 'main', 'infoscreen');
	s.addremove = false;
	var names = ['概览','信号','流量','短信','热点','设备','详细信息','设置','应用'];
	var defaults = ['0','1','2','3','7'];
	for (var i = 1; i <= 5; i++) {
		var o = s.option(form.ListValue, 'nav_slot' + i, '底部入口 ' + i);
		names.forEach(function(name, index) { o.value(String(index), name); });
		o.default = defaults[i-1];
		o.rmempty = false;
	}
	return m.render();
}

return view.extend({
	load: function() {
		return L.resolveDefault(callList(), []).then(function(r) {
			var apps = Array.isArray(r) ? r : ((r && r.apps) || []);
			return apps.filter(function(a) { return a.id == 'navbar'; })[0] || null;
		});
	},

	render: function(app) {
		if (!app)
			return fiveForm();

		return fiveForm().then(function(five) {
			var box = E('div', { 'style': 'display:none' }, five);
			var toggle = E('button', {
				'class': 'btn cbi-button',
				'click': function() {
					var shown = box.style.display != 'none';
					box.style.display = shown ? 'none' : '';
					toggle.textContent = shown ? '仍然设置 5 个入口…' : '收起';
				}
			}, '仍然设置 5 个入口…');

			return E([], [
				E('h2', '底部导航'),
				E('div', { 'class': 'cbi-section' }, [
					E('div', { 'class': 'alert-message notice' }, [
						E('h4', '已由“底部导航”应用接管（版本 ' + (app.version || '?') + '）'),
						E('p', '信息屏底部显示全部 9 个页面，按固定顺序：概览、信号、流量、短信、热点、设备、详细信息、设置、应用，和左右键切换页面的顺序一致。' +
							'这里的“5 个入口”设置不适用（屏幕上 高级 里的同名设置这时也是隐藏的）。'),
						E('p', '只有在屏幕上把 高级 → 底部导航（应用设置）改成“5 个（原样）”，或者卸载这个应用之后，下面的 5 个入口才生效。')
					]),
					toggle
				]),
				box
			]);
		});
	}
});
