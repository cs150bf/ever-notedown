fs = require 'fs-plus'
path = require 'path'
moment = require 'moment'
crypto = null # delayed require 'crypto'
cheerio = null
mime = null

exports.endsWith = (strToCheck, suffix) ->
  return false unless strToCheck?
  strToCheck.indexOf(suffix, strToCheck.length - suffix.length) isnt -1

exports.forceEndsWith = (strToCheck, suffix) ->
  if this.endsWith(strToCheck, suffix)
    strToCheck
  else
    strToCheck + suffix

exports.isStringEmpty = (inputStr) ->
  if inputStr and /([^\s])/.test(inputStr)
    false
  else
    true

exports.timeOpts = {hour: "2-digit", minute: "2-digit", second: "2-digit"}

exports.timeMin = (timeStr0, timeStr1) ->
  timeStrFormat = "YYYY-MM-DD HH:mm:ss"
  time0 = moment(timeStr0, timeStrFormat)
  time1 = moment(timeStr1, timeStrFormat)
  tmin = moment.min(time0, time1)
  return tmin.format(timeStrFormat)

exports.convertHexNCR2String = convertHexNCR2String = (inputStr) ->
  hexNCRTestReg = /([^`]\s*?)&#x([a-zA-Z0-9]+?);/i
  startIndex = 0
  while startIndex < inputStr.length and
      hexNCRTestReg.test(inputStr.slice(startIndex, inputStr.length))
    matched = hexNCRTestReg.exec(inputStr.slice(startIndex, inputStr.length))
    return inputStr unless matched?
    tmpString = String.fromCharCode(parseInt('0x' + matched[2]))
    inputStr = inputStr.slice(0, startIndex + matched.index) + matched[1] + tmpString + inputStr.slice(startIndex + matched.index + matched[0].length, inputStr.length)
    startIndex += matched.index + matched[1].length + tmpString.length - 2
  return inputStr

exports.getCurrentTimeString = () ->
  moment().format("YYYY-MM-DD HH:mm:ss")

exports.sanitizeFilename = (fnStem, ext) ->
  fn = fnStem.replace(/[;\s\:\,\.\?\*\/\\]/g, "_").replace(/[`#@%~<>\{\}\!\|\+\$\^\&]/g, "_").replace(/_{1,}/g, "_")
  if fn.length > 25 then fn = fn.slice(0, 25)
  if ext? then fn += ext
  return fn

exports.sanitizeTimeString = (timeString) ->
  timeString ?= this.getCurrentTimeString()
  timeString.replace(/\ /g, "_").replace(/-/g, "").replace(/:/g, "")

exports.sanitizeString = sanitizeString = (inputStr) ->
  inputStr.replace(/\s/g, "_").replace(/[^a-zA-Z0-9]/g, "_").replace(/_{1,}/g, "_")

exports.getSanitizedTimeString = () ->
  timeString = this.getCurrentTimeString()
  sTimeString = this.sanitizeTimeString(timeString)
  return sTimeString

exports.sanitizeID = sanitizeID = (id) ->
  return unless id?.length > 0
  id = sanitizeString(id).replace(/_/g, '-')
  if /[\-0-9]/i.test(id.charAt(0)) # avoid caveat (e.g.: "#-1-blah" or "#3-1-something" is not a valid selector)
    id = 'm' + id
  id = id.replace(/-{2,}/g, '-')
  return id

exports.sanitizeHeaderText = sanitizeHeaderText = (headerText) ->
  return unless headerText?.length > 0
  headerText = headerText.trim().toLowerCase()
  headerText = headerText.replace(/[\'\"]/g, '').replace(/-{3}/g, '').replace(/-{2}/g, '').replace(/\.{3}/g, '')
  headerText = this.convertDecNCR2String(this.convertHexNCR2String(headerText))
  headerText = headerText.replace(/[—‘’“”…]/g, '')
  headerText = sanitizeString(headerText)
  return headerText

exports.renameFile = (oldFilename) ->
  sTimeString = this.getSanitizedTimeString()
  fileExt = path.extname(oldFilename)
  oldDir = path.dirname(oldFilename)
  oldFnStem = path.basename(oldFilename, fileExt)
  newFnStem = oldFnStem + "_#{sTimeString}"
  newFilename = path.join(oldDir, newFnStem + fileExt)
  return newFilename

exports.timeOut = (ms) ->
  ms ?= 10000
  startTime = new Date().getTime()
  continue while (new Date().getTime() - startTime < ms)

exports.convertHexNCR2String = convertHexNCR2String = (inputStr) ->
  return this.convertNCR2String(inputStr, 'hex')

exports.convertDecNCR2String = convertDecNCR2String = (inputStr) ->
  return this.convertNCR2String(inputStr, 'dec')

exports.convertNCR2String = convertNCR2String = (inputStr, base) ->
  base ?= 'hex'
  switch base
    when 'hex'
      testReg = /([^`]\s*?)&#x([a-fA-F0-9]+?);/i
      prefix = '0x'
    when 'dec'
      testReg = /([^`]\s*?)&#([0-9]+?);/i
      prefix = ''
    else
      return inputStr
  startIndex = 0
  while startIndex < inputStr.length and
      testReg.test(inputStr.slice(startIndex, inputStr.length))
    matched = testReg.exec(inputStr.slice(startIndex, inputStr.length))
    return inputStr unless matched?
    tmpString = String.fromCharCode(parseInt(prefix + matched[2]))
    inputStr = inputStr.slice(0, startIndex + matched.index) + matched[1] + tmpString + inputStr.slice(startIndex + matched.index + matched[0].length, inputStr.length)
    startIndex += matched.index + matched[1].length + tmpString.length - 2
  return inputStr

# TODO: This doesn't even make sense...
exports.literalReplace = (inputStr, oldSubStr, newSubStr, options) ->
  return inputStr unless inputStr? and oldSubStr?
  replaceOnce = options?.replaceOnce
  unless replaceOnce?
    replaceOnce = false
  lookAhead = options?.lookAhead
  negatedLookAhead = options?.negatedLookAhead
  unless negatedLookAhead?
    negatedLookAhead = false
  lookBack = options?.lookBack
  negatedLookBack = options?.negatedLookBack
  unless negatedLookBack?
    negatedLookBack = false
  startIndex = inputStr.indexOf(oldSubStr)
  oldSubStrLength = oldSubStr.length
  newSubStrLength = newSubStr.length
  outputStr = inputStr
  i = 0
  validReplacements = 0
  while startIndex > -1 and startIndex < outputStr.length
    if validReplacements > 0 and replaceOnce then return outputStr
    if i > 500 then return outputStr
    skip = false
    if lookBack? and startIndex >= lookBack.length
      if outputStr.slice(startIndex - lookBack.length, startIndex) is lookBack and negatedLookBack
        startIndex = outputStr.indexOf(oldSubStr, startIndex + oldSubStrLength + 1)
        skip = true
      else if not negatedLookBack
        startIndex = outputStr.indexOf(oldSubStr, startIndex + oldSubStrLength + 1)
        skip = true
    else if lookAhead? and outputStr.length >= (startIndex + oldSubStrLength + lookAhead.length)
      if outputStr.slice(startIndex + oldSubStrLength, startIndex + oldSubStrLength + lookAhead.length) is lookAhead and negatedLookAhead
        startIndex = outputStr.indexOf(oldSubStr, startIndex + oldSubStrLength + lookAhead.length)
        skip = true
      else if not negatedLookAhead
        startIndex = outputStr.indexOf(oldSubStr, startIndex + oldSubStrLength + lookAhead.length)
        skip = true
    unless skip
      outputStr = outputStr.slice(0, startIndex) + newSubStr + outputStr.slice(startIndex + oldSubStrLength, outputStr.length)
      startIndex = outputStr.indexOf(oldSubStr, startIndex + newSubStrLength)
      validReplacements += 1
    i += 1
  return outputStr

exports.escapeDollarSign = (rawString) ->
  return "" unless rawString?
  return rawString.replace(/\$/g, '$$$$')

exports.stringEscape = (rawString) ->
  escapedStr = rawString.replace(/\n/g, "\\n").replace(/\"/g, '\\"').replace(/\'/g, "\\'")
  escapedStr = escapedStr.replace(/\t/g, "\\t").replace(/\r/g, "\\r")
  escapedStr

exports.mathEscape = (rawMath) ->
  escapedMath = rawMath.replace(/</g, ' \\lt ').replace(/>/g, ' \\gt ')

exports.htmlEncode = (rawHTML) ->
  escapedHTML = rawHTML.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/'/g, '&#39;')
  escapedHTML = escapedHTML.replace(/</g, '&lt;').replace(/>/g, '&gt;')
  return escapedHTML

exports.htmlDecode = (encodedHTML) ->
  restoredHTML = encodedHTML.replace(/&gt;/g, '>').replace(/&lt;/g, '<')
  restoredHTML = restoredHTML.replace(/&quot;/g, '"').replace(/&amp;/g, '&')
  restoredHTML = restoredHTML.replace(/&apos;/g, "'")#.replace(/&#39;/g, "'")
  return restoredHTML

exports.parseMetaData = (inputStr, defaultMeta={}) ->
  title = defaultMeta.title ? null
  notebook = defaultMeta.notebook ? null
  tags = defaultMeta.tags ? ['EVND']
  date = defaultMeta.date ? null
  endOfMetaLineNum = 0
  outputStr = ""
  metaStr = ""
  metadata = true

  tagsLowerCase = []
  for tag in tags
    tagsLowerCase.push(tag.toLowerCase())

  metaDict =
    h1: /^#[^#]+?/i # strip all 1st level headings as logically, note title is 1st level
    lh1: /^(=){2,}\s*$/i # for alternate h1 heading
    title: /^Title:\s.*?/i # note title (either MMD metadata 'Title' â€“ must occur before the first blank line â€“ or atx style 1st level heading)
    notebook: /^(Notebook:|=)\s.*?/i # notebook (either MMD metadata 'Notebook' or '= <name>'; must occur before the first blank line)
    tags: /^(Tags:|@)\s.*?/i # note tags (either MMD metadata 'Tags: ' or '@ <tag list>'; must occur before the first blank line)
    date: /^(Date:)\s.*?/i # datek (either MMD metadata 'Date'; must occur before the first blank line)
    endOfMETA: /^\s?$/i # metadata block ends at first blank line

  metaParseFuncs =
    h1: (line) ->
      title ?= line.slice(line.indexOf('#')+1, line.length).trim()
      outputStr += "#{line}\n"
      if endOfMetaLineNum is 0 then endOfMetaLineNum = i
    lh1: (line, prevLine) ->
      if prevLine?.trim()? then title ?= prevLine.trim()
      outputStr += "#{line}\n"
      if endOfMetaLineNum is 0 then endOfMetaLineNum = i - 1
    title: (line) ->
      if metadata
        metaStr += "#{line}\n"
        title = line.slice(line.indexOf(/^Title:\s/i)+7, line.length).trim()
      else
        outputStr += "#{line}\n"
        if endOfMetaLineNum is 0 then endOfMetaLineNum = i
    notebook: (line) ->
      if metadata
        metaStr += "#{line}\n"
        notebook = line.slice(line.indexOf(' ')+1, line.length).trim()
      else
        outputStr += "#{line}\n"
        if endOfMetaLineNum is 0 then endOfMetaLineNum = i
    tags: (line) ->
      if metadata
        metaStr += "#{line}\n"
        rawTags = line.slice(line.indexOf(' ')+1, line.length).split(',')
        for rawTag in rawTags
          rawTag = rawTag.trim()
          rawTagLowerCase = rawTag.toLowerCase()
          if rawTag.length > 0 and not (rawTagLowerCase in tagsLowerCase)
            tags.push(rawTag)
            tagsLowerCase.push(rawTagLowerCase)
      else
        outputStr += "#{line}\n"
        if endOfMetaLineNum is 0 then endOfMetaLineNum = i
    date: (line) ->
      if metadata
        metaStr += "#{line}\n"
        date = line.slice(line.indexOf(' ')+1, line.length).trim()
      else
        outputStr += line + "\n"
        if endOfMetaLineNum is 0 then endOfMetaLineNum = i
    endOfMETA: (line) ->
      if metadata
        metaStr += "#{line}\n"
        metadata = false
        endOfMetaLineNum = i
      outputStr += "#{line}\n"

  lines = inputStr.toString().split(/[\n\r]/)
  for i in [0..lines.length]
    lineMatched = false
    prevLine = l
    l = lines[i]
    continue unless l?
    for k, v of metaDict
      if v.test(l)
        lineMatched = true
        if k is "lh1"
          metaParseFuncs[k] l, prevLine
        else
          metaParseFuncs[k] l
        break
    if not lineMatched
      outputStr += "#{l}\n"

  if metaStr.charAt(metaStr.length-2) isnt '\n' then metaStr += "\n"
  title ?= this.getFirstValidLine(outputStr) ? "New Empty EVND Note"

  outputs =
    title: title
    notebook: notebook
    tags: tags
    date: date
    content: outputStr
    metaText: metaStr
    endOfMetaLineNum: endOfMetaLineNum

  return outputs


# TODO: Use editor.lineTextForBufferRow(bufferRow)??? -- No?
exports.getFirstValidLine = (inputStr, maxLineLength) ->
  lines = inputStr.toString().split(/[\n\r]/)
  for line in lines
    if line and not this.isStringEmpty(line)
      if line.length > maxLineLength
        return line[0:maxLineLength]
      else
        return line
    else
      continue
  null

#
# TODO: Use mime to check file type!
#
exports.isMarkdown = isMarkdown = (filePath) ->
  endsWith = this.endsWith
  endsWith(filePath, '.markdown') or endsWith(filePath, '.md') or
    endsWith(filePath, '.mdown') or endsWith(filePath, '.mkd') or endsWith(filePath, '.mkdown')

#
# TODO: Use mime to check file type!
#       (This is particularly...ugh, needs fixing)
#
exports.isHTML = isHTML = (filePath) ->
  endsWith = this.endsWith
  endsWith(filePath, '.html') or endsWith(filePath, '.htm')

#
# TODO: Use mime to check file type!
#
exports.isText = isText = (filePath) ->
  endsWith = this.endsWith
  endsWith(filePath, '.txt') or endsWith(filePath, '.text')

#
# TODO: Use mime to check file type!
#
exports.isImage = (filePath) ->
  endsWith = this.endsWith
  endsWith(filePath, '.jpg') or endsWith(filePath, '.jpeg') or endsWith(filePath, '.gif') or
      endsWith(filePath, '.png') or endsWith(filePath, '.svg') or endsWith(filePath, '.bmp')

#
# TODO: Use mime to check file type!
#
exports.isPDF = (filePath) ->
  endsWith = this.endsWith
  endsWith(filePath, '.pdf')

#
# TODO: Use mime to check file type!
#
exports.isAudio = (filePath) ->
  endsWith = this.endsWith
  endsWith(filePath, '.mp3') or endsWith(filePath, '.wav')

exports.wrapLine = wrapLine = (lineStr, charLimit=72) ->
  if not lineStr? then return ""
  return lineStr unless lineStr.length > charLimit
  wrappedStr = lineStr.slice(0, charLimit) + "\n"
  wrappedStr += wrapLine(lineStr.slice(charLimit, lineStr.length))
  return wrappedStr

exports.coerceTwoDigit = coerceTwoDigit = (num, limit) ->
  limit ?= 60
  if num > 0 and num < 10
    return "0" + num.toString()
  else if num > 0 and num < limit
    return num.toString()
  else
    div = Math.floor(num / limit)
    rem = num - div*limit
    return [div.toString(), rem.toString()]


exports.enDateHelper = enDateHelper = (enFormatedDate, opts) ->
  deltaYear = opts.year ? 0
  deltaMon = opts.month ? 0
  deltaDay = opts.day ? 0
  deltaHour = opts.hour ? 0
  deltaMinute = opts.minute ? 0
  deltaSecond = opts.second ? 0
  dateFormat = 'YYYYMMDDHHmmss'
  dateStr = enFormatedDate.slice(0, 8) + enFormatedDate.slice(9, 15)
  dateStr = moment(dateStr, dateFormat).subtract(-deltaYear, 'years').format(dateFormat)
  dateStr = moment(dateStr, dateFormat).subtract(-deltaMon, 'months').format(dateFormat)
  dateStr = moment(dateStr, dateFormat).subtract(-deltaDay, 'days').format(dateFormat)
  dateStr = moment(dateStr, dateFormat).subtract(-deltaHour, 'hours').format(dateFormat)
  dateStr = moment(dateStr, dateFormat).subtract(-deltaMinute, 'minutes').format(dateFormat)
  dateStr = moment(dateStr, dateFormat).subtract(-deltaSecond, 'seconds').format(dateFormat)
  return dateStr.slice(0,8) + "T" + dateStr.slice(8, 14)

exports.enDateToTimeString = enDateToTimeString = (enFormatedDate) ->
  enDateFormat = 'YYYYMMDD[T]HHmmss'
  timeString = moment(enFormatedDate, enDateFormat).format("YYYY-MM-DD HH:mm:ss")
  return timeString

exports.mtimeToTimeString = (mtime) ->
  d = new Date(mtime)
  timeString = moment(d).format("YYYY-MM-DD HH:mm:ss")
  return timeString

exports.timeStringToENDate = timeStringToENDate = (timeStr) ->
  enDateFormat = 'YYYYMMDD[T]HHmmss'
  timeStrFormat = "YYYY-MM-DD HH:mm:ss"
  enDateStr = moment(timeStr, timeStrFormat).format(enDateFormat)
  return enDateStr

exports.parseAttribute = parseAttribute = (attrVal, key) ->
  keyIndex = attrVal.indexOf(key)
  return unless keyIndex > -1

  colonIndex = attrVal.indexOf(':', keyIndex + key.length)
  semiColonIndex = attrVal.indexOf(';', colonIndex)
  val = attrVal.slice(colonIndex + 1, semiColonIndex)
  return val

#
# Try to convert other units (ex, cm, etc.) to px
# Example: 2ex => ? px
#
exports.toPixel = toPixel = (oldLength, oldUnit) ->
  defaultFontSize = 16 # in px
  defaultRatioToPx =
    em: defaultFontSize
    ex: 0.5 * defaultFontSize
    cm: 37.7953
    in: 96
    pt: 4.0/3
  return unless defaultRatioToPx[oldUnit]?
  oldLengthVal = parseFloat(oldLength)
  pxVal = oldLengthVal * defaultRatioToPx[oldUnit]
  return pxVal


exports.stringMD5 = stringMD5 = (inputString, encoding) ->
  return null unless inputString?
  crypto ?= require 'crypto'
  encoding ?= 'hex'
  md5 = crypto.createHash('md5')
  md5.update(inputString, 'utf8')
  return md5.digest(encoding)

exports.fileMD5 = fileMD5 = (filePath, encoding) ->
  return unless fs.isFileSync(filePath)
  crypto ?= require 'crypto'
  encoding ?= 'hex'
  fileBin = fs.readFileSync(filePath, 'binary')
  md5 = crypto.createHash('md5')
  md5.update(fileBin, 'binary')
  return md5.digest(encoding)

exports.extractSVG = extractSVG = (svgElement, svgDefsInnerHTML, options) ->
  reStyle = options?.reStyle ? false
  if reStyle
    oldStyle = svgElement.getAttribute("style")
    style = oldStyle
    if options.width?
      svgElement.removeAttribute("width")
      style += " width: #{options.width};"
    if options.height
      svgElement.removeAttribute("height")
      style += " height: #{options.height};"
    svgElement.setAttribute("style", style)

  svgInnerHTML = svgElement.innerHTML
  svgOuterHTML = svgElement.outerHTML
  insertIndex = svgOuterHTML.indexOf(svgInnerHTML)
  svgHTML = svgOuterHTML.slice(0, insertIndex) + svgDefsInnerHTML
  svgHTML += svgOuterHTML.slice(insertIndex, svgOuterHTML.length)
  insertIndex = svgHTML.indexOf('<svg') + 4
  toInsert = ' version="1.1" baseProfile="full" xmlns="http://www.w3.org/2000/svg" '
  svgHTML = svgHTML.slice(0, insertIndex) + toInsert + svgHTML.slice(insertIndex, svgHTML.length)
  return svgHTML

# Loop through input HTML/XML to close certain tags
# Example:
#   <img src="/path/to/image" style="" >
#     to
#   <img src="/path/to/image" style="" />
#
# TODO: I should probably use more regex....
#       Wait what was the point of this?
exports.closeTags = closeTags = (inputStr, tag) ->
  return inputStr unless inputStr? and tag?
  startIndex = 0
  reStr = "<\\s*#{tag}(?:\\s|>)"
  re = new RegExp(reStr)
  while re.test(inputStr.slice(startIndex, inputStr.length))
    strLength = inputStr.length
    tmpIndex = inputStr.slice(startIndex, inputStr.length).search(re) + startIndex
    closeIndex = inputStr.indexOf(">", tmpIndex + tag.length + 1)
    currentTag = inputStr.slice(tmpIndex, closeIndex).replace(/\s+/g,"")
    if currentTag.charAt(currentTag.length-1) is '/'
      startIndex = closeIndex
      continue
    nextTagIndex0 = inputStr.indexOf("<", closeIndex)
    nextTagIndex1 = inputStr.indexOf(">", nextTagIndex0)
    nextTag = inputStr.slice(nextTagIndex0, nextTagIndex1).replace(/\s+/g,"")
    if nextTag.indexOf("</#{tag}") is -1
      inputStr = "#{inputStr.slice(0, closeIndex)}/#{inputStr.slice(closeIndex, strLength)}"
      startIndex = closeIndex + 1
    else
      startIndex = closeIndex
  return inputStr

exports.bindTextHTML = bindTextHTML = (text, html) ->
  markdownDict =
    heading: /^[\s>]*?(#{1,6})([^#].+?)$/i
    lheading: /^[\s>]*?(=|-){2,}\s*$/i
    fenced: /^(?:`{3}|~{3,})(?!`)(.*?)$/i
    image: /!\[(.*?)\]\(\s*(\S+?)\s*(?:"(.*?)"|(?:))\s*\)/i
    footnoteRef: /\[\^([^\[\]\n\r]+?)\](?!\:)/i
    footnote: /^\s*?\[\^(.+?)\]\:/i

  markdownParseFuncs =
    heading: (line, prevLine, num, o) =>
      matched = markdownDict.heading.exec(line)
      level = matched[1].trim().length
      headerTagName = "h#{level.toString()}"
      text = matched[2]
        .trim()
        .replace(/[`\$]/g, '')
        .replace(/\*{3}([^\*]+?)\*{3}/g, '$1')
        .replace(/\*{2}([^\*]+?)\*{2}/g, '$1')
        .replace(/\*{1}([^\*]+?)\*{1}/g, '$1')
        .replace(/~{2}([^~]+?)~{2}/g, '$1')
      oText = o("<#{headerTagName}>#{text}</#{headerTagName}>")
      text = o(oText).text().toLowerCase() #.replace(/\"/g, '\\"')
      text = this.sanitizeHeaderText(text)
      foundHeaders = []
      #console.log "Header text: #{text}"
      for tmpHeader in o(headerTagName)
        tmpHeaderText = this.sanitizeHeaderText(o(tmpHeader).text())
        #console.log "tmp header text: #{tmpHeaderText}"
        if text is tmpHeaderText
          foundHeaders.push(tmpHeader)
      # TODO: what if we found more than 1 header that matched "text"?
      return unless foundHeaders.length > 0
      id = o(foundHeaders[0]).attr("id")
      if sanitizeID(id) isnt id
        id = sanitizeID(id)
        o(foundHeaders[0]).attr("id", id)
      if not id?
        id = "h#{level.toString()}-id-#{sanitizeString(text).replace(/_/g, '-').toLowerCase()}"
        id = sanitizeID(id)
        o(foundHeaders[0]).attr("id", id)
      bindings[num] =
        id: id
        tag: "h#{level.toString()}"
    lheading: (line, prevLine, num, o) =>
      return unless prevLine?.trim()?.length > 0
      if /^\s*?>+?/i.test(line)
        tmpMatch = /^[\s>]*(.+)/i.exec(prevLine)
        return unless tmpMatch? and tmpMatch[1]?.trim().length > 0
        text = tmpMatch[1].trim()
      else
        text = prevLine.trim()
      level = if line.indexOf('-') > -1 then 2 else 1
      foundHeaders = []
      for tmpHeader in o("h#{level.toString()}")
        if o(tmpHeader).text() is text.replace(/[`\$]/g, '')
          foundHeaders.push(tmpHeader)
      # TODO: what if we found more than 1 header that matched "text"?
      return unless foundHeaders.length > 0
      id = o(foundHeaders[0]).attr("id")
      if not id?
        id = "h#{level.toString()}-id-#{sanitizeString(text).replace(/_/g, '-').toLowerCase()}"
        o(foundHeaders[0]).attr("id", id)
      bindings[num-1] =
        id: id
        tag: "h#{level.toString()}"
    fenced: (line, prevLine, num, o) =>
      foundCodeBlocks = o("pre:contains(\"#{prevLine}\")")
      return unless foundCodeBlocks.length > 0
      id = o(foundCodeBlocks[0]).attr("id")
      if not id?
        id = "fenced-code-block-#{codeBlockCount.toString()}"
        o(foundCodeBlocks[0]).attr("id", id)
      bindings[num] =
        id: id
        tag: 'pre'
      codeBlockCount += 1
    image: (line, prevLine, num, o) =>
      matched = markdownDict.image.exec(line)
      altText = matched[1]
      imagePath = matched[2]
      optTitle = matched[3]
      for img in o('img')
        imgTitle = o(img).attr("title")
        imgSRC = o(img).attr("src")
        imgID = o(img).attr("id")
        # TODO: Resolve image path accordingly!
        if imgSRC is imagePath
          unless imgID?
            imgID = "img-src-#{path.basename(imgSRC).replace(/[_\.]/g, '-').toLowerCase()}"
            o(img).attr("id", imgID)
          bindings[num] =
            id: imgID
            tag: 'img'
          break
    footnoteRef: (line, prevLine, num, o) =>
      matched = markdownDict.footnoteRef.exec(line)
      footnoteID = matched[1]
      footnoteRefID = "fnref:#{footnoteID}"
      bindings[num] =
        id: footnoteRefID
        tag: 'a'
    footnote: (line, prevLine, num, o) =>
      matched = markdownDict.footnote.exec(line)
      footnoteID = matched[1]
      footnoteDefID = "fn:#{footnoteID}"
      bindings[num] =
        id: footnoteDefID
        tag: 'li'

  bindings = {}
  textLines = text.split(/[\n\r]/)
  cheerio ?= require 'cheerio'
  o = cheerio.load(html)
  line = null
  prevLine = line
  validPrevLine = line
  fencedCodeBlock = false
  codeBlockCount = 0
  for i in [0..textLines.length]
    prevLine = line
    line = textLines[i]
    continue unless line?
    for k, v of markdownDict
      if v.test(line)
        if k is "fenced"
          # even number of "```"
          fencedCodeBlock = not fencedCodeBlock
          if fencedCodeBlock
            markdownParseFuncs[k] line, prevLine, i, o
        else if not fencedCodeBlock
          markdownParseFuncs[k] line, validPrevLine, i, o
    if line.trim().length > 0 then validPrevLine = line

  bindResult =
    bindings: bindings
    html: o.html()
  return bindResult


exports.findMinDist = findMinDist = ({testVal, toCompare}={}) ->
  return null unless testVal? and toCompare?
  for i in [0..toCompare.length-1]
    if not toCompare[i]? then toCompare.splice(i, 1)
  return null unless toCompare?.length > 1
  toCompare.sort((a,b) => return a-b)
  return null if testVal < toCompare[0] or testVal > toCompare[toCompare.length-1]
  minDist = Math.abs(testVal - toCompare[0])
  closest = toCompare[0]
  for i in [1..toCompare.length]
    continue unless toCompare[i]?
    curDist = Math.abs(testVal - toCompare[i])
    if curDist < minDist
      minDist = curDist
      closest = toCompare[i]
  return closest

exports.defaultExtension = (mimetype) ->
  return "" unless mimetype?
  return "" if mimetype in ['application/octet-stream', 'evernote/x-attachments']
  mime ?= require 'mime'
  defaultExt = mime.extension?(mimetype)
  if defaultExt? then return ".#{defaultExt}" else return ""

exports.iconLookUp = iconLookUp = (filePath) ->
  iconDict =
    "file-media": ['audio', 'video']
    "markdown": ['x-markdown']
    "file-code": [
      'x-java-source',
      'x-c',
      'py',
      'javascript',
      'coffeescript',
      'enml'
    ]
    "file-zip": ['zip']
    "file-pdf": ['pdf']
    "file-binary": ['application']

  enDict =
    "file-media":
      type: "evernote/x-attachments"
      style: "cursor:pointer;"
      height: "43"
    "markdown":
      type: "evernote/x-attachments"
      style: "cursor:pointer;"
      height: "43"
    "file-code":
      type: "evernote/x-attachments"
      style: "cursor:pointer;"
      height: "43"
    "file-zip":
      type: "evernote/x-attachments"
      style: "cursor:pointer;"
      height: "43"
    "file-pdf":
      type: "evernote/x-pdf"
      style: "cursor:pointer;"
      height: "1013"
      width: "100%"
    "file-binary":
      type: "evernote/x-attachments"
      style: "cursor:pointer;"
      height: "43"


  mime ?= require 'mime'
  mimetype = mime.lookup(filePath)
  extension = path.extname(filePath)
  icon = 'file-text'
  tmpInd = mimetype.indexOf('/')
  type0 = mimetype.slice(0, tmpInd)
  type1 = mimetype.slice(tmpInd+1, mimetype.length)
  for k, v in iconDict
    if type1 in v then return {icon: k, mimetype: mimetype, enInfo:enDict[k]}
    if extesnion in v then return {icon: k, mimetype: mimetype, enInfo:enDict[k]}
    if type0 in v then return {icon: k, mimetype: mimetype, enInfo:enDict[k]}

  return {icon: icon, mimetype: mimetype, enInfo: enDict["file-binary"]}

