package objects;

/**
 * The glow that sits on a strum while a sustain note is being held.
 *
 * Atlases live in  images/noteHoldCovers/holdCover<Color>.png + .xml  (Purple, Blue, Green, Red)
 * and use these animation prefixes:
 *   holdCoverStart<Color>  plays once when the hold begins
 *   holdCover<Color>       loops while the note is held
 *   holdCoverEnd<Color>    plays once when the hold ends or is dropped
 *
 * PlayState owns one cover per lane and calls start() / stop().
 */
class NoteHoldCover extends FlxSprite
{
	public static final COLORS:Array<String> = ['Purple', 'Blue', 'Green', 'Red'];
	public static final FOLDER:String = 'noteHoldCovers/';
	static inline var FRAMERATE:Int = 24;

	public var lane(default, null):Int = 0;
	public var holding(default, null):Bool = false;
	public var usable(default, null):Bool = false;

	var target:StrumNote = null;

	public function new(lane:Int)
	{
		super();
		this.lane = lane;
		visible = false;
		antialiasing = ClientPrefs.data.antialiasing;

		var color:String = COLORS[lane % COLORS.length];
		var path:String = FOLDER + 'holdCover' + color;
		if (Paths.fileExists('images/$path.png', IMAGE))
		{
			frames = Paths.getSparrowAtlas(path);
			if (frames != null)
			{
				animation.addByPrefix('start', 'holdCoverStart' + color, FRAMERATE, false);
				animation.addByPrefix('loop', 'holdCover' + color, FRAMERATE, true);
				animation.addByPrefix('end', 'holdCoverEnd' + color, FRAMERATE, false);
				animation.finishCallback = onAnimationFinished;
				usable = animation.exists('loop');
			}
		}
		if (!usable) trace('Hold cover atlas missing or has no loop animation: images/$path');
	}

	public function start(strum:StrumNote):Void
	{
		if (!usable || strum == null) return;
		target = strum;
		if (holding) return;

		holding = true;
		visible = true;
		follow();
		animation.play(animation.exists('start') ? 'start' : 'loop', true);
	}

	public function stop():Void
	{
		if (!holding) return;
		holding = false;

		if (animation.exists('end')) animation.play('end', true);
		else visible = false;
	}

	function onAnimationFinished(name:String):Void
	{
		switch (name)
		{
			case 'start':
				if (holding) animation.play('loop', true);
			case 'end':
				visible = false;
		}
	}

	function follow():Void
	{
		if (target == null) return;
		x = target.x + target.width / 2 - width / 2;
		y = target.y + target.height / 2 - height / 2;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		if (visible) follow();
	}
}
