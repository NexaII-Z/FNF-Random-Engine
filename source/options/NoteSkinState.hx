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
 * Left:  paged 4-column grid of note skin cards + search bar below page label.
 * Right: large preview of selected skin + animation buttons.
 * Navigation: D-pad left/right moves between skins, wrapping pages automatically.
 * Equip:  press A (ACCEPT) to equip currently highlighted skin.
 * Equipped card = blue highlight. Selected (not equipped) = gold highlight.
 */
class NoteSkinState extends MusicBeatState
{
	// ── Layout constants ─────────────────────────────────────────────────────
	static inline var GRID_X:Int    = 20;
	static inline var GRID_Y:Int    = 110; // pushed down to make room for search bar
	static inline var CARD_SIZE:Int = 130;
	static inline var CARD_GAP:Int  = 12;
	static inline var COLS:Int      = 4;
	static inline var ROWS:Int      = 4;
	static inline var PAGE_SIZE:Int = COLS * ROWS; // 16 per page

	static inline var DIVIDER_X:Int = GRID_X + COLS * (CARD_SIZE + CARD_GAP) + 10;
	static inline var PREVIEW_X:Int = DIVIDER_X + 20;
	static inline var PREVIEW_Y:Int = 60;

	// ── State ────────────────────────────────────────────────────────────────
	var allSkins:Array<String> = [];
	var filtered:Array<String> = [];
	var curPage:Int            = 0;
	var curSelected:Int        = 0; // index in `filtered` — highlighted (not necessarily equipped)
	var equippedIdx:Int        = 0; // index in `filtered` of currently equipped skin

	// ── Grid ─────────────────────────────────────────────────────────────────
	var cardGroup:FlxSpriteGroup;
	var cardBGs:Array<FlxSprite>   = [];
	var cardNotes:Array<StrumNote> = [];
	var cardLabels:Array<FlxText>  = [];

	// ── Right panel ──────────────────────────────────────────────────────────
	var previewBG:FlxSprite;
	var skinNameText:FlxText;
	var previewNotes:Array<StrumNote> = [];
	var previewAnim:String            = 'static';
	var animLabel:FlxText;

	// ── Search ───────────────────────────────────────────────────────────────
	var searchBG:FlxSprite;
	var searchInput:FlxUIInputText;
	var searchIconText:FlxText;

	// ── Page / title labels ───────────────────────────────────────────────────
	var pageText:FlxText;
	var titleText:FlxText;

	// ── Page arrows ───────────────────────────────────────────────────────────
	var pageLeftTxt:FlxText;
	var pageRightTxt:FlxText;

	// ── Input hold repeat ─────────────────────────────────────────────────────
	var holdTimer:Float  = 0;
	var holdDelay:Float  = 0.4;  // seconds before repeat starts
	var holdRepeat:Float = 0.1;  // repeat interval
	var holdDir:Int      = 0;    // -1 left, 1 right, 0 none

