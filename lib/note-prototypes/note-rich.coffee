fs =  require 'fs-plus'
utils = require './../utils'
path = require 'path'
renderer = null # delayed require './../renderer'
cheerio = null # delayed require 'cheerio'
toMarkdown = null # delayed require 'to-markdown'
{Note} = require './note-base'
{File, Directory} = require 'atom'
{resourcePath} = atom.getLoadSettings()
packagePath = path.dirname(__dirname)

getRealGitPath = ->
  if window.evnd?.storageManager?.gitDir?
    return window.evnd.storageManager.gitDir.getRealPathSync()
  gitPath = atom.config.get('ever-notedown.gitPath')
  gitPathSymlink = atom.config.get('ever-notedown.gitPathSymlink')
  gitDir = new Directory(gitPath, gitPathSymlink)
  return gitDir.getRealPathSync()

# TODO
hrefFallBack = (html) ->
  fallbackHREF = '#'
  o = cheerio.load(html)
  for linkElement in o('a')
    href = o(linkElement).attr('href')
    unless href?.length > 0
      o(linkElement).attr('href', fallbackHREF)
  o.html()

# TODO
resolveAttachmentPaths = (html, filePath) ->
  [rootDirectory] = atom.project.relativizePath(filePath)
  o = cheerio.load(html)
  for ebdElement in o('embed')
    ebd = o(ebdElement)
    if src = ebd.attr('src')
      continue if src.match(/^(https?):\/\//)
      continue if src.startsWith(process.resourcesPath)
      continue if src.startsWith(resourcePath)
      continue if src.startsWith(packagePath)

      if src[0] is '/'
        unless fs.isFileSync(src)
          if rootDirectory? and src.substring(1)?
            ebd.attr('src', path.join(rootDirectory, src.substring(1)))
      else if src.match(/^atom:\/\//)
        atomConfigPath = atom.getConfigDirPath()
        srcPath = src.replace(/^atom:\/\//, '')
        testSRCs = [
          path.join(atomConfigPath, 'assets/', srcPath)
          path.join(atomConfigPath, 'dev/packages/', srcPath)
          path.join(atomConfigPath, 'packages/', srcPath)
        ]
        for testSRC in testSRCs
          if fs.isFileSync(testSRC)
            ebd.attr('src', testSRC)
            break
      else if filePath? and src?
        ebd.attr('src', path.resolve(path.dirname(filePath), src))

  o.html()

# TODO
resolveImagePaths = (html, filePath) ->
  [rootDirectory] = atom.project.relativizePath(filePath)
  o = cheerio.load(html)
  for imgElement in o('img')
    img = o(imgElement)
    if src = img.attr('src')
      continue if src.match(/^(https?):\/\//)
      continue if src.startsWith(process.resourcesPath)
      continue if src.startsWith(resourcePath)
      continue if src.startsWith(packagePath)

      if src[0] is '/'
        unless fs.isFileSync(src)
          if rootDirectory? and src.substring(1)?
            img.attr('src', path.join(rootDirectory, src.substring(1)))
      else if src.match(/^atom:\/\//)
        atomConfigPath = atom.getConfigDirPath()
        srcPath = src.replace(/^atom:\/\//, '')
        testSRCs = [
          path.join(atomConfigPath, 'assets/', srcPath)
          path.join(atomConfigPath, 'dev/packages/', srcPath)
          path.join(atomConfigPath, 'packages/', srcPath)
        ]
        for testSRC in testSRCs
          if fs.isFileSync(testSRC)
            img.attr('src', testSRC)
            break
      else if filePath? and src?
        img.attr('src', path.resolve(path.dirname(filePath), src))

  o.html()

class RichNote extends Note
  constructor: (options={}) ->
    super(options)
    @attachments = options.attachments ? {}
    @addAttachments = false

  htmlHeader: ({cssLink, toInsert, addTitle} = {}) ->
    cssLink ?= true
    toInsert ?= ""
    addTitle ?= true
    if @css? then cssPath = path.join(@path, "#{@fnStem}_style.css") else cssPath = "#{@fnStem}_style.css"
    if cssLink
      cssInsert = "<link rel=\"stylesheet\" type=\"text/css\" href=\"#{cssPath}\">"
    else
      if not fs.isFileSync(cssPath)
        cssContent = @css
        fs.writeFileSync(cssPath, @css, 'utf8')
      cssContent = fs.readFileSync(cssPath, 'utf8')
      cssInsert = "<style>#{cssContent}</style>"
    titleInsert = if addTitle then "<title>#{@title}</title>" else ""
    header = "<head>#{titleInsert}#{cssInsert}#{toInsert}</head>"
    return header

  styledHTML: ({cssInline, cssLink, inputHTML}={}) ->
    cssInline ?= false
    cssLink ?= true
    inputHTML ?= @rawHTML
    return inputHTML unless @css? or @header?
    idHTML = if @id? then "<div style=\"display:none\" title=\"evnd-note-id\" id=\"evnd-note-id\"><p>#{@id}</p></div>" else ""
    inputHTML += idHTML
    if @css?
      if cssInline
        renderer ?= require './../renderer'
        html = renderer.inlineCss({html: inputHTML, css: @css})
      else
        header = @htmlHeader(cssLink: cssLink)
        html = "<div class=\"ever-notedown-preview\">#{inputHTML}</div>"
    else
      html = inputHTML
    if header? then html = header + html
    else if @header? then html = @header + html
    return html

  #
  # Based on the official Atom Markdown Preview package
  #
  @getMarkdownPreviewCSS: ->
    markdowPreviewRules = []
    ruleRegExp = /\.ever-notedown-preview/

    for stylesheet in document.styleSheets
      if stylesheet.rules?
        for rule in stylesheet.rules
          # We only need `.ever-notedown-preview` css
          markdowPreviewRules.push(rule.cssText) if rule.selectorText?.match(ruleRegExp)?

    markdownPreviewCSS = markdowPreviewRules.join('\n')
    markdownPreviewCSS

  @removeFloatingButtons: (html) ->
    cheerio ?= require 'cheerio'
    o = cheerio.load(html)
    o('div.evnd-function-buttons').remove()
    return o.html()

  # Some markdown theme has :before, :after, :first-child, :last-child
  # psudo elements defined for blockquotes
  # those CSS definitions will not be put into inline CSS,
  # so we'll have to fix them
  @resolveBlockquoteStyles: (html, options) ->
    theme = atom.config.get('ever-notedown.theme')
    markdownPreviewCSS = RichNote.getMarkdownPreviewCSS()
    beforeAfter = /blockquote\:{1,2}(?:(?:before)|(?:after))/i.test(markdownPreviewCSS)
    firstLastChild = /blockquote\s*?>\s*?\:\s*?(?:first|last)-child\s*{([\s\S]+?)}/i.test(markdownPreviewCSS)
    #return html unless beforeAfter or firstLastChild
    blqBeforeReg = /blockquote\:{1,2}before\s*{([\s\S]+?)}/i
    beforeMatched = blqBeforeReg.exec(markdownPreviewCSS)
    if beforeMatched?
      beforeCSS = beforeMatched[1]
      beforeContentMatched = /content\:(.+?);/i.exec(beforeCSS)
      if beforeContentMatched?
        beforeContent = beforeContentMatched[1].trim().replace(/[\'\"]/g, '')
      else
        beforeContent = ""
      beforeHTML = "<span class=\"blockquote-before\">#{beforeContent}</span>"

    blqAfterReg = /blockquote\:{1,2}after\s*{([\s\S]+?)}/i
    afterMatched = blqAfterReg.exec(markdownPreviewCSS)
    if afterMatched?
      afterCSS = afterMatched[1]
      afterContentMatched = /content\:(.+?);/i.exec(afterCSS)
      if afterContentMatched?
        afterContent = afterContentMatched[1].trim().replace(/[\'\"]/g, '')
      else
        afterContent = ""
      afterHTML = "<span class=\"blockquote-after\">#{afterContent}</span>"

    firstChildReg = /blockquote\s*?>\s*?\:\s*?first-child\s*{([\s\S]+?)}/i
    firstChildMatched = firstChildReg.exec(markdownPreviewCSS)
    if firstChildMatched?
      firstChildCSS = firstChildMatched[1]
      #console.log firstChildCSS

    lastChildReg = /blockquote\s*?>\s*?\:\s*?last-child\s*{([\s\S]+?)}/i
    lastChildMatched = lastChildReg.exec(markdownPreviewCSS)
    if lastChildMatched?
      lastChildCSS = lastChildMatched[1]
      #console.log lastChildCSS

    return html unless beforeHTML? or afterHTML? or firstChildCSS? or lastChildCSS?
    cheerio ?= require 'cheerio'
    o = cheerio.load(html)
    for blq in o.root().children('blockquote')
      if beforeHTML?
        o(blq).prepend(beforeHTML)
      else
        o(blq).children('.blockquote-before').remove()
      if afterHTML?
        o(blq).append(afterHTML)
      else
        o(blq).children('.blockquote-after').remove()
      if firstChildCSS?
        firstChild = o(blq).children().first()
        if o(firstChild).hasClass('blockquote-before')
          firstChild = o(firstChild).next()
        if firstChild?
          oldStyle = o(firstChild).attr("style") ? ""
          o(firstChild).attr("style", oldStyle + firstChildCSS)
      if lastChildCSS?
        lastChild = o(blq).children().last()
        if o(lastChild).hasClass('blockquote-after')
          lastChild = o(lastChild).next()
        if lastChild?
          oldStyle = o(lastChild).attr("style") ? ""
          o(lastChild).attr("style", oldStyle + lastChildCSS)

    return o.html()

  # Replace Octicon and Font Awesome icons with PNGs
  @resolveIcons: (html, options) ->
    toBase64 = options?.toBase64 ? false

    cheerio ?= require 'cheerio'
    o = cheerio.load(html)

    octPNGPath = path.join atom.packages.getLoadedPackage("ever-notedown").path,
        'assets/octicons-2.2.1/png/'
    if fs.isDirectorySync(octPNGPath)
      for octIcon in o('span.icon, i.icon, span[class^=icon-], i[class^=icon-]')
        octText = o(octIcon).text()
        if octText? and octIcon.tagName is 'i' then octText = "<i>#{octText}</i>"
        octStyle = o(octIcon).attr('style') ? "margin-right:5px;"
        octClasses = o(octIcon).attr('class').split(' ')
        for octClass in octClasses
          if octClass.slice(0, 5) is 'icon-'
            iconPath = path.join(octPNGPath, octClass + '.png')
            if fs.isFileSync(iconPath)
              if toBase64
                originalData = fs.readFileSync iconPath, 'binary'
                base64Data = new Buffer(originalData, 'binary').toString('base64')
                imgSRC = "data:image/png;base64,#{base64Data}"
              else
                imgSRC = iconPath
              newOctHTML = "<span style=\"#{octStyle}\">"
              newOctHTML += "<img style=\"margin-right:5px;\" src=\"#{imgSRC}\" title=\"#{octClass}.png\" />"
              newOctHTML += "#{octText}</span>"
              o(octIcon).replaceWith(newOctHTML)
            break

    faPNGPath = path.join atom.packages.getLoadedPackage("ever-notedown").path,
        "assets/font-awesome-4.3.0/png/"
    if fs.isDirectorySync(faPNGPath)
      for faIcon in o('span.fa, i.fa')
        faText = o(faIcon).text()
        if faText? and faIcon.tagName is 'i' then faText = "<i>#{faText}</i>"
        faStyle = o(faIcon).attr('style') ? "margin-right:5px;"
        faClasses = o(faIcon).attr('class').split(' ')
        for faClass in faClasses
          if faClass.slice(0, 3) is 'fa-'
            iconPath = path.join(faPNGPath, faClass + '.png')
            if fs.isFileSync(iconPath)
              if toBase64
                originalData = fs.readFileSync iconPath, 'binary'
                base64Data = new Buffer(originalData, 'binary').toString('base64')
                imgSRC = "data:image/png;base64,#{base64Data}"
              else
                imgSRC = iconPath
              newFaHTML = "<span style=\"#{faStyle}\">"
              newFaHTML += "<img style=\"margin-right:5px;\" src=\"#{imgSRC}\" title=\"#{faClass}.png\" />"
              newFaHTML += "#{faText}</span>"
              o(faIcon).replaceWith(newFaHTML)
            break

    return o.html()

  tidy: () ->
    prohibitedElements = [
      'applet'
      'base'
      'basefont'
      'bgsound'
      'blink'
      'body'
      'button'
      'dir'
      'embed'
      'fieldset'
      'form'
      'frame'
      'frameset'
      'head'
      'html'
      'iframe'
      'ilayer'
      'input'
      'isindex'
      'label'
      'layer'
      'legend'
      'link'
      'marquee'
      'menu'
      'meta'
      'noframes'
      'noscript'
      'object'
      'optgroup'
      'option'
      'param'
      'plaintext'
      'script'
      'select'
      'style'
      'textarea'
      'xml'
    ]
    prohibitedAttributes = [
      'id'
      'class'
      'onclick'
      'ondblclick'
      'on*'
      'accesskey'
      'data'
      'dynsrc'
      'tabindex'
      'role'
      'aria-readonly'
      'tooltip'
      'tooltip-persistant'
    ]

    #console.log "Begin tyding up this note..."
    html = @rawHTML ? "<p>@rawHTML is null!!!!!!!!!</p>"

    # tidy up
    html = utils.closeTags(html, 'use')

    cheerio ?= require 'cheerio'
    html = html.replace(/&nbsp;/g, 'nobreakspace')
    html = resolveImagePaths(html, @path)
    html = resolveAttachmentPaths(html, @path)
    html = hrefFallBack(html)
    o = cheerio.load(html)

    mathjax = atom.config.get('ever-notedown.mathjax')
    mathjaxOutput = atom.config.get('ever-notedown.mathjaxOutput')

    gitPath = window.evnd?.gitPath ? getRealGitPath()

    o = cheerio.load(RichNote.removeFloatingButtons(o.html()))
    o = cheerio.load(RichNote.resolveBlockquoteStyles(o.html()))
    o('div.svgDefinitions').remove()
    for oSVG in o('svg')
      if o(oSVG).attr("class") is "svgDefinitions"
        o(oSVG).remove()
        continue
      elementID = o(oSVG).attr("id")
      if not elementID? or (elementID is "undefined")
        elementID = 'svg' + utils.stringMD5(o(oSVG).html())
      svgFilePath = path.join(@path, 'img/', elementID + '.svg')
      if not fs.isFileSync(svgFilePath)
        svgFilePath2 = path.join(gitPath, 'tmp/Math/', elementID + '.svg')
        if fs.isFileSync(svgFilePath2)
          fs.moveSync(svgFilePath2, svgFilePath) # Move
          fs.moveSync(svgFilePath2.replace('.svg', '.png'), svgFilePath.replace('.svg', '.png'))
        else
          continue
      if o(oSVG).parent().attr("class").indexOf("MathJax") > -1
        if o(oSVG).parent().parent().attr("class").indexOf("MathJax_SVG_Display") > -1
          oScript = o(oSVG).parent().parent().parent().children('script')
        else
          oScript = o(oSVG).parent().parent().children('script')
        altText = o(oScript).html()
      svgElement = o('<img src="' + svgFilePath + '" />')
      o(svgElement).attr("title", path.basename(svgFilePath))
      svgStyle = o(oSVG).attr('style')
      if o(oSVG).attr('width')?
        svgStyle += " width: #{o(oSVG).attr('width')};"
      if o(oSVG).attr('height')?
        svgStyle += " height: #{o(oSVG).attr('height')};"
      o(svgElement).attr("style", svgStyle)
      o(svgElement).attr("alt", altText)
      o(svgElement).attr("tooltip", altText)
      if altText then o(oSVG).parent().parent().attr("tooltip", altText)
      o(oSVG).parent().append(o(svgElement))
      o(oSVG).remove() #?

    for mathSpan in o('span.MathJax_SVG')
      unless o(mathSpan).attr("title")?.length > 0
        o(mathSpan).attr("title", "MathJax_SVG")
    for mathDiv in o('div.MathJax_SVG_Display')
      unless o(mathDiv).attr("title")?.length > 0
        o(mathDiv).attr("title", "MathJax_SVG_Display")

    html = o.html()
    @rawHTML = html.replace(/nobreakspace/g, '&nbsp;') # Resolved SVGs...
    # TODO: Styling? CSS
    html = @styledHTML({cssInline: true, inputHTML: html})

    # tidy up
    html = utils.closeTags(html, 'use')
    o = cheerio.load(html)
    o('.note-meta-info').remove() # remove the meta info section

    o = cheerio.load(RichNote.resolveIcons(o.html()))

    # Handle highlighted Text!
    for omark in o('mark')
      markInnerHTML = o(omark).html()
      newHTML = "<span style=\"background-color: yellow;\">#{markInnerHTML}</span>"
      o(omark).replaceWith(newHTML)

    if mathjax and (mathjaxOutput is 'HTML/CSS')
      for nobrElm in o('nobr')
        for nSpan in o(nobrElm).find('span')
          oldStyles = o(nSpan).attr('style') ? ""
          if oldStyles.indexOf("white-space") isnt -1
            newStyles = oldStyles
          else
            newStyles = oldStyles + " white-space: nowrap;"
          o(nSpan).attr('style', newStyles)
        o(nobrElm).parent().append(o(nobrElm).html())
        o(nobrElm).remove()

    for oScript in o('script')
      scriptHTML = utils.htmlEncode(o.html(o(oScript)))
      scriptType = o(oScript).attr("type")
      dlm = if scriptType.indexOf("display") > -1 then "$$" else "$"
      newHTML = "<span style=\"display: none;\"><code>#{scriptHTML}</code></span>"
      newElement = o(newHTML)
      o(newElement).attr("style", "display:none")
      o(newElement).attr("title", "hidden_script_mathjax")
      o(newElement).attr("class", "hidden-script-mathjax")
      o(newElement).append("<span style=\"display: none;\" title=\"raw_mathjax_script\">#{dlm}#{o(oScript).html()}#{dlm}</span>")
      o(oScript).parent().append(o.html(newElement))

    for elm in o('.table-of-contents, h1, h2, h3, h4, h5, h6')
      for oScript in o(elm).find('script')
        o(oScript).remove()

    for elm in o('.table-of-contents')
      for par in o(elm).find('p')
        o(par).remove()

    #
    # Handle Table of Content links!
    #
    for elm in o('a.toc-jump-link')
      href = o(elm).attr("href")
      if href.charAt(0) is '#'
        href = "#toc:#{href.slice(1, href.length)}"
        o(elm).attr("href", href)

    @addAttachments = false # assuming...
    for k, v of @attachments
      if not v.info? then v.active = false # assume...

    for oEMBED in o('embed')
      attachmentFound = false
      ebdSRC = o(oEMBED).attr("src")
      ebdTitle = o(oEMBED).attr("title")

      # This <embed /> element is the result of appending attachments to
      # the EN note via AppleScript
      if (not ebdTitle or ebdTitle is "undefined") and ebdSRC.indexOf("?hash=") > -1
        o(oEMBED).attr("style", "display:none")

      # This <embed /> elements links to local files, we need to resolve these
      else if ebdSRC.indexOf("?hash=") is -1 and fs.isFileSync(ebdSRC)
        fileMD5 = utils.fileMD5(ebdSRC)

        for k, v of @attachments
          if v.md5 is fileMD5 and v.info?.hash is fileMD5# found!
            hash = v.info.hash
            o(oEMBED).attr('src',  "?hash=#{hash}")
            mimetype = v["info"]["mime"]
            o(oEMBED).attr("id", "en-media:#{mimetype}:#{hash}")
            o(oEMBED).attr("style", "cursor:pointer")
            if mimetype is "application/pdf"
              o(oEMBED).attr("height", "1013")
              o(oEMBED).attr("width", "100%")
              o(oEMBED).attr("type", "evernote/x-pdf")
            else
              o(oEMBED).attr("height", "43")
              o(oEMBED).attr("type", "evernote/x-attachment")
            v.active = true
            attachmentFound = true
            break

        if not attachmentFound # Need to upload? this attachment
          if ebdSRC.indexOf(@path) is -1 # this file isn't in current note's path
            ebdExt = path.extname(ebdSRC)
            ebdDir = path.dirname(ebdSRC)
            ebdFnStem = utils.sanitizeString(path.basename(ebdSRC, ebdExt))
            newEBDName = ebdFnStem + ebdExt
            ebdDEST = path.join(@path, 'attachments/', newEBDName)
            if fs.isFileSync(ebdDEST) # file of the same name existed!
              ebdDEST = utils.renameFile(ebdDEST)
            if ebdSRC.indexOf(path.join(gitPath, 'tmp/')) > -1
              fs.moveSync(ebdSRC, ebdDEST) # Move
            else
              tmpFileBin = fs.readFileSync(ebdSRC, 'binary')
              fs.writeFileSync(ebdDEST, tmpFileBin, 'binary')  # Copy
            ebdSRC = ebdDEST
            o(oEMBED).attr('src', ebdSRC)
            fileMD5 = utils.fileMD5(ebdSRC)

          if (not ebdTitle) or (ebdTitle is "Optional title")
            ebdTitle = path.basename(ebdSRC)
            o(oEMBED).attr("title", ebdTitle)

          attachmentFileName = path.basename(ebdSRC)
          #if @attachments[attachmentFileName]?
          @attachments[attachmentFileName] =
            title: ebdTitle
            path: ebdSRC
            info: null
            active: true
            md5: fileMD5
          @addAttachments = true
        if o(oEMBED).parent().length > 0
          o(oEMBED).parent().after(o.html(o(oEMBED)))

    for enmedia in o('div.en-media')
      o(enmedia).remove()
      #console.log "en-media? TODO!"

    for oIMG in o('img')
      attachmentFound = false
      imgSRC = o(oIMG).attr('src')
      imgTitle = o(oIMG).attr("title")
      continue unless imgSRC?

      # This <img /> element is the result of appending attachments to
      # the EN note via AppleScript
      if (not imgTitle? or imgTitle is "undefined") and imgSRC.indexOf("?hash=") > -1
        o(oIMG).attr("style", "display:none")

      # This <img /> elements links to local files, we need to resolve these
      else if imgSRC.indexOf("?hash=") is -1 and fs.isFileSync(imgSRC)
        if not imgTitle?
          imgTitle = path.basename(imgSRC)
          o('img').attr('title', imgTitle)

        if utils.endsWith(imgSRC, '.svg')
          imgSRC = imgSRC.replace('.svg', '.png')
          o(oIMG).attr("src", imgSRC)
        if utils.endsWith(imgTitle, '.svg')
          imgTitle = imgTitle.replace('.svg', '.png')
          o(oIMG).attr("title", imgTitle)
        imgMD5 = utils.fileMD5(imgSRC)
        if (not imgTitle) or (imgTitle is "Optional title")
          imgTitle = path.basename(imgSRC)
          o(oIMG).attr("title", imgTitle)

        for k, v of @attachments
          if v.md5 is imgMD5 and v.info?.hash? and (v.info.hash is imgMD5) # found!
            hash = v.info.hash
            o(oIMG).attr('src',  "?hash=#{hash}")
            mimetype = v["info"]["mime"]
            o(oIMG).attr("id", "en-media:#{mimetype}:#{hash}:none:none")
            o(oIMG).attr("title", v.title)
            v.active = true
            attachmentFound = true
            break

        if not attachmentFound # Need to upload? this attachment
          #console.log "New attachment! " + imgSRC
          if imgSRC.indexOf(@path) is -1 # this file isn't in current note's path
            imgExt = path.extname(imgSRC)
            imgDir = path.dirname(imgSRC)
            imgFnStem = utils.sanitizeString(path.basename(imgSRC, imgExt))
            newIMGName = imgFnStem + imgExt
            imgDEST = path.join(@path, 'img/', newIMGName)
            if fs.isFileSync(imgDEST)
              imgDEST = utils.renameFile(imgDEST)
            if imgSRC.indexOf(path.join(gitPath, 'tmp/Math')) > -1
              fs.moveSync(imgSRC, imgDEST) # Move
            else
              tmpImageBin = fs.readFileSync(imgSRC, 'binary')
              fs.writeFileSync(imgDEST, tmpImageBin, 'binary')  # Copy
            imgSRC = imgDEST
            o(oIMG).attr('src', imgSRC)
            imgMD5 = utils.fileMD5(imgSRC)

          imgFileName = path.basename(imgSRC)
          @attachments[imgFileName] =
            title: imgTitle
            path: imgSRC
            info: null
            active: true
            md5: imgMD5
          @addAttachments = true

    for oinput in o('input')
      if o(oinput).attr("type") is "checkbox"
        checked = o.html(oinput).indexOf("checked") > -1
        if checked
          objHTML = "<object class=\"en-todo en-todo-checked\" />"
        else
          objHTML = "<object class=\"en-todo\" />"
        o(oinput).replaceWith(objHTML)


    ## Append time stamp
    timeStamp = utils.getCurrentTimeString()
    o('div').last().append("<div style=\"display: none;\" title=\"evnd-time-stamp\" id=\"evnd-time-stamp\"><p>#{timeStamp}</p></div>")

    # XML and HTML
    xml = o.xml()?.replace(/&/g, '&amp;')?.replace(/nobreakspace/g, '&#160;')
    doctype = '<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">'
    newHtml = doctype + o.html()?.replace(/nobreakspace/g, '&nbsp;')

    # ENML
    # Handle images, attachements, GFM TO-DO's, etc.

    # checkboxes
    for oinput in o('input')
      if o(oinput).attr("type") is "checkbox"
        oinputHTML = o.html(o(oinput))
        if oinputHTML.indexOf("checked") > -1
          o(oinput).after("<p>en-todo-place-holder-checked</p>")
        else
          o(oinput).after("<p>en-todo-place-holder-unchecked</p>")
    for olabel in o('label')
      olabelInnerHTML = o(olabel).html()
      o(olabel).after(olabelInnerHTML)

    # TODO!
    o(pElm).remove() for pElm in prohibitedElements
    o('*').removeAttr(attribute) for attribute in prohibitedAttributes

    attachmentConverted = false
    if @attachments?
      for oIMG in o('img')
        srcVal = o(oIMG).attr('src')
        if srcVal.indexOf('?hash=') > -1
          hash = srcVal.slice(srcVal.indexOf('?hash=')+6, srcVal.length).trim()
          for k, v of @attachments
            if v.info?.hash is hash
              o(oIMG).attr("hash", hash)
              mimetype = v["info"]["mime"]
              o(oIMG).attr("type", mimetype)
              o(oIMG).attr("src", null)
              o(oIMG).attr("title", v.title)
              attachmentConverted = true
              break

    enml = o.html()?.replace(/nobreakspace/g, '&#160;')
    enml = enml?.replace('<p>en-todo-place-holder-checked</p>', '<en-todo checked="true"/>')
    enml = enml?.replace('<p>en-todo-place-holder-unchecked</p>', '<en-todo/>')
    if attachmentConverted then enml = enml?.replace(/<img/g, '<en-media')
    enml = utils.closeTags(enml, 'br')
    enml = utils.closeTags(enml, 'hr')
    #enml = enml.replace(/<br>/g, '<br />').replace(/<hr>/g, '<hr />')
    enml = utils.closeTags(enml, 'img')
    enml = utils.closeTags(enml, 'en-media')
    enml = '<en-note>' + enml + '</en-note>'


    # validation against DTD?
    # TODO!
    #
    #return {xml: xml, html: newHtml, enml: enml}

    @html = newHtml
    @enml = enml

    # TODO: clean-up unused attachments
    #for k, v of @attachments
    #  if not v.active
        # TODO: remove unused files (fs.removeSync?)
        # delete @attachments[k]
        #console.log "Need to remove attachment: #{k}"

  compareHTML: (html0, html1, fnStem="test") ->
    cheerio ?= require 'cheerio'
    o0 = cheerio.load(html0)
    o1 = cheerio.load(html1)
    o0('*').removeAttr("id")
    o0('head').remove()
    o1('*').removeAttr("id")
    o1('head').remove()

    htmlSame = o0.html() is o1.html()
    if not htmlSame
      gitPath = window.evnd?.gitPath ? getRealGitPath()
      fs.writeFileSync(path.join(gitPath, 'tmp/', fnStem + '_0.html'), o0.html(), 'utf8')
      fs.writeFileSync(path.join(gitPath, 'tmp/', fnStem + '_1.html'), o1.html(), 'utf8')
    return htmlSame


module.exports =
  RichNote: RichNote
