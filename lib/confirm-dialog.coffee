{View} = require 'atom-space-pen-views'
utils = require './utils'
fs = require 'fs-plus'
EVNDPreviewView = null

{Emitter, Disposable, CompositeDisposable} = require 'atom'

module.exports =
class ConfirmDialog extends View
  @content: ->
    @div class: 'note-confirm-dialog padded inset-panel', =>
      @div class: 'padded inset-panel-body', =>
        @span class: 'text-highlight big-text',
          'Note content updated, please check if this update is valid, if so please press "Confirm" to save the changes. Otherwise please press "Revert" to go back to the last saved version.'
        @div class: 'note-info-buttons pull-right', =>
          @button class: 'note-info-button', click: 'confirmChange', =>
            @i class: 'icon icon-check'
            @span 'Confirm'
          @button class: 'note-info-button', click: 'revertChange', =>
            @i class: 'icon icon-x'
            @span 'Revert'
          @button class: 'note-info-button', click: 'cancel', =>
            @i class: 'icon icon-x'
            @span 'Cancel'

  constructor: ({@editorId, @filePath, @note, @oldText, @newText, @newNoteInfo}) ->
    super
    @emitter ?= new Emitter
    @disposables ?= new CompositeDisposable

    if @editorId?
      @resolveEditor(@editorId)
    else if @filePath?
      if atom.workspace?
        @subscribeToFilePath(@filePath)
      else
        @disposables.add atom.packages.onDidActivateInitialPackages =>
          @subscribeToFilePath(@filePath)

  initialize: ->
    @emitter ?= new Emitter
    @disposables ?= new CompositeDisposable
    if @editorId?
      @resolveEditor(@editorId)
    else if @filePath?
      if atom.workspace?
        @subscribeToFilePath(@filePath)
      else
        @disposables.add atom.packages.onDidActivateInitialPackages =>
          @subscribeToFilePath(@filePath)

  serialize: ->

  cancel: ->
    @destroy()

  destroy: ->
    @panel?.destroy()

  show: ->
    @panel ?= atom.workspace.addBottomPanel item: this
    @panel.show()

  confirmChange: ->
    unless @editor?
      @initialize()
      utils.timeOut(500)
    try
      @editor.save()
      text = @editor.getText()
      previewView = @getPreviewViewForEditor(@editor)
      if previewView? and not previewView.loading
        html = previewView[0].innerHTML
        css = previewView.getMarkdownPreviewCSS()
        updateContent =
          text: text
          rawHTML: html
          css: css
        for k, v of @newNoteInfo
          updateContent[k] = v
        @note.update(window.evnd.storageManager, updateContent)
        @note.setSyncdContent()
        @note.modificationTime = utils.enDateToTimeString(@note.enModificationDate)
        @note.lastSyncDate = @note.enModificationDate
        commitMsg = "Pulled note #{@note.title} from Evernote client!\n"
        commitMsg += "#{@note.summary()}\n"
        window.evnd.storageManager.addNote(@note, true, commitMsg)
        @cancel()
      else
        @note.updateMarkdown @editor.getText(), null,
          @editor.getGrammar(), false, () =>
            @note.setSyncdContent()
            # TODO: commit?
            newDateStr = utils.timeStrToENDate(utils.getCurrentTimeString())
            window.evnd.enHelper.setModificationDate @note, newDateStr, () =>
              # TODO: set modification Time on the Evernote side?
              @note.lastSyncDate = @note.enModificationDate
              commitMsg = "Pulled note #{@note.title} from Evernote client!\n"
              commitMsg += "#{@note.summary()}\n"
              window.evnd.storageManager.addNote(@note, true, commitMsg)
              @cancel()
    catch e
      console.error e

  revertChange: ->
    unless @editor?
      @initialize()
      utils.timeOut(500)
    @editor.setText(@oldText)
    @cancel()

  getPreviewViewForEditor: (editor) ->
    uri = @uriForEditor(editor)
    previewPane = atom.workspace.paneForURI(uri)
    if previewPane?
      evndPreviewView = previewPane.itemForURI(uri)
      return evndPreviewView if @isEVNDPreviewView(evndPreviewView)
    return null

  uriForEditor: (editor) ->
    "ever-notedown-preview://editor/#{editor.id}"

  isEVNDPreviewView: (object) ->
    EVNDPreviewView ?= require './ever-notedown-preview-view'
    object instanceof EVNDPreviewView

  resolveEditor: (editorId) ->
    resolve = =>
      @editor = @editorForId(editorId)

      if @editor?
        @emitter.emit 'did-change-title' if @editor?
        #@handleEvents()
      else
        # The editor this preview was created for has been closed so close
        # this preview since a preview cannot be rendered without an editor
        @parents('.pane').view()?.destroyItem(this)

    if atom.workspace?
      resolve()
    else
      @disposables.add atom.packages.onDidActivateInitialPackages(resolve)

  editorForId: (editorId) ->
    for editor in atom.workspace.getTextEditors()
      return editor if editor.id?.toString() is editorId.toString()
    null

  subscribeToFilePath: (filePath) ->
    @file = new File(filePath, false)
    @emitter.emit 'did-change-title'
