# KhaTextBox
A TextBox with selection, scrolling and cut/copy/paste functionality built on-top of Kha.

The most recent patch fixes an issue with using and rendering multiple TextBox's, including correctly hiding/showing the mouse cursor when hovering over them. However, you will need to call the following at the end of each frame for the mouse behaviour to work properly, otherwise the mouse will remain hidden.

```haxe
TextBox.mouseOverTextBox = false;
```

## Project's Future
The TextBox is considered complete. Most, if not all, of the features that exist are suitable for game development. If you wish to add your own features, I would suggest forking the project. This TextBox project will continue to receive bug fixes and optimisations where necessary when found to be an issue.

If you run into any problems using this TextBox, you may submit an issue and it will be resolved duly.
