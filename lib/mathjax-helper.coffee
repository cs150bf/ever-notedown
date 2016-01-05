# Used some code from
#   https://github.com/Galadirith/markdown-preview-plus/blob/15804e705c5831ff572b354cf150214c4bdbee4f/lib/mathjax-helper.coffee#
## mathjax-helper
##
## This module will handle loading the MathJax environment and provide a wrapper
## for calls to MathJax to process LaTeX equations.
#
# Reproduced LICENSE Info:
#
#  Copyright (c) 2014 Edward Fauchon-Jones
#
#  Permission is hereby granted, free of charge, to any person obtaining
#  a copy of this software and associated documentation files (the
#  "Software"), to deal in the Software without restriction, including
#  without limitation the rights to use, copy, modify, merge, publish,
#  distribute, sublicense, and/or sell copies of the Software, and to
#  permit persons to whom the Software is furnished to do so, subject to
#  the following conditions:
#
#  The above copyright notice and this permission notice shall be
#  included in all copies or substantial portions of the Software.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
#  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
#  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
#  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

CSON    = null #require 'season'
path    = null #require 'path'
utils   = null #require './utils'
svg2pngHelper = require('./svg2png-helper')


#
# Default Macros
#
defaultMacros =
  bold: ["{\\bf #1}", 1]
  #
  #vec: ['\\mathbf\{ #1\}', 1]
  #ket: ['\\left|#1\\right\\rangle', 1]
  #bra: ['\\left\\langle #1\\right|', 1]
  #ketbra: ['\\left|#1\\rangle\\!\\langle #2\\right|', 2]
  #braket: ['\\left\\langle #1\\middle\\vert #2 \\right\\rangle', 2]
  #

macroPaths =
  "None": ""
  "Default": "default.cson"
  "Physical Sciences": "physical-sciences.cson"
  "Math": "math.cson"
  "Custom 1": "custom1.cson"
  "Custom 2": "custom2.cson"

loadCustomMacros = ->
  path ?= require 'path'
  CSON ?= require 'season'

  macroFile = atom.config.get('ever-notedown.mathjaxCustomMacros')
  if macroFile is "None"
    macros = {}
  else
    evndPkgPath = atom.packages.resolvePackagePath('ever-notedown')
    macrosPath = path.join evndPkgPath, "assets/mathjax/macros", macroPaths[macroFile]
    try
      macros = CSON.readFileSync(macrosPath)
    catch e
      console.log e
      macros = null
  return macros


module.exports =
  #
  # Load MathJax environment
  #
  loadMathJax: ->
    path ?= require 'path'
    script = document.getElementById("mathjax-script")
    unless script?
      script = document.createElement("script")
      script.id = "mathjax-script"
      script.addEventListener "load", () ->
        configureMathJax()
      script.type = "text/javascript"
    try
      # (Original comment in 'mathjax-wrapper' package:
      #
      ## atom.packages.resolvePackagePath('mathjax-wrapper') doesnt work but
      ## does for other packages? Nor does 'atom://mathjax-wrapper' work (I get
      ## CSP errors). getLoaded over getActive is important.
      pkgPath = atom.packages.getLoadedPackage('ever-notedown')
      script.src  = path.join(
        pkgPath.path,
        "assets/mathjax/MathJax.js?delayStartupUntil=configured" )
      document.getElementsByTagName("head")[0].appendChild(script)
    finally
      return
    return

  # Doesn't really work....
  unloadMathJax: ->
    script = document.getElementById("mathjax-script")
    if script? then script.remove()
    if MathJax? then MathJax = null

  # NOT working!
  reconfigureMathJax: ->
    script = document.getElementById("mathjax-script")
    if script?
      @unloadMathJax()
    @loadMathJax()

  #
  ##
  ## Process DOM elements for LaTeX equations with MathJax
  ##
  ## @param domElements An array of DOM elements to be processed by MathJax. See
  ##   [element](https://developer.mozilla.org/en-US/docs/Web/API/element) for
  ##   details on DOM elements.
  #
  #
  # Modified for Ever-Notedown: svg2png, calblack, etc.
  #
  mathProcessor: (domElements, domFragment, bindings, filePath, callback) ->
    if MathJax?
      MathJax.Hub.Queue ["Typeset", MathJax.Hub, domElements]
      MathJax.Hub.Queue () =>
        svg2pngHelper.svg2png domFragment, filePath
      #MathJax.Hub.Queue () =>
      #  console.log domFragment.querySelectorAll('.math')
      MathJax.Hub.Queue () =>
        callback null, domFragment, bindings
    return

  #
  # For Ever-Notedown, takes html as input
  #
  mathRenderer: (html, filePath, callback) ->
    if MathJax?
      template = document.createElement('template')
      template.innerHTML = html
      domFragment = template.content.cloneNode(true)
      elms = [].slice.call(domFragment.querySelectorAll('.math'))
      MathJax.Hub.Queue ["Typeset", MathJax.Hub, elms]
      MathJax.Hub.Queue () =>
        # SVG->PNG?
        svg2pngHelper.svg2png domFragment, filePath
      MathJax.Hub.Queue () =>
        renderedContent = document.createElement('template')
        renderedContent.appendChild(domFragment.cloneNode(true))
        callback null, renderedContent.innerHTML
    return

  #
  # For EVND
  #
  loadCustomMacros: loadCustomMacros

  macroPaths: macroPaths

  macrosToCSONString: (macros) ->
    return "" unless macros?
    CSON ?= require 'season'
    return CSON.stringify(macros, null, 4)

#
## Configure MathJax environment. Similar to the TeX-AMS_HTML configuration with
## a few unnessesary features stripped away
#
# Modified for Ever-Notedown: use SVG, Macros, etc.
#   TODO: More config options?
#
configureMathJax = ->
  macros = loadCustomMacros() ? defaultMacros

  MathJax.Hub.Config {
    #jax: ["input/TeX","output/HTML-CSS"]
    jax: ["input/TeX", "output/SVG"]
    extensions: []
    TeX: {
      #equationNumbers: { autoNumber: "AMS" }
      extensions: ["AMSmath.js","AMSsymbols.js","noErrors.js","noUndefined.js"]
      Macros: macros
    }
    SVG: {
      font: "Asana-Math"
      undefinedFamily: ["STIXGeneral", 'Arial Unicode MS', "serif"]
      linebreaks:
        automatic: false
        width: "75%"
    }
    messageStyle: "none"
    showMathMenu: false
  }
  MathJax.Hub.Configured()
  return

