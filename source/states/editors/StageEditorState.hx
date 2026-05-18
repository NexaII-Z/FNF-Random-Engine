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
import flixel.math.FlxMath;
import flixel.tweens.FlxTween;

import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUINumericStepper;

import objects.Character;
import backend.StageData;

using StringTools;

// ─── Types ───────────────────────────────────────────────────────────────────

enum StageObjType { SOLID; ANIM; NO_ANIM; CHARACTER; }

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
	var ?charRef:String; // 'dad' | 'bf' | 'gf' for CHARACTER type
}

// ─────────────────────────────────────────────────────────────────────────────

class StageEditorState extends MusicBeatState
{
	// ── Cameras ──────────────────────────────────────────────────────────────
	var editorCam:FlxCamera;
	var uiCam:FlxCamera;

	// Editor zoom & pan
	var editorZoom:Float  = 1.0;
	var camPanMode:Bool   = false; // toggled by C button
	var camPanLabel:FlxText;

	// ── Scene ────────────────────────────────────────────────────────────────
	var stageBG:FlxSprite;
	var spriteLayer:FlxSpriteGroup;
	var dadChar:Character;
	var bfChar:Character;
	var gfChar:Character;

	// ── Objects (includes CHARACTER entries for Dad/BF/GF) ───────────────────
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
	var stageLoaderInput:FlxUIInputText;

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
	// Character position steppers in Data tab
	var charXStepper:FlxUINumericStepper;
	var charYStepper:FlxUINumericStepper;

	// Edit tab
	var editXStepper:FlxUINumericStepper;
	var editYStepper:FlxUINumericStepper;
	var editSXStepper:FlxUINumericStepper;
	var editSYStepper:FlxUINumericStepper;

	// ── Layer panel ───────────────────────────────────────────────────────────
	static inline var LP_W:Int  = 180;
	static inline var LP_H:Int  = 300;
	static inline var LP_IH:Int = 20;
	var layerGroup:FlxGroup;
	var layerEntries:Array<FlxText> = [];

	// ── Error text ────────────────────────────────────────────────────────────
	var errorText:FlxText;
	var errorTimer:FlxTimer;

	static inline var SLOW:Float = 2;
	static inline var FAST:Float = 10;

	// ── Tab box dimensions ────────────────────────────────────────────────────
	static inline var TAB_W:Int = 280;
	static inline var TAB_H:Int = 460;
	static inline var INNER:Int = 260; // usable width inside tab

	// ─────────────────────────────────────────────────────────────────────────

