package textbox;

import kha.Color;
import kha.Font;
import kha.Scheduler;
import kha.graphics2.Graphics;
import kha.math.FastVector2 in FV2;
import kha.input.KeyCode;
import kha.input.Keyboard;
import kha.input.Mouse;
import kha.System;
import kha.Scheduler;

using kha.StringExtensions;

class TextBox 
{

	/**
	* Private fields
	**/

	var _mouseX:Int;
	var _mouseY:Int;
	var _mouse:Mouse;
	var _dt:Float;
	var _lastTime:Float;

	var characters:Array<Int>;
	var breaks:Array<Int>;
	var cursorIndex:Int;

	var anim:Int;
	var isActive:Bool;

	var selecting:Bool;
	var selectionStart:Int;
	var selectionEnd:Int;

	var wordSelection:Bool;
	var disableInsert:Bool;

	var mouseButtonDown:Bool;
	var showEditingCursor:Bool;

	var scrollOffset:FV2;
	var scrollTop:Float;
	var scrollBottom:Float;
	var beginScrollOver:Bool;
	var isMouseOverScrollBar:Bool;
	var isMouseDownScrollBar:Bool;

	var scrollBarLastY:Float;
	var scrollBarCurrentY:Float;

	var keyCodeDown:Int;
	var ctrl:Bool;

	static var scrollBarWidth = 25;
	static inline var margin:Float = 10;

	/**
	* Public fields
	**/

	public var position:FV2;
	public var size:FV2;

	public var wordWrap:Bool;
	public var multiline:Bool;

	public var font:Font;
	public var fontSize:Int;
	public var border:Int;
	public var borderColor:Int = -1;
	public var backColor:Int = -1;
    public var textColor:Int = -1;
    public var highlightColor:Int = -1;
    public var highlightTextColor:Int = -1;

	/**
	* Public properties
	**/

	var _useScrollBar:Bool = true;
    public var useScrollBar(get, set):Bool;
    function get_useScrollBar():Bool 
	{
        return _useScrollBar;
    }
    function set_useScrollBar(val):Bool 
	{
        _useScrollBar = val;
        if (val)
            scrollBarWidth = 25;
        else
            scrollBarWidth = 0;
        return val;
    }

	/**
	* Create a new `TextBox`.
	**/
	public function new(x:Float, y:Float, w:Float, h:Float, font:Font, fontSize:Int) // constructor
	{
		position = new FV2(x, y);
		size = new FV2(w, h);
		this.font = font;
		this.fontSize = fontSize;
		scrollBarWidth = 25;
		scrollBarCurrentY = y;
		scrollTop = scrollBottom = 0;
		scrollOffset = new FV2(0, 0);
		anim = 0;
		characters = [];
		beginScrollOver = false;
		// cursorIndexCache = [];
		breaks = [];
		disableInsert = showEditingCursor = wordSelection = selecting = false;
		selectionStart = selectionEnd = -1;
		Keyboard.get().notify(keyDown, keyUp, keyPress);
		mouseButtonDown = false;
		keyCodeDown = -1;
		_mouse = Mouse.get();
		_mouse.notify(mouseDown, mouseUp, mouseMove, mouseWheel, null);

		wordWrap = multiline = true;

		System.notifyOnCutCopyPaste(cut, copy, paste);

		#if test
		characters = ("Lorem ipsum dolor sit amet, consetetur sadipscing elitr, "
			+ "sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, "
			+ "sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. "
			+ "Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. "
			+ "Lorem ipsum dolor sit amet, consetetur sadipscing elitr, "
			+ "sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, "
			+ "sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. "
			+ "Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. "
			+ "Lorem ipsum dolor sit amet, consetetur sadipscing elitr, "
			+ "sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, "
			+ "sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. "
			+ "Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet.").toCharArray();
		
		format();
		#end

		_lastTime = System.time;
        
		border = 1;
		borderColor = Color.Black;
		backColor = Color.White;
        textColor = Color.Black;
        highlightColor = 0xFF3390FF;
        highlightTextColor = Color.White;
	} // constructor


	/**
	* Public functions
	**/
    
	public function setText(value:String) //setText
	{
		characters = value.toCharArray();
	} //setText

