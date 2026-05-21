package objects;

import backend.animation.PsychAnimationController;
import backend.NoteTypesConfig;

import shaders.RGBPalette;
import shaders.RGBPalette.RGBShaderReference;

import objects.StrumNote;

import flixel.math.FlxRect;
import flixel.group.FlxSpriteGroup;

using StringTools;

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String
}

typedef NoteSplashData = {
	disabled:Bool,
	texture:String,
	useGlobalShader:Bool,
	useRGBShader:Bool,
	antialiasing:Bool,
	r:FlxColor,
	g:FlxColor,
	b:FlxColor,
	a:Float
}

// ─────────────────────────────────────────────────────────────────────────────
//  NoteHoldCover
//  Hold glow effect that plays over a sustain note while it is being held.
//  No RGB — the sprite sheet provides its own colors.
//
//  Atlas files go in:   shared/images/noteHoldCovers/
//    purple.png + purple.xml   (direction 0 – left)
//    blue.png   + blue.xml     (direction 1 – down)
//    green.png  + green.xml    (direction 2 – up)
//    red.png    + red.xml      (direction 3 – right)
//
//  Required animation prefixes inside each atlas:
//    holdCoverStart  → plays once when the hold begins
//    holdCover       → loops while the note is held
//    holdCoverEnd    → plays once when released / missed, then hides itself
// ─────────────────────────────────────────────────────────────────────────────
class NoteHoldCover extends FlxSpriteGroup
{
	static inline var FRAMERATE:Int      = 24;
	static inline var FOLDER:String      = 'noteHoldCovers/';
	static final DIR_NAMES:Array<String> = ['purple', 'blue', 'green', 'red'];

	public var glow:FlxSprite;
	public var holding:Bool = false;

	public function new(direction:Int = 0)
	{
		super(0, 0);

		glow = new FlxSprite();
		glow.antialiasing = ClientPrefs.data.antialiasing;

		var dirName   = DIR_NAMES[direction % DIR_NAMES.length];
		var atlasPath = FOLDER + dirName;

		if (Paths.fileExists('images/$atlasPath.png', IMAGE))
		{
			glow.frames = Paths.getSparrowAtlas(atlasPath);
			glow.animation.addByPrefix('holdStart', 'holdCoverStart', FRAMERATE, false);
			glow.animation.addByPrefix('holdLoop',  'holdCover',      FRAMERATE, true);
			glow.animation.addByPrefix('holdEnd',   'holdCoverEnd',   FRAMERATE, false);
			glow.animation.finishCallback = _onAnimFinished;
		}
		else
		{
			// Atlas missing — stay invisible so nothing crashes.
			glow.visible = false;
		}

		add(glow);
	}

	/** Call when the player first presses and starts holding. */
	public function playStart():Void
	{
		holding      = true;
		visible      = true;
		glow.visible = true;
		glow.setPosition(x, y);
		if (glow.animation.getByName('holdStart') != null)
			glow.animation.play('holdStart', true);
		else if (glow.animation.getByName('holdLoop') != null)
			glow.animation.play('holdLoop', true);
	}

	/** Call every frame while the note is still held (after start anim finishes). */
	public function playContinue():Void
	{
		if (glow.animation.curAnim != null
		 && glow.animation.curAnim.name == 'holdLoop') return; // already looping
		if (glow.animation.getByName('holdLoop') != null)
			glow.animation.play('holdLoop', true);
	}

	/** Call when the player releases or misses the sustain. */
	public function playEnd():Void
	{
		holding = false;
		if (glow.animation.getByName('holdEnd') != null)
			glow.animation.play('holdEnd', true);
		else
			kill(); // no end anim — just disappear
	}

	function _onAnimFinished(animName:String):Void
	{
		if (animName == 'holdStart')
			playContinue();
		else if (animName == 'holdEnd')
		{
			visible = false;
			kill();
		}
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		// Keep glow sprite synced to the group's position.
		glow.setPosition(x, y);
	}

	override function kill():Void
	{
		super.kill();
		visible      = false;
		holding      = false;
		if (glow != null) glow.visible = false;
	}

	override function revive():Void
	{
		super.revive();
		visible = true;
		if (glow != null) glow.visible = true;
	}
}

// ─────────────────────────────────────────────────────────────────────────────
//  Note
// ─────────────────────────────────────────────────────────────────────────────

