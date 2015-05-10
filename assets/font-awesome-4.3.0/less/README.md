# Modifications made for EVND

In `path.less`, remove version info otherwise Atom will not be able to resolve the path properly.


> Error message:   
>> atom://ever-notedown/assets/font-awesome-4.3.0/fonts/fontawesome-webfont.ttf?v=4.3.0:1 GET atom://ever-notedown/assets/font-awesome-4.3.0/fonts/fontawesome-webfont.ttf?v=4.3.0 net::ERR_FILE_NOT_FOUND
>   

&nbsp;

Original:
```css
@font-face {
  font-family: 'FontAwesome';
  src: url('@{fa-font-path}/fontawesome-webfont.eot?v=@{fa-version}');
  src: url('@{fa-font-path}/fontawesome-webfont.eot?#iefix&v=@{fa-version}') format('embedded-opentype'),
    url('@{fa-font-path}/fontawesome-webfont.woff2?v=@{fa-version}') format('woff2'),
    url('@{fa-font-path}/fontawesome-webfont.woff?v=@{fa-version}') format('woff'),
    url('@{fa-font-path}/fontawesome-webfont.ttf?v=@{fa-version}') format('truetype'),
    url('@{fa-font-path}/fontawesome-webfont.svg?v=@{fa-version}#fontawesomeregular') format('svg');
//  src: url('@{fa-font-path}/FontAwesome.otf') format('opentype'); // used when developing fonts
  font-weight: normal;
  font-style: normal;
}
```


&nbsp;

Modified:
```css
@font-face {
  font-family: 'FontAwesome';
  src: url('@{fa-font-path}/fontawesome-webfont.eot');
  src: url('@{fa-font-path}/fontawesome-webfont.eot?#iefix') format('embedded-opentype'),
    url('@{fa-font-path}/fontawesome-webfont.woff2') format('woff2'),
    url('@{fa-font-path}/fontawesome-webfont.woff') format('woff'),
    url('@{fa-font-path}/fontawesome-webfont.ttf') format('truetype'),
    url('@{fa-font-path}/fontawesome-webfont.svg#fontawesomeregular') format('svg');
//  src: url('@{fa-font-path}/FontAwesome.otf') format('opentype'); // used when developing fonts
  font-weight: normal;
  font-style: normal;
}
```