	public function getText() //getText
	{
		var result = "";
		for (i in 0...characters.length)
			result += String.fromCharCode(characters[i]);
		return result;
	} //getText

	public function render(g:Graphics):Void //render
	{
		_dt = System.time - _lastTime;

		g.color = backColor;
		g.fillRect(position.x, position.y, size.x, size.y);
		g.color = borderColor;
		g.drawRect(position.x, position.y, size.x, size.y, border);

		g.scissor(Math.round(position.x), Math.round(position.y), Math.round(size.x), Math.round(size.y));

		if ((selectionStart > -1 || selectionEnd > -1) && selectionStart != selectionEnd) 
		{
			var startIndex = selectionStart;
			var endIndex = selectionEnd;
			if (endIndex < startIndex)
			{
				var temp = startIndex;
				startIndex = endIndex;
				endIndex = temp;
			}
			var startLine = findLine(startIndex);
			var startBreak = startLine > 0 ? breaks[startLine - 1] : 0;
			var startX = font.widthOfCharacters(fontSize, characters, startBreak, startIndex - startBreak);
			var endLine = findLine(endIndex);
			var endBreak = endLine > 0 ? breaks[endLine - 1] : 0;
			var endX = font.widthOfCharacters(fontSize, characters, endBreak, endIndex - endBreak);
			//g.fillRect(x + margin + startX, y + margin + startLine * font.height(fontSize), 200, (endLine - startLine + 1) * font.height(fontSize));
			
    		g.color = highlightColor;
			for (line in startLine...endLine + 1) 
			{
				var x1 = position.x + margin + border / 2;
				if (line == startLine) {
					x1 = position.x + margin + startX + border / 2;
				}
				
				var lineWidth = 0.0;

				if (line == 0)
					lineWidth = font.widthOfCharacters(fontSize, characters, 0, breaks[0]);
				else
					lineWidth = font.widthOfCharacters(fontSize, characters, breaks[line - 1], breaks[line] - breaks[line - 1]);
				
				var x2 = position.x + lineWidth + 5 + border / 2;
				if (line == endLine) {
					x2 = position.x + margin + endX + border / 2;
				}

				g.fillRect(x1, position.y + margin + line * font.height(fontSize) - scrollOffset.y, x2 - x1, font.height(fontSize));
			}
		}

		g.color = textColor;
		g.font = font;
		g.fontSize = fontSize;

		if (breaks.length == 0)
		{
			g.drawCharacters(characters, 0, characters.length, position.x + margin + border / 2, position.y + margin + border / 2);
		} else
		{
			var maxOfLines = Math.ceil(size.y / font.height(fontSize));
			var topLine = Std.int((scrollOffset.y / font.height(fontSize)));
			var bottomLine = topLine + maxOfLines;
			var line = topLine;
			var lastBreak = line > 0 ? breaks[line - 1] : 0;

			if (line < 0)
				line = 0;

			for (i in topLine...bottomLine) 
			{
				var lineBreak = breaks[i];
                renderLine(g, lastBreak, lineBreak - lastBreak, position.x + margin + border / 2, position.y + margin + border / 2, line);
                
				lastBreak = lineBreak;
				++line;
			}
			line = breaks.length;
			lastBreak = breaks[line - 1];
			
            renderLine(g, lastBreak, characters.length - lastBreak, position.x + margin + border / 2, position.y + margin + border / 2, line);
		}
		
		if (Std.int(anim / 20) % 2 == 0 && isActive) 
		{ // blink caret
			var line = findCursorLine();
			var lastBreak = line > 0 ? breaks[line - 1] : 0;
			var cursorX = font.widthOfCharacters(fontSize, characters, lastBreak, cursorIndex - lastBreak);
			g.color = Color.Black;
			g.drawLine(position.x + margin + cursorX + border / 2, position.y + margin + font.height(fontSize) * line - scrollOffset.y, position.x + margin + cursorX + border / 2, position.y + margin + font.height(fontSize) * (line + 1) - scrollOffset.y, 2);
		} // blink caret

		if (Std.int(anim / 5) % 2 == 0 && beginScrollOver && isActive) 
		{
			scroll();
		}

		if (showEditingCursor && !isMouseDownScrollBar)
		{
			_mouse.hideSystemCursor();
			var fontHeight = font.height(fontSize);
			var top = _mouseY - fontHeight / 2;
			var bottom = _mouseY + fontHeight / 2;
            var size = fontHeight / 8;
            if (size < 1) {
                size = 1;
            }
            if (size % .5 != size) {
                size = Std.int(size) + .5;
            }

			var left = _mouseX - size;
			var right = _mouseX + size;
			g.color = Color.Black;
			g.drawLine(_mouseX, top, _mouseX, bottom);
			g.drawLine(left, top, right, top);
			g.drawLine(left, bottom, right, bottom);
		}
		else
			_mouse.showSystemCursor();

		g.disableScissor();

        if (useScrollBar)
		{
            g.color = Color.fromBytes(40, 40, 40);
            g.fillRect(position.x + size.x - scrollBarWidth + border / 2, position.y + border / 2, scrollBarWidth - border, size.y - border);

            var scrollFillColor = Color.fromBytes(80, 80, 80);
            if (isMouseDownScrollBar)
                scrollFillColor = Color.fromBytes(20, 20, 20);
            else if (isMouseOverScrollBar)
                scrollFillColor = Color.fromBytes(150, 150, 150);

            g.color = scrollFillColor;
            g.fillRect(position.x + size.x - scrollBarWidth + border / 2, scrollBarCurrentY + border / 2, scrollBarWidth - border, size.y / 2 - border);
        }

		_lastTime = System.time;

		#if debug
		g.color = Color.White;
		g.fontSize = 12;
		var lineY = 2.0;
		
		var values:Dynamic = {
			totalBreaks: breaks.length,
			totalCharacters: characters.length,
			caretIndex: cursorIndex,
			selectionStart: selectionStart,
			selectionEnd: selectionEnd,
			isActive: isActive,
			beginScrollOver: beginScrollOver
		};

		for (field in Reflect.fields(values))
		{
			var print_text = "" + field + ": " + Reflect.field(values, field);
			var print_width = g.font.width(g.fontSize, print_text);
			g.drawString("" + field + ": " + Reflect.field(values, field), System.windowWidth() - print_width - 4, lineY);
			lineY += g.font.height(g.fontSize) + 4;
		}

		#end
	} //render