/**
 * The note object used as a data structure to spawn and manage notes.
 *
 * Hold covers:
 *   When the player starts holding a sustain note, call:
 *     note.spawnHoldCover(yourLayerGroup);
 *   When the player releases or misses:
 *     note.killHoldCover();
 *   followStrumNote() syncs cover position automatically every frame.
 *
 * PlayState wiring (minimal additions needed):
 *
 *   1. Add a layer group in create() (renders above sustains, below splashes):
 *        var holdCoverLayer:FlxSpriteGroup;
 *        holdCoverLayer = new FlxSpriteGroup();
 *        add(holdCoverLayer);
 *
 *   2. In goodNoteHit(note):
 *        if (note.isSustainNote && note.mustPress && !note.tooLate)
 *            note.spawnHoldCover(holdCoverLayer);
 *
 *   3. In noteMiss(note) and key-release handler:
 *        if (note.isSustainNote) note.killHoldCover();
**/
class Note extends FlxSprite
{
	public var extraData:Map<String, Dynamic> = new Map<String, Dynamic>();

	public var strumTime:Float = 0;
	public var noteData:Int    = 0;

	public var mustPress:Bool  = false;
	public var canBeHit:Bool   = false;
	public var tooLate:Bool    = false;

	public var wasGoodHit:Bool = false;
	public var missed:Bool     = false;

	public var ignoreNote:Bool     = false;
	public var hitByOpponent:Bool  = false;
	public var noteWasHit:Bool     = false;
	public var prevNote:Note;
	public var nextNote:Note;

	public var spawned:Bool = false;

	public var tail:Array<Note> = []; // for sustains
	public var parent:Note;
	public var blockHit:Bool = false; // only works for player

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool  = false;
	public var noteType(default, set):String = null;

	public var eventName:String  = '';
	public var eventLength:Int   = 0;
	public var eventVal1:String  = '';
	public var eventVal2:String  = '';

	public var rgbShader:RGBShaderReference;
	public static var globalRgbShaders:Array<RGBPalette> = [];
	public var inEditor:Bool = false;

	public var animSuffix:String   = '';
	public var gfNote:Bool         = false;
	public var earlyHitMult:Float  = 1;
	public var lateHitMult:Float   = 1;
	public var lowPriority:Bool    = false;

	public static var SUSTAIN_SIZE:Int       = 44;
	public static var swagWidth:Float        = 160 * 0.7;
	public static var colArray:Array<String> = ['purple', 'blue', 'green', 'red'];
	public static var defaultNoteSkin(default, never):String = 'noteSkins/NOTE_assets';

	public var noteSplashData:NoteSplashData = {
		disabled:        false,
		texture:         null,
		antialiasing:    !PlayState.isPixelStage,
		useGlobalShader: false,
		useRGBShader:    (PlayState.SONG != null) ? !(PlayState.SONG.disableNoteRGB == true) : true,
		r: -1,
		g: -1,
		b: -1,
		a: ClientPrefs.data.splashAlpha
	};

	public var offsetX:Float     = 0;
	public var offsetY:Float     = 0;
	public var offsetAngle:Float = 0;
	public var multAlpha:Float   = 1;
	public var multSpeed(default, set):Float = 1;

	public var copyX:Bool     = true;
	public var copyY:Bool     = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;

	public var hitHealth:Float   = 0.023;
	public var missHealth:Float  = 0.0475;
	public var rating:String     = 'unknown';
	public var ratingMod:Float   = 0;
	public var ratingDisabled:Bool = false;

	public var texture(default, set):String = null;

	public var noAnimation:Bool    = false;
	public var noMissAnimation:Bool = false;
	public var hitCausesMiss:Bool  = false;
	public var distance:Float      = 2000;

	public var hitsoundDisabled:Bool    = false;
	public var hitsoundChartEditor:Bool = true;
	public var hitsound:String          = 'hitsound';

	// ── Hold cover ────────────────────────────────────────────────────────────
	/** The active hold-cover effect for this sustain note. */
	public var holdCover:NoteHoldCover = null;

	// ─────────────────────────────────────────────────────────────────────────

	private function set_multSpeed(value:Float):Float {
		resizeByRatio(value / multSpeed);
		multSpeed = value;
		return value;
	}

	public function resizeByRatio(ratio:Float)
	{
		if (isSustainNote && animation.curAnim != null && !animation.curAnim.name.endsWith('end'))
		{
			scale.y *= ratio;
			updateHitbox();
		}
	}

	private function set_texture(value:String):String {
		if (texture != value) reloadNote(value);
		texture = value;
		return value;
	}

