package states.stages;

import openfl.filters.ShaderFilter;
import shaders.RainShader;

import flixel.addons.display.FlxTiledSprite;

import substates.GameOverSubstate;
import states.stages.objects.*;
import objects.Note;

class PhillyBlazin extends BaseStage
{
	var rainShader:RainShader;
	var rainTimeScale:Float = 1;

	var picoHandler:PicoBlazinHandler;
	var darnellHandler:DarnellBlazinHandler;

	var scrollingSky:FlxTiledSprite;
	var skyAdditive:BGSprite;
	var lightning:BGSprite;
	var foregroundMultiply:BGSprite;
	var additionalLighten:FlxSprite;

	var lightningTimer:Float = 3.0;

	override function create()
	{
		// FlxTransitionableState is not available in Psych 0.7.3.
		// Use PlayState's own skipNextTransOut flag instead.
		game.skipNextTransOut = true;

		function setupScale(spr:BGSprite)
		{
			spr.scale.set(1.75, 1.75);
			spr.updateHitbox();
		}

		if (!ClientPrefs.data.lowQuality)
		{
			var skyGraphic = Paths.image('phillyBlazin/skyBlur');
			scrollingSky = new FlxTiledSprite(skyGraphic,
				Std.int(skyGraphic.width * 1.1) + 475,
				Std.int(skyGraphic.height / 1.1), true, false);
			scrollingSky.antialiasing = ClientPrefs.data.antialiasing;
			scrollingSky.setPosition(-500, -120);
			scrollingSky.scrollFactor.set();
			add(scrollingSky);

			skyAdditive = new BGSprite('phillyBlazin/skyBlur', -600, -175, 0.0, 0.0);
			setupScale(skyAdditive);
			skyAdditive.visible = false;
			add(skyAdditive);

			lightning = new BGSprite('phillyBlazin/lightning', -50, -300, 0.0, 0.0, ['lightning0'], false);
			setupScale(lightning);
			lightning.visible = false;
			add(lightning);
		}

		var phillyForegroundCity:BGSprite = new BGSprite('phillyBlazin/streetBlur', -600, -175, 0.0, 0.0);
		setupScale(phillyForegroundCity);
		add(phillyForegroundCity);

		if (!ClientPrefs.data.lowQuality)
		{
			foregroundMultiply = new BGSprite('phillyBlazin/streetBlur', -600, -175, 0.0, 0.0);
			setupScale(foregroundMultiply);
			foregroundMultiply.blend = MULTIPLY;
			foregroundMultiply.visible = false;
			add(foregroundMultiply);

			additionalLighten = new FlxSprite(-600, -175).makeGraphic(1, 1, FlxColor.WHITE);
			additionalLighten.scrollFactor.set();
			additionalLighten.scale.set(2500, 2500);
			additionalLighten.updateHitbox();
			additionalLighten.blend = ADD;
			additionalLighten.visible = false;
			add(additionalLighten);
		}

		if (ClientPrefs.data.shaders)
			setupRainShader();

		var _song = PlayState.SONG;
		if (_song.gameOverSound == null || _song.gameOverSound.trim().length < 1)
			GameOverSubstate.deathSoundName = 'fnf_loss_sfx-pico-gutpunch';
		if (_song.gameOverLoop == null || _song.gameOverLoop.trim().length < 1)
			GameOverSubstate.loopSoundName = 'gameOver-pico';
		if (_song.gameOverEnd == null || _song.gameOverEnd.trim().length < 1)
			GameOverSubstate.endSoundName = 'gameOverEnd-pico';
		if (_song.gameOverChar == null || _song.gameOverChar.trim().length < 1)
			GameOverSubstate.characterName = 'pico-blazin';
		// NOTE: GameOverSubstate.deathDelay does not exist in Psych 0.7.3 — removed.

		setDefaultGF('nene');
		precache();

		if (isStoryMode)
		{
			switch (songName)
			{
				case 'blazin':
					setEndCallback(function()
					{
						game.endingSong = true;
						inCutscene = true;
						canPause = false;
						game.skipNextTransIn = true;
						FlxG.camera.visible = false;
						camHUD.visible = false;
						game.startVideo('blazinCutscene');
					});
			}
		}
	}

	override function createPost()
	{
		picoHandler    = new PicoBlazinHandler();
		darnellHandler = new DarnellBlazinHandler();

		FlxG.camera.focusOn(camFollow.getPosition());
		FlxG.camera.fade(FlxColor.BLACK, 1.5, true, null, true);

		for (character in boyfriendGroup.members)
		{
			if (character == null) continue;
			character.color = 0xFFDEDEDE;
		}
		for (character in dadGroup.members)
		{
			if (character == null) continue;
			character.color = 0xFFDEDEDE;
		}
		for (character in gfGroup.members)
		{
			if (character == null) continue;
			character.color = 0xFF888888;
		}

		var unspawnNotes:Array<Note> = cast game.unspawnNotes;
		for (note in unspawnNotes)
		{
			if (note == null) continue;
			note.noAnimation    = true;
			note.noMissAnimation = true;
		}

		// Psych 0.7.3: FlxGroup.remove() takes only one argument — no splice bool.
		remove(dadGroup);
		addBehindBF(dadGroup);
	}

