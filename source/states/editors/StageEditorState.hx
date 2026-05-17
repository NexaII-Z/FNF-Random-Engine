package states.editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUINumericStepper;

import objects.Character;

enum StageObjType { SOLID; ANIM; NO_ANIM; }

typedef StageObj =
{
	var name:String;
	var type:StageObjType;
	var sprite:FlxSprite;
	var imagePath:String;
	var animPrefix:String;
	var animName:String;
	var solidColor:Int;
	var x:Float;
	var y:Float;
	var scaleX:Float;
	var scaleY:Float;
	var scrollX:Float;
	var scrollY:Float;
	var aboveChars:Bool;
	var antialiasing:Bool;
}

class StageEditorState extends MusicBeatState
{
	// ── Cameras ──────────────────────────────────────────────────────────────
	var editorCam:FlxCamera;
	var uiCam:FlxCamera;

	// ── Scene ────────────────────────────────────────────────────────────────
	var stageBG:FlxSprite;
	var spriteLayer:FlxSpriteGroup;
	var dadChar:Character;
	var bfChar:Character;
	var gfChar:Character;

	// ── Objects ──────────────────────────────────────────────────────────────
	var objs:Array<StageObj> = [];
	var curSel:Int = -1;

	// ── Tab menu ─────────────────────────────────────────────────────────────
	var UI_box:FlxUITabMenu;
	var blockTyping:Array<FlxUIInputText> = [];

	// Import tab
	var importPathInput:FlxUIInputText;
	var stageNameInput:FlxUIInputText;
	var stageZoomStepper:FlxUINumericStepper;
	var stageCamSpeedStepper:FlxUINumericStepper;

	// Data tab
	var dataNameInput:FlxUIInputText;
	var dataColorInput:FlxUIInputText;
	var dataAnimPrefixInput:FlxUIInputText;
	var dataAnimNameInput:FlxUIInputText;
	var dataScrollXStepper:FlxUINumericStepper;
	var dataScrollYStepper:FlxUINumericStepper;
	var dataAboveCheck:FlxUICheckBox;
	var dataAACheck:FlxUICheckBox;
	var hideGFCheck:FlxUICheckBox;

	// Edit tab
	var editXStepper:FlxUINumericStepper;
	var editYStepper:FlxUINumericStepper;
	var editSXStepper:FlxUINumericStepper;
	var editSYStepper:FlxUINumericStepper;

	// ── Layer panel ───────────────────────────────────────────────────────────
	static inline var LP_W:Int  = 175;
	static inline var LP_H:Int  = 280;
	static inline var LP_IH:Int = 20;
	var layerGroup:FlxGroup;
	var layerEntries:Array<FlxText> = [];

	// ── Error text ────────────────────────────────────────────────────────────
	var errorText:FlxText;
	var errorTimer:FlxTimer;

	static inline var SLOW:Float = 2;
	static inline var FAST:Float = 10;

	// ─────────────────────────────────────────────────────────────────────────

	override function create()
	{
		super.create();

		editorCam = new FlxCamera();
		uiCam = new FlxCamera();
		uiCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.reset(editorCam);
		FlxG.cameras.add(uiCam, false);

		stageBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		stageBG.cameras = [editorCam];
		add(stageBG);

		spriteLayer = new FlxSpriteGroup();
		spriteLayer.cameras = [editorCam];
		add(spriteLayer);

		// Characters - always present
		dadChar = new Character(100, 200, 'dad');
		dadChar.setGraphicSize(Std.int(dadChar.width * 0.45));
		dadChar.updateHitbox();
		dadChar.cameras = [editorCam];
		add(dadChar);

		bfChar = new Character(700, 200, 'bf', true);
		bfChar.setGraphicSize(Std.int(bfChar.width * 0.45));
		bfChar.updateHitbox();
		bfChar.cameras = [editorCam];
		add(bfChar);

		gfChar = new Character(400, 230, 'gf');
		gfChar.setGraphicSize(Std.int(gfChar.width * 0.45));
		gfChar.updateHitbox();
		gfChar.cameras = [editorCam];
		add(gfChar);

		// Tab menu - same structure as ChartingState
		var tabs = [
			{name: 'Import', label: 'Import'},
			{name: 'Data',   label: 'Data'},
			{name: 'Edit',   label: 'Edit'},
		];
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(295, 430);
		UI_box.x = FlxG.width - UI_box.width - 8;
		UI_box.y = 20;
		UI_box.scrollFactor.set();
		UI_box.cameras = [uiCam];

		addImportTab();
		addDataTab();
		addEditTab();
		add(UI_box);

		buildLayerPanel();

		errorText = new FlxText(0, FlxG.height - 36, FlxG.width, '', 16);
		errorText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.RED, CENTER,
			flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		errorText.scrollFactor.set();
		errorText.cameras = [uiCam];
		errorText.visible = false;
		add(errorText);

		FlxG.mouse.visible = true;

		#if mobile
		addTouchPad('LEFT_FULL', 'A_B_C_E_F');
		if (touchPad != null) touchPad.cameras = [uiCam];
		#end

		refreshLayerPanel();
	}

