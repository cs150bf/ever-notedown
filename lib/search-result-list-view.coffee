{$, $$, SelectListView, View, TextEditorView} = require 'atom-space-pen-views'
{Emitter} = require 'atom'
path = require 'path'
fs = require 'fs-plus'
_ = require 'underscore-plus'

utils = require './utils'

sortByDict =
  "Title": "title"
  "Notebook": "notebook"
  "Creation Time": "enCreationDate"
  "Modification Time": "enModificationDate"

module.exports =
class SearchResultListView extends SelectListView
  @content: ->
    @div class: 'select-list', =>
      @subview 'filterEditorView', new TextEditorView(mini: true, placeholderText:"Evernote search result (sortBy: #{atom.config.get('ever-notedown.sortBy')})")
      @div class: 'error-message', outlet: 'error'
      @div class: 'loading', outlet: 'loadingArea', =>
        @span class: 'loading-message', outlet: 'loading'
        @span class: 'badge', outlet: 'loadingBadge'
      @ol class: 'list-group', outlet: 'list'

  possibleFilterKeys: ['title', 'tag', 'notebook', 'noteLink']

  constructor: (noteItems) ->
    super
    @emitter = new Emitter
    @noteItems = noteItems

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

  cancelled: ->
    @destroy()

  destroy: ->
    @disposables?.dispose()
    @panel?.destroy()
    if window.evnd?.searchResultListView?
      window.evnd.searchResultListView = null

  confirmed: (noteItem) ->
    @emitter.emit 'did-confirm-search-result', noteItem.noteLink
    @cancel()

  onDidConfirmSearchResult: (callback) ->
    @emitter.on 'did-confirm-search-result', callback

  getEmptyMessage: (itemCount, filteredItemCount) =>
    if not itemCount
      'No notes found!'
    else
      super

  toggle: () ->
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
    for noteLink, noteInfo of @noteItems
      continue if noteLink is "found"
      noteItem = {}
      for k, v of noteInfo
        noteItem[k] = v
      noteItem.tags.sort (a, b) =>
        a - b
      noteItem.tag = noteItem.tags.toString()
      noteItem.notebook = noteInfo.notebook.name
      noteItem.visibleText = noteItem.title + noteItem.notebook + noteItem.tag + noteLink + utils.enDateToTimeString(noteItem.enModificationDate)
      notes.push(noteItem)

    sortBy = atom.config.get('ever-notedown.sortBy')
    if sortBy isnt 'default' and sortByDict[sortBy]?
      notes = @sortBy(notes, sortByDict[sortBy])
    @setItems(notes)
    @focusFilterEditor()

  viewForItem: ({title, notebook, noteLink, enModificationDate, tags}) ->
    $$ ->
      @li class: 'two-lines', 'data-note-title': title, =>
        @div class: 'primary-line', =>
        @div class: 'pull-right', title:"Tags: #{tags.toString()}", =>
          for tag in tags
            @span class: "badge", tag
        @div =>
          @span class:'text-highlight', title:"Title: #{title}",  title

        @div class: 'secondary-line', =>
          @span class: 'icon icon-book', title:"Notebook: #{notebook}", notebook
          @span class: 'pull-right no-icon text-info', title:'Last modification time (in Evernote)', utils.enDateToTimeString(enModificationDate)
        @div class: 'secondary-line', =>
          @div class: 'pull-left', title:"Note link: #{noteLink}", noteLink

  # TODO: Proper sorting!
  sortBy: (arr, key) ->
    arr.sort (a, b) =>
      if typeof a[key] is 'string'
        a[key].toUpperCase().localeCompare(b[key]?.toUpperCase())
      else
        (a[key] || '\uffff').toUpperCase() > (b[key] || '\uffff').toUpperCase()


