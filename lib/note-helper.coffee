fs =  require 'fs-plus'
utils = require './utils'
path = require 'path'
cheerio = null # delayed require 'cheerio'
renderer = null # delayed require './renderer'
toMarkdown = null #
{File} = require 'pathwatcher'
{Note} = require './note-prototypes/note-base'
{RichNote} = require './note-prototypes/note-rich'
{MarkdownNote} = require './note-prototypes/note-markdown'
{HTMLNote} = require './note-prototypes/note-html'
{TextNote} = require './note-prototypes/note-text'

findNote = (noteIndex, {title, id, noteLink, filePath, fnStem, dir} = {}) ->
  return null unless noteIndex and (title? or filePath? or id? or fnStem?)
  noteIndexJSON = noteIndex.jsonOBJ
  notes = noteIndex.notes
  if noteLink?
    for noteKey, noteOBJ of notes
      if noteLink is noteOBJ.noteLink then return noteOBJ
    for noteKey, noteOBJ of noteIndexJSON
      if noteLink is noteOBJ.noteLink
        noteOBJ.reconstruct = true
        switch noteOBJ.format
          when "Text" then return new TextNote(noteOBJ)
          when "HTML" then return new HTMLNote(noteOBJ)
          else return new MarkdownNote(noteOBJ)
  else if (dir? and fnStem?) or filePath?
    unless fnStem?
      extName = path.extname(filePath)
      fnStem = path.basename(filePath, extName)
    unless dir?
      dir = path.basename(path.dirname(filePath))
    for noteKey, noteOBJ of notes
      if fnStem is noteOBJ.fnStem and dir?.replace(/\/$/, '') is noteOBJ.dir?.replace(/\/$/, '')
        return noteOBJ
    for noteKey, noteOBJ of noteIndexJSON
      if fnStem is noteOBJ.fnStem and dir?.replace(/\/$/, '') is noteOBJ.dir?.replace(/\/$/, '')
        noteOBJ.reconstruct = true
        switch noteOBJ.format
          when "Text" then return new TextNote(noteOBJ)
          when "HTML" then return new HTMLNote(noteOBJ)
          else return new MarkdownNote(noteOBJ)
  else if id?
    for noteKey, noteOBJ of notes
      if id is noteOBJ.id then return noteOBJ
    for noteKey, noteOBJ of noteIndexJSON
      if id is noteOBJ.id
        noteOBJ.reconstruct = true
        switch noteOBJ.format
          when "Text" then return new TextNote(noteOBJ)
          when "HTML" then return new HTMLNote(noteOBJ)
          else return new MarkdownNote(noteOBJ)
  else
    trimTitle = title.trim()
    for noteKey, noteOBJ of notes
      if trimTitle is noteOBJ.title.trim() then return noteOBJ
    for noteOBJ in noteIndexJSON
      if noteOBJ.title.trim() is trimTitle
        noteOBJ.reconstruct = true
        switch noteOBJ.format
          when "Text" then return new TextNote(noteOBJ)
          when "HTML" then return new HTMLNote(noteOBJ)
          else return new MarkdownNote(noteOBJ)
  return null


class NoteIndex
  constructor: (options = {}) ->
    @jsonOBJ = options.jsonOBJ ? null
    @notes = options.notes ? {}
    @absfilename = options.absfilename
    @file = options.file ? null
    if @absfilename?
      @file ?= new File(@absfilename, false)
    else if @file?
      @absfilename = @file.getRealPathSync()
    else
      gitPath = atom.config.get('ever-notedown.gitPath')
      gitPathSymlink = atom.config.get('ever-notedown.gitPathSymlink')
      filename = path.join(gitPath, "index.json")
      @file = new File(filename, gitPathSymlink)
      @absfilename = @file.getRealPathSync()

  stringify: () ->
    filter = (key, value) ->
      if key in ["text", "html", "enml", "rawHTML", "css", "syncdContent"]
        return null
      else
        return value
    JSON.stringify(@jsonOBJ, filter, 4)

  addnote: (note) ->
    @notes[note.id] = note
    @jsonOBJ[note.id] = note

  update: () ->
    @file.write(@stringify())

  removeNote: (note) ->
    if @notes[note.id]? then delete @notes[note.id]
    if @jsonOBJ[note.id]? then delete @jsonOBJ[note.id]

  makeTree: () ->
    notebookCollection =
      "Default Notebook (unnamed)": []
    for k, v of @jsonOBJ
      if v.notebook?.name of notebookCollection
        notebookCollection[v.notebook.name].push(v)
      else if v.notebook?.name
        notebookCollection[v.notebook.name] = [v]
      else
        notebookCollection["Default Notebook (unnamed)"].push(v)

    return notebookCollection


module.exports =
  findNote: findNote
  NoteIndex: NoteIndex
  MarkdownNote: MarkdownNote
  HTMLNote: HTMLNote
  TextNote: TextNote

