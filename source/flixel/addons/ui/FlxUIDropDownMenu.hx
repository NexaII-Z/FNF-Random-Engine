package flixel.addons.ui;

import flash.geom.Rectangle;
import flixel.addons.ui.interfaces.IFlxUIClickable;
import flixel.addons.ui.interfaces.IFlxUIWidget;
import flixel.addons.ui.interfaces.IHasParams;

import flixel.ui.FlxButton;

import flixel.util.FlxDestroyUtil;
import flixel.util.FlxStringUtil;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxColor;
import flixel.addons.ui.FlxUIGroup;
import flixel.addons.ui.FlxUIText;
import flixel.addons.ui.FlxUIButton;
import flixel.addons.ui.FlxUISpriteButton;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUIAssets;
import flixel.addons.ui.StrNameLabel;
import flixel.addons.ui.FlxUI;

/*
 * NexaII Engine - Redesigned FlxUIDropDownMenu
 *
 * Visual changes vs stock:
 *   • Dark gunmetal panel background with rounded corners
 *   • Cyan accent header bar with arrow glyph sprite
 *   • Hover-highlighted rows (cyan tint)
 *   • Selected item marked with a side-bar accent
 *   • Mobile swipe scroll preserved + wider tap area
 *   • Drop direction defaults to Down
 *
 * Functional parity: scrolling, keyboard arrow, mouse wheel, callbacks.
 */

/**
 * @author larsiusprime (original), NexaII Engine reskin
 */
class FlxUIDropDownMenu extends FlxUIGroup implements IFlxUIWidget implements IFlxUIClickable implements IHasParams
{
	// ─── Theme ──────────────────────────────────────────────────────────
	/** Header background (deep cyan) */
	public static inline var HEADER_BG:Int      = 0xFF006064;
	/** Header text color */
	public static inline var HEADER_TEXT:Int    = 0xFFE0F7FA;
	/** Panel background */
	public static inline var PANEL_BG:Int       = 0xFF12151F;
	/** Panel border */
	public static inline var PANEL_BORDER:Int   = 0xFF00BCD4;
	/** Row default text */
	public static inline var ROW_TEXT:Int       = 0xFFB0BEC5;
	/** Row hover text */
	public static inline var ROW_HOVER_TEXT:Int = 0xFF00E5FF;
	/** Row hover bg */
	public static inline var ROW_HOVER_BG:Int   = 0xFF1A2A2E;
	/** Accent bar for selected row */
	public static inline var ACCENT_BAR:Int     = 0xFF00E5FF;
	/** Header height */
	public static inline var HEADER_H:Int       = 32;
	/** Row height (mobile-comfortable) */
	public static inline var ROW_H:Int          = 36;

	// ─── Skip-button-update ─────────────────────────────────────────────
	public var skipButtonUpdate(default, set):Bool;
	private function set_skipButtonUpdate(b:Bool):Bool
	{
		skipButtonUpdate = b;
		header.button.skipButtonUpdate = b;
		return b;
	}

	// ─── Selection ──────────────────────────────────────────────────────
	public var selectedId(get, set):String;
	public var selectedLabel(get, set):String;
	private var _selectedId:String;
	private var _selectedLabel:String;

	private var currentScroll:Int = 0;
	public  var canScroll:Bool = true;

	private function get_selectedId():String { return _selectedId; }
	private function set_selectedId(str:String):String
	{
		if (_selectedId == str) return str;
		var i:Int = 0;
		for (btn in list)
		{
			if (btn != null && btn.name == str)
			{
				var item:FlxUIButton = list[i];
				_selectedId = str;
				if (item.label != null) { _selectedLabel = item.label.text; header.text.text = item.label.text; }
				else                    { _selectedLabel = ""; header.text.text = ""; }
				return str;
			}
			i++;
		}
		return str;
	}

	private function get_selectedLabel():String { return _selectedLabel; }
	private function set_selectedLabel(str:String):String
	{
		if (_selectedLabel == str) return str;
		var i:Int = 0;
		for (btn in list)
		{
			if (btn.label.text == str)
			{
				_selectedId    = list[i].name;
				_selectedLabel = str;
				header.text.text = str;
				return str;
			}
			i++;
		}
		return str;
	}