	public function update():Void // update
	{
		++anim;
	} // update

	

	/**
	* Event handling
	**/

	function cut():String //cut
	{
		if (!isActive)
			return null;

		if (selectionStart >= 0 && selectionEnd >= 0) {
			var startIndex = 0;
			var endIndex = 0;
			if (selectionEnd < selectionStart)
			{
				startIndex = selectionEnd;
				endIndex = selectionStart;
			}
			else
			{
				startIndex = selectionStart;
				endIndex = selectionEnd;
			}

			var data = createString(characters.splice(startIndex, endIndex - startIndex));
			cursorIndex = startIndex;
			selectionStart = selectionEnd = -1;
			format();
			return data;
		}
		else {
			return null;
		}
	} //cut

	function copy():String //copy
	{
		if (!isActive)
			return null;

		if (selectionStart >= 0 && selectionEnd >= 0) {
			var startIndex = 0;
			var endIndex = 0;
			if (selectionEnd < selectionStart)
			{
				startIndex = selectionEnd;
				endIndex = selectionStart;
			}
			else
			{
				startIndex = selectionStart;
				endIndex = selectionEnd;
			}

			return createString(characters.slice(startIndex, endIndex));
		}
		else {
			return null;
		}
	} //copy

	function paste(data:String):Void //paste
	{
		if (!isActive)
			return;

		for (i in 0...data.length) {
			characters.insert(cursorIndex, data.charCodeAt(i));
			++cursorIndex;
			format();
		}
	} //paste

	function keyDown(code:KeyCode):Void // keyDown
	{
		if (!isActive)
			return;
		
		keyCodeDown = code;
		switch (code) {
			case Left:
				doLeftOperation();
			case Right:
				doRightOperation();
			case Down:
				doDownOperation();
			case Up:
				doUpOperation();
			case Backspace:
				doBackspaceOperation();
			case Delete:
				doDeleteOperation();
			case Shift:
				if (selectionStart == -1 && selectionEnd == -1)
					selectionStart = selectionEnd = cursorIndex;
				
				selecting = true;
			case Control:
				wordSelection = true;
				disableInsert = true;
				ctrl = true;
			default:
		}

		Scheduler.removeTimeTask(_repeatTimerId);
        Scheduler.addTimeTaskToGroup(1234, function() { // 1234 is the group, seems as good as any group id
          	 if (keyCodeDown > -1) {
                _repeatTimerId = Scheduler.addTimeTask(repeatTimer, 0, 1 / 20);
             }
        }, .6);
	} // keyDown

