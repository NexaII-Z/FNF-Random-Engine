package states.stages.objects;

import flixel.text.FlxText;

/**
 * Weekend 1 helpers.
 *
 * Flip these two switches if you want the extras back once the stage shows up:
 *   USE_VIDEOS      - play darnellCutscene / 2hotCutscene / blazinCutscene .mp4 files in story mode
 *   USE_RAIN_SHADER - the rain/lighting camera shader (heavy, can fail to compile on some mobile GPUs)
 */
class W1Util
{
	public static var USE_VIDEOS:Bool = false;
	public static var USE_RAIN_SHADER:Bool = false;

	/** Points the asset lookup at assets/week_assets/weekend1 (falls back to assets/weekend1, then assets/shared). */
	public static function useWeekendFolder()
	{
		Paths.setCurrentLevel('weekend1');
	}

	/** Loads every image up front (without GPU upload) and returns the ones that could not be found/decoded. */
	public static function checkImages(keys:Array<String>):Array<String>
	{
		var missing:Array<String> = [];
		for (key in keys)
		{
			var graphic:Dynamic = null;
			try { graphic = Paths.image(key, null, false); }
			catch(e:Dynamic) { graphic = null; }
			if(graphic == null) missing.push(key);
		}
		return missing;
	}

	/** Puts a red warning on screen (and in the log) listing the files the stage could not load. */
	public static function reportMissing(missing:Array<String>)
	{
		if(missing == null || missing.length < 1) return;

		var msg:String = 'WEEKEND 1: ' + missing.length + ' image(s) failed to load:\n' + missing.join('\n');
		trace(msg);

		var txt:FlxText = new FlxText(20, 20, FlxG.width - 40, msg, 20);
		txt.setFormat(Paths.font('vcr.ttf'), 20, FlxColor.RED, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		txt.scrollFactor.set();
		txt.cameras = [PlayState.instance.camOther];
		PlayState.instance.add(txt);

		FlxTween.tween(txt, {alpha: 0}, 1, {startDelay: 15, onComplete: function(_) { PlayState.instance.remove(txt); txt.destroy(); }});
	}
}
