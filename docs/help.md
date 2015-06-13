
This is an Atom plugin for editing Evernote notes in Markdown format that works with the Evernote Mac client via AppleScript.
> This doc is intended to be viewed in Atom with EVND. To see the result as a rendered note in Evernote, see [this sample note](https://www.evernote.com/l/AER4LWAANh9JY7PBhP9q8rYllx9Znkw5zY8). If you are currently viewing this note on `www.evernote.com`, it's recommended that you use `Save to Evernote` to view with your Evernote Mac Client.   


[TOC]

# EVND (Ever Notedown) Demo - Help Document (Draft)


## Intro

### Overview
This is an Atom plugin for editing Evernote notes in Markdown format.

 ![demo overview](atom://ever-notedown/docs/demo/demo-0-create-note.gif "demo-0-create-note.gif")

- **OS X only** (See `Installation` and `Status` section for more info)
- **Local note editing**: 
  - This plugin works by communicating with the Evernote OSX Client via AppleScript, so all the work is done on your local machine, no authorization required.
- **2-way editing (...ish)**
  - Edit notes in EVND or in Evernote, and sync changes... to some extend.
  - Import notes from Evernote and convert to Markdown format.
- **Evenote meta info: notebook and tags** [**\[demo\]**](https://www.evernote.com/l/AETmq10fstdMo5-b5RJSrIAyBY6sScLvYqs)
- **Images and Attachments** [**\[See demo\]**](https://www.evernote.com/l/AESqRZ75YFRDrojYCY5l0XNhp6EATx1Vy2c)
  - Pasting, drag-and-drop, markdown syntax, etc.
  - 2-way sync (get changes/annotations made in Evernote)
- **Functioning TOC (table of contents) and footnotes**
  - Clickable links even in Evernote client![^sample footnote] [**\[See demo\]**](https://www.evernote.com/l/AETJY1bRe-5AtLzDibAX06qeFH4b47uRg5E)
- **LaTeX Mathematical Expressions with MathJax (and user-defined Macros)** [**\[See demo\]**](https://www.evernote.com/l/AES5wqBjghpBh79jgzEGhqByqKD1uw64B5U)
- **Icon fonts and emojis** :tada:
- **All the regular Github-Flavored-Markdown features (links, lists, tables, etc.)**
- **Quick notes from selected text: code snippets, etc.**
- **Configurable themes for markdown rendering** [**\[Demo here\]**](https://www.evernote.com/l/AERp-6EbVWJDl5ZHzWwhll_AxrLpEFd13N4)
  - Several markdown rendering themes are available to choose, you can also edit the stylesheets yourself.
- **Auto backup and version control (with GIT)**
- **Sort & search notes** [**\[See demo\]**](https://www.evernote.com/l/AETukpDn_w1DYKIQu0GVqc29jKS5ADeCR-A)
- **Export well-formated HTMLs**
- **Enhanced Markdown editing experience in Atom**
  - Supports inline-HTML syntax highlighting
  - Syncronized scrolling and tab switching of editor and preview panel
  - Shortcut keys for formatting text (bold, italics, udnerline, highlights, blockquotes, etc.)

&nbsp;

> ### Status
> 
> Works For Me... (WFM)[^footnote status]

&nbsp;  
&nbsp;   

## Installation

### Requirements

- OS X `Mavericks, Yosemite`
- Atom `>0.197.0` <sub>WFM</sub> [^wfm]
- Evernote OSX Client `>6.0.0`
- GIT `2.1.2` <sub>WFM</sub>[^wfm] &nbsp; (Version 2+ should work.)


### Preparation
**Before installing the EVND plugin**, please consider _**Setting Up EVND Storage**_ first (assuming you already have Atom installed):  
1. Decide where you want your EVND notes (markdown text file, rendered HTMLs, images and attachments, etc.) to locate.   
  -- Personally, I would put the EVND folder in a cloud drive sync'd directory (dropbox, google drive, onedrive, etc.).     
2. Create the folder, and make a symbolic link to `~/.atom/evnd`:     
 ```bash
 $ ln -s path/to/your/folder ~/.atom/evnd
 ```
3. Enter the folder, create a file named `index.json`, write `{}` and save.    
 ```bash
 $ cd ~/.atom/evnd
 $ echo "{}" > index.json
 ```
4. Initialize the folder as a git repo (and make an initial commit if you like)    
 ```bash
 $ cd path/to/your/folder
 $ git init
 ------ Optional ------
 $ git add .
 $ git commit -m "Initial commit"   
 ```

&nbsp;&nbsp;&nbsp;

### Install
- **APM**: `apm install ever-notedown`
- **Preferences**: Open Atom and go to `Preferences > Packages`, search for `Ever Notedown`, and install it.  

&nbsp;   
&nbsp;


### Using EVND

#### First Time
If you haven't already set up the EVND local storage, it will try to create a folder at `~/.atom/evnd/` for you... or so I think. 

> **Enabling spell-check:**   
> By default, the Atom **`spell-check`** core package activates only for these grammars: `source.asciidoc`, `source.gfm`, `text.git-commit`, `text.plain`, `text.plain.null-grammar`. To enable spellcheck for custom EVND grammars, go to Atom -> Preferences -> Packages -> spell-check, and set _`Grammars`_ to:   
>> [source.asciidoc, source.gfm, text.git-commit, text.plain, text.plain.null-grammar, source.litcoffee, text.markdown.evnd.mathjax.source.litcoffee.inline.html, text.markdown.evnd.mathjax.source.gfm.inline.html, text.markdown.evnd.source.gfm.inline.html]
>   


#### Activating EVND

To save Atom start up time, EVND will only be automatically loaded partially when you open Atom, so there might be times when you see that elements such as `[TOC]` and mathjax equations are not rendered in preview. There are many ways to fully activate EVND, e.g.: toggling the EVND panel, opening up the drop-down EVND note list, etc. 
> [**Demo**](https://www.evernote.com/l/AERzpsK7uF1EhIaMHEvwfAktAEg5xowOCwg)

#### Atom UI Theme compatibility

For now I know EVND can look kind of awkward with the One Dark/Light UI theme. Atom Dark/Light UI, Seti UI, Unity UI and Yosemite UI should be fine.

#### Shortcut Keys (General EVND Functions)

| Keyboard Shortcuts                           | Function          |
|:---------------------------------------------|:-----------------:|
| <kbd>shift</kbd><kbd>cmd</kbd><kbd>M</kbd> | Toggle Preview    |
| <kbd>shift</kbd><kbd>cmd</kbd><kbd>E</kbd> | To Evernote       |
| <kbd>alt</kbd><kbd>cmd</kbd><kbd>n</kbd>   | Toggle Note List  |
| <kbd>f5</kbd>                                | Refresh (preview) |
| <kbd>cmd</kbd><kbd>+</kbd>, <kbd>cmd</kbd><kbd>=</kbd>                 | Zoom-in (preview) |
| <kbd>cmd</kbd><kbd>-</kbd>, <kbd>cmd</kbd><kbd>\_</kbd>                 | Zoom-out (preview)|
| <kbd>cmd</kbd><kbd>0</kbd>                 | Reset zoom (preview)|

> [link to how to customize your own keyboard shortcuts in Atom]

&nbsp;   
&nbsp;   

## Features

### Communicating with Evernote

#### 2-way syncing <i class="fa fa-refresh"></i>

- Notes created in EVND: 
  - **EVND->Evernote**: Works pretty well. You can push changes to Evernote any time you want.
  - _Evernote->EVND_: You can make changes in Evernote and then load the changes back to EVND... sort of[^fn html2markdown].
- Import notes from Evernote
  - with notelink or query string [**\[see demo\]**](https://www.evernote.com/l/AESxb3MfMWlL_Iqhv7kx7PSfFuUKjIzhU2o). EVND will (attempt to) convert the notes into Markdown[^fn html2markdown].
  
#### Images and Attachments <i class="icon icon-file-media"></i>

- Insert images with pasting or drag-and-drop
- Insert attachments with syntax `!{alt text}[path/to/file "Optional Text"]` or drag-and-drop
- Special attachments (PDFs, audios) will display properly in Evernote.
- 2-way syncing! New attachments added and changes made in Evernote will be detected and loaded back to the EVND storage (e.g. annotated images in Evernote, etc.)


> `*` _Not sure how well it works with large files..._   

&nbsp;

### Note Management

You can use 2 versions of note browser:
1. A searchable drop-down list of notes. You can change the default sorting method in the EVND package settings.
  - Fuzzy search with any text in title, tags, notebook, file path, etc. (anything visible in the drop-down list).
  - Search with keywords (e.g."notebook:inbox")
2. A browser in side panel organized by notebooks with several sorting buttons. 


> [**Demo here**](https://www.evernote.com/l/AETukpDn_w1DYKIQu0GVqc29jKS5ADeCR-A)

&nbsp;

### Themes for Rendering

> [**Demo here**](https://www.evernote.com/l/AERp-6EbVWJDl5ZHzWwhll_AxrLpEFd13N4)

&nbsp;

### Extended GFM Syntax


#### LaTeX Mathematical Expressions with MathJax


##### MathJax: Basic Usage

- Inline math equations (`$...$`): $a^2 + b^2 = c^2$
- Display mode math equations (`$$...$$`):
$$ 
\begin{align}
  \nabla \times \vec{\mathbf{B}} -\, \frac1c\, \frac{\partial\vec{\mathbf{E}}}{\partial t} & = \frac{4\pi}{c}\vec{\mathbf{j}} \\
  \nabla \cdot \vec{\mathbf{E}} & = 4 \pi \rho \\
  \nabla \times \vec{\mathbf{E}}\, +\, \frac1c\, \frac{\partial\vec{\mathbf{B}}}{\partial t} & = \vec{\mathbf{0}} \\
  \nabla \cdot \vec{\mathbf{B}} & = 0
\end{align}
$$

> **Notes:** If mathjax is enabled in settings, you will need to use backslash to escape regular dollar signs: \$

&nbsp;

##### MathJax: Custom Macros

You can define your own macros or use one of the pre-defined macro files. 

TODO: Screenshot 1   
TODO: Screenshot 2   

To choose one of the pre-defined macro files, go to EVND package settings (`Atom->Preferences->Packages->Ever Notedown`), find the config option for "Mathjax Custom Macros"(see screenshot) and select from drop down list.

![Alt text](atom://ever-notedown/docs/images/clipboard_20150430_211015.png "Optional title")      
&nbsp;

Fo view current macros or edit custom macros, from the menu bar, select `Packages -> Ever Notedown -> Settings -> MathJax`. You can use the pre-defined macros for reference.

> [**Demo for MathJax & Macros**](https://www.evernote.com/l/AES5wqBjghpBh79jgzEGhqByqKD1uw64B5U)

&nbsp;

#### Table of Contents

To define a table of contents, write `[toc]` or `[TOC]` in a separate paragraph.

&nbsp;

#### Footnotes

To insert a footnote, use `[^footnote label text]`, like this[^another sample footnote], and then define the footnote by writing a separate paragraph anywhere in the document, starting the paragraph with `[^footnote label text]: `.

[^another sample footnote]: Footnote definition!

&nbsp;

#### Attachments <i class="fa fa-paperclip"></i>

Insert attachments with the syntax `!{alt text}(path/to/your/attachment/file "Optional title")`.

> - [**Demo for PDF attachments**](https://www.evernote.com/l/AESHF44qHkRANq1H4U4W9GLvMMdI7ojT2O4)
> - [**Demo for Audio Attachments**](https://www.evernote.com/l/AEQGmNV9LGNHopmiaylXNKxpKwnUhEpuujg)

&nbsp;

#### Images

Use the usual Markdown syntax for images: `![Alt Text](path/to/the/image "Optional Title")`

> [**Demo for 2-way syncing images**](https://www.evernote.com/l/AESqRZ75YFRDrojYCY5l0XNhp6EATx1Vy2c)

&nbsp;

#### Icon Fonts and Emojis

You can insert emojis like this - (`:tada:`) :tada:   

Octicons and FontAwesome are also available, use `<i class="icon icon-home"></i>` and `<i class="fa fa-anchor"></i>` and EVND will convert them to PNG images when sending to Evernote:
- <i class="icon icon-home"></i>   
- <i class="fa fa-anchor"></i>
- <i class="fa fa-university"></i>


> **TODO**: More on this... Image size, color, quality, how to customize & extend, etc.

&nbsp;

#### Fenced code blocks

You can define fenced code block in the usual GFM way. Several syntax highlighting themes are available in the package settings.

```python
import numpy as np
import matplotlib.pyplot as plt

print "Hello World!"
```

![Alt text](atom://ever-notedown/docs/images/clipboard_20150501_172409.png "Optional title")    
&nbsp;

You can also customize your own syntax theme:
> **Menu**:   
> Packages -> Ever Notedown -> Settings -> Syntax Themes (for fenced code blocks) -> Edit Syntax Theme: custom1.css 

&nbsp;

#### Tables

| Tables   |      Are         |  Cool     |
|----------|:----------------:|----------:|
| col 1 is |  left-aligned    |    \$1600 |
| col 2 is |    centered      |      \$12 |
| col 3 is | right-aligned    |       \$1 |
| See how  | the dollar signs | <u>are</u>|
| escaped? | **bold** _italic_| &nbsp;    |

&nbsp;

#### Checkboxes

You can configure EVND to render `[ ]`, `[x]` as checkboxes everywhere in the file beside is the general GFM task list `- [ ]`. Those checkboxes will be funcitoning in Evernote, and you can load changes back into EVND.
> [**Demo here**](https://www.evernote.com/l/AERKM1qy1s5Lp6jyDcHN2pBkRCk4AIst-es)

&nbsp;   


&nbsp;

### Editing Markdown Files in Atom with EVND

#### Quick notes from selection (code snippet)
Quickly clip part of your code as a new note. 
> [**Demo**](https://www.evernote.com/l/AERKM1qy1s5Lp6jyDcHN2pBkRCk4AIst-es)

&nbsp;
#### Keyboard Shortcuts for Text Formating

| Keyboard Shortcuts      | Format     |
|:------------------------|:----------:|
|<kbd>cmd</kbd><kbd>b</kbd>       | **bold**   |
|<kbd>cmd</kbd><kbd>i</kbd>       | _italic_   |
|<kbd>ctrl</kbd><kbd>~</kbd> (ctrl + shift + \`)| ~~strikethrough~~|
|<kbd>shift</kbd><kbd>cmd</kbd><kbd>U</kbd>| <u>underline</u>|
|<kbd>shift</kbd><kbd>cmd</kbd><kbd>H</kbd>| <mark>highlight</mark>|
|<kbd>cmd</kbd><kbd>></kbd> (shift + cmd + .) or <br> <kbd>shift</kbd><kbd>cmd</kbd><kbd>K</kbd>| blockquote|


>[**See demo**](https://www.evernote.com/l/AETNS1RKOoJMuKAg9uzLQsNqXXw4Z_zeAdw)


&nbsp;
  
#### Syncronized Scrolling

Limited but basically working...   
> [**Demo**](https://www.evernote.com/l/AEQHcoHTT-hHgqf3Ryt1JmVcfX6gstuNoSg)

&nbsp;

#### Auto tab switching
Only works after EVND is "fully" activated. Suppose you have multiple markdown files and their previews opened in split mode with markdown files on one side and previews on the other, when you switch tabs between markdown files, the corresponding previews will automatically switch accordingly. (See demo)

> [**Demo**](https://www.evernote.com/l/AEQHcoHTT-hHgqf3Ryt1JmVcfX6gstuNoSg)

&nbsp;
#### Enhanced Syntax Highlighting in Editors

- inline HTML
- EVND syntax: attachments
- EVND syntax: mathjax equations

~~(Screenshots here)~~  

##### Inline HTML Highlighting

| Default GFM in Atom | Extended GFM with EVND |
|:------------------- | ----------------------:|
|![Alt text](atom://ever-notedown/docs/images/clipboard_20150509_192314.png "Optional title") | ![Alt text](atom://ever-notedown/docs/images/clipboard_20150509_192555.png "Optional title") |
|![Alt text](atom://ever-notedown/docs/images/clipboard_20150509_194336.png "Optional title") | ![Alt text](atom://ever-notedown/docs/images/clipboard_20150509_192507.png "Optional title")|

##### Attachment Definition
| Default GFM in Atom | Extended GFM with EVND |
|:------------------- | ----------------------:|
| TODO |  TODO |

##### MathJax Highlighting
| Default GFM in Atom | Extended GFM with EVND |
|:------------------- | ----------------------:|
| ![Alt text](atom://ever-notedown/docs/images/clipboard_20150509_193731.png "Optional title") |  ![Alt text](atom://ever-notedown/docs/images/clipboard_20150509_193136.png "Optional title") |


&nbsp;  
&nbsp;  

## Troubleshooting

### Frequrently Asked Questions

- Question 1
- Question 2

### Evernote Bugs <i class="icon icon-bug"></i>

#### Cannot create notebook with AppleScript - Ticket# 1014193  

Currently users cannot create new notebooks from EVND due to a bug in Evernote Mac Client's AppleScript functionalities. Read more in **Notes for Developers** (Packages -> Ever Notedown -> Help -> Notes for Developers).  


#### Random Upload Limit Error - Ticket# 953466

Attempting to update the `HTML content` of a note with basically the same content with get an error message saying

    error "Evernote got an error: Operation would exceed monthly upload allowance.
    
Barring some rare exceptions, users should not see this in EVND...  

&nbsp;  
&nbsp;

## Tips

- Disable `live update` for better performance (preview will refresh upon save)
- Consider disable auto-complete for better performance
- Use key-bindings and snippets for faster input

&nbsp;

## Credits

### Inspired by

- [Evernote Plugin for Sublime Text](https://github.com/bordaigorl/sublime-evernote)
- [MacDown](https://github.com/uranusjr/macdown)
- Mou Editor
- Atom Markdown Preview
- Markdown Preview Plus
- StackEdit
- Marxico


&nbsp;


## What Else?

- Notes for developers?[^developers]



[^developers]: Packages -> Ever Notedown -> Helper -> Notes For Developers


[^footnote status]: **Status** - I initially wrote this for my own use, and over the course of about a year, it has become increasingly...complicated. And I'm guessing that other people might find some use with this, so I thought I'd share. I've been using EVND to write my notes, but I don't have the time or means to do more serious tests, hence I can only say the status is _**"Works For Me"**_.  

[^wfm]: **WFM (Works for me)** - Works for me.

[^fn html2markdown]: **HTML2Markdown** -  The result might vary since the function is still in a crude state. The resulting Markdown text might contain some un-converted HTML. Changes in meta info (notebook, tags) and images & attachments should be loaded just fine.

[^sample footnote]: **Sample footnote** - No big deal, just a random footnote.
