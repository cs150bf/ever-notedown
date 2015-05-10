
# For EVND

Based on One-Light-Syntax package, modified to change background color, font family, font size, etc.

## Modifying `editor.less`

### Selectors

Add selector `pre.editor-colors` and change tag `atom-text-editor` to `.atom-text-editor`

Change   
```css
.atom-text-editor, // <- remove when Shadow DOM can't be disabled
:host {
```


To   

```css
.atom-text-editor, // <- remove when Shadow DOM can't be disabled
pre.editor-colors,
:host {
```

### Change color, background colors

Comment out the lines
```css
  //background-color: @syntax-background-color;
  //color: @syntax-text-color;
```



Add these lines
```css
  background-color: #ececec; // darken(#f7f7f7, 5%) = #ececec
  //overflow: scroll;
  padding: 10px 20px;
```


### Change font size, font family, line height, etc.

Added these lines:
```css
  font-size: 16px;
  font-family: "Liberation Mono", Courier, monospace;
  line-height: 1.6;
  font-weight: inherit;
  color: #000000;
```
