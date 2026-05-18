package options;

import objects.Note;
import objects.StrumNote;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.group.FlxSpriteGroup;
import flixel.addons.ui.FlxUIInputText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

/**
 * Full-screen note skin selector.
 * Left:  paged 4-column grid of note skin cards.
 * Right: large preview of selected skin with control labels + search bar.
 * Center: scrollbar thumb for dragging between pages.
 */
class NoteSkinState extends MusicBeatState
{
	// ── Layout constants ─────────────────────────────────────────────────────
	static inline var GRID_X:Int      = 20;
	static inline var GRID_Y:Int      = 80;
	static inline var CARD_SIZE:Int   = 130;
	static inline var CARD_GAP:Int    = 12;
	static inline var COLS:Int        = 4;
	static inline var ROWS:Int        = 4;
	static inline var PAGE_SIZE:Int   = COLS * ROWS;
	// 16 per page

	static inline var DIVIDER_X:Int   = GRID_X + COLS * (CARD_SIZE + CARD_GAP) + 10;
	static inline var PREVIEW_X:Int   = DIVIDER_X + 20;
	static inline var PREVIEW_Y:Int   = 60;
	static inline var SCROLLBAR_X:Int = DIVIDER_X + 6;
	static inline var SCROLLBAR_Y:Int = GRID_Y;
	static inline var SCROLLBAR_H:Int = ROWS * (CARD_SIZE + CARD_GAP);
	static inline var THUMB_H:Int     = 40;
	// ── State ────────────────────────────────────────────────────────────────
	var allSkins:Array<String>  = [];
	var filtered:Array<String>  = [];
	var curPage:Int             = 0;
	var curSelected:Int         = 0;   // index in `filtered`

	// ── Grid ────────────────────────────────────────────────────────────────
	var cardGroup:FlxSpriteGroup;
	var cardBGs:Array<FlxSprite>    = [];
	var cardNotes:Array<StrumNote>  = [];
	var cardLabels:Array<FlxText>   = [];
	// ── Scrollbar ────────────────────────────────────────────────────────────
	var scrollTrack:FlxSprite;
	var scrollThumb:FlxSprite;
	var draggingScroll:Bool   = false;
	var dragOffsetY:Float     = 0;

	// ── Right panel ──────────────────────────────────────────────────────────
	var previewBG:FlxSprite;
	var skinNameText:FlxText;
	// Preview notes (4 strumlines)
	var previewNotes:Array<StrumNote> = [];
	var previewAnim:String            = 'static';
	// Control labels (ASKL / DFJK or custom)
	var controlLabels:Array<FlxText>  = [];
	var controlArrows:Array<FlxText>  = [];

	var animLabel:FlxText;
	// ── Search ───────────────────────────────────────────────────────────────
	var searchBG:FlxSprite;
	var searchInput:FlxUIInputText;
	var searchIconText:FlxText;

	// ── Page label ───────────────────────────────────────────────────────────
	var pageText:FlxText;
	var titleText:FlxText;
	// ── Page arrows ──────────────────────────────────────────────────────────
	var pageLeftBtn:FlxSprite;
	var pageRightBtn:FlxSprite;
	var pageLeftTxt:FlxText;
	var pageRightTxt:FlxText;
	// ── Control key names cache ───────────────────────────────────────────────
	var noteKeyNames:Array<String> = ['A', 'S', 'K', 'L'];

	override function create()
	{
		super.create();

		persistentUpdate = true;
		FlxG.mouse.visible = true;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Note Skin Selector", null);
		#end

		// ── Background ───────────────────────────────────────────────────────
		var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF2A1A4A;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.screenCenter();
		add(bg);

		// ── Load skin list ───────────────────────────────────────────────────
		loadSkinList();
		// ── Title ────────────────────────────────────────────────────────────
		titleText = new FlxText(GRID_X, 10, 300, 'Notes', 28);
		titleText.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, LEFT,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(titleText);
		pageText = new FlxText(GRID_X, 44, 400, '', 16);
		pageText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.GRAY, LEFT);
		add(pageText);
		// ── Divider ──────────────────────────────────────────────────────────
		var divider = new FlxSprite(DIVIDER_X, 0).makeGraphic(2, FlxG.height, 0xFF444466);
		add(divider);
		// ── Scrollbar track ──────────────────────────────────────────────────
		scrollTrack = new FlxSprite(SCROLLBAR_X, SCROLLBAR_Y).makeGraphic(8, SCROLLBAR_H, 0xFF333355);
		add(scrollTrack);
		scrollThumb = new FlxSprite(SCROLLBAR_X - 1, SCROLLBAR_Y).makeGraphic(10, THUMB_H, 0xFFAABBFF);
		add(scrollThumb);

