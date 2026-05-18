package options;

import states.MainMenuState;
import backend.StageData;
import backend.ClientPrefs;
import backend.Paths;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import objects.Alphabet;

class OptionsState extends MusicBeatState
{
	var options:Array<String> = [
		'Note Skins',
		'Note Colors',
		'Controls',
		'Adjust Delay and Combo',
		'Graphics',
		'Visuals and UI',
		'Gameplay',
		#if mobile
		'Mobile Options'
		#end
	];
	
	private var grpOptions:FlxTypedGroup<Alphabet>;
	private static var curSelected:Int = 0;
	public static var menuBG:FlxSprite;
	public static var onPlayState:Bool = false;
	var bg:FlxSprite;

	function openSelectedSubstate(label:String) {
		persistentUpdate = false;
		
		switch(label) {
			case 'Note Skins':
				MusicBeatState.switchState(new NoteSkinState());
			case 'Note Colors':
				openSubState(new options.NotesSubState());
			case 'Controls':
				openSubState(new options.ControlsSubState());
			case 'Graphics':
				openSubState(new options.GraphicsSettingsSubState());
			case 'Visuals and UI':
				openSubState(new options.VisualsUISubState());
			case 'Gameplay':
				openSubState(new options.GameplaySettingsSubState());
			case 'Adjust Delay and Combo':
				MusicBeatState.switchState(new options.NoteOffsetState());
			#if mobile
			case 'Mobile Options':
				openSubState(new mobile.options.MobileOptionsSubState());
			#end
		}
	}

	override function create() {
		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Options Menu", null);
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.color = 0xFFea71fd;
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		for (i in 0...options.length)
		{
			var optionText:Alphabet = new Alphabet(0, 0, options[i], true);
			optionText.screenCenter(X);
			optionText.y = (100 * i) + 200;
			grpOptions.add(optionText);
		}

		changeSelection();

		#if mobile
		addTouchPad('UP_DOWN', 'A_B');
		#end

		super.create();
	}

	var exiting:Bool = false;
	override function update(elapsed:Float) {
		super.update(elapsed);

		if (!exiting) {
			if (controls.UI_UP_P) {
				changeSelection(-1);
			}
			if (controls.UI_DOWN_P) {
				changeSelection(1);
			}

			if (controls.BACK) {
				exiting = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
			}
			else if (controls.ACCEPT) {
				openSelectedSubstate(options[curSelected]);
			}
		}

		var bullShit:Int = 0;
		for (item in grpOptions.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.y = FlxMath.lerp(item.y, (item.targetY * 130) + (FlxG.height * 0.45), FlxMath.bound(elapsed * 9.6, 0, 1));
			item.screenCenter(X);

			if (item.targetY == 0) {
				item.alpha = 1;
			} else {
				item.alpha = 0.6;
			}
		}
	}
	
	function changeSelection(change:Int = 0) {
		curSelected += change;
		if (curSelected < 0)
			curSelected = options.length - 1;
		if (curSelected >= options.length)
			curSelected = 0;

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}
}