	// ─── Children ───────────────────────────────────────────────────────
	public var header:FlxUIDropDownHeader;
	public var list:Array<FlxUIButton> = [];
	public var dropPanel:FlxSprite;        // we use a plain styled sprite now

	public var params(default, set):Array<Dynamic>;
	private function set_params(p:Array<Dynamic>):Array<Dynamic> { return params = p; }

	public var dropDirection(default, set):FlxUIDropDownMenuDropDirection = Down;
	private function set_dropDirection(d):FlxUIDropDownMenuDropDirection
	{
		dropDirection = d;
		updateButtonPositions();
		return dropDirection;
	}

	public static inline var CLICK_EVENT:String = "click_dropdown";
	public var callback:String->Void;

	// ────────────────────────────────────────────────────────────────────

	public function new(X:Float = 0, Y:Float = 0, DataList:Array<StrNameLabel>,
		?Callback:String->Void, ?Header:FlxUIDropDownHeader,
		?DropPanel:FlxUI9SliceSprite, ?ButtonList:Array<FlxUIButton>,
		?UIControlCallback:Bool->FlxUIDropDownMenu->Void)
	{
		super(X, Y);
		callback = Callback;
		header   = Header;

		if (header == null)
			header = new FlxUIDropDownHeader();

		// Styled drop panel (plain colored sprite, drawn on our own)
		var panelW:Int = Std.int(header.background.width);
		dropPanel = new FlxSprite(0, 0);
		// actual size is set in setData / constructor after list is built
		dropPanel.makeGraphic(panelW, 4, FlxColor.TRANSPARENT);
		dropPanel.visible = false;

		if (DataList != null)
		{
			for (i in 0...DataList.length)
			{
				var data = DataList[i];
				list.push(makeListButton(i, data.label, data.name));
			}
			selectSomething(DataList[0].name, DataList[0].label);
		}
		else if (ButtonList != null)
		{
			for (btn in ButtonList)
			{
				list.push(btn);
				btn.resize(header.background.width, ROW_H);
				btn.x = 0;
			}
		}

		updateButtonPositions();
		rebuildPanel();
		dropPanel.visible = false;
		add(dropPanel);

		for (btn in list)
		{
			add(btn);
			btn.visible = false;
		}

		header.button.onUp.callback = onDropdown;
		add(header);
	}

	// ─── Panel graphic ──────────────────────────────────────────────────
	private function rebuildPanel():Void
	{
		var panelW:Int  = Std.int(header.background.width);
		var panelH:Int  = getPanelHeight();
		if (panelH < 4) panelH = 4;

		// Always force redraw (unique:true) so resizing never serves a stale cached graphic
		dropPanel.makeGraphic(panelW, panelH, FlxColor.TRANSPARENT, true);

		// Dark background
		FlxSpriteUtil.drawRect(dropPanel, 0, 0, panelW, panelH, PANEL_BG);
		// Top + bottom border lines
		FlxSpriteUtil.drawLine(dropPanel, 0, 0,          panelW, 0,          {color: PANEL_BORDER, thickness: 1});
		FlxSpriteUtil.drawLine(dropPanel, 0, panelH - 1, panelW, panelH - 1, {color: PANEL_BORDER, thickness: 1});
		// Left border
		FlxSpriteUtil.drawLine(dropPanel, 0, 0, 0, panelH, {color: PANEL_BORDER, thickness: 1});
		// Right border
		FlxSpriteUtil.drawLine(dropPanel, panelW - 1, 0, panelW - 1, panelH, {color: PANEL_BORDER, thickness: 1});
	}

	private function updateButtonPositions():Void
	{
		var buttonHeight:Int = ROW_H;
		dropPanel.y = header.background.y;

		if (dropsUp())
			dropPanel.y -= getPanelHeight();
		else
			dropPanel.y += HEADER_H;

		var offset:Float = dropPanel.y;
		for (i in 0...currentScroll)
		{
			var button:FlxUIButton = list[i];
			if (button != null) button.y = FlxG.height + 250;
		}
		for (i in currentScroll...list.length)
		{
			var button:FlxUIButton = list[i];
			if (button != null)
			{
				button.y = offset;
				offset  += buttonHeight;
			}
		}
	}

