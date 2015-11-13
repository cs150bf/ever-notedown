fs =  require 'fs-plus'
utils = require './../utils'
path = require 'path'
mime = require 'mime'
{File, Directory} = require 'atom'
cheerio = null
toMarkdown = null
markdownCleanUp = null

getRealGitPath = ->
  if window.evnd?.storageManager?.gitDir?
    return window.evnd.storageManager.gitDir.getRealPathSync()
  gitPath = atom.config.get('ever-notedown.gitPath')
  gitPathSymlink = atom.config.get('ever-notedown.gitPathSymlink')
  gitDir = new Directory(gitPath, gitPathSymlink)
  return gitDir.getRealPathSync()

class Note
  constructor: (options={}) ->
    @creationTime = options.creationTime ? utils.getCurrentTimeString()
    @enCreationDate = options.enCreationDate ? null
    @lastSyncDate = options.lastSyncDate ? null
    @enModificationDate = options.enModificationDate ? null
    @modificationTime = options.modificationTime ? utils.getCurrentTimeString()
    @metaDate = options.metaDate ? null
    gitPath = getRealGitPath()
    if options.dir?
      @dir = options.dir
    else if options.path? and options.path.indexOf(gitPath) > -1
      @dir = path.relative(gitPath, options.path)
    else
      tmpTimeString = utils.sanitizeTimeString(@creationTime)
      tmpIndex = tmpTimeString.indexOf('_')
      if tmpIndex > -1 then tmpTimeString = tmpTimeString.slice(0, tmpIndex)
      @dir = "#{tmpTimeString}/"
    if options.path? and options.path.indexOf(gitPath) > -1
      @path = options.path
    else
      @path = path.join gitPath, @dir
    fs.makeTreeSync path.join(@path, 'img/') # folder for images
    @title = options.title ? "EVND New Note"
    @noteLink = options.noteLink ? null
    @tags = options.tags ? ['EVND']
    @notebook = options.notebook ? null
    @enExportedFiles = options.enExportedFiles ? []
    @format = "Markdown" # will be overwritten
    moved = options.moved ? false
    @fnStem = options.fnStem ? Note.makeFilename(@title, @path, moved)
    @enml = null


  absPath: () ->
    return path.join @path, @fnStem + ".markdown"

  open: () ->
    atom.open options =
      pathsToOpen: @absPath()

  summary: () ->
    keySet = [
      "title",
      "path",
      "fnStem",
      "format",
      "id",
      "noteLink",
      "tags",
      "notebook",
      "queryString",
      "creationTime",
      "enCreationDate",
      "lastSyncDate",
      "enModificationDate",
      "modificationTime",
      "enExportedFiles"
    ]
    tmpOBJ = {}
    for key in keySet when @[key]?
      tmpOBJ[key] = @[key]
    if @attachments?
      tmpOBJ["attachments"] = {}
      for k, v of @attachments
        if v.active
          tmpOBJ["attachments"][k] =
            path: v.path,
            hash: v.info?.hash,
            mime: v.info?.mime,
            size: v.info?.size,
            md5: v.md5
    infostr = JSON.stringify(tmpOBJ, null, 4)
    return infostr

  updateNotebook: (newNotebook, dontChangeTime=false) ->
    if typeof newNotebook is 'string'
      newNotebookName = newNotebook.trim()
      newNotebookType = ""
    else
      newNotebookName = newNotebook.name?.trim() ? ""
      newNotebookType = newNotebook.type?.trim() ? ""
    notebookChanged = false
    if newNotebookName.length > 0 and newNotebookName isnt @notebook.name
      @notebook.name = newNotebookName
      notebookChanged = true
    if newNotebookType.length > 0 and newNotebookType isnt @notebook.type
      @notebook.type = newNotebookType
      notebookChanged = true
    if notebookChanged
      @setMetaText()
      @modificationTime = utils.getCurrentTimeString() unless dontChangeTime
      #console.log "Modified notebook on ... " + @modificationTime unless dontChangeTime
    return notebookChanged

  # TODO: case-insensitive?
  updateTags: (newTags, merge=false, dontChangeTime=false) ->
    tagChanged = false
    #console.log "Old tags: " + @tags
    #console.log "New tags: " + newTags
    for tag, i in @tags
      @tags[i] = tag.toLowerCase()
    for tag, i in newTags
      newTags[i] = tag.toLowerCase()
    if not merge
      for oldTag in @tags
        if not (oldTag in newTags)
          @tags.splice(@tags.indexOf(oldTag), 1)
          tagChanged = true
    for newTag in newTags
      newTag = newTag.trim()
      if newTag.length > 0 and not (newTag in @tags)
        @tags.push(newTag)
        tagChanged = true
    if tagChanged
      @setMetaText()
      @modificationTime = utils.getCurrentTimeString() unless dontChangeTime
      #console.log "Modified tags on ..." + @modificationTime unless dontChangeTime
    return tagChanged

  update: (storageManager, options={}) ->
    storageManager ?= null
    dontChangeTime = options.dontChangeTime ? false
    modified = false
    htmlModified = false
    toTidy = false
    oldMetaInfo = utils.parseMetaData(@text)
    oldHTML = @html
    if storageManager? then storageManager.addNote @, false, null
    for k, v of options
      if k is "notebook" and v?
        notebookChanged = @updateNotebook(v, dontChangeTime)
      else if k is "tags" and v?
        tagChanged = @updateTags(v, false, dontChangeTime)
      else if v? and (k of @) and (typeof @[k] isnt "function")
        if (JSON.stringify(v) is JSON.stringify(@[k])) then continue
        if k is "rawHTML" then toTidy = true
        updateLog = "Changed property #{k}"
        if not (k in ["html", "enml", "rawHTML", "text", "css"])
          updateLog += " from #{JSON.stringify(@[k], null, 4)} to #{JSON.stringify(v, null, 4)}"
        #console.log updateLog
        @[k] = v
        if k is "text" then newMetaInfo = utils.parseMetaData(v)

    if (not newMetaInfo?) and modified
      newMetaInfo = utils.parseMetaData(@getMetaText() + "\n\n")
    metaChanged = false
    if newMetaInfo?
      for k, v of newMetaInfo
        if k is "tags"
          metaChanged = v.sort() is oldMetaInfo.tags.sort()
        else if not (k in ["content", "endOfMetaLineNum"])
          metaChanged = v is oldMetaInfo[k]
        if metaChanged then break
      if metaChanged then @setMetaText()

    if toTidy
      @tidy()
      htmlModified = not @compareHTML(oldHTML, @html)
      #console.log("Comparing new and old @html (different?): " + htmlModified)
    if storageManager?
      noteModified = storageManager.addNote @, false, null
    noteModified = noteModified or modified or htmlModified
    #console.log("noteModified: " + noteModified)
    if noteModified and not dontChangeTime
      @modificationTime = utils.getCurrentTimeString()
      #console.log "Modified notes on ..." + @modificationTime
    return noteModified

  getMetaText: () ->
    metaStr = ""
    metaStr += "Title: #{@title}\n"
    if @notebook? then metaStr += "Notebook: #{@notebook.name}\n"
    if @tags?.length
      metaStr += "Tags: "
      for tag in @tags
        metaStr += "#{tag}, "
      metaStr = "#{metaStr.slice(0, metaStr.length-2)}\n"
    if @metaDate? then metaStr += "Date: #{@metaDate}\n"
    return metaStr

  setMetaData: ({metaText, metaInfo}={}) ->
    if not metaInfo? then metaInfo = utils.parseMetaData(metaText)
    if metaInfo.title? then @title = metaInfo.title
    if metaInfo.tags? then @tags = metaInfo.tags
    if metaInfo.date? then @metaDate = metaInfo.date
    if metaInfo.notebook? then @notebook.name = metaInfo.notebook

  setMetaText: (metaInfo = null) ->
    content = @parseMeta().content
    if metaInfo? then @setMetaData({metaInfo: metaInfo})
    metaText = @getMetaText()
    @setContent(metaText + content)

  metaTextFromNoteInfo: (noteInfo) ->
    metaStr = ""
    metaStr += "Title: #{noteInfo.title}\n"
    if noteInfo.notebook? then metaStr += "Notebook: #{noteInfo.notebook.name}\n"
    if noteInfo.tags?.length
      metaStr += "Tags: "
      for tag in noteInfo.tags
        continue if tag is "DummyTag"
        metaStr += "#{tag}, "
      metaStr = "#{metaStr.slice(0, metaStr.length-2)}\n"
    if noteInfo.subjectDate? then metaStr += "Date: #{noteInfo.subjectDate}\n"
    return metaStr

  # TODO: subject date?
  # TODO: case-insensitive match?
  checkMeta: (noteInfo) ->
    metaDifferent = false
    return metaDifferent unless noteInfo?
    if noteInfo.title isnt @title then metaDifferent = true
    if noteInfo.notebook?.name?
      if typeof @notebook is "string"
        notebookName = @notebook.trim()
      else
        notebookName = @notebook?.name
      if noteInfo.notebook.name isnt notebookName
        metaDifferent = true
    if noteInfo.tags?.length > 0
      for noteTag in noteInfo.tags
        continue if noteTag is "DummyTag"
        if not (noteTag in @tags)
          metaDifferent = true
          break
      for noteTag in @tags
        if not (noteTag in noteInfo.tags)
          metaDifferent = true
          break
    else if @tags?.length > 0
      metaDifferent = true
    #console.log "Checked meta info... meta different? " + metaDifferent
    return metaDifferent

  getContent: () ->
    return null

  setContent: () ->
    return null

  parseMeta: (options) ->
    lastSyncd = options?.lastSyncd ? false
    if lastSyncd
      content = @syncdContent
    else
      content = @getContent()
    metaInfo = utils.parseMetaData(content)
    return metaInfo

  tidy: ->
    return

  updateAttachmentsInfo: (newAttachmentsInfo) ->
    return unless newAttachmentsInfo?
    for k, v of newAttachmentsInfo
      filename = v.filename
      if @attachments[filename]?
        if @attachments[filename].md5 is v.hash
          @attachments[filename].info = v
          @attachments[filename].active = true
        else
          @attachments[v.hash] =
            path: null
            info: v
            active: true
            md5: v.hash
      else
        @attachments[filename] =
          path: null
          info: v
          active: true
          md5: v.hash
        #console.log("Entry #{k}: #{JSON.stringify(@attachments[k])}")
    for k, v of @attachments
      if v.info? and (not newAttachmentsInfo[v.md5]?) then v.active = false
    #console.log("Now the attachment infos are like...")
    #console.log(@attachments)

  attachmentsSummary: () ->
    summary =
      count: 0
      images: {count: 0, mathjax:{count:0}, icon:{count:0}, others:{count:0}}
      pdfs: {count: 0}
      audios: {count: 0}
      others: {count: 0}
    for k, attachment of @attachments when attachment.active is true
      summary.count += 1
      filename = path.basename(attachment.path)
      attachment.filename = filename
      attachment.mime = attachment.info?.mime ? mime.lookup(filename)
      if utils.isImage(filename)
        summary.images.count += 1
        if filename.slice(0, 3) is 'svg' # assume all images starting with 'svg' is mathjax
          summary.images.mathjax.count += 1
          summary.images.mathjax[k] = attachment
        else if filename.slice(0, 3) is 'fa_' or filename.slice(0, 5) is 'icon_'
          summary.images.icon.count += 1
          summary.images.icon[k] = attachment
        else
          summary.images.others.count += 1
          summary.images.others[k] = attachment
      else if utils.isPDF(filename)
        summary.pdfs.count += 1
        summary.pdfs[k] = attachment
      else if utils.isAudio(filename)
        summary.audios.count += 1
        summary.audios[k] = attachment
      else
        mimetype = attachment.mime
        if mimetype.indexOf('image') > -1
          summary.images.count += 1
          summary.images.others.count += 1
          summary.images.others[k] = attachment
        else if mimetype.indexOf('wav') > -1 or mimetype.indexOf('mp3') > -1
          summary.audios.count += 1
          summary.audios[k] = attachment
        else if mimetype.indexOf('pdf') > -1
          summary.pdfs.count += 1
          summary.pdfs[k] = attachment
        else
          summary.others.count += 1
          summary.others[k] = attachment

    return summary

  @attachmentsInfoSummary: (attachmentsInfo) ->
    summary =
      count: 0
      images: {count: 0, mathjax:{count:0}, icon:{count:0}, others:{count:0}}
      pdfs: {count: 0}
      audios: {count: 0}
      others: {count: 0}
    for k, attachment of attachmentsInfo
      summary.count += 1
      filename = attachment.filename
      if filename? and filename.indexOf('.') > -1
        sortWithMime = false
        if utils.isImage(filename)
          summary.images.count += 1
          if filename.slice(0, 3) is 'svg' # assume all images starting with 'svg' is mathjax
            summary.images.mathjax.count += 1
            summary.images.mathjax[k] = attachment
          else if filename.slice(0, 3) is 'fa_' or filename.slice(0, 5) is 'icon_'
            summary.images.icon.count += 1
            summary.images.icon[k] = attachment
          else
            summary.images.others.count += 1
            summary.images.others[k] = attachment
          #images[k] = attachment
        else if utils.isPDF(filename)
          summary.pdfs.count += 1
          summary.pdfs[k] = attachment
        else if utils.isAudio(filename)
          summary.audios.count += 1
          summary.audios[k] = attachment
        else
          sortWithMime = true
      else
        sortWithMime = true

      if sortWithMime
        mimetype = attachment.mime
        if mimetype.indexOf('image') > -1
          summary.images.count += 1
          summary.images.others.count += 1
          summary.images.others[k] = attachment
        else if mimetype.indexOf('wav') > -1 or mimetype.indexOf('mp3') > -1
          summary.audios.count += 1
          summary.audios[k] = attachment
        else if mimetype.indexOf('pdf') > -1
          summary.pdfs.count += 1
          summary.pdfs[k] = attachment
        else
          summary.others.count += 1
          summary.others[k] = attachment

    return summary

  @attachmentInfoToHTML: (attachment, filename, unmatchedClass) ->
    unless filename?
      if attachment.filename? then filename = attachment.filename
      else if attachment.path? then filename = path.basename(attachment.path)
      else
        filename = ""
    unmatchedClass ?= "text-error"
    filePath = attachment.path ? "N/A"
    title = "Path: #{filePath}\nMD5: #{attachment.md5 ? attachment.hash}"
    if attachment.matchFound
      html = "<li title=\"#{title}\">"
    else
      html = "<li title=\"#{title}\" class=\"#{unmatchedClass}\">"
    html += "<u>filename</u>: #{filename}<br/><u>mime type</u>: #{attachment.mime}</li>"
    return html

  @attachmentsInfoSummaryToHTML: (summary, unmatchedClass) ->
    return unless summary?
    unmatchedClass ?= "text-error"
    for k, v of summary
      continue if k in ["count", "html", "allMatched", "matchFound"]
      if k is "images"
        for k1, v1 of v
          tmpHTML = ""
          continue if k1 in ["count", "html", "allMatched", "matchFound"]
          for k2, v2 of v1
            continue if k2 in ["count", "html", "allMatched", "matchFound"]
            tmpHTML += Note.attachmentInfoToHTML(v2, v2.filename, unmatchedClass)
          summary[k][k1].html = tmpHTML
      else
        tmpHTML = ""
        for k1, v1 of v
          continue if k1 in ["count", "html", "allMatched", "matchFound"]
          tmpHTML += Note.attachmentInfoToHTML(v1, v1.filename, unmatchedClass)
        summary[k].html = tmpHTML

    return summary

  @compareAttachmentsInfoSummary: (summary0, summary1) ->
    summary0.allMatched = true
    for k, v of summary0
      continue if k in ["count", "html", "allMatched", "matchFound"]
      summary0[k].allMatched = true
      if k is "images"
        for k1, v1 of v
          continue if k1 in ["count", "html", "allMatched", "matchFound"]
          summary0[k][k1].allMatched = true
          for k2, v2 of v1
            continue if k2 in ["count", "html", "allMatched", "matchFound"]
            hash0 = summary0[k][k1][k2].md5 ? summary0[k][k1][k2].hash
            summary0[k][k1][k2].matchFound = false
            for kt, vt of summary1[k][k1]
              continue if kt in ["count", "html", "allMatched", "matchFound"]
              tmpHASH = vt.md5 ? vt.hash
              if tmpHASH is hash0
                summary0[k][k1][k2].matchFound = true
                break
            if not summary0[k][k1][k2].matchFound
              summary0[k][k1].allMatched = false
          if not summary0[k][k1].allMatched
            summary0[k].allMatched = false
      else
        for k1, v1 of v
          continue if k1 in ["count", "html", "allMatched", "matchFound"]
          hash0 = summary0[k][k1].md5 ? summary0[k][k1].hash
          summary0[k][k1].matchFound = false
          for kt, vt of summary1[k]
            continue if kt in ["count", "html", "allMatched", "matchFound"]
            tmpHASH = vt.md5 ? vt.hash
            if tmpHASH is hash0
              summary0[k][k1].matchFound = true
              break
          if not summary0[k][k1].matchFound
            summary0[k].allMatched = false
      if not summary0[k].allMatched
        summary0.allMatched = false
    return summary0

  @openNote: (note) ->
    atom.open options =
      pathsToOpen: note.absPath()
      searchAllPanes: true

  @makeFilename: (title, filePath, moved) ->
    title ?= "Empty title"
    filePath ?= getRealGitPath()
    moved ?= false # are we moving the note from somewhere else?

    fnStem = utils.sanitizeFilename(title.toLowerCase())

    # TODO: What if the file is already in the evnd folder when created?
    #       If it's saved somewhere else, we'll need to avoid overwriting another note...
    if moved
      for fileExt in [".html", ".markdown", ".txt", "_raw.html", "_plain.html", ".enml"]
        absFilename = path.join(filePath, fnStem + fileExt)
        if fs.existsSync(absFilename)
          fnStem +=  "_#{utils.sanitizeTimeString()}"
          break
    fnStem

  makeQueryString: (options={}) ->
    options.id ?= true
    options.title ?= false
    options.notebook ?= false
    options.keywords ?= false
    options.tags ?= false
    queryString = ""
    if options.id and @id? then queryString += @id
    if @enCreationDate?
      advancedDate = utils.enDateHelper(@enCreationDate, {second:-2})
      queryString += " created:#{advancedDate}"
      delayedDate = utils.enDateHelper(@enCreationDate, {second:2})
      queryString += " -created:#{delayedDate}"
    if options.title then queryString += "intitle:\"#{@title}\""
    if options.notebook and @notebook? then queryString += " notebook:\"#{@notebook.name}\""
    if options.keywords and @keywords?
      tmpStr = ""
      for keyword in @keywords
        tmpStr += keyword + " "
      queryString = tmpStr + queryString
    if options.tags and @tags? and @tags.length > 0
      for tag in @tags
        queryString += " tag:\"" + tag + "\""
    #console.log("Query string: #{queryString}")
    return queryString


  getLastModifiedTime: () ->
    absPath = @absPath()
    for editor in atom.workspace.getTextEditors() when editor.getPath() is absPath
      if editor.isModified()
        return utils.getCurrentTimeString()
    if fs.isFileSync(absPath)
      fileModificationTimeStr = utils.mtimeToTimeString(fs.statSync(absPath)["mtime"])
      #console.log "fileModificationTimeStr: #{fileModificationTimeStr}"
      earlier = utils.timeMin(fileModificationTimeStr, @modificationTime)
      if earlier is @modificationTime
        fileContent = fs.readFileSync(absPath, 'utf8')
        if fileContent is @getContent()
          return @modificationTime
        else
          return fileModificationTimeStr
      else
        return @modificationTime
    else
      return @modificationTime

  #
  # Check enModificationTime against @lastSyncDate and last note modification time
  #
  checkConflict: (noteInfo) ->
    conflictStatus =
      unsyncdModificationInEvernote: null
      unsyncdModificationInAtomEVND: null
      lastSyncTime: null
      enModificationTime: null
      modificationTime: null
    if @lastSyncDate?
      lastSyncTimeStr = utils.enDateToTimeString(@lastSyncDate)
    if noteInfo?.enModificationDate?
      enModifiedTimeStr = utils.enDateToTimeString(noteInfo.enModificationDate)
    lastModifiedTimeStr = @getLastModifiedTime()

    if enModifiedTimeStr? and lastSyncTimeStr isnt enModifiedTimeStr
      earlier1 = utils.timeMin(lastSyncTimeStr, enModifiedTimeStr)
      if earlier1 is lastSyncTimeStr
        conflictStatus.unsyncdModificationInEvernote = true
      else
        conflictStatus.unsyncdModificationInEvernote = false # something fishy!
    unless conflictStatus.unsyncdModificationInEvernote is true
      metaChanged = @checkMeta(noteInfo)
      if metaChanged
        conflictStatus.unsyncdModificationInEvernote = true
      else
        conflictStatus.unsyncdModificationInEvernote = false
    if lastModifiedTimeStr isnt lastSyncTimeStr
      earlier2 = utils.timeMin(lastSyncTimeStr, lastModifiedTimeStr)
      if earlier2 is lastSyncTimeStr
        conflictStatus.unsyncdModificationInAtomEVND = true
      else
        conflictStatus.unsyncdModificationInAtomEVND = false # something fishy!
    conflictStatus.modificationTime = lastModifiedTimeStr
    conflictStatus.enModificationTime = enModifiedTimeStr
    conflictStatus.lastSyncTime = lastSyncTimeStr
    #console.log conflictStatus
    return conflictStatus

  parseHTML: (html) ->
    # hack
    html = html.replace /<\s*p\s+style="\s*margin:\s*15px\s+0\s*;\s*"\s*\/\s*>/g,
      "<p style=\"margin: 15px 0;\"> </p>"
    html = html.replace /<\s*p\sstyle="\s*margin:\s*15px\s+0\s*;\s*margin\-top:\s*0\s*;\s*"\s*\/\s*>/g,
      "<p style=\"margin: 15px 0; margin-top: 0;\"> </p>"
    html = html.replace /<\s*p\s*\/\s*>/g, "<p>   </p>"

    cheerio ?= require 'cheerio'
    o = cheerio.load(html)

    # remove the hidden time stamp, note id, svg definitions, etc.
    for div in o('div')
      if o(div).attr("title") is "evnd-time-stamp" then o(div).remove()
      if o(div).attr("title") is "evnd-note-id" then o(div).remove()
      if o(div).attr("title") is "svgDefinitions" then o(div).remove()

    # remove the TOC sections
    for div in o('div')
      if o(div).attr("title") is "evnd-toc-div"
        o(div).after("<p>   </p><p>[TOC]</p><p>   </p>")
        o(div).remove()

    # resolve paragraphs containing empty string?
    for paragraph in o('p')
      if o(paragraph).children().length is 0 and o(paragraph).text().trim().length is 0
        o(paragraph).text("nobreakspace")

    # remove hidden images
    r = /^(?:(?:)|(.+?))display\:(?:(?:)|(?:\s*)none;(?:(?:)|(?:.+?)))$/i
    for img in o('img')
      if r.test(o(img).attr("style"))
        #console.log o.html(o(img))
        o(img).remove()

    # remove hidden attachments (embed)
    for ebd in o('embed')
      if r.test(o(ebd).attr("style")) then o(ebd).remove()

    # resolve visible images (img)
    for img in o('img')
      src = o(img).attr("src")
      if @attachments? and src.slice(0, 6) is "?hash="
        hash = src.slice(6, src.length)
        for k, v of @attachments
          if v.info?.hash is hash and v.path?
            o(img).attr("src", v.path)
            break

    # resolve visible attachments (embed)
    for ebd in o('embed')
      embedInfo = {}
      embedInfo.alt = o(ebd).attr("alt")
      embedInfo.src = o(ebd).attr("src")
      embedInfo.type = o(ebd).attr("type")
      embedInfo.id = o(ebd).attr("id")
      embedInfo.height = o(ebd).attr("height")
      embedInfo.width = o(ebd).attr("width")
      embedInfo.title = o(ebd).attr("title")
      continue unless embedInfo.src?.slice(0, 6) is "?hash="
      hash = embedInfo.src.slice(6, embedInfo.src.length)
      if @attachments?
        for k, v of @attachments
          if v.info?.hash is hash
            if v.path?
              embedInfo.src = v.path
              o(ebd).attr("src", embedInfo.src)
            v.embedInfo = embedInfo
            break

    # Remove "script" elements
    for scrpt in o('script')
      if o(scrpt).attr("type").indexOf("math/tex") > -1 then o(scrpt).remove()

    for sp in o('span.math')
      o(sp).remove()
    for sp in o('span')
      if o(sp).html().trim().length is 0 then o(sp).remove()

    #toMarkdown ?= require('to-markdown').toMarkdown
    #toMarkdown ?= require 'html2markdown'
    toMarkdown ?= require('./../markdown-helper').toMarkdown
    #html = utils.htmlDecode(o.html()).replace(/&#xA0;/g, '&nbsp;')
    html = o.html()
    html = html.replace(/nobreakspace/g, '&nbsp;')
    #console.log "html to convert: " + html
    markdown = toMarkdown(html).replace(/&#xA0;/g, ' ').replace(/&nbsp;/g, '     ')
    markdown = markdown.replace(/\n\*\s\*\s\*\s*\n/g, '\n------\n')
    markdown = markdown.replace(/(^|\n)((?:)|(?:[>\s]+))\*\s{3}/g, '$1$2-   ')
    markdownCleanUp ?= require('./../markdown-helper').markdownCleanUp
    markdown = markdownCleanUp(markdown)

    return markdown

module.exports =
  Note: Note
