fs =  require 'fs-plus'
utils = require './../utils'
path = require 'path'
renderer = null # delayed require './renderer'
{RichNote} = require './note-rich'

class MarkdownNote extends RichNote
  constructor: (options={}) ->
    super(options)
    @format = "Markdown"
    reconstruct = options.reconstruct ? false
    if reconstruct
      markdownFilename = path.join(@path, "#{@fnStem}.markdown")
      if fs.isFileSync(markdownFilename)
        defaultText = fs.readFileSync(markdownFilename, 'utf8')
      else
        defaultText = null
      rawHTMLFilename = path.join(@path, "#{@fnStem}_plain.html")
      if fs.isFileSync(rawHTMLFilename)
        defaultRawHTML = fs.readFileSync(rawHTMLFilename, 'utf8')
      else
        defaultRawHTML = null
      htmlFilename = path.join(@path, "#{@fnStem}.html")
      if fs.isFileSync(htmlFilename)
        defaultHTML = fs.readFileSync(htmlFilename, 'utf8')
      else
        defaultHTML = null
      enmlFilename = path.join(@path, "#{@fnStem}.enml")
      if fs.isFileSync(enmlFilename)
        defaultENML = fs.readFileSync(enmlFilename, 'utf8')
      else
        defaultENML = null
      cssFilename = path.join(@path, "#{@fnStem}_style.css")
      if fs.isFileSync(cssFilename)
        defaultCSS = fs.readFileSync(cssFilename, 'utf8')
      else
        defaultCSS = null
      syncdFilename = path.join(@path, "#{@fnStem}_syncd.txt")
      if fs.isFileSync(syncdFilename)
        defaultSyncdContent = fs.readFileSync(syncdFilename, 'utf8')
      else
        defaultSyncdContent = null
    else
      defaultText = "Hello World!"
      defaultRawHTML = "<p>Hello World!</p>"
      defaultHTML = "<p>Hello World!</p>"
      defaultENML = "<p>Hello World!</p>"
      defaultCSS = null
      defaultSyncdContent = null
    @text = options.text ? defaultText
    @html = options.html ? defaultHTML
    @rawHTML = options.rawHTML ? defaultRawHTML
    @enml = options.enml ? defaultENML
    @css = options.css ? defaultCSS
    @syncdContent = options.syncdContent ? defaultSyncdContent
    # unique identifying string
    @id = options.id ? "[Note ID: #{utils.stringMD5(@creationTime + @getContent())}]"
    @tidy()
    @header = options.header ? @htmlHeader()
    @queryString = options.queryString ? @makeQueryString()
    @renderOptions = options.renderOptions ? {'mathjax':true}
    @contentMD5 = utils.stringMD5(@getContent())
    if reconstruct
      absPath = @absPath()
      if fs.isFileSync(absPath) and @contentMD5 isnt options.contentMD5
        @modificationTime = utils.mtimeToTimeString(fs.statSync(absPath)["mtime"])

  getContent: () ->
    return @text

  setContent: (newContent, dontChangeTime=false) ->
    if newContent isnt @text
      @text = newContent
      @modificationTime = utils.getCurrentTimeString() unless dontChangeTime

  absPath: () ->
    return path.join @path, @fnStem + ".markdown"

  updateMarkdown: (newText, renderOptions, grammar, dontChangeTime, callback) ->
    return if newText is @text and not renderOptions?
    renderOptions ?= null
    grammar ?= null
    dontChangeTime ?= false
    renderer ?= require './../renderer'
    if renderOptions isnt null then @renderOptions = renderOptions
    newMetaInfo = utils.parseMetaData(newText)
    renderer.toDOMFragment newText, @renderOptions.mathjax, @path,
      newMetaInfo, grammar, (domFragment) =>
        @rawHTML = domFragment.outerHTML
        @text = newText
        @tidy()
        @modificationTime = utils.getCurrentTimeString() unless dontChangeTime
        callback()

  update: (storageManager, options={}) ->
    storageManager ?= null
    dontChangeTime = options.dontChangeTime ? false
    if storageManager? then storageManager.addNote @, false, null

    contentUpdated = false
    if options.css? and options.css isnt @css
      @css = options.css
      contentUpdated = true
      toTidy = true
    # Meta info problem: possible conflicts of options.<keyword> and
    # the block of meta info defined in the text?
    if options.text? and (options.text isnt @syncdContent)
      contentUpdated = true
      if options.rawHTML?
        @rawHTML = options.rawHTML
        @text = options.text
        @setMetaData({metaText: options.text})
        toTidy = true
      else
        renderOptions = options.renderOptions ? @renderOptions
        @updateMarkdown(options.text, renderOptions, dontChangeTime)
        toTidy = false
    if options.notebook? then notebookUpdated = @updateNotebook(options.notebook, dontChangeTime)
    if options.tags? then tagsUpdated = @updateTags(options.tags, false, dontChangeTime)
    noteUpdated = notebookUpdated or tagsUpdated or contentUpdated
    metaUpdated = false
    for k, v of options
      if v? and v isnt "missing value" and typeof @[k] isnt "function"
        continue if k in ["text", "rawHTML", "tags", "notebook", "css"]
        continue if JSON.stringify(@[k]) is JSON.stringify(v)
        @[k] = v
        noteUpdated = true unless k is "renderOptions" and options.rawHTML?
        if k in ["title", "metaDate"] then metaUpdated = true

    if metaUpdated then @setMetaText()
    if contentUpdated and toTidy then @tidy()
    if storageManager? then noteModified = storageManager.addNote @, false, null
    @modificationTime = utils.getCurrentTimeString() unless dontChangeTime or (not noteUpdated)
    return noteUpdated

  setSyncdContent: (newContent) =>
    if newContent?
      @setContent(newContent, true)
      @syncdContent = @getContent()
    else
      @syncdContent = @getContent()

module.exports =
  MarkdownNote: MarkdownNote
