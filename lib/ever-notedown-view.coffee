{Emitter, Disposable, CompositeDisposable} = require 'atom'
{$, $$$, View} = require 'atom-space-pen-views'
NoteManagerView = null
EVNDView = null
noteHelper = null


sortByDict =
  "Title": "title"
  "Modification Time": "modificationTime"

isEVNDView = (object) ->
  EVNDView ?= require './ever-notedown-view'
  object instanceof EVNDView

floatingButtons = "<button id=\"fl-btn-delete\" title=\"Delete\">" +
    "<span class=\"fa fa-trash\"></span></button>" +
    "<button id=\"fl-btn-open-note\" title=\"Open Note in Atom\">" +
    "<span class=\"fa fa-pencil\"></span></button>" +
    "<button id=\"fl-btn-open-info\" title=\"Open Info Dialog\">" +
    "<span class=\"fa fa-info-circle\"></span></button>" +
    "<button id=\"fl-btn-open-finder\" title=\"Open Finder (to the note directory)\">" +
    "<span class=\"fa fa-folder-open-o\"></span></button>"

timer = null

module.exports =
class EVNDView extends View
  @content: ->
    @div class: 'ever-notedown-panel native-key-bindings', tabindex: -1, =>
      @div class: 'ever-notedown-panel-tag', =>
        @button class: 'evnd-tag-button', click: 'toggle', =>
          @span class: 'icon icon-light-bulb'
      @div id: 'ever-notedown-panel-content', =>
        @div id: 'evnd-panel-functions', =>
          @div id: 'evnd-panel-file-functions', =>
            @ul id: 'evnd-panel-functions-list-1', =>
              @li =>
                @button id: 'evnd-panel-import-note', click: 'importNote', =>
                  @span class: 'icon icon-search', 'Import from Evernote'
              @li =>
                @button id: 'evnd-panel-new-file', click: 'newNote', =>
                  @span class: 'icon icon-plus', "New note"
              @li =>
                @button id: 'evnd-panel-delete-file', click: 'deleteNote', =>
                  @span class: 'icon icon-trashcan', "Delete current note"
              @li =>
                @button id: 'evnd-panel-export-file', click: 'exportNote', =>
                  @span class: 'icon icon-jump-down', 'Export current note'
          @div id: 'evnd-panel-function-buttons', =>
            @ul =>
              @li =>
                @button id: 'evnd-panel-close', title: 'Close this panel', click: 'destroy', =>
                  @span class: 'icon icon-x', style: 'font-size: 150%;'
              @li =>
                @button id: 'evnd-panel-help', title: 'Open Help Document', click: 'openHelp', =>
                  @span class: 'icon icon-question'
              @li =>
                @button id: 'evnd-panel-config', title: 'Open Atom Packages Config', click: 'openConfig', =>
                  @span class: 'icon icon-gear'
              @li =>
                @button id: 'evnd-panel-open-note-list', title: 'Open searchable drop-down note list', click: 'openNoteList', =>
                  @span class: 'icon icon-list-unordered'
        @div class: 'evnd-note-list', =>
          @div class: 'evnd-note-list-funcs', =>
            @div id:'evnd-note-list-funcs-title', "EVND Notes"
            @div id:'evnd-note-list-funcs-buttons', =>
              @button id: 'evnd-note-list-refresh', title: 'refresh', click: 'refresh', =>
                @span class: 'icon icon-sync'
              @button id: 'evnd-note-list-a2z', class: 'a2z', title: 'Sort By Title', click: 'sortByTitle', =>
                @span class: 'fa fa-sort-alpha-asc'
              @button id: 'evnd-note-list-mtime', class: 'asc clk', title: 'Sort By Modification Time', click: 'sortByModTime', =>
                @span class: 'fa fa-clock-o'
          @div class: 'evnd-note-list-tree'


  activate: ->
    new EVNDView

  serialize: ->

  constructor: () ->
    super
    @emitter = new Emitter
    @disposables = new CompositeDisposable
    @added = false

  destroy: ->
    @panel?.destroy()
    window.evnd.modalPanel = null
    @disposables.dispose()

  on: (eventName) ->
    super

  toggle: (evNotedown) ->
    @emitter ?= new Emitter
    @disposables ?= new CompositeDisposable
    if evNotedown? then @evNotedown = evNotedown
    if @isVisible()
      @hide()
    else
      @show()

  hide: ->
    $('.ever-notedown-panel-tag').removeClass "ever-notedown-panel-tag-pulled"
    $('.ever-notedown-panel').animate {right: "0px"}, 400, () =>
      if $('atom-workspace').hasClass('theme-one-dark-ui') or $('atom-workspace').hasClass('theme-one-light-ui')
        @panel?.hide()
      return

  show: ->
    @panel ?= atom.workspace.addModalPanel item: this
    return unless @panel?
    unless @noteTree?
      $('.evnd-note-list-menu-div').append(@makeMenu())
      $('#evnd-note-list-a2z').hover (e) =>
        @toggleA2ZIcon()
    for i in [0..@panel.item[0].parentElement.classList.length-1]
      klass = @panel.item[0].parentElement.classList[i]
      if klass?.indexOf("from") > -1
        @panel.item[0].parentElement.classList.remove(klass)
    unless @panel.item[0].parentElement.classList.contains("ever-notedown-panel-container")
      @panel.item[0].parentElement.classList.add("ever-notedown-panel-container")
    $('.ever-notedown-panel-tag').addClass "ever-notedown-panel-tag-pulled"
    $('.ever-notedown-panel').animate {right: "350px"}, 400, () =>
      return
    @panel?.show() unless @panel?.isVisible()

  isVisible: ->
    @panel?.isVisible() and $('.ever-notedown-panel').css('right') is '350px'

  refresh: ->
    @makeMenu()

  getDefaultSortingMethod: ->
    return @sorting if @sorting?
    sorting = {method: "Title", reverse: false}
    if atom.config.get('ever-notedown.sortBy') is "Modification Time"
      sorting.method = "Modification Time"
      sorting.reverse = true
    @sorting = sorting
    return sorting

  makeMenu: (sorting) ->
    return "" unless window?.evnd?.noteIndex
    sorting ?= @getDefaultSortingMethod()
    @noteTree = window.evnd.noteIndex.makeTree()
    notebookList = []
    for k, v of @noteTree
      notebookList.push(k)
      v = @sortNotes(v, sorting)
    notebookList = @sortNotebooks(notebookList, @noteTree, sorting)
    if sorting.reverse
      notebookList.reverse()
      for k, v of @noteTree
        v.reverse()
    $('.evnd-note-list-tree').empty()
    $('.evnd-note-list-tree').append("<ul class=\"evnd-note-list-notebook\"></ul>")
    for notebook in notebookList
      notebookListHTML = "<li><span class=\"evnd-menu-item\"></span></li>"
      $(notebookListHTML).appendTo('.evnd-note-list-notebook')
      $(".evnd-menu-item:last").append("<span class=\"fa fa-book\"></span>")
      notebookHTML = "<span class=\"evnd-menu-item-notebook\">#{notebook}</span>"
      $(".evnd-menu-item:last").append(notebookHTML)
      nNotes = @noteTree[notebook].length.toString()
      noteCountHTML = "<span class=\"notes-count\" title=\"Note Count\">#{nNotes}</span>"
      $(".evnd-menu-item:last").append(noteCountHTML)
      lastNoteSelector = ".evnd-note-list-notebook > li:last"
      if @noteTree[notebook].length > 0
        $(lastNoteSelector).append("<ul class=\"evnd-note-list-notes\"></ul>")
        for note in @noteTree[notebook]
          noteHTML = "<li><span class=\"evnd-menu-note-title\">#{note.title}</span>" +
                    "<span class=\"evnd-menu-note-id\" style=\"display:none;\">" +
                    "#{note.id}</span></li>"
          $(".evnd-note-list-notes:last").append(noteHTML)
          tagsHTML = "<span class=\"icon icon-tag evnd-menu-note-tags\">#{note.tags.toString()}</span>"
          $(".evnd-note-list-notes:last > li:last").append(tagsHTML)
          cTimeHTML = "<span class=\"evnd-menu-note-ctime\" title=\"Creation Time\">#{note.creationTime}</span>"
          mTimeHTML = "<span class=\"evnd-menu-note-mtime\" title=\"Modification Time\">#{note.modificationTime}</span>"
          timeHTML = "<span class=\"evnd-menu-note-time\">#{cTimeHTML}#{mTimeHTML}</span>"
          $(".evnd-note-list-notes:last > li:last").append(timeHTML)
          fltBtnHTML = "<div class=\"floating-buttons\"></div>"
          $(".evnd-note-list-notes:last > li:last").append(fltBtnHTML)
    $(".evnd-note-list-notes").each () ->
      $(this).hide()
    $(".evnd-note-list-notebook > li").click () ->
      $(this).siblings().find('ul').hide(100)
      $(this).siblings().find('.evnd-menu-item span:first-child').removeClass('icon')
      $(this).siblings().find('.evnd-menu-item span:first-child').removeClass('icon-book')
      $(this).siblings().find('.evnd-menu-item span:first-child').addClass('fa')
      $(this).siblings().find('.evnd-menu-item span:first-child').addClass('fa-book')
      $(this).siblings().removeClass("evnd-menu-item-selected")
      $(this).siblings().removeClass("evnd-menu-item-clicked")
      if $(this).hasClass("evnd-menu-item-selected")
        $(this).removeClass("evnd-menu-item-selected")
        $(this).addClass("evnd-menu-item-unselected")
        $(this).find('.evnd-menu-item span:first-child').removeClass('icon')
        $(this).find('.evnd-menu-item span:first-child').removeClass('icon-book')
        $(this).find('.evnd-menu-item span:first-child').addClass('fa')
        $(this).find('.evnd-menu-item span:first-child').addClass('fa-book')
        $(this).find('ul').hide(100)
      else
        $(this).addClass("evnd-menu-item-selected")
        $(this).removeClass("evnd-menu-item-unselected")
        $(this).find('.evnd-menu-item span:first-child').addClass('icon')
        $(this).find('.evnd-menu-item span:first-child').addClass('icon-book')
        $(this).find('.evnd-menu-item span:first-child').removeClass('fa')
        $(this).find('.evnd-menu-item span:first-child').removeClass('fa-book')
        $(this).find('ul').each () ->
          if not $(this).is(":visible")
            $(this).show(150)
      if $(this).hasClass("evnd-menu-item-clicked")
        $(this).removeClass("evnd-menu-item-clicked")
      else
        $(this).addClass("evnd-menu-item-clicked")
    $(".evnd-note-list-notebook > li").hover (event) =>
      showNotes = =>
        $(event.currentTarget).siblings().find('ul').hide(100)
        $(event.currentTarget).siblings().find('.evnd-menu-item span:first-child').removeClass('icon')
        $(event.currentTarget).siblings().find('.evnd-menu-item span:first-child').removeClass('icon-book')
        $(event.currentTarget).siblings().find('.evnd-menu-item span:first-child').addClass('fa')
        $(event.currentTarget).siblings().find('.evnd-menu-item span:first-child').addClass('fa-book')
        $(event.currentTarget).siblings().removeClass("evnd-menu-item-selected")
        if not $(event.currentTarget).hasClass("evnd-menu-item-unselected")
          $(event.currentTarget).find('.evnd-menu-item span:first-child').addClass('icon')
          $(event.currentTarget).find('.evnd-menu-item span:first-child').addClass('icon-book')
          $(event.currentTarget).find('.evnd-menu-item span:first-child').removeClass('fa')
          $(event.currentTarget).find('.evnd-menu-item span:first-child').removeClass('fa-book')
          $(event.currentTarget).find('ul').each () ->
            if not $(this).is(":visible")
              $(this).show(150)
      if timer?
        window.clearTimeout(timer)
        timer = null
      timer = window.setTimeout showNotes, 500
    $(".evnd-note-list-notebook > li").mouseleave (event) =>
      if timer?
        window.clearTimeout(timer)
        timer = null
      $(event.currentTarget).removeClass("evnd-menu-item-unselected")
    $(".evnd-note-list-notes").hover () ->
      $(this).parent().addClass("evnd-menu-item-selected")
    $(".evnd-note-list-notes > li").mouseenter (event) ->
      if $(this).find(".floating-buttons").children().length is 0
        $(this).find(".floating-buttons").append(floatingButtons)
        noteID = $(this).find(".evnd-menu-note-id").text()
        flBtnHTML = "<span class=\"evnd-menu-note-id\" style=\"display:none;\">#{noteID}</span>"
        $(this).find(".floating-buttons").append(flBtnHTML)
    $(".evnd-note-list-notes > li").mouseleave ->
      $(this).find(".floating-buttons").empty()
    $(".evnd-note-list-notes > li").on "click", '#fl-btn-delete', (event) =>
      noteID = $(event.currentTarget).parent().find(".evnd-menu-note-id").text()
      noteHelper ?= require './note-helper'
      note = noteHelper.findNote(window.evnd.noteIndex, {id: noteID})
      @emitter.emit 'did-click-button-delete-note', note
    $(".evnd-note-list-notes > li").on "click", '#fl-btn-open-note', (event) =>
      noteID = $(event.currentTarget).parent().find(".evnd-menu-note-id").text()
      noteHelper ?= require './note-helper'
      note = noteHelper.findNote(window.evnd.noteIndex, {id: noteID})
      @emitter.emit 'did-click-button-open-note', note
    $(".evnd-note-list-notes > li").on "click", '#fl-btn-open-info', (event) =>
      noteID = $(event.currentTarget).parent().find(".evnd-menu-note-id").text()
      noteHelper ?= require './note-helper'
      note = noteHelper.findNote(window.evnd.noteIndex, {id: noteID})
      @emitter.emit 'did-click-button-open-info', note
    $(".evnd-note-list-notes > li").on "click", '#fl-btn-open-finder', (event) =>
      noteID = $(event.currentTarget).parent().find(".evnd-menu-note-id").text()
      noteHelper ?= require './note-helper'
      note = noteHelper.findNote(window.evnd.noteIndex, {id: noteID})
      @emitter.emit 'did-click-button-open-finder', note.path

  sortBy: (arr, key) ->
    arr.sort (a, b) =>
      if key is null
        (a || '\uffff').toUpperCase().localeCompare((b || '\uffff').toUpperCase())
      else if typeof a[key] is 'string'
        a[key].toUpperCase().localeCompare(b[key]?.toUpperCase())
      else
        (a[key] || '\uffff').toUpperCase() > (b[key] || '\uffff').toUpperCase()

  sortNotes: (arr, sorting) ->
    sorting ?= @getDefaultSortingMethod()
    if sorting.method in ["Title", "Modification Time"]
      @sortBy(arr, sortByDict[sorting.method])
    else if sortByDict[sorting.method]?
      @sortBy(arr, sortByDict[sorting.method])
    else
      @defaultNoteSortingMethod(arr)

  sortNotebooks: (arr, noteTree, sorting) ->
    sorting ?= @getDefaultSortingMethod()
    if sorting.method is "Modification Time" and noteTree?
      tmpArr = []
      for x in arr
        tmpArr.push({name: x, modificationTime: noteTree[x]?[noteTree[x].length-1]?.modificationTime})
      tmpArr = @sortBy(tmpArr, "modificationTime")
      newArr = []
      for x in tmpArr
        newArr.push(x.name)
      return newArr
    else
      @defaultNotebookSortingMethod(arr)

  defaultNoteSortingMethod: (arr) ->
    arr.sort (a, b) =>
      a.title.toUpperCase().localeCompare(b.title?.toUpperCase())

  defaultNotebookSortingMethod: (arr) ->
    arr.sort (a, b) =>
      a.toUpperCase().localeCompare(b.toUpperCase())

  sortByTitle: ->
    a2z = $("#evnd-note-list-a2z").hasClass("a2z")
    @sorting = {method: "Title", reverse: (not a2z)}
    @makeMenu(@sorting)
    @toggleA2Z()

  toggleA2Z: ->
    if $("#evnd-note-list-a2z").hasClass("a2z")
      $("#evnd-note-list-a2z").removeClass("a2z")
      $("#evnd-note-list-a2z").addClass("z2a")
      $("#evnd-note-list-a2z > span").removeClass("fa-sort-alpha-asc")
      $("#evnd-note-list-a2z > span").addClass("fa-sort-alpha-desc")
    else
      $("#evnd-note-list-a2z").addClass("a2z")
      $("#evnd-note-list-a2z").removeClass("z2a")
      $("#evnd-note-list-a2z > span").removeClass("fa-sort-alpha-desc")
      $("#evnd-note-list-a2z > span").addClass("fa-sort-alpha-asc")

  sortByModTime: ->
    asc = $("#evnd-note-list-mtime").hasClass("asc")
    @sorting = {method: "Modification Time", reverse: (not asc)}
    @makeMenu(@sorting)
    @toggleTimeAsc()

  toggleTimeAsc: ->
    if $("#evnd-note-list-mtime").hasClass("asc")
      $("#evnd-note-list-mtime").removeClass("asc")
      $("#evnd-note-list-mtime").addClass("desc")
    else
      $("#evnd-note-list-mtime").addClass("asc")
      $("#evnd-note-list-mtime").removeClass("desc")

  toggleA2ZIcon: ->
    #console.log "Toggling A2Z Icon..."
    if $("#evnd-note-list-a2z > span").hasClass("fa-sort-alpha-asc")
      $("#evnd-note-list-a2z > span").removeClass("fa-sort-alpha-asc")
      $("#evnd-note-list-a2z > span").addClass("fa-sort-alpha-desc")
    else
      $("#evnd-note-list-a2z > span").removeClass("fa-sort-alpha-desc")
      $("#evnd-note-list-a2z > span").addClass("fa-sort-alpha-asc")

  importNote: ->
    @hide()
    @emitter.emit 'did-click-button-import-note'

  openConfig: ->
    @hide()
    @emitter.emit 'did-click-button-open-config'

  onDidClickButtonOpenConfig: (callback) ->
    @emitter.on 'did-click-button-open-config', callback

  openHelp: ->
    @hide()
    @emitter.emit 'did-click-button-open-help'

  onDidClickButtonOpenHelp: (callback) ->
    @emitter.on 'did-click-button-open-help', callback

  openNoteList: ->
    @hide()
    @emitter.emit 'did-click-button-open-note-list'

  onDidClickButtonNoteList: (callback) ->
    @emitter.on 'did-click-button-open-note-list', callback

  newNote: ->
    #console.log "Need to emit did-click-button-new-note"
    @hide()
    @emitter.emit 'did-click-button-new-note'

  onDidClickButtonImportNote: (callback) ->
    @emitter.on 'did-click-button-import-note', callback

  onDidClickButtonNewNote: (callback) ->
    #console.log 'Inside onDidClickButtonNewNote'
    @emitter.on 'did-click-button-new-note', callback

  exportNote: ->
    @hide()
    @emitter.emit 'did-click-button-export-note'

  onDidClickButtonExportNote: (callback) ->
    @emitter.on 'did-click-button-export-note', callback

  deleteNote: ->
    @emitter.emit 'did-click-button-delete-note'

  onDidClickButtonDeleteNote: (callback) ->
    @emitter.on 'did-click-button-delete-note', callback

  onDidClickButtonOpenNote: (callback) ->
    @emitter.on 'did-click-button-open-note', callback

  onDidClickButtonOpenInfo: (callback) ->
    @emitter.on 'did-click-button-open-info', callback

  onDidClickButtonOpenFinder: (callback) ->
    @emitter.on 'did-click-button-open-finder', callback