	override function create()
	{
		super.create();

		editorCam = new FlxCamera();
		uiCam     = new FlxCamera();
		uiCam.bgColor = FlxColor.TRANSPARENT;
		FlxG.cameras.reset(editorCam);
		FlxG.cameras.add(uiCam, false);

		stageBG = new FlxSprite().makeGraphic(FlxG.width * 3, FlxG.height * 3, FlxColor.BLACK);
		stageBG.x = -FlxG.width;
		stageBG.y = -FlxG.height;
		stageBG.cameras = [editorCam];
		add(stageBG);

		spriteLayer = new FlxSpriteGroup();
		spriteLayer.cameras = [editorCam];
		add(spriteLayer);

		// ── Characters — correct Psych Engine default positions ───────────────
		// Dad: left side, BF: right side, GF: center (on speaker)
		dadChar = new Character(100, 300, 'dad');
		dadChar.setGraphicSize(Std.int(dadChar.width * 0.5));
		dadChar.updateHitbox();
		dadChar.cameras = [editorCam];
		add(dadChar);

		gfChar = new Character(400, 310, 'gf');
		gfChar.setGraphicSize(Std.int(gfChar.width * 0.5));
		gfChar.updateHitbox();
		gfChar.cameras = [editorCam];
		add(gfChar);

		bfChar = new Character(650, 300, 'bf', true);
		bfChar.setGraphicSize(Std.int(bfChar.width * 0.5));
		bfChar.updateHitbox();
		bfChar.cameras = [editorCam];
		add(bfChar);

		// Add character entries to objs so they appear in layer panel
		objs.push({ name:'Dad',  type:CHARACTER, sprite:dadChar, imagePath:'', animPrefix:'', animName:'',
			solidColor:0, x:dadChar.x, y:dadChar.y, scaleX:0.5, scaleY:0.5,
			scrollX:1, scrollY:1, aboveChars:false, antialiasing:true, charRef:'dad' });
		objs.push({ name:'GF',   type:CHARACTER, sprite:gfChar,  imagePath:'', animPrefix:'', animName:'',
			solidColor:0, x:gfChar.x,  y:gfChar.y,  scaleX:0.5, scaleY:0.5,
			scrollX:1, scrollY:1, aboveChars:false, antialiasing:true, charRef:'gf' });
		objs.push({ name:'BF',   type:CHARACTER, sprite:bfChar,  imagePath:'', animPrefix:'', animName:'',
			solidColor:0, x:bfChar.x,  y:bfChar.y,  scaleX:0.5, scaleY:0.5,
			scrollX:1, scrollY:1, aboveChars:false, antialiasing:true, charRef:'bf' });

		// ── Tab menu ──────────────────────────────────────────────────────────
		var tabs = [
			{name:'Import', label:'Import'},
			{name:'Data',   label:'Data'},
			{name:'Edit',   label:'Edit'},
		];
		UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.resize(TAB_W, TAB_H);
		UI_box.x = FlxG.width - TAB_W - 8;
		UI_box.y = 20;
		UI_box.scrollFactor.set();
		UI_box.cameras = [uiCam];

		addImportTab();
		addDataTab();
		addEditTab();
		add(UI_box);

		buildLayerPanel();

		// ── Cam pan mode label ────────────────────────────────────────────────
		camPanLabel = new FlxText(LP_W + 10, FlxG.height - 24, 200, 'PAN MODE: OFF', 12);
		camPanLabel.setFormat(Paths.font('vcr.ttf'), 12, FlxColor.GRAY, LEFT);
		camPanLabel.cameras = [uiCam];
		camPanLabel.scrollFactor.set();
		add(camPanLabel);

		// ── Error text ────────────────────────────────────────────────────────
		errorText = new FlxText(0, FlxG.height - 44, FlxG.width, '', 14);
		errorText.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.RED, CENTER,
			flixel.text.FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		errorText.scrollFactor.set();
		errorText.cameras = [uiCam];
		errorText.visible = false;
		add(errorText);

		FlxG.mouse.visible = true;

		// ── Mobile: A_B_C_X_Y ─────────────────────────────────────────────────
		// A = idle chars, B = back, C = toggle pan, X = zoom out, Y = zoom in
		#if mobile
		addTouchPad('LEFT_FULL', 'A_B_C_X_Y');
		if (touchPad != null) touchPad.cameras = [uiCam];
		#end

		refreshLayerPanel();
	}

	// ─────────────────────────────────────────────────────────────────────────
	// IMPORT TAB
	// ─────────────────────────────────────────────────────────────────────────

	function addImportTab()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = 'Import';

		var y = 10;

		// Path input
		tab.add(mkLabel(10, y, 'Image path (no extension):'));
		y += 12;
		importPathInput = new FlxUIInputText(10, y, INNER, 'stages/myStage/bg', 9);
		blockTyping.push(importPathInput);
		tab.add(importPathInput);
		y += 20;

		// Add buttons — each on its own row so text fits
		var solidBtn  = mkWideBtn(10, y, 'Add Solid Color',           addSolid);             y += 30;
		var animBtn   = mkWideBtn(10, y, 'Add Animation (PNG+XML)',    function() addAnim(importPathInput.text.trim()));  y += 30;
		var noAnimBtn = mkWideBtn(10, y, 'Add No Animation (PNG only)',function() addNoAnim(importPathInput.text.trim())); y += 36;

		tab.add(solidBtn); tab.add(animBtn); tab.add(noAnimBtn);

		// Stage settings divider
		var sep = mkLabel(10, y, '── Stage Settings ──');
		sep.color = FlxColor.CYAN;
		tab.add(sep); y += 16;

		tab.add(mkLabel(10, y, 'Stage filename (no .json/.lua):'));  y += 12;
		stageNameInput = new FlxUIInputText(10, y, INNER, 'myStage', 9);
		blockTyping.push(stageNameInput);
		tab.add(stageNameInput); y += 22;

		tab.add(mkLabel(10, y, 'Default Zoom:')); tab.add(mkLabel(130, y, 'Camera Speed:'));
		y += 12;
		stageZoomStepper = new FlxUINumericStepper(10, y, 0.1, 1.0, 0.1, 10.0, 2);
		stageZoomStepper.name = 'stage_zoom';
		stageCamSpeedStepper = new FlxUINumericStepper(130, y, 50, 1000, 100, 9999, 0);
		stageCamSpeedStepper.name = 'stage_cs';
		tab.add(stageZoomStepper); tab.add(stageCamSpeedStepper); y += 36;

		// Stage loader
		var sep2 = mkLabel(10, y, '── Load Existing Stage ──');
		sep2.color = FlxColor.YELLOW;
		tab.add(sep2); y += 16;