	override function set_visible(Value:Bool):Bool
	{
		var vDrop:Bool   = dropPanel.visible;
		var vBtns:Array<Bool> = [];
		for (i in 0...list.length)
			vBtns.push(list[i] != null ? list[i].visible : false);

		super.set_visible(Value);

		dropPanel.visible = vDrop;
		for (i in 0...list.length)
			if (list[i] != null) list[i].visible = vBtns[i];

		return Value;
	}

	private function dropsUp():Bool
	{
		return dropDirection == Up || (dropDirection == Automatic && exceedsHeight());
	}
	private function exceedsHeight():Bool
	{
		return y + getPanelHeight() + HEADER_H > FlxG.height;
	}
	private function getPanelHeight():Int
	{
		return list.length * ROW_H;
	}

	// ─── Data ───────────────────────────────────────────────────────────
	public function setData(DataList:Array<StrNameLabel>):Void
	{
		var i:Int = 0;
		if (DataList != null)
		{
			for (data in DataList)
			{
				var recycled:Bool = false;
				if (list != null && i <= list.length - 1)
				{
					var btn:FlxUIButton = list[i];
					if (btn != null)
					{
						btn.label.text = data.label;
						list[i].name   = data.name;
						var capturedI:Int = i;
						list[i].onUp.callback = function() { onClickItem(capturedI); };
						recycled       = true;
					}
				}
				else { list = []; }

				if (!recycled)
				{
					var t:FlxUIButton = makeListButton(i, data.label, data.name);
					list.push(t);
					add(t);
					t.visible = false;
				}
				i++;
			}

			if (list.length > DataList.length)
			{
				for (j in DataList.length...list.length)
				{
					var b:FlxUIButton = list.pop();
					b.visible = false;
					b.active  = false;
					remove(b, true);
					b.destroy();
					b = null;
				}
			}
			selectSomething(DataList[0].name, DataList[0].label);
		}
		rebuildPanel();
		updateButtonPositions();
	}

	private function selectSomething(name:String, label:String):Void
	{
		header.text.text = label;
		selectedId       = name;
		selectedLabel    = label;
	}

	// ─── Row button factory ─────────────────────────────────────────────
	private function makeListButton(i:Int, Label:String, Name:String):FlxUIButton
	{
		var capturedIndex:Int = i; // capture by value, not reference
		var t:FlxUIButton = new FlxUIButton(0, 0, Label);
		t.broadcastToFlxUI = false;
		t.onUp.callback    = function() { onClickItem(capturedIndex); };
		t.name             = Name;

		// Custom graphic: dark row with hover highlight
		var bw:Int = Std.int(header.background.width);

		// Normal state: subtle dark row
		var normalKey:String = "nexDDrow_n_" + bw;
		var normalSpr:FlxSprite = new FlxSprite();
		normalSpr.makeGraphic(bw, ROW_H, FlxColor.TRANSPARENT, false, normalKey);
		FlxSpriteUtil.drawRect(normalSpr, 0, 0, bw, ROW_H, PANEL_BG);
		FlxSpriteUtil.drawLine(normalSpr, 0, ROW_H - 1, bw, ROW_H - 1,
			{color: 0xFF1E2A2E, thickness: 1}); // subtle separator

		// Hover state: bright row
		var hoverKey:String = "nexDDrow_h_" + bw;
		var hoverSpr:FlxSprite = new FlxSprite();
		hoverSpr.makeGraphic(bw, ROW_H, FlxColor.TRANSPARENT, false, hoverKey);
		FlxSpriteUtil.drawRect(hoverSpr, 0, 0, bw, ROW_H, ROW_HOVER_BG);
		// Left accent bar on hover
		FlxSpriteUtil.drawRect(hoverSpr, 0, 0, 3, ROW_H, ACCENT_BAR);

		t.loadGraphicSlice9([FlxUIAssets.IMG_INVIS, FlxUIAssets.IMG_HILIGHT, FlxUIAssets.IMG_HILIGHT],
			bw, ROW_H,
			[[1, 1, 3, 3], [1, 1, 3, 3], [1, 1, 3, 3]],
			FlxUI9SliceSprite.TILE_NONE);

		t.labelOffsets[FlxButton.PRESSED].y -= 1;
		t.up_color   = ROW_TEXT;
		t.over_color = ROW_HOVER_TEXT;
		t.down_color = ROW_HOVER_TEXT;

		t.resize(bw - 2, ROW_H - 1);
		t.label.alignment = "left";
		t.autoCenterLabel();
		t.x = 1;
		// Indent text from left accent bar
		for (offset in t.labelOffsets) offset.x += 8;

		return t;
	}

