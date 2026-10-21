'use strict';
'require view';
'require tyfza1.status as status';
'require tyfza1.ui as ui';

return view.extend({
	load: function() { return ui.snapshot(); },
	render: function(initial) {
		return ui.page('运行状态', '光链路、业务网络与无线，集中查看。接口连接不等于互联网可达。 · UI r2', initial, ui.snapshot, function(data) {
			var pon = data.pon || {}, optical = pon.optical || {}, bosa = pon.bosa || {},
				ddm = pon.transceiver || {};
			/* DDM scaling is kept local on purpose. Moving it into status.js would
			 * be cleaner, but a browser that still holds a cached status.js would
			 * then fail here with "Cannot read properties of undefined (reading
			 * 'power')" - a view renamed to bust the cache still pulls its
			 * dependencies from the cache. Local definitions make this file
			 * self-contained. */
			function ddmTemp(v){ if (v == null) return '未提供';
				var n = +v & 0xffff; if (n & 0x8000) n -= 0x10000;
				return (n / 256).toFixed(1) + ' °C'; }
			function ddmVolt(v){ return v == null ? '未提供' : (+v / 10000).toFixed(2) + ' V'; }
			function ddmBias(v){ return v == null ? '未提供' : (+v / 500).toFixed(2) + ' mA'; }
			function ddmPower(v){ return v == null || +v <= 0 ? '未提供' :
				(10 * Math.log10(+v / 10000)).toFixed(2) + ' dBm'; }
			/* Tiles carry only the readings you glance at to decide whether the line
			 * is healthy: receive/transmit power, module temperature, supply voltage
			 * and the two optical states. Bias current is a diagnostic - it only
			 * means something once a power reading looks wrong - so it sits in the
			 * fold below instead of widening the grid.
			 *
			 * The protocol is deliberately NOT repeated here: the state panel above
			 * already lists it under 运行协议, and the same value twice on one screen
			 * is noise, not emphasis. */
			return E('div', {}, [data.pon ? status.ponCard(pon) : E('p', { class: 'alert-message warning' }, 'PON 状态读取失败。'),
				ui.grid([
					ui.tile('接收光功率', ddmPower(ddm.rx_power_raw), '下行收光功率'),
					ui.tile('发送光功率', ddmPower(ddm.tx_power_raw), '上行发光功率'),
					ui.tile('温度', ddmTemp(ddm.temperature_raw), '光模块内部温度'),
					ui.tile('光口发射', optical.tx_disabled == null ? '未提供' : optical.tx_disabled === '1' ? '已关闭' : '已允许', '发送方向是否被关闭'),
					ui.tile('光学校准', bosa.configured == null ? '未提供' : bosa.configured === '1' ? '已配置' : '未就绪', '沿用原厂数据加载机制')
				]),
				ui.fold('光模块详情（电压 / 偏置 / 原始读数）', 'module', [
					status.rows([
						['供电电压', ddmVolt(ddm.voltage_raw)],
						['偏置电流', ddmBias(ddm.bias_raw)],
						['温度原始值', ddm.temperature_raw == null ? '未提供' : status.value(ddm.temperature_raw) + '（1/256 °C）'],
						['DDM 来源', ddm.temperature_raw == null ? '未提供，光模块未上报' : '光模块 A2 页（MSA SFF-8472）'],
						/* ff/ff/ff is what identify() reads from a module that does not
						 * implement the Semtech page-0x7f registers. Printing the raw
						 * bytes would look like a fault, so say what it means. */
						['模块识别', !bosa.identity || /^f{2}(\/f{2})*$/i.test(bosa.identity) ?
							'未识别（MSA 器件，不响应 Semtech 身份寄存器）' : bosa.identity],
						['校准方式', bosa.eeprom === '1' ? '模块自带 EEPROM' : '主机侧写入']
					])
				]),
				ui.grid([status.card('注册与认证', null, ui.authentication(pon)), status.offloadCard(pon)]),
				status.card('业务网络', null, [ui.networks(data), ui.link('管理上网', 'admin/onu/internet')]),
				status.card('无线网络', null, [data.wifiError ? ui.note('无线状态读取失败。') : data.wifi.length ? ui.grid(data.wifi.map(function(wifi) {
					return status.card(wifi.ssid || wifi.name, status.badge(wifi.up ? '运行中' : '未运行', wifi.up ? 'good' : 'muted'), status.rows([
						['接口', wifi.name], ['信道', status.value(wifi.channel)], ['频率', wifi.frequency ? wifi.frequency + ' GHz' : '—'],
						['当前 PHY 速率', wifi.bitrate ? wifi.bitrate + ' Mbit/s' : '—']
					]));
				})) : ui.note('未发现无线接口；请检查无线配置与校准加载状态。'), ui.link('管理 Wi-Fi 6', 'admin/network/wireless')]),
				ui.fold('物理端口与累计流量', 'ports', ui.ports(pon)),
				ui.fold('OLT 下发的 GEM 业务通道', 'paths', ui.services(pon)),
				ui.note((data.board.model || 'TYFZA1') + ' · ' + ((data.board.release || {}).description || '固件信息未提供'))
			]);
		});
	},
	handleSaveApply: null, handleSave: null, handleReset: null
});
