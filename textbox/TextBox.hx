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
import textbox.ScrollBar.HitResult;

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
	var _outOnce:Bool;

	var characters:Array<Int>;
	var breaks:Array<Int>;
	var cursorIndex:Int;

	var anim:Int;

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

	var keyCodeDown:Int;
	var ctrl:Bool;

	static inline var margin:Float = 10;

	/**
	* Public fields
	**/

	public var position:FV2;
	public var size:FV2;

	public var wordWrap(get, set):Bool;
	public var multiline(get, set):Bool;

	public var useScrollBar(get, set):Bool;

	public var useTextHighlight:Bool;

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

    private var _scrollBar:ScrollBar = null;
    function get_useScrollBar() return (_scrollBar != null);
    function set_useScrollBar(val) 
	{
        if (val) {
            if (_scrollBar == null) {
                _scrollBar = new ScrollBar(this);
                _scrollBar.onChange = onScrollBarChange;
            }
        } else {
            _scrollBar = null;
        }
        format();
        return val;
    }

	var _multiline:Bool;
	var _prevHeight:Float;
	function get_multiline() return _multiline;
	function set_multiline(val)
	{
		_multiline = val;
		if (val)
		{
			if (_prevHeight != null)
				size.y = _prevHeight;
		}
		else
		{
			_prevHeight = size.y;
			size.y = font.height(fontSize) + margin * 2;
		}

		format();

		return _multiline;
	}

	var _wordWrap:Bool;
	function get_wordWrap() return _wordWrap;
	function set_wordWrap(val)
	{
		_wordWrap = val;
		format();
		return _wordWrap;
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

		useTextHighlight = wordWrap = multiline = true;

		System.notifyOnCutCopyPaste(cut, copy, paste);
        useScrollBar = true;
        
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

		_outOnce = false;
        
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
        format();
	} //setText

	public function getText() //getText
	{
		var result = "";
		for (i in 0...characters.length)
			result += String.fromCharCode(characters[i]);
		return result;
	} //getText

	public function changeScrollBarColors(back:Color, thumbBase:Color, thumbOver:Color, thumbDown:Color)
	{
		_scrollBar.backColor = back;
		_scrollBar.thumbBaseColor = thumbBase;
		_scrollBar.thumbDownColor = thumbDown;
		_scrollBar.thumbOverColor = thumbOver;
	}

	public function render(g:Graphics):Void //render
	{
		_dt = System.time - _lastTime;

		g.color = backColor;
		g.fillRect(position.x, position.y, size.x, size.y);
		g.color = borderColor;
		g.drawRect(position.x, position.y, size.x, size.y, border);

		g.scissor(Math.round(position.x), Math.round(position.y), Math.round(size.x), Math.round(size.y));

		if ((selectionStart > -1 || selectionEnd > -1) && selectionStart != selectionEnd && isActive) 
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

				g.fillRect(x1 - scrollOffset.x, position.y + margin + line * font.height(fontSize) - scrollOffset.y, x2 - x1, font.height(fontSize));
			}
		}

		g.color = textColor;
		g.font = font;
		g.fontSize = fontSize;

		if (breaks.length == 0)
		{
			renderLine(g, 0, characters.length, position.x + margin + border / 2, position.y + margin + border / 2, 0);
		} else
		{
			var maxOfLines = Math.ceil(size.y / font.height(fontSize));
			var topLine = Std.int((scrollOffset.y / font.height(fontSize)));
            if (topLine != 0) {
               topLine--; 
            }
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
			g.drawLine(position.x + margin + cursorX + border / 2 - scrollOffset.x, position.y + margin + font.height(fontSize) * line - scrollOffset.y, position.x + margin + cursorX + border / 2 - scrollOffset.x, position.y + margin + font.height(fontSize) * (line + 1) - scrollOffset.y, 2);
		} // blink caret

		if (Std.int(anim / 5) % 2 == 0 && beginScrollOver && isActive) 
		{
			scroll();
		}

		if (showEditingCursor)
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

        if (useScrollBar && scrollBottom > 0 && multiline)
		{
            _scrollBar.render(g);
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
			beginScrollOver: beginScrollOver,
			isWordWrapping: wordWrap,
			isMultiline: multiline,
			scrollOffsetX: scrollOffset.x,
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

    private static var activeTextBox:TextBox = null;
    private var isActive(get, null):Bool;
    private function get_isActive():Bool {
        return (activeTextBox == this);
    }
    
	function mouseDown(button:Int, x:Int, y:Int):Void // mouseDown
	{
		mouseButtonDown = true;
        if (inBounds(x, y)) {
            activeTextBox = this;
            _outOnce = false;
            selectionStart = selectionEnd = findIndex(x - position.x, y - position.y);
		}
	} // mouseDown

	function mouseUp(button:Int, x:Int, y:Int):Void // mouseUp
	{
		mouseButtonDown = false;
		beginScrollOver = false;
		if (x >= position.x && x <= position.x + size.x - scrollBarWidth && y >= position.y && y <= position.y + size.y)
		{
			_outOnce = false;
			activeTextBox = this;
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
			if (!hasSelection() || _outOnce)
				activeTextBox = null;
			
			_outOnce = true;
		}
	} // mouseUp

    private function inBounds(x:Int, y:Int):Bool {
        var cx = size.x - scrollBarWidth;
        return (x >= position.x && x <= position.x + cx && y >= position.y  && y <= position.y + size.y);
    }

    private function inScrollBounds(x:Int, y:Int):Bool {
        if (_scrollBar == null || _scrollBar.visible == false) {
            return false;
        }
        
        return (_scrollBar.hitTest(x, y) != HitResult.NONE);
    }
    
	function mouseMove(x:Int, y:Int, mx:Int, my:Int):Void // mouseMove
	{
		_mouseX = x;
		_mouseY = y;

        showEditingCursor = inBounds(x, y);

        if (showEditingCursor)
		{
            if (mouseButtonDown && selectionStart >= 0)
            {
                cursorIndex = selectionEnd = findIndex(x - position.x, y - position.y);
                if (cursorIndex < 0)
                    cursorIndex = 0;
                else if (cursorIndex > characters.length)
                    cursorIndex = characters.length;
            }
		}
		else if (mouseButtonDown && hasSelection() && !inScrollBounds(x, y) && isActive)
		{
			beginScrollOver = true;
		}
	} // mouseMove

	function mouseWheel(steps:Int):Void // mouseWheel
	{
		if (multiline && inBounds(_mouseX, _mouseY))
		{
			scrollOffset.y += steps * 20;
			if (scrollOffset.y < scrollTop || (breaks.length + 1) * font.height(fontSize) < size.y)
				scrollOffset.y = scrollTop;
			else if (scrollOffset.y > scrollBottom)
				scrollOffset.y = scrollBottom;
			
			updateScrollBarPosition();
		}
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

		var breakOut = false;
		var line = findCursorLine();
		var lastBreak = line > 0 ? breaks[line - 1] : 0;
		var cursorX = font.widthOfCharacters(fontSize, characters, lastBreak, cursorIndex - lastBreak);
		if (breaks.length > line) {
			var newBreak = breaks[line];
			var nextBreak = breaks.length > line + 1 ? breaks[line + 1] : characters.length;
			if (newBreak + 1 == nextBreak)
			{
				cursorIndex = newBreak;
				breakOut = true;
			}

			for (index in newBreak...nextBreak) {
				if (breakOut)
					break;

				var newX = font.widthOfCharacters(fontSize, characters, newBreak, index - newBreak);
				if (newX >= cursorX) {
					cursorIndex = index;
					if (selecting) {
						selectionEnd = cursorIndex;
					}
					breakOut = true;
				}
			}
			if (!breakOut)
			{
				cursorIndex = nextBreak;
				if (selecting) {
					selectionEnd = cursorIndex;
				}
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
		
		var breakOut = false;
		var line = findCursorLine();
		var lastBreak = line > 0 ? breaks[line - 1] : 0;
		var cursorX = font.widthOfCharacters(fontSize, characters, lastBreak, cursorIndex - lastBreak);
		if (line > 0) {
			var newBreak = line > 1 ? breaks[line - 2] : 0;
			var nextBreak = lastBreak;
			
			for (index in newBreak...nextBreak) {
				if (breakOut)
					break;

				var newX = font.widthOfCharacters(fontSize, characters, newBreak, index - newBreak);
				if (newX >= cursorX) {
					cursorIndex = index;
					if (selecting) {
						selectionEnd = cursorIndex;
					}
					breakOut = true;
				}
			}

			if (!breakOut)
			{
				cursorIndex = nextBreak - 1 < 0 ? 0 : nextBreak - 1;
				if (selecting) {
					selectionEnd = cursorIndex;
				}
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

		scrollToCaret();
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
				
				format();
			}
		}

		scrollToCaret();
	} // doDeleteOperation

	
	/**
	* Scrolling functions
	**/

	function scrollToCaret() // scrollToCaret
	{
		var caretPos = getIndexPosition(cursorIndex);

		if (multiline)
		{
			// vertical scrolling
			if (caretPos.y > scrollOffset.y + size.y - font.height(fontSize))
			{
				scrollOffset.y = caretPos.y - size.y + font.height(fontSize) + margin;
			}
			else if (caretPos.y < scrollOffset.y)
			{
				scrollOffset.y = caretPos.y - margin;
			}

			if (scrollOffset.y > scrollBottom)
				scrollOffset.y = scrollBottom;
			else if (scrollOffset.y < 0)
				scrollOffset.y = 0;
			
			updateScrollBarPosition();
		}
		
		var scrollLeft = findMaximumLineWidth();

		// horizontal scrolling
		if (caretPos.x > scrollOffset.x + size.x - margin * 2)
		{
			scrollOffset.x = caretPos.x - size.x + margin * 2;
		}
		else if (caretPos.x < scrollOffset.x)
		{
			scrollOffset.x = caretPos.x - margin;
		}

		if (scrollOffset.x > scrollLeft - size.x + margin * 2)
			scrollOffset.x = scrollLeft - size.x + margin * 2;
		
		if (scrollOffset.x < 0)
			scrollOffset.x = 0;
	} // scrollToCaret

	function onScrollBarChange() 
	{
        if (useScrollBar)
		{
			var percent = (_scrollBar.value - position.y) / (size.y / 2);
        	scrollOffset.y = _scrollBar.percentValue * scrollBottom;
		}
    }

	function scroll() // scroll
	{
		var x_val = _mouseX < position.x ? 0 : _mouseX - position.x;
		var y_val = _mouseY < position.y ? 0 : _mouseY - position.y;
		if (multiline)
		{
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
		}

		if (_mouseX < position.x)
		{
			var scroll_step = position.x - _mouseX;
			scrollOffset.x -= scroll_step;
			if (scrollOffset.x < 0)
				scrollOffset.x = 0;
		}
		else if (_mouseX > position.x + size.x)
		{
			var scroll_step = _mouseX - (position.x + size.x);
			scrollOffset.x += scroll_step;
			var maxWidth = findMaximumLineWidth();

			if (scrollOffset.x > maxWidth - size.x + margin * 2)
				scrollOffset.x = maxWidth - size.x + margin * 2;
			
			if (scrollOffset.x < 0)
				scrollOffset.x = 0;
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
        if (!_scrollBar.visible || _scrollBar == null) {
            return;
        }
		var percent = scrollOffset.y / scrollBottom;
		_scrollBar.value = percent * (size.y / 2);
	} // updateScrollBarPosition

	function checkScrollBar() // checkScrollBar
	{
		var scrollMax = (breaks.length + 1) * font.height(fontSize);
		scrollBottom = scrollMax - size.y + margin * 2;

		if (scrollMax < size.y)
		{
            if (_scrollBar != null) {
				scrollOffset.y = 0;
                _scrollBar.visible = false;
            }
			scrollBottom = 0;
		}
		else
		{
            if (_scrollBar != null) {
                _scrollBar.visible = true;
            }
		}
	} // checkScrollBar

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
		var startIndex = selectionStart;
		var endIndex = selectionEnd;
		if (endIndex < startIndex)
		{
			var temp = endIndex;
			endIndex = startIndex;
			startIndex = temp;
		}

		if (startIndex < 0)
			startIndex = 0;
		
		var count = endIndex - startIndex;

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

			scrollToCaret();
		}
	} // insertCharacter

    private var scrollBarWidth(get, null):Float;
    private function get_scrollBarWidth():Float {
        if (_scrollBar == null) {
            return 0;
        }
        return _scrollBar.width;
    }
    
    
	/**
	* Formatting functionality
	**/

	function format():Void // format
	{
		if (multiline && wordWrap)
		{
			var lastChance = -1;
			breaks = [];
			var lastBreak = 0;
			var i = 0;
			while (i < characters.length)
			{
				var width = font.widthOfCharacters(fontSize, characters, lastBreak, i - lastBreak);
				if (width >= size.x - margin * 2 - scrollBarWidth)
				{
					if (lastChance < 0)
					{
						lastChance = i - 1;
					}
					breaks.push(lastChance + 1);
					lastBreak = lastChance + 1;
					i = lastBreak;
					lastChance = -1;
				}

				if (characters[i] == " ".charCodeAt(0))
				{
					lastChance = i;
				}
				else if (characters[i] == "\n".charCodeAt(0) || characters[i] == "\r".charCodeAt(0))
				{
					breaks.push(i + 1);
					lastBreak = i + 1;
					lastChance = -1;
				}
				++i;
			}

			checkScrollBar();
		}
		else if (multiline)
		{
			var lastChance = -1;
			breaks = [];
			var lastBreak = 0;
			var i = 0;
			while (i < characters.length)
			{
				if (characters[i] == "\n".charCodeAt(0) || characters[i] == "\r".charCodeAt(0))
				{
					breaks.push(i + 1);
					lastBreak = i + 1;
					lastChance = -1;
				}
				++i;
			}

			checkScrollBar();
		}
		else
		{
			breaks = [];
			characters = getText().split("\n").join("").split("\r").join("").toCharArray();
		}
	} // format

	function findMaximumLineWidth():Float // findMaximumLineWidth
	{
		var result = 0.0;

		var line = 0;

		if (breaks.length == 0)
			return font.widthOfCharacters(fontSize, characters, 0, characters.length);
		
		var startX = 0;
		var endX = 0;

		for (lineBreak in breaks)
		{
			startX = line == 0 ? 0 : lineBreak;
			endX = line == 0 ? lineBreak : breaks[line];

			var width = font.widthOfCharacters(fontSize, characters, startX, endX - startX);

			if (width > result)
				result = width;
			
			line++;
		}

		var width = font.widthOfCharacters(fontSize, characters, endX, characters.length - endX);

		if (width > result)
			result = width;

		return result;
	} // findMaximumLineWidth

	function getIndexPosition(index:Int):FV2 // getIndexPosition
	{
		var result = new FV2(0, 0);
		var line = findLine(index);
		var startBreak = line > 0 ? breaks[line - 1] : 0;
		
		var x = font.widthOfCharacters(fontSize, characters, startBreak, index - startBreak);
		var y = line * font.height(fontSize) + margin;

		result = new FV2(x, y);

		return result;
	} // getIndexPosition

	function findLine(index:Int):Int // findLine 
	{
		var line = 0;
		for (lineBreak in breaks) 
		{
			if (lineBreak > index) 
			{
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
		var nextBreak = line + 1 > breaks.length ? characters.length : breaks[line + 1];

		var startLine = line > 0 ? breaks[line - 1] : 0;
		var endLine = line + 1 > breaks.length ? characters.length : breaks[line];
		
		var lineWidth = font.widthOfCharacters(fontSize, characters, startLine, endLine - startLine);
		if (x > lineWidth)
		{
			if (endLine == characters.length)
				return endLine;
			else
				return endLine - 1;
		}

		while (index < nextBreak) {
            var charWidth = font.widthOfCharacters(fontSize, characters, index, 1);
            totalWidth += charWidth;
			++index;
            if (totalWidth >= x - margin + scrollOffset.x) {
                var delta = totalWidth - (x - margin) + scrollOffset.x;
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
        if (hasSelection() && useTextHighlight) {
            var lineStartIndex = 0;
            if (line > 0) {
                lineStartIndex = breaks[line - 1];
            }
			var lineEndIndex = characters.length;
            if (line < breaks.length) {
                lineEndIndex = breaks[line];
            }
            
            var startInRange = (startIndex >= lineStartIndex && startIndex <= lineEndIndex);
            var endInRange = (endIndex >= lineStartIndex && endIndex <= lineEndIndex);
            
            if (startInRange == false && endInRange == false) {
                if (start >= startIndex && start + end <= endIndex && isActive) {
                    g.color = highlightTextColor;
                }
                g.drawCharacters(chars, start, end, x - scrollOffset.x, y + line * font.height(fontSize) - scrollOffset.y);
            } else if (startInRange == true && endInRange == true) {
                g.drawCharacters(chars, start, startIndex - start, x - scrollOffset.x, y + line * font.height(fontSize) - scrollOffset.y);
				
                x += font.widthOfCharacters(fontSize, chars, start, startIndex - start);
                start += startIndex - start;

                if (isActive) {
                    g.color = highlightTextColor;
                }
                g.drawCharacters(chars, start, endIndex - startIndex, x - scrollOffset.x, y + line * font.height(fontSize) - scrollOffset.y);

                x += font.widthOfCharacters(fontSize, chars, start, endIndex - startIndex);
                start += endIndex - startIndex;
                
                g.color = textColor;
                g.drawCharacters(chars, start, lineEndIndex - start, x - scrollOffset.x, y + line * font.height(fontSize) - scrollOffset.y);
            } else if (startInRange == true && endInRange == false) {
                g.drawCharacters(chars, start, startIndex - start, x - scrollOffset.x, y + line * font.height(fontSize) - scrollOffset.y);
              
                x += font.widthOfCharacters(fontSize, chars, start, startIndex - start);
                start += startIndex - start;
                
                if (isActive) {
                    g.color = highlightTextColor;
                }
                g.drawCharacters(chars, start, lineEndIndex - start, x - scrollOffset.x, y + line * font.height(fontSize) - scrollOffset.y);
            } else if (startInRange == false && endInRange == true) {
                if (isActive) {
                    g.color = highlightTextColor;
                }
                g.drawCharacters(chars, start, endIndex - start, x - scrollOffset.x, y + line * font.height(fontSize) - scrollOffset.y);
                
                x += font.widthOfCharacters(fontSize, chars, start, endIndex - start);
                start += endIndex - start;
                
                g.color = textColor;
                g.drawCharacters(chars, start, lineEndIndex - start, x - scrollOffset.x, y + line * font.height(fontSize) - scrollOffset.y);
			}
        } else {
            g.drawCharacters(chars, start, end, x - scrollOffset.x, y + line * font.height(fontSize) - scrollOffset.y);
        }
    } //renderLine

	function createString(array:Array<Int>):String //createString
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
