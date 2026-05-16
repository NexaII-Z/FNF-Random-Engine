package states.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.FlxCamera;
import flixel.group.FlxGroup;
import flixel.group.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.graphics.frames.FlxAtlasFrames;

import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUINumericStepper;

import objects.Character;
import objects.HealthIcon;

// ─── Data types ─────────────────────────────────────────────────────────────

enum StageObjectType { SOLID; ANIM; NO_ANIM; CHARACTER; }

typedef StageObject =
{
	var name:String;
	var type:StageObjectType;
	var sprite:FlxSprite;
	var ?animPrefix:String;   // for ANIM type
	var ?imagePath:String;    // for ANIM / NO_ANIM
	var ?solidColor:Int;      // for SOLID
	var layerIndex:Int;
	var visible:Bool;
}

// ────────────────────────────────────────────────────────────────────────────

class StageEditorState extends MusicBeatState
{
	// ─── Tab menu (right side, matches chart editor) ──────────────────
	var UI_box:FlxUITabMenu;

	// ─── Layer panel (top-left) ───────────────────────────────────────
	var layerPanel:FlxSprite;
	var layerGroup:FlxGroup;
	var layerTexts:Array<FlxText> = [];
	var layerUpBtn:FlxButton;
	var layerDownBtn:FlxButton;

	// ─── Stage objects ────────────────────────────────────────────────
	var stageObjects:Array<StageObject> = [];
	var curSelected:Int = -1;

	// ─── Characters (always present, can't be deleted) ────────────────
	var dadChar:Character;
	var bfChar:Character;
	var gfChar:Character;
	var dadIcon:HealthIcon;
	var bfIcon:HealthIcon;
	var gfIcon:HealthIcon;
	var gfVisible:Bool = true;

	// ─── Black bg (always bottom layer) ──────────────────────────────
	var stageBG:FlxSprite;

	// ─── Sprite render group (ordered by layerIndex) ──────────────────
	var spriteLayer:FlxTypedGroup<FlxSprite>;

	// ─── Move speed ───────────────────────────────────────────────────
	var moveSpeed:Float = 2;
	var fastSpeed:Float = 10;

	// ─── UI input refs ────────────────────────────────────────────────
	var blockTypingOn:Array<FlxUIInputText> = [];

	// Import tab
	var importPathInput:FlxUIInputText;

	// Data tab
	var dataNameInput:FlxUIInputText;
	var dataColorInput:FlxUIInputText;
	var dataAnimInput:FlxUIInputText;
	var dataAnimPrefix:FlxUIInputText;
	var hideGFCheck:FlxUICheckBox;

	// Edit tab
	var editXStepper:FlxUINumericStepper;
	var editYStepper:FlxUINumericStepper;
	var editScaleXStepper:FlxUINumericStepper;
	var editScaleYStepper:FlxUINumericStepper;

	// ─── Error / info display ─────────────────────────────────────────
	var errorText:FlxText;
	var errorTimer:FlxTimer;

	// ─── Layer panel tab display ──────────────────────────────────────
	static inline var LAYER_PANEL_W:Int  = 180;
	static inline var LAYER_PANEL_H:Int  = 300;
	static inline var LAYER_ITEM_H:Int   = 22;

	// ─── Camera ──────────────────────────────────────────────────────
	var editorCam:FlxCamera;
	var uiCam:FlxCamera;

	// ─────────────────────────────────────────────────────────────────

	override function create()
	{
		super.create();

		// Two cameras: one for stage objects, one for UI
		editorCam = new FlxCamera();
		uiCam     = new FlxCamera();
		uiCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.reset(editorCam);
		FlxG.cameras.add(uiCam, false);

		// Black background (always bottom)
		stageBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		stageBG.cameras = [editorCam];
		add(stageBG);

		// Sprite layer group
		spriteLayer = new FlxTypedGroup<FlxSprite>();
		spriteLayer.cameras = [editorCam];
		add(spriteLayer);

		// Characters
		setupCharacters();

		// ── Right-side Tab Menu (same pattern as ChartingState) ────────
		var tabs = [
			{name: "Import", label: 'Import'},
			{name: "Data",   label: 'Data'},
			{name: "Edit",   label: 'Edit'},
		];
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(300, 420);
		UI_box.x = FlxG.width - UI_box.width - 10;
		UI_box.y = 25;
		UI_box.scrollFactor.set();
		UI_box.cameras = [uiCam];

		addImportTab();
		addDataTab();
		addEditTab();

		add(UI_box);

		// ── Layer panel (top-left) ────────────────────────────────────
		buildLayerPanel();

		// ── Error text ────────────────────────────────────────────────
		errorText = new FlxText(0, FlxG.height - 40, FlxG.width, '', 18);
		errorText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.RED, CENTER);
		errorText.scrollFactor.set();
		errorText.cameras = [uiCam];
		errorText.visible = false;
		add(errorText);

