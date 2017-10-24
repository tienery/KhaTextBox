package;

import textbox.TextBox;

import kha.Assets;
import kha.Color;
import kha.Framebuffer;
import kha.Scheduler;
import kha.System;

class Main {
	static var textBox;

	public static function main() {
		System.init({title: "TextBox", width: 1024, height: 768}, function () {
			Assets.loadEverything(function () {
				textBox = new TextBox(50, 50, 400, 400, Assets.fonts.LiberationSans_Regular, 24);
				textBox.border = 3;
				textBox.multiline = false;
				textBox.wordWrap = false;
				textBox.usePassword = true;
				textBox.useTextHighlight = true;
				textBox.changeScrollBarColors(Color.fromFloats(0, .3, 0), Color.fromFloats(0, .6, 0), Color.fromFloats(0, .7, 0), Color.fromFloats(0, .5, 0));

				System.notifyOnRender(render);
				Scheduler.addTimeTask(textBox.update, 0, 1 / 60);
			});
		});
	}

	static function render(framebuffer: Framebuffer): Void {
		var g = framebuffer.g2;
		g.begin(true, Color.fromValue(0x333333));
		textBox.render(g);
		g.end();
	}
}