	// ─── Accessors ──────────────────────────────────────────────────────
	public function changeLabelByIndex(i:Int, NewLabel:String):Void
	{
		var btn:FlxUIButton = getBtnByIndex(i);
		if (btn != null && btn.label != null) btn.label.text = NewLabel;
	}

	public function changeLabelById(name:String, NewLabel:String):Void
	{
		var btn:FlxUIButton = getBtnById(name);
		if (btn != null && btn.label != null) btn.label.text = NewLabel;
	}

	public function getBtnByIndex(i:Int):FlxUIButton
	{
		if (i >= 0 && i < list.length) return list[i];
		return null;
	}

	public function getBtnById(name:String):FlxUIButton
	{
		for (btn in list) if (btn.name == name) return btn;
		return null;
	}

	// ─── Update ─────────────────────────────────────────────────────────
	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		#if (FLX_MOUSE || FLX_TOUCH)
		if (dropPanel.visible)
		{
			if (Controls.instance.mobileC)
			{
				if (list.length > 1 && canScroll)
				{
					for (swipe in FlxG.swipes)
					{
						var f = swipe.startPosition.x - swipe.endPosition.x;
						var g = swipe.startPosition.y - swipe.endPosition.y;
						if (25 <= Math.sqrt(f * f + g * g))
						{
							var ang = swipe.startPosition.angleBetween(swipe.endPosition);
							if (-45 <= ang && 45 >= ang)
							{
								currentScroll++;
								if (currentScroll >= list.length) currentScroll = list.length - 1;
								updateButtonPositions();
							}
							else if ((-180 <= ang && -135 >= ang) || (135 <= ang && 180 >= ang))
							{
								--currentScroll;
								if (currentScroll < 0) currentScroll = 0;
								updateButtonPositions();
							}
						}
					}
				}
			}
			else
			{
				if (list.length > 1 && canScroll)
				{
					var lastS:Int = currentScroll;
					if (FlxG.mouse.wheel > 0 || FlxG.keys.justPressed.UP)
					{
						--currentScroll;
						if (currentScroll < 0) currentScroll = 0;
					}
					else if (FlxG.mouse.wheel < 0 || FlxG.keys.justPressed.DOWN)
					{
						currentScroll++;
						if (currentScroll >= list.length) currentScroll = list.length - 1;
					}
					if (lastS != currentScroll) updateButtonPositions();
				}
				if (FlxG.mouse.justPressed && !FlxG.mouse.overlaps(this, camera))
					showList(false);
			}
		}
		#end
	}

	override public function destroy():Void
	{
		super.destroy();
		dropPanel = FlxDestroyUtil.destroy(dropPanel);
		list      = FlxDestroyUtil.destroyArray(list);
		callback  = null;
	}

	// ─── List visibility ─────────────────────────────────────────────────
	private function showList(b:Bool):Void
	{
		for (button in list)
		{
			button.visible = b;
			button.active  = b;
		}
		dropPanel.visible = b;
		if (currentScroll != 0)
		{
			currentScroll = 0;
			updateButtonPositions();
		}
		FlxUI.forceFocus(b, this);
	}

	private function onDropdown():Void
	{
		(dropPanel.visible) ? showList(false) : showList(true);
	}

	private function onClickItem(i:Int):Void
	{
		var item:FlxUIButton = list[i];
		selectSomething(item.name, item.label.text);
		showList(false);
		if (callback != null) callback(item.name);
		if (broadcastToFlxUI) FlxUI.event(CLICK_EVENT, this, item.name, params);
	}

	// ─── Static helper ──────────────────────────────────────────────────
	public static function makeStrIdLabelArray(StringArray:Array<String>, UseIndexID:Bool = false):Array<StrNameLabel>
	{
		var arr:Array<StrNameLabel> = [];
		for (i in 0...StringArray.length)
		{
			var ID:String = UseIndexID ? Std.string(i) : StringArray[i];
			arr[i] = new StrNameLabel(ID, StringArray[i]);
		}
		return arr;
	}
}

