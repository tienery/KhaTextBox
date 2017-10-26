package textbox;

import kha.math.FastVector2 in FV2;
import kha.Color;
import kha.graphics2.Graphics;
import kha.input.Mouse;

@:enum
abstract HitResult(Int) from Int to Int 
{
    var NONE:Int        = 0;
    var CONTAINER:Int   = 1;
    var THUMB:Int       = 2;
}

@:enum
abstract Orientation(Int) from Int to Int
{
    var VERTICAL    =   0;
    var HORIZONTAL  =   1;
}

class ScrollBar
{
    public var visible:Bool = true;
    public var position:FV2;
    public var size:FV2;
    public var orientation:Orientation;
    
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

        orientation = VERTICAL;
    }
    
    private var _mouseDownY:Float = -1;
    function mouseDown(button:Int, x:Int, y:Int):Void // mouseDown
    {
        _isThumbDown = (hitTest(x, y) == HitResult.THUMB);
        if (_isThumbDown) {
            if (orientation == VERTICAL)
                _mouseDownY = (y - position.y - value);
            else
                _mouseDownY = (x - position.x - value);
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
            if (orientation == VERTICAL)
            {
                var left = position.x - _proximity;
                var right = position.x + _proximity;
                if (x >= left && x < right)
                {
                    value = y - position.y - _mouseDownY;
                }
            }
            else
            {
                var up = position.y - _proximity;
                var down = position.y + _proximity;
                if (y >= up && y < down)
                {
                    value = x - position.x - _mouseDownY;
                }
            }
        }
    }
    
    public function hitTest(x:Int, y:Int):HitResult {
        var r = HitResult.NONE;
        if (x >= position.x && x <= position.x + size.x && y >= position.y && y <= position.y + size.y) {
            r = HitResult.CONTAINER;

            if (orientation == VERTICAL)
            {
                if (y >= thumbY && y <= thumbY + thumbHeight)
                    r = HitResult.THUMB;
            }
            else
            {
                if (x >= thumbY && x <= thumbY + thumbHeight)
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
        } else
        {
            if (orientation == VERTICAL)
            {
                if (newValue > size.y - thumbHeight)
                    newValue = size.y - thumbHeight;
            }
            else
            {
                if (newValue > size.x - thumbHeight)
                    newValue = size.x - thumbHeight;
            }
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
        var result = 0.0;
        if (orientation == VERTICAL)
            result = size.y - thumbHeight;
        else
            result = size.x - thumbHeight;

        return value / result;
    }
    
    public function render(g:Graphics):Void {
        if (visible == false) {
            return;
        }
        
        g.color = backColor;
        var x = position.x;
        var y = position.y;
        var width = size.x;
        var height = size.y;

        g.fillRect(x, y, width, height);           
        
        var scrollFillColor = thumbBaseColor;
        if (_isThumbDown)
            scrollFillColor = thumbDownColor;
        else if (_isThumbOver)
            scrollFillColor = thumbOverColor;

        g.color = scrollFillColor;
        if (orientation == VERTICAL)
            g.fillRect(x, thumbY, width, thumbHeight);
        else
            g.fillRect(thumbY, y, thumbHeight, height);
    }
    
    private var thumbY(get, null):Float;
    @:noCompletion private function get_thumbY():Float {
        if (orientation == VERTICAL)
            return position.y + value;
        else
            return position.x + value;
    }
    
    private var thumbHeight(get, null):Float;
    @:noCompletion private function get_thumbHeight():Float {
        if (orientation == VERTICAL)
            return size.y / 2;
        else
            return size.x / 2;
    }
}