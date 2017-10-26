package textbox;

import kha.math.FastVector2 in FV2;
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
    public var visible:Bool = true;
    public var position:FV2;
    public var size:FV2;
    
	private var _isThumbDown:Bool;
    private var _isThumbOver:Bool;
    private var _proximity:Float = 100;
    
    public var onChange:Void->Void = null;
    
    public var thumbBaseColor:Color;
    public var thumbOverColor:Color;
    public var thumbDownColor:Color;
    public var backColor:Color;
    
    public function new()
    {
        backColor = Color.fromBytes(40, 40, 40);
        thumbBaseColor = Color.fromBytes(80, 80, 80);
        thumbDownColor = Color.fromBytes(20, 20, 20);
        thumbOverColor = Color.fromBytes(150, 150, 150);

        Mouse.get().notify(mouseDown, mouseUp, mouseMove, null, null);

        position = new FV2(0, 0);
        size = new FV2(0, 0);
    }
    
    private var _mouseDownY:Float = -1;
    function mouseDown(button:Int, x:Int, y:Int):Void // mouseDown
    {
        _isThumbDown = (hitTest(x, y) == HitResult.THUMB);
        if (_isThumbDown) {
            _mouseDownY = (y - position.y - value);
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
            var left = position.x - _proximity;
            var right = position.x + _proximity;
            if (x >= left && x < right)
            {
                value = y - position.y - _mouseDownY;
            }
        }
    }
    
    public function hitTest(x:Int, y:Int):HitResult {
        var r = HitResult.NONE;
        if (x >= position.x && x <= position.x + size.x && y >= position.y && y <= position.y + size.y) {
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
        } else if (newValue > size.y - thumbHeight) {
            newValue = size.y - thumbHeight;
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
        return value / (size.y - thumbHeight);
    }
    
    public function render(g:Graphics):Void {
        if (visible == false) {
            return;
        }
        
        g.color = backColor;
        g.fillRect(position.x, position.y, size.x, size.y);           
        
        var scrollFillColor = thumbBaseColor;
        if (_isThumbDown)
            scrollFillColor = thumbDownColor;
        else if (_isThumbOver)
            scrollFillColor = thumbOverColor;

        g.color = scrollFillColor;
        g.fillRect(position.x, thumbY, size.x, thumbHeight);           
    }
    
    private var thumbY(get, null):Float;
    @:noCompletion private function get_thumbY():Float {
        return position.y + value;
    }
    
    private var thumbHeight(get, null):Float;
    @:noCompletion private function get_thumbHeight():Float {
        return size.y / 2;
    }
}