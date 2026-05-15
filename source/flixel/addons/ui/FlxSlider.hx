package flixel.addons.ui;

#if FLX_MOUSE
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxSpriteUtil;
import flixel.util.FlxColor;

/**
 * NexaII Engine - Redesigned FlxSlider
 * Modern dark theme with neon accents, pill handle, glow track.
 * Mobile-friendly: large touch targets, touch drag support.
 * @author Gama11 (original), redesigned for NexaII Engine
 */
class FlxSlider extends FlxSpriteGroup
{
	// ─── Theme constants ───────────────────────────────────────────────
	/** Track background color (dark gunmetal) */
	public static inline var TRACK_BG_COLOR:Int     = 0xFF1A1D2E;
	/** Filled track / accent color (electric cyan) */
	public static inline var ACCENT_COLOR:Int        = 0xFF00E5FF;
	/** Handle color (bright white-cyan) */
	public static inline var HANDLE_COLOR:Int        = 0xFFE0F7FA;
	/** Handle border color (deep cyan) */
	public static inline var HANDLE_BORDER:Int       = 0xFF0097A7;
	/** Label / min-max text color */
	public static inline var LABEL_COLOR:Int         = 0xFF90A4AE;
	/** Value text color (accent) */
	public static inline var VALUE_COLOR:Int         = 0xFF00E5FF;
	/** Track height in pixels */
	public static inline var TRACK_HEIGHT:Int        = 6;
	/** Handle width for mobile-easy tapping */
	public static inline var HANDLE_W:Int            = 22;
	/** Handle height (pill shape) */
	public static inline var HANDLE_H:Int            = 34;
	/** Minimum touch-hit-area half-width for mobile */
	public static inline var TOUCH_PAD:Int           = 28;

	// ─── Public API (matches original FlxSlider) ───────────────────────
	public var body:FlxSprite;
	public var bodyFill:FlxSprite;   // filled portion of track
	public var handle:FlxSprite;
	public var minLabel:FlxText;
	public var maxLabel:FlxText;
	public var nameLabel:FlxText;
	public var valueLabel:FlxText;

	public var value:Float;
	public var minValue:Float;
	public var maxValue:Float;
	public var decimals:Int = 0;
	public var clickSound:String;
	public var hoverSound:String;
	public var hoverAlpha:Float = 0.85;
	public var callback:Float->Void = null;
	public var setVariable:Bool = true;

	public var expectedPos(get, never):Float;
	public var relativePos(get, never):Float;
	public var varString(default, set):String;

	var _bounds:FlxRect;
	var _width:Int;
	var _height:Int;
	var _thickness:Int;
	var _color:FlxColor;
	var _handleColor:FlxColor;
	var _object:Dynamic;
	var _lastPos:Float;
	var _justClicked:Bool = false;
	var _justHovered:Bool = false;

	// touch drag support
	var _touchDragging:Bool = false;

	public function new(Object:Dynamic, VarString:String, X:Float = 0, Y:Float = 0,
		MinValue:Float = 0, MaxValue:Float = 10, Width:Int = 200, Height:Int = HANDLE_H,
		Thickness:Int = TRACK_HEIGHT, Color:Int = TRACK_BG_COLOR, HandleColor:Int = HANDLE_COLOR)
	{
		super();
		x = X;
		y = Y;

		if (MinValue == MaxValue)
			FlxG.log.error("FlxSlider: MinValue and MaxValue can't be the same (" + MinValue + ")");

		decimals = FlxMath.getDecimals(MinValue);
		if (FlxMath.getDecimals(MaxValue) > decimals)
			decimals = FlxMath.getDecimals(MaxValue);
		decimals++;

		minValue    = MinValue;
		maxValue    = MaxValue;
		_object     = Object;
		varString   = VarString;
		_width      = Width;
		_height     = Height;
		_thickness  = Thickness;
		_color      = Color;
		_handleColor = HandleColor;

		createSlider();
	}