	function keyUp(code:KeyCode):Void // keyUp
	{
		if (!isActive)
			return;

		keyCodeDown = -1;

		Scheduler.removeTimeTasks(1234);

		switch (code) {
			case Shift:
				selecting = false;
			case Left, Right, Up, Down:
				if (!selecting)
					selectionStart = selectionEnd = -1;
			case Control:
				wordSelection = false;
				disableInsert = false;
				ctrl = false;
			case A:
				if (ctrl)
				{
					selectionStart = 0;
					selectionEnd = characters.length;
				}
			case D:
				if (ctrl)
				{
					selectionStart = selectionEnd = -1;
				}
			default:
		}
	} // keyUp

	function mouseDown(button:Int, x:Int, y:Int):Void // mouseDown
	{
		mouseButtonDown = true;
		if (y >= position.y && y <= position.y + size.y) {
			if (x >= position.x + size.x - scrollBarWidth && x <= position.x + size.x) {
				isActive = true;
				isMouseDownScrollBar = true;
				scrollBarLastY = y - scrollBarCurrentY;
			}
			else if (x >= position.x && x <= position.x + size.x) {
				isActive = true;
				selectionStart = selectionEnd = findIndex(x - position.x, y - position.y);
			}
		}
	} // mouseDown

	function mouseUp(button:Int, x:Int, y:Int):Void // mouseUp
	{
		mouseButtonDown = false;
		beginScrollOver = false;
		if (x >= position.x && x <= position.x + size.x - scrollBarWidth && y >= position.y && y <= position.y + size.y)
		{
			if (isMouseDownScrollBar)
			{
				isMouseDownScrollBar = false;
				return;
			}

			isActive = true;
			cursorIndex = findIndex(x - position.x, y - position.y);
			if (selecting)
			{
				selectionEnd = cursorIndex;
			}

			if (selectionStart == selectionEnd)
				selectionStart = selectionEnd = -1;

			if (cursorIndex < 0)
				cursorIndex = 0;
			else if (cursorIndex > characters.length)
				cursorIndex = characters.length;
		}
		else
		{
			isActive = false;
		}

		isMouseDownScrollBar = false;
	} // mouseUp

	function mouseMove(x:Int, y:Int, mx:Int, my:Int):Void // mouseMove
	{
		_mouseX = x;
		_mouseY = y;

		showEditingCursor = (x >= position.x && x <= position.x + size.x - scrollBarWidth && y >= position.y && y <= position.y + size.y);

		if (y >= position.y && y <= position.y + size.x)
		{
			if (x >= position.x + size.x - scrollBarWidth && x <= position.x + size.x) 
			{
				moveScrollBar(y);
				isMouseOverScrollBar = true;
			}
			else if (x >= position.x && x <= position.x + size.x)
			{
				moveScrollBar(y);
				isMouseOverScrollBar = false;

				if (mouseButtonDown && selectionStart >= 0)
				{
					isMouseOverScrollBar = false;
					cursorIndex = selectionEnd = findIndex(x - position.x, y - position.y);
					if (cursorIndex < 0)
						cursorIndex = 0;
					else if (cursorIndex > characters.length)
						cursorIndex = characters.length;
				}
			}
			else
				isMouseOverScrollBar = false;
		}
		else if (mouseButtonDown && selectionStart >= 0)
		{
			beginScrollOver = true;
			isMouseOverScrollBar = false;
		}
		else
			isMouseOverScrollBar = false;
	} // mouseMove

	function mouseWheel(steps:Int):Void // mouseWheel
	{
		scrollOffset.y += steps * 20;
		if (scrollOffset.y < scrollTop || (breaks.length + 1) * font.height(fontSize) < size.y)
			scrollOffset.y = scrollTop;
		else if (scrollOffset.y > scrollBottom)
			scrollOffset.y = scrollBottom;
		
		updateScrollBarPosition();
	} // mouseWheel