		FlxG.mouse.visible = true;

		#if mobile
		addTouchPad("LEFT_FULL", "A_B_C_D_E_F");
		if (touchPad != null) touchPad.cameras = [uiCam];
		#end

		refreshLayerPanel();
	}

	// ─────────────────────────────────────────────────────────────────
	// CHARACTER SETUP
	// ─────────────────────────────────────────────────────────────────

	function setupCharacters()
	{
		dadChar = new Character(100, 100, 'dad');
		dadChar.cameras = [editorCam];
		dadChar.setGraphicSize(Std.int(dadChar.width * 0.5));
		dadChar.updateHitbox();
		add(dadChar);

		bfChar = new Character(600, 100, 'bf', true);
		bfChar.cameras = [editorCam];
		bfChar.setGraphicSize(Std.int(bfChar.width * 0.5));
		bfChar.updateHitbox();
		add(bfChar);

		gfChar = new Character(350, 150, 'gf');
		gfChar.cameras = [editorCam];
		gfChar.setGraphicSize(Std.int(gfChar.width * 0.5));
		gfChar.updateHitbox();
		add(gfChar);

		dadIcon = new HealthIcon('dad');
		bfIcon  = new HealthIcon('bf');
		gfIcon  = new HealthIcon('gf');
		for (ic in [dadIcon, bfIcon, gfIcon]) { ic.cameras = [uiCam]; ic.scrollFactor.set(); }
	}

	// ─────────────────────────────────────────────────────────────────
	// LAYER PANEL
	// ─────────────────────────────────────────────────────────────────

	function buildLayerPanel()
	{
		layerGroup = new FlxGroup();
		layerGroup.cameras = [uiCam];

		layerPanel = new FlxSprite(5, 5).makeGraphic(LAYER_PANEL_W, LAYER_PANEL_H, 0xCC111111);
		layerPanel.scrollFactor.set();
		layerGroup.add(layerPanel);

		// Up / Down buttons
		layerUpBtn = new FlxButton(5, LAYER_PANEL_H + 8, "▲", function() moveLayer(-1));
		layerUpBtn.setGraphicSize(Std.int(LAYER_PANEL_W / 2) - 2, 22);
		layerUpBtn.updateHitbox();
		layerUpBtn.scrollFactor.set();
		layerGroup.add(layerUpBtn);

		layerDownBtn = new FlxButton(5 + Std.int(LAYER_PANEL_W / 2), LAYER_PANEL_H + 8, "▼", function() moveLayer(1));
		layerDownBtn.setGraphicSize(Std.int(LAYER_PANEL_W / 2) - 2, 22);
		layerDownBtn.updateHitbox();
		layerDownBtn.scrollFactor.set();
		layerGroup.add(layerDownBtn);

		add(layerGroup);
	}

	function refreshLayerPanel()
	{
		// Remove old text entries
		for (t in layerTexts) layerGroup.remove(t, true);
		layerTexts = [];

		// Characters always at top
		var charNames = ['Dad', 'BF', 'GF'];
		for (i in 0...charNames.length)
		{
			var t = makeLayerText(charNames[i], 5, 8 + i * LAYER_ITEM_H, true);
			layerGroup.add(t);
			layerTexts.push(t);
		}

		// User objects
		for (i in 0...stageObjects.length)
		{
			var obj = stageObjects[i];
			var yPos = 8 + (charNames.length + i) * LAYER_ITEM_H;
			var t = makeLayerText(obj.name, 5, yPos, false);
			if (i == curSelected) t.color = FlxColor.CYAN;
			layerGroup.add(t);
			layerTexts.push(t);
		}
	}

	function makeLayerText(label:String, x:Float, y:Float, isChar:Bool):FlxText
	{
		var t = new FlxText(x, y, LAYER_PANEL_W - 10, (isChar ? '[' + label + ']' : label), 11);
		t.setFormat(Paths.font("vcr.ttf"), 11, isChar ? FlxColor.YELLOW : FlxColor.WHITE, LEFT);
		t.scrollFactor.set();

		if (!isChar)
		{
			// Click to select
			var captured = stageObjects.length - (stageObjects.length - layerTexts.length + 3);
			// We'll handle selection in update via mouse overlap instead
		}
		return t;
	}

	function moveLayer(dir:Int)
	{
		if (curSelected < 0 || curSelected >= stageObjects.length) return;
		var target = curSelected + dir;
		if (target < 0 || target >= stageObjects.length) return;

		var tmp = stageObjects[curSelected];
		stageObjects[curSelected] = stageObjects[target];
		stageObjects[target] = tmp;
		curSelected = target;

		rebuildSpriteLayer();
		refreshLayerPanel();
	}

	function rebuildSpriteLayer()
	{
		spriteLayer.clear();
		for (obj in stageObjects)
			spriteLayer.add(obj.sprite);
	}

	// ─────────────────────────────────────────────────────────────────
	// IMPORT TAB
	// ─────────────────────────────────────────────────────────────────

	function addImportTab()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = 'Import';

		// Default path hint
		importPathInput = new FlxUIInputText(10, 40, 230, 'images/myStage/', 9);
		blockTypingOn.push(importPathInput);

		var pathLabel = new FlxText(10, 25, 230, 'Image path (no extension):', 9);

		// ── Add Solid Color ──────────────────────────────────────────
		var solidBtn = new FlxButton(10, 80, 'Add Solid Color', function()
		{
			addSolidColor();
		});
		solidBtn.setGraphicSize(200, 28);
		solidBtn.updateHitbox();

		// ── Add Animation ─────────────────────────────────────────────
		var animBtn = new FlxButton(10, 120, 'Add Animation', function()
		{
			addAnimation(importPathInput.text);
		});
		animBtn.setGraphicSize(200, 28);
		animBtn.updateHitbox();

		// ── Add No Animation ──────────────────────────────────────────
		var noAnimBtn = new FlxButton(10, 160, 'Add No Animation', function()
		{
			addNoAnim(importPathInput.text);
		});
		noAnimBtn.setGraphicSize(200, 28);
		noAnimBtn.updateHitbox();

		tab.add(pathLabel);
		tab.add(importPathInput);
		tab.add(solidBtn);
		tab.add(animBtn);
		tab.add(noAnimBtn);

		UI_box.addGroup(tab);
	}

	// ─────────────────────────────────────────────────────────────────
	// DATA TAB
	// ─────────────────────────────────────────────────────────────────

	function addDataTab()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = 'Data';

		// Name
		var nameLabel = new FlxText(10, 10, 200, 'Object Name:', 9);
		dataNameInput = new FlxUIInputText(10, 25, 180, '', 9);
		blockTypingOn.push(dataNameInput);

		var nameUpdateBtn = new FlxButton(195, 25, 'Set', function()
		{
			if (curSelected >= 0 && curSelected < stageObjects.length)
			{
				stageObjects[curSelected].name = dataNameInput.text;
				refreshLayerPanel();
			}
		});
		nameUpdateBtn.setGraphicSize(50, 20);
		nameUpdateBtn.updateHitbox();

		// Solid Color (only relevant for SOLID type)
		var colorLabel = new FlxText(10, 55, 200, 'Solid Color (0xFFRRGGBB):', 9);
		dataColorInput = new FlxUIInputText(10, 70, 180, '0xFFFFFFFF', 9);
		blockTypingOn.push(dataColorInput);

		var colorSetBtn = new FlxButton(195, 70, 'Set', function()
		{
			if (curSelected >= 0 && stageObjects[curSelected].type == SOLID)
			{
				var col = Std.parseInt(dataColorInput.text);
				if (col == null) col = 0xFFFFFFFF;
				stageObjects[curSelected].solidColor = col;
				stageObjects[curSelected].sprite.makeGraphic(100, 100, col, true);
			}
		});
		colorSetBtn.setGraphicSize(50, 20);
		colorSetBtn.updateHitbox();

		// Animation (only for ANIM type)
		var animLabel = new FlxText(10, 100, 200, 'Anim name (in XML):', 9);
		dataAnimPrefix = new FlxUIInputText(10, 115, 130, '', 9);
		blockTypingOn.push(dataAnimPrefix);

		var animNameLabel = new FlxText(10, 140, 200, 'Display name / alias:', 9);
		dataAnimInput = new FlxUIInputText(10, 155, 130, '', 9);
		blockTypingOn.push(dataAnimInput);

		var addAnimBtn = new FlxButton(145, 130, 'Add Anim', function()
		{
			if (curSelected >= 0 && stageObjects[curSelected].type == ANIM)
			{
				var obj  = stageObjects[curSelected];
				var pref = dataAnimPrefix.text;
				var name = dataAnimInput.text.length > 0 ? dataAnimInput.text : pref;
				if (obj.sprite.frames != null)
					obj.sprite.animation.addByPrefix(name, pref, 24, true);
				else
					showError('No frames loaded on this object!');
			}
		});
		addAnimBtn.setGraphicSize(100, 20);
		addAnimBtn.updateHitbox();

		// Hide GF
		hideGFCheck = new FlxUICheckBox(10, 185, null, null, 'Hide GF', 100, function()
		{
			gfVisible = !hideGFCheck.checked;
			gfChar.visible = gfVisible;
		});

		// Save
		var saveBtn = new FlxButton(10, 370, 'Save Stage JSON', function() saveStage());
		saveBtn.setGraphicSize(200, 28);
		saveBtn.updateHitbox();
		saveBtn.color = FlxColor.GREEN;
		saveBtn.label.color = FlxColor.WHITE;

		tab.add(nameLabel);
		tab.add(dataNameInput);
		tab.add(nameUpdateBtn);
		tab.add(colorLabel);
		tab.add(dataColorInput);
		tab.add(colorSetBtn);
		tab.add(animLabel);
		tab.add(dataAnimPrefix);
		tab.add(animNameLabel);
		tab.add(dataAnimInput);
		tab.add(addAnimBtn);
		tab.add(hideGFCheck);
		tab.add(saveBtn);

		UI_box.addGroup(tab);
	}

	// ─────────────────────────────────────────────────────────────────
	// EDIT TAB
	// ─────────────────────────────────────────────────────────────────

	function addEditTab()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = 'Edit';

		var posLabel = new FlxText(10, 10, 200, 'Position:', 9);

		editXStepper = new FlxUINumericStepper(10, 25, 1, 0, -99999, 99999, 1);
		editXStepper.name = 'edit_x';

		editYStepper = new FlxUINumericStepper(120, 25, 1, 0, -99999, 99999, 1);
		editYStepper.name = 'edit_y';

		var xLabel = new FlxText(10,  15, 50, 'X:', 9);
		var yLabel = new FlxText(120, 15, 50, 'Y:', 9);

		var scaleLabel = new FlxText(10, 65, 200, 'Scale:', 9);

		editScaleXStepper = new FlxUINumericStepper(10, 80, 0.1, 1, 0.01, 100, 2);
		editScaleXStepper.name = 'edit_sx';

		editScaleYStepper = new FlxUINumericStepper(120, 80, 0.1, 1, 0.01, 100, 2);
		editScaleYStepper.name = 'edit_sy';

		var sxLabel = new FlxText(10,  70, 50, 'SX:', 9);
		var syLabel = new FlxText(120, 70, 50, 'SY:', 9);

		var applyBtn = new FlxButton(10, 115, 'Apply', function()
		{
			if (curSelected >= 0 && curSelected < stageObjects.length)
			{
				var spr = stageObjects[curSelected].sprite;
				spr.x = editXStepper.value;
				spr.y = editYStepper.value;
				spr.scale.set(editScaleXStepper.value, editScaleYStepper.value);
				spr.updateHitbox();
			}
		});
		applyBtn.setGraphicSize(120, 26);
		applyBtn.updateHitbox();

		var helpText = new FlxText(10, 155, 270,
			'Keyboard:\nArrows = Move slow\nWASD = Move fast\n\nMobile:\nLeft pad arrows = Move\nHold = Fast move\nB = Back', 9);
		helpText.color = FlxColor.GRAY;

		tab.add(posLabel);
		tab.add(xLabel);
		tab.add(yLabel);
		tab.add(editXStepper);
		tab.add(editYStepper);
		tab.add(scaleLabel);
		tab.add(sxLabel);
		tab.add(syLabel);
		tab.add(editScaleXStepper);
		tab.add(editScaleYStepper);
		tab.add(applyBtn);
		tab.add(helpText);

		UI_box.addGroup(tab);
	}

	// ─────────────────────────────────────────────────────────────────
	// getEvent (same pattern as ChartingState)
	// ─────────────────────────────────────────────────────────────────

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = cast sender;
			if (curSelected >= 0 && curSelected < stageObjects.length)
			{
				var spr = stageObjects[curSelected].sprite;
				switch (nums.name)
				{
					case 'edit_x':  spr.x = nums.value;
					case 'edit_y':  spr.y = nums.value;
					case 'edit_sx': spr.scale.x = nums.value; spr.updateHitbox();
					case 'edit_sy': spr.scale.y = nums.value; spr.updateHitbox();
				}
			}
		}
	}

	// ─────────────────────────────────────────────────────────────────
	// UPDATE
	// ─────────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// ── Block input while typing ──────────────────────────────────
		var typing = false;
		for (inp in blockTypingOn)
			if (inp.hasFocus) { typing = true; break; }

		// ── Layer panel click selection ───────────────────────────────
		#if FLX_MOUSE
		if (FlxG.mouse.justPressed)
		{
			var charCount = 3; // Dad, BF, GF entries
			for (i in 0...stageObjects.length)
			{
				var t = layerTexts[charCount + i];
				if (t != null && FlxG.mouse.overlaps(t, uiCam))
				{
					curSelected = i;
					refreshLayerPanel();
					syncEditTab();
					break;
				}
			}
		}
		#end

		if (!typing)
		{
			// ── Arrow keys = slow move ──────────────────────────────
			#if !mobile
			if (curSelected >= 0 && curSelected < stageObjects.length)
			{
				var spr = stageObjects[curSelected].sprite;
				var spd = FlxG.keys.pressed.W || FlxG.keys.pressed.A ||
				          FlxG.keys.pressed.S || FlxG.keys.pressed.D
				          ? fastSpeed : moveSpeed;

				if (FlxG.keys.pressed.LEFT  || FlxG.keys.pressed.A) spr.x -= spd;
				if (FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.D) spr.x += spd;
				if (FlxG.keys.pressed.UP    || FlxG.keys.pressed.W) spr.y -= spd;
				if (FlxG.keys.pressed.DOWN  || FlxG.keys.pressed.S) spr.y += spd;

				// Sync stepper display
				editXStepper.value = spr.x;
				editYStepper.value = spr.y;
			}

			// ── Back to Master Editor ─────────────────────────────
			if (FlxG.keys.justPressed.ESCAPE)
			{
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MainMenuState());
			}
			#end

			#if mobile
			if (touchPad != null && curSelected >= 0 && curSelected < stageObjects.length)
			{
				var spr  = stageObjects[curSelected].sprite;
				// Hold any arrow = fast
				var holding = touchPad.buttonLeft.pressed || touchPad.buttonRight.pressed
				           || touchPad.buttonUp.pressed   || touchPad.buttonDown.pressed;
				var spd = holding ? fastSpeed : moveSpeed;

				if (touchPad.buttonLeft.pressed)  spr.x -= spd;
				if (touchPad.buttonRight.pressed) spr.x += spd;
				if (touchPad.buttonUp.pressed)    spr.y -= spd;
				if (touchPad.buttonDown.pressed)  spr.y += spd;

				editXStepper.value = spr.x;
				editYStepper.value = spr.y;
			}

			if (touchPad != null && touchPad.buttonB.justPressed)
			{
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MainMenuState());
			}
			#end
		}
	}

	// ─────────────────────────────────────────────────────────────────
	// OBJECT CREATION
	// ─────────────────────────────────────────────────────────────────

	function addSolidColor()
	{
		var spr = new FlxSprite(200, 200);
		spr.makeGraphic(100, 100, FlxColor.WHITE);
		spr.cameras = [editorCam];
		spriteLayer.add(spr);

		var obj:StageObject = {
			name: 'Solid_' + stageObjects.length,
			type: SOLID,
			sprite: spr,
			solidColor: FlxColor.WHITE,
			layerIndex: stageObjects.length,
			visible: true
		};
		stageObjects.push(obj);
		curSelected = stageObjects.length - 1;
		refreshLayerPanel();
		syncEditTab();
	}

	function addAnimation(path:String)
	{
		path = path.trim();
		if (path.length == 0) { showError('Enter a path first!'); return; }

		var pngPath = Paths.image(path);
		var xmlPath = Paths.file('images/' + path + '.xml');

		// Check both exist
		var pngExists = openfl.utils.Assets.exists(pngPath);
		var xmlExists = openfl.utils.Assets.exists(xmlPath);

		if (!pngExists) { showError('PNG not found: ' + path); return; }
		if (!xmlExists) { showError('XML not found: ' + path + '\n(PNG and XML must share the same name)'); return; }

		var spr = new FlxSprite(200, 200);
		try
		{
			spr.frames = Paths.getSparrowAtlas(path);
		}
		catch (e:Dynamic)
		{
			showError('Failed to load atlas: ' + e);
			return;
		}

		spr.cameras = [editorCam];
		spriteLayer.add(spr);

		var obj:StageObject = {
			name: 'Anim_' + stageObjects.length,
			type: ANIM,
			sprite: spr,
			imagePath: path,
			animPrefix: '',
			layerIndex: stageObjects.length,
			visible: true
		};
		stageObjects.push(obj);
		curSelected = stageObjects.length - 1;
		refreshLayerPanel();
		syncEditTab();
	}

	function addNoAnim(path:String)
	{
		path = path.trim();
		if (path.length == 0) { showError('Enter a path first!'); return; }

		var pngPath = Paths.image(path);
		if (!openfl.utils.Assets.exists(pngPath)) { showError('PNG not found: ' + path); return; }

		var spr = new FlxSprite(200, 200);
		try
		{
			spr.loadGraphic(Paths.image(path));
		}
		catch (e:Dynamic)
		{
			showError('Failed to load image: ' + e);
			return;
		}

		spr.cameras = [editorCam];
		spriteLayer.add(spr);

		var obj:StageObject = {
			name: 'Img_' + stageObjects.length,
			type: NO_ANIM,
			sprite: spr,
			imagePath: path,
			layerIndex: stageObjects.length,
			visible: true
		};
		stageObjects.push(obj);
		curSelected = stageObjects.length - 1;
		refreshLayerPanel();
		syncEditTab();
	}

	// ─────────────────────────────────────────────────────────────────
	// SYNC EDIT TAB when selection changes
	// ─────────────────────────────────────────────────────────────────

	function syncEditTab()
	{
		if (curSelected < 0 || curSelected >= stageObjects.length) return;
		var spr = stageObjects[curSelected].sprite;
		editXStepper.value      = spr.x;
		editYStepper.value      = spr.y;
		editScaleXStepper.value = spr.scale.x;
		editScaleYStepper.value = spr.scale.y;

		dataNameInput.text = stageObjects[curSelected].name;
		if (stageObjects[curSelected].type == SOLID)
			dataColorInput.text = '0x' + StringTools.hex(stageObjects[curSelected].solidColor ?? 0xFFFFFFFF, 8).toUpperCase();
	}

	// ─────────────────────────────────────────────────────────────────
	// SAVE
	// ─────────────────────────────────────────────────────────────────

	function saveStage()
	{
		var objsData:Array<Dynamic> = [];
		for (obj in stageObjects)
		{
			objsData.push({
				name:       obj.name,
				type:       Std.string(obj.type),
				x:          obj.sprite.x,
				y:          obj.sprite.y,
				scaleX:     obj.sprite.scale.x,
				scaleY:     obj.sprite.scale.y,
				imagePath:  obj.imagePath ?? '',
				solidColor: obj.solidColor ?? 0xFFFFFFFF,
				layerIndex: obj.layerIndex,
				visible:    obj.visible
			});
		}

		var data = haxe.Json.stringify({
			stageObjects: objsData,
			hideGF: hideGFCheck.checked
		}, "\t");

		#if mobile
		StorageUtil.saveContent('myStage.json', data);
		showError('Saved! (myStage.json)');
		#else
		var _file = new openfl.net.FileReference();
		_file.save(data, 'myStage.json');
		#end
	}

	// ─────────────────────────────────────────────────────────────────
	// ERROR DISPLAY
	// ─────────────────────────────────────────────────────────────────

	function showError(msg:String)
	{
		errorText.text    = msg;
		errorText.visible = true;
		if (errorTimer != null) errorTimer.cancel();
		errorTimer = new FlxTimer().start(4, function(_) { errorText.visible = false; });
	}

	override function destroy()
	{
		super.destroy();
	}
}