		// ── Grid card group ──────────────────────────────────────────────────
		cardGroup = new FlxSpriteGroup();
		add(cardGroup);
		// ── Right panel ──────────────────────────────────────────────────────
		previewBG = new FlxSprite(PREVIEW_X, PREVIEW_Y).makeGraphic(
			FlxG.width - PREVIEW_X - 10, FlxG.height - PREVIEW_Y - 10, 0xFF1A1030);
		add(previewBG);
		// Skin name
		skinNameText = new FlxText(PREVIEW_X + 10, PREVIEW_Y + 10, previewBG.width - 20, '', 24);
		skinNameText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.YELLOW, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(skinNameText);

		// ── Search bar ───────────────────────────────────────────────────────
		searchBG = new FlxSprite(PREVIEW_X + 10, PREVIEW_Y + 50).makeGraphic(
			Std.int(previewBG.width - 60), 32, 0xFF2A2050);
		add(searchBG);

		searchIconText = new FlxText(searchBG.x + searchBG.width + 4, searchBG.y + 6, 30, '📁', 14);
		add(searchIconText);
		searchInput = new FlxUIInputText(searchBG.x + 6, searchBG.y + 6,
			Std.int(searchBG.width - 12), 'Search Skins...', 14);
		searchInput.color      = FlxColor.WHITE;
		searchInput.caretColor = FlxColor.CYAN;
		add(searchInput);

		// ── Control key name display ─────────────────────────────────────────
		buildControlDisplay();
		// ── Preview note strumlines ───────────────────────────────────────────
		buildPreviewNotes();

		// ── Page nav arrows ───────────────────────────────────────────────────
		pageLeftTxt  = makePanelText('<', GRID_X, FlxG.height - 36, 24);
		pageRightTxt = makePanelText('>', GRID_X + COLS * (CARD_SIZE + CARD_GAP) - 20, FlxG.height - 36, 24);
		add(pageLeftTxt);
		add(pageRightTxt);
		// ── Mobile back button ───────────────────────────────────────────────
		#if mobile
		addTouchPad("LEFT_FULL", "A_B");
		#end