		tab.add(mkLabel(10, y, 'Stage name to load:'));  y += 12;
		stageLoaderInput = new FlxUIInputText(10, y, INNER, 'stage', 9);
		blockTyping.push(stageLoaderInput);
		tab.add(stageLoaderInput); y += 22;

		var loadBtn = mkWideBtn(10, y, 'Load Stage', function() loadStage(stageLoaderInput.text.trim()));
		loadBtn.color = 0xFF5D4037;
		loadBtn.label.color = FlxColor.WHITE;
		tab.add(loadBtn);

		UI_box.addGroup(tab);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// DATA TAB
	// ─────────────────────────────────────────────────────────────────────────

	function addDataTab()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = 'Data';

		var y = 10;

		// Name
		tab.add(mkLabel(10, y, 'Lua variable name:')); y += 12;
		dataNameInput = new FlxUIInputText(10, y, 185, '', 9);
		blockTyping.push(dataNameInput);
		var nBtn = mkSmallBtn(200, y, 'Set', function() {
			if (hasSel()) { objs[curSel].name = dataNameInput.text; refreshLayerPanel(); }
		});
		tab.add(dataNameInput); tab.add(nBtn); y += 22;

		// Solid color
		tab.add(mkLabel(10, y, 'Solid color (0xFFRRGGBB):')); y += 12;
		dataColorInput = new FlxUIInputText(10, y, 185, '0xFFFFFFFF', 9);
		blockTyping.push(dataColorInput);
		var cBtn = mkSmallBtn(200, y, 'Set', function() {
			if (!hasSel() || objs[curSel].type != SOLID) return;
			var col = Std.parseInt(dataColorInput.text);
			if (col == null) { showError('Bad hex!'); return; }
			objs[curSel].solidColor = col;
			objs[curSel].sprite.makeGraphic(100, 100, col, true);
		});
		tab.add(dataColorInput); tab.add(cBtn); y += 22;

		// Anim prefix
		tab.add(mkLabel(10, y, 'XML prefix (exact name in XML):')); y += 12;
		dataAnimPrefixInput = new FlxUIInputText(10, y, INNER, '', 9);
		blockTyping.push(dataAnimPrefixInput);
		tab.add(dataAnimPrefixInput); y += 22;

		// Anim alias
		tab.add(mkLabel(10, y, 'Anim alias (name in Lua):')); y += 12;
		dataAnimNameInput = new FlxUIInputText(10, y, 185, '', 9);
		blockTyping.push(dataAnimNameInput);
		var addAnimBtn = mkSmallBtn(200, y, 'Add', function() {
			if (!hasSel() || objs[curSel].type != ANIM) { showError('Select Anim object first!'); return; }
			var pfx = dataAnimPrefixInput.text.trim();
			var als = dataAnimNameInput.text.trim();
			if (pfx.length == 0) { showError('Enter XML prefix!'); return; }
			if (als.length == 0) als = pfx;
			objs[curSel].animPrefix = pfx;
			objs[curSel].animName   = als;
			if (objs[curSel].sprite.frames != null)
				objs[curSel].sprite.animation.addByPrefix(als, pfx, 24, true);
			showInfo('Anim added: ' + als);
		});
		tab.add(dataAnimNameInput); tab.add(addAnimBtn); y += 22;

		// Scroll factor
		tab.add(mkLabel(10, y, 'Scroll X:')); tab.add(mkLabel(120, y, 'Scroll Y:')); y += 12;
		dataScrollXStepper = new FlxUINumericStepper(10, y, 0.1, 1.0, 0, 5, 2);
		dataScrollXStepper.name = 'data_sx';
		dataScrollYStepper = new FlxUINumericStepper(120, y, 0.1, 1.0, 0, 5, 2);
		dataScrollYStepper.name = 'data_sy';
		tab.add(dataScrollXStepper); tab.add(dataScrollYStepper); y += 28;

		// Flags
		dataAboveCheck = new FlxUICheckBox(10, y, null, null, 'Above Characters', 120, function() {
			if (hasSel()) objs[curSel].aboveChars = dataAboveCheck.checked;
		});
		dataAACheck = new FlxUICheckBox(140, y, null, null, 'Antialiasing', 100, function() {
			if (hasSel()) { objs[curSel].antialiasing = dataAACheck.checked; objs[curSel].sprite.antialiasing = dataAACheck.checked; }
		});
		dataAACheck.checked = true;
		tab.add(dataAboveCheck); tab.add(dataAACheck); y += 24;

		hideGFCheck = new FlxUICheckBox(10, y, null, null, 'Hide Girlfriend', 130, function() {
			gfChar.visible = !hideGFCheck.checked;
		});
		tab.add(hideGFCheck); y += 28;

