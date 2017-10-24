package textbox;
import kha.Color;
import kha.graphics2.Graphics;
import kha.input.Mouse;

@:enum
abstract HitResult(Int) from Int to Int {
    var NONE:Int = 0;
    var CONTAINER:Int = 1;
    var THUMB:Int = 2;
}

class ScrollBar
{
    public var width:Float = 25;
    public var visible:Bool = true;
    
    private var _textBox:TextBox;
	private var _isThumbDown:Bool;
    private var _isThumbOver:Bool;
    private var _proximity:Float = 100;
    
    public var onChange:Void->Void = null;
    
    public var thumbBaseColor:Color;
    public var thumbOverColor:Color;
    public var thumbDownColor:Color;
    public var backColor:Color;
    
    public function new(parent:TextBox)
    {
        _textBox = parent;
        backColor = Color.fromBytes(40, 40, 40);
        thumbBaseColor = Color.fromBytes(80, 80, 80);
        thumbDownColor = Color.fromBytes(20, 20, 20);
        thumbOverColor = Color.fromBytes(150, 150, 150);

        Mouse.get().notify(mouseDown, mouseUp, mouseMove, null, null);
    }
    
    private var _mouseDownY:Float = -1;
    function mouseDown(button:Int, x:Int, y:Int):Void // mouseDown
    {
        _isThumbDown = (hitTest(x, y) == HitResult.THUMB);
        if (_isThumbDown) {
            _mouseDownY = (y - scrollBarY - value);
        } else {
            _mouseDownY = -1;
        }
    }
    
    function mouseUp(button:Int, x:Int, y:Int):Void {
        _isThumbDown = false;
        _isThumbOver = (hitTest(x, y) == HitResult.THUMB);
    }
    
    function mouseMove(x:Int, y:Int, mx:Int, my:Int):Void {
        _isThumbOver = (hitTest(x, y) == HitResult.THUMB);
        if (_isThumbDown && _mouseDownY > -1) 
        {
            var left = scrollBarX - _proximity;
            var right = scrollBarX + _proximity;
            if (x >= left && x < right)
            {
                value = y - scrollBarY - _mouseDownY;
            }
        }
    }
    
    public function hitTest(x:Int, y:Int):HitResult {
        var r = HitResult.NONE;
        if (x >= scrollBarX && x <= scrollBarX + scrollBarWidth && y >= scrollBarY && y <= scrollBarY + scrollBarHeight) {
            r = HitResult.CONTAINER;
            if (y >= thumbY && y <= thumbY + thumbHeight) {
                r = HitResult.THUMB;
            }
        }
        return r;
    }
    
    private var _value:Float = 0;
    public var value(get, set):Float;
    private function get_value():Float {
        return _value;
    }
    private function set_value(newValue:Float):Float {
        if (newValue < 0) {
            newValue = 0;
        } else if (newValue > scrollBarHeight - thumbHeight) {
            newValue = scrollBarHeight - thumbHeight;
        }
        
        if (newValue != _value) {
            _value = newValue;
            if (onChange != null) {
                onChange();
            }
        }
        return _value;
    }
    
    public var percentValue(get, null):Float;
    private function get_percentValue():Float {
        return value / (scrollBarHeight - thumbHeight);
    }
    
    public function render(g:Graphics):Void {
        if (visible == false) {
            return;
        }
        
        g.color = backColor;
        g.fillRect(scrollBarX, scrollBarY, scrollBarWidth, scrollBarHeight);           
        
        var scrollFillColor = thumbBaseColor;
        if (_isThumbDown)
            scrollFillColor = thumbDownColor;
        else if (_isThumbOver)
            scrollFillColor = thumbOverColor;

        g.color = scrollFillColor;
        g.fillRect(scrollBarX, thumbY, scrollBarWidth, thumbHeight);           
    }
    
    private var scrollBarX(get, null):Float;
    @:noCompletion private function get_scrollBarX():Float {
        return _textBox.position.x + _textBox.size.x - width + _textBox.border / 2;
    }
    
    private var scrollBarY(get, null):Float;
    @:noCompletion private function get_scrollBarY():Float {
        return _textBox.position.y + _textBox.border / 2;
    }
    
    private var scrollBarWidth(get, null):Float;
    @:noCompletion private function get_scrollBarWidth():Float {
        return width - _textBox.border;
    }
    
    private var scrollBarHeight(get, null):Float;
    @:noCompletion private function get_scrollBarHeight():Float {
        return _textBox.size.y - _textBox.border;
    }
    
    private var thumbY(get, null):Float;
    @:noCompletion private function get_thumbY():Float {
        return scrollBarY + value;
    }
    
    private var thumbHeight(get, null):Float;
    @:noCompletion private function get_thumbHeight():Float {
        return _textBox.size.y / 2 - _textBox.border;
    }
}