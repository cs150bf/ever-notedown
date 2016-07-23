#   EVND (Ever Notedown) 

## About
=======
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/cs150bf/ever-notedown/master/LICENSE.md) [![Version 0.2.24](https://img.shields.io/badge/apm-v0.2.24-green.svg)](https://github.com/cs150bf/ever-notedown/releases)

This is an Atom plugin for editing Evernote notes in Markdown format that works with the Evernote Mac client via AppleScript. Please read more [here](https://www.evernote.com/l/AER4LWAANh9JY7PBhP9q8rYllx9Znkw5zY8).

![demo overview](https://raw.github.com/cs150bf/ever-notedown/master/docs/demo/demo-0-create-note.gif "demo-0-create-note.gif")


## About This Branch

This branch is made for those who wants to use different fonts for MathJax. See more on [this issue](https://github.com/cs150bf/ever-notedown/issues/42).  

How to:   
0) Exit Atom.   
1) Move your `~/.atom/packages/ever-notedown/` folder to somewhere else;   
2) Clone branch `morefonts` of the repo
```bash
$ cd ~/.atom/packages
$ git clone --branch morefonts https://github.com/cs150bf/ever-notedown
```   
3) Re-install the package
```bash
$ cd ~/.atom/packages/ever-notedown
$ apm install
```   
4) Choose your favorite MathJax font BEFORE starting Atom by modifying the `lib/mathjax-helper.coffee` file. For example:
```bash
$ cd ~/.atom/packages/ever-notedown/lib
```
Open `mathjax-helper.coffee` with your favorite text editor. Scroll down to the bottom to find the section with `MathJax.Hub.Config`, modify the line starting with `font: ` in the following segment:
```coffee
    SVG: {
      font: "Gyre Pagella"
      undefinedFamily: ["STIXGeneral", 'Arial Unicode MS', "serif"]
      linebreaks:
        automatic: false
        width: "75%"
    }
```
Now if you start Atom and try again you should see MathJax font is now set to `Gyre Pagella`.   

5) If you want to change the font, you need to first exit Atom, do the modify `lib/mathjax-helper.coffee` thing again, and restart Atom. I know, it's quite painful...   

6) For now these fonts are available.
```
Asana-Math
Gyre-Pagella
Gyre-Termes
Latin-Modern
Neo-Euler
STIX-web
TeX
```


