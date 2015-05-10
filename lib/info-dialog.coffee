{Emitter, Disposable, CompositeDisposable} = require 'atom'
{$, View} = require 'atom-space-pen-views'
utils = require './utils'
fs = require 'fs-plus'
ConfirmDialog = null
EVNDPreviewView = null
Note = null

module.exports =
class InfoDialog extends View
  @content: ->
    @div class: 'note-info-dialog padded float', =>
      @div class: 'heading', =>
        @i class: 'pull-right icon icon-x clickable dialog-button', click: 'cancel'
        @span class: 'text-highlight note-info-title', "Note Info"
        @span style: 'margin: 5px 5px;'
        @span class: 'badge badge-info', outlet: 'noteFormat'
      @div class: 'body', =>
        @div class: 'block note-time-info', =>
          @div class: 'block', =>
            @span class: 'icon icon-book text-highlight bold', outlet: 'notebook'
            @span style: 'margin: 8px 8px;', ""
            @span class: 'icon icon-tag text-highlight', ""
            @ul class: 'note-tags', outlet: 'noteTags'
          @div class: 'block', =>
            @span class: 'icon icon-pencil text-info'
            @span class: 'bold text-info', outlet: "noteTitle"
          @div class: 'block', =>
            @span class: 'property-name inline-block highlight-success', "Note last sync'd with Evernote on: "
            @span class: 'property-val text-highlight bold underlined', outlet: 'lastSyncTime'
          @div class: 'block', =>
            @span class: 'property-name inline-block highlight-info', "Note last modified in Evernote on: "
            @span class: 'property-val text-highlight', outlet: 'enModificationTime'
            @span style: 'margin-left: 8px;', outlet: 'enModifiedCheck'
          @div class: 'block', =>
            @span class: 'property-name inline-block highlight-warning', "Local note file last modified on: "
            @span class: 'property-val text-highlight', outlet: 'fileModificationTime'
            @span style: 'margin-left: 8px;', outlet: 'localModifiedCheck'
        @div class: 'block note-preview', =>
        #  @textarea outlet: 'notePreview'
        #@div class: 'block note-summary', =>
          @table style: "overflow-y:scroll;height:220px;margin-left:auto;margin-right:auto;border-collapse:separate;border-spacing:10px 0", =>
            @tbody =>
              @tr =>
                @td class:'table-content', style:"vertical-align:top; width:250px", =>
                  @ul =>
                    @li title:'Notebook (EVND)', =>
                      @span class:'fa fa-book', outlet: 'localNotebook'
                    @li title:'Title (EVND)', =>
                      @span class:'fa fa-pencil', outlet: 'localTitle'
                    @li title:'Tags (EVND)', =>
                      @ul class:'note-tags fa fa-tags', outlet: 'localTags'
                    @li title:'Attachments (EVND)', =>
                      @span class:'fa fa-paperclip', title:'Attachment Count (EVND)', outlet: 'localAttachmentCount'
                      @ul class:'attachments-info', =>
                        @li title:'Attachment-images (EVND)', id:'localImages', =>
                          @span class:'fa fa-image', outlet:'localImagesCount'
                          @ul class:'attachments-info-sub', =>
                            @li id:'localMathjax', =>
                              @span outlet:'localMathjaxCount'
                              @ul class:'attachments-info-sub2', outlet:'localMathjax'
                            @li id:'localIcons', =>
                              @span outlet:'localIconsCount'
                              @ul class:'attachments-info-sub2', outlet:'localIcons'
                            @li id:'localOtherImages', =>
                              @span outlet:'localOtherImagesCount'
                              @ul class:'attachments-info-sub2', outlet:'localOtherImages'
                        @li title:'Attachments-PDF (EVND)', id:'localPDFs', =>
                          @span class:'fa fa-file-pdf-o', outlet:'localPDFsCount'
                          @ul class:'attachments-info-sub2', outlet:'localPDFs'
                        @li title:'Attachments-Audio (EVND)', id:'localAudios', =>
                          @span class:'fa fa-file-audio-o', outlet:'localAudiosCount'
                          @ul class:'attachments-info-sub2', outlet:'localAudios'
                        @li title:'Attachments-Others (EVND)', id:'localOthers', =>
                          @span class:'fa fa-file-o', outlet:'localOthersCount'
                          @ul class:'attachments-info-sub2', outlet:'localOthers'
                @td style:"vertical-align:top", =>
                  @hr class:'vertical'
                @td class:'table-content', style:"vertical-align:top; width:250px", =>
                  @ul =>
                    @li title:'Notebook (Evernote)', =>
                      @span class:'fa fa-book', outlet: 'enNotebook'
                    @li title:'Title (Evernote)', =>
                      @span class:'fa fa-pencil', outlet: 'enTitle'
                    @li title:'Tags (Evernote)', =>
                      @ul class:'note-tags fa fa-tags', outlet: 'enTags'
                    @li title:'Attachments (Evernote)', =>
                      @span class:'fa fa-paperclip', title:'Attachment Count (Evernote)', outlet: 'enAttachmentCount'
                      @ul class:'attachments-info', =>
                        @li title:'Attachment-images (Evernote)', id:'enImages', =>
                          @span class:'fa fa-image', outlet:'enImagesCount'
                          @ul class:'attachments-info-sub', =>
                            @li id:'enMathjax', =>
                              @span outlet:'enMathjaxCount'
                              @ul class:'attachments-info-sub2', outlet:'enMathjax'
                            @li id:'enIcons', =>
                              @span outlet:'enIconsCount'
                              @ul class:'attachments-info-sub2', outlet:'enIcons'
                            @li id:'enOtherImages', =>
                              @span outlet:'enOtherImagesCount'
                              @ul class:'attachments-info-sub2', outlet:'enOtherImages'
                        @li title:'Attachments-PDF (Evernote)', id:'enPDFs', =>
                          @span class:'fa fa-file-pdf-o', outlet:'enPDFsCount'
                          @ul class:'attachments-info-sub2', outlet:'enPDFs'
                        @li title:'Attachments-Audio (Evernote)', id:'enAudios', =>
                          @span class:'fa fa-file-audio-o', outlet:'enAudiosCount'
                          @ul class:'attachments-info-sub2', outlet:'enAudios'
                        @li title:'Attachments-Others (Evernote)', id:'enOthers', =>
                          @span class:'fa fa-file-o', outlet:'enOthersCount'
                          @ul class:'attachments-info-sub2', outlet:'enOthers'
        @div class: 'block note-info-buttons', =>
          @button class: 'note-info-button', id: 'pull-note-button', click: 'pullNote', =>
            @span 'Pull'
            @i class: 'icon icon-arrow-down'
          @button class: 'note-info-button', id: 'open-note-button',  click: 'openNote', =>
            @span 'Open'
            @i class: 'icon icon-pencil'
          @button class: 'note-info-button', click: 'cancel', =>
            @span 'Cancel'
            @i class: 'icon icon-x'
          @button class: 'pull-right note-info-button', id:'delete-note-button', click: 'delete', =>
            @span class: 'text-error', 'Delete'
            @i class: 'icon icon-trashcan text-error'

  @constructor: () ->
    super
    @emitter = new Emitter
    @disposables = new CompositeDisposable

  addInfo: (note, noteInfo, noteAttachmentsInfo) ->
    @emitter ?= new Emitter
    @disposables ?= new CompositeDisposable
    @note = note
    @evNotedown = window.evnd
    @notebook.text(note.notebook?.name ? "<Default Notebook>")
    @localNotebook.text(note?.notebook?.name)
    @enNotebook.text(noteInfo?.notebook?.name)
    if note.notebook.name?.toLowerCase() isnt noteInfo.notebook.name?.toLowerCase()
      @localNotebook.addClass("text-error")
      @enNotebook.addClass("text-warning")
    for tag, i in noteInfo?.tags
      noteInfo.tags[i] = tag?.toLowerCase()
    for tag, i in note.tags
      tag = tag?.toLowerCase()
      note.tags[i] = tag
      @noteTags.append("<li class=\"badge note-tag\">#{tag}</li>")
      if tag in noteInfo.tags
        @localTags.append("<li class=\"note-tag\">#{tag}</li>")
        @enTags.append("<li class=\"note-tag\">#{tag}</li>")
      else
        @localTags.append("<li class=\"text-error note-tag\">#{tag}</li>")
    for tag in noteInfo?.tags
      if tag isnt "DummyTag" and not (tag in note.tags)
        @enTags.append("<li class=\"text-warning note-tag\">#{tag}</li>")
    @noteFormat.text(note.format ? "Markdown")
    @noteTitle.text("Title: #{note.title ? "N/A"}")
    @localTitle.text(note.title)
    @enTitle.text(noteInfo.title)
    if note.title isnt noteInfo.title
      @localTitle.addClass("text-error")
      @enTitle.addClass("text-warning")
    if note?.lastSyncDate?
      lastSyncTimeStr = utils.enDateToTimeString(note.lastSyncDate)
      @lastSyncTime.text(lastSyncTimeStr)
    else
      @lastSyncTime.text("N/A")
    if noteInfo?.enModificationDate?
      conflictStatus = @note.checkConflict(noteInfo)
      @enModificationTime.text(conflictStatus.enModificationTime)
      if conflictStatus.unsyncdModificationInEvernote
        @enModifiedCheck.addClass("text-error icon icon-alert")
        @enConflict = true
        #@enModifiedCheck.text("Modification done in the Evernote client hasn't been sync'd.")
      else
        @enModifiedCheck.addClass("text-success icon icon-check")
        @enConflict = false
      @enModifiedCheck.text(" ")
    else
      @enModificationTime.text("N/A")
    if fs.isFileSync(note?.absPath())
      @fileModificationTime.text(conflictStatus?.modificationTime)
      if conflictStatus?.unsyncdModificationInAtomEVND
        @localModifiedCheck.addClass("text-error icon icon-alert")
        @localConflict = true
        #@localModifiedCheck.text("Modification done in Atom hasn't been sync'd.")
      else
        @localModifiedCheck.addClass("text-success icon icon-check")
        @localConflict = false
      @localModifiedCheck.text(" ")
    else
      @fileModificationTime.text("N/A")

    localSummary = note.attachmentsSummary(noteAttachmentsInfo)
    {Note} = require './note-prototypes/note-base' unless Note?
    enSummary = Note.attachmentsInfoSummary(noteAttachmentsInfo)
    localSummary = Note.compareAttachmentsInfoSummary(localSummary, enSummary)
    enSummary = Note.compareAttachmentsInfoSummary(enSummary, localSummary)
    localSummary = Note.attachmentsInfoSummaryToHTML(localSummary, "text-error")
    enSummary = Note.attachmentsInfoSummaryToHTML(enSummary, "text-warning")

    @localAttachmentCount.text("Attachments: #{localSummary.count}")
    if not localSummary.allMatched
      @localAttachmentCount.addClass('text-error')
    @localImagesCount.text("images: #{localSummary.images.count}")
    if not localSummary.images.allMatched
      @localImagesCount.addClass('text-error')
    @localMathjaxCount.text("mathjax: #{localSummary.images.mathjax.count}")
    if not localSummary.images.mathjax.allMatched
      @localMathjaxCount.addClass('text-error')
    @localMathjax.append(localSummary.images.mathjax.html)
    @localIconsCount.text("icons: #{localSummary.images.icon.count}")
    if not localSummary.images.icon.allMatched
      @localIconsCount.addClass('text-error')
    @localIcons.append(localSummary.images.icon.html)
    @localOtherImagesCount.text("other images: #{localSummary.images.others.count}")
    if not localSummary.images.others.allMatched
      @localOtherImagesCount.addClass('text-error')
    @localOtherImages.append(localSummary.images.others.html)
    @localPDFsCount.text("pdfs: #{localSummary.pdfs.count}")
    if not localSummary.pdfs.allMatched
      @localPDFsCount.addClass('text-error')
    @localPDFs.append(localSummary.pdfs.html)
    @localAudiosCount.text("audios: #{localSummary.audios.count}")
    if not localSummary.audios.allMatched
      @localAudiosCount.addClass('text-error')
    @localAudios.append(localSummary.audios.html)
    @localOthersCount.text("other attachments: #{localSummary.others.count}")
    if not localSummary.others.allMatched
      @localOthersCount.addClass('text-error')
    @localOthers.append(localSummary.others.html)

    @enAttachmentCount.text("Attachments: #{enSummary.count}")
    if not enSummary.allMatched
      @enAttachmentCount.addClass('text-warning')
    @enImagesCount.text("images: #{enSummary.images.count}")
    if not enSummary.images.allMatched
      @enImagesCount.addClass('text-warning')
    @enMathjaxCount.text("mathjax: #{enSummary.images.mathjax.count}")
    if not enSummary.images.mathjax.allMatched
      @enMathjaxCount.addClass('text-warning')
    @enMathjax.append(enSummary.images.mathjax.html)
    @enIconsCount.text("icons: #{enSummary.images.icon.count}")
    if not enSummary.images.icon.allMatched
      @enIconsCount.addClass('text-warning')
    @enIcons.append(enSummary.images.icon.html)
    @enOtherImagesCount.text("other images: #{enSummary.images.others.count}")
    if not enSummary.images.others.allMatched
      @enOtherImagesCount.addClass('text-warning')
    @enOtherImages.append(enSummary.images.others.html)
    @enPDFsCount.text("pdfs: #{enSummary.pdfs.count}")
    if not enSummary.pdfs.allMatched
      @enPDFsCount.addClass('text-warning')
    @enPDFs.append(enSummary.pdfs.html)
    @enAudiosCount.text("audios: #{enSummary.audios.count}")
    if not enSummary.audios.allMatched
      @enAudiosCount.addClass('text-warning')
    @enAudios.append(enSummary.audios.html)
    @enOthersCount.text("other attachments: #{enSummary.others.count}")
    if not enSummary.others.allMatched
      @enOthersCount.addClass('text-warning')
    @enOthers.append(enSummary.others.html)

    @.find('.attachments-info > li > span').on 'click', (e) ->
      $(@).parent().children('.attachments-info-sub, .attachments-info-sub2').each () ->
        if $(@).is(":visible")
          $(@).hide(150)
        else
          $(@).show(150)
    @.find('.attachments-info-sub > li > span').on 'click', (e) ->
      $(@).parent().find('.attachments-info-sub2').each () ->
        if $(@).is(":visible")
          $(@).hide(150)
        else
          $(@).show(150)
    @.find('.attachments-info > li').each () ->
      $(@).find('ul').each () ->
        $(@).hide()


  serialize: ->

  cancel: ->
    @destroy()

  destroy: ->
    @disposables?.dispose()
    @panel?.destroy()

  show: ->
    @panel ?= atom.workspace.addModalPanel item: this
    @panel?.className = "floating"
    for i in [0..@panel.item[0].parentElement.classList.length-1]
      klass = @panel.item[0].parentElement.classList[i]
      if klass?.indexOf("from") > -1
        @panel.item[0].parentElement.classList.remove(klass)
    #unless @panel.item[0].parentElement.classList.contains("floating")
    #  @panel.item[0].parentElement.classList.add("floating")
    unless @panel.item[0].parentElement.classList.contains("note-info-dialog-panel")
      @panel.item[0].parentElement.classList.add("note-info-dialog-panel")
    @panel.show()

  on: (eventName) ->
    super

  openNote: ->
    return unless @note? and @evNotedown?
    if @enConflict and @localConflict
      atom.confirm
        message: "Conflicting changes!"
        detailedMessage: "Not sure what to do..."
        buttons:
          "Open local note anyway": =>
            @openNoteInEditor()
            @cancel()
          "Cancel": => return
    else if @enConflict
      atom.confirm
        message: "This note has unsync'd changes made in the Evernote client"
        detailedMessage: "Are you sure you don't want to \"pull\" (update local note with content from the Evernote client) first?"
        buttons:
          "Alright, pull first": => @pullNote()
          "Open local note anyway": =>
            @openNoteInEditor()
            @cancel()
          "Cancel": => return
    else
      @openNoteInEditor()
      @cancel()

  onDidPullNote: (callback) ->
    @emitter.on 'did-pull-note', callback

  pullNote: ->
    return unless @note?
    @emitter.emit 'did-pull-note', @note.id
    @cancel()
    # TODO: what if note.format isn't "Markdown"?

  openNoteInEditor: () ->
    @emitter.emit 'did-open-note', @note.id
    # TODO: What if the current note isn't of format "Markdown"?

  onDidOpenNote: (callback) ->
    @emitter.on 'did-open-note', callback

  delete: () ->
    @emitter.emit 'did-click-delete-note', @note.id
    @cancel()

  onDidClickDelete: (callback) ->
    @emitter.on 'did-click-delete-note', callback
