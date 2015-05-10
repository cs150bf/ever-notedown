{$, $$, SelectListView, View, TextEditorView} = require 'atom-space-pen-views'
{Emitter} = require 'atom'
pathUtil = require 'path'
fs = require 'fs-plus'
_ = require 'underscore-plus'
evernoteHelper = null
noteHelper = null
InfoDialog = null

sortByDict =
  "Title": "title"
  "Notebook": "notebook"
  "Creation Time": "creationTime"
  "Modification Time": "modificationTime"

module.exports =
class NoteManagerView extends SelectListView
  evNotedown: null
  possibleFilterKeys: ['title', 'tag', 'notebook', 'path']

  @content: ->
    @div class: 'select-list', =>
      @subview 'filterEditorView', new TextEditorView(mini: true, placeholderText:"EVND Notes (sortBy: #{atom.config.get('ever-notedown.sortBy')})")
      @div class: 'error-message', outlet: 'error'
      @div class: 'loading', outlet: 'loadingArea', =>
        @span class: 'loading-message', outlet: 'loading'
        @span class: 'badge', outlet: 'loadingBadge'
      @ol class: 'list-group', outlet: 'list'

  constructor: ->
    super
    @emitter = new Emitter

  activate: ->
    new NoteManagerView

  initialize: (serializeState) ->
    super
    @addClass('ever-notedown-note-manager')

  serialize: ->

  getFilterKey: ->
    filter = 'visibleText'
    input = @filterEditorView.getText()
    inputArr = input.split(':')

    if inputArr.length > 1 and inputArr[0] in @possibleFilterKeys
      filter = inputArr[0]

    return filter

  getFilterQuery: ->
    input = @filterEditorView.getText()
    inputArr = input.split(':')

    if inputArr.length > 1
      input = inputArr[1]

    return input

  destroy: ->
    @panel?.destroy()

  cancelled: ->
    @hide()

  confirmed: (note) ->
    @emitter.emit 'did-confirm-note', note.id
    @cancel()

  onDidConfirmNote: (callback) ->
    @emitter.on 'did-confirm-note', callback

  getEmptyMessage: (itemCount, filteredItemCount) =>
    if not itemCount
      'No notes saved yet'
    else
      super

  toggle: () ->
    @evNotedown = window.evnd
    if @panel?.isVisible()
      @hide()
    else
      @show()

  hide: ->
    @panel?.hide()

  show: ->
    @panel ?= atom.workspace.addModalPanel(item: this)
    @panel.show()
    notes = []
    currentNotes = @evNotedown.noteIndex.jsonOBJ
    for title, note of currentNotes
      noteItem = {}
      for k, v of note
        noteItem[k] = v
      noteItem.tags.sort (a, b) ->
        return a > b
      noteItem.tag = noteItem.tags.toString()
      noteItem.notebook = note.notebook?.name
      if note.getLastModifiedTime?
        noteItem.modificationTime = note.getLastModifiedTime()
      else
        noteItem.modificationTime = note.modificationTime
      noteItem.visibleText = note.title + noteItem.notebook + noteItem.tag + note.path + note.fnStem + noteItem.modificationTime
      notes.push(noteItem)

    sortBy = atom.config.get('ever-notedown.sortBy')
    if sortBy isnt 'default' and sortByDict[sortBy]?
      notes = @sortBy(notes, sortByDict[sortBy])
      if sortBy.indexOf('Time') > -1
        notes.reverse()
    @setItems(notes)
    @focusFilterEditor()

  viewForItem: ({title, path, fnStem, format, tags, modificationTime, notebook}) ->
    switch format
      when "Markdown" then icon = "icon-markdown"
      when "Text" then icon = "icon-file-text"
      when "HTML" then icon = "icon-file-code"
      else icon = "icon-file-text"
    $$ ->
      @li class: 'two-lines', 'data-note-title': title, =>
        @div class: 'primary-line', =>
        @div class: 'pull-right', title: "Tags: #{tags.toString()}", =>
          for tag in tags
            @span class: "badge", tag
        @div =>
          @span class: "icon #{icon}", title:"Title: #{title}", title

        @div class: 'secondary-line', =>
          @span class: 'icon icon-book', title:"Notebook: #{notebook}", notebook
          @span class: 'pull-right no-icon text-info', title:'Last modification time (in EVND)', modificationTime

        if atom.config.get('ever-notedown.showPath')
          @div class: 'secondary-line', =>
            if path is @evNotedown?.storageManager?.gitPath then path = "EVND://"
            switch format
              when "Text" then ext = '.txt'
              when "Markdown" then ext = '.markdown'
              else ext = '.html'
            absPath = pathUtil.join path, fnStem + ext
            @div class: 'pull-left', title:"File Path: #{absPath}",  absPath

  sortBy: (arr, key) ->
    arr.sort (a, b) =>
      if typeof a[key] is 'string'
        a[key].toUpperCase().localeCompare(b[key]?.toUpperCase())
      else
        (a[key] || '\uffff').toUpperCase() > (b[key] || '\uffff').toUpperCase()


