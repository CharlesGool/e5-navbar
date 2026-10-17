'use strict';
'require view';
'require form';
'require uci';

// LuCI 服务 -> 信息屏应用 -> 底部导航, for the navbar app (its menu file points the
// tab here): the bar's setting itself -- all nine pages, or the five chosen
// below (the screen's own nav_slot1..5) -- read and saved as uci, the same
// option as the screen's 高级 setting.  The screen follows within 30 s (it asks
// the app's GET /mode); a change on the screen itself applies at once.

var NAMES = ['概览', '信号', '流量', '短信', '热点', '设备', '详细信息', '设置', '应用'];

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('e5-plugin-navbar').catch(function() { return null; }),
			uci.load('e5-infoscreen')
		]);
	},

	render: function() {
		if (!uci.get('e5-plugin-navbar', 'settings'))
			uci.add('e5-plugin-navbar', 'settings', 'settings');
		var all = (uci.get('e5-plugin-navbar', 'settings', 'mode') || 'all') != 'five';

		var mode = new form.Map('e5-plugin-navbar', '底部导航',
			'信息屏底部的导航按钮。和屏幕上 高级 → 界面与锁屏 → 底部导航显示 是同一个设置。');
		var s = mode.section(form.NamedSection, 'settings', 'settings');
		s.addremove = false;
		var o = s.option(form.ListValue, 'mode', '底部导航显示');
		o.value('all', '全部 9 个页面（概览、信号、流量、短信、热点、设备、详细信息、设置、应用）');
		o.value('five', '5 个（下面选择的入口）');
		o.default = 'all';
		o.rmempty = false;

		var five = new form.Map('e5-infoscreen', '5 个入口',
			all ? '当前显示全部 9 个页面，下面的设置在选择“5 个”之后才生效。'
			    : '从左到右选择五个入口；顶部菜单仍可访问全部页面。');
		var t = five.section(form.NamedSection, 'main', 'infoscreen');
		t.addremove = false;
		var defaults = ['0', '1', '2', '3', '7'];
		for (var i = 1; i <= 5; i++) {
			var p = t.option(form.ListValue, 'nav_slot' + i, '底部入口 ' + i);
			NAMES.forEach(function(name, index) { p.value(String(index), name); });
			p.default = defaults[i - 1];
			p.rmempty = false;
		}

		return Promise.all([mode.render(), five.render()]).then(function(nodes) {
			return E([], nodes);
		});
	}
});