	// ─── IMPORT TAB ──────────────────────────────────────────────────────────

	function addImportTab()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = 'Import';

		var pathLabel = new FlxText(10, 10, 270, 'Image path (no extension):', 9);
		importPathInput = new FlxUIInputText(10, 22, 270, 'stages/myStage/', 9);
		blockTyping.push(importPathInput);

		var solidBtn = mkBtn(10, 52, 'Add Solid Color', addSolid);
		var animBtn  = mkBtn(10, 84, 'Add Animation  (PNG + XML)', function() addAnim(importPathInput.text.trim()));
		var noAnimBtn= mkBtn(10, 116, 'Add No Animation  (PNG only)', function() addNoAnim(importPathInput.text.trim()));

		var sep = new FlxText(10, 152, 270, '─── Stage Settings ───', 9);
		sep.color = FlxColor.CYAN;

		var snLabel = new FlxText(10, 166, 270, 'Stage name (filename, no .json/.lua):', 9);
		stageNameInput = new FlxUIInputText(10, 178, 200, 'myStage', 9);
		blockTyping.push(stageNameInput);

		var zLabel = new FlxText(10, 200, 100, 'Default Zoom:', 9);
		stageZoomStepper = new FlxUINumericStepper(10, 212, 0.1, 1.0, 0.1, 10.0, 2);
		stageZoomStepper.name = 'stage_zoom';

		var csLabel = new FlxText(130, 200, 100, 'Camera Speed:', 9);
		stageCamSpeedStepper = new FlxUINumericStepper(130, 212, 50, 1000, 100, 9999, 0);
		stageCamSpeedStepper.name = 'stage_cs';

		tab.add(pathLabel);   tab.add(importPathInput);
		tab.add(solidBtn);    tab.add(animBtn);    tab.add(noAnimBtn);
		tab.add(sep);
		tab.add(snLabel);     tab.add(stageNameInput);
		tab.add(zLabel);      tab.add(stageZoomStepper);
		tab.add(csLabel);     tab.add(stageCamSpeedStepper);

