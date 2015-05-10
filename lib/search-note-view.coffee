# Based on https://github.com/atom/find-and-replace/blob/a29bdbfde9a2ecaf503b4b8bc7ff3c011f7fb017/lib/find-view.coffee
#
# Reproduced License Info:
# Copyright (c) 2014 GitHub Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# 
_ = require 'underscore-plus'
{$, $$$, View, TextEditorView} = require 'atom-space-pen-views'
{Emitter, CompositeDisposable} = require 'atom'

module.exports =
class SearchNoteView extends View
  @content: ->
    @div tabIndex: -1, class: 'evnd-search-note', =>
      @header class: 'header', =>
        @span outlet: 'descriptionLabel', class: 'header-item description', 'Import note from Evernote'
        @span class: 'header-item options-label pull-right', =>
          @span 'Take input string as: '
          @span outlet: 'optionsLabel', class: 'options'

      @section class: 'input-block find-container', =>
        @div class: 'input-block-item input-block-item--flex editor-container', =>
          @subview 'searchEditor', new TextEditorView(mini: true, placeholderText: 'Search Evernote notes')
          @div class: 'find-meta-container', =>
            @span outlet: 'resultCounter', class: 'text-subtle result-counter', ''

        @div class: 'input-block-item', =>
          @div class: 'btn-group btn-group-find', =>
            @button outlet: 'searchButton', class: 'btn', click:'searchNote', 'Search'

          @div class: 'btn-group btn-toggle btn-group-options', =>
            @button outlet: 'noteLinkButton', class: 'btn selected', 'Note Link'
            @button outlet: 'queryStringButton', class: 'btn', 'Query String'

  constructor: ->
    super
    @emitter = new Emitter
    @disposables = new CompositeDisposable

  initialize: ->
    @emitter ?= new Emitter
    @disposables ?= new CompositeDisposable
    @handleEvents()
    @selectQueryStringButton()
    @clearMessage()

  serialize: ->

  cancel: ->
    @destroy()

  destroy: ->
    @panel?.destroy()
    if window.evnd?.searchNoteView? then window.evnd.searchNoteView = null

  show: ->
    @panel ?= atom.workspace.addBottomPanel item: this
    @panel.show()

  handleEvents: ->
    @disposables.add atom.commands.add @element,
      'core:close': => @panel?.hide()
      'core:cancel': => @panel?.hide()

    # Handling cancel in the workspace + code editors
    handleEditorCancel = ({target}) =>
      isMiniEditor = target.tagName is 'ATOM-TEXT-EDITOR' and target.hasAttribute('mini')
      @panel?.hide() unless isMiniEditor

    @disposables.add atom.commands.add 'atom-workspace',
      'core:cancel': handleEditorCancel
      'core:close': handleEditorCancel

    @noteLinkButton.on 'click', @selectNoteLinkButton
    @queryStringButton.on 'click', @selectQueryStringButton

    @on 'focus', => @searchEditor.focus()


  onDidSearchWithString: (callback) ->
    @emitter.on 'did-search-with-string', callback

  searchNote: ->
    searchString = @searchEditor.getText().trim()
    return unless searchString.length > 0
    console.log "Search with string #{searchString} (as #{@searchType})"
    if @searchType is "noteLink"
      @emitter.emit 'did-search-with-string', {noteLink: searchString}
    else
      @emitter.emit 'did-search-with-string', {queryString: searchString}

  selectNoteLinkButton: =>
    unless @noteLinkButton.hasClass('selected')
      @noteLinkButton.addClass('selected')
    @queryStringButton.removeClass('selected')
    @optionsLabel.text("Note Link")
    @searchType = "noteLink"

  selectQueryStringButton: =>
    unless @queryStringButton.hasClass('selected')
      @queryStringButton.addClass('selected')
    @noteLinkButton.removeClass('selected')
    @optionsLabel.text("Query String")
    @searchType = "queryString"

  setInfoMessage: (infoMessage) ->
    @descriptionLabel.text(infoMessage).removeClass('text-error')

  setErrorMessage: (errorMessage) ->
    @descriptionLabel.text(errorMessage).addClass('text-error')

  clearMessage: ->
    @descriptionLabel.html('Import note from Evernote <span class="subtle-info-message">Close this panel with the <span class="highlight">esc</span> key</span>').removeClass('text-error')
