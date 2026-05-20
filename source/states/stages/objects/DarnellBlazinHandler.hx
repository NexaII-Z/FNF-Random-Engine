package states.stages.objects;

import objects.Note;
import objects.Character;

class DarnellBlazinHandler
{
	public function new() {}

	var cantUppercut:Bool = false;

	public function noteHit(note:Note)
	{
		// SPECIAL CASE: If Pico hits a poor note at low health (30% chance),
		// Darnell may duck below Pico's punch to attempt an uppercut.
		if (wasNoteHitPoorly(note.rating) && isPlayerLowHealth() && FlxG.random.bool(30))
		{
			playUppercutPrepAnim();
			return;
		}

		if (cantUppercut)
		{
			playPunchHighAnim();
			return;
		}

		switch (note.noteType)
		{
			case "weekend-1-punchlow":         playHitLowAnim();
			case "weekend-1-punchlowblocked":  playBlockAnim();
			case "weekend-1-punchlowdodged":   playDodgeAnim();
			case "weekend-1-punchlowspin":     playSpinAnim();

			case "weekend-1-punchhigh":        playHitHighAnim();
			case "weekend-1-punchhighblocked": playBlockAnim();
			case "weekend-1-punchhighdodged":  playDodgeAnim();
			case "weekend-1-punchhighspin":    playSpinAnim();

			case "weekend-1-blockhigh":        playPunchHighAnim();
			case "weekend-1-blocklow":         playPunchLowAnim();
			case "weekend-1-blockspin":        playPunchHighAnim();

			case "weekend-1-dodgehigh":        playPunchHighAnim();
			case "weekend-1-dodgelow":         playPunchLowAnim();
			case "weekend-1-dodgespin":        playPunchHighAnim();

			case "weekend-1-hithigh":          playPunchHighAnim();
			case "weekend-1-hitlow":           playPunchLowAnim();
			case "weekend-1-hitspin":          playPunchHighAnim();

			case "weekend-1-picouppercutprep": // Continue whatever animation was playing
			case "weekend-1-picouppercut":     playUppercutHitAnim();

			case "weekend-1-darnelluppercutprep": playUppercutPrepAnim();
			case "weekend-1-darnelluppercut":     playUppercutAnim();

			case "weekend-1-idle":          playIdleAnim();
			case "weekend-1-fakeout":       playCringeAnim();
			case "weekend-1-taunt":         playPissedConditionalAnim();
			case "weekend-1-tauntforce":    playPissedAnim();
			case "weekend-1-reversefakeout": playFakeoutAnim();
		}

		cantUppercut = false;
	}

	public function noteMiss(note:Note)
	{
		// SPECIAL CASE: Darnell prepared to uppercut and Pico missed - FINISH HIM!
		if (dad.animation.curAnim != null && dad.animation.curAnim.name == 'uppercutPrep')
		{
			playUppercutAnim();
			return;
		}

		if (willMissBeLethal())
		{
			playPunchLowAnim();
			return;
		}

		if (cantUppercut)
		{
			playPunchHighAnim();
			return;
		}

		switch (note.noteType)
		{
			case "weekend-1-punchlow":         playPunchLowAnim();
			case "weekend-1-punchlowblocked":  playPunchLowAnim();
			case "weekend-1-punchlowdodged":   playPunchLowAnim();
			case "weekend-1-punchlowspin":     playPunchLowAnim();

			case "weekend-1-punchhigh":        playPunchHighAnim();
			case "weekend-1-punchhighblocked": playPunchHighAnim();
			case "weekend-1-punchhighdodged":  playPunchHighAnim();
			case "weekend-1-punchhighspin":    playPunchHighAnim();

			case "weekend-1-blockhigh":        playPunchHighAnim();
			case "weekend-1-blocklow":         playPunchLowAnim();
			case "weekend-1-blockspin":        playPunchHighAnim();

			case "weekend-1-dodgehigh":        playPunchHighAnim();
			case "weekend-1-dodgelow":         playPunchLowAnim();
			case "weekend-1-dodgespin":        playPunchHighAnim();

			case "weekend-1-hithigh":          playPunchHighAnim();
			case "weekend-1-hitlow":           playPunchLowAnim();
			case "weekend-1-hitspin":          playPunchHighAnim();

			// Successfully dodge Pico's uppercut attempt
			case "weekend-1-picouppercutprep":
				playHitHighAnim();
				cantUppercut = true;
			case "weekend-1-picouppercut":     playDodgeAnim();

			case "weekend-1-darnelluppercutprep": playUppercutPrepAnim();
			case "weekend-1-darnelluppercut":     playUppercutAnim();

			case "weekend-1-idle":           playIdleAnim();
			case "weekend-1-fakeout":        playCringeAnim();
			case "weekend-1-taunt":          playPissedConditionalAnim();
			case "weekend-1-tauntforce":     playPissedAnim();
			case "weekend-1-reversefakeout": playFakeoutAnim();
		}
		cantUppercut = false;
	}

