cheerio = null
utils = require './utils'

stripEmptyLines = (inputStr) ->
  lines = inputStr.split(/[\n\r]/)
  outputStr = ""
  for line in lines
    if line.trim() is "" then continue
    outputStr += line + "\n"
  return outputStr


exports.markdownCleanUp = (markdown) ->
  mdDict =
    blockquote: /^\s*>/i
    codeblock: /^s{4,}|\t/i
    list: /^\s{0,3}(?:\-|\*|\+)\s+/i
    numList: /^\s{0,3}\d*\.\s+/i
    #codeblock1: /^`{3}\S*?\s*$/
  mdDict1 =
    toc: /^\s*\[TOC\]\s*$/i
  mdDict2 =
    codeblock1: /^`{3}\S*?\s*$/i
  unindented = /^\s{0,3}\S+/i


  breakOnSingleNewLine = atom.config.get('ever-notedown.breakOnSingleNewLine')
  lineBreak = if breakOnSingleNewLine then "" else "\n"
  mlines = markdown.toString().split(/[\n\r]/)
  consecutiveEmptyLine = false
  wasInsideBlockToWrap = false
  startOfBlockToWrap = -1
  endOfBlockToWrap = -1
  lastBlockType = ""
  newMarkdown = ""

  for i in [0..mlines.length-1]
    line = mlines[i]

    if consecutiveEmptyLine and line.trim().length is 0 then continue
    consecutiveEmptyLine = if (line.trim().length is 0) then true else false
    #if consecutiveEmptyLine then console.log "This line is empty! " + i

    insideBlockToWrap = false

    for k, v of mdDict2
      if v.test(line)
        if lastBlockType is ""
          startOfBlockToWrap = i
          lastBlockType = k
          insideBlockToWrap = true
        else
          endOfBlockToWrap = i
          lastBlockType = ""
          insideBlockToWrap = true
        break
    if (not insideBlockToWrap) and (lastBlockType of mdDict2) then insideBlockToWrap = true
    #if insideBlockToWrap
    #  console.log "Line: " + i.toString()
    #  console.log "Block type: #{lastBlockType}"

    if not insideBlockToWrap
      for k, v of mdDict
        if v.test(line)
          if k is lastBlockType
            insideBlockToWrap = true
          else if lastBlockType isnt ""
            insideBlockToWrap = true
            endOfBlockToWrap = i-1
            startOfBlockToWrap = i
          else
            insideBlockToWrap = true
            startOfBlockToWrap = i
          lastBlockType = k
          break
      if (not insideBlockToWrap) and wasInsideBlockToWrap
        if breakOnSingleNewLine
          endOfBlockToWrap = i-1
          lastBlockType = ""
        else if not unindented.test(line)
          insideBlockToWrap = true
        else
          endOfBlockToWrap = i-1
          lastBlockType = ""
          insideBlockToWrap = false

    if not insideBlockToWrap
      for k, v of mdDict1
        if v.test(line)
          insideBlockToWrap = true


    if insideBlockToWrap and not wasInsideBlockToWrap and startOfBlockToWrap is i
      newMarkdown += "#{lineBreak}#{line}\n"
    else if (not insideBlockToWrap) and wasInsideBlockToWrap and endOfBlockToWrap is (i-1)
      newMarkdown += "#{line}\n#{lineBreak}"
    else if (startOfBlockToWrap is i) and (endOfBlockToWrap is (i-1))
      newMarkdown += "#{lineBreak}#{lineBreak}#{line}\n"
    else
      newMarkdown += "#{line}\n"


    wasInsideBlockToWrap = insideBlockToWrap

  return newMarkdown

exports.toMarkdown = (html, options) ->
  options ?= {}
  options.codeInline = true
  options.inCodeBlock = false

  cheerio ?= require 'cheerio'

  o = cheerio.load(html)
  refStyle = options.refStyle ? false
  if refStyle
    refs = []

  parseHeaders = (oheader, options) =>
    # alternative o(oheader).get(0).tagName
    return o.html(oheader) unless oheader?.tagName?.slice(0, 1)?.toLowerCase() is 'h'
    breakOnSingleNewLine = options.breakOnSingleNewLine ? false
    preChar = options.preChar ? ""
    style = options.style ? "#"
    headerHTML = o(oheader).html()
    headerText = headerHTML
    for headerChildElm in o(oheader).children()
      headerChildElmText = parseElm(headerChildElm, options)
      headerText = utils.literalReplace(headerText, o.html(headerChildElm), headerChildElmText, replaceOptions)
    headerText = utils.htmlDecode(headerText).replace(/\n/g, ' ')
    tagName = oheader.tagName
    headerLevel = parseInt(tagName.slice(1, tagName.length))
    headerSymbol = ""
    if headerLevel > 2 or style is "#"
      for i in [0..headerLevel-1]
        headerSymbol += "#"
      line = "\n#{preChar}#{headerSymbol} #{headerText}   \n"
    else
      headerSymbol =  if headerLevel is 1 then "==========" else "----------"
      line = "\n#{preChar}#{headerText}\n#{preChar}#{headerSymbol}   \n"
    if not breakOnSingleNewLine then line += "\n"
    return line

  parseParagraph = (opar, options) =>
    return o.html(opar) unless opar?.tagName?.toLowerCase() is 'p'
    breakOnSingleNewLine = options.breakOnSingleNewLine ? false
    preChar = options.preChar ? ""
    parHTML = o(opar).html()
    parText = parHTML
    newOptions = {}
    for k, v of options
      newOptions[k] = v
    newOptions.sameParagraph = true
    for oparElm in o(opar).children()
      oparElmText = parseElm(oparElm, newOptions)
      parText = utils.literalReplace(parText, o.html(oparElm), oparElmText, replaceOptions)
    if breakOnSingleNewLine
      parText += "\n"
    else
      parText += "\n\n"
    regTmp = new RegExp("\n(?!(?:#{preChar.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}))", "g")
    parText = preChar + parText.replace(regTmp, "\n#{preChar}")
    parText = utils.htmlDecode(parText)
    return parText

  parseLineBreak = (obr, options) =>
    return o.html(obr) unless obr?.tagName?.toLowerCase() is 'br'
    preChar = options.preChar ? ""
    sameParagraph = options.sameParagraph ? false
    breakOnSingleNewLine = options.breakOnSingleNewLine ? false
    if breakOnSingleNewLine
      brText = ""
    else
      brText = "    "
    if not sameParagraph then brText += "\n#{preChar}"
    return brText

  parseUnderscore = (ouds, options) =>
    return o.html(ouds)

  parseStrong = (ostrong, options) =>
    return o.html(ostrong) unless ostrong?.tagName?.toLowerCase() in ['strong', 'b']
    strongStyle = options.strongStyle ? "**"
    strongHTML = o(ostrong).html()
    strongText = strongHTML
    for elm in o(ostrong).children()
      elmText = parseElm(elm, options)
      strongText = utils.literalReplace(strongText, o.html(elm), elmText)
    return "#{strongStyle}#{strongText}#{strongStyle}"

  parseEmphasis = (oemph, options) =>
    return o.html(oemph) unless oemph?.tagName?.toLowerCase() in ['i', 'em']
    emphasisStyle = options.emphasisStyle ? "_"
    emphHTML = o(oemph).html()
    emphText = emphHTML
    for elm in o(oemph).children()
      elmText = parseElm(elm, options)
      emphText = utils.literalReplace(emphText, o.html(elm), elmText, replaceOptions)
    return "#{emphasisStyle}#{emphText}#{emphasisStyle}"

  parseDel = (odel, options) =>
    return o.html(odel) unless odel?.tagName?.toLowerCase() is 'del'
    delStyle = options.delStyle ? "~~"
    delHTML = o(odel).html()
    delText = delHTML
    for elm in o(odel).children()
      elmText = parseElm(elm, options)
      delText = utils.literalReplace(delText, o.html(elm), elmText, replaceOptions)
    return "#{delStyle}#{delText}#{delStyle}"

  parseKBD = (okbd, options) =>
    return "<kbd>#{o(okbd).html()}</kbd>"

  parseCode = (ocode, options) =>
    return o.html(ocode) unless ocode?.tagName?.toLowerCase() is 'code'
    codeInline = options.codeInline ? true
    if codeInline
      codeMarkdown = parseCodeInline(ocode, options)
    else
      codeMarkdown = parseCodeBlock(ocode, options)
    return codeMarkdown

  parseCodeInline = (ocode, options) =>
    return o.html(ocode) unless ocode?.tagName?.toLowerCase() is 'code'
    codeText = utils.htmlDecode(o(ocode).text())
    codeText = utils.literalReplace(codeText, '\\$', '\\\\$')
    if codeText.indexOf('`') > -1
      codeMarkdown = "``#{codeText}``"
    else
      codeMarkdown = "`#{codeText}`"
    return codeMarkdown

  parseCodeBlock = (ocode, options)  =>
    return o.html(ocode) unless ocode?.tagName?.toLowerCase() in ['code']
    return o.html(ocode) unless o(ocode).parent().tagName?.toLowerCase() is 'pre'
    codeBlockStyle = options.codeBlockStyle ? '    '
    rawCodeText = o(ocode).text()
    rawCodeLines = rawCodeText.split(/[\n\r]/)
    codeText = ""
    for codeLine in rawCodeLines
      codeText += codeBlockStyle + codeLine + "\n"
    codeText = utils.htmlDecode(codeText)
    codeText = utils.literalReplace(codeText, '\\$', '\\\\$')
    return codeText

  parseListItem = (oli, options) =>
    return o.html(oli) unless oli?.tagName?.toLowerCase() is 'li'
    listItemHTML = o(oli).html()
    listItemText = listItemHTML
    for listItemElm in o(oli).children()
      listItemElmText = parseElm(listItemElm, options)
      listItemText = utils.literalReplace(listItemText, o.html(listItemElm), listItemElmText, replaceOptions)
    return listItemText

  parseUnorderedList = (olist, options) =>
    return o.html(olist) unless olist?.tagName?.toLowerCase() is 'ul'
    breakOnSingleNewLine = options.breakOnSingleNewLine ? false
    preChar = options.preChar ? ""
    listStyle = options.listStyle ? '-   '
    indentStyle = options.indentStyle ? '    '
    newOptions = {}
    for k, v of options
      newOptions[k] = v
    newOptions.preChar = preChar + indentStyle

    listText = ""
    for listItem in o(olist).children('li')
      listItemText = parseListItem(listItem, newOptions)
      listText += preChar + listStyle + listItemText + "\n"
    if breakOnSingleNewLine
      listText += "\n"
    else
      listText += "\n\n"
    return listText

  parseOrderedList = (olist, options) =>
    return o.html(olist) unless olist?.tagName?.toLowerCase() is 'ol'
    breakOnSingleNewLine = options.breakOnSingleNewLine ? false
    preChar = options.preChar ? ""
    indentStyle = options.indentStyle ? '    '
    newOptions = {}
    for k, v of options
      newOptions[k] = v
    newOptions.preChar = preChar + indentStyle

    listText = ""
    i = 1
    for listItem in o(olist).children('li')
      listItemText = parseListItem(listItem, newOptions)
      listStyle = "#{i.toString()}.   "
      i += 1
      listText += preChar + listStyle + listItemText + "\n"
    if breakOnSingleNewLine
      listText += "\n"
    else
      listText += "\n\n"
    return listText

  parseImage = (oimg, options) =>
    return o.html(oimg) unless oimg?.tagName?.toLowerCase() is 'img'
    refStyle = options.refStyle ? false
    altText = o(oimg).attr("alt")
    imgSRC = o(oimg).attr("src")
    optTitle = o(oimg).attr("title") ? "Optional title"
    if refStyle
      id = (refs?.length + 1).toString()
      refDef = "[#{id}]: #{imgSRC} \"#{optTitle}\""
      imgText = "![#{altText}][#{id}]"
      refs.push(refDef)
    else
      imgText = "![#{altText}](#{imgSRC} \"#{optTitle}\")"
    return imgText

  parseEmbed = (oebd, options) =>
    return o.html(oebd) unless oebd?.tagName?.toLowerCase() is 'embed'
    refStyle = options.refStyle ? false
    altText = o(oebd).attr("alt")
    ebdSRC = o(oebd).attr("src")
    optTitle = o(oebd).attr("title") ? "Optional title"
    if refStyle
      id = (refs?.length + 1).toString()
      refDef = "[#{id}]: #{ebdSRC} \"#{optTitle}\""
      ebdText = "!{#{altText}}[#{id}]"
      refs.push(refDef)
    else
      ebdText = "!{#{altText}}(#{ebdSRC} \"#{optTitle}\")"
    return ebdText

  parseLink = (olink, options) =>
    return o.html(olink) unless olink?.tagName?.toLowerCase() is 'a'
    refStyle = options.refStyle ? false
    linkText = o(olink).text()
    href = o(olink).attr("href")
    unless href?.length > 0
      return linkText
      #if linkText.length > 0 then return " [#{linkText}] " else return ""
    optTitle = o(olink).attr("title")
    optTitle = if optTitle? then " \"#{optTitle}\"" else ""
    if refStyle
      id = (refs?.length + 1).toString()
      refDef = "[#{id}]: #{href} #{optTitle}"
      linkMarkdown = "![#{linkText}][#{id}]"
      refs.push(refDef)
    else if linkText is href
      linkMarkdown = href # Auto link!
    else
      linkMarkdown = "[#{linkText}](#{href} #{optTitle})"
    return linkMarkdown

  parseHR = (ohr, options) =>
    return o.html(ohr) unless ohr?.tagName?.toLowerCase() is 'hr'
    breakOnSingleNewLine = options.breakOnSingleNewLine ? false
    preChar = options.preChar ? ""
    hrStyle = options.hrStyle ? '--------------'
    if breakOnSingleNewLine
      hrMarkdown = preChar + hrStyle + "\n"
    else
      hrMarkdown = preChar + hrStyle + "\n\n"
    return hrMarkdown

  parseBlockquote = (oblock, options) =>
    return o.html(oblock) unless oblock?.tagName?.toLowerCase() is 'blockquote'
    blockquoteStyle = options.blockquoteStyle ? "> "
    preChar = options.preChar ? ""
    breakOnSingleNewLine = options.breakOnSingleNewLine ? false
    newOptions = {}
    for k, v of options
      newOptions[k] = v
    newOptions.preChar = preChar + blockquoteStyle
    blockHTML = o(oblock).html()
    blockText = blockHTML
    for elm in o(oblock).children()
      elmText = parseElm(elm, newOptions)
      blockText = utils.literalReplace(blockText, o.html(elm), elmText)

    if breakOnSingleNewLine
      blockText += "\n"
    else
      blockText += "\n\n"
    blockText = utils.htmlDecode(blockText)
    return blockText

  parseLabel = (olabel, options) =>
    return o.html(olabel) unless olabel?.tagName?.toLowerCase() is 'label'
    labelHTML = o(olabel).html()
    labelText = labelHTML
    for elm in o(olabel).children()
      elmText = parseElm(elm, options)
      labelText = utils.literalReplace(labelText, o.html(elm), elmText, replaceOptions)
    labelText = utils.htmlDecode(labelText)
    return labelText

  parseObject = (obj, options) =>
    return o.html(obj) unless obj?.tagName?.toLowerCase() is 'object'
    unless o(obj).attr("class")?.indexOf('en-todo') > -1
      return parseUnknownElement(obj, options)
    checked = o(obj).attr("class")?.indexOf("checked") > -1
    objText = if checked then "[x]" else "[ ]"
    objText += " " + o(obj).html()
    for elm in o(obj).children()
      elmText = parseElm(elm, options)
      objText = utils.literalReplace(objText, o.html(elm), elmText, replaceOptions)
    return objText

  parseInput = (inp, options) =>
    return o.html(inp) unless inp?.tagName?.toLowerCase() is 'input'
    return parseUnknownElement(inp, options) unless o(inp).attr("type") is 'checkbox'
    checked = o(inp).attr("class")?.indexOf("checked") > -1
    inputText = if checked then "[x]" else "[ ]"
    inputText += " " + o(inp).text()
    return inputText

  parseInlineMath = (ospan, options) =>
    return o.html(ospan) unless ospan?.tagName?.toLowerCase() is 'span'
    return o.html(ospan) unless o(ospan).hasClass("math") or o(ospan).attr("tooltip")?.length > 0
    mathText = ""
    for mathSpan in o(ospan).find('span')
      if o(mathSpan).attr("title") in ["raw_mathjax_script"]
        mathText += utils.htmlDecode(o(mathSpan).text())
    return mathText

  parseMath = (ospan, options) =>
    return o.html(ospan) unless ospan?.tagName?.toLowerCase() is 'span'
    return o.html(ospan) unless o(ospan).attr("title") in ["hidden_script_mathjax"]
    mathText = "\n"
    for mathSpan in o(ospan).find('span')
      if o(mathSpan).attr("title") in ["raw_mathjax_script"]
        mathText += utils.htmlDecode(o(mathSpan).text())
    mathText += "\n"
    return mathText

  parseSpan = (ospan, options) =>
    return o.html(ospan) unless ospan?.tagName?.toLowerCase() is 'span'
    return parseMath(ospan, options) if o(ospan).attr("title") in ["hidden_script_mathjax"]
    return "" if o(ospan).attr("title") is "MathJax_SVG" and o(ospan).children().length is 1 and o(ospan).children('img').length is 1
    if o(ospan).hasClass("math") or o(ospan).attr("tooltip")?.length > 0
      return parseInlineMath(ospan, options)
    # TODO: inline-block? block?
    spanStyle = o(ospan).attr("style")
    markReg = /background\-color\:\s*yellow/i # Highlighted text?
    if (not options.inCodeBlock) and spanStyle?
      if markReg.test(spanStyle)
        spanText = "<mark>" + o(ospan).html() + "</mark>"
      else
        spanText = o.html(ospan) # Outer HTML!
    else
      spanText = o(ospan).html()
    for elm in o(ospan).children()
      elmText = parseElm(elm, options)
      spanText = utils.literalReplace(spanText, o.html(elm), elmText, replaceOptions)
    spanText = utils.htmlDecode(spanText)
    return "#{spanText}"

  parsePre = (opre, options) =>
    return o.html(opre) unless opre?.tagName?.toLowerCase() is 'pre'
    breakOnSingleNewLine = options.breakOnSingleNewLine ? false
    newOptions = {}
    for k, v of options
      newOptions[k] = v
    newOptions.codeInline = false
    preTitle = o(opre).attr("title")
    if preTitle.indexOf("fenced-code-block") > -1
      lang = preTitle.slice(18, preTitle.length)
      preWrap = "```#{lang}\n"
      newOptions.inCodeBlock = true

    preHTML = o(opre).html()
    preText = preHTML
    for elm in o(opre).children()
      elmText = parseElm(elm, newOptions)
      preText = utils.literalReplace(preText, o.html(elm), elmText, replaceOptions)
    preText += "\n"
    preText = utils.htmlDecode(preText)
    if preText.charAt(0) is '\n' then preText = preText.slice(1, preText.length)
    if preWrap? then preText = "#{preWrap}#{preText}```"
    if not breakOnSingleNewLine then preText += "\n"
    return preText

  parseTableRow = (otr, options) =>
    return o.html(otr) unless otr?.tagName?.toLowerCase() is 'tr'
    newOptions = {}
    for k, v of options
      newOptions[k] = v
    i = 0
    tText = o(otr).html()
    for tElm in o(otr).children()
      newOptions.colCharCount = options.maxColCharCount?[i]
      newOptions.colAlign = options.colAlignments?[i]
      elmText = parseElm(tElm, newOptions)
      tText = utils.literalReplace(tText, o.html(tElm), elmText, replaceOptions)
      i += 1
    tText = "|" + utils.htmlDecode(tText).replace(/\n/g, '') + "\n"
    return tText

  parseTableBody = (otbody, options) =>
    return o.html(otbody) unless otbody?.tagName?.toLowerCase() is 'tbody'
    tText = o(otbody).html()
    for elm in o(otbody).children()
      elmText = parseElm(elm, options)
      tText = utils.literalReplace(tText, o.html(elm), elmText, replaceOptions)
    tText = utils.htmlDecode(tText)
    return tText

  parseTableCell = (otcell, options) =>
    return o.html(otcell) unless otcell?.tagName?.toLowerCase() in ['th', 'td']
    tcellAlign = options.colAlign
    tcellText = o(otcell).html()
    for elm in o(otcell).children()
      elmText = parseElm(elm, options)
      tcellText = utils.literalReplace(tcellText, o.html(elm), elmText, replaceOptions)
    tcellText = tcellText.replace(/\$/g, '\\$$').replace(/\n/g, '')
    if options.colCharCount?
      if tcellText.length < (options.colCharCount - 3)
        padLength = options.colCharCount - 3 - tcellText.length
        padLengthLeft = Math.round(padLength*0.5)
        padLengthRight = padLength - padLengthLeft
        padLeft = ""
        padRight = ""
        for i in [0..padLengthLeft-1]
          padLeft += " "
        if padLengthRight > 0
          for i in [0..padLengthRight-1]
            padRight += " "
        switch tcellAlign
          when "left" then tcellText += padLeft + padRight
          when "right" then tcellText = padLeft + padRight + tcellText
          else tcellText = padLeft + tcellText + padRight
    tcellText = " " + tcellText + " |"
    return tcellText

  parseTableHead = (othead, options) =>
    return o.html(othead) unless othead?.tagName?.toLowerCase() is 'thead'
    return o.html(othead) unless o(othead).children('tr').length is 1
    colAlignments = []
    styleReg = /text\-align\:(.+?)(?:;|(?:))$/i
    tHeadRow =  o(othead).children('tr')[0]
    options.maxColCharCount ?= []
    i = 0
    for col in o(tHeadRow).children('th')
      colStyles = o(col).attr("style")
      if styleReg.test(colStyles)
        colAlign = styleReg.exec(colStyles)[1].trim()
      else
        colAlign = "none"
      colAlignments.push colAlign
      unless options.maxColCharCount?[i]?
        options.maxColCharCount[i] = o(col).text().length + 3
      i += 1

    makeCenterAlignment = (curColCharCount) ->
      tmpAlignText = " "
      for j in [1..colCharCount-3]
        tmpAlignText += "-"
      tmpAlignText += " |"
      return tmpAlignText

    makeLeftAlignment = (curColCharCount) ->
      tmpAlignText = ":"
      for j in [1..colCharCount-3]
        tmpAlignText += "-"
      tmpAlignText += " |"
      return tmpAlignText

    makeRightAlignment = (curColCharCount) ->
      tmpAlignText = " "
      for j in [1..colCharCount-3]
        tmpAlignText += "-"
      tmpAlignText += ":|"
      return tmpAlignText

    alignText = "|"
    i = 0
    for colAlign in colAlignments
      colCharCount = options.maxColCharCount[i]
      switch colAlign
        when "center" then alignText += makeCenterAlignment(colCharCount)
        when "left" then alignText += makeLeftAlignment(colCharCount)
        when "right" then alignText += makeRightAlignment(colCharCount)
        else alignText += makeCenterAlignment(colCharCount)
      i += 1

    tHeadText = parseElm(o(othead).children('tr')[0], options) + alignText + "\n"
    return tHeadText

  parseTable = (otable, options) =>
    return o.html(otable) unless otable?.tagName?.toLowerCase() is 'table'
    maxColCharCount = []
    colAlignments = []
    styleReg = /text\-align\:(.+?)(?:;|(?:))$/i
    for thead in o(otable).children('thead, tbody')
      for tr in o(thead).children('tr')
        i = 0
        for col in o(tr).children('td, th')
          colStyles = o(col).attr("style")
          if styleReg.test(colStyles)
            colAlign = styleReg.exec(colStyles)[1]
          else
            colAlign = "none"
          colCharCount = Math.min(o(col).text().length + 3, 35)
          if maxColCharCount.length < (i+1)
            maxColCharCount.push(colCharCount)
            colAlignments.push(colAlign)
          else
            if colCharCount > maxColCharCount[i] then maxColCharCount[i] = colCharCount
          if maxColCharCount[i] < 4 then maxColCharCount[i] = 4
          i += 1
    options.maxColCharCount = maxColCharCount
    options.colAlignments = colAlignments
    tText = o(otable).html()
    for tElm in o(otable).children()
      elmText = parseElm(tElm, options)
      tText = utils.literalReplace(tText, o.html(tElm), elmText, replaceOptions)
    tText = stripEmptyLines(utils.htmlDecode(tText)) + "\n"
    return tText

  parseSup = (osup, options) =>
    return o.html(osup) unless osup?.tagName?.toLowerCase() is 'sup'
    if o(osup).children().length is 1 and o(osup).children('a').length is 1
      # This is a footnote reference!
      fnLink = o(osup).children('a')[0]
      fnID = utils.htmlDecode(o(fnLink).attr("href").replace(/#fn\:/i, '')).replace(/%20/g, ' ')
      return "[^#{fnID}]"
    else
      return parseUnknownElement(osup, options)

  parseFootnoteDiv = (odiv, options) =>
    return o.html(odiv) unless odiv?.tagName?.toLowerCase() is 'div'
    return parseDiv(odiv) unless o(odiv).attr("title") is "footnotes"
    return parseDiv(odiv) unless o(odiv).children('hr').length is 1
    return parseDiv(odiv) unless o(odiv).children('ol').length is 1
    fnText = "\n"
    for li in o(odiv).children('ol').children('li')
      for link in o(li).children('a')
        if o(link).attr("href")?.indexOf('#fnref:') > -1
          fnRefID = utils.htmlDecode(o(link).attr("href").replace(/#fnref\:/i, '')).replace(/%20/g, ' ')
          fnText += "[^#{fnRefID}]: "
          break
      li0 = o(o.html(li))
      for link0 in o(li0).children('a')
        if o(link0).attr("href")?.indexOf('#fnref:') > -1
          o(link0).remove()
          break
      listItemText = parseListItem(o(li0)[0], options).replace(/\[.+?\]\(.+?\)/i, '')
      fnText += listItemText.replace(/\n{2,}/g, '\n') + "\n\n"
    fnText = utils.htmlDecode(fnText)
    return fnText

  parseDiv = (odiv, options) =>
    return o.html(odiv) unless odiv?.tagName?.toLowerCase() is 'div'
    return "" if o(odiv).attr("title") in ["MathJax_SVG_Display"]
    return "" if o(odiv).attr("class") in ["MathJax_SVG_Display"]
    paragraphStyle = [
      'margin: 15px 0; margin-top: 0;'
      'margin: 15px 0;'
    ]
    divStyle = o(odiv).attr("style")
    divClass = o(odiv).attr("class")
    divTitle = o(odiv).attr("title")
    if divTitle is "footnotes" and o(odiv).children().length is 2 and o(odiv).children('hr').length is 1 and o(odiv).children('ol').length is 1
      return parseFootnoteDiv(odiv, options)
    if divClass isnt "ever-notedown-preview" and divStyle? and not (divStyle in paragraphStyle)
      divHTML = o.html(odiv) # outerHTML!
      styledDiv = true
    else
      styledDiv = false
      divHTML = "\n" + o(odiv).html() + "\n"
    divText = divHTML
    newOptions = {}
    for k, v of options
      newOptions[k] = v
    newOptions.styledDiv = true
    for divElm in o(odiv).children()
      elmText = parseElm(divElm, newOptions)
      divText = utils.literalReplace(divText, o.html(divElm), elmText, replaceOptions)
    divText = utils.htmlDecode(divText)
    return divText

  parseUnknownElement = (oelm, options) =>
    return unless o(oelm).length is 1
    elmHTML = o(oelm).html()
    elmText = elmHTML
    for childElm in o(oelm).children()
      childElmText = parseElm(childElm, options)
      oldElmText = elmText
      elmText = utils.literalReplace(elmText, o.html(childElm), childElmText, replaceOptions)
    elmText = utils.htmlDecode(elmText)
    return elmText

  parseElm = (oelm, options) =>
    return "" unless o(oelm).length >= 1
    if o(oelm).length > 1
      elmsHTML = o.html(oelm)
      elmsText = elmsHTML
      for childElm in oelm
        childElmText = parseElm(childElm, options)
        elmsText = utils.literalReplace(elmsText, o.html(childElm), childElmText, replaceOptions)
      elmText = utils.htmlDecode(elmsText)
    else
      tag = oelm.tagName ? ""
      tag = tag.toLowerCase()
      if tag in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']
        elmText = parseHeaders(oelm, options)
      else
        switch tag
          when 'p' then elmText = parseParagraph(oelm, options)
          when 'pre' then elmText = parsePre(oelm, options)
          when 'img' then elmText = parseImage(oelm, options)
          when 'embed' then elmText = parseEmbed(oelm, options)
          when 'code' then elmText = parseCode(oelm, options)
          when 'kbd' then elmText = parseKBD(oelm, options)
          when 'a' then elmText = parseLink(oelm, options)
          when 'strong' then elmText = parseStrong(oelm, options)
          when 'b' then elmText = parseStrong(oelm, options)
          when 'em' then elmText = parseEmphasis(oelm, options)
          when 'i' then elmText = parseEmphasis(oelm, options)
          when 'u' then elmText = parseUnderscore(oelm, options)
          when 'del' then elmText = parseDel(oelm, options)
          when 'span' then elmText = parseSpan(oelm, options)
          when 'ul' then elmText = parseUnorderedList(oelm, options)
          when 'ol' then elmText = parseOrderedList(oelm, options)
          when 'blockquote' then elmText = parseBlockquote(oelm, options)
          when 'hr' then elmText = parseHR(oelm, options)
          when 'br' then elmText = parseLineBreak(oelm, options)
          when 'div' then elmText = parseDiv(oelm, options)
          when 'label' then elmText = parseLabel(oelm, options)
          when 'object' then elmText = parseObject(oelm, options)
          when 'input' then elmText = parseInput(oelm, options)
          when 'table' then elmText = parseTable(oelm, options)
          when 'thead' then elmText = parseTableHead(oelm, options)
          when 'tbody' then elmText = parseTableBody(oelm, options)
          when 'tr' then elmText = parseTableRow(oelm, options)
          when 'th' then elmText = parseTableCell(oelm, options)
          when 'td' then elmText = parseTableCell(oelm, options)
          when 'sup' then elmText = parseSup(oelm, options)
          else elmText = parseUnknownElement(oelm, options)
    return elmText

  rootElms = o.root().children()
  if rootElms.length is 1 and rootElms[0].tagName is 'div'
    html = o(rootElms[0]).html()
    o = cheerio.load(html)
  replaceOptions = {replaceOnce: true}
  markdownText = parseElm(o.root().children(), options)
  if refs?.length > 0
    for refDef in refs
      continue unless refDef?
      markdownText += refDef + "\n"

  if atom.config.get('ever-notedown.convertHexNCR2String')
    markdownText = utils.convertHexNCR2String(markdownText)
  return markdownText

