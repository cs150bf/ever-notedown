# Used some code from https://github.com/atom/markdown-preview/blob/9ff76ad3f6407a0fb68163a538c6d460280a1718/lib/main.coffee
#
# Reproduced license info:
#  Copyright (c) 2014 GitHub Inc.
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
path = require 'path'

{CompositeDisposable, Disposable} = require 'atom'
{File, Directory} = require 'atom'
{$} = require 'atom-space-pen-views'
TextEditor = null
CSON = null
chartsHelper = null
evernoteHelper = null # delay require './evernote-helper'
storage = null # delay require './storage-manager'
noteHelper = null # require './note-helper'
mathjaxHelper = null
utils = null
fenceNameForScope = null #require './extension-helper'
fs = null #require 'fs-plus'
git = null # requrie 'git-utils'
cheerio = null # require 'cheerio'
clipboard = null
_ = null # require 'underscore-plus'


# used some code from atom/markdown-preview/lib/main.coffee
url = null #require 'url'

NoteManagerView = null # Defer until used
EVNDPreviewView = null # Defer until used
EVNDView = null # Defer until used
NoteInfoView = null
ConfirmDialog = null
InfoDialog = null
SearchNoteView = null
SearchResultListView = null
renderer = null # Defer until used

isNoteInfoView = (object) ->
  NoteInfoView ?= require './info-dialog'
  object instanceof NoteInfoView

isNoteManagerView = (object) ->
  NoteManagerView ?= require './note-manager'
  object instanceof NoteManagerView

isEVNDView = (object) ->
  EVNDView ?= require './ever-notedown-view'
  object instanceof EVNDView

createEVNDPreviewView = (state) ->
  EVNDPreviewView ?= require './ever-notedown-preview-view'
  new EVNDPreviewView(state)

isEVNDPreviewView = (object) ->
  EVNDPreviewView ?= require './ever-notedown-preview-view'
  object instanceof EVNDPreviewView

atom.deserializers.add
  name: 'EVNDPreviewView'
  deserialize: (state) ->
    createEVNDPreviewView(state) if state.constructor is Object

defaultGitPath = path.join atom.getConfigDirPath(), 'evnd/'

themeDict =
  "Default": "assets/themes/default/style.css"
  "Default 2": "assets/themes/default2/style.css"
  "Default 3": "assets/themes/default3/style.css"
  "Atom": "assets/themes/atom/style.css"
  "Custom 1": "assets/themes/custom1/style.css"
  "Custom 2": "assets/themes/custom2/style.css"

syntaxThemeDict =
  "Default": "assets/themes-syntax/default/style.css"
  "Default 2": "assets/themes-syntax/default2/style.css"
  "One Light": "assets/themes-syntax/one-light/style.css"
  "One Dark": "assets/themes-syntax/one-dark/style.css"
  "Solarized Light": "assets/themes-syntax/solarized-light/style.css"
  "Solarized Dark": "assets/themes-syntax/solarized-dark/style.css"
  "Github": "assets/themes-syntax/github/style.css"
  "Chester": "assets/themes-syntax/chester/style.css"
  "Tomorrow": "assets/themes-syntax/tomorrow/style.css"
  "IDLE": "assets/themes-syntax/IDLE/style.css"
  "Seti Syntax": "assets/themes-syntax/seti-syntax/style.css"
  "Cobalt": "assets/themes-syntax/cobalt/style.css"
  "Monokai": "assets/themes-syntax/monokai/style.css"
  "Serpia": "assets/themes-syntax/serpia/style.css"
  "Custom 1": "assets/themes-syntax/custom1/style.css"
  "Custom 2": "assets/themes-syntax/custom2/style.css"

noteTemplateDict =
  "Default": "assets/templates/default.markdown"
  "Lecture Notes": "assets/templates/lecture_notes.markdown"
  "None": ""
  "Custom 1": "assets/templates/custom1.markdown"
  "Custom 2": "assets/templates/custom2.markdown"

evndGrammarList = [
  'source.gfm'
  'source.litcoffee'
  'text.markdown.evnd.mathjax.source.litcoffee.inline.html'
  'text.markdown.evnd.mathjax.source.gfm.inline.html'
  'text.markdown.evnd.source.gfm.inline.html'
]

# Global variables?
window.evnd =
  evndView: null
  editor: null
  searchNoteView: null
  searchResultListView: null
  noteManagerView: null
  cssTheme: ""
  cssCode: ""
  template: ""
  noteIndex: null
  storageManager: null
  enHelper: null
  init: null
  chartsLibsLoaded: null
  gitPath: null
  gitPathSymlink: null
  svgCollections: null
  newNoteDisposables: null

