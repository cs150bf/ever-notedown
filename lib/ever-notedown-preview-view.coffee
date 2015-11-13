# Based on https://github.com/atom/markdown-preview/blob/9ff76ad3f6407a0fb68163a538c6d460280a1718/lib/markdown-preview-view.coffee
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

{Emitter, Disposable, CompositeDisposable} = require 'atom'
{$, $$, $$$, ScrollView} = require 'atom-space-pen-views'
_ = require 'underscore-plus'
fs = require 'fs-plus'
{File} = require 'atom'

renderer = require './renderer'
utils = require './utils'
crypto = require 'crypto'
noteHelper = null

RichNote = null

module.exports =
class EVNDPreviewView extends ScrollView
  @content: ->
    @div class: 'ever-notedown-preview native-key-bindings', tabindex: -1

  constructor: ({@editorId, @filePath, html, @markdownSource, @bindings, @noteID}={}) ->
    super
    @emitter = new Emitter
    @disposables = new CompositeDisposable
    @loaded = false
    if @markdownSource?
      @showLoading()
      @renderMarkdownText(@markdownSource)
    else if html?
      @loading = false
      @loaded = true
      @empty()
      template = document.createElement('template')
      template.innerHTML = html
      domFragment = template.content.cloneNode(true)
      @append(domFragment)
    if @noteID? and window.evnd?.noteIndex?
      noteHelper ?= require './note-helper'
      @note = noteHelper.findNote(window.evnd.noteIndex, {id: @noteID})
      if @note?
        @activateButtons()
      else
        @disableButtons()
    else
      @disableButtons()
    @prevBufferRow = -5
    @prevScrollTop = 0

  attached: ->
    return if @isAttached
    @isAttached = true

    if @editorId?
      @resolveEditor(@editorId)
    else
      if atom.workspace?
        @subscribeToFilePath(@filePath)
      else
        @disposables.add atom.packages.onDidActivateInitialPackages =>
          @subscribeToFilePath(@filePath)

    @parents('.item-views')?.attr("style", "overflow-x: scroll;")

  serialize: ->
    deserializer: 'EVNDPreviewView'
    filePath: @getPath()
    editorId: @editorId
    html: @[0].innerHTML
    markdownSource: @markdownSource
    bindings: @bindings
    noteID: @noteID

  destroy: ->
    @disposables?.dispose()
    #@parents('.pane').view()?.destroyItem(this)

  onDidChangeTitle: (callback) ->
    @emitter.on 'did-change-title', callback

  onDidChangeModified: (callback) ->
    # No op to suppress deprecation warning
    new Disposable

  onDidChangeMarkdown: (callback) ->
    @emitter.on 'did-change-markdown', callback

  # for tracking the editor
  onDidChangeScrollTop: (callback) ->
    @emitter.on 'did-change-scroll-top', callback

  # the button "to Evernote" clicked?
  onDidClickButtonEvernote: (callback) ->
    @emitter.on 'did-click-button-evernote', callback

  onDidClickButtonNewNote: (callback) ->
    @emitter.on 'did-click-button-new-note', callback

  onDidClickButtonPull: (callback) ->
    @emitter.on 'did-click-button-pull', callback

  onDidClickButtonHome: (callback) ->
    @emitter.on 'did-click-button-home', callback

  onDidClickButtonEye: (callback) ->
    @emitter.on 'did-click-button-eye', callback

  onDidClickButtonInfo: (callback) ->
    @emitter.on 'did-click-button-info', callback

  onDidClickButtonHTML: (callback) ->
    @emitter.on 'did-click-button-html', callback

  onDidClickButtonENML: (callback) ->
    @emitter.on 'did-click-button-enml', callback

  onDidClickButtonFolder: (callback) ->
    @emitter.on 'did-click-button-folder', callback

  on: (eventName) ->
    super

  subscribeToFilePath: (filePath) ->
    @file = new File(filePath)
    @emitter.emit 'did-change-title'
    @handleEvents()
    @renderMarkdown()

  resolveEditor: (editorId) ->
    resolve = =>
      @editor = @editorForId(editorId)

      if @editor?
        @emitter.emit 'did-change-title' if @editor?
        @handleEvents()
        @renderMarkdown()
      else
        # The editor this preview was created for has been closed so close
        # this preview since a preview cannot be rendered without an editor
        atom.workspace?.paneForItem(this)?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      @disposables.add atom.packages.onDidActivateInitialPackages(resolve)

  editorForId: (editorId) ->
    for editor in atom.workspace.getTextEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  handleEvents: ->
    @disposables.add atom.grammars.onDidAddGrammar => _.debounce((=> @renderMarkdown()), 250)
    @disposables.add atom.grammars.onDidUpdateGrammar _.debounce((=> @renderMarkdown()), 250)

    atom.commands.add @element,
      'core:move-up': =>
        @scrollUp()
      'core:move-down': =>
        @scrollDown()
      'core:save-as': (event) =>
        event.stopPropagation()
        @saveAs()
      'core:copy': (event) =>
        event.stopPropagation() if @copyToClipboard()
      'ever-notedown:zoom-in': =>
        zoomLevel = parseFloat(@css('zoom')) or 1
        @css('zoom', zoomLevel + .1)
      'ever-notedown:zoom-out': =>
        zoomLevel = parseFloat(@css('zoom')) or 1
        @css('zoom', zoomLevel - .1)
      'ever-notedown:reset-zoom': =>
        @css('zoom', 1)
      'ever-notedown:refresh-preview': =>
        @renderMarkdown()

    changeHandler = =>
      @renderMarkdown()

      # TODO: Remove paneForURI call when ::paneForItem is released
      pane = atom.workspace.paneForItem?(this) ? atom.workspace.paneForURI(@getURI())
      if pane? and pane isnt atom.workspace.getActivePane()
        pane.activateItem(this)

    trackEditor = =>
      return if (not @editor?) or @loading or (not @bindings)
      # TODO: what if soft-wrapped?
      currentScrRowRange = @editor.getVisibleRowRange()
      currentScreenRow = currentScrRowRange[0]
      curLastScreenRow = currentScrRowRange[1]
      currentBufferRow = @editor.bufferRowForScreenRow(currentScreenRow)
      curLastBufferRow = @editor.bufferRowForScreenRow(curLastScreenRow)
      if @lastBufferRow? and @lastBufferRow is currentBufferRow then return
      currentLine = @editor.lineTextForBufferRow(currentBufferRow)
      bindingKeys = []
      metaEndRow = @bindings.endOfMetaLineNum
      currentRow = currentBufferRow - metaEndRow
      @scrollToRow(currentRow, curLastBufferRow - metaEndRow)

    if @file?
      @disposables.add @file.onDidChange(changeHandler)
    else if @editor?
      @disposables.add @editor.getBuffer().onDidStopChanging ->
        changeHandler() if atom.config.get 'ever-notedown.liveUpdate'
      @disposables.add @editor.onDidChangePath => @emitter.emit 'did-change-title'
      @disposables.add @editor.getBuffer().onDidSave ->
        changeHandler() unless atom.config.get 'ever-notedown.liveUpdate'
      @disposables.add @editor.getBuffer().onDidReload ->
        changeHandler() unless atom.config.get 'ever-notedown.liveUpdate'
      # TODO: add tracking for editor
      #       add editor.onDidChangeScrollTop?? (see Minimap for reference)
      @disposables.add @editor.onDidChangeScrollTop =>
        trackEditor() if atom.config.get 'ever-notedown.syncScroll'
      #editorPane = atom.workspace?.paneForItem?(@editor)
      #previewPane = atom.workspace?.paneForItem?(this) ? atom.workspace.paneForURI(@getURI())
      #if editorPane? and previewPane? and editorPane isnt previewPane
      #  @disposables.add editorPane?.observeActiveItem (activeItem) =>
      #    if activeItem is @editor
      #      previewPane = atom.workspace?.paneForItem?(this) ? atom.workspace.paneForURI(@getURI())
      #      if previewPane?.getActiveItem() isnt activeItem then previewPane.activateItem(this)

    @disposables.add atom.config.onDidChange 'ever-notedown.breakOnSingleNewline', changeHandler
    @disposables.add atom.config.onDidChange 'ever-notedown.toc', changeHandler
    @disposables.add atom.config.onDidChange 'ever-notedown.mathjax', changeHandler
    @disposables.add atom.config.onDidChange 'ever-notedown.mathjaxOutput', changeHandler
    @disposables.add atom.config.onDidChange 'ever-notedown.mathjaxCustomMacros', changeHandler
    @disposables.add atom.config.onDidChange 'ever-notedown.footnote', changeHandler
    @disposables.add atom.config.onDidChange 'ever-notedown.checkbox', changeHandler
    @disposables.add atom.config.onDidChange 'ever-notedown.smartyPants', changeHandler

  attachNote: (note) ->
    return false unless note? or (@noteID? and window.evnd?.noteIndex?)
    return false if note? and note.absPath() isnt @getPath()
    if note?
      @note = note
      @noteID = note.id
    else
      noteHelper ?= require './note-helper'
      @note = noteHelper.findNote(window.evnd.noteIndex, {id: @noteID})
    if @note?
      @activateButtons()
      return true
    else
      @disableButtons()
      return false

  disableButtons: ->
    @.find('#button-pull').attr("disabled", true)
    @.find('#button-pull').addClass('evnd-button-disabled')
    @.find('#button-pull').parent().addClass('evnd-button-div-disabled')
    @.find('#button-eye').attr("disabled", true)
    @.find('#button-eye').addClass('evnd-button-disabled')
    @.find('#button-eye').parent().addClass('evnd-button-div-disabled')
    @.find('#button-info').attr("disabled", true)
    @.find('#button-info').addClass('evnd-button-disabled')
    @.find('#button-info').parent().addClass('evnd-button-div-disabled')
    @.find('#button-folder').attr("disabled", true)
    @.find('#button-folder').addClass('evnd-button-disabled')
    @.find('#button-folder').parent().addClass('evnd-button-div-disabled')
    @.find('#button-html').attr("disabled", true)
    @.find('#button-html').addClass('evnd-button-disabled')
    @.find('#button-html').parent().addClass('evnd-button-div-disabled')
    @.find('#button-enml').attr("disabled", true)
    @.find('#button-enml').addClass('evnd-button-disabled')
    @.find('#button-enml').parent().addClass('evnd-button-div-disabled')

  activateButtons: ->
    @.find('#button-pull').attr("disabled", false)
    @.find('#button-pull').removeClass('evnd-button-disabled')
    @.find('#button-pull').parent().removeClass('evnd-button-div-disabled')
    @.find('#button-eye').attr("disabled", false)
    @.find('#button-eye').removeClass('evnd-button-disabled')
    @.find('#button-eye').parent().removeClass('evnd-button-div-disabled')
    @.find('#button-info').attr("disabled", false)
    @.find('#button-info').removeClass('evnd-button-disabled')
    @.find('#button-info').parent().removeClass('evnd-button-div-disabled')
    @.find('#button-folder').attr("disabled", false)
    @.find('#button-folder').removeClass('evnd-button-disabled')
    @.find('#button-folder').parent().removeClass('evnd-button-div-disabled')
    @.find('#button-html').attr("disabled", false)
    @.find('#button-html').removeClass('evnd-button-disabled')
    @.find('#button-html').parent().removeClass('evnd-button-div-disabled')
    @.find('#button-enml').attr("disabled", false)
    @.find('#button-enml').removeClass('evnd-button-disabled')
    @.find('#button-enml').parent().removeClass('evnd-button-div-disabled')

  makeButtons: ->
    $$ ->
      @div class: 'evnd-function-buttons', =>
        @div class: 'evnd-button-div evnd-button-div-hidden', =>
          @button class: 'evnd-function-button', id: 'button-folder', =>
            @div class: 'button-icon-div', =>
              @span class: 'fa fa-folder-open-o', id: 'button-icon-folder'
          @span "Open Finder"
        @div class: 'evnd-button-div evnd-button-div-hidden', =>
          @button class: 'evnd-function-button', id: 'button-enml', =>
            @div class: 'button-icon-div', =>
              @span class: 'fa fa-code', id: 'button-icon-enml'
          @span "Get ENML content (from Evernote)"
        @div class: 'evnd-button-div evnd-button-div-hidden', =>
          @button class: 'evnd-function-button', id: 'button-html', =>
            @div class: 'button-icon-div', =>
              @span class: 'icon icon-file-code', id: 'button-icon-html'
          @span "Get HTML content (from Evernote)"
        @div class: 'evnd-button-div evnd-button-div-hidden', =>
          @button class: 'evnd-function-button', id: 'button-eye', =>
            @div class: 'button-icon-div', =>
              @span class: 'icon icon-eye', id: 'button-icon-eye'
          @span "Open in Evernote"
        @div class: 'evnd-button-div', =>
          @button class: 'evnd-function-button', id: 'button-info', =>
            @div class: 'button-icon-div', =>
              @span class: 'icon icon-info', id: 'button-icon-info'
          @span "View Note Info"
        @div class: 'evnd-button-div', =>
          @button class: 'evnd-function-button', id: 'button-home', =>
            @div class: 'button-icon-div', =>
              @span class: 'icon icon-home', id: 'button-icon-home'
          @span "Toggle EVND Panel"
        @div class: 'evnd-button-div', =>
          @button class: 'evnd-function-button', id: 'button-pull', =>
            @div class: 'button-icon-div', =>
              @span class: 'fa fa-arrow-circle-down', id: 'button-icon-pull'
              @span class: 'button-icon icon-spin4 animate-spin', id: 'pull-syncing'
          @span "Pull from Evernote"
        @div class: 'evnd-button-div', =>
          @button class: 'evnd-function-button', id: 'button-evernote', =>
            @div class: 'button-icon-div', =>
              @span class: 'button-icon icon-evernote', id: 'button-icon-evernote'
              @span class: 'button-icon icon-spin4 animate-spin', id: 'evernote-syncing'
          @span "To Evernote"
        @div class: 'evnd-button-div', =>
          @button class: 'evnd-function-button', id: 'button-new-note', =>
            @div class: 'button-icon-div', =>
              @span class: 'button-icon icon-doc-new', style: 'padding-left: 2px;'
          @span "New Note"

  renderMarkdown: ->
    @showLoading() unless @loaded
    @getMarkdownSource().then (source) => @renderMarkdownText(source) if source?

  getMarkdownSource: ->
    if @file?
      @file.read() # TODO: How to nest Promises?
      #utils.parseMetaData(@file.read())
      #@file.read().then (fileContent) =>
      #  Promise.resolve(utils.parseMetaData(fileContent))
    else if @editor?
      Promise.resolve(utils.parseMetaData(@editor.getText()))
    else
      Promise.resolve(null)

  getHTML: (callback) ->
    if not @loading
      htmlBody = @[0].innerHTML
      callback null, htmlBody
    else
      @getMarkdownSource().then (source) =>
        return unless source?

        text = source.content
        renderer.toHTML text, atom.config.get('ever-notedown.mathjax'),
          @getPath(), source, @getGrammar(), callback

  codeBlockShadowDOM: (domFragment) ->
    codeBlocks = domFragment.querySelectorAll('.evnd-fenced-code-block')
    for codeBlock in codeBlocks
      shadowCodeBlock = codeBlock.createShadowRoot()
      shadowCodeBlock.innerHTML = codeBlock.innerHTML
      codeBlock.innerHTML = ""
    return domFragment

  renderMarkdownText: (source) ->
    @markdownSource = source
    text = source.content
    metaInfo = source
    renderer.toDOMFragment text, atom.config.get('ever-notedown.mathjax'),
      @getPath(), metaInfo, @getGrammar(), (error, domFragment, bindings) =>
        if error
          @showError(error)
        else
          @loading = false
          @loaded = true
          @html(domFragment)
          @append(@makeButtons())
          if @note?
            if @editor?.isModified()
              evndModified = true
            else
              lastModificationTimeStr = @note.getLastModifiedTime()
              lastSyncTimeStr = utils.enDateToTimeString(@note.lastSyncDate)
              if lastModificationTimeStr isnt utils.enDateToTimeString(@note.lastSyncDate) and
                  utils.timeMin(lastModificationTimeStr, lastSyncTimeStr) is lastSyncTimeStr
                evndModified = true
            if evndModified
              @.find('#button-evernote').addClass('evnd-yellow')
              @.find('#button-pull').addClass('evnd-red')
          else
            @disableButtons()
          @bindings = bindings
          @.find('.evnd-function-buttons').on 'mouseenter', (e) =>
            @.find('#button-eye').parent().removeClass('evnd-button-div-hidden')
            @.find('#button-html').parent().removeClass('evnd-button-div-hidden')
            @.find('#button-enml').parent().removeClass('evnd-button-div-hidden')
            @.find('#button-folder').parent().removeClass('evnd-button-div-hidden')
          @.find('.evnd-function-buttons').on 'mouseleave', (e) =>
            @.find('#button-eye').parent().addClass('evnd-button-div-hidden')
            @.find('#button-html').parent().addClass('evnd-button-div-hidden')
            @.find('#button-enml').parent().addClass('evnd-button-div-hidden')
            @.find('#button-folder').parent().addClass('evnd-button-div-hidden')
          @.find('#button-folder').on 'click', (e) =>
            if @note?.path?
              filePath = @note.path
            else
              filePath = path.dirname(@getPath())
            @emitter.emit 'did-click-button-folder', filePath
          @.find('#button-eye').on 'click', (e) =>
            @emitter.emit 'did-click-button-eye', @getPath(), @
          @.find('#button-html').on 'click', (e) =>
            @emitter.emit 'did-click-button-html', @note
          @.find('#button-enml').on 'click', (e) =>
            @emitter.emit 'did-click-button-enml', @note
          @.find('#button-info').on 'click', (e) =>
            @emitter.emit 'did-click-button-info', @note
          @.find('#button-home').on 'click', (e) =>
            @emitter.emit 'did-click-button-home'
          @.find('#button-pull').on 'click', (e) =>
            @emitter.emit 'did-click-button-pull', @getPath(), @
          @.find('#button-evernote').on 'click', (e) =>
            @emitter.emit 'did-click-button-evernote', @editor, @
          @.find('#button-new-note').on 'click', (e) =>
            @emitter.emit 'did-click-button-new-note'
          @.find('.table-of-contents a, .footnotes a, a.footnote').on 'click', (e) =>
            target = e.target
            if target.nodeName.toLowerCase() isnt 'a' then target = e.currentTarget
            targetID = target.getAttribute("href")?.replace(/\./g, '\\.')?.replace(/\:/g, '\\:')
            if atom.config.get('ever-notedown.syncScroll') and
                @bindings? and
                @editor?.isAlive() and
                @isEditorActive()
              metaEndRow = @bindings.endOfMetaLineNum
              #console.log @bindings
              #console.log targetID
              for k, v of @bindings
                continue unless v.id?
                #console.log "##{v.id.replace(/\./g, '\\.').replace(/\:/g, '\\:')}"
                if "##{v.id.replace(/\./g, '\\.').replace(/\:/g, '\\:')}" is targetID
                  targetRow = parseInt(k) + parseInt(metaEndRow)
                  @editor.scrollToBufferPosition([targetRow, 0], {center: true})
                  newEditorScrollTop = @editor.getScrollTop() + @editor.getHeight()/2.2
                  @editor.setScrollTop(newEditorScrollTop)
                  if targetRow < @editor.bufferRowForScreenRow(@editor.getVisibleRowRange()[0])
                    @editor.scrollToBufferPosition([targetRow, 0], {center: false})
                  #return unless $(targetID).get(0)?
                  return unless $(document.getElementById(targetID.slice(1))).get(0)
                  #$(targetID).get(0).scrollIntoView({behavior: "smooth", block: "start"})
                  $(document.getElementById(targetID.slice(1))).get(0).scrollIntoView({behavior: "smooth", block: "start"})
                  break
            else
              #return unless $(targetID).get(0)?
              return unless $(document.getElementById(targetID.slice(1))).get(0)
              #$(targetID).get(0).scrollIntoView({behavior: "smooth", block: "start"})
              $(document.getElementById(targetID.slice(1))).get(0).scrollIntoView({behavior: "smooth", block: "start"})
          @emitter.emit 'did-change-markdown'
          utils.timeOut(200)
          @originalTrigger('ever-notedown:markdown-changed')

  getTitle: ->
    if @file?
      "#{path.basename(@getPath())} Preview"
    else if @editor?
      "#{@editor.getTitle()} Preview"
    else
      "Ever Notedown Preview"

  getIconName: ->
    "markdown"

  getURI: ->
    if @file?
      "ever-notedown-preview://#{@getPath()}"
    else
      "ever-notedown-preview://editor/#{@editorId}"

  getPath: ->
    if @file?
      @file.getPath()
    else if @editor?
      @editor.getPath()

  getGrammar: ->
    @editor?.getGrammar()

  getDocumentStyleSheets: -> # This function exists so we can stub it
    document.styleSheets

  getTextEditorStyles: ->

    textEditorStyles = document.createElement("atom-styles")
    textEditorStyles.setAttribute "context", "atom-text-editor"
    document.body.appendChild textEditorStyles

    Array.prototype.slice.apply(textEditorStyles).map (styleElement) -> styleElement.innerText

    textEditorStyles.remove()

  getMarkdownPreviewCSS: ->
    return @markdownPreviewCSS if @markdownPreviewCSS

    markdowPreviewRules = []
    ruleRegExp = /\.ever-notedown-preview/
    cssUrlRefExp = /url\(atom:\/\/ever-notedown\/assets\/(.*)\)/

    for stylesheet in @getDocumentStyleSheets()
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

  showError: (result) ->
    failureMessage = result?.message

    @html $$$ ->
      @h2 'Previewing Markdown Failed'
      @h3 failureMessage if failureMessage?

  showLoading: ->
    @loading = true
    @html $$$ ->
      @div class: 'markdown-spinner', 'Loading Markdown\u2026'

  cleanUpHTML: (html) ->
    {RichNote} = require './note-prototypes/note-rich' unless RichNote?
    html = RichNote.resolveIcons(html, {toBase64:true})
    html = RichNote.removeFloatingButtons(html)
    return html

  copyToClipboard: ->
    return false if @loading

    selection = window.getSelection()
    selectedText = selection.toString()
    selectedNode = selection.baseNode

    # Use default copy event handler if there is selected text inside this view
    return false if selectedText and selectedNode? and (@[0] is selectedNode or $.contains(@[0], selectedNode))

    @getHTML (error, html) =>
      if error?
        console.warn('Copying Markdown as HTML failed', error)
      else
        html = @cleanUpHTML(html)
        atom.clipboard.write(html)

    true

  saveAs: ->
    return if @loading

    filePath = @getPath()
    title = 'Markdown to HTML'
    if @note?
      title = @note.title
      filePath = path.join @note.path, "#{@note.fnStem}_export.html"
    else if filePath
      title = path.parse(filePath).name
      filePath += '.html'
    else
      filePath = 'untitled.md.html'
      if projectPath = atom.project.getPaths()[0]
        filePath = path.join(projectPath, filePath)

    if htmlFilePath = atom.showSaveDialogSync(filePath)

      @getHTML (error, htmlBody) =>
        if error?
          console.warn('Saving Markdown as HTML failed', error)
        else
          htmlBody = @cleanUpHTML(htmlBody)
          html = """
          <!DOCTYPE html>
          <html>
            <head>
                <meta charset="utf-8" />
                <title>#{title}</title>
                <style>#{@getMarkdownPreviewCSS()}</style>
            </head>
            <body class='ever-notedown-preview'>#{htmlBody}</body>
          </html>""" + "\n" # Ensure trailing newline

          fs.writeFileSync(htmlFilePath, html)
          atom.workspace.open(htmlFilePath)

  isEqual: (other) ->
    @[0] is other?[0] # Compare DOM elements

  isEditorActive: ->
    return false unless @editor?
    editorPane = atom.workspace?.paneForItem?(@editor) ? atom.workspace.paneForURI(@editor.getURI())
    if editorPane?.getActiveItem() is @editor then return true else return false

  #
  # TODO: What to do with long paragraph?
  # TODO: Use the 'diff-match-patch' library?
  #
  scrollToRow: (firstRow, lastRow) =>
    if firstRow <= 0
      @.scrollToTop()
      return
    if @editor?
      lastBufferRow = @editor.getLastBufferRow()
      if Math.abs(lastRow - lastBufferRow) < 5
        if @bindings[lastBufferRow]?.scrollTop?
          @.scrollTop(@bindings[lastBufferRow].scrollTop)
        else
          @.scrollToBottom()
        return
    return unless @bindings?
    bindingKeys = []
    for k, v of @bindings
      if k isnt "endOfMetaLineNum" then bindingKeys.push(parseInt(k))
    bindingKeys.sort((a, b) => return a-b)
    rowToCheck = -1
    prevRowToCheck = -1
    for i in [0..bindingKeys.length-1]
      if rowToCheck isnt -1 and @bindings[rowToCheck]?.scrollTop?
        prevRowToCheck = rowToCheck
      rowToCheck = bindingKeys[i]
      continue if rowToCheck > lastRow or (rowToCheck < firstRow and bindingKeys[i+1] < lastRow)
      continue if @bindings[rowToCheck]?.tag in ["a", "pre", "li"]
      unless @bindings[rowToCheck]?.scrollTop? and
            ((not @bindings[prevRowToCheck]?.scrollTop?) or
             (@bindings[prevRowToCheck]?.scrollTop? and
                @bindings[rowToCheck]?.scrollTop > @bindings[prevRowToCheck]?.scrollTop))
        continue unless @bindings[rowToCheck]?.id?
        selector = "##{@bindings[rowToCheck].id.replace(/\./g, '\\.').replace(/\:/g, '\\:')}"
        #continue unless $(selector).get(0)?
        continue unless $(document.getElementById(@bindings[rowToCheck].id)).get(0)
        elms = @[0].querySelectorAll("##{@bindings[rowToCheck].id.replace(/\./g, '\\.').replace(/\:/g, '\\:')}")
        continue unless elms.length > 0
        domElementOffsetTop = elms[0].offsetTop
        if (not domElementOffsetTop?) or (@bindings[prevRowToCheck]?.scrollTop? and @bindings[prevRowToCheck].scrollTop > domElementOffsetTop)
          domElementOffsetTop = elms[0].offsetParent.offsetTop
        #jQueryOffsetTop = $(selector).offset().top
        jQueryOffsetTop = $(document.getElementById(@bindings[rowToCheck].id)).offset().top
        if @bindings[prevRowToCheck]?.scrollTop?
          if jQueryOffsetTop? and @bindings[prevRowToCheck].scrollTop < jQueryOffsetTop
            @bindings[rowToCheck].scrollTop = jQueryOffsetTop
          else if domElementOffsetTop? and @bindings[prevRowToCheck].scrollTop < domElementOffsetTop
            @bindings[rowToCheck].scrollTop = domElementOffsetTop
        else if prevRowToCheck is -1
          if jQueryOffsetTop? and domElementOffsetTop?
            if jQueryOffsetTop < domElementOffsetTop
              @bindings[rowToCheck].scrollTop = domElementOffsetTop
            else
              @bindings[rowToCheck].scrollTop = jQueryOffsetTop
          else if jQueryOffsetTop?
            @bindings[rowToCheck].scrollTop = jQueryOffsetTop
          else
            @bindings[rowToCheck].scrollTop = domElementOffsetTop

      scrollTop = @bindings[rowToCheck].scrollTop
      for j in [(i+1)..bindingKeys.length-1]
        if @bindings[bindingKeys[j]]?.scrollTop?
          nextScrollTop = @bindings[bindingKeys[j]].scrollTop
          nextBindingRow = bindingKeys[j]
          break
      if scrollTop? and rowToCheck >= firstRow and rowToCheck <= lastRow # element visible!
        extraHeight = - @.height() * 1.0 * (rowToCheck - firstRow)/(lastRow - firstRow)
        newScrollTop = scrollTop + extraHeight
        break
      else if scrollTop? and rowToCheck < firstRow and nextBindingRow? and nextBindingRow > lastRow
        nextRowToCheck = bindingKeys[i+1]
        scrollTop = @bindings[rowToCheck].scrollTop
        nScreenRows = lastRow - firstRow
        extraHeight = @.height() * 1.0 * (firstRow - rowToCheck)/nScreenRows
        newScrollTop = scrollTop + extraHeight
        break

    unless newScrollTop? and
        ((firstRow < @prevBufferRow and newScrollTop < @scrollTop()) or
         (firstRow > @prevBufferRow and newScrollTop > @scrollTop()))
      if newScrollTop?
        nScreenRows = lastRow - firstRow
        extraHeight0 = @height() * 1.0 * (firstRow - @prevBufferRow)/nScreenRows
        newScrollTop = @scrollTop() + extraHeight0

    if newScrollTop?
      @scrollTop(newScrollTop)
    @prevBufferRow = firstRow


