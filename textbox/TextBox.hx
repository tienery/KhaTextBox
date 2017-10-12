package textbox;

import kha.Color;
import kha.Font;
import kha.graphics2.Graphics;
import kha.input.KeyCode;
import kha.input.Keyboard;
import kha.input.Mouse;
import kha.System;

using kha.StringExtensions;

class TextBox {
	var _mouseX: Int;
	var _mouseY: Int;
	var _mouse: Mouse;
	var _dt: Float;
	var _lastTime: Float;

	public var x: Float;
	public var y: Float;
	public var w: Float;
	public var h: Float;
	public var font: Font;
	public var fontSize: Int;
	static inline var margin: Float = 10;

	var characters: Array<Int>;
	var breaks: Array<Int>;

	var cursorIndex: Int;

	var anim: Int;
	var isActive: Bool;

	var selecting: Bool;
	var selectionStart: Int;
	var selectionEnd: Int;
	var wordSelection: Bool;
	var disableInsert: Bool;

	var mouseButtonDown: Bool;
	var showEditingCursor: Bool;

	var scrollOffset: Float;
	var scrollTop: Float;
	var scrollBottom: Float;
	var beginScrollOver: Bool;
	var isMouseOverScrollBar: Bool;
	var isMouseDownScrollBar: Bool;

	var keyCodeDown: Int;
	var repeatInterval: Int;
	var repeat: Int;
	var repeatDelay: Float;

	static var scrollBarWidth = 25;

    public var textColor:Int = -1;
    public var highlightColor:Int = -1;
    public var highlightTextColor:Int = -1;
    
	public function new(x: Float, y: Float, w: Float, h: Float, font: Font, fontSize: Int) {
		this.x = x;
		this.y = y;
		this.w = w;
		this.h = h;
		this.font = font;
		this.fontSize = fontSize;
		scrollBarWidth = 25;
		scrollTop = scrollBottom = scrollOffset = 0;
		anim = 0;
		characters = [];
		beginScrollOver = false;
		repeat = 0;
		repeatInterval = 2;
		// cursorIndexCache = [];
		breaks = [];
		disableInsert = showEditingCursor = wordSelection = selecting = false;
		selectionStart = selectionEnd = -1;
		Keyboard.get().notify(keyDown, keyUp, keyPress);
		mouseButtonDown = false;
		_mouse = Mouse.get();
		_mouse.notify(mouseDown, mouseUp, mouseMove, mouseWheel, null);

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
		#end

		format();

		_lastTime = System.time;
        
        if (textColor == -1) {
            textColor = Color.Black;
        }
        if (highlightColor == -1) {
            highlightColor = 0xFF3390FF;
        }
        if (highlightTextColor == -1) {
            highlightTextColor = Color.White;
        }
	}

	public function setText(value:String)
	{
		characters = value.toCharArray();
	}

	public function getText()
	{
		var result = "";
		for (i in 0...characters.length)
			result += String.fromCharCode(characters[i]);
		return result;
	}

	function createString(array: Array<Int>): String {
		var buf = new StringBuf();
		for (value in array) {
			buf.addChar(value);
		}
		return buf.toString();
	}

	function cut(): String {
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
	}

	function copy(): String {
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
	}

	function paste(data: String): Void {
		if (!isActive)
			return;

		for (i in 0...data.length) {
			characters.insert(cursorIndex, data.charCodeAt(i));
			++cursorIndex;
			format();
		}
	}

