package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;

class OutdatedState extends MusicBeatState
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
			guh = "Sup bro, looks like you're running an outdated version of Psych Engine (" + MainMenuState.psychEngineVersion + "),\nplease update to " + TitleState.updateVersion + "!\nPress B to proceed anyway.\n\nThank you for using the Port!";
		}
		else
		{
			guh = "Sup bro, looks like you're running an outdated version of Psych Engine (" + MainMenuState.psychEngineVersion + "),\nplease update to " + TitleState.updateVersion + "!\nPress ESCAPE to proceed anyway.\n\nThank you for using the Port!";
		}

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
			if (controls.ACCEPT)
			{
				leftState = true;
				CoolUtil.browserLoad("https://github.com/AliAlafandy/FNF-PsychEngine-0.7.3-Template/releases");
			}
			else if (controls.BACK)
			{
				leftState = true;
			}

			if (leftState)
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
		super.update(elapsed);
	}
}