	function keyPress(character:String):Void // keyPress
	{
		if (!isActive || ctrl)
			return;

		var char = character.charCodeAt(0);
		insertCharacter(char);
		keyCodeDown = char;
	} // keyPress

	var _repeatTimerId:Int;
    function repeatTimer() {
		if (keyCodeDown > -1)
		{
			if (isActive)
			{
				var code = keyCodeDown;
				anim = 0;
				switch (code)
				{
					case Left:
						doLeftOperation();
					case Right:
						doRightOperation();
					case Up:
						doUpOperation();
					case Down:
						doDownOperation();
					case Delete:
						doDeleteOperation();
					case Backspace:
						doBackspaceOperation();
					default:
						if (isChar(keyCodeDown))
							insertCharacter(keyCodeDown);
				}
			}
		}
    }


	/**
	* Key function operations
	**/

	function doLeftOperation() // doLeftOperation
	{
		if (wordSelection)
		{
			var offset = 0;
			var startIndex = cursorIndex;
			var nextCharIndex = getNextCharacter(-1);
			var endIndex = getStartOfWord();
			if (endIndex < nextCharIndex)
				cursorIndex = endIndex;
			else
			{
				offset = nextCharIndex - endIndex;
				if (offset < 0)
					offset = -offset;
				else
					offset += 1;
				
				cursorIndex = getStartOfWord(offset);
			}
		}
		else
			--cursorIndex;
		
		if (cursorIndex < 0) {
			cursorIndex = 0;
		}
		if (selecting) {
			selectionEnd = cursorIndex;
		}

		scrollToCaret();
	} // doLeftOperation

	function doRightOperation() // doRightOperation
	{
		if (wordSelection)
		{
			var offset = 0;
			var startIndex = cursorIndex;
			var nextCharIndex = getNextCharacter();
			var endIndex = getEndOfWord();
			if (endIndex > nextCharIndex)
				cursorIndex = endIndex;
			else
			{
				offset = endIndex - nextCharIndex;
				if (offset < 0)
					offset = -offset;
				else
					offset += 1;
				
				cursorIndex = getEndOfWord(offset);
			}
		}
		else
			++cursorIndex;
		
		if (cursorIndex > characters.length) {
			cursorIndex = characters.length;
		}
		if (selecting) {
			selectionEnd = cursorIndex;
		}
		scrollToCaret();
	} // doRightOperation

	function doDownOperation() // doDownOperation
	{
		if (wordSelection)
			return;

		var line = findCursorLine();
		var lastBreak = line > 0 ? breaks[line - 1] : 0;
		var cursorX = font.widthOfCharacters(fontSize, characters, lastBreak, cursorIndex - lastBreak);
		if (breaks.length > line) {
			var newBreak = breaks[line];
			var nextBreak = breaks.length > line + 2 ? breaks[line + 1] : characters.length;
			for (index in newBreak...nextBreak) {
				var newX = font.widthOfCharacters(fontSize, characters, newBreak, index - newBreak);
				if (newX >= cursorX) {
					cursorIndex = index;
					if (selecting) {
						selectionEnd = cursorIndex;
					}
					return;
				}
			}
			cursorIndex = nextBreak;
			if (selecting) {
				selectionEnd = cursorIndex;
			}
		}
		else
		{
			cursorIndex = characters.length;
			if (selecting)
				selectionEnd = cursorIndex;
		}

		scrollToCaret();
	} // doDownOperation

	function doUpOperation() // doUpOperation
	{
		if (wordSelection)
			return;
		
		var line = findCursorLine();
		var lastBreak = line > 0 ? breaks[line - 1] : 0;
		var cursorX = font.widthOfCharacters(fontSize, characters, lastBreak, cursorIndex - lastBreak);
		if (line > 0) {
			var newBreak = line > 1 ? breaks[line - 2] : 0;
			var nextBreak = lastBreak;
			for (index in newBreak...nextBreak) {
				var newX = font.widthOfCharacters(fontSize, characters, newBreak, index - newBreak);
				if (newX >= cursorX) {
					cursorIndex = index;
					if (selecting) {
						selectionEnd = cursorIndex;
					}
					return;
				}
			}
			cursorIndex = nextBreak;
			if (selecting) {
				selectionEnd = cursorIndex;
			}
		}
		else
		{
			cursorIndex = 0;
			if (selecting)
				selectionEnd = cursorIndex;
		}

		scrollToCaret();
	} // doUpOperation