		// ── Character position section ────────────────────────────────────────
		var charSep = mkLabel(10, y, '── Character Position ──');
		charSep.color = FlxColor.CYAN;
		tab.add(charSep); y += 16;

		tab.add(mkLabel(10, y, 'X:')); tab.add(mkLabel(120, y, 'Y:')); y += 12;
		charXStepper = new FlxUINumericStepper(10, y, 5, 0, -9999, 9999, 0);
		charXStepper.name = 'char_x';
		charYStepper = new FlxUINumericStepper(120, y, 5, 0, -9999, 9999, 0);
		charYStepper.name = 'char_y';
		tab.add(charXStepper); tab.add(charYStepper); y += 28;

		var applyCharBtn = mkWideBtn(10, y, 'Apply Char Position', function() {
			if (!hasSel() || objs[curSel].type != CHARACTER) { showError('Select a character first!'); return; }
			objs[curSel].sprite.x = charXStepper.value;
			objs[curSel].sprite.y = charYStepper.value;
			objs[curSel].x = charXStepper.value;
			objs[curSel].y = charYStepper.value;
		});
		tab.add(applyCharBtn); y += 34;

		// Save buttons
		var saveJsonBtn = mkWideBtn(10, y, 'Save  myStage.json', saveJSON);
		saveJsonBtn.color = 0xFF2E7D32;
		saveJsonBtn.label.color = FlxColor.WHITE;
		tab.add(saveJsonBtn); y += 30;

		var saveLuaBtn = mkWideBtn(10, y, 'Save  myStage.lua', saveLua);
		saveLuaBtn.color = 0xFF1565C0;
		saveLuaBtn.label.color = FlxColor.WHITE;
		tab.add(saveLuaBtn);

		UI_box.addGroup(tab);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// EDIT TAB
	// ─────────────────────────────────────────────────────────────────────────