// ════════════════════════════════════════════════════════════════════════════
// Header
// ════════════════════════════════════════════════════════════════════════════

/**
 * NexaII-styled dropdown header.
 * Solid cyan-tinted bar with a clean chevron arrow.
 */
class FlxUIDropDownHeader extends FlxUIGroup
{
	public var background:FlxSprite;
	public var text:FlxUIText;
	public var button:FlxUISpriteButton;

	public function new(Width:Int = 160, ?Background:FlxSprite,
		?Text:FlxUIText, ?Button:FlxUISpriteButton)
	{
		super();

		background = Background;
		text       = Text;
		button     = Button;

		// ── Background bar ─────────────────────────────────────────────
		if (background == null)
		{
			background = new FlxSprite(0, 0);
			background.makeGraphic(Width, FlxUIDropDownMenu.HEADER_H,
				FlxColor.TRANSPARENT, false, "nexDDhdr_" + Width);

			// Fill
			FlxSpriteUtil.drawRect(background, 0, 0, Width, FlxUIDropDownMenu.HEADER_H,
				FlxUIDropDownMenu.HEADER_BG);
			// Bottom accent line
			FlxSpriteUtil.drawLine(background,
				0, FlxUIDropDownMenu.HEADER_H - 2,
				Width, FlxUIDropDownMenu.HEADER_H - 2,
				{color: FlxUIDropDownMenu.ACCENT_BAR, thickness: 2});
		}

		// ── Arrow button ───────────────────────────────────────────────
		if (button == null)
		{
			// Draw a simple downward chevron as the arrow sprite
			var arrowSize:Int = FlxUIDropDownMenu.HEADER_H;
			var arrowSpr:FlxSprite = new FlxSprite(0, 0);
			arrowSpr.makeGraphic(arrowSize, arrowSize, FlxColor.TRANSPARENT, false, "nexDDarrow");
			var cx:Int = Std.int(arrowSize / 2);
			var cy:Int = Std.int(arrowSize / 2) + 2;
			// Chevron: two diagonal lines
			FlxSpriteUtil.drawLine(arrowSpr, cx - 7, cy - 4, cx,     cy + 4,
				{color: FlxUIDropDownMenu.HEADER_TEXT, thickness: 2});
			FlxSpriteUtil.drawLine(arrowSpr, cx,     cy + 4, cx + 7, cy - 4,
				{color: FlxUIDropDownMenu.HEADER_TEXT, thickness: 2});

			button = new FlxUISpriteButton(0, 0, arrowSpr);
			button.loadGraphicSlice9([FlxUIAssets.IMG_BUTTON_THIN], 80,
				FlxUIDropDownMenu.HEADER_H,
				[FlxStringUtil.toIntArray(FlxUIAssets.SLICE9_BUTTON)],
				FlxUI9SliceSprite.TILE_NONE, -1, false,
				FlxUIAssets.IMG_BUTTON_SIZE, FlxUIAssets.IMG_BUTTON_SIZE);
		}

		button.resize(background.height, background.height);
		button.x = background.x + background.width - button.width;

		// Widen hitbox to full header width for easy mobile tapping
		button.width        = Width;
		button.offset.x    -= (Width - button.frameWidth);
		button.x            = offset.x;
		button.label.offset.x += button.offset.x;

		// ── Text ───────────────────────────────────────────────────────
		if (text == null)
		{
			text = new FlxUIText(0, 0, Std.int(background.width - background.height));
			text.size  = 10;
			text.bold  = false;
		}
		// Vertically center text
		text.setPosition(10, Std.int((FlxUIDropDownMenu.HEADER_H - text.size) / 2) - 1);
		text.color = FlxUIDropDownMenu.HEADER_TEXT;

		add(background);
		add(button);
		add(text);
	}

	override public function destroy():Void
	{
		super.destroy();
		background = FlxDestroyUtil.destroy(background);
		text       = FlxDestroyUtil.destroy(text);
		button     = FlxDestroyUtil.destroy(button);
	}
}

enum FlxUIDropDownMenuDropDirection
{
	Automatic;
	Down;
	Up;
}