module.exports =
  config:
    showPath:
      type: 'boolean'
      default: true
      order: 1
    gitPath:
      type: 'string'
      default: defaultGitPath
      description: 'Default location to store your ever-notedown notes, GIT-backed'
      order: 2
    gitPathSymlink:
      type: 'boolean'
      default: true
      description: 'Check this if the specified gitPath is a symbolic link'
      order: 3
    openNoteInEvernoteAuto:
      title: 'Open Note in Evernote'
      type: 'boolean'
      default: false
      description: "Automatically open note in Evernote client after note creation or modification"
      order: 4
    pulledContentInSplitPane:
      type: 'boolean'
      default: false
      description: "After loading note content from the Evernote client database, put the loaded content in a separate pane as a new file? (default: false, will overwrite old note content)."
      order: 5
    sortBy:
      type: 'string'
      default: 'Title'
      enum: ['default', 'Title', 'Notebook', 'Creation Time', 'Modification Time']
      description: 'Default sorting is the order in which the notes are displayed in the drop-down note browser'
      order: 6
    convertHexNCR2String:
      title: 'Convert Hex NCR to String'
      type: 'boolean'
      default: true
      description: 'When importing (or pulling) from Evernote, convert hex NCR represented Unicode characters to UTF8 string'
      order: 7
    defaultFormat:
      type: 'string'
      default: 'Markdown'
      enum: ['Text', 'Markdown', 'HTML']
      description: '(Please choose only "Markdown" for now...)'
      order: 7
    codeSnippet:
      type: 'boolean'
      default: true
      description: 'Render selected content as a fenced code block'
      order: 8
    toc:
      title: 'TOC'
      type: 'boolean'
      default: true
      description: 'Enable Table of Contents generation ([TOC])'
      order: 9
    checkbox:
      type: 'boolean'
      default: true
      description: 'Render ([ ], [x]) as checkboxes everywhere'
      order: 10
    footnote:
      type: 'boolean'
      default: true
      description: 'Parse footnotes in MMD style...([^text] for reference, [^text]: for definition)'
      order: 11
    mathjax:
      type: 'boolean'
      default: true
      description: 'Enable MathJax processing'
      order: 12
    mathjaxOutput:
      type: 'string'
      default: 'SVG'
      enum: ['SVG'] #['SVG', 'HTML/CSS']
      order: 13
    mathjaxCustomMacros:
      type: 'string'
      default: "Physical Sciences"
      enum: [
        "None",
        "Default",
        "Physical Sciences",
        "Math",
        "Custom 1",
        "Custom 2"
      ]
      order: 14
      description: 'Use custom defined macros (~/.atom/packages/ever-notdown/assets/mathjax/macros/custom.json) for MathJax rendering. (After making changes, please use "View -> Reload" for the change to take effect.)'
    breakOnSingleNewline:
      type: 'boolean'
      default: false
      description: 'Markdown rendering option'
      order: 15
    smartyPants:
      type: 'boolean'
      default: false
      description: 'Use "smart" typograhic punctuation for things like quotes and dashes.'
      order: 16
    noteTemplate:
      type: 'string'
      default: 'Default'
      description: 'Template for creating new note'
      enum: [
        "Default",
        "Lecture Notes",
        "Custom 1",
        "Custom 2",
        "None"
      ]
      order: 17
    theme:
      type: 'string'
      default: "Default"
      enum: [
        "Default",
        "Default 2",
        "Default 3",
        "Atom",
        "Custom 1",
        "Custom 2"
      ]
      order: 18
    syntaxTheme:
      type: 'string'
      default: "Default"
      enum: [
        "Default",
        "Default 2",
        "One Light",
        "One Dark",
        "Solarized Light",
        "Solarized Dark",
        "Github",
        "Chester",
        "Tomorrow",
        "IDLE",
        "Seti Syntax",
        "Cobalt",
        "Monokai",
        "Serpia",
        "Custom 1",
        "Custom 2"
      ]
      order: 19
    liveUpdate:
      type: 'boolean'
      default: true
      description: 'For Markdown Preview'
      order: 20
    openPreviewInSplitPane:
      type: 'boolean'
      default: true
      order: 21
    syncScroll:
      type: 'boolean'
      default: true
      description: 'Sync scrolling between the editor and the preview pane'
      order: 22
    grammars:
      type: 'array'
      default: [
        'source.gfm'
        'source.litcoffee'
        'text.html.basic'
        'text.plain'
        'text.plain.null-grammar'
        'text.markdown.evnd.source.gfm.inline.html'
        'text.markdown.evnd.mathjax.source.gfm.inline.html'
        'text.markdown.evnd.mathjax.source.litcoffee.inline.html'
      ]
      order: 23
    evndGrammar:
      title: 'Extended grammar for syntax highlighting markdown files in editor'
      type: 'string'
      order: 24
      enum: [
        'Extended source.litcoffee'
        'Extended source.gfm'
      ]
      default: 'Extended source.gfm'
      description: 'Support extra syntax highlighting, eg: inline HTML, MathJax equations, etc.'


  subscriptions: null

  # TODO: This CSS matter... should we just go for "getMarkdownPreviewCSS"?

  activate: (state) ->
    return unless process.platform is 'darwin' # OSX Only!

    window.evnd.init = true
    window.evnd.chartsLibsLoaded = false

    #console.log atom.config.get('ever-notedown.gitPath')
    @loadJSON (newNoteIndex) =>
      window.evnd.noteIndex = newNoteIndex

    mathjax = atom.config.get('ever-notedown.mathjax')
    if mathjax
      mathjaxHelper = require('./mathjax-helper')
      mathjaxHelper.loadMathJax()

    # Events subscribed to in atom's system can be easily
    # cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register commands
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:toggle': =>
        @toggle()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:toggle-note-list': =>
        @createNoteManagerView(state).toggle()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:selection-to-evernote', =>
        @sel2Evernote()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:file-to-evernote', =>
        @file2Evernote()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:pull-current-note-from-evernote', =>
        @pullFromEvernote()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:import-note-from-evernote', =>
        @showImportNotePanel()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:new-note', =>
        @openNewNote()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:open-config', =>
        @openConfig()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:open-help-document', =>
        @openHelpDoc()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:markdown-quick-ref', =>
        @openMarkdownQuickRef()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:mathjax-quick-ref', =>
        @openMathJaxQuickRef()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:notes-for-developers', =>
        @openDevNotes()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:toggle-preview': =>
        @togglePreview()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:copy-rendered-html': =>
        @copyHtml()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:save-rendered-html': =>
        @saveHtml()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:toggle-break-on-single-newline': =>
        keyPath = 'ever-notedown.breakOnSingleNewline'
        atom.config.set(keyPath, not atom.config.get(keyPath))

    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:view-current-note-template': =>
        @openNewNote()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:edit-note-template-custom1': =>
        @editCustomTemplate('Custom 1')
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:edit-note-template-custom2': =>
        @editCustomTemplate('Custom 2')
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:view-current-theme-css': =>
        @viewThemeCSS()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:edit-theme-custom1': =>
        @editCustomThemeCSS('Custom 1')
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:edit-theme-custom2': =>
        @editCustomThemeCSS('Custom 2')
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:view-current-syntax-theme-css': =>
        @viewSyntaxThemeCSS()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:edit-syntax-theme-custom1': =>
        @editCustomSyntaxThemeCSS('Custom 1')
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:edit-syntax-theme-custom2': =>
        @editCustomSyntaxThemeCSS('Custom 2')
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:view-mathjax-macros': =>
        @viewMathJaxMacros()
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:edit-macros-custom1': =>
        @editCustomMacros('Custom 1')
    @subscriptions.add atom.commands.add 'atom-workspace',
      'ever-notedown:edit-macros-custom2': =>
        @editCustomMacros('Custom 2')

    @subscriptions.add atom.commands.add 'atom-text-editor', 'drop': (event) =>
      #console.log 'Dropping item!'
      @onDrop(event)

    @subscriptions.add atom.commands.add 'atom-text-editor',
      'core:paste': (event) =>
        #console.log "Pasting stuff!"
        event.stopPropagation()
        @pasteImage()

    @subscriptions.add atom.commands.add 'atom-text-editor',
      'ever-notedown:bold-text': =>
        @boldText()
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'ever-notedown:emphasis-text': =>
        @emphasisText()
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'ever-notedown:underline-text': =>
        @underlineText()
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'ever-notedown:highlight-text': =>
        @highlightText()
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'ever-notedown:strikethrough-text': =>
        @strikeThroughText()
    @subscriptions.add atom.commands.add 'atom-text-editor',
      'ever-notedown:blockquote': =>
        @blockquote()

    @subscriptions.add atom.workspace.observePaneItems (item) =>
      if isEVNDPreviewView(item)
        item.disposables.add item.onDidClickButtonEvernote (editor, previewView) =>
          @file2Evernote(editor, previewView)
        item.disposables.add item.onDidClickButtonPull (filePath, previewView) =>
          @pullFromEvernote(null, filePath, previewView)
        item.disposables.add item.onDidClickButtonNewNote =>
          @openNewNote()
        item.disposables.add item.onDidClickButtonHome =>
          @toggle()
        item.disposables.add item.onDidClickButtonEye (filePath, previewView) =>
          @openNoteInEvernote(null, filePath, previewView)
        item.disposables.add item.onDidClickButtonInfo (note) =>
          @confirmedNoteItem({note: note})
        item.disposables.add item.onDidClickButtonHTML (note) =>
          @getNoteHTML({note: note})
        item.disposables.add item.onDidClickButtonENML (note) =>
          @getNoteENML({note: note})
        item.disposables.add item.onDidClickButtonFolder (notePath) =>
          @openFinder(notePath)
        @subscriptions.add item.disposables


    previewFile = @previewFile.bind(this)
    @subscriptions.add atom.commands.add '.tree-view .file .name[data-name$=\\.markdown]',
      'ever-notedown:preview-file', previewFile
    @subscriptions.add atom.commands.add '.tree-view .file .name[data-name$=\\.md]',
      'ever-notedown:preview-file', previewFile
    @subscriptions.add atom.commands.add '.tree-view .file .name[data-name$=\\.mdown]',
      'ever-notedown:preview-file', previewFile
    @subscriptions.add atom.commands.add '.tree-view .file .name[data-name$=\\.mkd]',
      'ever-notedown:preview-file', previewFile
    @subscriptions.add atom.commands.add '.tree-view .file .name[data-name$=\\.mkdown]',
      'ever-notedown:preview-file', previewFile
    @subscriptions.add atom.commands.add '.tree-view .file .name[data-name$=\\.ron]',
      'ever-notedown:preview-file', previewFile
    @subscriptions.add atom.commands.add '.tree-view .file .name[data-name$=\\.txt]',
      'ever-notedown:preview-file', previewFile

    atom.workspace.addOpener (uriToOpen) ->
      try
        {protocol, host, pathname} = url.parse(uriToOpen)
      catch error
        return

      return unless protocol is 'ever-notedown-preview:'

      try
        pathname = decodeURI(pathname) if pathname
      catch error
        return

      if host is 'editor'
        createEVNDPreviewView(editorId: pathname.substring(1))
      else
        createEVNDPreviewView(filePath: pathname)

  deactivate: ->
    # TODO: manage storage?
    #if atom.config.get('ever-notedown.mathjax') then @removeMathJaxGrammar()
    @removeEVNDGrammar()
    window.evnd.noteIndex?.update()
    window.evnd.noteManagerView?.destroy?()
    window.evnd.searchResultListView?.destroy?()
    window.evnd.evndView?.destroy()
    @subscriptions.dispose()
    for k, v of window.evnd
      if k in ["cssTheme", "cssCode", "template"]
        window.evnd[k] = ""
      else
        window.evnd[k] = null

  serialize: ->
    noteManagerViewState: window.evnd.noteManagerView?.serialize()

  toggle: ->
    if window.evnd.init then @loadModule()

    unless window.evnd.evndView?
      EVNDView ?= require './ever-notedown-view'
      newEVNDView = new EVNDView(@)
      newEVNDView.disposables.add newEVNDView.onDidClickButtonImportNote =>
        @showImportNotePanel()
      newEVNDView.disposables.add newEVNDView.onDidClickButtonNewNote =>
        newEVNDView.hide()
        @openNewNote()
      newEVNDView.disposables.add newEVNDView.onDidClickButtonDeleteNote =>
        @deleteNote()
      newEVNDView.disposables.add newEVNDView.onDidClickButtonNoteList =>
        @createNoteManagerView(@).toggle()
      newEVNDView.disposables.add newEVNDView.onDidClickButtonOpenConfig =>
        @openConfig()
      newEVNDView.disposables.add newEVNDView.onDidClickButtonOpenHelp =>
        @openHelpDoc()
      newEVNDView.disposables.add newEVNDView.onDidClickButtonOpenNote (note) =>
        newEVNDView.hide()
        @openNote(note)
      newEVNDView.disposables.add newEVNDView.onDidClickButtonOpenFinder (notePath) =>
        @openFinder(notePath)
      newEVNDView.disposables.add newEVNDView.onDidClickButtonOpenInfo (note) =>
        @confirmedNoteItem({note: note})
      newEVNDView.disposables.add newEVNDView.onDidClickButtonDeleteNote (note) =>
        @deleteNote {note:note}, (deleted) =>
          if deleted then newEVNDView.refresh()
      newEVNDView.disposables.add newEVNDView.onDidClickButtonExportNote () =>
        @saveHtml()
      @subscriptions.add newEVNDView.disposables
      window.evnd.evndView = newEVNDView

    window.evnd.evndView.toggle(@)

  #
  # Based on the official Atom Markdown Preview package
  # Updated Nov 15, 2015
  # TODO: move these functions to `ever-notedown-preview-view.coffee`
  #
  getTextEditorStyles: ->
    textEditorStyles = document.createElement("atom-styles")
    textEditorStyles.initialize(atom.styles)
    textEditorStyles.setAttribute "context", "atom-text-editor"
    document.body.appendChild textEditorStyles

    # Extract style elements content
    Array.prototype.slice.apply(textEditorStyles.childNodes).map (styleElement) ->
      styleElement.innerText

  # TODO: remove the particular {overflow-y: scroll;}?
  getMarkdownPreviewCSS: ->
    return @markdownPreviewCSS if @markdownPreviewCSS
    markdowPreviewRules = []
    ruleRegExp = /\.ever-notedown-preview/
    cssUrlRefExp = /url\(atom:\/\/ever-notedown\/assets\/(.*)\)/

    for stylesheet in document.styleSheets
      if stylesheet.rules?
        for rule in stylesheet.rules
          # We only need `.ever-notedown-preview` css
          markdowPreviewRules.push(rule.cssText) if rule.selectorText?.match(ruleRegExp)?

    @markdownPreviewCSS = markdowPreviewRules
      .concat(@getTextEditorStyles())
      .join('\n')
      .replace(/([^\.])atom-text-editor/g, '$1pre.editor-colors') # <atom-text-editor> are now <pre>
      .replace(/:host/g, '.host') # Remove shadow-dom :host selector causing problem on FF
      .replace cssUrlRefExp, (match, assetsName, offset, string) -> # base64 encode assets
        assetPath = path.join __dirname, '../assets', assetsName
        originalData = fs.readFileSync assetPath, 'binary'
        base64Data = new Buffer(originalData, 'binary').toString('base64')
        "url('data:image/jpeg;base64,#{base64Data}')"
    @markdownPreviewCSS

  editCustomSyntaxThemeCSS: (syntaxThemeName) ->
    return unless syntaxThemeName.indexOf('Custom') > -1 and syntaxThemeDict[syntaxThemeName]?
    if window.evnd.init then @loadModule()
    evndPkgPath = atom.packages.resolvePackagePath('ever-notedown')
    syntaxThemeFilePath = path.join evndPkgPath, syntaxThemeDict[syntaxThemeName]
    atom.workspace.open(syntaxThemeFilePath)

  viewSyntaxThemeCSS: ->
    @loadCSS() unless window.evnd.cssCode?
    syntaxThemeCSS = window.evnd.cssCode
    atom.workspace.open('').then (editor) =>
      editor.setText(syntaxThemeCSS)
      cssGrammar = atom.grammars.grammarForScopeName('source.css')
      if cssGrammar then editor.setGrammar(cssGrammar)

  editCustomThemeCSS: (themeName) ->
    return unless themeName?.indexOf('Custom') > -1 and themeDict[themeName]?
    if window.evnd.init then @loadModule()
    evndPkgPath = atom.packages.resolvePackagePath('ever-notedown')
    themeFilePath = path.join evndPkgPath, themeDict[themeName]
    atom.workspace.open(themeFilePath)

  viewThemeCSS: ->
    @loadCSS() unless window.evnd.cssTheme?
    themeCSS = window.evnd.cssTheme
    atom.workspace.open('').then (editor) =>
      editor.setText(themeCSS)
      cssGrammar = atom.grammars.grammarForScopeName('source.css')
      if cssGrammar then editor.setGrammar(cssGrammar)

  loadCSS: (themeName, syntaxThemeName) ->
    # Load defined CSS themes
    themeName ?= atom.config.get('ever-notedown.theme')
    themeFileName = themeDict[themeName]
    syntaxThemeName ?= atom.config.get('ever-notedown.syntaxTheme')
    syntaxThemeFileName = syntaxThemeDict[syntaxThemeName]
    return unless themeFileName? and syntaxThemeFileName?
    evndPkgPath = atom.packages.resolvePackagePath('ever-notedown')
    themeFilePath = path.join evndPkgPath, themeFileName
    window.evnd.cssTheme = fs.readFileSync(themeFilePath, 'utf8')
    syntaxThemeFilePath = path.join evndPkgPath, syntaxThemeFileName
    window.evnd.cssCode = fs.readFileSync(syntaxThemeFilePath, 'utf8')
    themePath = path.join evndPkgPath, "styles/theme.css"
    themeCSS = window.evnd.cssTheme + window.evnd.cssCode
    fs.writeFileSync(themePath, themeCSS, 'utf8')
    @reloadTheme(themeCSS, {sourcePath: themePath})
    return themeCSS

  reloadTheme: (source, params) ->
    return unless source
    #console.log "Reloading css style sheet... #{params.sourcePath}"
    sourcePath = params?.sourcePath
    sourcePath ?= path.join atom.packages.resolvePackagePath('ever-notedown'), 'styles/theme.css'
    priority = params?.priority
    styleElements = atom.styles.getStyleElements()
    for styleElement in styleElements
      if styleElement.sourcePath is sourcePath
        priority ?= styleElement.priority ? 0
        atom.styles.removeStyleElement(styleElement)
        #break
    params.priority = priority
    atom.styles.addStyleSheet(source, params)
    @markdownPreviewCSS = null

  removeTheme: (sourcePath) ->
    return unless sourcePath
    #console.log "Removing css style sheet... #{sourcePath}"
    styleElements = atom.styles.getStyleElements()
    for styleElement in styleElements
      if styleElement.sourcePath is sourcePath
        atom.styles.removeStyleElement(styleElement)
        break

  viewTemplate: ->
    if window.evnd.init then @loadModule()
    template = window.evnd.template ? @loadTemplate()
    atom.workspace.open('').then (editor) =>
      editor.setText(template)

  editCustomTemplate: (templateName) ->
    return unless templateName?.indexOf('Custom') > -1 and
        noteTemplateDict[templateName]?
    if window.evnd.init then @loadModule()
    evndPkgPath = atom.packages.resolvePackagePath('ever-notedown')
    templateFilePath = path.join evndPkgPath, noteTemplateDict[templateName]
    atom.workspace.open templateFilePath, {searchAllPanes: true}

  loadTemplate: (templateName) ->
    evndPkgPath = atom.packages.resolvePackagePath('ever-notedown')
    templateName ?= atom.config.get('ever-notedown.noteTemplate')
    if templateName is "None"
      window.evnd.template = ""
    else
      templateFilePath = path.join evndPkgPath, noteTemplateDict[templateName]
      window.evnd.template = fs.readFileSync(templateFilePath, 'utf8')
    return window.evnd.template

  viewMathJaxMacros: ->
    if window.evnd.init then @loadModule()
    unless atom.config.get('ever-notedown.mathjax')
      window.alert "MathJax is not enabled currently!"
      return
    mathjaxHelper ?= require './mathjax-helper'
    console.log mathjaxHelper
    macros = mathjaxHelper.loadCustomMacros()
    console.log macros
    atom.workspace.open('').then (editor) =>
      editor.setText(mathjaxHelper.macrosToCSONString(macros))
      grammar = atom.grammars.grammarForScopeName('source.coffee')
      if grammar? then editor.setGrammar(grammar)

  editCustomMacros: (macroName) ->
    if window.evnd.init then @loadModule()
    mathjaxHelper ?= require './mathjax-helper'
    return unless macroName?.indexOf('Custom') > -1 and
      mathjaxHelper.macroPaths[macroName]?
    atom.workspace.open(mathjaxHelper.macroPaths[macroName])

  getGitDir: (gitPath, gitPathSymlink) ->
    gitPath ?= atom.config.get('ever-notedown.gitPath')
    gitPathSymlink ?= atom.config.get('ever-notedown.gitPathSymlink')
    if window.evnd.storageManager?.gitDir? and
        window.evnd.storageManager.gitPath is gitPath and
        window.evnd.storageManager.gitPathSymlink is gitPathSymlink
      return window.evnd.storageManager?.gitDir
    gitDir = new Directory(gitPath, gitPathSymlink)
    return gitDir

  getRealGitPath: ->
    gitDir = @getGitDir()
    return gitDir.getRealPathSync()

  loadGitRepo: (gitPath, gitPathSymlink, callback) ->
    gitPath ?= atom.config.get('ever-notedown.gitPath')
    gitPathSymlink ?= atom.config.get('ever-notedown.gitPathSymlink')
    #console.log "Git Path: " + gitPath
    storage ?= require './storage-manager'
    gitDir = @getGitDir(gitPath, gitPathSymlink)

    loadGitRepoNormal = =>
      if window.evnd.storageManager?.gitPath is gitPath and
          window.evnd.storageManager?.gitPathSymlink is gitPathSymlink and
          window.evnd.storageManager?.gitDir?.existsSync()
        if window.evnd.storageManager.gitRepo is null
          window.evnd.storageManager.initRepo () =>
            callback(window.evnd.storageManager)
        else
          callback(window.evnd.storageManager)
      else
        storageOptions =
          gitPath: gitPath
          gitPathSymlink: gitPathSymlink
          gitRepo: null
          gitDir: gitDir
        window.evnd.storageManager ?= new storage.StorageManager(storageOptions)
        callback(window.evnd.storageManager)

    if not gitDir.existsSync()
      dmsg = "The current GIT directory #{gitPath} "
      if gitPathSymlink then dmsg += "(symolic link) "
      dmsg += "for EVND doesn't exist!"
      atom.confirm
        message: dmsg
        buttons:
          "mkdir": =>
            @initGitDir gitDir, () =>
              loadGitRepoNormal()
          "Open Settings": =>
            @openConfig()
            callback(null)
      return
    else
      loadGitRepoNormal()

  initGitDir: (gitDir, callback) ->
    gitDir ?= @getGitDir()
    if gitDir?.existsSync()
      if callback? then callback()
      return
    atom.confirm
      message: "Will create directory at #{gitDir.getRealPathSync()}"
      buttons:
        "Confirm": =>
          fs ?= require 'fs-plus'
          fs.makeTreeSync(gitDir.getRealPathSync())
          if callback? then callback()
        "Cancel": =>
          if callback? then callback()
          return

  initJSONFile: (jsonFile, callback) ->
    @initGitDir null, () =>
      jsonFile.write("{}")
      if callback? then callback()

  loadJSON: (callback) ->
    path ?= require 'path'
    jsonPath = path.join(@getRealGitPath(), "index.json")
    jsonFile = new File(jsonPath)

    loadJSONNormal = =>
      jsonFile.read().then (jsonString) =>
        jobj = JSON.parse(jsonString)
        noteHelper ?= require './note-helper'
        options =
          jsonOBJ: jobj
          absfilename: jsonPath
          file: jsonFile
        callback(new noteHelper.NoteIndex(options))

    if jsonFile.existsSync()
      loadJSONNormal()
    else
      @initJSONFile jsonFile, () =>
        loadJSONNormal()

  openConfig: ->
    options =
      searchAllPanes: true
    if atom.config.get('ever-notedown.openPreviewInSplitPane')
      options.split = "left"
    atom.workspace.open 'atom://config/packages', options

  openHelpDoc: ->
    if window.evnd.init then @loadModule()
    pathToHelpDoc = path.join __dirname, '../docs/help.md'
    options =
      searchAllPanes: true
    if atom.config.get('ever-notedown.openPreviewInSplitPane')
      options.split = "left"
    atom.workspace.open(pathToHelpDoc, options).then (editor) =>
      @addPreviewForEditor(editor)

  openMarkdownQuickRef: ->
    if window.evnd.init then @loadModule()
    window.alert "Sorry, this function has not yet been implemented... :-/"

  openMathJaxQuickRef: ->
    if window.evnd.init then @loadModule()
    window.alert "Sorry, this function has not yet been implemented... :-/"

  openDevNotes: ->
    if window.evnd.init then @loadModule()
    pathToDevNotes = path.join __dirname, '../docs/dev_notes.md'
    options =
      searchAllPanes: true
    if atom.config.get('ever-notedown.openPreviewInSplitPane')
      options.split = "left"
    atom.workspace.open(pathToDevNotes, options).then (editor) =>
      @addPreviewForEditor(editor)

  #
  # toggle the search panel (similar to find-and-replace)
  #
  showImportNotePanel: ->
    if window.evnd.init then @loadModule()
    if window.evnd?.searchNoteView?.panel?
      window.evnd.searchNoteView.show()
    else
      SearchNoteView ?= require './search-note-view'
      window.evnd.searchNoteView = new SearchNoteView()
      window.evnd.searchNoteView.show()
      @subscriptions.add window.evnd.searchNoteView.onDidSearchWithString ({queryString, noteLink}={}) =>
        @searchNotes({queryString:queryString, noteLink:noteLink})

  #
  # Open note list (Scroll List view)
  #
  createNoteManagerView: (state) ->
    if window.evnd.init then @loadModule()
    unless window.evnd.noteManagerView?
      NoteManagerView ?= require './note-manager-view'
      window.evnd.noteManagerView = new NoteManagerView()
      @subscriptions.add window.evnd.noteManagerView.onDidConfirmNote (noteID) =>
        @confirmedNoteItem({noteID: noteID})
    window.evnd.noteManagerView

  #
  # Import from Evernote?
  #
  searchNotes: ({queryString, noteLink}={}) ->
    if window.evnd.init then @loadModule()
    reg0 = /^https\:\/\/www\.evernote\.com\/shard\/([^\s\/]+)\/[^\s\/]+\/([^\s\/]+)\/([^\s\/]+)\/$/i
    if noteLink? and reg0.test(noteLink) #noteLink.slice(0, 8) is 'https://'
      matched = reg0.exec(noteLink)
      noteLink = "evernote:///view/#{matched[2]}/#{matched[1]}/#{matched[3]}/#{matched[3]}/"
    evernoteHelper ?= require './evernote-helper'
    window.evnd.enHelper ?= new evernoteHelper.EvernoteHelper()
    window.evnd.enHelper.searchNotes {queryString:queryString, noteLink: noteLink}, (result) =>
      if (not result) or (not result.found) or (result? and _.size(result) < 2)
        window.alert("No results found!")
        return
      else
        SearchResultListView ?= require './search-result-list-view'
        window.evnd.searchResultListView = new SearchResultListView(result)
        window.evnd.searchResultListView.show()
        @subscriptions.add window.evnd.searchResultListView.onDidConfirmSearchResult (noteLink) =>
          @importFromEvernote({noteLink: noteLink})


  handleToEvernoteError: (error, noteOptions) ->
    message = "#{error.message} when trying to send note to Evernote"
    detail = "Note options:\n"
    for k, v of noteOptions
      continue if k in ["rawHTML", "text", "css"]
      detail += "  #{k}: #{JSON.stringify(v)}\n"
    stack = "#{error.stack}\n"
    atom.notifications.addError(message, {stack: stack, detail: detail, dismissable: true})

  # TODO: Handles "code snippet"
  # TODO: use selection.getScreenRange() (for code annotating?)
  #
  sel2Evernote: ->
    if window.evnd.init then @loadModule()

    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    curFilePath = editor.getPath()
    lastSelection = editor.getLastSelection()
    selectionText = lastSelection.getText().toString() #editor.getSelectedText()
    bufferRowRange = lastSelection.getBufferRowRange()
    rowRange = "#L#{(bufferRowRange[0]+1).toString()}-#{(bufferRowRange[1]+1).toString()}"

    if selectionText.trim().length is 0
      window.alert "Nothing selected!"
      return

    # Convert selected text (Markdown) to HTML
    # TODO: if current file is code file (selected text is code snippet), render
    # TODO: renderer, async???
    textContent = selectionText ? "Nothing here"
    parsedInput = utils.parseMetaData(textContent)
    newTitle = parsedInput.title
    newTextContent = parsedInput.content
    tags = parsedInput.tags
    date = parsedInput.date
    notebookName = parsedInput.notebook
    metaText = parsedInput.metaText

    if utils.isMarkdown(curFilePath) or
       editor.getGrammar()?.scopeName in evndGrammarList or
        (utils.isText(curFilePath) and
         atom.config.get('ever-notedown.defaultFormat') is 'Markdown')
      renderOptions = {mathjax: atom.config.get('ever-notedown.mathjax')}
    else if atom.config.get('ever-notedown.codeSnippet')
      if path.basename(curFilePath)?
        newTitle = "Code snippet: #{path.basename(curFilePath)}#{rowRange}"
      scopeName = editor.getGrammar()?.scopeName
      fenceName = if scopeName? then fenceNameForScope(scopeName) else ""
      newTextContent = "```#{fenceName}\n#{newTextContent}\n```\n"
      newTextContent += "\n<br><br>**Source file**: #{curFilePath}  \n"
      newTextContent += "<br>**Clipped Time**: #{utils.getCurrentTimeString()}   \n"
      textContent = metaText + "\n\n" + newTextContent
      renderOptions = {mathjax: false}
    else
      newHtmlContent = null
      noteFormat = "Text"
      tmpCss = null

    if noteFormat is "Text"
      options =
        title: newTitle
        update: false
        text: textContent # This will include MetaData section...
        tags: tags
        notebook: {name: notebookName}
        metaDate: date
        rawHTML: newHtmlContent
        css: tmpCss
        format: noteFormat
        filePath: curFilePath
        renderOptions: renderOptions ? null

      try
        @toEvernote options, null, (curNote) =>
          @openNote(curNote)
      catch error
        @handleToEvernoteError(error, options)

    else
      renderer ?= require './renderer'
      renderer.toHTML newTextContent, renderOptions.mathjax, editor.getPath(),
        parsedInput, editor.getGrammar(), (error, html) =>
          if error
            console.error('Converting Markdown to HTML failed', error)
            return # TODO: notify user
          else
            tmpCss = if (window.evnd.cssTheme? and window.evnd.cssCode?) then (window.evnd.cssTheme + window.evnd.cssCode) else @loadCSS()
            #tmpCss = @getMarkdownPreviewCSS()
            noteFormat = "Markdown"
            newHtmlContent = html

            options =
              title: newTitle
              update: false
              moved: true
              text: textContent # This will include MetaData section...
              tags: tags
              notebook: {name: notebookName}
              metaDate: date
              rawHTML: newHtmlContent
              css: tmpCss
              format: noteFormat
              filePath: curFilePath
              renderOptions: renderOptions ? null

            try
              @toEvernote options, null, (curNote) =>
                @openNote(curNote)
            catch error
              @handleToEvernoteError(error, options)

  file2Evernote: (editor, previewView) ->
    if window.evnd.init then @loadModule()

    if previewView?
      testView = previewView
      editor ?= previewView.editor
    else
      testView ?= atom.workspace.getActivePane().getActiveItem()

    editor ?= atom.workspace.getActiveTextEditor()
    return unless editor? or isEVNDPreviewView(testView)
    # update note in Evernote if current file is already in the EVND git repo
    if editor?
      curFilePath = editor.getPath()
    else
      editorId = parseInt(testView.editorId)
      editor = testView.editor
      curFilePath = testView.filePath
      if editor?
        curFilePath = editor.getPath()
      else if curFilePath?
        editor = atom.workspace.openSync(curFilePath, {searchAllPanes: true})
      return unless curFilePath? and editor?

    unless curFilePath?
      if editor?
        dMsg = "EVND will now try to save it as a new note... please try again later."
        atom.notifications.addWarning("File is not yet saved!", {detail: dMsg, dismissable: true})
        utils.timeOut(1000)
        @saveNewNote(editor)
      else
        window.alert "File not saved! Cannot send to Evernote... please save first."
      return
    #if curFilePath.indexOf(atom.config.get('ever-notedown.gitPath')) > -1
    gitPath0 = @getRealGitPath()
    gitPath1 = atom.config.get('ever-notedown.gitPath')
    if curFilePath.indexOf(gitPath0) > -1 or
        curFilePath.indexOf(gitPath1) > -1
      update = true
      moved = false
      #console.log("Will update this note...")
    else
      update = false
      moved = true
      #console.log("Will create a new note...")

    textContent = editor.getText()
    parsedInput = utils.parseMetaData(textContent)
    newTextContent = parsedInput.content
    newTitle = parsedInput.title
    tags = parsedInput.tags
    date = parsedInput.date
    notebookName = parsedInput.notebook

    # TODO: Fix Async!!!
    if utils.isMarkdown(curFilePath) or
        editor?.getGrammar()?.scopeName in evndGrammarList or
        (utils.isText(curFilePath) and
         atom.config.get('ever-notedown.defaultFormat') is 'Markdown')
      previewView ?= @getPreviewViewForEditor(editor)
      unless previewView?
        @addPreviewForEditor(editor)
        # TODO: notifiy user
        dMsg = "Please check the rendered result in preview pane first!\n"
        dMsg += "Please close this message, and wait until "
        dMsg += "the preview finishes loading before trying again."
        #window.alert(dMsg)
        atom.notifications.addWarning('Content not rendered!', {detail: dMsg, dismissable: true})
        return
      if previewView.loading then utils.timeOut(500)

      html = previewView[0].innerHTML
      # TODO: Need to properly handle CSS selection
      tmpCss = if (window.evnd.cssTheme? and window.evnd.cssCode?) then (window.evnd.cssTheme + window.evnd.cssCode) else window.evnd.loadCSS()
      #tmpCss = @getMarkdownPreviewCSS()
      newHtmlContent = html
      noteFormat = "Markdown"
      # Send resulting HTML to Evernote Application (create a new note or update)
    else if utils.isHTML(curFilePath) or
        editor?.getGrammar()?.scopeName in ['text.html.basic'] or
        (utils.isText(curFilePath) and
          atom.config.get('ever-notedown.defaultFormat') is 'HTML')
      newHtmlContent = newTextContent
      noteFormat = "HTML"
    else # no need to convert
      newHtmlContent = null
      noteFormat = "Text"

    options =
      title: newTitle
      text: textContent # This will include MetaData section...
      tags: tags
      notebook: {name: notebookName}
      metaDate: date
      rawHTML: newHtmlContent
      css: tmpCss
      format: noteFormat
      update: update
      filePath: curFilePath
      renderOptions: {mathjax: atom.config.get('ever-notedown.mathjax')}

    options.moved = moved
    if not moved
      options.path = path.dirname(curFilePath)
      options.fnStem = path.basename(curFilePath, path.extname(curFilePath))

    # Send content to Evernote Application (create a new note or update)
    try
      @toEvernote options, previewView, (curNote) =>
        if options.moved then @openNote(curNote)
    catch error
      @handleToEvernoteError(error, options)

    # TODO: Open the written file (in the default GIT repo)
    # TODO: Async?
    if options.moved
      for editor in atom.workspace.getTextEditors() when editor.getPath() is curFilePath
        @removePreviewForEditor(editor)
    else
      @addPreviewForEditor(editor)

  toEvernote: (options, previewView, callback) ->
    evernoteHelper ?= require './evernote-helper'
    window.evnd.enHelper ?= new evernoteHelper.EvernoteHelper()
    # Send resulting HTML to Evernote Application (create a new note)
    # Note: This function contains an async call (osa)
    #       In the callback function of osa, a global variable should be updated
    # TODO: tags, other implicit info encoding, etc.
    options.update ?= false
    noteHelper ?= require './note-helper'

    if options.update
      curNote = noteHelper.findNote(window.evnd.noteIndex, {title: options.title, fnStem: path.basename(options.filePath, path.extname(options.filePath)), dir: path.basename(path.dirname(options.filePath))})
      if curNote is null
        options.update = false
        #console.log("Note not found in current note index")
        switch options.format
          when "Markdown" then curNote = new noteHelper.MarkdownNote(options)
          when "Text" then curNote = new noteHelper.TextNote(options)
          else curNote = new noteHelper.HTMLNote(options)
      else
        #console.log("Note found in current note index")
        curNote.update window.evnd.storageManager, options
    else
      switch options.format
        when "Markdown" then curNote = new noteHelper.MarkdownNote(options)
        when "Text" then curNote = new noteHelper.TextNote(options)
        else curNote = new noteHelper.HTMLNote(options)
    #console.log("Current Note entity title: " + curNote.title)
    window.evnd.noteIndex.addnote(curNote)

    # TODO: Async call in storage manager
    window.evnd.storageManager.addNote curNote, false, null, () =>
      #console.log("Sending to evernote..." +  utils.getCurrentTimeString())

      unless previewView?
        openNoteOptions =
          searchAllPanes: true
          addPreview: true
        @openNote curNote, openNoteOptions, (editor) =>
          previewView = @getPreviewViewForEditor(editor)

      updateNoteNormal = () =>
        ensyncs = previewView?[0].querySelectorAll('#evernote-syncing') ? []
        for ensync in ensyncs
          ensync?.style.visibility = 'visible'
          ensync?.previousSibling.classList.add('faded')
        window.evnd.enHelper.updateNote curNote, curNote.addAttachments, true, (updateSuccess) =>
          if updateSuccess
            window.evnd.enHelper.getENML curNote, curNote.queryString, (enml) =>
              curNote.update(window.evnd.storageManager, {enml:enml, dontChangeTime:true})
              curNote.lastSyncDate = curNote.enModificationDate
              ensyncs = previewView?[0].querySelectorAll('#evernote-syncing') ? []
              for ensync in ensyncs
                ensync?.style.visibility = 'hidden'
                ensync?.previousSibling.classList.remove("faded")
                ensync?.parentNode.parentNode.classList.remove("evnd-yellow")
                ensync?.parentNode.parentNode.classList.remove("evnd-red")
              ensyncs = previewView?[0].querySelectorAll('#pull-syncing') ? []
              for ensync in ensyncs
                ensync?.parentNode.parentNode.classList.remove("evnd-yellow")
                ensync?.parentNode.parentNode.classList.remove("evnd-red")
              gitMessage = "Update Evernote note \"#{curNote.title}\" success!\n"
              gitMessage += "#{curNote.summary()}"
              window.evnd.storageManager.addNote curNote, true, gitMessage
              #console.log(gitMessage)
              #window.alert(gitMessage.split(/[\n\r]/g)[0])
              atom.notifications.addSuccess(gitMessage.split(/[\n\r]/g)[0])
          else
            #console.log "Update failed!"
            window.alert "Update failed!"
            ensyncs = previewView?[0].querySelectorAll('#evernote-syncing')
            for ensync in ensyncs
              ensync?.style.visibility = 'hidden'
              ensync?.previousSibling.classList.remove("faded")

      createNoteNormal = () =>
        ensyncs = previewView?[0].querySelectorAll('#evernote-syncing') ? []
        for ensync in ensyncs
          ensync?.style.visibility = 'visible'
          ensync?.previousSibling.classList.add('faded')
        window.evnd.enHelper.createNewNote curNote, (createSuccess) =>
          if createSuccess
            window.evnd.enHelper.getENML curNote, curNote.queryString, (enml) =>
              curNote.update(window.evnd.storageManager, {enml:enml, dontChangeTime:true})
              curNote.lastSyncDate = curNote.enModificationDate ? curNote.enCreationDate
              ensyncs = previewView?[0].querySelectorAll('#evernote-syncing') ? []
              for ensync in ensyncs
                ensync?.style.visibility = 'hidden'
                ensync?.previousSibling.classList.remove("faded")
                ensync?.parentNode.parentNode.classList.remove("evnd-yellow")
                ensync?.parentNode.parentNode.classList.remove("evnd-red")
              ensyncs = previewView?[0].querySelectorAll('#pull-syncing') ? []
              for ensync in ensyncs
                ensync?.parentNode.parentNode.classList.remove("evnd-yellow")
                ensync?.parentNode.parentNode.classList.remove("evnd-red")
              gitMessage = "Create new Evernote note \"#{curNote.title}\" success!\n"
              gitMessage += "#{curNote.summary()}"
              window.evnd.storageManager.addNote curNote, true, gitMessage
              #console.log(gitMessage)
              #window.alert(gitMessage.split(/[\n\r]/g)[0])
              atom.notifications.addSuccess(gitMessage.split(/[\n\r]/g)[0])
          else
            window.alert "Something went wrong when trying to create new note..."
            ensyncs = previewView?[0].querySelectorAll('#evernote-syncing')
            for ensync in ensyncs
              ensync?.style.visibility = 'hidden'
              ensync?.previousSibling.classList.remove("faded")

      saveOnly = () =>
        gitMessage = "Locally updated note \"#{curNote.title}\"\n"
        gitMessage += "#{curNote.summary()}"
        window.evnd.storageManager.addNote curnote. true, gitMessage
        #console.log(gitMessage)
        window.alert(gitMessage.split(/[\n\r]/g)[0])

      if options.update
        window.evnd.enHelper.getNoteInfo curNote, null, (enNoteInfo) =>
          if enNoteInfo?
            #console.log("enNoteInfo: " + JSON.stringify(enNoteInfo, null, 4))
            #console.log("curNote.lastSyncDate: " + utils.enDateToTimeString(curNote.lastSyncDate))
            #console.log("curNote.modificationTime: " + curNote.modificationTime)
            if enNoteInfo.enModificationDate isnt curNote.lastSyncDate
              dMsg = "On the Evernote client side, this note was last modified "
              dMsg += "on #{utils.enDateToTimeString(enNoteInfo.enModificationDate)}. "
              dMsg += "But the last time the local note was in sync with the "
              dMsg += "Evernote client was #{utils.enDateToTimeString(curNote.lastSyncDate)}.\n"
              dMsg += "The local note was modified on #{curNote.modificationTime}.\n"
              dMsg += "If you choose \"Update anyway\", the note content in the "
              dMsg += "Evernote database will be overwritten AFTER the note is "
              dMsg += "exported (you can find the exported note in the EVND folder).\n"
              dMsg += "If you choose \"Save only\", the note content will be "
              dMsg += "saved to the local EVND folder (with GIT commit), but "
              dMsg += "no info will be sent to the Evernote client."
              atom.confirm
                message: "Alert: possible conflicts!"
                detailedMessage: dMsg
                buttons:
                  "Update anyway": -> updateNoteNormal()
                  "Save only": -> saveOnly()
                  "Cancel": -> return #console.log("cancelled update note")
            else
              lastSyncTime = utils.enDateToTimeString(curNote.lastSyncDate)
              tMinStr = utils.timeMin(lastSyncTime, curNote.modificationTime)
              #console.log(tMinStr)
              if tMinStr isnt curNote.modificationTime
                updateNoteNormal()
              else
                window.alert("Note hasn't changed, nothing to update.")
          else # no note info was found
            createNoteNormal()
      else
        createNoteNormal()

      if callback? then callback(curNote)

  openNewNote: (initText, options, callback) ->
    # TODO: Template?
    if window.evnd.init then @loadModule()
    initText ?= window.evnd.template ? @loadTemplate()
    if options?.addPreview?
      addPreview = options.addPreview
      delete options.addPreview
    else
      addPreview = true

    tmpDirPath = @makeNoteDir()
    fs.makeTreeSync(tmpDirPath) unless fs.isDirectorySync(tmpDirPath)
    options ?= {}
    if (not options.split?) and atom.config.get('ever-notedown.openPreviewInSplitPane')
      options.split = 'left'
    atom.workspace.open('', options).then (editor) =>
      if initText then editor.setText(initText)
      editorElement = atom.views.getView(editor)
      window.evnd.newNoteDisposables[editor.id] = atom.commands.add editorElement,
        'core:save': (event) =>
          event.stopPropagation()
          @saveNewNote(editor, tmpDirPath)
      switch atom.config.get('ever-notedown.defaultFormat')
        when 'Text' then scopeName = 'text.plain'
        when 'Markdown' then scopeName = @getMarkdownScopeName()
        when 'HTML' then scopeName = 'text.html.basic'
      grammar = atom.grammars.grammarForScopeName(scopeName)
      if grammar? then editor.setGrammar(grammar)
      if addPreview
        @addPreviewForEditor editor, null, (previewView) =>
          if callback? then callback(editor)
      else if callback?
        callback(editor)

  makeNoteDir: ->
    tmpTimeString = utils.getSanitizedTimeString()
    tmpIndex = tmpTimeString.indexOf('_')
    tmpDirName = if tmpIndex > -1 then tmpTimeString.slice(0, tmpIndex) else tmpTimeString
    gitPath = @getRealGitPath()
    tmpDirPath = path.join gitPath, tmpDirName
    return tmpDirPath

  saveNewNote: (editor, noteDir) ->
    noteDir ?= @makeNoteDir()
    text = editor.getText()
    parsedInput = utils.parseMetaData(text)
    title = parsedInput.title
    textContent = parsedInput.content
    tags = parsedInput.tags
    date = parsedInput.date
    notebookName = parsedInput.notebook
    metaText = parsedInput.metaText
    filePath = path.join noteDir, utils.sanitizeFilename(title.toLowerCase()) + ".markdown"

    if noteFilePath = atom.showSaveDialogSync(filePath)
      options =
        title: title
        text: text # This will include MetaData section...
        tags: tags
        notebook: {name: notebookName}
        metaDate: date
        format: "Markdown"
        filePath: noteFilePath

      fs.writeFileSync(noteFilePath, text)
      window.evnd.newNoteDisposables?[editor.id]?.dispose()
      @removePreviewForEditor(editor)
      editor.getBuffer().setPath(noteFilePath)
      newNote = new noteHelper.MarkdownNote(options)
      editor.save()
      @addPreviewForEditor(editor, newNote)
      gitMessage = "Created new note \"#{title}\" (locally) ...\n"
      gitMessage += "#{newNote.summary()}"
      window.evnd.storageManager.addNote newNote, true, gitMessage
      if atom.config.get('ever-notedown.mathjax')
        @setMathJaxGrammar(editor)
      else
        @setEVNDGrammar(editor)

  openNote: (note, options, callback) ->
    # TODO: What if the current note isn't of format "Markdown"?
    #console.log "Opening note..."
    absPath = note.absPath()
    if options?.addPreview?
      addPreview = options.addPreview
      delete options.addPreview
    else
      addPreview = true
    options ?= {searchAllPanes: true}
    if (not options.split?) and atom.config.get('ever-notedown.openPreviewInSplitPane')
      options.split = 'left'
    atom.workspace.open(absPath, options).then (editor) =>
      switch note.format
        when 'Text' then scopeName = 'text.plain'
        when 'Markdown' then scopeName = @getMarkdownScopeName()
        when 'HTML' then scopeName = 'text.html.basic'
      grammar = atom.grammars.grammarForScopeName(scopeName)
      if grammar? then editor.setGrammar(grammar)
      #console.log "Note opened, now dealing with preview..."
      if addPreview
        @addPreviewForEditor editor, note, (previewView) =>
          if callback? then callback(editor)
      else
        @removePreviewForEditor(editor)
        #console.log "Note and preview opened, now handling callback..."
        if callback? then callback(editor)

  openNoteInEvernote: (noteID, filePath, previewView) ->
    if window.evnd.init then @loadModule()
    if previewView?.note?
      note = previewView.note
    else if previewView?.noteID?
      note = noteHelper.findNote(window.evnd.noteIndex, {id: previewView.noteID})
    else if noteID?
      note = noteHelper.findNote(window.evnd.noteIndex, {id: noteID})
    else if filePath?
      gitPath0 = atom.config.get('ever-notedown.gitPath')
      gitPath1 = @getRealGitPath()
      if filePath.indexOf(gitPath0) > -1 or
          filePath.indexOf(gitPath1) > -1
        fnStem = path.basename(filePath, path.extname(filePath))
        dir = path.basename(path.dirname(filePath))
        note = noteHelper.findNote(window.evnd.noteIndex, {fnStem: fnStem, dir: dir})
      else
        note = null
    else
      note = @searchedOpenedNote()
    unless note?
      window.alert("No opened note found!")
      return
    window.evnd.enHelper ?= new evernoteHelper.EvernoteHelper()
    window.evnd.enHelper.openNote note, () =>
      #console.log "New note opened in Evernote!"
      return

  openFinder: (notePath) ->
    if window.evnd.init then  @loadModule()
    window.evnd.enHelper ?= new evernoteHelper.EvernoteHelper()
    window.evnd.enHelper.openFinder notePath, () =>
      #console.log "Note directory opened in Finder!"
      return

  searchOpenedNote: () ->
    noteHelper ?= require './note-helper'
    gitPath0 = atom.config.get('ever-notedown.gitPath')
    gitPath1 = @getRealGitPath()
    editor = atom.workspace.getActiveTextEditor()
    if editor? and
        (editor.getPath().indexOf(gitPath0) > -1 or
         editor.getPath().indexOf(gitPath1) > -1)
      filePath = editor.getPath()
      fnStem = path.basename(filePath, path.extname(filePath))
      dir = path.basename(path.dirname(filePath))
      note = noteHelper.findNote(window.evnd?.noteIndex, {fnStem: fnStem, dir: dir})
    else
      curView = atom.workspace.getActivePaneItem()
      if isEVNDPreviewView(curView)
        if curView.editor?
          curFilePath = curView.editor.getPath()
        else
          curFilePath = curView.filePath
        if curFilePath? and
            (curFilePath.indexOf(gitPath0) > -1 or
            curFilePath.indexOf(gitPath1) > -1)
          fnStem = path.basename(curFilePath, path.extname(curFilePath))
          dir = path.basename(path.dirname(curFilePath))
          note = noteHelper.findNote(window.evnd?.noteIndex, {fnStem: fnStem, dir: dir})
    return note

  getNoteENML: ({note, noteID}={}) ->
    if window.evnd.init then @loadModule()
    unless note?
      if noteID?
        note = noteHelper.findNote(window.evnd.noteIndex, {id: noteID})
      else
        note = searchOpenedNote()
    return unless note?
    window.evnd.enHelper ?= new evernoteHelper.EvernoteHelper()
    window.evnd.enHelper.getENML note, null, (enml) =>
      if enml?
        tmpDir = note.path
        options = {}
        if atom.config.get('ever-notedown.openPreviewInSplitPane')
          options.split = 'left'
        atom.project.setPaths([tmpDir])
        atom.workspace.open('', options).then (editor) =>
          editor.setText(enml)
          grammar = atom.grammars.grammarForScopeName('text.xml')
          if grammar? then editor.setGrammar(grammar)
        return
      else
        window.alert "Something went wrong and getting ENML failed..."
        return

  getNoteHTML: ({note, noteID}={}) ->
    if window.evnd.init then @loadModule()
    unless note?
      if noteID?
        note = noteHelper.findNote(window.evnd.noteIndex, {id: noteID})
      else
        note = searchOpenedNote()
    return unless note?
    window.evnd.enHelper ?= new evernoteHelper.EvernoteHelper()
    window.evnd.enHelper.getHTML note, null, (html) =>
      if html?
        tmpDir = note.path
        options = {}
        if atom.config.get('ever-notedown.openPreviewInSplitPane')
          options.split = 'left'
        atom.project.setPaths([tmpDir])
        atom.workspace.open('', options).then (editor) =>
          editor.setText(html)
          grammar = atom.grammars.grammarForScopeName('text.html.basic')
          if grammar? then editor.setGrammar(grammar)
        return
      else
        window.alert "Something went wrong and getting HTML failed..."
        return

  confirmedNoteItem: ({note, noteID}={}) ->
    if window.evnd.init then @loadModule()
    unless note?
      if noteID?
        note = noteHelper.findNote(window.evnd.noteIndex, {id: noteID})
      else
        note = searchOpenedNote()
    return unless note?
    window.evnd.enHelper ?= new evernoteHelper.EvernoteHelper()
    window.evnd.enHelper.getNoteInfo note, null, (newNoteInfo) =>
      if newNoteInfo?
        window.evnd.enHelper.getAttachmentsInfo note, newNoteInfo.queryString, (newAttachmentsInfo) =>
          InfoDialog ?= require './info-dialog'
          infoDialog = new InfoDialog()
          infoDialog.addInfo(note, newNoteInfo, newAttachmentsInfo)
          infoDialog.show()
          infoDialog.disposables.add infoDialog.onDidClickDelete (noteID) =>
            @deleteNote({noteID:noteID})
          infoDialog.disposables.add infoDialog.onDidOpenNote (noteID) =>
            note = noteHelper.findNote(window.evnd.noteIndex, {id: noteID})
            @openNote(note)
          infoDialog.disposables.add infoDialog.onDidPullNote (noteID) =>
            @pullFromEvernote(noteID)
          @subscriptions.add infoDialog.disposables
      else
        window.alert("Note info retrieve error! (Maybe this note has not been sent to Evernote? Or it might have already been deleted in Evernote.)")
        @openNote(note)

  deleteNote: ({note, noteID, noteTitle}={}, callback) ->
    if window.evnd.init then @loadModule()
    if not note?
      if noteID?
        note = noteHelper.findNote(window.evnd.noteIndex, {id: noteID})
      else if noteTitle?
        note = noteHelper.findNote(window.evnd.noteIndex, {title: noteTitle})
      else
        note = @searchOpenedNote()
    unless note?
      #console.log "No active note (editor or preview) found!"
      return

    # TODO
    confirmedDeleteNote = (note, callback) ->
      window.evnd.noteIndex?.removeNote(note)
      #console.log "Note #{note.title} deleted..."
      for paneItem in atom.workspace.getPaneItems()
        if paneItem.getPath? and paneItem.getPath() is note.absPath()
          paneItem.destroy()
      if callback? then callback(true)

    atom.confirm
      message: "Confirm: Delete Note \"#{note.title}\"?"
      detailedMessage: "This action will remove note \"#{note.title}\" from note Index, but related files will remain on disk for now."
      buttons:
        "Confirm": => confirmedDeleteNote(note, callback)
        "Cancel": =>
          #console.log "Cancelled deleting note..."
          if callback? then callback(false)

  importFromEvernote: ({noteLink} = {}) ->
    if window.evnd.init then @loadModule()
    return unless noteLink?
    note = noteHelper.findNote(window.evnd.noteIndex, {noteLink: noteLink})
    if note?
      @pullFromEvernote(note.id, note.path, null)
    else # Construct a new note entity
      # TODO: note format? Markdown? HTML?
      window.evnd.enHelper.getNoteInfo null, {noteLink: noteLink}, (noteInfo) =>
        enModificationTimeStr = utils.enDateToTimeString(noteInfo.enModificationDate)
        noteInfo.creationTime = enModificationTimeStr
        noteInfo.modificationTime = enModificationTimeStr
        note = new noteHelper.MarkdownNote(noteInfo)
        enDest = path.join(note.path, note.fnStem) + "_evernote"
        window.evnd.enHelper.retrieveNote noteLink, note.queryString, enDest, () =>
          utils.timeOut(200)
          if not ("#{enDest}.html/" in note.enExportedFiles)
            note.enExportedFiles.push("#{enDest}.html/")
          if not ("#{enDest}.enex" in note.enExportedFiles)
            note.enExportedFiles.push("#{enDest}.enex")
          gitMessage = "About to import Evernote note \"#{note.title}\" ...\n"
          gitMessage += "#{note.summary()}"
          window.evnd.storageManager.addNote note, true, gitMessage
          @pullFromEvernote(note.id, note.path, null)

  pullFromEvernote: (noteID, filePath, previewView) ->
    if window.evnd.init then @loadModule()
    if noteID?
      note = noteHelper.findNote(window.evnd.noteIndex, {id: noteID})
    else if filePath?
      gitPath0 = atom.config.get('ever-notedown.gitPath')
      gitPath1 = @getRealGitPath()
      if filePath.indexOf(gitPath0) or filePath.indexOf(gitPath1)
        fnStem = path.basename(filePath, path.extname(filePath))
        dir = path.basename(path.dirname(filePath))
        note = noteHelper.findNote(window.evnd.noteIndex, {fnStem: fnStem, dir: dir})
    else
      note = @searchedOpenedNote()
    unless note?
      window.alert("No opened note found!")
      return

    pullNoteNormal = (note, options) =>
      window.evnd.enHelper ?= new evernoteHelper.EvernoteHelper()
      window.evnd.enHelper.pullNote note, (updated, textContent, html, newNoteInfo) =>
        #console.log "Note pulled..."
        if not updated
          @openNote note, null, () =>
            window.alert("Nothing unsync'd! Opening note...")
            return
        else
          openNoteOptions = {addPreview: true}
          if options?.newPane or atom.config.get('ever-notedown.pulledContentInSplitPane')
            openNoteOptions.addPreview = false
          @openNote note, options, () =>
            textContent = note.metaTextFromNoteInfo(newNoteInfo) + textContent
            for editor in atom.workspace.getTextEditors() when editor.getPath() is note.absPath()
              oldText = editor.getText()
              if openNoteOptions.addPreview
                editor.setText(textContent)
              else
                openNewNoteOptions = {addPreview:false, split: "right", activatePane: true}
                visibleScreenRowRange = editor.getVisibleRowRange()
                @openNewNote textContent, openNewNoteOptions, (newEditor) =>
                  row1 = visibleScreenRowRange[0]
                  row2 = visibleScreenRowRange[1]
                  try
                    newEditor.scrollToScreenPosition [parseInt((row1 + row2)/2), 0], {center: true}
                  catch e
                    console.log e
              break

            if openNoteOptions.addPreview
              ConfirmDialog ?= require './confirm-dialog'
              confirmDialogOptions =
                editorId: editor.id
                filePath: editor.getPath()
                note: note
                oldText: oldText
                newText: textContent
                newNoteInfo: newNoteInfo
              confirmDialog = new ConfirmDialog confirmDialogOptions
              confirmDialog.show()
              if window.evnd.searchNoteView? then window.evnd.searchNoteView.cancel()

    conflictStatus = note.checkConflict()
    unless conflictStatus.unsyncdModificationInAtomEVND
      if previewView? and previewView.editor?.isModified()
        conflictStatus.unsyncdModificationInAtomEVND = true
      else
        notePath = note.absPath()
        for editor in atom.workspace.getTextEditors() when editor.getPath() is notePath
          if editor.isModified()
            conflictStatus.unsyncdModificationInAtomEVND = true
          break
    if conflictStatus.unsyncdModificationInAtomEVND
      detailedMsg = "You can still go ahead and grab content from Evernote, "
      detailedMsg += "whether the new content will be put in a new pane or "
      detailedMsg += "oevewrite existing content depends on your settings"
      detailedMsg += "(EVND will wait for your confirmation to write new "
      detailedMsg += "onto disk).\nYour current setting: "
      if atom.config.get('ever-notedown.pulledContentInSplitPane')
        detailedMsg += "open grabbed content in a separate pane.\n"
      else
        detailedMsg += "overwrite existing content.\n"
      detailedMsg += "You can also make sure that this time the new content "
      detailedMsg += "is put into a separate pane.\n\n"
      detailedMsg += "Please choose how to proceed: "
      atom.confirm
        message: "There are changes that have not been sent to Evernote."
        detailedMessage: detailedMsg
        buttons:
          "Cancel": => return #console.log "Cancelled"
          "Go ahead": => pullNoteNormal(note, {searchAllPanes: true})
          "Put pulled content in a new pane": =>
            pullNoteNormal(note, {newPane: true, searchAllPanes: true})
    else
      pullNoteNormal(note, {searchAllPanes: true})

  togglePreview: ->
    if window.evnd.init then @loadModule()
    if isEVNDPreviewView(atom.workspace.getActivePaneItem())
      atom.workspace.destroyActivePaneItem()
      return

    editor = atom.workspace.getActiveTextEditor()
    return unless editor?

    grammars = atom.config.get('ever-notedown.grammars') ? []
    unless editor.getGrammar().scopeName in grammars
      scopeName = editor.getGrammar().scopeName
      warningMsg = "Cannot preview this file because grammar '#{scopeName}' isn't supported.\n"
      warningMsg += "\n(Current supported grammars set in EVND settings: #{grammars.toString()})"
      window.alert(warningMsg)
      return

    @addPreviewForEditor(editor) unless @removePreviewForEditor(editor)

  getPreviewViewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previewPane = atom.workspace.paneForURI(uri)
    if previewPane?
      evndPreviewView = previewPane.itemForURI(uri)
      return evndPreviewView if isEVNDPreviewView(evndPreviewView)
    return null

  uriForEditor: (editor) ->
    "ever-notedown-preview://editor/#{editor?.id}"

  removePreviewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previewPane = atom.workspace.paneForURI(uri)
    if previewPane?
      previewPane.destroyItem(previewPane.itemForURI(uri))
      true
    else
      false

  addPreviewForEditor: (editor, note, callback) ->
    uri = @uriForEditor(editor)
    previousActivePane = atom.workspace.getActivePane()
    options =
      searchAllPanes: true
    if atom.config.get('ever-notedown.openPreviewInSplitPane')
      options.split = 'right'
    atom.workspace.open(uri, options).then (evNotedownPreviewView) =>
      if isEVNDPreviewView(evNotedownPreviewView)
        filePath = editor.getPath()
        fnStem = path.basename(filePath, path.extname(filePath))
        dir = path.basename(path.dirname(filePath))
        note ?= noteHelper?.findNote(window.evnd?.noteIndex, {fnStem: fnStem, dir: dir})
        evNotedownPreviewView.note = note
        evNotedownPreviewView.noteID = note?.id
        if note? then evNotedownPreviewView.activateButtons()
        previousActivePane.activate()
        if callback? then callback(evNotedownPreviewView)

  boldText: ->
    if window.evnd.init then @loadModule()
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    selectedText = editor.getSelectedText()
    options =
      select: true
    editor.insertText "**#{selectedText}**", options

  emphasisText: ->
    if window.evnd.init then @loadModule()
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    selectedText = editor.getSelectedText()
    options =
      select: true
    editor.insertText "_#{selectedText}_", options

  underlineText: ->
    if window.evnd.init then @loadModule()
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    selectedText = editor.getSelectedText()
    options =
      select: true
    editor.insertText "<u>#{selectedText}</u>", options

  highlightText: ->
    if window.evnd.init then @loadModule()
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    selectedText = editor.getSelectedText()
    options =
      select: true
    editor.insertText "<mark>#{selectedText}</mark>", options

  strikeThroughText: ->
    if window.evnd.init then @loadModule()
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    selectedText = editor.getSelectedText()
    options =
      select: true
    editor.insertText "~~#{selectedText}~~", options

  blockquote: ->
    if window.evnd.init then @loadModule()
    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    selectedText = editor.getSelectedText()
    selectedTextLines = selectedText.toString().split(/[\n\r]/)
    for i in [0..selectedTextLines.length-1]
      selectedTextLines[i] = ">  #{selectedTextLines[i]}"
    newText = selectedTextLines.join("\n")
    options =
      select: true
    editor.insertText newText, options

  pasteImage: () ->
    if window.evnd.init then @loadModule()
    editor = atom.workspace.getActiveTextEditor()
    return unless editor? and editor? isnt '' and atom.workspace.getActivePane().isFocused()

    image = clipboard.readImage()
    if not image.isEmpty()
      buf = image.toPng()
      imgBin = atob(buf.toString('base64'))
      timeStr = utils.sanitizeTimeString(utils.getCurrentTimeString())
      if window.evnd.storageManager?.gitPath
        newPath = path.join(window.evnd.storageManager.gitPath, 'tmp/', "clipboard_#{timeStr}.png")
      else
        newPath = path.join(atom.getConfigDirPath(), 'evnd/tmp/', "#{timeStr}.png")
      fs.writeFileSync(newPath, imgBin, 'binary')
      editor.insertText("![Alt text](#{newPath} \"Optional title\")")
    else
      filePath = clipboard.readText().trim()
      if fs.isFileSync(filePath)
        if utils.isImage(filePath)
          clipboard.writeText("![Alt text](#{filePath} \"Optional title\")")
        else
          clipboard.writeText("!{Alt text}(#{filePath} \"Optional title\")") # Attachment...
      else
        return

  onDrop: (event) ->
    utils ?= require './utils'
    _ ?= require 'underscore-plus'
    path ?= require 'path'

    editor = atom.workspace.getActiveTextEditor()
    return unless editor?
    curPath = editor.getPath()
    return unless utils.isMarkdown(curPath)
    event.preventDefault()
    event.stopPropagation()
    pathsToDrop = _.pluck(event.dataTransfer.files, 'path')
    # TODO: Pop up warning if there're spaces in filenames!
    if pathsToDrop.length > 0
      for onePath in pathsToDrop
        continue unless onePath?
        filename = path.basename(onePath)
        if utils.isImage(filename)
          attachmentText = " ![attachment](#{onePath} \"#{filename}\")"
        else
          attachmentText = " !{attachment}(#{onePath} \"#{filename}\") "
        editor.insertText(attachmentText)
    return

  previewFile: ({target}) ->
    if window.evnd.init then @loadModule()
    filePath = target.dataset.path
    return unless filePath

    for editor in atom.workspace.getTextEditors() when editor.getPath() is filePath
      @addPreviewForEditor(editor)
      return

    atom.workspace.open "ever-notedown-preview://#{encodeURI(filePath)}",
      searchAllPanes: true

  saveHtml: ->
    if window.evnd.init then @loadModule()
    editor = atom.workspace.getActiveTextEditor()
    paneItem = atom.workspace.getActivePaneItem()
    return unless editor? or isEVNDPreviewView(paneItem)

    if editor?
      previewView = @getPreviewViewForEditor(editor)
      if previewView?
        previewView?.saveAs()
      else
        @addPreviewForEditor editor, null, (previewView) ->
          #previewView = @getPreviewViewForEditor(editor)
          previewView?.saveAs()
    else if isEVNDPreviewView(paneItem)
      paneItem.saveAs()

  copyHtml: ->
    if window.evnd.init then @loadModule()
    editor = atom.workspace.getActiveTextEditor()
    paneItem = atom.workspace.getActivePaneItem()
    return unless editor? or isEVNDPreviewView(paneItem)

    if editor?
      previewView = @getPreviewViewForEditor(editor)
      if previewView?
        previewView?.copyToClipboard()
      else
        @addPreviewForEditor editor, null, (previewView) ->
          #previewView = @getPreviewViewForEditor(editor)
          previewView?.copyToClipboard()
    else if isEVNDPreviewView(paneItem)
      paneItem.copyToClipboard()

  getMarkdownScopeName: ->
    grammar = @getEVNDGrammar()
    scopeName = grammar?.scopeName ? 'source.gfm'
    return scopeName

  getEVNDGrammarScopeName: ({evndGrammar, mathjax}={})->
    scopeNameDict =
      litcoffee: 'source.litcoffee'
      litcoffeeMathJax: 'text.markdown.evnd.mathjax.source.litcoffee.inline.html'
      gfm: 'text.markdown.evnd.source.gfm.inline.html'
      gfmMathJax: 'text.markdown.evnd.mathjax.source.gfm.inline.html'

    evndGrammar ?= atom.config.get('ever-notedown.evndGrammar')
    mathjax ?= atom.config.get('ever-notedown.mathjax')
    switch evndGrammar
      when 'Extended source.litcoffee'
        scopeName = if mathjax then scopeNameDict.litcoffeeMathJax else scopeNameDict.litcoffee
      when 'Extended source.gfm'
        scopeName = if mathjax then scopeNameDict.gfmMathJax else scopeNameDict.gfm
    return scopeName

  getEVNDGrammar: ({mathjax}={}) ->
    scopeName = @getEVNDGrammarScopeName({mathjax: mathjax})
    grammar = atom.grammars.grammarForScopeName(scopeName)
    if grammar?
      return grammar

    # grammar doesn't exists?
    evndGrammar = atom.config.get('ever-notedown.evndGrammar')
    switch evndGrammar
      when 'Extended source.litcoffee'
        gramamr = atom.grammars.grammarForScopeName('source.litcoffee')
      when 'Extended source.gfm'
        grammar = atom.grammars.grammarForScopeName('source.gfm')
    return gramamr

  addInlineHTMLGrammar: ->
    inlineHTMLGrammar = atom.grammars.grammarForScopeName('evnd.inline.html')
    unless inlineHTMLGrammar?
      inlineHTMLGrammarPath = path.join __dirname, 'grammars/', 'evnd-inline-html.cson'
      inlineHTMLGrammar = atom.grammars.readGrammarSync inlineHTMLGrammarPath
      atom.grammars.addGrammar inlineHTMLGrammar

  addEVNDGrammar: ->
    switch atom.config.get('ever-notedown.evndGrammar')
      when 'Extended source.litcoffee' then grammarFileName = null
      when 'Extended source.gfm' then grammarFileName = 'evnd.cson'
    if grammarFileName?
      @addInlineHTMLGrammar()
      evndGrammarPath = path.join __dirname, 'grammars/', grammarFileName
      evndGrammar = atom.grammars.readGrammarSync evndGrammarPath
      atom.grammars.addGrammar(evndGrammar)
    else
      evndGrammar = atom.grammars.grammarForScopeName('source.gfm')
    unless evndGramamr?
      return
    for editor in atom.workspace.getTextEditors()
      editorPath = editor.getPath()
      if editor.getGrammar()?.scopeName in evndGrammarList or
          (editorPath? and utils.isMarkdown(editorPath))
        editor.setGrammar(evndGrammar)

  removeEVNDGrammar: ->
    grammarsToRemove = [
      'text.markdown.evnd.mathjax.source.litcoffee.inline.html'
      'text.markdown.evnd.mathjax.source.gfm.inline.html'
      'text.markdown.evnd.source.gfm.inline.html'
    ]
    for scopeName in grammarsToRemove
      atom.grammars.removeGrammarForScopeName(scopeName)
    defaultGrammar = atom.grammars.grammarForScopeName('source.gfm')
    for editor in atom.workspace.getTextEditors()
      editorPath = editor.getPath()
      if editorPath? and editor.getGrammar()?.scopeName in evndGrammarList
        editor.setGrammar(defaultGrammar)

  setEVNDGrammar: (editor) ->
    return unless editor?
    evndGrammar = @getEVNDGrammar({mathjax: false})
    if evndGrammar? and editor?.getGrammar()?.scopeName in evndGrammarList
      editor.setGrammar(evndGrammar)

  addMathJaxGrammar: ->
    switch atom.config.get('ever-notedown.evndGrammar')
      when 'Extended source.litcoffee' then grammarFileName = 'evnd-litcoffee-mathjax.cson'
      when 'Extended source.gfm' then grammarFileName = 'evnd-mathjax.cson'
    if grammarFileName?
      @addInlineHTMLGrammar()
      mathjaxGrammarPath = path.join __dirname, 'grammars/', grammarFileName
      mathjaxGrammar = atom.grammars.readGrammarSync mathjaxGrammarPath
      atom.grammars.addGrammar(mathjaxGrammar)
    else
      mathjaxGrammar = atom.grammars.grammarForScopeName('source.gfm')
    unless mathjaxGrammar?
      return
    for editor in atom.workspace.getTextEditors()
      editorPath = editor.getPath()
      if editor.getGrammar()?.scopeName in evndGrammarList or
          (editorPath? and utils.isMarkdown(editorPath))
        editor.setGrammar(mathjaxGrammar)

  setMathJaxGrammar: (editor) ->
    return unless editor?
    mathjaxGrammar = @getEVNDGrammar({mathjax: true})
    if mathjaxGrammar? and editor?.getGrammar()?.scopeName in evndGrammarList
      editor.setGrammar(mathjaxGrammar)

  removeMathJaxGrammar: ->
    grammarsToRemove = [
      'text.markdown.evnd.mathjax.source.litcoffee.inline.html'
      'text.markdown.evnd.mathjax.source.gfm.inline.html'
    ]
    for scopeName in grammarsToRemove
      atom.grammars.removeGrammarForScopeName(scopeName)
    evndGrammar = @getEVNDGrammar({mathjax: false})
    for editor in atom.workspace.getTextEditors()
      editorPath = editor.getPath()
      if editorPath? and editor.getGrammar()?.scopeName?.indexOf('mathjax') > -1
        editor.setGrammar(evndGrammar)

  switchEVNDGrammar: (newEVNDGrammar, mathjax) ->
    mathjax ?= atom.config.get('ever-notedown.mathjax')
    newEVNDGrammarScopeName = @getEVNDGrammarScopeName({evndGrammar: newEVNDGrammar, mathjax: mathjax})
    newEVNDGrammar = atom.grammars.grammarForScopeName(newEVNDGrammarScopeName)
    if not newEVNDGrammar?
      if mathjax then @addMathJaxGrammar() else @addEVNDGrammar()
      return
    else
      for editor in atom.workspace.getTextEditors()
        editorPath = editor.getPath()
        editor.setGrammar(newEVNDGrammar)

  loadModule: ->
    {TextEditor} = require 'atom' unless TextEditor?

    utils ?= require './utils'
    CSON ?= require 'season'
    fs ?= require 'fs-plus'
    path ?= require 'path'
    git ?= require 'git-utils'
    _ ?= require 'underscore-plus'

    evernoteHelper ?= require './evernote-helper'
    storage ?= require './storage-manager'
    noteHelper ?= require './note-helper'
    mathjaxHelper ?= require './mathjax-helper'
    {fenceNameForScope} = require './extension-helper' unless fenceNameForScope?
    cheerio ?= require 'cheerio'
    clipboard ?= require 'clipboard'

    url ?= require 'url'

    SearchResultListView ?= require './search-result-list-view'
    SearchNoteView ?= require './search-note-view'
    NoteManagerView ?= require './note-manager-view' # Defer until used
    EVNDPreviewView ?= require './ever-notedown-preview-view' # Defer until used
    EVNDView ?= require './ever-notedown-view' # Defer until used
    renderer ?= require './renderer' # Defer until used

    if window.evnd.init
      for paneItem in atom.workspace.getPaneItems() when isEVNDPreviewView(paneItem)
        paneItem.renderMarkdown()


      @loadCSS()
      @loadTemplate()

      if atom.config.get('ever-notedown.mathjax')
        @addMathJaxGrammar()
      else
        @addEVNDGrammar()

      @loadGitRepo null, null, (newStorageManager) =>
        window.evnd.storageManager = newStorageManager
        window.evnd.svgCollections = {}
        window.evnd.newNoteDisposables = {}
        window.evnd.gitPath = window.evnd.storageManager.gitPath
        window.evnd.gitPathSymlink = window.evnd.storageManager.gitPathSymlink
        @loadJSON (newNoteIndex) =>
          window.evnd.noteIndex = newNoteIndex
          if window.evnd.evndView? then window.evnd.evndView.refresh()
          for paneItem in atom.workspace.getPaneItems()
            if isEVNDPreviewView(paneItem) and not paneItem.note?
              filePath = paneItem.getPath()
              fnStem = path.basename(filePath, path.extname(filePath))
              dir = path.basename(path.dirname(filePath))
              note = noteHelper.findNote(window.evnd.noteIndex, {fnStem: fnStem, dir: dir})
              if (not paneItem.noteID?) and note?
                paneItem.noteID = note.id
              paneItem.attachNote(note)

      #
      # TODO: Implement this!
      #
      #@subscriptions.add atom.config.observe 'ever-notedown.renderDiagrams', (toRender) =>
      #  if toRender and not window.evnd.chartsLibsLoaded
      #    chartsHelper ?= require './charts-helper'
      #    chartsHelper.loadChartsLibraries()

      @subscriptions.add atom.config.onDidChange 'ever-notedown.gitPath', (event) =>
        newGitPath = event.newValue
        reloadGitRepo = =>
          @loadGitRepo newGitPath, null, (newStorageManager) =>
            if newStorageManager?
              window.evnd.storageManager = newStorageManager
              @loadJSON (newNoteIndex) =>
                window.evnd.noteIndex = newNoteIndex
                if window.evnd.evndView? then window.evnd.evndView.refresh()
                window.evnd.gitPath = newGitPath
        dmsg = "Changing git repo path for EVND to #{newGitPath}"
        if atom.config.get('ever-notedown.gitPathSymlink') then dmsg += " (symbolic link)"
        atom.confirm
          message: dmsg + "?"
          buttons:
            "Confirm": => reloadGitRepo()
            "Cancel": => return
            "Revert": =>
              atom.config.set 'ever-notedown.gitPath', event.oldValue

      @subscriptions.add atom.config.onDidChange 'ever-notedown.gitPathSymlink', (event) =>
        gitPathSymlink = event.newValue
        reloadGitRepo = =>
          @loadGitRepo null, gitPathSymlink, (newStorageManager) =>
            if newStorageManager?
              window.evnd.storageManager = newStorageManager
              @loadJSON (newNoteIndex) =>
                window.evnd.noteIndex = newNoteIndex
                if window.evnd.evndView? then window.evnd.evndView.refresh()
                window.evnd.gitPathSymlink = gitPathSymlink
        dmsg = "Changing git repo path for EVND to #{atom.config.get('ever-notedown.gitPath')}"
        if gitPathSymlink then dmsg += " (symbolic link)"
        atom.confirm
          message: dmsg + "?"
          buttons:
            "Confirm": => reloadGitRepo()
            "Cancel": => return
            "Revert": =>
              atom.config.set 'ever-notedown.gitPathSymlink', event.oldValue

      @subscriptions.add atom.config.observe 'ever-notedown.noteTemplate', (newTemplateName) =>
        @loadTemplate(newTemplateName)

      @subscriptions.add atom.config.onDidChange 'ever-notedown.theme', (event) =>
        newThemeName = event.newValue
        @loadCSS(newThemeName)

      @subscriptions.add atom.config.onDidChange 'ever-notedown.syntaxTheme', (event) =>
        newSyntaxThemeName = event.newValue
        @loadCSS(null, newSyntaxThemeName)

      # TODO: ...
      @subscriptions.add atom.config.observe 'ever-notedown.mathjax', (mathjax) =>
        if mathjax
          mathjaxHelper.loadMathJax()
          @addMathJaxGrammar()
        else
          mathjaxHelper.unloadMathJax()
          @removeMathJaxGrammar()

      @subscriptions.add atom.config.onDidChange 'ever-notedown.evndGrammar', (event) =>
        mathjax = atom.config.get('ever-notedown.mathjax')
        @switchEVNDGrammar(event.newValue, mathjax)

      @subscriptions.add atom.config.observe 'ever-notedown.mathjaxCustomMacros', (customMacros) =>
        mathjaxHelper.reconfigureMathJax() # TODO: this isn't working!

      @subscriptions.add atom.config.observe 'ever-notedown.sortBy', (sortBy) =>
        window.evnd.noteManagerView?.destroy()
        window.evnd.noteManagerView = null
        window.evnd.searchResultListView?.destroy()
        window.evnd.searchResultListView = null

      @subscriptions.add atom.workspace.observeTextEditors (editor) =>
        if (editor?.getGrammar()?.scopeName in ['source.gfm', 'source.litcoffee']) or
            utils.isMarkdown(editor?.getPath?())
          if atom.config.get('ever-notedown.mathjax')
            @setMathJaxGrammar(editor)
          else
            @setEVNDGrammar(editor)

      @subscriptions.add atom.workspace.observeActivePaneItem (activeItem) =>
        if activeItem is atom.workspace.getActiveTextEditor() and activeItem?.id
          previewView = @getPreviewViewForEditor(activeItem)
          if previewView?
            editorPane = atom.workspace.paneForItem(activeItem)
            previewPane = atom.workspace.paneForItem(previewView)
            if previewPane isnt editorPane and
                previewPane?.getActiveItem() isnt previewView
              previewPane.activateItem(previewView)


      window.evnd.init = false
