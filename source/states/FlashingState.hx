package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.effects.FlxFlicker;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.addons.transition.FlxTransitionableState;
import lime.app.Application;

class FlashingState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var warnText:FlxText;

	override function create()
	{
		super.create();
		leftState = false;

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		var guh:String;

		if (controls.mobileC)
		{
			guh = "Hey, watch out!\nThis Engine contains some flashing lights!\nPress A to disable them now or go to Options Menu.\nPress B to ignore this message.\nYou've been warned!";
		}
		else
		{
			guh = "Hey, watch out!\nThis Engine contains some flashing lights!\nPress ENTER to disable them now or go to Options Menu.\nPress ESCAPE to ignore this message.\nYou've been warned!";
		}

		controls.isInSubstate = false;

		warnText = new FlxText(0, 0, FlxG.width, guh, 32);
		warnText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		add(warnText);

		#if mobile
		addTouchPad("NONE", "A_B");
		#end
	}

	override function update(elapsed:Float)
	{
		if (!leftState)
		{
			var back:Bool = controls.BACK;
			if (controls.ACCEPT || back)
			{
				leftState = true;
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;

				if (!back)
				{
					ClientPrefs.data.flashing = false;
					ClientPrefs.saveSettings();
					FlxG.sound.play(Paths.sound('confirmMenu'));

					FlxFlicker.flicker(warnText, 1, 0.1, false, true, function(flk:FlxFlicker)
					{
						new FlxTimer().start(0.5, function(tmr:FlxTimer)
						{
							MusicBeatState.switchState(new TitleState());
						});
					});
				}
				else
				{
					FlxG.sound.play(Paths.sound('cancelMenu'));
					FlxTween.tween(warnText, {alpha: 0}, 1, {
						onComplete: function(twn:FlxTween)
						{
							MusicBeatState.switchState(new BetaState());
						}
					});
				}
			}
		}
		super.update(elapsed);
	}
}