		UI_box.addGroup(tab);
	}

	// ─── DATA TAB ────────────────────────────────────────────────────────────

	function addDataTab()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = 'Data';

		// Name
		tab.add(new FlxText(10, 8, 270, 'Lua variable name:', 9));
		dataNameInput = new FlxUIInputText(10, 20, 185, '', 9);
		blockTyping.push(dataNameInput);
		var nBtn = mkSmallBtn(200, 20, 'Set', function() {
			if (hasSel()) { objs[curSel].name = dataNameInput.text; refreshLayerPanel(); }
		});

		// Solid color
		tab.add(new FlxText(10, 44, 270, 'Solid color  (e.g. 0xFFRRGGBB):', 9));
		dataColorInput = new FlxUIInputText(10, 56, 185, '0xFFFFFFFF', 9);
		blockTyping.push(dataColorInput);
		var cBtn = mkSmallBtn(200, 56, 'Set', function() {
			if (!hasSel() || objs[curSel].type != SOLID) return;
			var col = Std.parseInt(dataColorInput.text);
			if (col == null) { showError('Bad hex color!'); return; }
			objs[curSel].solidColor = col;
			objs[curSel].sprite.makeGraphic(100, 100, col, true);
		});

		// Anim
		tab.add(new FlxText(10, 82, 270, 'XML prefix (exact name in XML file):', 9));
		dataAnimPrefixInput = new FlxUIInputText(10, 94, 270, '', 9);
		blockTyping.push(dataAnimPrefixInput);

		tab.add(new FlxText(10, 114, 270, 'Anim alias  (name used in Lua):', 9));
		dataAnimNameInput = new FlxUIInputText(10, 126, 185, '', 9);
		blockTyping.push(dataAnimNameInput);
		var addAnimBtn = mkSmallBtn(200, 126, 'Add', function() {
			if (!hasSel() || objs[curSel].type != ANIM) { showError('Select an Anim object first!'); return; }
			var pfx = dataAnimPrefixInput.text.trim();
			var als = dataAnimNameInput.text.trim();
			if (pfx.length == 0) { showError('Enter the XML prefix!'); return; }
			if (als.length == 0) als = pfx;
			objs[curSel].animPrefix = pfx;
			objs[curSel].animName   = als;
			if (objs[curSel].sprite.frames != null)
				objs[curSel].sprite.animation.addByPrefix(als, pfx, 24, true);
			showInfo('Anim added: ' + als);
		});

		// Scroll factor
		tab.add(new FlxText(10, 150, 270, 'Scroll Factor  (X / Y):', 9));
		dataScrollXStepper = new FlxUINumericStepper(10,  162, 0.1, 1.0, 0, 5, 2);
		dataScrollXStepper.name = 'data_sx';
		dataScrollYStepper = new FlxUINumericStepper(100, 162, 0.1, 1.0, 0, 5, 2);
		dataScrollYStepper.name = 'data_sy';

		// Flags
		dataAboveCheck = new FlxUICheckBox(10, 186, null, null, 'Above Characters', 130, function() {
			if (hasSel()) objs[curSel].aboveChars = dataAboveCheck.checked;
		});
		dataAACheck = new FlxUICheckBox(150, 186, null, null, 'Antialiasing', 100, function() {
			if (hasSel()) { objs[curSel].antialiasing = dataAACheck.checked; objs[curSel].sprite.antialiasing = dataAACheck.checked; }
		});
		dataAACheck.checked = true;

		hideGFCheck = new FlxUICheckBox(10, 210, null, null, 'Hide Girlfriend', 130, function() {
			gfChar.visible = !hideGFCheck.checked;
		});

		// Save - JSON and Lua separately, matching Blue.json / Blue.lua format
		var saveJsonBtn = mkBtn(10, 375, 'Save  myStage.json', saveJSON);
		saveJsonBtn.color = 0xFF2E7D32;
		saveJsonBtn.label.color = FlxColor.WHITE;

		var saveLuaBtn = mkBtn(10, 403, 'Save  myStage.lua', saveLua);
		saveLuaBtn.color = 0xFF1565C0;
		saveLuaBtn.label.color = FlxColor.WHITE;

		tab.add(dataNameInput);    tab.add(nBtn);
		tab.add(dataColorInput);   tab.add(cBtn);
		tab.add(dataAnimPrefixInput);
		tab.add(dataAnimNameInput); tab.add(addAnimBtn);
		tab.add(dataScrollXStepper); tab.add(dataScrollYStepper);
		tab.add(dataAboveCheck);   tab.add(dataAACheck);
		tab.add(hideGFCheck);
		tab.add(saveJsonBtn);
		tab.add(saveLuaBtn);

		UI_box.addGroup(tab);
	}

	// ─── EDIT TAB ────────────────────────────────────────────────────────────

	function addEditTab()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = 'Edit';

		tab.add(new FlxText(10, 8, 270, 'Position:', 9));
		tab.add(new FlxText(10,  20, 20, 'X:', 9));
		editXStepper = new FlxUINumericStepper(22,  18, 1, 0, -99999, 99999, 1);
		editXStepper.name = 'edit_x';
		tab.add(new FlxText(150, 20, 20, 'Y:', 9));
		editYStepper = new FlxUINumericStepper(162, 18, 1, 0, -99999, 99999, 1);
		editYStepper.name = 'edit_y';

		tab.add(new FlxText(10, 46, 270, 'Scale:', 9));
		tab.add(new FlxText(10,  58, 25, 'SX:', 9));
		editSXStepper = new FlxUINumericStepper(34,  56, 0.05, 1, 0.01, 50, 2);
		editSXStepper.name = 'edit_scx';
		tab.add(new FlxText(150, 58, 25, 'SY:', 9));
		editSYStepper = new FlxUINumericStepper(174, 56, 0.05, 1, 0.01, 50, 2);
		editSYStepper.name = 'edit_scy';

		var applyBtn = mkBtn(10, 84, 'Apply Transform', function() {
			if (!hasSel()) return;
			var s = objs[curSel].sprite;
			s.x = editXStepper.value;    objs[curSel].x = s.x;
			s.y = editYStepper.value;    objs[curSel].y = s.y;
			s.scale.set(editSXStepper.value, editSYStepper.value);
			s.updateHitbox();
			objs[curSel].scaleX = s.scale.x;
			objs[curSel].scaleY = s.scale.y;
		});

		var help = new FlxText(10, 116, 270,
			'Keyboard Controls:\n  Arrow keys  →  move slow\n  WASD  →  move fast\n\n' +
			'Mobile Controls:\n  Left pad arrows  →  move\n  Hold any arrow  →  fast\n  B  →  back to menu', 9);
		help.color = FlxColor.GRAY;

		tab.add(editXStepper); tab.add(editYStepper);
		tab.add(editSXStepper); tab.add(editSYStepper);
		tab.add(applyBtn);
		tab.add(help);

		UI_box.addGroup(tab);
	}

	// ─── getEvent ────────────────────────────────────────────────────────────

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var n:FlxUINumericStepper = cast sender;
			if (hasSel())
			{
				var s = objs[curSel].sprite;
				switch (n.name)
				{
					case 'edit_x':   s.x = n.value;        objs[curSel].x = n.value;
					case 'edit_y':   s.y = n.value;        objs[curSel].y = n.value;
					case 'edit_scx': s.scale.x = n.value;  objs[curSel].scaleX = n.value; s.updateHitbox();
					case 'edit_scy': s.scale.y = n.value;  objs[curSel].scaleY = n.value; s.updateHitbox();
					case 'data_sx':  objs[curSel].scrollX = n.value; s.scrollFactor.x = n.value;
					case 'data_sy':  objs[curSel].scrollY = n.value; s.scrollFactor.y = n.value;
				}
			}
		}
	}

	// ─── LAYER PANEL ─────────────────────────────────────────────────────────

	function buildLayerPanel()
	{
		layerGroup = new FlxGroup();
		layerGroup.cameras = [uiCam];

		var bg = new FlxSprite(4, 4).makeGraphic(LP_W, LP_H, 0xCC080812);
		bg.scrollFactor.set();
		layerGroup.add(bg);

		var upBtn = new FlxButton(4, LP_H + 6, "▲ Up", function() moveLayer(-1));
		upBtn.setGraphicSize(Std.int(LP_W / 2) - 2, 22); upBtn.updateHitbox(); upBtn.scrollFactor.set();
		layerGroup.add(upBtn);

		var dnBtn = new FlxButton(4 + Std.int(LP_W / 2) + 2, LP_H + 6, "▼ Down", function() moveLayer(1));
		dnBtn.setGraphicSize(Std.int(LP_W / 2) - 2, 22); dnBtn.updateHitbox(); dnBtn.scrollFactor.set();
		layerGroup.add(dnBtn);

		add(layerGroup);
	}

	function refreshLayerPanel()
	{
		for (t in layerEntries) { layerGroup.remove(t, true); t.destroy(); }
		layerEntries = [];

		// Characters locked at top
		for (i in 0...['[Dad]', '[BF]', '[GF]'].length)
		{
			var lbl = ['[Dad]', '[BF]', '[GF]'][i];
			var t = new FlxText(8, 6 + i * LP_IH, LP_W - 8, lbl, 10);
			t.setFormat(Paths.font('vcr.ttf'), 10, FlxColor.YELLOW, LEFT);
			t.scrollFactor.set();
			layerGroup.add(t); layerEntries.push(t);
		}

		for (i in 0...objs.length)
		{
			var o   = objs[i];
			var sel = (i == curSel);
			var t   = new FlxText(8, 6 + (3 + i) * LP_IH, LP_W - 8,
				(sel ? '► ' : '  ') + o.name + ' [' + typeChar(o.type) + ']', 10);
			t.setFormat(Paths.font('vcr.ttf'), 10, sel ? FlxColor.CYAN : FlxColor.WHITE, LEFT);
			t.scrollFactor.set();
			layerGroup.add(t); layerEntries.push(t);
		}
	}

	inline function typeChar(t:StageObjType):String
		return switch(t) { case SOLID: 'S'; case ANIM: 'A'; case NO_ANIM: 'I'; }

	function moveLayer(dir:Int)
	{
		if (!hasSel()) return;
		var tgt = curSel + dir;
		if (tgt < 0 || tgt >= objs.length) return;
		var tmp = objs[curSel]; objs[curSel] = objs[tgt]; objs[tgt] = tmp;
		curSel = tgt;
		rebuildSpriteLayer();
		refreshLayerPanel();
	}

	function rebuildSpriteLayer()
	{
		spriteLayer.clear();
		for (o in objs) spriteLayer.add(o.sprite);
	}

	// ─── OBJECT CREATION ─────────────────────────────────────────────────────

	function addSolid()
	{
		var spr = new FlxSprite(200, 200);
		spr.makeGraphic(100, 100, FlxColor.WHITE);
		spr.cameras = [editorCam];
		spriteLayer.add(spr);
		pushObj(spr, SOLID, '', 0xFFFFFFFF);
	}

	function addAnim(path:String)
	{
		if (path.length == 0) { showError('Enter an image path!'); return; }
		path = stripSlash(path);

		if (!openfl.utils.Assets.exists(Paths.getSharedPath('images/' + path + '.png')))
		{ showError('PNG not found:\nimages/' + path + '.png'); return; }

		if (!openfl.utils.Assets.exists(Paths.getSharedPath('images/' + path + '.xml')))
		{ showError('XML not found:\nimages/' + path + '.xml\nThe PNG and XML must have the same name!'); return; }

		var spr = new FlxSprite(200, 200);
		try { spr.frames = Paths.getSparrowAtlas(path); }
		catch (e:Dynamic) { showError('Atlas error: ' + e); return; }
		spr.antialiasing = true;
		spr.cameras = [editorCam];
		spriteLayer.add(spr);
		pushObj(spr, ANIM, path, 0);
	}

	function addNoAnim(path:String)
	{
		if (path.length == 0) { showError('Enter an image path!'); return; }
		path = stripSlash(path);

		if (!openfl.utils.Assets.exists(Paths.getSharedPath('images/' + path + '.png')))
		{ showError('PNG not found:\nimages/' + path + '.png'); return; }

		var spr = new FlxSprite(200, 200);
		try { spr.loadGraphic(Paths.image(path)); }
		catch (e:Dynamic) { showError('Image error: ' + e); return; }
		spr.antialiasing = true;
		spr.cameras = [editorCam];
		spriteLayer.add(spr);
		pushObj(spr, NO_ANIM, path, 0);
	}

	function pushObj(spr:FlxSprite, t:StageObjType, path:String, col:Int)
	{
		var prefix = switch(t) { case SOLID: 'solid'; case ANIM: 'anim'; case NO_ANIM: 'img'; };
		objs.push({
			name: prefix + objs.length,
			type: t, sprite: spr,
			imagePath: path, animPrefix: '', animName: '',
			solidColor: col,
			x: 200, y: 200, scaleX: 1, scaleY: 1,
			scrollX: 1, scrollY: 1,
			aboveChars: false, antialiasing: true
		});
		selectObj(objs.length - 1);
	}

	function selectObj(i:Int)
	{
		curSel = i;
		refreshLayerPanel();
		if (!hasSel()) return;
		var o = objs[i];
		editXStepper.value       = o.x;
		editYStepper.value       = o.y;
		editSXStepper.value      = o.scaleX;
		editSYStepper.value      = o.scaleY;
		dataNameInput.text       = o.name;
		dataColorInput.text      = '0x' + StringTools.hex(o.solidColor, 8).toUpperCase();
		dataAnimPrefixInput.text = o.animPrefix;
		dataAnimNameInput.text   = o.animName;
		dataScrollXStepper.value = o.scrollX;
		dataScrollYStepper.value = o.scrollY;
		dataAboveCheck.checked   = o.aboveChars;
		dataAACheck.checked      = o.antialiasing;
	}

	// ─── UPDATE ──────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// Layer panel click selection
		#if FLX_MOUSE
		if (FlxG.mouse.justPressed)
		{
			for (i in 0...objs.length)
			{
				var t = layerEntries[3 + i];
				if (t != null && FlxG.mouse.overlaps(t, uiCam)) { selectObj(i); break; }
			}
		}
		#end

		var typing = false;
		for (inp in blockTyping) if (inp.hasFocus) { typing = true; break; }
		if (typing) return;

		#if !mobile
		if (hasSel())
		{
			var s   = objs[curSel].sprite;
			var spd = (FlxG.keys.pressed.W || FlxG.keys.pressed.A ||
			           FlxG.keys.pressed.S || FlxG.keys.pressed.D) ? FAST : SLOW;
			if (FlxG.keys.pressed.LEFT  || FlxG.keys.pressed.A) { s.x -= spd; objs[curSel].x = s.x; }
			if (FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.D) { s.x += spd; objs[curSel].x = s.x; }
			if (FlxG.keys.pressed.UP    || FlxG.keys.pressed.W) { s.y -= spd; objs[curSel].y = s.y; }
			if (FlxG.keys.pressed.DOWN  || FlxG.keys.pressed.S) { s.y += spd; objs[curSel].y = s.y; }
			editXStepper.value = s.x;
			editYStepper.value = s.y;
		}
		if (FlxG.keys.justPressed.ESCAPE)
		{
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new MasterEditorMenu());
		}
		#end

		#if mobile
		if (touchPad != null && hasSel())
		{
			var s   = objs[curSel].sprite;
			var holding = touchPad.buttonLeft.pressed || touchPad.buttonRight.pressed ||
			              touchPad.buttonUp.pressed   || touchPad.buttonDown.pressed;
			var spd = holding ? FAST : SLOW;
			if (touchPad.buttonLeft.pressed)  { s.x -= spd; objs[curSel].x = s.x; }
			if (touchPad.buttonRight.pressed) { s.x += spd; objs[curSel].x = s.x; }
			if (touchPad.buttonUp.pressed)    { s.y -= spd; objs[curSel].y = s.y; }
			if (touchPad.buttonDown.pressed)  { s.y += spd; objs[curSel].y = s.y; }
			editXStepper.value = s.x;
			editYStepper.value = s.y;
		}
		if (touchPad != null && touchPad.buttonB.justPressed)
		{
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new MasterEditorMenu());
		}
		#end
	}

	// ─── SAVE JSON  (matches Blue.json exactly) ───────────────────────────────

	function saveJSON()
	{
		var name = stageName();

		// Build raw JSON string manually so key order matches the template
		var sb = new StringBuf();
		sb.add('{\n');
		sb.add('\t"directory": "",\n');
		sb.add('\t"defaultZoom": ' + stageZoomStepper.value + ',\n');
		sb.add('\t"isPixelStage": false,\n');
		sb.add('\t"hide_girlfriend": ' + (hideGFCheck.checked ? 'true' : 'false') + ',\n');
		sb.add('\t"camera_speed": ' + Std.int(stageCamSpeedStepper.value) + ',\n');
		sb.add('\n');
		sb.add('\t"boyfriend":  [' + Std.int(bfChar.x)  + ', ' + Std.int(bfChar.y)  + '],\n');
		sb.add('\t"girlfriend": [' + Std.int(gfChar.x)  + ', ' + Std.int(gfChar.y)  + '],\n');
		sb.add('\t"opponent":   [' + Std.int(dadChar.x) + ', ' + Std.int(dadChar.y) + '],\n');
		sb.add('\n');
		sb.add('\t"camera_boyfriend":  [-200, 40],\n');
		sb.add('\t"camera_opponent":   [100, -35],\n');
		sb.add('\t"camera_girlfriend": [225, 0]\n');
		sb.add('}');

		doSave(name + '.json', sb.toString());
	}

	// ─── SAVE LUA  (matches Blue.lua exactly) ────────────────────────────────

	function saveLua()
	{
		var sb = new StringBuf();
		sb.add('function onCreate()\n');

		for (obj in objs)
		{
			switch (obj.type)
			{
				case NO_ANIM:
					sb.add('\tmakeLuaSprite(\'' + obj.name + '\', \'' + obj.imagePath + '\', '
						+ Std.int(obj.x) + ', ' + Std.int(obj.y) + ')\n');

				case ANIM:
					sb.add('\tmakeAnimatedLuaSprite(\'' + obj.name + '\', \'' + obj.imagePath + '\', '
						+ Std.int(obj.x) + ', ' + Std.int(obj.y) + ')\n');
					if (obj.animName.length > 0)
						sb.add('\taddAnimationByPrefix(\'' + obj.name + '\', \'' + obj.animName
							+ '\', \'' + obj.animPrefix + '\', 24, true)\n');

				case SOLID:
					// solid color sprite - no image, just a colored rectangle via makeGraphic
					sb.add('\tmakeLuaSprite(\'' + obj.name + '\', nil, '
						+ Std.int(obj.x) + ', ' + Std.int(obj.y) + ')\n');
					sb.add('\tmakeGraphic(\'' + obj.name + '\', 100, 100, \''
						+ StringTools.hex(obj.solidColor & 0xFFFFFF, 6).toUpperCase() + '\')\n');
			}

			// Scale
			if (obj.scaleX != 1 || obj.scaleY != 1)
				sb.add('\tscaleObject(\'' + obj.name + '\', '
					+ trimFloat(obj.scaleX) + ', ' + trimFloat(obj.scaleY) + ')\n');

			// Scroll factor
			if (obj.scrollX != 1 || obj.scrollY != 1)
				sb.add('\tsetScrollFactor(\'' + obj.name + '\', '
					+ trimFloat(obj.scrollX) + ', ' + trimFloat(obj.scrollY) + ')\n');

			// Antialiasing
			if (!obj.antialiasing)
				sb.add('\tsetProperty(\'' + obj.name + '.antialiasing\', false)\n');

			sb.add('\taddLuaSprite(\'' + obj.name + '\', ' + (obj.aboveChars ? 'true' : 'false') + ')\n\n');
		}

		sb.add('end\n\n');
		sb.add('function onBeatHit()\nend\n\n');
		sb.add('function onUpdate(elapsed)\nend\n');

		doSave(stageName() + '.lua', sb.toString());
	}

	// ─── HELPERS ─────────────────────────────────────────────────────────────

	inline function hasSel():Bool   return curSel >= 0 && curSel < objs.length;
	inline function stageName():String { var n = stageNameInput.text.trim(); return n.length > 0 ? n : 'myStage'; }
	inline function stripSlash(s:String):String return (s.length > 0 && s.charAt(s.length - 1) == '/') ? s.substr(0, s.length - 1) : s;
	inline function trimFloat(v:Float):String { var s = Std.string(v); return s; }

	function mkBtn(x:Float, y:Float, lbl:String, cb:Void->Void):FlxButton
	{
		var b = new FlxButton(x, y, lbl, cb);
		b.setGraphicSize(270, 26); b.updateHitbox();
		return b;
	}
	function mkSmallBtn(x:Float, y:Float, lbl:String, cb:Void->Void):FlxButton
	{
		var b = new FlxButton(x, y, lbl, cb);
		b.setGraphicSize(75, 20); b.updateHitbox();
		return b;
	}

	function showError(msg:String)
	{
		errorText.text    = msg;
		errorText.color   = FlxColor.RED;
		errorText.visible = true;
		if (errorTimer != null) errorTimer.cancel();
		errorTimer = new FlxTimer().start(4, function(_) errorText.visible = false);
	}
	function showInfo(msg:String)
	{
		errorText.text    = msg;
		errorText.color   = FlxColor.LIME;
		errorText.visible = true;
		if (errorTimer != null) errorTimer.cancel();
		errorTimer = new FlxTimer().start(3, function(_) errorText.visible = false);
	}

	function doSave(fileName:String, content:String)
	{
		#if mobile
		StorageUtil.saveContent(fileName, content);
		showInfo('Saved: ' + fileName);
		#else
		var f = new openfl.net.FileReference();
		f.save(content, fileName);
		#end
	}

	override function destroy() super.destroy();
}