		// ── Initial render ───────────────────────────────────────────────────
		applySearch();
	}

	// ─── Skin list ────────────────────────────────────────────────────────────

	function loadSkinList()
	{
		allSkins = ['Default'];
		var modSkins = Mods.mergeAllTextsNamed('images/noteSkins/list.txt');
		for (s in modSkins)
			if (s.trim().length > 0 && !allSkins.contains(s.trim()))
				allSkins.push(s.trim());

		filtered = allSkins.copy();
		// Start on currently selected skin
		var idx = filtered.indexOf(ClientPrefs.data.noteSkin);
		if (idx < 0) idx = 0;
		curSelected = idx;
		curPage     = Std.int(curSelected / PAGE_SIZE);
	}

	// ─── Build control key display ────────────────────────────────────────────

	function buildControlDisplay()
	{
		// Arrow glyphs
		var arrowGlyphs = ['←', '↓', '↑', '→'];
		// Get bound key names from ClientPrefs controls
		var bound = getBoundKeyNames();

		var noteAreaW  = previewBG.width - 20;
		var noteStartX = PREVIEW_X + 10;
		var arrowY     = PREVIEW_Y + 110;
		var keyY       = arrowY + 44;
		var spacing    = Std.int(noteAreaW / 4);

		for (i in 0...4)
		{
			var cx = noteStartX + spacing * i + Std.int(spacing / 2);
			var arTxt = new FlxText(cx - 20, arrowY, 40, arrowGlyphs[i], 28);
			arTxt.setFormat(Paths.font('vcr.ttf'), 28, 0xFFB0C4FF, CENTER);
			add(arTxt);
			controlArrows.push(arTxt);
			var kTxt = new FlxText(cx - 20, keyY, 40, bound[i], 18);
			kTxt.setFormat(Paths.font('vcr.ttf'), 18, FlxColor.WHITE, CENTER);
			add(kTxt);
			controlLabels.push(kTxt);
		}

		// "Player" label (no opponent label since we removed the checkbox)
		var playerLabel = new FlxText(noteStartX, keyY + 28, 120, 'Player', 16);
		playerLabel.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.CYAN, LEFT);
		add(playerLabel);

		// Animation label
		animLabel = new FlxText(noteStartX, PREVIEW_Y + 220, noteAreaW, 'PREVIEW ANIMATIONS', 14);
		animLabel.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.GRAY, CENTER);
		add(animLabel);

		// Anim buttons row
		var animNames  = ['static', 'pressed', 'confirm'];
		var btnY       = animLabel.y + 22;
		for (i in 0...animNames.length)
		{
			var btnBG = new FlxSprite(noteStartX + i * 90, btnY).makeGraphic(80, 28, 0xFF333366);
			add(btnBG);
			var idx  = i; // capture
			var bTxt = new FlxText(btnBG.x, btnBG.y + 5, 80, animNames[i], 13);
			bTxt.setFormat(Paths.font('vcr.ttf'), 13, FlxColor.WHITE, CENTER);
			add(bTxt);
		}
	}

	function getBoundKeyNames():Array<String>
	{
		// Try to read from ClientPrefs keyBinds;
		// fall back to ASKL
		var defaults = ['A', 'S', 'K', 'L'];
		try
		{
			var binds:Array<Array<Dynamic>> = ClientPrefs.data.gameplaySettings != null
				? null : null;
			// not used directly

			// In Psych 0.7.3, key names are in ClientPrefs.keyBinds
			var kb = ClientPrefs.keyBinds;
			if (kb != null)
			{
				var names = [];
				var keys  = ['note_left', 'note_down', 'note_up', 'note_right'];
				for (k in keys)
				{
					var arr:Array<Dynamic> = Reflect.field(kb, k);
					if (arr != null && arr.length > 0)
					{
						var keyName:String = Std.string(arr[0]);
						// Strip FlxKey prefix and shorten
						keyName = keyName.split('_').pop();
						if (keyName.length > 3) keyName = keyName.charAt(0);
						names.push(keyName.toUpperCase());
					}
					else names.push(defaults[names.length]);
				}
				return names;
			}
		}
		catch (e:Dynamic) {}
		return defaults;
	}

	// ─── Build preview strumlines ─────────────────────────────────────────────

	function buildPreviewNotes()
	{
		for (n in previewNotes) n.destroy();
		previewNotes = [];
		var noteAreaW  = previewBG.width - 20;
		var noteStartX = PREVIEW_X + 10;
		var spacing    = Std.int(noteAreaW / 4);
		var noteY      = PREVIEW_Y + 300;
		for (i in 0...4)
		{
			var cx = noteStartX + spacing * i + Std.int(spacing / 2) - 40;
			var sn = new StrumNote(cx, noteY, i, 0);
			sn.setGraphicSize(75, 75);
			sn.updateHitbox();
			sn.centerOffsets();
			sn.centerOrigin();

			// Apply selected skin
			applyNoteSkin(sn);
			sn.playAnim('static');
			add(sn);
			previewNotes.push(sn);
		}
	}

	function applyNoteSkin(note:StrumNote)
	{
		var skin:String = Note.defaultNoteSkin;
		var postfix     = Note.getNoteSkinPostfix();
		var custom      = skin + postfix;
		if (Paths.fileExists('images/$custom.png', IMAGE)) skin = custom;
		// Override with selected skin if not default
		if (filtered.length > 0 && curSelected < filtered.length)
		{
			var sel = filtered[curSelected];
			if (sel != 'Default' && sel != ClientPrefs.defaultData.noteSkin)
			{
				var skinPath = 'images/noteSkins/$sel';
				if (Paths.fileExists('$skinPath.png', IMAGE)) skin = 'noteSkins/$sel';
			}
		}

		note.texture = skin;
		note.reloadNote();
	}

	function refreshPreviewNotes()
	{
		for (sn in previewNotes)
		{
			applyNoteSkin(sn);
			sn.playAnim(previewAnim);
		}
		if (filtered.length > 0 && curSelected < filtered.length)
			skinNameText.text = filtered[curSelected];
		else
			skinNameText.text = '';
	}

	// ─── Grid rendering ───────────────────────────────────────────────────────

	function renderPage()
	{
		// Clear old cards
		for (bg in cardBGs)    { cardGroup.remove(bg, true);    bg.destroy();
		}
		for (sn in cardNotes)  { cardGroup.remove(sn, true);    sn.destroy(); }
		for (lb in cardLabels) { cardGroup.remove(lb, true);    lb.destroy();
		}
		cardBGs    = [];
		cardNotes  = [];
		cardLabels = [];

		var start = curPage * PAGE_SIZE;
		var end   = Std.int(Math.min(start + PAGE_SIZE, filtered.length));

		for (idx in start...end)
		{
			var gridIdx = idx - start;
			var col = gridIdx % COLS;
			var row = Std.int(gridIdx / COLS);
			var cx = GRID_X + col * (CARD_SIZE + CARD_GAP);
			var cy = GRID_Y + row * (CARD_SIZE + CARD_GAP);
			var isSelected = (idx == curSelected);

			// Card background
			var cardBG = new FlxSprite(cx, cy).makeGraphic(CARD_SIZE, CARD_SIZE,
				isSelected ? 0xFF4A3A8A : 0xFF252040);
			if (isSelected)
			{
				// Bright border effect — draw a 2px inset border
				cardBG.makeGraphic(CARD_SIZE, CARD_SIZE, 0xFFFFCC00);
				var inner = new FlxSprite(cx + 2, cy + 2).makeGraphic(CARD_SIZE - 4, CARD_SIZE - 4, 0xFF252040);
				cardGroup.add(inner);
				cardBGs.push(inner);
			}
			cardGroup.add(cardBG);
			cardBGs.push(cardBG);
			// Up-arrow strumnote preview
			var sn = new StrumNote(cx + Std.int(CARD_SIZE / 2) - 25, cy + 20, 2, 0);
			// direction 2 = up
			sn.setGraphicSize(50, 50);
			sn.updateHitbox();
			sn.centerOffsets();
			sn.centerOrigin();

			var skinName = filtered[idx];
			if (skinName != 'Default' && skinName != ClientPrefs.defaultData.noteSkin)
			{
				var skinPath = 'noteSkins/$skinName';
				if (Paths.fileExists('images/$skinPath.png', IMAGE))
					sn.texture = skinPath;
			}
			sn.reloadNote();
			sn.playAnim('static');
			cardGroup.add(sn);
			cardNotes.push(sn);
			// Label
			var lbl = new FlxText(cx, cy + CARD_SIZE - 28, CARD_SIZE, skinName, 10);
			lbl.setFormat(Paths.font('vcr.ttf'), 10,
				isSelected ? FlxColor.YELLOW : FlxColor.WHITE, CENTER);
			lbl.borderStyle = FlxTextBorderStyle.OUTLINE;
			lbl.borderColor = FlxColor.BLACK;
			cardGroup.add(lbl);
			cardLabels.push(lbl);
		}

		// Page text
		var totalPages = Std.int(Math.ceil(filtered.length / PAGE_SIZE));
		pageText.text  = 'Page ${curPage + 1} / ${Std.int(Math.max(1, totalPages))}';
		// Scrollbar thumb position
		updateScrollThumb();
	}

	function updateScrollThumb()
	{
		var totalPages = Std.int(Math.ceil(filtered.length / PAGE_SIZE));
		if (totalPages <= 1) { scrollThumb.visible = false; return;
		}
		scrollThumb.visible = true;

		var travel   = SCROLLBAR_H - THUMB_H;
		var fraction = totalPages > 1 ?
		curPage / (totalPages - 1) : 0;
		scrollThumb.y = SCROLLBAR_Y + fraction * travel;
	}

	// ─── Search ───────────────────────────────────────────────────────────────

	var lastSearch:String = '';

	function applySearch()
	{
		var q = searchInput != null ? searchInput.text.toLowerCase().trim() : '';
		if (q == 'search skins...') q = '';

		filtered = q.length == 0
			? allSkins.copy()
			: allSkins.filter(s -> s.toLowerCase().indexOf(q) >= 0);
		if (filtered.length == 0) filtered = ['(no results)'];

		curSelected = 0;
		curPage     = 0;
		renderPage();
		refreshPreviewNotes();
	}

	// ─── Update ───────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// Search bar live update
		if (searchInput != null)
		{
			var q = searchInput.text;
			if (q != lastSearch) { lastSearch = q; applySearch(); }
		}

		var typing = searchInput != null && searchInput.hasFocus;
		// ── Scrollbar drag ────────────────────────────────────────────────────
		#if FLX_MOUSE
		if (FlxG.mouse.justPressed && FlxG.mouse.overlaps(scrollThumb))
		{
			draggingScroll = true;
			dragOffsetY    = FlxG.mouse.y - scrollThumb.y;
		}
		if (!FlxG.mouse.pressed) draggingScroll = false;

		if (draggingScroll)
		{
			var newY       = FlxMath.bound(FlxG.mouse.y - dragOffsetY,
				SCROLLBAR_Y, SCROLLBAR_Y + SCROLLBAR_H - THUMB_H);
			scrollThumb.y  = newY;
			var fraction   = (newY - SCROLLBAR_Y) / (SCROLLBAR_H - THUMB_H);
			var totalPages = Std.int(Math.ceil(filtered.length / PAGE_SIZE));
			var newPage    = Std.int(Math.round(fraction * (totalPages - 1)));
			if (newPage != curPage) { curPage = newPage; renderPage(); }
		}

		// ── Grid card click ───────────────────────────────────────────────────
		if (FlxG.mouse.justPressed && !draggingScroll)
		{
			var start = curPage * PAGE_SIZE;
			for (i in 0...cardNotes.length)
			{
				if (FlxG.mouse.overlaps(cardBGs[i * 2 > cardBGs.length - 1 ? i : i]))
				{
					var realIdx = start + i;
					if (realIdx < filtered.length && filtered[realIdx] != '(no results)')
					{
						selectSkin(realIdx);
					}
					break;
				}
			}

			// Anim buttons
			var animNames = ['static', 'pressed', 'confirm'];
			var noteAreaW = previewBG.width - 20;
			var noteStartX= PREVIEW_X + 10;
			var btnY      = PREVIEW_Y + 258;
			for (i in 0...animNames.length)
			{
				var bx = noteStartX + i * 90;
				if (FlxG.mouse.x >= bx && FlxG.mouse.x <= bx + 80
				 && FlxG.mouse.y >= btnY && FlxG.mouse.y <= btnY + 28)
				{
					previewAnim = animNames[i];
					for (sn in previewNotes) sn.playAnim(previewAnim);
				}
			}

			// Page arrows
			if (FlxG.mouse.overlaps(pageLeftTxt))  changePage(-1);
			if (FlxG.mouse.overlaps(pageRightTxt)) changePage(1);
		}
		#end

		if (!typing)
		{
			// Keyboard navigation
			if (controls.UI_LEFT_P)  changePage(-1);
			if (controls.UI_RIGHT_P) changePage(1);

			if (controls.UI_UP_P)   moveCardSelection(-COLS);
			if (controls.UI_DOWN_P) moveCardSelection(COLS);
			if (controls.ACCEPT)
			{
				if (filtered.length > 0 && filtered[curSelected] != '(no results)')
					selectSkin(curSelected);
			}

			if (controls.BACK)
			{
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new OptionsState());
			}

			#if mobile
			if (touchPad != null && touchPad.buttonB.justPressed)
			{
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new OptionsState());
			}
			#end
		}
	}

	function moveCardSelection(delta:Int)
	{
		var newSel = curSelected + delta;
		newSel     = Std.int(FlxMath.bound(newSel, 0, filtered.length - 1));
		var newPage = Std.int(newSel / PAGE_SIZE);
		if (newPage != curPage) { curPage = newPage; }
		curSelected = newSel;
		renderPage();
		refreshPreviewNotes();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function changePage(dir:Int)
	{
		var totalPages = Std.int(Math.ceil(filtered.length / PAGE_SIZE));
		curPage = Std.int(FlxMath.bound(curPage + dir, 0, totalPages - 1));
		curSelected = curPage * PAGE_SIZE;
		renderPage();
		refreshPreviewNotes();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function selectSkin(idx:Int)
	{
		curSelected             = idx;
		ClientPrefs.data.noteSkin = filtered[idx] == 'Default'
			? ClientPrefs.defaultData.noteSkin
			: filtered[idx];
		ClientPrefs.saveSettings();

		renderPage();
		refreshPreviewNotes();
		FlxG.sound.play(Paths.sound('confirmMenu'));
	}

	// ─── Helpers ──────────────────────────────────────────────────────────────

	function makePanelText(str:String, x:Float, y:Float, size:Int):FlxText
	{
		var t = new FlxText(x, y, 40, str, size);
		t.setFormat(Paths.font('vcr.ttf'), size, FlxColor.WHITE, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		return t;
	}

	override function destroy()
	{
		FlxG.mouse.visible = false;
		super.destroy();
	}
}