	function createSlider():Void
	{
		// Layout: handle is vertically centred; track is centered too.
		// offset.x accounts for handle overhang on each side.
		var trackY:Int  = Std.int((HANDLE_H - TRACK_HEIGHT) / 2);
		var trackX:Int  = Std.int(HANDLE_W / 2);
		offset.set(trackX, 20); // 20px reserved above for nameLabel

		_bounds = FlxRect.get(x + offset.x, y + offset.y + trackY, _width, HANDLE_H);

		// ── Track background ──────────────────────────────────────────
		body = new FlxSprite(offset.x, offset.y + trackY);
		body.makeGraphic(_width, TRACK_HEIGHT, FlxColor.TRANSPARENT, false,
			"nexSliderTrack_" + _width);
		FlxSpriteUtil.drawRoundRect(body, 0, 0, _width, TRACK_HEIGHT, TRACK_HEIGHT, TRACK_HEIGHT,
			TRACK_BG_COLOR);
		body.scrollFactor.set();

		// ── Filled track (updates each frame) ────────────────────────
		bodyFill = new FlxSprite(offset.x, offset.y + trackY);
		bodyFill.makeGraphic(_width, TRACK_HEIGHT, ACCENT_COLOR, false, "nexSliderFill_" + _width);
		bodyFill.scrollFactor.set();

		// ── Handle (pill shape) ───────────────────────────────────────
		handle = new FlxSprite(offset.x, offset.y);
		handle.makeGraphic(HANDLE_W, HANDLE_H, FlxColor.TRANSPARENT, false, "nexSliderHandle");
		// Outer border
		FlxSpriteUtil.drawRoundRect(handle, 0, 0, HANDLE_W, HANDLE_H, HANDLE_W, HANDLE_W,
			HANDLE_BORDER);
		// Inner fill
		FlxSpriteUtil.drawRoundRect(handle, 2, 2, HANDLE_W - 4, HANDLE_H - 4,
			HANDLE_W - 4, HANDLE_W - 4, HANDLE_COLOR);
		// Grip lines (3 horizontal dashes in the middle)
		var cx:Int = Std.int(HANDLE_W / 2);
		var cy:Int = Std.int(HANDLE_H / 2);
		for (i in -1...2)
		{
			FlxSpriteUtil.drawLine(handle, cx - 5, cy + i * 5, cx + 5, cy + i * 5,
				{color: HANDLE_BORDER, thickness: 1});
		}
		handle.scrollFactor.set();

		// ── Labels ────────────────────────────────────────────────────
		nameLabel = new FlxText(offset.x, 2, _width, varString, 10);
		nameLabel.alignment   = "center";
		nameLabel.color       = LABEL_COLOR;
		nameLabel.bold        = true;
		nameLabel.scrollFactor.set();

		var textY:Float = offset.y + HANDLE_H + 4;

		valueLabel = new FlxText(offset.x, textY, _width, "", 10);
		valueLabel.alignment  = "center";
		valueLabel.color      = VALUE_COLOR;
		valueLabel.bold       = true;
		valueLabel.scrollFactor.set();

		minLabel = new FlxText(offset.x - 30, textY, 60, Std.string(minValue), 9);
		minLabel.alignment = "left";
		minLabel.color     = LABEL_COLOR;
		minLabel.scrollFactor.set();

		maxLabel = new FlxText(offset.x + _width - 30, textY, 60, Std.string(maxValue), 9);
		maxLabel.alignment = "right";
		maxLabel.color     = LABEL_COLOR;
		maxLabel.scrollFactor.set();

		add(body);
		add(bodyFill);
		add(handle);
		add(nameLabel);
		add(valueLabel);
		add(minLabel);
		add(maxLabel);
	}

	override public function update(elapsed:Float):Void
	{
		var inRect:Bool = false;
		var pressing:Bool = false;
		var pressX:Float  = 0;

		#if FLX_MOUSE
		if (!Controls.instance.mobileC)
		{
			inRect   = mouseInRect(_bounds);
			pressing = FlxG.mouse.pressed;
			pressX   = FlxG.mouse.getPositionInCameraView(camera).x;
		}
		#end

		#if FLX_TOUCH
		if (Controls.instance.mobileC)
		{
			for (touch in FlxG.touches.list)
			{
				if (touch.pressed)
				{
					var tp:FlxPoint = touch.getPositionInCameraView(camera);
					// Use wider touch target for mobile
					var touchBounds = FlxRect.get(
						_bounds.x - TOUCH_PAD, _bounds.y,
						_bounds.width + TOUCH_PAD * 2, _bounds.height
					);
					if (FlxMath.pointInFlxRect(tp.x, tp.y, touchBounds))
					{
						inRect   = true;
						pressing = true;
						pressX   = tp.x;
					}
					touchBounds.put();
				}
			}
		}
		#end

		if (inRect)
		{
			alpha = hoverAlpha;

			#if FLX_SOUND_SYSTEM
			if (hoverSound != null && !_justHovered)
				FlxG.sound.play(hoverSound);
			#end
			_justHovered = true;

			if (pressing)
			{
				handle.x = pressX - Std.int(HANDLE_W / 2);
				updateValue();

				#if FLX_SOUND_SYSTEM
				if (clickSound != null && !_justClicked)
				{
					FlxG.sound.play(clickSound);
					_justClicked = true;
				}
				#end
			}
		}
		else
		{
			alpha = 1;
			_justHovered = false;
		}

		if (!pressing)
			_justClicked = false;

		if ((varString != null) && (Reflect.getProperty(_object, varString) != null))
			value = Reflect.getProperty(_object, varString);

		if (handle.x != expectedPos)
			handle.x = expectedPos;

		// Update filled track width
		var fillW:Int = Std.int(handle.x + HANDLE_W / 2 - (x + offset.x));
		if (fillW < 0) fillW = 0;
		if (fillW > _width) fillW = _width;
		bodyFill.makeGraphic(fillW > 0 ? fillW : 1, TRACK_HEIGHT, ACCENT_COLOR, false, "fill_dyn");

		valueLabel.text = Std.string(FlxMath.roundDecimal(value, decimals));

		super.update(elapsed);
	}