	function doBackspaceOperation() // doBackspaceOperation
	{
		if (selectionStart > -1 && selectionEnd > -1)
			removeSelection();
		else
		{
			characters.splice(cursorIndex - 1, 1);
			--cursorIndex;
			if (cursorIndex < 0)
				cursorIndex = 0;
			
			format();
		}
	} // doBackspaceOperation

	function doDeleteOperation() // doDeleteOperation
	{
		if (cursorIndex > characters.length - 1)
			return;
		else
		{
			if (selectionStart > -1 && selectionEnd > -1)
				removeSelection();
			else
			{
				if (cursorIndex == 0)
					characters.splice(0, 1);
				else
					characters.splice(cursorIndex, 1);
			}

			format();
		}
	} // doDeleteOperation

	
	/**
	* Scolling functions
	**/

	function scrollToCaret() // scrollToCaret
	{
		var line = findCursorLine();
		var maxOfLines = Math.floor(size.y / font.height(fontSize));
		var topLine = Std.int((scrollOffset.y / font.height(fontSize)));
		var bottomLine = topLine + maxOfLines - 1;

		if (line > bottomLine)
		{
			scrollOffset.y += font.height(fontSize) * 5;
		}
		else if (line < topLine)
		{
			scrollOffset.y -= font.height(fontSize) * 5;
		}

		if (scrollOffset.y > scrollBottom)
			scrollOffset.y = scrollBottom;
		else if (scrollOffset.y < 0)
			scrollOffset.y = 0;
		
		updateScrollBarPosition();
	} // scrollToCaret

	function scroll() // scroll
	{
		var x_val = _mouseX < position.x ? 0 : _mouseX - position.x;
		var y_val = _mouseY < position.y ? 0 : _mouseY - position.y;
		if (_mouseY < position.y)
		{
			var scroll_step = position.y - _mouseY;
			scrollOffset.y -= scroll_step;
			if (scrollOffset.y < scrollTop)
				scrollOffset.y = scrollTop;
			else if (scrollOffset.y > scrollBottom)
				scrollOffset.y = scrollBottom;
		}
		else if (_mouseY > position.y + size.y)
		{
			var scroll_step = _mouseY - (position.y + size.y);
			scrollOffset.y += scroll_step;
			if (scrollOffset.y < scrollTop)
				scrollOffset.y = scrollTop;
			else if (scrollOffset.y > scrollBottom)
				scrollOffset.y = scrollBottom;
		}

		cursorIndex = selectionEnd = findIndex(x_val, y_val);
		if (cursorIndex < 0)
			cursorIndex = 0;
		else if (cursorIndex > characters.length)
			cursorIndex = characters.length;
		
		updateScrollBarPosition();
	} // scroll

	function updateScrollBarPosition() // updateScrollBarPosition
	{
		var percent = scrollOffset.y / scrollBottom;

		scrollBarCurrentY = percent * (size.y / 2) + position.y;

		if (scrollBarCurrentY < position.y)
			scrollBarCurrentY = position.y;
		else if (scrollBarCurrentY > position.y + size.y / 2)
			scrollBarCurrentY = position.y + size.y / 2;
		
	} // updateScrollBarPosition

	function checkScrollBar() // checkScrollBar
	{
		if (!useScrollBar)
			return;

		var scrollMax = (breaks.length + 1) * font.height(fontSize);
		scrollBottom = (scrollMax) - size.y + margin * 2;

		if (scrollMax < size.y)
		{
			scrollBarWidth = 0;
			//format();
		}
		else
		{
			scrollBarWidth = 25;
		}
	} // checkScrollBar

	function moveScrollBar(y:Int) // moveScrollBar
	{
		if (isMouseDownScrollBar)
		{
			scrollBarCurrentY = y - scrollBarLastY;

			if (scrollBarCurrentY < position.y)
				scrollBarCurrentY = position.y;
			else if (scrollBarCurrentY > size.y / 2 + position.y)
				scrollBarCurrentY = size.y / 2 + position.y;
			
			var percent = (scrollBarCurrentY - position.y) / (size.y / 2);
			scrollOffset.y = percent * scrollBottom;
		}
	} // moveScrollBar


