package states;

class OutdatedState extends MusicBeatState
{
	public static var leftState:Bool = false;

	var warnText:FlxText;
	override function create()
	{
		super.create();

		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);

		var guh:String;

		if (controls.mobileC)
		{
			guh = "Also, This Engine Is in Beta   \n
			Which Means You Will Find Some Bugs While Playing \n
        you can reort them in the Random Engine Github, Or Gamebanana Website
          Press A To Continue.";
		} else {
			guh = "Also, This Engine Is in Beta   \n
			Which Means You Will Find Some Bugs While Playing \n
        you can reort them in the Random Engine Github, Or Gamebanana Website
          Press Enter To Continue.";
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
		if(!leftState) {
			if (controls.ACCEPT)
			{

			if(leftState)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxTween.tween(warnText, {alpha: 0}, 1, {
					onComplete: function (twn:FlxTween) {
						MusicBeatState.switchState(new MainMenuState());
					}
				});
			}
		}
		super.update(elapsed);
	}
}