	override function create()
	{
		super.create();

		persistentUpdate = true;
		FlxG.mouse.visible = true;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Note Skin Selector", null);
		#end

		// ── Background ────────────────────────────────────────────────────────
		var bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFF2A1A4A;
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.screenCenter();
		add(bg);

		// ── Load skin list ────────────────────────────────────────────────────
		loadSkinList();

		// ── Title ─────────────────────────────────────────────────────────────
		titleText = new FlxText(GRID_X, 10, 300, 'Notes', 28);
		titleText.setFormat(Paths.font('vcr.ttf'), 28, FlxColor.WHITE, LEFT,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(titleText);

		pageText = new FlxText(GRID_X, 44, 400, '', 16);
		pageText.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.GRAY, LEFT);
		add(pageText);

		// ── Search bar (left side, below page label) ──────────────────────────
		var gridW = COLS * (CARD_SIZE + CARD_GAP) - CARD_GAP;
		searchBG = new FlxSprite(GRID_X, 66).makeGraphic(gridW - 36, 32, 0xFF2A2050);
		add(searchBG);

		searchIconText = new FlxText(searchBG.x + searchBG.width + 4, searchBG.y + 6, 30, '🔍', 14);
		add(searchIconText);

		searchInput = new FlxUIInputText(searchBG.x + 6, searchBG.y + 6,
			Std.int(searchBG.width - 12), 'Search...', 14);
		searchInput.color      = FlxColor.WHITE;
		searchInput.caretColor = FlxColor.CYAN;
		add(searchInput);

		// ── Divider ───────────────────────────────────────────────────────────
		var divider = new FlxSprite(DIVIDER_X, 0).makeGraphic(2, FlxG.height, 0xFF444466);
		add(divider);

		// ── Grid card group ───────────────────────────────────────────────────
		cardGroup = new FlxSpriteGroup();
		add(cardGroup);

		// ── Right panel ───────────────────────────────────────────────────────
		previewBG = new FlxSprite(PREVIEW_X, PREVIEW_Y).makeGraphic(
			FlxG.width - PREVIEW_X - 10, FlxG.height - PREVIEW_Y - 10, 0xFF1A1030);
		add(previewBG);

		skinNameText = new FlxText(PREVIEW_X + 10, PREVIEW_Y + 10, previewBG.width - 20, '', 24);
		skinNameText.setFormat(Paths.font('vcr.ttf'), 24, FlxColor.YELLOW, CENTER,
			FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(skinNameText);

		// ── Preview notes ─────────────────────────────────────────────────────
		buildPreviewNotes();

		// ── Animation buttons ─────────────────────────────────────────────────
		animLabel = new FlxText(PREVIEW_X + 10, PREVIEW_Y + 120, previewBG.width - 20, 'PREVIEW ANIMATIONS', 14);
		animLabel.setFormat(Paths.font('vcr.ttf'), 14, FlxColor.GRAY, CENTER);
		add(animLabel);

		var animNames = ['static', 'pressed', 'confirm'];
		var btnY      = animLabel.y + 22;
		for (i in 0...animNames.length)
		{
			var btnBG = new FlxSprite(PREVIEW_X + 10 + i * 90, btnY).makeGraphic(80, 28, 0xFF333366);
			add(btnBG);
			var bTxt = new FlxText(btnBG.x, btnBG.y + 5, 80, animNames[i], 13);
			bTxt.setFormat(Paths.font('vcr.ttf'), 13, FlxColor.WHITE, CENTER);
			add(bTxt);
		}

		// ── Page nav arrows ───────────────────────────────────────────────────
		var arrowY = FlxG.height - 36;
		pageLeftTxt  = makePanelText('<', GRID_X, arrowY, 24);
		pageRightTxt = makePanelText('>', GRID_X + gridW - 20, arrowY, 24);
		add(pageLeftTxt);
		add(pageRightTxt);

		// ── Mobile back button ────────────────────────────────────────────────
		#if mobile
		addTouchPad("LEFT_FULL", "A_B");
		#end

		// ── Initial render ────────────────────────────────────────────────────
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

		// Find equipped skin
		var equipped = ClientPrefs.data.noteSkin;
		var eqName   = (equipped == null || equipped == ClientPrefs.defaultData.noteSkin)
			? 'Default' : equipped;
		equippedIdx  = filtered.indexOf(eqName);
		if (equippedIdx < 0) equippedIdx = 0;

		curSelected = equippedIdx;
		curPage     = Std.int(curSelected / PAGE_SIZE);
	}

	// ─── Build preview strumlines (right panel, all 4 directions) ─────────────

	function buildPreviewNotes()
	{
		for (n in previewNotes) { remove(n, true); n.destroy(); }
		previewNotes = [];

		var noteAreaW  = previewBG.width - 20;
		var noteStartX = PREVIEW_X + 10;
		var spacing    = Std.int(noteAreaW / 4);
		var noteY      = PREVIEW_Y + 40; // sit just below the skin name

		for (i in 0...4)
		{
			var cx = noteStartX + spacing * i + Std.int(spacing / 2) - 37;
			var sn = new StrumNote(cx, noteY, i, 0);
			sn.setGraphicSize(75, 75);
			sn.updateHitbox();
			sn.centerOffsets();
			sn.centerOrigin();
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

		if (filtered.length > 0 && curSelected < filtered.length)
		{
			var sel = filtered[curSelected];
			if (sel != 'Default' && sel != ClientPrefs.defaultData.noteSkin)
			{
				var skinPath = 'noteSkins/$sel';
				if (Paths.fileExists('images/$skinPath.png', IMAGE)) skin = skinPath;
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
		skinNameText.text = (filtered.length > 0 && curSelected < filtered.length)
			? filtered[curSelected] : '';
	}

	// ─── Grid rendering ───────────────────────────────────────────────────────

	function renderPage()
	{
		// Clear old cards
		for (b in cardBGs)    { cardGroup.remove(b, true); b.destroy(); }
		for (s in cardNotes)  { cardGroup.remove(s, true); s.destroy(); }
		for (l in cardLabels) { cardGroup.remove(l, true); l.destroy(); }
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
			var cx  = GRID_X + col * (CARD_SIZE + CARD_GAP);
			var cy  = GRID_Y + row * (CARD_SIZE + CARD_GAP);

			var isSelected = (idx == curSelected);
			var isEquipped = (idx == equippedIdx);

			// Card BG color: blue = equipped, gold border = selected, plain = neither
			var bgColor:FlxColor = isEquipped ? 0xFF1A4A8A : 0xFF252040;

			if (isSelected && !isEquipped)
			{
				// Gold border outer, dark fill inner
				var outer = new FlxSprite(cx, cy).makeGraphic(CARD_SIZE, CARD_SIZE, 0xFFFFCC00);
				cardGroup.add(outer);
				cardBGs.push(outer);
				var inner = new FlxSprite(cx + 2, cy + 2).makeGraphic(CARD_SIZE - 4, CARD_SIZE - 4, bgColor);
				cardGroup.add(inner);
				cardBGs.push(inner);
			}
			else if (isSelected && isEquipped)
			{
				// Gold border + blue fill
				var outer = new FlxSprite(cx, cy).makeGraphic(CARD_SIZE, CARD_SIZE, 0xFFFFCC00);
				cardGroup.add(outer);
				cardBGs.push(outer);
				var inner = new FlxSprite(cx + 2, cy + 2).makeGraphic(CARD_SIZE - 4, CARD_SIZE - 4, 0xFF1A4A8A);
				cardGroup.add(inner);
				cardBGs.push(inner);
			}
			else
			{
				var cardBG = new FlxSprite(cx, cy).makeGraphic(CARD_SIZE, CARD_SIZE, bgColor);
				cardGroup.add(cardBG);
				cardBGs.push(cardBG);
			}

			// ── Note icon: use this skin's OWN up note (direction 2) ───────────
			var skinName = filtered[idx];
			var sn = new StrumNote(0, 0, 2, 0); // direction 2 = up, temporary position
			sn.setGraphicSize(58, 58);
			sn.updateHitbox();
			sn.centerOffsets();
			sn.centerOrigin();

			// Apply this card's own skin
			if (skinName != 'Default' && skinName != ClientPrefs.defaultData.noteSkin)
			{
				var skinPath = 'noteSkins/$skinName';
				if (Paths.fileExists('images/$skinPath.png', IMAGE))
					sn.texture = skinPath;
			}
			sn.reloadNote();
			sn.playAnim('static');

			// Center the note inside the card
			sn.x = cx + Std.int((CARD_SIZE - sn.width)  / 2);
			sn.y = cy + Std.int((CARD_SIZE - sn.height) / 2) - 10; // slight upward offset to leave room for label

			cardGroup.add(sn);
			cardNotes.push(sn);

			// Label
			var lbl = new FlxText(cx, cy + CARD_SIZE - 26, CARD_SIZE, skinName, 10);
			lbl.setFormat(Paths.font('vcr.ttf'), 10,
				isSelected ? FlxColor.YELLOW : (isEquipped ? 0xFF88CCFF : FlxColor.WHITE), CENTER);
			lbl.borderStyle = FlxTextBorderStyle.OUTLINE;
			lbl.borderColor = FlxColor.BLACK;
			cardGroup.add(lbl);
			cardLabels.push(lbl);
		}

		// Page label
		var totalPages = Std.int(Math.ceil(filtered.length / PAGE_SIZE));
		pageText.text  = 'Page ${curPage + 1} / ${Std.int(Math.max(1, totalPages))}';
	}

	// ─── Search ───────────────────────────────────────────────────────────────

	var lastSearch:String = '';

	function applySearch()
	{
		var q = searchInput != null ? searchInput.text.toLowerCase().trim() : '';
		if (q == 'search...') q = '';

		filtered = q.length == 0
			? allSkins.copy()
			: allSkins.filter(s -> s.toLowerCase().indexOf(q) >= 0);
		if (filtered.length == 0) filtered = ['(no results)'];

		// Re-find equipped index in new filtered list
		var equipped = ClientPrefs.data.noteSkin;
		var eqName   = (equipped == null || equipped == ClientPrefs.defaultData.noteSkin)
			? 'Default' : equipped;
		equippedIdx  = filtered.indexOf(eqName);
		if (equippedIdx < 0) equippedIdx = 0;

		curSelected = equippedIdx;
		curPage     = Std.int(curSelected / PAGE_SIZE);

		renderPage();
		refreshPreviewNotes();
	}

	// ─── Update ───────────────────────────────────────────────────────────────

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// Search live update
		if (searchInput != null)
		{
			var q = searchInput.text;
			if (q != lastSearch) { lastSearch = q; applySearch(); }
		}

		var typing = searchInput != null && searchInput.hasFocus;

		// ── Mouse: click card or anim buttons ─────────────────────────────────
		#if FLX_MOUSE
		if (FlxG.mouse.justPressed && !typing)
		{
			// Card clicks
			var start = curPage * PAGE_SIZE;
			for (i in 0...cardNotes.length)
			{
				if (FlxG.mouse.overlaps(cardNotes[i]))
				{
					var realIdx = start + i;
					if (realIdx < filtered.length && filtered[realIdx] != '(no results)')
					{
						curSelected = realIdx;
						renderPage();
						refreshPreviewNotes();
						FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
					}
					break;
				}
			}

			// Anim buttons
			var animNames  = ['static', 'pressed', 'confirm'];
			var noteAreaW  = previewBG.width - 20;
			var btnY       = animLabel.y + 22;
			for (i in 0...animNames.length)
			{
				var bx = PREVIEW_X + 10 + i * 90;
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
			// ── D-pad left/right: move selection, auto-page ───────────────────
			var pressedLeft  = controls.UI_LEFT_P;
			var pressedRight = controls.UI_RIGHT_P;
			var heldLeft     = controls.UI_LEFT;
			var heldRight    = controls.UI_RIGHT;

			if (pressedLeft)
			{
				holdDir   = -1;
				holdTimer = 0;
				moveSelection(-1);
			}
			else if (pressedRight)
			{
				holdDir   = 1;
				holdTimer = 0;
				moveSelection(1);
			}
			else if (heldLeft && holdDir == -1)
			{
				holdTimer += elapsed;
				if (holdTimer >= holdDelay)
				{
					holdTimer -= holdRepeat;
					moveSelection(-1);
				}
			}
			else if (heldRight && holdDir == 1)
			{
				holdTimer += elapsed;
				if (holdTimer >= holdDelay)
				{
					holdTimer -= holdRepeat;
					moveSelection(1);
				}
			}
			else
			{
				holdDir   = 0;
				holdTimer = 0;
			}

			// ACCEPT = equip selected skin
			if (controls.ACCEPT)
				equipSelected();

			if (controls.BACK)
			{
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new OptionsState());
			}

			#if mobile
			if (touchPad != null && touchPad.buttonA.justPressed)
				equipSelected();

			if (touchPad != null && touchPad.buttonB.justPressed)
			{
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new OptionsState());
			}
			#end
		}
	}

	// ─── Selection movement with auto-page scroll ─────────────────────────────

	function moveSelection(dir:Int)
	{
		if (filtered.length == 0 || filtered[0] == '(no results)') return;

		var newSel = curSelected + dir;

		// Clamp to valid range
		if (newSel < 0) newSel = 0;
		if (newSel >= filtered.length) newSel = filtered.length - 1;
		if (newSel == curSelected) return;

		curSelected = newSel;

		// Auto-page: if selection moved off the current page
		var newPage = Std.int(curSelected / PAGE_SIZE);
		if (newPage != curPage)
		{
			curPage = newPage;
		}

		renderPage();
		refreshPreviewNotes();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	function changePage(dir:Int)
	{
		var totalPages = Std.int(Math.ceil(filtered.length / PAGE_SIZE));
		var newPage    = Std.int(FlxMath.bound(curPage + dir, 0, totalPages - 1));
		if (newPage == curPage) return;
		curPage     = newPage;
		curSelected = curPage * PAGE_SIZE;
		renderPage();
		refreshPreviewNotes();
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);
	}

	// ─── Equip ────────────────────────────────────────────────────────────────

	function equipSelected()
	{
		if (filtered.length == 0 || filtered[curSelected] == '(no results)') return;

		equippedIdx = curSelected;
		ClientPrefs.data.noteSkin = filtered[curSelected] == 'Default'
			? ClientPrefs.defaultData.noteSkin
			: filtered[curSelected];
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
