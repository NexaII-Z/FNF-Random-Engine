package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

class BetaState extends MusicBeatState
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
			guh = "Also, This Engine Is in Beta\nWhich Means You Will Find Some Bugs While Playing.\nYou can report them on the Random Engine Github or Gamebanana.\nPress A To Continue.";
		}
		else
		{
			guh = "Also, This Engine Is in Beta\nWhich Means You Will Find Some Bugs While Playing.\nYou can report them on the Random Engine Github or Gamebanana.\nPress Enter To Continue.";
		}

		warnText = new FlxText(0, 0, FlxG.width, guh, 32);
		warnText.setFormat("VCR OSD Mono", 32, FlxColor.WHITE, CENTER);
		warnText.screenCenter(Y);
		add(warnText);

		#if mobile
		addTouchPad("NONE", "A");
		#end
	}

	override function update(elapsed:Float)
	{
		if (!leftState)
		{
			if (controls.ACCEPT)
			{
				leftState = true;
				FlxG.sound.play(Paths.sound('confirmMenu'));
				FlxTween.tween(warnText, {alpha: 0}, 1, {
					onComplete: function(twn:FlxTween)
					{
						MusicBeatState.switchState(new TitleState());
					}
				});
			}
		}
		super.update(elapsed);
	}
}