	private function mouseInRect(rect:FlxRect):Bool
	{
		#if FLX_MOUSE
		var mp = FlxG.mouse.getPositionInCameraView(camera);
		return FlxMath.pointInFlxRect(mp.x, mp.y, rect);
		#else
		return false;
		#end
	}

	function updateValue():Void
	{
		if (_lastPos != relativePos)
		{
			if ((setVariable) && (varString != null))
				Reflect.setProperty(_object, varString, (relativePos * (maxValue - minValue)) + minValue);

			_lastPos = relativePos;

			if (callback != null)
				callback(relativePos);
		}
	}

	public function setTexts(Name:String, Value:Bool = true, ?Min:String, ?Max:String, Size:Int = 9):Void
	{
		nameLabel.visible  = (Name != null);
		if (Name != null) nameLabel.text = Name;

		minLabel.visible   = (Min != null);
		if (Min != null) minLabel.text = Min;

		maxLabel.visible   = (Max != null);
		if (Max != null) maxLabel.text = Max;

		valueLabel.visible = Value;

		nameLabel.size  = Size;
		valueLabel.size = Size;
		minLabel.size   = Std.int(Size * 0.9);
		maxLabel.size   = Std.int(Size * 0.9);
	}

	override public function destroy():Void
	{
		body       = FlxDestroyUtil.destroy(body);
		bodyFill   = FlxDestroyUtil.destroy(bodyFill);
		handle     = FlxDestroyUtil.destroy(handle);
		minLabel   = FlxDestroyUtil.destroy(minLabel);
		maxLabel   = FlxDestroyUtil.destroy(maxLabel);
		nameLabel  = FlxDestroyUtil.destroy(nameLabel);
		valueLabel = FlxDestroyUtil.destroy(valueLabel);
		_bounds    = FlxDestroyUtil.put(_bounds);
		super.destroy();
	}

	function get_expectedPos():Float
	{
		var pos:Float = x + offset.x + ((_width - HANDLE_W) * ((value - minValue) / (maxValue - minValue)));
		if (pos > x + _width + offset.x - HANDLE_W) pos = x + _width + offset.x - HANDLE_W;
		if (pos < x + offset.x)                     pos = x + offset.x;
		return pos;
	}

	function get_relativePos():Float
	{
		var pos:Float = (handle.x - x - offset.x) / (_width - HANDLE_W);
		if (pos > 1) pos = 1;
		if (pos < 0) pos = 0;
		return pos;
	}

	function set_varString(Value:String):String
	{
		try
		{
			Reflect.getProperty(_object, Value);
			varString = Value;
		}
		catch (e:Dynamic)
		{
			FlxG.log.error("FlxSlider: '" + Value + "' is not a valid field of '" + _object + "'");
			varString = null;
		}
		return Value;
	}

	override function set_x(value:Float):Float
	{
		super.set_x(value);
		updateBounds();
		return x = value;
	}

	override function set_y(value:Float):Float
	{
		super.set_y(value);
		updateBounds();
		return y = value;
	}

	inline function updateBounds()
	{
		if (_bounds != null)
		{
			var trackY = Std.int((HANDLE_H - TRACK_HEIGHT) / 2);
			_bounds.set(x + offset.x, y + offset.y + trackY, _width, HANDLE_H);
		}
	}
}
#end