	public function noteMissPress(direction:Int)
	{
		if (willMissBeLethal())
			playPunchLowAnim(); // Darnell punches so Pico dies
		else
		{
			// Pico wildly throws punches but Darnell dodges or blocks
			if (FlxG.random.bool(50))
				playDodgeAnim();
			else
				playBlockAnim();
		}
	}

	// ---- Animation helpers ----

	var alternate:Bool = false;
	function doAlternate():String
	{
		alternate = !alternate;
		return alternate ? '1' : '2';
	}

	function playBlockAnim()
	{
		dad.playAnim('block', true);
		// In 0.7.3 camGame is accessed via PlayState.instance.camGame
		PlayState.instance.camGame.shake(0.002, 0.1);
		moveToBack();
	}

	function playCringeAnim()
	{
		dad.playAnim('cringe', true);
		moveToBack();
	}

	function playDodgeAnim()
	{
		dad.playAnim('dodge', true, false);
		moveToBack();
	}

	function playIdleAnim()
	{
		dad.playAnim('idle', false);
		moveToBack();
	}

	function playFakeoutAnim()
	{
		dad.playAnim('fakeout', true);
		moveToBack();
	}

	function playPissedConditionalAnim()
	{
		if (dad.animation.curAnim != null && dad.animation.curAnim.name == "cringe")
			playPissedAnim();
		else
			playIdleAnim();
	}

	function playPissedAnim()
	{
		dad.playAnim('pissed', true);
		moveToBack();
	}

	function playUppercutPrepAnim()
	{
		dad.playAnim('uppercutPrep', true);
		moveToFront();
	}

	function playUppercutAnim()
	{
		dad.playAnim('uppercut', true);
		moveToFront();
	}

	function playUppercutHitAnim()
	{
		dad.playAnim('uppercutHit', true);
		moveToBack();
	}

	function playHitHighAnim()
	{
		dad.playAnim('hitHigh', true);
		PlayState.instance.camGame.shake(0.0025, 0.15);
		moveToBack();
	}

	function playHitLowAnim()
	{
		dad.playAnim('hitLow', true);
		PlayState.instance.camGame.shake(0.0025, 0.15);
		moveToBack();
	}

	function playPunchHighAnim()
	{
		dad.playAnim('punchHigh' + doAlternate(), true);
		moveToFront();
	}

	function playPunchLowAnim()
	{
		dad.playAnim('punchLow' + doAlternate(), true);
		moveToFront();
	}

	function playSpinAnim()
	{
		dad.playAnim('hitSpin', true);
		PlayState.instance.camGame.shake(0.0025, 0.15);
		moveToBack();
	}

	// ---- Condition checks ----

	function willMissBeLethal():Bool
	{
		return PlayState.instance.health <= 0.0 && !PlayState.instance.practiceMode;
	}

	function wasNoteHitPoorly(rating:String):Bool
	{
		return (rating == "bad" || rating == "shit");
	}

	function isPlayerLowHealth():Bool
	{
		return PlayState.instance.health <= 0.3 * 2;
	}

	// ---- Layer swapping ----
	// In Psych 0.7.3, boyfriendGroup and dadGroup are standard FlxSpriteGroups.
	// We swap render order by swapping their positions in FlxG.state.members.

	function moveToBack()
	{
		var dadPos:Int = FlxG.state.members.indexOf(dadGroup);
		var bfPos:Int  = FlxG.state.members.indexOf(boyfriendGroup);
		if (dadPos < bfPos) return; // already behind BF
		FlxG.state.members[bfPos] = dadGroup;
		FlxG.state.members[dadPos] = boyfriendGroup;
	}

	function moveToFront()
	{
		var dadPos:Int = FlxG.state.members.indexOf(dadGroup);
		var bfPos:Int  = FlxG.state.members.indexOf(boyfriendGroup);
		if (dadPos > bfPos) return; // already in front of BF
		FlxG.state.members[bfPos] = dadGroup;
		FlxG.state.members[dadPos] = boyfriendGroup;
	}

	// ---- Convenience getters (mirror PlayState.instance) ----

	var boyfriend(get, never):Character;
	var dad(get, never):Character;
	var boyfriendGroup(get, never):FlxSpriteGroup;
	var dadGroup(get, never):FlxSpriteGroup;

	function get_boyfriend()     return PlayState.instance.boyfriend;
	function get_dad()           return PlayState.instance.dad;
	function get_boyfriendGroup() return PlayState.instance.boyfriendGroup;
	function get_dadGroup()      return PlayState.instance.dadGroup;
}
