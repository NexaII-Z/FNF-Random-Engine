package flixel.addons.ui;

import flixel.addons.ui.interfaces.IFlxUIWidget;
import flixel.addons.ui.interfaces.IHasParams;
import flixel.addons.ui.interfaces.IResizable;

/**
 * NexaII Engine - Redesigned FlxUIInputText
 * Thin wrapper around the redesigned FlxInputText.
 * All theming lives in FlxInputText; this file only manages FlxUI events.
 *
 * @author Lars Doucet (original), NexaII Engine reskin
 */
class FlxUIInputText extends FlxInputText implements IResizable implements IFlxUIWidget implements IHasParams
{
	public var name:String;
	public var broadcastToFlxUI:Bool = true;

	public static inline var CHANGE_EVENT:String = "change_input_text";
	public static inline var ENTER_EVENT:String  = "enter_input_text";
	public static inline var DELETE_EVENT:String = "delete_input_text";
	public static inline var INPUT_EVENT:String  = "input_input_text";
	public static inline var COPY_EVENT:String   = "copy_input_text";
	public static inline var PASTE_EVENT:String  = "paste_input_text";
	public static inline var CUT_EVENT:String    = "cut_input_text";

	/**
	 * @param X              X position
	 * @param Y              Y position
	 * @param Width          Field width (height is auto)
	 * @param Text           Initial text
	 * @param size           Font size (default 10 for readability)
	 * @param TextColor      Text colour (defaults to theme cyan-white)
	 * @param BackgroundColor Background (defaults to dark panel)
	 * @param EmbeddedFont   Use embedded fonts
	 */
	public function new(X:Float = 0, Y:Float = 0, Width:Int = 200, ?Text:String,
		size:Int = 10, TextColor:Int = FlxInputText.THEME_TEXT,
		BackgroundColor:Int = FlxInputText.THEME_BG, EmbeddedFont:Bool = true)
	{
		super(X, Y, Width, Text, size, TextColor, BackgroundColor, EmbeddedFont);
	}

	public function resize(w:Float, h:Float):Void
	{
		width = w;
		height = h;
		calcFrame();
	}

	private override function onChange(action:String):Void
	{
		super.onChange(action);
		if (broadcastToFlxUI)
		{
			switch (action)
			{
				case FlxInputText.ENTER_ACTION:
					FlxUI.event(ENTER_EVENT, this, text, params);
				case FlxInputText.DELETE_ACTION, FlxInputText.BACKSPACE_ACTION:
					FlxUI.event(DELETE_EVENT, this, text, params);
					FlxUI.event(CHANGE_EVENT, this, text, params);
				case FlxInputText.INPUT_ACTION:
					FlxUI.event(INPUT_EVENT, this, text, params);
					FlxUI.event(CHANGE_EVENT, this, text, params);
				case FlxInputText.COPY_ACTION:
					FlxUI.event(COPY_EVENT, this, text, params);
				case FlxInputText.PASTE_ACTION:
					FlxUI.event(PASTE_EVENT, this, text, params);
					FlxUI.event(CHANGE_EVENT, this, text, params);
				case FlxInputText.CUT_ACTION:
					FlxUI.event(CUT_EVENT, this, text, params);
					FlxUI.event(CHANGE_EVENT, this, text, params);
			}
		}
	}
}