	function addEditTab()
	{
		var tab = new FlxUI(null, UI_box);
		tab.name = 'Edit';

		var y = 10;

		tab.add(mkLabel(10, y, 'Position:')); y += 12;
		tab.add(mkLabel(10, y, 'X:'));
		editXStepper = new FlxUINumericStepper(22, y, 1, 0, -99999, 99999, 1);
		editXStepper.name = 'edit_x';
		tab.add(mkLabel(130, y, 'Y:'));
		editYStepper = new FlxUINumericStepper(142, y, 1, 0, -99999, 99999, 1);
		editYStepper.name = 'edit_y';
		tab.add(editXStepper); tab.add(editYStepper); y += 28;

		tab.add(mkLabel(10, y, 'Scale:')); y += 12;
		tab.add(mkLabel(10, y, 'SX:'));
		editSXStepper = new FlxUINumericStepper(30, y, 0.05, 1, 0.01, 50, 2);
		editSXStepper.name = 'edit_scx';
		tab.add(mkLabel(130, y, 'SY:'));
		editSYStepper = new FlxUINumericStepper(150, y, 0.05, 1, 0.01, 50, 2);
		editSYStepper.name = 'edit_scy';
		tab.add(editSXStepper); tab.add(editSYStepper); y += 28;

		var applyBtn = mkWideBtn(10, y, 'Apply Transform', function() {
			if (!hasSel()) return;
			var s = objs[curSel].sprite;
			if (editXStepper.value  != 0) { s.x = editXStepper.value;  objs[curSel].x = s.x; }
			if (editYStepper.value  != 0) { s.y = editYStepper.value;  objs[curSel].y = s.y; }
			if (editSXStepper.value != 0) { s.scale.x = editSXStepper.value; objs[curSel].scaleX = s.scale.x; s.updateHitbox(); }
			if (editSYStepper.value != 0) { s.scale.y = editSYStepper.value; objs[curSel].scaleY = s.scale.y; s.updateHitbox(); }
		});
		tab.add(applyBtn); y += 34;

		// Visibility toggle when value is 0
		tab.add(mkLabel(10, y, 'Tip: value 0 = hide object', 8)); y += 16;

		var helpTxt = mkLabel(10, y,
			'Keys: Arrows = slow move\n' +
			'WASD = fast move\n' +
			'X = zoom out  Y = zoom in\n' +
			'C = toggle cam pan\n' +
			'A = play idle anims\n' +
			'B = back', 8);
		helpTxt.color = FlxColor.GRAY;
		tab.add(helpTxt);

		UI_box.addGroup(tab);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// getEvent
	// ─────────────────────────────────────────────────────────────────────────

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var n:FlxUINumericStepper = cast sender;
			if (!hasSel()) return;
			var s = objs[curSel].sprite;
			switch (n.name)
			{
				case 'edit_x':   if (n.value != 0) { s.x = n.value; objs[curSel].x = n.value; s.visible = true; }
				                 else s.visible = false;
				case 'edit_y':   if (n.value != 0) { s.y = n.value; objs[curSel].y = n.value; s.visible = true; }
				                 else s.visible = false;
				case 'edit_scx': if (n.value != 0) { s.scale.x = n.value; objs[curSel].scaleX = n.value; s.updateHitbox(); }
				case 'edit_scy': if (n.value != 0) { s.scale.y = n.value; objs[curSel].scaleY = n.value; s.updateHitbox(); }
				case 'data_sx':  objs[curSel].scrollX = n.value; s.scrollFactor.x = n.value;
				case 'data_sy':  objs[curSel].scrollY = n.value; s.scrollFactor.y = n.value;
				case 'char_x':   if (objs[curSel].type == CHARACTER) { s.x = n.value; objs[curSel].x = n.value; }
				case 'char_y':   if (objs[curSel].type == CHARACTER) { s.y = n.value; objs[curSel].y = n.value; }
			}
		}
	}

	// ─────────────────────────────────────────────────────────────────────────
	// LAYER PANEL
	// ─────────────────────────────────────────────────────────────────────────

	function buildLayerPanel()
	{
		layerGroup = new FlxGroup();
		layerGroup.cameras = [uiCam];

		var bg = new FlxSprite(4, 4).makeGraphic(LP_W, LP_H, 0xCC080812);
		bg.scrollFactor.set();
		layerGroup.add(bg);

		// Up / Down buttons
		var upBtn = new FlxButton(4, LP_H + 6, '▲ Up', function() {
			if (!hasSel() || objs[curSel].type == CHARACTER)
			{
				showError('Select a non-character object first!');
				return;
			}
			moveLayer(-1);
		});
		upBtn.setGraphicSize(Std.int(LP_W / 2) - 2, 22);
		upBtn.updateHitbox();
		upBtn.scrollFactor.set();
		layerGroup.add(upBtn);

		var dnBtn = new FlxButton(4 + Std.int(LP_W / 2) + 2, LP_H + 6, '▼ Down', function() {
			if (!hasSel() || objs[curSel].type == CHARACTER)
			{
				showError('Select a non-character object first!');
				return;
			}
			moveLayer(1);
		});
		dnBtn.setGraphicSize(Std.int(LP_W / 2) - 2, 22);
		dnBtn.updateHitbox();
		dnBtn.scrollFactor.set();
		layerGroup.add(dnBtn);

		add(layerGroup);
	}

	function refreshLayerPanel()
	{
		for (t in layerEntries) { layerGroup.remove(t, true); t.destroy(); }
		layerEntries = [];

		for (i in 0...objs.length)
		{
			var o   = objs[i];
			var sel = (i == curSel);
			var col = switch(o.type)
			{
				case CHARACTER: FlxColor.YELLOW;
				case _:         sel ? FlxColor.CYAN : FlxColor.WHITE;
			};
			var prefix = sel ? '► ' : '  ';
			var typeTag = switch(o.type)
			{
				case SOLID: '[S]'; case ANIM: '[A]'; case NO_ANIM: '[I]'; case CHARACTER: '[C]';
			};
			var t = new FlxText(8, 6 + i * LP_IH, LP_W - 8, prefix + o.name + ' ' + typeTag, 10);
			t.setFormat(Paths.font('vcr.ttf'), 10, col, LEFT);
			t.scrollFactor.set();
			layerGroup.add(t);
			layerEntries.push(t);
		}
	}

	function moveLayer(dir:Int)
	{
		if (!hasSel()) return;
		var tgt = curSel + dir;
		// Don't swap into the CHARACTER entries (first 3)
		if (tgt < 3 || tgt >= objs.length) return;
		var tmp = objs[curSel]; objs[curSel] = objs[tgt]; objs[tgt] = tmp;
		curSel = tgt;
		rebuildSpriteLayer();
		refreshLayerPanel();
	}

	function rebuildSpriteLayer()
	{
		spriteLayer.clear();
		for (o in objs)
			if (o.type != CHARACTER)
				spriteLayer.add(o.sprite);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// OBJECT CREATION
	// ─────────────────────────────────────────────────────────────────────────

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

		// Check both mod folder and shared folder
		var pngFound = checkAssetExists('images/' + path + '.png');
		var xmlFound = checkAssetExists('images/' + path + '.xml');

		if (!pngFound) { showError('PNG not found:\nimages/' + path + '.png'); return; }
		if (!xmlFound) { showError('XML not found:\nimages/' + path + '.xml'); return; }

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

		var pngFound = checkAssetExists('images/' + path + '.png');
		if (!pngFound) { showError('PNG not found:\nimages/' + path + '.png'); return; }

		var spr = new FlxSprite(200, 200);
		try { spr.loadGraphic(Paths.image(path)); }
		catch (e:Dynamic) { showError('Image error: ' + e); return; }
		spr.antialiasing = true;
		spr.cameras = [editorCam];
		spriteLayer.add(spr);
		pushObj(spr, NO_ANIM, path, 0);
	}

	/**
	 * Checks shared AND active mod folder for an asset.
	 * Fixes the mod image not found bug.
	 */
	function checkAssetExists(relativePath:String):Bool
	{
		// Check shared path
		if (openfl.utils.Assets.exists(Paths.getSharedPath(relativePath))) return true;
		// Check active mod folder
		#if MODS_ALLOWED
		var modPath = Paths.mods(relativePath);
		if (sys.FileSystem.exists(modPath)) return true;
		// Check mod directory
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
		{
			var dirPath = Paths.mods(Mods.currentModDirectory + '/' + relativePath);
			if (sys.FileSystem.exists(dirPath)) return true;
		}
		#end
		return false;
	}

	function pushObj(spr:FlxSprite, t:StageObjType, path:String, col:Int)
	{
		var prefix = switch(t) { case SOLID:'solid'; case ANIM:'anim'; case NO_ANIM:'img'; case CHARACTER:'char'; };
		objs.push({
			name: prefix + (objs.length - 3), // subtract 3 chars
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

		// Sync Edit tab
		editXStepper.value  = o.x;
		editYStepper.value  = o.y;
		editSXStepper.value = o.scaleX;
		editSYStepper.value = o.scaleY;

		// Sync Data tab
		dataNameInput.text       = o.name;
		dataColorInput.text      = '0x' + StringTools.hex(o.solidColor, 8).toUpperCase();
		dataAnimPrefixInput.text = o.animPrefix;
		dataAnimNameInput.text   = o.animName;
		dataScrollXStepper.value = o.scrollX;
		dataScrollYStepper.value = o.scrollY;
		dataAboveCheck.checked   = o.aboveChars;
		dataAACheck.checked      = o.antialiasing;

		// Sync char position steppers
		charXStepper.value = o.x;
		charYStepper.value = o.y;
	}

	// ─────────────────────────────────────────────────────────────────────────
	// STAGE LOADER
	// ─────────────────────────────────────────────────────────────────────────

	function loadStage(stageName:String)
	{
		if (stageName.length == 0) { showError('Enter a stage name!'); return; }

		var stageData:StageFile = StageData.getStageFile(stageName);
		if (stageData == null) { showError('Stage not found: ' + stageName); return; }

		// Apply stage data
		stageZoomStepper.value      = stageData.defaultZoom;
		stageCamSpeedStepper.value  = stageData.camera_speed != null ? stageData.camera_speed : 1000;
		stageNameInput.text         = stageName;

		if (stageData.hide_girlfriend) hideGFCheck.checked = true;
		gfChar.visible = !stageData.hide_girlfriend;

		// Character positions
		if (stageData.boyfriend != null && stageData.boyfriend.length >= 2)
		{
			bfChar.x = stageData.boyfriend[0];
			bfChar.y = stageData.boyfriend[1];
			objs[2].x = bfChar.x;
			objs[2].y = bfChar.y;
		}
		if (stageData.girlfriend != null && stageData.girlfriend.length >= 2)
		{
			gfChar.x = stageData.girlfriend[0];
			gfChar.y = stageData.girlfriend[1];
			objs[1].x = gfChar.x;
			objs[1].y = gfChar.y;
		}
		if (stageData.opponent != null && stageData.opponent.length >= 2)
		{
			dadChar.x = stageData.opponent[0];
			dadChar.y = stageData.opponent[1];
			objs[0].x = dadChar.x;
			objs[0].y = dadChar.y;
		}

		refreshLayerPanel();
		showInfo('Loaded stage: ' + stageName);
	}

	// ─────────────────────────────────────────────────────────────────────────
	// UPDATE
	// ─────────────────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// ── Layer panel click ─────────────────────────────────────────────────
		#if FLX_MOUSE
		if (FlxG.mouse.justPressed)
		{
			for (i in 0...objs.length)
			{
				var t = layerEntries[i];
				if (t != null && FlxG.mouse.overlaps(t, uiCam))
				{
					selectObj(i);
					break;
				}
			}
		}
		#end

		var typing = false;
		for (inp in blockTyping) if (inp.hasFocus) { typing = true; break; }
		if (typing) return;

		// ── Zoom (desktop: scroll wheel / X-Y keys, mobile: X-Y buttons) ──────
		var zoomDelta:Float = 0;
		#if !mobile
		if (FlxG.keys.justPressed.X || FlxG.mouse.wheel < 0) zoomDelta = -0.1;
		if (FlxG.keys.justPressed.Y || FlxG.mouse.wheel > 0) zoomDelta = 0.1;
		#end
		#if mobile
		if (touchPad != null)
		{
			if (touchPad.buttonX.justPressed) zoomDelta = -0.1;
			if (touchPad.buttonY.justPressed) zoomDelta = 0.1;
		}
		#end
		if (zoomDelta != 0)
		{
			editorZoom = FlxMath.bound(editorZoom + zoomDelta, 0.2, 3.0);
			editorCam.zoom = editorZoom;
		}

		// ── Pan mode toggle (C) ───────────────────────────────────────────────
		#if !mobile
		if (FlxG.keys.justPressed.C)
		{
			camPanMode = !camPanMode;
			camPanLabel.text  = 'PAN MODE: ' + (camPanMode ? 'ON' : 'OFF');
			camPanLabel.color = camPanMode ? FlxColor.CYAN : FlxColor.GRAY;
		}
		#end
		#if mobile
		if (touchPad != null && touchPad.buttonC.justPressed)
		{
			camPanMode = !camPanMode;
			camPanLabel.text  = 'PAN MODE: ' + (camPanMode ? 'ON' : 'OFF');
			camPanLabel.color = camPanMode ? FlxColor.CYAN : FlxColor.GRAY;
		}
		#end

		// ── Camera pan ────────────────────────────────────────────────────────
		if (camPanMode)
		{
			var panSpd:Float = 4;
			#if !mobile
			if (FlxG.keys.pressed.LEFT  || FlxG.keys.pressed.A) editorCam.scroll.x -= panSpd;
			if (FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.D) editorCam.scroll.x += panSpd;
			if (FlxG.keys.pressed.UP    || FlxG.keys.pressed.W) editorCam.scroll.y -= panSpd;
			if (FlxG.keys.pressed.DOWN  || FlxG.keys.pressed.S) editorCam.scroll.y += panSpd;
			#end
			#if mobile
			if (touchPad != null)
			{
				if (touchPad.buttonLeft.pressed)  editorCam.scroll.x -= panSpd;
				if (touchPad.buttonRight.pressed) editorCam.scroll.x += panSpd;
				if (touchPad.buttonUp.pressed)    editorCam.scroll.y -= panSpd;
				if (touchPad.buttonDown.pressed)  editorCam.scroll.y += panSpd;
			}
			#end
			return; // don't move objects while panning
		}

		// ── Idle animations (A) ───────────────────────────────────────────────
		#if !mobile
		if (FlxG.keys.justPressed.A)
		{
			for (c in [dadChar, bfChar, gfChar])
				if (c.animation.exists('idle')) c.animation.play('idle', true);
		}
		#end
		#if mobile
		if (touchPad != null && touchPad.buttonA.justPressed)
		{
			for (c in [dadChar, bfChar, gfChar])
				if (c.animation.exists('idle')) c.animation.play('idle', true);
		}
		#end

		// ── Object movement ───────────────────────────────────────────────────
		#if !mobile
		if (hasSel())
		{
			var s   = objs[curSel].sprite;
			var spd = (FlxG.keys.pressed.W || FlxG.keys.pressed.A ||
			           FlxG.keys.pressed.S || FlxG.keys.pressed.D) ? FAST : SLOW;
			if (FlxG.keys.pressed.LEFT  || FlxG.keys.pressed.A) { s.x -= spd; objs[curSel].x = s.x; editXStepper.value = s.x; }
			if (FlxG.keys.pressed.RIGHT || FlxG.keys.pressed.D) { s.x += spd; objs[curSel].x = s.x; editXStepper.value = s.x; }
			if (FlxG.keys.pressed.UP    || FlxG.keys.pressed.W) { s.y -= spd; objs[curSel].y = s.y; editYStepper.value = s.y; }
			if (FlxG.keys.pressed.DOWN  || FlxG.keys.pressed.S) { s.y += spd; objs[curSel].y = s.y; editYStepper.value = s.y; }
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
			var s       = objs[curSel].sprite;
			var holding = touchPad.buttonLeft.pressed || touchPad.buttonRight.pressed ||
			              touchPad.buttonUp.pressed   || touchPad.buttonDown.pressed;
			var spd     = holding ? FAST : SLOW;
			if (touchPad.buttonLeft.pressed)  { s.x -= spd; objs[curSel].x = s.x; editXStepper.value = s.x; }
			if (touchPad.buttonRight.pressed) { s.x += spd; objs[curSel].x = s.x; editXStepper.value = s.x; }
			if (touchPad.buttonUp.pressed)    { s.y -= spd; objs[curSel].y = s.y; editYStepper.value = s.y; }
			if (touchPad.buttonDown.pressed)  { s.y += spd; objs[curSel].y = s.y; editYStepper.value = s.y; }
		}
		if (touchPad != null && touchPad.buttonB.justPressed)
		{
			FlxG.mouse.visible = false;
			MusicBeatState.switchState(new MasterEditorMenu());
		}
		#end
	}

	// ─────────────────────────────────────────────────────────────────────────
	// SAVE JSON
	// ─────────────────────────────────────────────────────────────────────────

	function saveJSON()
	{
		var name = stageName();
		var sb   = new StringBuf();
		sb.add('{\n');
		sb.add('\t"directory": "",\n');
		sb.add('\t"defaultZoom": ' + stageZoomStepper.value + ',\n');
		sb.add('\t"isPixelStage": false,\n');
		sb.add('\t"hide_girlfriend": ' + (hideGFCheck.checked ? 'true' : 'false') + ',\n');
		sb.add('\t"camera_speed": ' + Std.int(stageCamSpeedStepper.value) + ',\n\n');
		sb.add('\t"boyfriend":  [' + Std.int(bfChar.x)  + ', ' + Std.int(bfChar.y)  + '],\n');
		sb.add('\t"girlfriend": [' + Std.int(gfChar.x)  + ', ' + Std.int(gfChar.y)  + '],\n');
		sb.add('\t"opponent":   [' + Std.int(dadChar.x) + ', ' + Std.int(dadChar.y) + '],\n\n');
		sb.add('\t"camera_boyfriend":  [-200, 40],\n');
		sb.add('\t"camera_opponent":   [100, -35],\n');
		sb.add('\t"camera_girlfriend": [225, 0]\n');
		sb.add('}');
		doSave(name + '.json', sb.toString());
	}

	// ─────────────────────────────────────────────────────────────────────────
	// SAVE LUA
	// ─────────────────────────────────────────────────────────────────────────

	function saveLua()
	{
		var sb = new StringBuf();
		sb.add('function onCreate()\n');

		for (obj in objs)
		{
			if (obj.type == CHARACTER) continue; // chars handled by JSON

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
					sb.add('\tmakeLuaSprite(\'' + obj.name + '\', nil, '
						+ Std.int(obj.x) + ', ' + Std.int(obj.y) + ')\n');
					sb.add('\tmakeGraphic(\'' + obj.name + '\', 100, 100, \''
						+ StringTools.hex(obj.solidColor & 0xFFFFFF, 6).toUpperCase() + '\')\n');
				case CHARACTER:
			}

			if (obj.scaleX != 1 || obj.scaleY != 1)
				sb.add('\tscaleObject(\'' + obj.name + '\', ' + obj.scaleX + ', ' + obj.scaleY + ')\n');
			if (obj.scrollX != 1 || obj.scrollY != 1)
				sb.add('\tsetScrollFactor(\'' + obj.name + '\', ' + obj.scrollX + ', ' + obj.scrollY + ')\n');
			if (!obj.antialiasing)
				sb.add('\tsetProperty(\'' + obj.name + '.antialiasing\', false)\n');

			sb.add('\taddLuaSprite(\'' + obj.name + '\', ' + (obj.aboveChars ? 'true' : 'false') + ')\n\n');
		}

		sb.add('end\n\nfunction onBeatHit()\nend\n\nfunction onUpdate(elapsed)\nend\n');
		doSave(stageName() + '.lua', sb.toString());
	}

	// ─────────────────────────────────────────────────────────────────────────
	// HELPERS
	// ─────────────────────────────────────────────────────────────────────────

	inline function hasSel():Bool     return curSel >= 0 && curSel < objs.length;
	inline function stageName():String { var n = stageNameInput.text.trim(); return n.length > 0 ? n : 'myStage'; }
	inline function stripSlash(s:String):String
		return (s.length > 0 && s.charAt(s.length - 1) == '/') ? s.substr(0, s.length - 1) : s;

	function mkLabel(x:Float, y:Float, text:String, size:Int = 9):FlxText
	{
		return new FlxText(x, y, INNER, text, size);
	}

	function mkWideBtn(x:Float, y:Float, lbl:String, cb:Void->Void):FlxButton
	{
		var b = new FlxButton(x, y, lbl, cb);
		b.setGraphicSize(INNER, 24);
		b.updateHitbox();
		return b;
	}

	function mkSmallBtn(x:Float, y:Float, lbl:String, cb:Void->Void):FlxButton
	{
		var b = new FlxButton(x, y, lbl, cb);
		b.setGraphicSize(55, 20);
		b.updateHitbox();
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