	/**
	* Character/word handling
	**/

	function getNextCharacter(dir:Int = 1):Int // getNextCharacter
	{
		var result = 0;
		var startIndex = cursorIndex;
		if (dir > 0)
		{
			result = startIndex;
			for (i in startIndex...characters.length - 1)
			{
				if (!isAlphanumericOrChar(characters[i]))
					result = i;
				else
				{
					result = i;
					break;
				}
			}
		}
		else if (dir < 0)
		{
			result = startIndex;
			while (startIndex > 0)
			{
				if (!isAlphanumericOrChar(characters[startIndex]))
					result = startIndex;
				else
					break;
				--startIndex;
			}
		}
		return result;
	} // getNextCharacter

	function getEndOfWord(offset:Int = 0):Int // getEndOfWord
	{
		var startIndex = cursorIndex + offset;
		var result = startIndex;
		for (i in startIndex...characters.length)
		{
			if (isChar(characters[i]))
				result = i;
			else
			{
				result = i;
				break;
			}
		}
		return result;
	} // getEndOfWord

	function getStartOfWord(offset:Int = 0):Int // getStartOfWord
	{
		var result = 0;
		var startIndex = cursorIndex - offset;
		while (startIndex > -1)
		{
			if (isChar(characters[startIndex]))
				result = startIndex;
			else
			{
				result = startIndex;
				break;
			}
			--startIndex;
		}
		return result;
	} // getStartOfWord

	function isChar(char:Int):Bool // isChar
	{
		return ((char >= 48 && char < 58) || (char >= 65 && char < 91) || (char >= 97 && char < 123));
	} // isChar

	function isAlphanumericOrChar(char:Int):Bool // isAlphanumericOrChar
	{
		return (char >= 33 && char < 126 || char > 127);
	} // isAlphanumericOrChar

	function removeSelection():Void // removeSelection
	{
		var count = selectionEnd - selectionStart;
		if (count < 0)
			count = -count;
		
		var startIndex = cursorIndex;
		if (selectionStart > selectionEnd)
		{
			if (cursorIndex > selectionEnd)
				startIndex = selectionEnd;
		}
		else if (selectionEnd > selectionStart)
		{
			if (cursorIndex > selectionStart)
				startIndex = selectionStart;
		}

		if (startIndex < 0)
			startIndex = 0;

		characters.splice(startIndex, count);
		cursorIndex = (selectionStart > selectionEnd ? selectionEnd : selectionStart);
		selectionStart = selectionEnd = -1;
		format();
	} // removeSelection

	function insertCharacter(char:Int) // insertCharacter
	{
		if (!disableInsert)
		{
			if (hasSelection())
				removeSelection();

			anim = 0;
			characters.insert(cursorIndex, char);
			++cursorIndex;
			selectionStart = selectionEnd = -1;
			format();
		}
	} // insertCharacter

	/**
	* Formatting functionality
	**/

	function format():Void // format
	{
		var lastChance = -1;
		breaks = [];
		var lastBreak = 0;
		var i = 0;
		while (i < characters.length) {
			var width = font.widthOfCharacters(fontSize, characters, lastBreak, i - lastBreak);
			if (width >= size.x - margin * 2 - scrollBarWidth) {
				if (lastChance < 0) {
					lastChance = i - 1;
				}
				breaks.push(lastChance + 1);
				lastBreak = lastChance + 1;
				i = lastBreak;
				lastChance = -1;
			}

			if (characters[i] == " ".charCodeAt(0)) {
				lastChance = i;
			}
			else if (characters[i] == "\n".charCodeAt(0) || characters[i] == "\r".charCodeAt(0)) {
				breaks.push(i + 1);
				lastBreak = i + 1;
				lastChance = -1;
			}
			++i;
		}

		checkScrollBar();
	} // format

	function findLine(index:Int):Int // findLine 
	{
		var line = 0;
		for (lineBreak in breaks) {
			if (lineBreak > index) {
				break;
			}
			++line;
		}
		return line;
	} // findLine

	function findCursorLine():Int // findCursorLine
	{
		return findLine(cursorIndex);		
	} // findCursorLine