	public function defaultRGB()
	{
		var arr:Array<FlxColor> = ClientPrefs.data.arrowRGB[noteData];
		if (PlayState.isPixelStage) arr = ClientPrefs.data.arrowRGBPixel[noteData];

		if (noteData > -1 && noteData <= arr.length)
		{
			rgbShader.r = arr[0];
			rgbShader.g = arr[1];
			rgbShader.b = arr[2];
		}
	}

	private function set_noteType(value:String):String {
		noteSplashData.texture = PlayState.SONG != null ? PlayState.SONG.splashSkin : 'noteSplashes';
		defaultRGB();

		if (noteData > -1 && noteType != value) {
			switch (value) {
				case 'Hurt Note':
					ignoreNote     = mustPress;
					rgbShader.r    = 0xFF101010;
					rgbShader.g    = 0xFFFF0000;
					rgbShader.b    = 0xFF990022;
					noteSplashData.r       = 0xFFFF0000;
					noteSplashData.g       = 0xFF101010;
					noteSplashData.texture = 'noteSplashes/noteSplashes-electric';
					lowPriority    = true;
					missHealth     = isSustainNote ? 0.25 : 0.1;
					hitCausesMiss  = true;
					hitsound       = 'cancelMenu';
					hitsoundChartEditor = false;
				case 'Alt Animation':
					animSuffix = '-alt';
				case 'No Animation':
					noAnimation    = true;
					noMissAnimation = true;
				case 'GF Sing':
					gfNote = true;
			}
			if (value != null && value.length > 1) NoteTypesConfig.applyNoteTypeData(this, value);
			if (hitsound != 'hitsound' && ClientPrefs.data.hitsoundVolume > 0)
				Paths.sound(hitsound);
			noteType = value;
		}
		return value;
	}

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note,
		?sustainNote:Bool = false, ?inEditor:Bool = false, ?createdFrom:Dynamic = null)
	{
		super();

		animation = new PsychAnimationController(this);

		antialiasing = ClientPrefs.data.antialiasing;
		if (createdFrom == null) createdFrom = PlayState.instance;

		if (prevNote == null) prevNote = this;

		this.prevNote     = prevNote;
		isSustainNote     = sustainNote;
		this.inEditor     = inEditor;
		this.moves        = false;

		x += (ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50;
		y -= 2000;
		this.strumTime = strumTime;
		if (!inEditor) this.strumTime += ClientPrefs.data.noteOffset;

		this.noteData = noteData;

		if (noteData > -1) {
			texture   = '';
			rgbShader = new RGBShaderReference(this, initializeGlobalRGBShader(noteData));
			if (PlayState.SONG != null && PlayState.SONG.disableNoteRGB) rgbShader.enabled = false;

			x += swagWidth * (noteData);
			if (!isSustainNote && noteData < colArray.length) {
				var animToPlay:String = '';
				animToPlay = colArray[noteData % colArray.length];
				animation.play(animToPlay + 'Scroll');
			}
		}

		if (prevNote != null)
			prevNote.nextNote = this;

		if (isSustainNote && prevNote != null)
		{
			alpha     = 0.6;
			multAlpha = 0.6;
			hitsoundDisabled = true;
			if (ClientPrefs.data.downScroll) flipY = true;

			offsetX += width / 2;
			copyAngle = false;

			animation.play(colArray[noteData % colArray.length] + 'holdend');
			updateHitbox();
			offsetX -= width / 2;

			if (PlayState.isPixelStage) offsetX += 30;

			if (prevNote.isSustainNote)
			{
				prevNote.animation.play(colArray[prevNote.noteData % colArray.length] + 'hold');
				prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.05;
				if (createdFrom != null && createdFrom.songSpeed != null)
					prevNote.scale.y *= createdFrom.songSpeed;

				if (PlayState.isPixelStage) {
					prevNote.scale.y *= 1.19;
					prevNote.scale.y *= (6 / height);
				}
				prevNote.updateHitbox();
			}

			if (PlayState.isPixelStage) {
				scale.y *= PlayState.daPixelZoom;
				updateHitbox();
			}
			earlyHitMult = 0;
		}
		else if (!isSustainNote)
		{
			centerOffsets();
			centerOrigin();
		}
		x += offsetX;
	}

	public static function initializeGlobalRGBShader(noteData:Int)
	{
		if (globalRgbShaders[noteData] == null)
		{
			var newRGB:RGBPalette = new RGBPalette();
			globalRgbShaders[noteData] = newRGB;

			var arr:Array<FlxColor> = (!PlayState.isPixelStage)
				? ClientPrefs.data.arrowRGB[noteData]
				: ClientPrefs.data.arrowRGBPixel[noteData];
			if (noteData > -1 && noteData <= arr.length)
			{
				newRGB.r = arr[0];
				newRGB.g = arr[1];
				newRGB.b = arr[2];
			}
		}
		return globalRgbShaders[noteData];
	}

	var _lastNoteOffX:Float = 0;
	static var _lastValidChecked:String;
	public var originalHeight:Float   = 6;
	public var correctionOffset:Float = 0;

	public function reloadNote(texture:String = '', postfix:String = '') {
		if (texture == null) texture = '';
		if (postfix == null) postfix = '';

		var skin:String = texture + postfix;
		if (texture.length < 1) {
			skin = PlayState.SONG != null ? PlayState.SONG.arrowSkin : null;
			if (skin == null || skin.length < 1)
				skin = defaultNoteSkin + postfix;
		}

		var animName:String = null;
		if (animation.curAnim != null) animName = animation.curAnim.name;

		var skinPixel:String   = skin;
		var lastScaleY:Float   = scale.y;
		var skinPostfix:String = getNoteSkinPostfix();
		var customSkin:String  = skin + skinPostfix;
		var path:String        = PlayState.isPixelStage ? 'pixelUI/' : '';
		if (customSkin == _lastValidChecked
		 || Paths.fileExists('images/' + path + customSkin + '.png', IMAGE))
		{
			skin              = customSkin;
			_lastValidChecked = customSkin;
		}
		else skinPostfix = '';

		if (PlayState.isPixelStage) {
			if (isSustainNote) {
				var graphic = Paths.image('pixelUI/' + skinPixel + 'ENDS' + skinPostfix);
				loadGraphic(graphic, true, Math.floor(graphic.width / 4), Math.floor(graphic.height / 2));
				originalHeight = graphic.height / 2;
			} else {
				var graphic = Paths.image('pixelUI/' + skinPixel + skinPostfix);
				loadGraphic(graphic, true, Math.floor(graphic.width / 4), Math.floor(graphic.height / 5));
			}
			setGraphicSize(Std.int(width * PlayState.daPixelZoom));
			loadPixelNoteAnims();
			antialiasing = false;

			if (isSustainNote) {
				offsetX       += _lastNoteOffX;
				_lastNoteOffX  = (width - 7) * (PlayState.daPixelZoom / 2);
				offsetX       -= _lastNoteOffX;
			}
		} else {
			frames = Paths.getSparrowAtlas(skin);
			loadNoteAnims();
			if (!isSustainNote) {
				centerOffsets();
				centerOrigin();
			}
		}

		if (isSustainNote) scale.y = lastScaleY;
		updateHitbox();
		if (animName != null) animation.play(animName, true);
	}

	public static function getNoteSkinPostfix()
	{
		var skin:String = '';
		if (ClientPrefs.data.noteSkin != ClientPrefs.defaultData.noteSkin)
			skin = '-' + ClientPrefs.data.noteSkin.trim().toLowerCase().replace(' ', '_');
		return skin;
	}

	function loadNoteAnims() {
		if (isSustainNote)
		{
			attemptToAddAnimationByPrefix('purpleholdend', 'pruple end hold', 24, true);
			animation.addByPrefix(colArray[noteData] + 'holdend', colArray[noteData] + ' hold end', 24, true);
			animation.addByPrefix(colArray[noteData] + 'hold',    colArray[noteData] + ' hold piece', 24, true);
		}
		else animation.addByPrefix(colArray[noteData] + 'Scroll', colArray[noteData] + '0');

		setGraphicSize(Std.int(width * 0.7));
		updateHitbox();
	}

	function loadPixelNoteAnims() {
		if (isSustainNote)
		{
			animation.add(colArray[noteData] + 'holdend', [noteData + 4], 24, true);
			animation.add(colArray[noteData] + 'hold',    [noteData],     24, true);
		}
		else animation.add(colArray[noteData] + 'Scroll', [noteData + 4], 24, true);
	}

	function attemptToAddAnimationByPrefix(name:String, prefix:String,
		framerate:Float = 24, doLoop:Bool = true)
	{
		var animFrames = [];
		@:privateAccess
		animation.findByPrefix(animFrames, prefix);
		if (animFrames.length < 1) return;
		animation.addByPrefix(name, prefix, framerate, doLoop);
	}

	// ── Hold cover API ────────────────────────────────────────────────────────

	/**
	 * Spawns a hold cover effect on this sustain note.
	 * Call from PlayState when the player starts holding the note.
	 * @param layer  The FlxSpriteGroup to add the cover to (e.g. holdCoverLayer).
	 */
	public function spawnHoldCover(layer:FlxSpriteGroup):Void
	{
		if (inEditor || !isSustainNote || holdCover != null) return;

		var cover       = new NoteHoldCover(noteData);
		cover.x         = x;
		cover.y         = y;
		layer.add(cover);
		holdCover       = cover;
		cover.playStart();
	}

	/**
	 * Keeps the cover sprite glued to the note's current position.
	 * Called automatically inside followStrumNote() — no manual call needed.
	 */
	public function updateHoldCoverPosition():Void
	{
		if (holdCover == null || !holdCover.alive) return;
		holdCover.x = x;
		holdCover.y = y;
	}

	/**
	 * Triggers the end animation on the active cover and clears the reference.
	 * Call from PlayState when the player releases or misses the sustain.
	 */
	public function killHoldCover():Void
	{
		if (holdCover == null) return;
		holdCover.playEnd();
		holdCover = null;
	}

	// ─────────────────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (mustPress)
		{
			canBeHit = (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * lateHitMult) &&
						strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult));

			if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit)
				tooLate = true;
		}
		else
		{
			canBeHit = false;

			if (strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
			{
				if ((isSustainNote && prevNote.wasGoodHit) || strumTime <= Conductor.songPosition)
					wasGoodHit = true;
			}
		}

		if (tooLate && !inEditor)
			if (alpha > 0.3) alpha = 0.3;
	}

	override public function destroy()
	{
		// Clean up cover if note is destroyed mid-hold.
		if (holdCover != null)
		{
			holdCover.kill();
			holdCover = null;
		}
		super.destroy();
		_lastValidChecked = '';
	}

	public function followStrumNote(myStrum:StrumNote, fakeCrochet:Float, songSpeed:Float = 1)
	{
		var strumX:Float         = myStrum.x;
		var strumY:Float         = myStrum.y;
		var strumAngle:Float     = myStrum.angle;
		var strumAlpha:Float     = myStrum.alpha;
		var strumDirection:Float = myStrum.direction;

		distance = (0.45 * (Conductor.songPosition - strumTime) * songSpeed * multSpeed);
		if (!myStrum.downScroll) distance *= -1;

		var angleDir = strumDirection * Math.PI / 180;
		if (copyAngle) angle = strumDirection - 90 + strumAngle + offsetAngle;
		if (copyAlpha) alpha = strumAlpha * multAlpha;
		if (copyX)     x     = strumX + offsetX + Math.cos(angleDir) * distance;

		if (copyY)
		{
			y = strumY + offsetY + correctionOffset + Math.sin(angleDir) * distance;
			if (myStrum.downScroll && isSustainNote)
			{
				if (PlayState.isPixelStage) y -= PlayState.daPixelZoom * 9.5;
				y -= (frameHeight * scale.y) - (Note.swagWidth / 2);
			}
		}

		// Keep hold cover glued to the note's screen position.
		updateHoldCoverPosition();
	}

	public function clipToStrumNote(myStrum:StrumNote)
	{
		var center:Float = myStrum.y + offsetY + Note.swagWidth / 2;
		if (isSustainNote && (mustPress || !ignoreNote) &&
			(!mustPress || (wasGoodHit || (prevNote.wasGoodHit && !canBeHit))))
		{
			var swagRect:FlxRect = clipRect;
			if (swagRect == null) swagRect = new FlxRect(0, 0, frameWidth, frameHeight);

			if (myStrum.downScroll)
			{
				if (y - offset.y * scale.y + height >= center)
				{
					swagRect.width  = frameWidth;
					swagRect.height = (center - y) / scale.y;
					swagRect.y      = frameHeight - swagRect.height;
				}
			}
			else if (y + offset.y * scale.y <= center)
			{
				swagRect.y      = (center - y) / scale.y;
				swagRect.width  = width / scale.x;
				swagRect.height = (height / scale.y) - swagRect.y;
			}
			clipRect = swagRect;
		}
	}

	@:noCompletion
	override function set_clipRect(rect:FlxRect):FlxRect
	{
		clipRect = rect;
		if (frames != null)
			frame = frames.frames[animation.frameIndex];
		return rect;
	}
}