	function doLeftOperation()
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
	}

	function doRightOperation()
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
	}

	function doDownOperation()
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
	}

	function doUpOperation()
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
	}

	function doBackspaceOperation()
	{
		if (selectionStart > -1 && selectionEnd > -1)
			removeSelection();
		else
		{
			characters.splice(cursorIndex - 1, 1);
			--cursorIndex;
			if (cursorIndex < 0)
				cursorIndex = 0;
		}
	}

	function doDeleteOperation()
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
		}
	}

	function keyDown(code: KeyCode): Void {
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
			case Shift:
				if (selectionStart == -1 && selectionEnd == -1)
					selectionStart = selectionEnd = cursorIndex;
				
				selecting = true;
			case Control:
				wordSelection = true;
				disableInsert = true;
			default:
		}
	}

	function keyUp(code: KeyCode): Void {
		if (!isActive)
			return;

		keyCodeDown = -1;

		switch (code) {
			case Shift:
				selecting = false;
			case Left, Right, Up, Down:
				if (!selecting)
					selectionStart = selectionEnd = -1;
			case Backspace:
				doBackspaceOperation();
			case Delete:
				doDeleteOperation();
			case Control:
				wordSelection = false;
				disableInsert = false;
			default:
		}
	}

	function mouseDown(button: Int, x: Int, y: Int): Void {
		mouseButtonDown = true;
		if (y >= this.y && y <= this.y + this.h) {
			if (x >= this.x + this.w - scrollBarWidth && x <= this.x + this.w) {
				isMouseDownScrollBar = true;
			}
			else if (x >= this.x && x <= this.x + this.w) {
				selectionStart = selectionEnd = findIndex(x - this.x, y - this.y);
			}
		}
		else
			isActive = false;
	}

	function mouseUp(button: Int, x: Int, y: Int): Void {
		mouseButtonDown = false;
		beginScrollOver = false;
		isMouseDownScrollBar = false;
		if (x >= this.x && x <= this.x + w - scrollBarWidth && y >= this.y && y <= this.y + h)
		{
			isActive = true;
			cursorIndex = findIndex(x - this.x, y - this.y);
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

	}

	function mouseMove(x: Int, y: Int, mx: Int, my: Int): Void {
		_mouseX = x;
		_mouseY = y;

		showEditingCursor = (x >= this.x && x <= this.x + w - scrollBarWidth && y >= this.y && y <= this.y + h);

		if (y >= this.y && y <= this.y + this.h)
		{
			if (x >= this.x + this.w - scrollBarWidth && x <= this.x + this.w) {
				isMouseOverScrollBar = true;
			}
			else if (mouseButtonDown && selectionStart >= 0 && x >= this.x && x <= this.x + this.w - scrollBarWidth) {
				isMouseOverScrollBar = false;
				cursorIndex = selectionEnd = findIndex(x - this.x, y - this.y);
				if (cursorIndex < 0)
					cursorIndex = 0;
				else if (cursorIndex > characters.length)
					cursorIndex = characters.length;
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
	}

	function scrollToCaret()
	{
		var line = findCursorLine();
		var maxOfLines = Math.floor(h / font.height(fontSize));
		var topLine = Std.int((scrollOffset / font.height(fontSize)));
		var bottomLine = topLine + maxOfLines - 1;

		if (line > bottomLine)
		{
			scrollOffset += font.height(fontSize) * 5;
		}
		else if (line < topLine)
		{
			scrollOffset -= font.height(fontSize) * 5;
		}

		if (scrollOffset > scrollBottom)
			scrollOffset = scrollBottom;
		else if (scrollOffset < 0)
			scrollOffset = 0;
	}

	function scroll()
	{
		var x_val = _mouseX < this.x ? 0 : _mouseX - this.x;
		var y_val = _mouseY < this.y ? 0 : _mouseY - this.y;
		if (_mouseY < this.y)
		{
			var scroll_step = this.y - _mouseY;
			scrollOffset -= scroll_step;
			if (scrollOffset < scrollTop)
				scrollOffset = scrollTop;
			else if (scrollOffset > scrollBottom)
				scrollOffset = scrollBottom;
		}
		else if (_mouseY > this.y + h)
		{
			var scroll_step = _mouseY - (this.y + h);
			scrollOffset += scroll_step;
			if (scrollOffset < scrollTop)
				scrollOffset = scrollTop;
			else if (scrollOffset > scrollBottom)
				scrollOffset = scrollBottom;
		}

		cursorIndex = selectionEnd = findIndex(x_val, y_val);
		if (cursorIndex < 0)
			cursorIndex = 0;
		else if (cursorIndex > characters.length)
			cursorIndex = characters.length;
	}

	function mouseWheel(steps: Int): Void {
		scrollOffset += steps * 20;
		if (scrollOffset < scrollTop || (breaks.length + 1) * font.height(fontSize) < h)
			scrollOffset = scrollTop;
		else if (scrollOffset > scrollBottom)
			scrollOffset = scrollBottom;
		
	}

	function getNextCharacter(dir:Int = 1):Int {
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
	}

	function getEndOfWord(offset:Int = 0):Int {
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
	}

	function getStartOfWord(offset:Int = 0):Int {
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
	}

	function isChar(char:Int):Bool {
		return ((char >= 48 && char < 58) || (char >= 65 && char < 91) || (char >= 97 && char < 123));
	}

	function isAlphanumericOrChar(char:Int):Bool {
		return (char >= 33 && char < 126 || char > 127);
	}

	function removeSelection(): Void {
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
	}

	function keyPress(character: String): Void {
		if (!isActive)
			return;

		var char = character.charCodeAt(0);
		insertCharacter(char);
		keyCodeDown = char;
	}

	function insertCharacter(char: Int)
	{
		if (!disableInsert)
		{
			anim = 0;
			characters.insert(cursorIndex, char);
			++cursorIndex;
			format();
		}
	}

	function format(): Void {
		var lastChance = -1;
		breaks = [];
		var lastBreak = 0;
		var i = 0;
		while (i < characters.length) {
			var width = font.widthOfCharacters(fontSize, characters, lastBreak, i - lastBreak);
			if (width >= w - margin * 2 - scrollBarWidth) {
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
	}

	function checkScrollBar()
	{
		var scrollMax = (breaks.length + 1) * font.height(fontSize);
		scrollBottom = (scrollMax) - h + margin;
		if (scrollMax < h)
		{
			scrollBarWidth = 0;
			//format();
		}
		else
		{
			scrollBarWidth = 25;
		}
	}

	public function update(): Void {
		++anim;
		++repeat;
	}

	function findLine(index: Int): Int {
		var line = 0;
		for (lineBreak in breaks) {
			if (lineBreak > index) {
				break;
			}
			++line;
		}
		return line;
	}

	function findCursorLine(): Int {
		return findLine(cursorIndex);		
	}

	function findIndex(x: Float, y: Float): Int {
		var line = Std.int((y - margin + scrollOffset) / font.height(fontSize));
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
	}

	public function render(g: Graphics): Void {
		_dt = System.time - _lastTime;

		g.color = Color.White;
		g.fillRect(x, y, w, h);
		g.color = Color.Black;
		g.drawRect(x, y, w, h);

		if (keyCodeDown > -1)
		{
			repeatDelay += _dt;
			if (repeatDelay >= 0.5)
			{
				if (Std.int(repeat / repeatInterval) % 2 == 0 && isActive)
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
		else
			repeatDelay = 0;

		g.scissor(Math.round(x), Math.round(y), Math.round(w), Math.round(h));

		if ((selectionStart > -1 || selectionEnd > -1) && selectionStart != selectionEnd) {
			var startIndex = selectionStart;
			var endIndex = selectionEnd;
			if (endIndex < startIndex) {
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
			for (line in startLine...endLine + 1) {
				var x1 = x + margin;
				if (line == startLine) {
					x1 = x + margin + startX;
				}
				var x2 = x + w - margin - scrollBarWidth;
				if (line == endLine) {
					x2 = x + margin + endX;
				}
				g.fillRect(x1, y + margin + line * font.height(fontSize) - scrollOffset, x2 - x1, font.height(fontSize));
			}
		}

		g.color = textColor;
		g.font = font;
		g.fontSize = fontSize;

		if (breaks.length == 0) {
			g.drawCharacters(characters, 0, characters.length, x + margin, y + margin);
		} else { 
			var line = 0;
			var lastBreak = 0;
			for (lineBreak in breaks) {
                renderLine(g, characters, lastBreak, lineBreak - lastBreak, x + margin, y + margin, line);
                
				lastBreak = lineBreak;
				++line;
			}
            renderLine(g, characters, lastBreak, characters.length - lastBreak, x + margin, y + margin, line);
		}
		
		if (Std.int(anim / 20) % 2 == 0 && isActive) {
			var line = findCursorLine();
			var lastBreak = line > 0 ? breaks[line - 1] : 0;
			var cursorX = font.widthOfCharacters(fontSize, characters, lastBreak, cursorIndex - lastBreak);
			g.drawLine(x + margin + cursorX, y + margin + font.height(fontSize) * line - scrollOffset, x + margin + cursorX, y + margin + font.height(fontSize) * (line + 1) - scrollOffset, 2);
		}

		if (Std.int(anim / 5) % 2 == 0 && beginScrollOver && isActive) {
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

		g.color = Color.fromBytes(40, 40, 40);
		g.fillRect(x + w - scrollBarWidth, y, scrollBarWidth, h);

		var scrollFillColor = Color.fromBytes(80, 80, 80);
		if (isMouseDownScrollBar)
			scrollFillColor = Color.fromBytes(20, 20, 20);
		else if (isMouseOverScrollBar)
			scrollFillColor = Color.fromBytes(150, 150, 150);

		g.color = scrollFillColor;
		g.fillRect(x + w - scrollBarWidth, y, scrollBarWidth, h / 2);

		_lastTime = System.time;
	}
    
    // this can (should) be refactored a little - this is initial implementation / iteration
    private function renderLine(g:Graphics, chars:Array<Int>, start:Int, length:Int, x:Float, y:Float, line:Int) {
        var startIndex = selectionStart;
        var endIndex = selectionEnd;
        if (endIndex < startIndex) { // this should be moved somewhere else, selectionStart should never be > selectionEnd
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
                if (start >= startIndex &&  start + length <= endIndex) {
                    g.color = highlightTextColor;
                }
                g.drawCharacters(chars, start, length, x, y + line * font.height(fontSize) - scrollOffset);
            } else if (startInRange == true && endInRange == true) {                    
                g.drawCharacters(chars, start, startIndex - start, x, y + line * font.height(fontSize) - scrollOffset);
              
                x += font.widthOfCharacters(fontSize, chars, start, startIndex - start);
                start += startIndex - start;
                
                g.color = highlightTextColor;
                g.drawCharacters(chars, start, endIndex - startIndex, x, y + line * font.height(fontSize) - scrollOffset);

                x += font.widthOfCharacters(fontSize, chars, start, endIndex - startIndex);
                start += endIndex - startIndex;
                
                g.color = textColor;
                g.drawCharacters(chars, start, lineEndIndex - start, x, y + line * font.height(fontSize) - scrollOffset);
            } else if (startInRange == true && endInRange == false) {
                g.drawCharacters(chars, start, startIndex - start, x, y + line * font.height(fontSize) - scrollOffset);
              
                x += font.widthOfCharacters(fontSize, chars, start, startIndex - start);
                start += startIndex - start;
                
                g.color = highlightTextColor;
                g.drawCharacters(chars, start, lineEndIndex - start, x, y + line * font.height(fontSize) - scrollOffset);
            } else if (startInRange == false && endInRange == true) {
                g.color = highlightTextColor;
                g.drawCharacters(chars, start, endIndex - start, x, y + line * font.height(fontSize) - scrollOffset);
                
                x += font.widthOfCharacters(fontSize, chars, start, endIndex - start);
                start += endIndex - start;

                
                g.color = textColor;
                g.drawCharacters(chars, start, lineEndIndex - start, x, y + line * font.height(fontSize) - scrollOffset);
            } else {
                g.drawCharacters(chars, start, length, x, y + line * font.height(fontSize) - scrollOffset);
            } 
        } else {
            g.drawCharacters(chars, start, length, x, y + line * font.height(fontSize) - scrollOffset);
        }
    }
    
    private inline function hasSelection() {
        return ((selectionStart > -1 || selectionEnd > -1) && selectionStart != selectionEnd);
    }
}