	function findIndex(x:Float, y:Float):Int // findIndex
	{
		var line = Std.int((y - margin + scrollOffset.y) / font.height(fontSize));
		if (line < 0) {
			line = 0;
		}
		if (line > breaks.length) {
			line = breaks.length;
		}
		var breakIndex = line > 0 ? breaks[line - 1] : 0;
		var index = breakIndex;
        var totalWidth:Float = 0;
		while (index < characters.length) {
            var charWidth = font.widthOfCharacters(fontSize, characters, index, 1);
            totalWidth += charWidth;
			++index;
            if (totalWidth >= x - margin) {
                var delta = totalWidth - (x - margin);
                if (Math.round(delta) >= Math.round(charWidth / 2)) {
                    --index;
                }
                break;
            }
		}
		return index;
	} // findIndex

	

	/**
	* Sub-rendering routines
	**/
    
    // this can (should) be refactored a little - this is initial implementation / iteration
    function renderLine(g:Graphics, start:Int, end:Int, x:Float, y:Float, line:Int) //renderLine
	{
		var chars = characters;
        var startIndex = selectionStart;
        var endIndex = selectionEnd;
        if (endIndex < startIndex) {
            var temp = startIndex;
            startIndex = endIndex;
            endIndex = temp;
        }

        g.color = textColor;
        if (hasSelection()) {
            var lineStartIndex = 0;
            if (line > 0) {
                lineStartIndex = breaks[line - 1];
            }
            var lineEndIndex = breaks[line];
            
            var startInRange = (startIndex >= lineStartIndex && startIndex <= lineEndIndex);
            var endInRange = (endIndex >= lineStartIndex && endIndex <= lineEndIndex);
            
            if (startInRange == false && endInRange == false) {
                if (start >= startIndex && start + end <= endIndex) {
                    g.color = highlightTextColor;
                }
                g.drawCharacters(chars, start, end, x, y + line * font.height(fontSize) - scrollOffset.y);
            } else if (startInRange == true && endInRange == true) {
                g.drawCharacters(chars, start, startIndex - start, x, y + line * font.height(fontSize) - scrollOffset.y);
              
                x += font.widthOfCharacters(fontSize, chars, start, startIndex - start);
                start += startIndex - start;
                
                g.color = highlightTextColor;
                g.drawCharacters(chars, start, endIndex - startIndex, x, y + line * font.height(fontSize) - scrollOffset.y);

                x += font.widthOfCharacters(fontSize, chars, start, endIndex - startIndex);
                start += endIndex - startIndex;
                
                g.color = textColor;
                g.drawCharacters(chars, start, lineEndIndex - start, x, y + line * font.height(fontSize) - scrollOffset.y);
            } else if (startInRange == true && endInRange == false) {
                g.drawCharacters(chars, start, startIndex - start, x, y + line * font.height(fontSize) - scrollOffset.y);
              
                x += font.widthOfCharacters(fontSize, chars, start, startIndex - start);
                start += startIndex - start;
                
                g.color = highlightTextColor;
                g.drawCharacters(chars, start, lineEndIndex - start, x, y + line * font.height(fontSize) - scrollOffset.y);
            } else if (startInRange == false && endInRange == true) {
                g.color = highlightTextColor;
                g.drawCharacters(chars, start, endIndex - start, x, y + line * font.height(fontSize) - scrollOffset.y);
                
                x += font.widthOfCharacters(fontSize, chars, start, endIndex - start);
                start += endIndex - start;

                
                g.color = textColor;
                g.drawCharacters(chars, start, lineEndIndex - start, x, y + line * font.height(fontSize) - scrollOffset.y);
            } else {
                g.drawCharacters(chars, start, end, x, y + line * font.height(fontSize) - scrollOffset.y);
            }
        } else {
            g.drawCharacters(chars, start, end, x, y + line * font.height(fontSize) - scrollOffset.y);
        }
    } //renderLine

	function createString(array: Array<Int>):String //createString
	{
		var buf = new StringBuf();
		for (value in array) {
			buf.addChar(value);
		}
		return buf.toString();
	} //createString

    inline function hasSelection() // hasSelection
	{
        return ((selectionStart > -1 || selectionEnd > -1) && selectionStart != selectionEnd);
    } // hasSelection
}
