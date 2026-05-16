package flixel.addons.ui;

import lime.system.Clipboard;
import flash.errors.Error;
import flash.events.KeyboardEvent;
import flash.geom.Rectangle;
import flixel.addons.ui.FlxUI.NamedString;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxColor;

/**
 * NexaII Engine - Redesigned FlxInputText
 * Dark theme with rounded background, glowing border on focus,
 * wide caret, and mobile tap-to-focus support.
 *
 * Based on FlxInputText v1.11 by larsiusprime / Gama11.
 */
class FlxInputText extends FlxText
{
	// ─── Filter / case constants (unchanged API) ────────────────────────
	public static inline var NO_FILTER:Int          = 0;
	public static inline var ONLY_ALPHA:Int         = 1;
	public static inline var ONLY_NUMERIC:Int       = 2;
	public static inline var ONLY_ALPHANUMERIC:Int  = 3;
	public static inline var CUSTOM_FILTER:Int      = 4;

	public static inline var ALL_CASES:Int          = 0;
	public static inline var UPPER_CASE:Int         = 1;
	public static inline var LOWER_CASE:Int         = 2;

	public static inline var BACKSPACE_ACTION:String = "backspace";
	public static inline var DELETE_ACTION:String    = "delete";
	public static inline var ENTER_ACTION:String     = "enter";
	public static inline var INPUT_ACTION:String     = "input";
	public static inline var PASTE_ACTION:String     = "paste";
	public static inline var COPY_ACTION:String      = "copy";
	public static inline var CUT_ACTION:String       = "cut";

	// ─── Theme ──────────────────────────────────────────────────────────
	/** Normal background (dark panel) */
	public static inline var THEME_BG:Int           = 0xFF1A1D2E;
	/** Idle border color */
	public static inline var THEME_BORDER_IDLE:Int  = 0xFF37474F;
	/** Focused border color (neon cyan glow) */
	public static inline var THEME_BORDER_FOCUS:Int = 0xFF00E5FF;
	/** Text color */
	public static inline var THEME_TEXT:Int         = 0xFFE0F7FA;
	/** Caret color */
	public static inline var THEME_CARET:Int        = 0xFF00E5FF;
	/** Corner radius for rounded rect */
	public static inline var CORNER_RADIUS:Int      = 6;
	/** Border thickness */
	public static inline var BORDER_PX:Int          = 2;
	/** Minimum field height for mobile tap comfort */
	public static inline var MIN_HEIGHT:Int         = 36;

	// ─── Public API ─────────────────────────────────────────────────────
	public var customFilterPattern(default, set):EReg;
	public var callback:String->String->Void;
	public var background:Bool = false;

	public var caretColor(default, set):Int;
	function set_caretColor(i:Int):Int { caretColor = i; dirty = true; return caretColor; }

	public var caretWidth(default, set):Int = 2; // wider for visibility
	function set_caretWidth(i:Int):Int { caretWidth = i; dirty = true; return caretWidth; }

	public var params(default, set):Array<Dynamic>;

	public var passwordMode(get, set):Bool;
	public var hasFocus(default, set):Bool = false;
	public var caretIndex(default, set):Int = 0;
	public var focusGained:Void->Void;
	public var focusLost:Void->Void;
	public var forceCase(default, set):Int = ALL_CASES;
	public var maxLength(default, set):Int  = 0;
	public var lines(default, set):Int;
	public var filterMode(default, set):Int = NO_FILTER;

	// Keep original field names so consumers don't break,
	// but we override calcFrame to use our styled sprites.
	public var fieldBorderColor(default, set):Int       = THEME_BORDER_IDLE;
	public var fieldBorderThickness(default, set):Int   = BORDER_PX;
	public var backgroundColor(default, set):Int        = THEME_BG;

	private var backgroundSprite:FlxSprite;
	private var _caretTimer:FlxTimer;
	private var caret:FlxSprite;
	private var fieldBorderSprite:FlxSprite;

	private var _scrollBoundIndeces:{left:Int, right:Int} = {left: 0, right: 0};
	private var _charBoundaries:Array<FlxRect>;
	private var lastScroll:Int;

	// ────────────────────────────────────────────────────────────────────