	override function beatHit()
	{
		// if (curBeat % 2 == 0) abot.beatHit();
	}

	// ── Note callbacks ────────────────────────────────────────────────────────
	// BaseStage in Psych 0.7.3 does NOT have goodNoteHit / noteMiss /
	// noteMissPress / opponentNoteHit / startSong as overrideable methods.
	// These are plain public functions; call them from PlayState like:
	//
	//   In goodNoteHit(note):
	//     if (Std.isOfType(stage, PhillyBlazin))
	//         cast(stage, PhillyBlazin).stageGoodNoteHit(note);
	//
	//   In noteMiss(note):
	//     if (Std.isOfType(stage, PhillyBlazin))
	//         cast(stage, PhillyBlazin).stageNoteMiss(note);
	//
	//   In opponentNoteHit(note):
	//     if (Std.isOfType(stage, PhillyBlazin))
	//         cast(stage, PhillyBlazin).stageOpponentNoteHit(note);
	//
	//   In keyReleased / ghost-tap handler:
	//     if (Std.isOfType(stage, PhillyBlazin))
	//         cast(stage, PhillyBlazin).stageNoteMissPress(direction);
	//
	//   At song start (after countdown):
	//     if (Std.isOfType(stage, PhillyBlazin))
	//         cast(stage, PhillyBlazin).stageSongStart();
	//
	// Alternatively, if your BaseStage DOES declare these as virtual functions
	// just swap 'public function' → 'override function' below.

	public function stageSongStart():Void
	{
		// nothing needed for Blazin on song start
	}

	public function stageGoodNoteHit(note:Note):Void
	{
		rainTimeScale += 0.7;
		if (picoHandler != null) picoHandler.noteHit(note);
	}

	public function stageNoteMiss(note:Note):Void
	{
		if (picoHandler != null) picoHandler.noteMiss(note);
	}

	public function stageNoteMissPress(direction:Int):Void
	{
		if (picoHandler != null) picoHandler.noteMissPress(direction);
	}

	public function stageOpponentNoteHit(note:Note):Void
	{
		if (darnellHandler != null) darnellHandler.noteHit(note);
	}

	// ── Internal helpers ──────────────────────────────────────────────────────

	function setupRainShader():Void
	{
		rainShader = new RainShader();
		rainShader.scale     = FlxG.height / 200;
		rainShader.intensity = 0.5;
		FlxG.camera.setFilters([new ShaderFilter(rainShader)]);
	}

	function precache():Void
	{
		for (i in 1...4)
			Paths.sound('lightning/Lightning$i');
	}

	override function update(elapsed:Float)
	{
		if (scrollingSky != null) scrollingSky.scrollX -= elapsed * 35;

		if (rainShader != null)
		{
			rainShader.updateViewInfo(FlxG.width, FlxG.height, FlxG.camera);
			rainShader.update(elapsed * rainTimeScale);
			rainTimeScale = FlxMath.lerp(0.02, Math.min(1, rainTimeScale),
				Math.exp(-elapsed / (1 / 3)));
		}

		lightningTimer -= elapsed;
		if (lightningTimer <= 0)
		{
			applyLightning();
			lightningTimer = FlxG.random.float(7, 15);
		}
	}

	function applyLightning():Void
	{
		if (ClientPrefs.data.lowQuality || game.endingSong) return;

		final LIGHTNING_FULL_DURATION:Float = 1.5;
		final LIGHTNING_FADE_DURATION:Float = 0.3;

		skyAdditive.visible = true;
		skyAdditive.alpha   = 0.7;
		FlxTween.tween(skyAdditive, {alpha: 0.0}, LIGHTNING_FULL_DURATION,
		{
			onComplete: function(_)
			{
				skyAdditive.visible        = false;
				lightning.visible          = false;
				foregroundMultiply.visible = false;
				additionalLighten.visible  = false;
			}
		});

		foregroundMultiply.visible = true;
		foregroundMultiply.alpha   = 0.64;
		FlxTween.tween(foregroundMultiply, {alpha: 0.0}, LIGHTNING_FULL_DURATION);

		additionalLighten.visible = true;
		additionalLighten.alpha   = 0.3;
		FlxTween.tween(additionalLighten, {alpha: 0.0}, LIGHTNING_FADE_DURATION);

		lightning.visible = true;
		lightning.animation.play('lightning0', true);

		if (FlxG.random.bool(65))
			lightning.x = FlxG.random.int(-250, 280);
		else
			lightning.x = FlxG.random.int(780, 900);

		FlxTween.color(boyfriend, LIGHTNING_FADE_DURATION, 0xFF606060, 0xFFDEDEDE);
		FlxTween.color(dad,       LIGHTNING_FADE_DURATION, 0xFF606060, 0xFFDEDEDE);
		FlxTween.color(gf,        LIGHTNING_FADE_DURATION, 0xFF606060, 0xFF888888);

		FlxG.sound.play(Paths.soundRandom('lightning/Lightning', 1, 3));
	}
}
