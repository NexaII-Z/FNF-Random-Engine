package states;

import flixel.FlxObject;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String  = '0.7.3';
	public static var randomEngineVersion:String = '0.1.0';
	public static var curSelected:Int = 0;

	// Left column items
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		#if MODS_ALLOWED
		'mods',
		#end
		'credits'
	];

	// Right-side fixed items
	var rightOption:String = 'options';
	var leftOption:String  = #if ACHIEVEMENTS_ALLOWED 'achievements' #else null #end;

	var menuItems:FlxTypedGroup<FlxSprite>;
	var rightItem:FlxSprite; // options - bottom right
	var leftItem:FlxSprite;  // awards  - above options

	var magenta:FlxSprite;
	var camFollow:FlxObject;

	static inline var LEFT_X:Float = 60;

	override function create()
	{
		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("In the Menus", null);
		#end

		transIn  = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;
		persistentUpdate = persistentDraw = true;

		var yScroll:Float = 0.25;
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color   = 0xFFfd719b;
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		// Left column - story/freeplay/mods/credits stacked on the left
		for (i in 0...optionShit.length)
		{
			var item = createMenuItem(optionShit[i], LEFT_X, (i * 140) + 90);
			item.y += (4 - optionShit.length) * 70;
		}

		// Options - bottom right
		if (rightOption != null)
		{
			rightItem = createMenuItem(rightOption, 0, 490);
			rightItem.x = FlxG.width - rightItem.width - 60;
		}

		// Awards - above options (flipped Y as requested)
		if (leftOption != null)
		{
			leftItem = createMenuItem(leftOption, 0, 0);
			if (rightItem != null)
				leftItem.setPosition(rightItem.x, rightItem.y - leftItem.height - 20);
			else
				leftItem.setPosition(FlxG.width - leftItem.width - 60, 330);
		}

		// Version texts
		var psychVer = new FlxText(12, FlxG.height - 64, 0, "Psych Engine v" + psychEngineVersion, 16);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);

		var randomVer = new FlxText(12, FlxG.height - 44, 0, "Random Engine v" + randomEngineVersion, 16);
		randomVer.scrollFactor.set();
		randomVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(randomVer);

		var fnfVer = new FlxText(12, FlxG.height - 24, 0,
			"Friday Night Funkin' v" + Application.current.meta.get('version'), 16);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);

		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');
		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end

		// Mobile: NONE for dpad (tap-to-navigate), B = back, C = editor
		#if mobile
		addTouchPad("NONE", "B_C");
		#end

		super.create();
		FlxG.camera.follow(camFollow, null, 0.15);
	}

	function createMenuItem(name:String, x:Float, y:Float):FlxSprite
	{
		var item = new FlxSprite(x, y);
		item.frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
		item.animation.addByPrefix('idle',     '$name basic', 24, true);
		item.animation.addByPrefix('selected', '$name white', 24, true);
		item.animation.play('idle');
		item.updateHitbox();
		item.antialiasing = ClientPrefs.data.antialiasing;
		item.scrollFactor.set();
		menuItems.add(item);
		return item;
	}

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (FreeplayState.vocals != null && FreeplayState.vocals.volume < 0.8)
			FreeplayState.vocals.volume += 0.5 * elapsed;

		if (!selectedSomethin)
		{
			handlePointerInput();

			#if mobile
			if (touchPad != null)
			{
				if (touchPad.buttonB.justPressed)
				{
					selectedSomethin = true;
					FlxG.sound.play(Paths.sound('cancelMenu'));
					MusicBeatState.switchState(new TitleState());
				}
				else if (touchPad.buttonC.justPressed)
				{
					selectedSomethin = true;
					MusicBeatState.switchState(new MasterEditorMenu());
				}
			}
			#end

			#if !mobile
			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}
			if (controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			if (FlxG.keys.justPressed.TAB)
			{
				#if MODS_ALLOWED
				selectedSomethin = true;
				MusicBeatState.switchState(new ModsMenuState());
				#end
			}
			#end
		}

		super.update(elapsed);
	}

	function handlePointerInput()
	{
		var points:Array<FlxPoint> = [];

		#if FLX_MOUSE
		// Hover: highlight whichever left-column item the mouse is over
		for (i in 0...optionShit.length)
		{
			var item = menuItems.members[i];
			if (item != null && FlxG.mouse.overlaps(item) && curSelected != i)
			{
				curSelected = i;
				changeItem();
				break;
			}
		}

		if (FlxG.mouse.justPressed)
			points.push(FlxPoint.weak(FlxG.mouse.x, FlxG.mouse.y));
		#end

		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
			if (touch.justPressed)
				points.push(FlxPoint.weak(touch.x, touch.y));
		#end

		for (pt in points)
		{
			// Left column - tap first time highlights, tap again confirms
			for (i in 0...optionShit.length)
			{
				var item = menuItems.members[i];
				if (item != null && item.overlapsPoint(pt))
				{
					if (curSelected != i)
					{
						curSelected = i;
						changeItem();
					}
					else
					{
						confirmSelection(optionShit[i], item);
					}
					break;
				}
			}

			// Options button
			if (rightItem != null && rightItem.overlapsPoint(pt))
				confirmSelection(rightOption, rightItem);

			// Awards button
			if (leftItem != null && leftItem.overlapsPoint(pt))
				confirmSelection(leftOption, leftItem);
		}

		// Keyboard ACCEPT still works for left column
		if (controls.ACCEPT)
			confirmSelection(optionShit[curSelected], menuItems.members[curSelected]);
	}

	function confirmSelection(option:String, item:FlxSprite)
	{
		if (selectedSomethin || item == null) return;
		selectedSomethin = true;

		FlxG.sound.play(Paths.sound('confirmMenu'));

		if (ClientPrefs.data.flashing)
			FlxFlicker.flicker(magenta, 1.1, 0.15, false);

		FlxFlicker.flicker(item, 1, 0.06, false, false, function(_)
		{
			switch (option)
			{
				case 'story_mode':
					MusicBeatState.switchState(new StoryMenuState());
				case 'freeplay':
					MusicBeatState.switchState(new FreeplayState());
				#if MODS_ALLOWED
				case 'mods':
					MusicBeatState.switchState(new ModsMenuState());
				#end
				#if ACHIEVEMENTS_ALLOWED
				case 'achievements':
					MusicBeatState.switchState(new AchievementsMenuState());
				#end
				case 'credits':
					MusicBeatState.switchState(new CreditsState());
				case 'options':
					MusicBeatState.switchState(new OptionsState());
					OptionsState.onPlayState = false;
					if (PlayState.SONG != null)
					{
						PlayState.SONG.arrowSkin  = null;
						PlayState.SONG.splashSkin = null;
						PlayState.stageUI         = 'normal';
					}
				default:
					selectedSomethin = false;
			}
		});

		// Fade out all other items
		for (memb in menuItems)
		{
			if (memb == item) continue;
			FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
		}
		if (rightItem != null && rightItem != item) FlxTween.tween(rightItem, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
		if (leftItem  != null && leftItem  != item) FlxTween.tween(leftItem,  {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
	}

	function changeItem(change:Int = 0)
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));

		for (item in menuItems)
		{
			item.animation.play('idle');
			item.centerOffsets();
		}

		var sel = menuItems.members[curSelected];
		if (sel != null)
		{
			sel.animation.play('selected');
			sel.centerOffsets();
			camFollow.setPosition(sel.getGraphicMidpoint().x, sel.getGraphicMidpoint().y);
		}
	}
}