	public function new(X:Float = 0, Y:Float = 0, Width:Int = 200, ?Text:String,
		size:Int = 10, TextColor:Int = THEME_TEXT, BackgroundColor:Int = THEME_BG,
		EmbeddedFont:Bool = true)
	{
		super(X, Y, Width, Text, size, EmbeddedFont);

		backgroundColor  = BackgroundColor;
		fieldBorderColor = THEME_BORDER_IDLE;

		if (BackgroundColor != FlxColor.TRANSPARENT)
			background = true;

		color      = TextColor;
		caretColor = THEME_CARET;

		// Tall caret for legibility
		caret = new FlxSprite();
		caret.makeGraphic(caretWidth, Std.int(size + 4));
		_caretTimer = new FlxTimer();

		caretIndex = 0;
		hasFocus   = false;

		if (background)
		{
			fieldBorderSprite = new FlxSprite(X, Y);
			backgroundSprite  = new FlxSprite(X, Y);
		}

		lines = 1;
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);

		if (Text == null) Text = "";
		text = Text;

		calcFrame();
	}

	override public function destroy():Void
	{
		FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		backgroundSprite  = FlxDestroyUtil.destroy(backgroundSprite);
		fieldBorderSprite = FlxDestroyUtil.destroy(fieldBorderSprite);
		callback = null;

		#if sys
		if (_charBoundaries != null)
		{
			while (_charBoundaries.length > 0) _charBoundaries.pop();
			_charBoundaries = null;
		}
		#end

		super.destroy();
	}

	override public function draw():Void
	{
		drawSprite(fieldBorderSprite);
		drawSprite(backgroundSprite);
		super.draw();

		if (caretColor != caret.color || caret.height != size + 4)
			caret.color = caretColor;

		drawSprite(caret);
	}

	private function drawSprite(Sprite:FlxSprite):Void
	{
		if (Sprite != null && Sprite.visible)
		{
			Sprite.scrollFactor = scrollFactor;
			Sprite.cameras = cameras;
			Sprite.draw();
		}
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		#if FLX_MOUSE
		if (FlxG.mouse.justPressed)
		{
			var hadFocus:Bool = hasFocus;
			if (FlxG.mouse.overlaps(this, camera))
			{
				caretIndex = getCaretIndex();
				hasFocus   = FlxG.stage.window.textInputEnabled = true;
				if (!hadFocus && focusGained != null) focusGained();
			}
			else
			{
				hasFocus = false;
				if (hadFocus && focusLost != null) focusLost();
			}
		}
		#end

		#if FLX_TOUCH
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				var hadFocus:Bool = hasFocus;
				if (touch.overlaps(this, camera))
				{
					hasFocus = FlxG.stage.window.textInputEnabled = true;
					caretIndex = text.length;
					if (!hadFocus && focusGained != null) focusGained();
				}
				else
				{
					hasFocus = false;
					if (hadFocus && focusLost != null) focusLost();
				}
			}
		}
		#end
	}

	private function onKeyDown(e:KeyboardEvent):Void
	{
		var key:Int = e.keyCode;

		if (hasFocus)
		{
			#if macos
			if (key == 67 && e.commandKey) {
			#else
			if (key == 67 && e.ctrlKey) {
			#end
				Clipboard.text = text;
				onChange(COPY_ACTION);
				return;
			}

			#if macos
			if (key == 86 && e.commandKey) {
			#else
			if (key == 86 && e.ctrlKey) {
			#end
				var newText:String = filter(Clipboard.text);
				if (newText.length > 0 && (maxLength == 0 || (text.length + newText.length) < maxLength))
				{
					text = insertSubstring(text, newText, caretIndex);
					caretIndex += newText.length;
					onChange(INPUT_ACTION);
					onChange(PASTE_ACTION);
				}
				return;
			}

			#if macos
			if (key == 88 && e.commandKey) {
			#else
			if (key == 88 && e.ctrlKey) {
			#end
				Clipboard.text = text;
				text = '';
				caretIndex = 0;
				onChange(INPUT_ACTION);
				onChange(CUT_ACTION);
				return;
			}

			if (key == 16 || key == 17 || key == 220 || key == 27) return;
			else if (key == 37) { if (caretIndex > 0) { caretIndex--; text = text; } }
			else if (key == 39) { if (caretIndex < text.length) { caretIndex++; text = text; } }
			else if (key == 35) { caretIndex = text.length; text = text; }
			else if (key == 36) { caretIndex = 0; text = text; }
			else if (key == 8)
			{
				if (caretIndex > 0)
				{
					caretIndex--;
					text = text.substring(0, caretIndex) + text.substring(caretIndex + 1);
					onChange(BACKSPACE_ACTION);
				}
			}
			else if (key == 46)
			{
				if (text.length > 0 && caretIndex < text.length)
				{
					text = text.substring(0, caretIndex) + text.substring(caretIndex + 1);
					onChange(DELETE_ACTION);
				}
			}
			else if (key == 13)
			{
				onChange(ENTER_ACTION);
			}
			else
			{
				if (e.charCode == 0) return;
				var newText:String = filter(String.fromCharCode(e.charCode));
				if (newText.length > 0 && (maxLength == 0 || (text.length + newText.length) < maxLength))
				{
					text = insertSubstring(text, newText, caretIndex);
					caretIndex++;
					onChange(INPUT_ACTION);
				}
			}
		}
	}

	private function onChange(action:String):Void
	{
		if (callback != null) callback(text, action);
	}

	private function insertSubstring(Original:String, Insert:String, Index:Int):String
	{
		if (Index != Original.length)
			Original = Original.substring(0, Index) + Insert + Original.substring(Index);
		else
			Original = Original + Insert;
		return Original;
	}

	private function getCaretIndex():Int
	{
		#if FLX_MOUSE
		var hit = FlxPoint.get(FlxG.mouse.x - x, FlxG.mouse.y - y);
		return getCharIndexAtPoint(hit.x, hit.y);
		#else
		return 0;
		#end
	}

	private function getCharBoundaries(charIndex:Int):Rectangle
	{
		if (_charBoundaries != null && charIndex >= 0 && _charBoundaries.length > 0)
		{
			var r:Rectangle = new Rectangle();
			if (charIndex >= _charBoundaries.length)
				_charBoundaries[_charBoundaries.length - 1].copyToFlash(r);
			else
				_charBoundaries[charIndex].copyToFlash(r);
			return r;
		}
		return null;
	}

	private override function set_text(Text:String):String
	{
		#if !js
		if (textField != null) lastScroll = textField.scrollH;
		#end
		var return_text:String = super.set_text(Text);
		if (textField == null) return return_text;

		var numChars:Int = Text.length;
		prepareCharBoundaries(numChars);
		textField.text = "";
		var textH:Float = 0;
		var textW:Float = 0;
		var lastW:Float = 0;
		var magicX:Float = 2;
		var magicY:Float = 2;

		for (i in 0...numChars)
		{
			textField.appendText(Text.substr(i, 1));
			textW = textField.textWidth;
			if (i == 0) textH = textField.textHeight;
			_charBoundaries[i].x      = magicX + lastW;
			_charBoundaries[i].y      = magicY;
			_charBoundaries[i].width  = textW - lastW;
			_charBoundaries[i].height = textH;
			lastW = textW;
		}
		textField.text = Text;
		onSetTextCheck();
		return return_text;
	}

	private function getCharIndexAtPoint(X:Float, Y:Float):Int
	{
		var i:Int = 0;
		#if !js
		X += textField.scrollH + 2;
		#end
		if (_charBoundaries != null && _charBoundaries.length > 0)
		{
			if (textField.textWidth <= textField.width)
			{
				switch (getAlignStr())
				{
					case RIGHT:  X = X - textField.width + textField.textWidth;
					case CENTER: X = X - textField.width / 2 + textField.textWidth / 2;
					default:
				}
			}
		}
		if (_charBoundaries != null)
		{
			for (r in _charBoundaries)
			{
				if (X >= r.left && X <= r.right) return i;
				i++;
			}
		}
		if (_charBoundaries != null && _charBoundaries.length > 0)
			if (X > textField.textWidth) return _charBoundaries.length;
		return 0;
	}

	private function prepareCharBoundaries(numChars:Int):Void
	{
		if (_charBoundaries == null) _charBoundaries = [];
		if (_charBoundaries.length > numChars)
		{
			var diff:Int = _charBoundaries.length - numChars;
			for (i in 0...diff) _charBoundaries.pop();
		}
		for (i in 0...numChars)
			if (_charBoundaries.length - 1 < i)
				_charBoundaries.push(FlxRect.get(0, 0, 0, 0));
	}

	private function onSetTextCheck():Void
	{
		#if !js
		var boundary:Rectangle = null;
		if (caretIndex == -1)
			boundary = getCharBoundaries(text.length - 1);
		else
			boundary = getCharBoundaries(caretIndex);

		if (boundary != null)
		{
			var diffW:Int = 0;
			if (boundary.right > lastScroll + textField.width - 2)
				diffW = -Std.int((textField.width - 2) - boundary.right);
			else if (boundary.left < lastScroll)
				diffW = Std.int(boundary.left) - 2;
			else
				diffW = lastScroll;
			#if !js
			textField.scrollH = diffW;
			#end
			calcFrame();
		}
		#end
	}

	private override function calcFrame(RunOnCpp:Bool = false):Void
	{
		super.calcFrame(RunOnCpp);

		// ── Styled border (rounded rect) ──────────────────────────────
		if (fieldBorderSprite != null && fieldBorderThickness > 0)
		{
			var bw:Int = Std.int(width  + fieldBorderThickness * 2);
			var bh:Int = Std.int(height + fieldBorderThickness * 2);
			if (bh < 4) bh = 4;
			var borderCol:Int = hasFocus ? THEME_BORDER_FOCUS : THEME_BORDER_IDLE;

			// Use 'true' to force redraw so focus color always updates
			fieldBorderSprite.makeGraphic(bw, bh, FlxColor.TRANSPARENT, true);
			FlxSpriteUtil.drawRoundRect(fieldBorderSprite, 0, 0, bw, bh,
				CORNER_RADIUS * 2, CORNER_RADIUS * 2, borderCol);

			fieldBorderSprite.x = x - fieldBorderThickness;
			fieldBorderSprite.y = y - fieldBorderThickness;
		}
		else if (fieldBorderSprite != null && fieldBorderThickness == 0)
		{
			fieldBorderSprite.visible = false;
		}

		// ── Styled background (rounded rect, slightly inset) ──────────
		if (backgroundSprite != null)
		{
			if (background)
			{
				var bw2:Int = Std.int(width);
				var bh2:Int = Std.int(height);
				if (bh2 < 4) bh2 = 4;
				backgroundSprite.makeGraphic(bw2, bh2, FlxColor.TRANSPARENT, true);
				FlxSpriteUtil.drawRoundRect(backgroundSprite, 0, 0, bw2, bh2,
					CORNER_RADIUS * 2 - 2, CORNER_RADIUS * 2 - 2, backgroundColor);
				backgroundSprite.x = x;
				backgroundSprite.y = y;
			}
			else
			{
				backgroundSprite.visible = false;
			}
		}

		// ── Caret ────────────────────────────────────────────────────
		if (caret != null)
		{
			var cw:Int = caretWidth;
			var ch:Int = Std.int(size + 4);

			var borderC:Int = 0xff000000 | (borderColor & 0x00ffffff);
			var caretC:Int  = 0xff000000 | (caretColor  & 0x00ffffff);
			var caretKey:String = "nexCaret" + cw + "x" + ch + "c:" + caretC;

			switch (borderStyle)
			{
				case NONE:
					caret.makeGraphic(cw, ch, caretC, false, caretKey);
					caret.offset.x = caret.offset.y = 0;
				case SHADOW:
					cw += Std.int(borderSize);
					ch += Std.int(borderSize);
					caret.makeGraphic(cw, ch, FlxColor.TRANSPARENT, false, caretKey);
					var r:Rectangle = new Rectangle(borderSize, borderSize, caretWidth, Std.int(size + 4));
					caret.pixels.fillRect(r, borderC);
					r.x = r.y = 0;
					caret.pixels.fillRect(r, caretC);
					caret.offset.x = caret.offset.y = 0;
				case OUTLINE_FAST, OUTLINE:
					cw += Std.int(borderSize * 2);
					ch += Std.int(borderSize * 2);
					caret.makeGraphic(cw, ch, borderC, false, caretKey);
					var r = new Rectangle(borderSize, borderSize, caretWidth, Std.int(size + 4));
					caret.pixels.fillRect(r, caretC);
					caret.offset.x = caret.offset.y = borderSize;
			}
			caret.width  = cw;
			caret.height = ch;
			caretIndex   = caretIndex;
		}
	}

	private function toggleCaret(timer:FlxTimer):Void
	{
		caret.visible = !caret.visible;
	}

	private function filter(text:String):String
	{
		if (forceCase == UPPER_CASE) text = text.toUpperCase();
		else if (forceCase == LOWER_CASE) text = text.toLowerCase();

		if (filterMode != NO_FILTER)
		{
			var pattern:EReg;
			switch (filterMode)
			{
				case ONLY_ALPHA:         pattern = ~/[^a-zA-Z]*/g;
				case ONLY_NUMERIC:       pattern = ~/[^0-9]*/g;
				case ONLY_ALPHANUMERIC:  pattern = ~/[^a-zA-Z0-9]*/g;
				case CUSTOM_FILTER:      pattern = customFilterPattern;
				default: throw new Error("FlxInputText: Unknown filterMode (" + filterMode + ")");
			}
			text = pattern.replace(text, "");
		}
		return text;
	}

	function set_customFilterPattern(cfp:EReg) { customFilterPattern = cfp; filterMode = CUSTOM_FILTER; return customFilterPattern; }

	private function set_params(p:Array<Dynamic>):Array<Dynamic>
	{
		params = p;
		if (params == null) params = [];
		var namedValue:NamedString = {name: "value", value: text};
		params.push(namedValue);
		return p;
	}

	private override function set_x(X:Float):Float
	{
		if ((fieldBorderSprite != null) && fieldBorderThickness > 0)
			fieldBorderSprite.x = X - fieldBorderThickness;
		if ((backgroundSprite != null) && background)
			backgroundSprite.x = X;
		return super.set_x(X);
	}

	private override function set_y(Y:Float):Float
	{
		if ((fieldBorderSprite != null) && fieldBorderThickness > 0)
			fieldBorderSprite.y = Y - fieldBorderThickness;
		if ((backgroundSprite != null) && background)
			backgroundSprite.y = Y;
		return super.set_y(Y);
	}

	private function set_hasFocus(newFocus:Bool):Bool
	{
		if (newFocus)
		{
			if (hasFocus != newFocus)
			{
				_caretTimer = new FlxTimer().start(0.5, toggleCaret, 0);
				caret.visible = true;
				caretIndex = text.length;
			}
		}
		else
		{
			caret.visible = false;
			if (_caretTimer != null) _caretTimer.cancel();
		}
		if (newFocus != hasFocus) calcFrame(); // redraw border color
		return hasFocus = newFocus;
	}

	private function getAlignStr():FlxTextAlign
	{
		var alignStr:FlxTextAlign = LEFT;
		if (_defaultFormat != null && _defaultFormat.align != null)
			alignStr = alignment;
		return alignStr;
	}

	private function set_caretIndex(newCaretIndex:Int):Int
	{
		var offx:Float = 0;
		var alignStr:FlxTextAlign = getAlignStr();
		switch (alignStr)
		{
			case RIGHT:
				offx = textField.width - 2 - textField.textWidth - 2;
				if (offx < 0) offx = 0;
			case CENTER:
				#if !js
				offx = (textField.width - 2 - textField.textWidth) / 2 + textField.scrollH / 2;
				#end
				if (offx <= 1) offx = 0;
			default:
				offx = 0;
		}

		caretIndex = newCaretIndex;
		if (caretIndex > (text.length + 1)) caretIndex = -1;

		if (caretIndex != -1)
		{
			var boundaries:Rectangle = null;
			if (caretIndex < text.length)
			{
				boundaries = getCharBoundaries(caretIndex);
				if (boundaries != null) { caret.x = offx + boundaries.left + x; caret.y = boundaries.top + y; }
			}
			else
			{
				boundaries = getCharBoundaries(caretIndex - 1);
				if (boundaries != null) { caret.x = offx + boundaries.right + x; caret.y = boundaries.top + y; }
				else if (text.length == 0) { caret.x = x + offx + 2; caret.y = y + 2; }
			}
		}

		#if !js
		caret.x -= textField.scrollH;
		#end
		if ((lines == 1) && (caret.x + caret.width) > (x + width))
			caret.x = x + width - 2;

		return caretIndex;
	}

	private function set_forceCase(Value:Int):Int { forceCase = Value; text = filter(text); return forceCase; }
	override private function set_size(Value:Int):Int { super.size = Value; caret.makeGraphic(caretWidth, Std.int(size + 4)); return Value; }
	private function set_maxLength(Value:Int):Int { maxLength = Value; if (text.length > maxLength) text = text.substring(0, maxLength); return maxLength; }

	private function set_lines(Value:Int):Int
	{
		if (Value == 0) return 0;
		if (Value > 1) { textField.wordWrap = true;  textField.multiline = true; }
		else           { textField.wordWrap = false; textField.multiline = false; }
		lines = Value; calcFrame(); return lines;
	}

	private function get_passwordMode():Bool { return textField.displayAsPassword; }
	private function set_passwordMode(value:Bool):Bool { textField.displayAsPassword = value; calcFrame(); return value; }
	private function set_filterMode(Value:Int):Int { filterMode = Value; text = filter(text); return filterMode; }
	private function set_fieldBorderColor(Value:Int):Int { fieldBorderColor = Value; calcFrame(); return fieldBorderColor; }
	private function set_fieldBorderThickness(Value:Int):Int { fieldBorderThickness = Value; calcFrame(); return fieldBorderThickness; }
	private function set_backgroundColor(Value:Int):Int { backgroundColor = Value; calcFrame(); return backgroundColor; }
}
