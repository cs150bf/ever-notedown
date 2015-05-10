# Used some code from 
# https://github.com/atom/markdown-preview/blob/9ff76ad3f6407a0fb68163a538c6d460280a1718/lib/renderer.coffee
#
# Reproduced license info:
#  Copyright (c) 2014 GitHub Inc.
#
#  Permission is hereby granted, free of charge, to any person obtaining
#  a copy of this software and associated documentation files (the
#  "Software"), to deal in the Software without restriction, including
#  without limitation the rights to use, copy, modify, merge, publish,
#  distribute, sublicense, and/or sell copies of the Software, and to
#  permit persons to whom the Software is furnished to do so, subject to
#  the following conditions:
#
#  The above copyright notice and this permission notice shall be
#  included in all copies or substantial portions of the Software.
#  
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
#  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
#  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
#  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#  

path = require 'path'
_ = require 'underscore-plus'
cheerio = require 'cheerio'
fs = require 'fs-plus'
Highlights = require 'highlights'
{$} = require 'atom-space-pen-views'
roaster = null # Defer until used
inliner = null # Defer until used
{scopeForFenceName} = require './extension-helper'
temp = null
mathjaxutils = null # require './mathjaxutils'
mathjaxHelper = null # require './mathjax-helper'
chartsHelper = null
utils = null

highlighter = null
{resourcePath} = atom.getLoadSettings()
packagePath = path.dirname(__dirname)


inline = "$"
MATHSPLIT = /(\$\$?|\\(?:begin|end)\{[a-z]*\*?\}|\\[\\{}$]|[{}]|(?:\n\s*)+|@@\d+@@)/i


# TODO: Use BufferedNodeProcess/BufferedProcess
stdoutParse = (stdout) ->
  if not stdout
    console.error("Empty stdout!")
    result = null
  else
    result = if stdout is "\n" then null else stdout
  result

stderrParse = (stderr) ->
  if stderrLines
    stderrLines = stderr.split(/(\r?\n)/g)
  else
    stderrLines = []


#
# Ever Notedown: modified to use tokenizeCodeBlocks for more consistency
#                between preview and exported HTML
#
exports.toDOMFragment = (text='', mathjax, filePath, metaInfo, grammar, callback) ->
  render text, mathjax, filePath, (error, html) =>
    return callback(error) if error?

    # Default code blocks to be coffee in Literate CoffeeScript files
    defaultCodeLanguage = 'coffee' if grammar?.scopeName is 'source.litcoffee'
    # For EVND, it makes a lot more sense to just go for the "tokenizeCodeBlocks"
    #   Original: convertCodeBlocksToAtomEditors(domFragment, defaultCodeLanguage)
    html = tokenizeCodeBlocks(html, defaultCodeLanguage)

    utils ?= require('./utils')
    bindResult = utils.bindTextHTML(text, html)
    bindings = bindResult.bindings
    html = bindResult.html
    bindings.endOfMetaLineNum = metaInfo.endOfMetaLineNum

    if metaInfo? then html = renderMeta(metaInfo) + html
    template = document.createElement('template')
    template.innerHTML = html
    domFragment = template.content.cloneNode(true)

    if mathjax
      mathjaxHelper ?= require('./mathjax-helper')
      elms = [].slice.call(domFragment.querySelectorAll('.math'))
      if elms? and elms.length > 0
        mathjaxHelper.mathProcessor elms, domFragment, bindings, filePath, callback
      else
        callback(null, domFragment, bindings)
    else
      callback(null, domFragment, bindings)

exports.toHTML = (text='', mathjax, filePath, metaInfo, grammar, callback) ->
  render text, mathjax, filePath, (error, html) =>
    return callback(error) if error?

    # Default code blocks to be coffee in Literate CoffeeScript files
    defaultCodeLanguage = 'coffee' if grammar?.scopeName is 'source.litcoffee'
    html = tokenizeCodeBlocks(html, defaultCodeLanguage)
    if metaInfo? then html = renderMeta(metaInfo) + html
    if mathjax
      mathjaxHelper ?= require('./mathjax-helper')
      mathjaxHelper.mathRenderer(html, filePath, callback)
    else
      callback(null, html)

render = (text, mathjax, filePath, callback) ->
  if mathjax
    textWithEscapedDollarSign = text.replace(/([^\\])\\\$/g, '$1escapedDollarSignEVND')
    mathjaxutils ?= require './mathjaxutils'
    text_and_math = mathjaxutils.remove_math(textWithEscapedDollarSign)
    text = text_and_math[0].replace(/escapedDollarSignEVND/g, '$')
    math = text_and_math[1]

  roaster ?= require 'roaster'
  options =
    sanitize: false
    breaks: atom.config.get('ever-notedown.breakOnSingleNewline')
    smartypants: atom.config.get('ever-notedown.smartyPants')

  # Remove the <!doctype> since otherwise marked will escape it
  # https://github.com/chjj/marked/issues/354
  text = text.replace(/^\s*<!doctype(\s+.*)?>\s*/i, '')

  roaster text, options, (error, html) =>
    return callback(error) if error?

    html = sanitize(html)
    html = resolveImagePaths(html, filePath)
    html = resolveAttachments(html, filePath)
    if atom.config.get('ever-notedown.checkbox')
      if html.indexOf('[ ]') > -1 or html.indexOf('[x]') > -1
        html = convertCheckBoxes(html)
    if atom.config.get('ever-notedown.footnote')
      html = generateFootnotes(html)
    if mathjax
      modMath = resolveMath(math)
      html = mathjaxutils.replace_math(html, modMath)
      # TODO:
      # EVND: I don't know why but this thing only renders properly if there's at least
      # two <span class="math"></span>...
      if math.length is 1
        html += '<span class="math" style="display:none;"><script type="math/tex">$x$</script></span>'
    if atom.config.get('ever-notedown.toc')
      if text.indexOf('[TOC]') > -1 or text.indexOf('[toc]') > -1
        html = generateTOC(html)

    callback(null, html.trim())


# Take an array of Strings of the format $$...$$, $...$, or \[...\]
# and enclose the acutal equations with appropriate HTML tags
resolveMath = (eqns) ->
  modifiedEqns = []
  for equation in eqns
    if equation.slice(0,2) is '$$' or equation.slice(0,2) is '\\['
      equation = equation.slice(2, -2)
      equation = '<span class="math"><script type="math/tex; mode=display">' + equation
    else
      equation = equation.slice(1, -1)
      equation = '<span class="math"><script type="math/tex">' + equation
    equation += '</script></span>'
    modifiedEqns.push(equation)
  return modifiedEqns

sanitize = (html) ->
  o = cheerio.load(html)
  o('script').remove()
  attributesToRemove = [
    'onabort'
    'onblur'
    'onchange'
    'onclick'
    'ondbclick'
    'onerror'
    'onfocus'
    'onkeydown'
    'onkeypress'
    'onkeyup'
    'onload'
    'onmousedown'
    'onmousemove'
    'onmouseover'
    'onmouseout'
    'onmouseup'
    'onreset'
    'onresize'
    'onscroll'
    'onselect'
    'onsubmit'
    'onunload'
  ]
  o('*').removeAttr(attribute) for attribute in attributesToRemove
  o.html()

resolveAttachments = (html, filePath) ->
  r= /!\{(.*?)\}\(\s*?([^\"\n\r]+?)(?:\s*?[\"“](.*?)[\"”]|\s*?)\)/gi
  o = cheerio.load(html)

  parseAttachmentsInElement = (elm) =>
    if elm?.tagName in ["code", "pre", "head", "script"]
      return
    else if o(elm).children()?.length > 0
      for childElm in o(elm).children()
        parseAttachmentsInElement(childElm)
        #return
    tmpElm = cheerio.parseHTML(o.html(elm))[0]
    for childElm in cheerio(tmpElm).children()
      cheerio(childElm).remove()
    elmText = cheerio(tmpElm).text()
    lines = elmText.split(/[\n\r]/)
    attachmentDefs = []
    tmpHTMLs = []
    for line in lines
      matched = r.exec(line)
      while matched?
        attachmentDef = matched[0].trim().replace(/“/g, "&#x201C;").replace(/”/g, "&#x201D;")
        altText = matched[1]
        src = matched[2]
        optTitle = matched[3]
        if src? # an attachment found!
          src = resolveAttachmentPath(src, filePath)
          utils ?= require './utils'
          iconResult = utils.iconLookUp(src)
          icon = iconResult.icon
          mimetype = iconResult.mimetype
          tmpHTML = "<div class=\"en-media attachments\" title=\"#{attachmentDef}\">"
          tmpHTML += "<span class=\"icon\ icon-#{icon}\"></span>"
          tmpHTML += "<embed src=\"#{src}\""
          if mimetype? then tmpHTML += " type=\"#{mimetype}\""
          title = if optTitle?.length > 0 then optTitle else path.basename(src)
          title = utils.stringEscape(title)
          if title? then tmpHTML += " title=\"#{title}\""
          tmpHTML += " /><span class=\"file-path\"><a href=\"#{src}\">#{src}</a></span></div>"
          attachmentDefs.push(attachmentDef)
          tmpHTMLs.push(tmpHTML)
        matched = r.exec(line)
    replacementOptions =
      replaceOnce: true
      lookBack: "title=\""
      negatedLookBack: true
    if tmpHTMLs.length > 0
      oldHTML = o.html(elm).toString().replace(/&quot;/g, "\"")
      for i in [0..attachmentDefs.length-1]
        attachmentDef = attachmentDefs[i]
        tmpHTML = tmpHTMLs[i]
        oldHTML = utils.literalReplace(oldHTML, attachmentDef, tmpHTML, replacementOptions)
      newHTML = oldHTML
      o(elm).replaceWith(newHTML)

  elmSelector = "html, body, p, ul, ol, li, span, strong, b, em, i, u, object, label, input, table, thead, tbody, th, tr, td, div, blockquote"
  for elm in o(elmSelector)
    parseAttachmentsInElement(elm)

  return o.html()

resolveAttachmentPath = (src, filePath) ->
  [rootDirectory] = atom.project.relativizePath(filePath)
  return src if src.match(/^(https?|atom):\/\//)
  return src if src.startsWith(process.resourcesPath)
  return src if src.startsWith(resourcePath)
  return src if src.startsWith(packagePath)

  if src[0] is '/'
    unless fs.isFileSync(src)
      if rootDirectory? and src.substring(1)?
        src = path.join(rootDirectory, src.substring(1))
  else  if filePath? and src?
    src = path.resolve(path.dirname(filePath), src)
  return src


resolveImagePaths = (html, filePath) ->
  [rootDirectory] = atom.project.relativizePath(filePath)
  o = cheerio.load(html)
  for imgElement in o('img')
    img = o(imgElement)
    if src = img.attr('src')
      continue if src.match(/^(https?|atom):\/\//)
      continue if src.startsWith(process.resourcesPath)
      continue if src.startsWith(resourcePath)
      continue if src.startsWith(packagePath)

      if src[0] is '/'
        unless fs.isFileSync(src)
          if rootDirectory? and src.substring(1)?
            img.attr('src', path.join(rootDirectory, src.substring(1)))
      else if filePath? and src?
        img.attr('src', path.resolve(path.dirname(filePath), src))

  o.html()

convertCodeBlocksToAtomEditors = (domFragment, defaultLanguage='text') ->
  if fontFamily = atom.config.get('editor.fontFamily')

    for codeElement in domFragment.querySelectorAll('code')
      codeElement.style.fontFamily = fontFamily

  for preElement in domFragment.querySelectorAll('pre')
    codeBlock = preElement.firstElementChild ? preElement
    fenceName = codeBlock.getAttribute('class')?.replace(/^lang-/, '') ? defaultLanguage

    editorElement = document.createElement('atom-text-editor')
    editorElement.setAttributeNode(document.createAttribute('gutter-hidden'))
    editorElement.removeAttribute('tabindex') # make read-only

    preElement.parentNode.insertBefore(editorElement, preElement)
    preElement.remove()

    editor = editorElement.getModel()
    # remove the default selection of a line in each editor
    editor.getDecorations(class: 'cursor-line', type: 'line')[0].destroy()
    editor.setText(codeBlock.textContent.trim())
    if grammar = atom.grammars.grammarForScopeName(scopeForFenceName(fenceName))
      editor.setGrammar(grammar)

  domFragment

tokenizeCodeBlocks = (html, defaultLanguage='text') ->
  o = cheerio.load(html)

  if fontFamily = atom.config.get('editor.fontFamily')
    o('code').css('font-family', fontFamily)

  for preElement in o("pre")
    codeBlock = o(preElement).children().first()
    fenceName = codeBlock.attr('class')?.replace(/^lang-/, '') ? defaultLanguage

    highlighter ?= new Highlights(registry: atom.grammars)
    highlightedHtml = highlighter.highlightSync
      fileContents: codeBlock.text()
      scopeName: scopeForFenceName(fenceName)

    highlightedBlock = o(highlightedHtml)
    # The `editor` class messes things up as `.editor` has absolutely positioned lines
    #highlightedBlock.removeClass('editor').addClass("atom-text-editor")
    highlightedBlock.removeClass('editor').addClass("lang-#{fenceName}").addClass('evnd-fenced-code-block')

    #
    # For EVND:
    # div.line doesn't display well in Evernote...
    #
    for divLine in highlightedBlock.children(".line")
      divLineHTML = o.html(divLine)
      spanLineHTML = divLineHTML.replace(/^\s*?<\s*?div\s/, '<span ')
      o(divLine).replaceWith(spanLineHTML)
    #for divLine in highlightedBlock.children(".line")
    #  for singleLine in o(divLine).children()
    #    highlightedBlock.append(singleLine)
    #    highlightedBlock.append('<br/>')
    #  o(divLine).remove()
    #highlightedBlock.remove(".line")
    highlightedBlock.addClass("fenced-code-block-#{fenceName}")
    highlightedBlock.attr("title", "fenced-code-block-#{fenceName}")

    o(preElement).replaceWith(highlightedBlock)

  o.html()

generateFootnotes = (html) ->
  o = cheerio.load(html)

  footnotesArr = []
  footnotes = {}
  fnReg = /^\s*?\[\^(.+?)\]\:/i
  footnotesParagraphs = {}
  for par in o('p')
    oparText = o(par).text().trim()
    if fnReg.test(oparText)
      footnoteID = fnReg.exec(oparText)[1]
      footnotesArr.push footnoteID
      footnotes[footnoteID] = o(par).html()
      footnotesParagraphs[footnoteID] = par

  footnoteRefsArr = []
  footnoteRefs = {}
  fnRefReg = /\[\^([^\[\]\n\r]+?)\](?!\:)/i
  footnoteCount = 0
  parseFootnoteInElement = (elm) =>
    if elm?.tagName in ["pre", "code", "head", "script"]
      return
    else if o(elm).children()?.length > 0
      for childElm in o(elm).children()
        parseFootnoteInElement(childElm)
        #return
    tmpElm = cheerio.parseHTML(o.html(elm))[0]
    for childElm in cheerio(tmpElm).children()
      cheerio(childElm).remove()
    #oElmText = o(elm).text().trim()
    oElmText = cheerio(tmpElm).text().trim()
    startIndex = 0
    while fnRefReg.test(oElmText.slice(startIndex, oElmText.length)) # This element contains footnote references!
      regResult = fnRefReg.exec(oElmText.slice(startIndex, oElmText.length))
      footnoteID = regResult[1]
      footnoteRefText = regResult[0]
      if footnoteID in footnotesArr
        unless footnoteID in footnoteRefsArr
          footnoteRefsArr.push footnoteID
          footnoteCount += 1
        footnoteRefs[footnoteID] = footnoteRefText
        #footnoteLink = "<sup><a href=\"#fn:#{footnoteID}\" id=\"fnref:#{footnoteID}\" name=\"fnref:#{footnoteID}\" class=\"footnote\">#{(footnotesArr.indexOf(footnoteID)+1).toString()}</a></sup>"
        footnoteLink = "<sup><a href=\"#fn:#{footnoteID}\" id=\"fnref:#{footnoteID}\" name=\"fnref:#{footnoteID}\" class=\"footnote\">#{footnoteCount.toString()}</a></sup>"
        oElmHTML = o.html(elm)
        utils ?= require './utils'
        oElmHTML = utils.literalReplace(oElmHTML, footnoteRefText, footnoteLink, {lookAhead:":", negatedLookAhead:true})
        o(elm).replaceWith(oElmHTML)
      startIndex += regResult.index + footnoteRefText.length
      if startIndex > oElmText.length then break

  elmSelector = "html, body, p, ul, ol, li, span, strong, b, em, i, u, object, label, input, table, thead, tbody, th, tr, td, div, h1, h2, h3, h4, h5, h6, blockquote"
  for elm in o(elmSelector)
    parseFootnoteInElement(elm)

  footnoteHTML = ""
  if footnotesArr.length > 0
    referencedFootnoteIDArr = []
    footnoteHTML += "<div class=\"footnotes\" title=\"footnotes\"><hr></hr><ol>"
    #for i in [0..footnotesArr.length-1]
    for i in [0..footnoteRefsArr.length-1]
      footnoteID = footnoteRefsArr[i]
      referencedFootnoteIDArr.push footnoteID
      #console.log footnoteID
      footnoteHTML += "<li id=\"fn:#{footnoteID}\">"
      footnoteHTML += footnotes[footnoteID].replace(fnReg, '').trim()
      footnoteHTML += "&nbsp;<a class=\"reversefootnote\" title=\"Return to article\" href=\"#fnref:#{footnoteID}\" name=\"fn:#{footnoteID}\">&#8617;</a></li>"
    for footnoteID in footnotesArr
      unless footnoteID in referencedFootnoteIDArr
        footnoteHTML += "<li id=\"fn:#{footnoteID}\">"
        footnoteHTML += footnotes[footnoteID].replace(fnReg, '').trim()
        footnoteHTML += "&nbsp;<a class=\"reversefootnote\" title=\"Return to article\" href=\"#fnref:#{footnoteID}\" name=\"fn:#{footnoteID}\">&#8617;</a></li>"
    footnoteHTML += "</ol></div>"

  for elm in o('code sup, pre sup, header sup, script sup')
    continue unless o(elm).find('a.footnote').length > 0
    footnoteID = o(o(elm).find('a.footnote')[0]).attr("href").replace(/#fn:/g, '')
    o(elm).replaceWith("[^#{footnoteID}]")

  for elm in o('sup a.footnote')
    footnoteID = o(elm).attr("href").replace(/#fn:/g, '')
    o(footnotesParagraphs[footnoteID]).remove()

  html = o.html() + footnoteHTML
  return html

generateTOC = (html, headerLevelLimit=6) ->
  o = cheerio.load(html)
  headerList = []
  for i in [1..headerLevelLimit]
    headerList.push("h#{i.toString()}")
  tocHTML = "<ul class=\"table-of-contents toc-level-1\" title=\"evnd-toc\">"
  lastHeaderLevel = 1
  allHeaders = []
  for header in o(':header')
    for i in [0..headerList.length]
      headerSelector = headerList[i]
      continue unless headerSelector?
      if o(header).is(headerSelector)
        tocItem = ""
        currentHeaderLevel = i+1
        if currentHeaderLevel > lastHeaderLevel
          for j in [0..(currentHeaderLevel-lastHeaderLevel-1)]
            tmpLevel = (lastHeaderLevel + j + 1).toString()
            tocItem += "<ul class=\"table-of-contents toc-level-#{tmpLevel}\">"
        else if currentHeaderLevel < lastHeaderLevel
          for j in [0..(lastHeaderLevel-currentHeaderLevel-1)]
            tocItem += "</ul>"
        utils ?= require './utils'
        hText = utils.htmlEncode(o(header).text())
        tmpHeader = o(o.html(header))
        o(tmpHeader).find('.hidden-script-mathjax').remove()
        hInnerHTML = o(tmpHeader).html()
        hLink = o(header).attr("id")
        if not hLink?
          hLink = utils.sanitizeID(hText)
        if /[\-0-9]/i.test(hLink.charAt(0)) # avoid caveat (e.g.: "#-1-blah" or "#3-1-something" is not a valid selector)
          hLink = 'm'+ hLink
        if hLink in allHeaders
          hLink = hLink + '-' + allHeaders.length.toString()
        hLink = hLink.replace(/-{2,}/g, '-')
        allHeaders.push(hLink)
        if hLink isnt o(header).attr("id")
          o(header).attr("id", hLink)
        o(header).prepend("<a name=\"toc:#{hLink}\"></a>")
        tocItem += "<li><span><a href=\"##{hLink}\" class=\"toc-jump-link\">#{hInnerHTML}</a><span></li>"
        lastHeaderLevel = currentHeaderLevel
        tocHTML += tocItem
  if lastHeaderLevel > 1
    for j in [0..(lastHeaderLevel-1)]
      tocHTML += "</ul>"
  for tocParagraph in o('p:contains("[TOC]")')
    if o(tocParagraph).text().trim() is "[TOC]"
      o(tocParagraph).replaceWith("<div class=\"evnd-toc-div\" title=\"evnd-toc-div\">#{tocHTML}</div>")
  for tocParagraph in o('p:contains("[toc]")')
    if o(tocParagraph).text().trim() is "[toc]"
      o(tocParagraph).replaceWith("<div title=\"evnd-toc-div\">#{tocHTML}</div>")

  return o.html()


convertCheckBoxes = (html) ->
  o = cheerio.load(html)
  parseCheckboxInElement = (elm) =>
    if elm?.tagName in ["pre", "code", "head", "script"]
      return
    else if o(elm).children()?.length > 0
      for childElm in o(elm).children()
        parseCheckboxInElement(childElm)
    elmText = o(elm).text()
    return unless elmText.indexOf("[ ]") > -1 or elmText.indexOf("[x]") > -1
    oldHTML = o.html(elm)
    checkboxHTML = "<input type=\"checkbox\" class=\"gfm-checkbox\"></input>"
    checkboxHTML1 = "<input type=\"checkbox\" class=\"gfm-checkbox\" checked=\"checked\"></input>"
    newHTML = oldHTML.replace(/\[\ \]/g, checkboxHTML).replace(/\[x\]/g, checkboxHTML1)
    o(elm).replaceWith(newHTML)

  elmSelector = "html, body, p, ul, ol, li, span, strong, b, em, i, u, object, label, input, table, thead, tbody, th, tr, td, div, h1, h2, h3, h4, h5, h6, blockquote"
  for elm in o(elmSelector)
    parseCheckboxInElement(elm)

  for elm in o('code > input, pre input, header input, script input')
    continue unless o(elm).attr("type") is "checkbox" and o(elm).attr("class") is "gfm-checkbox"
    if o.html(elm).indexOf('checked') > -1
      o(elm).replaceWith("[x]")
    else
      o(elm).replaceWith("[ ]")

  return o.html()

renderMeta = (metaInfo) ->
  tmpHTML = "<div class=\"note-meta-info\">"
  tmpHTML += "<div class=\"note-meta-info-content\">"
  tmpHTML += "<p class=\"note-info\">"
  if metaInfo.notebook?
    tmpHTML += "<span class=\"icon icon-book note-notebook\">#{metaInfo.notebook}</span>"
    tmpHTML += "<span style=\"margin: 8px 8px;\"></span>"
  if metaInfo.tags? then tmpHTML += "<span class=\"icon icon-tag\"></span>"
  for tag in metaInfo.tags
    tmpHTML += "<span class=\"badge note-tag\">#{tag}</span>"
    tmpHTML += "<span style=\"margin: 2px 2px;\"></span>"
  if metaInfo.title?
    tmpHTML += "</p><p class=\"text-info note-title\">"
    tmpHTML += "<span class=\"icon icon-pencil\">#{metaInfo.title}</span>"
  tmpHTML += "</p></div></div>"
  return tmpHTML

exports.inlineCss = ({html, css}={}) ->
  return unless html? and css?
  html.replace(/<div class=\"line\"><\/div>/g, '')
  #inliner ?= require('./inline-css')
  inliner ?= require('inline-css').inlineCssSync
  #console.log inliner
  options =
    extraCss: ''
    applyStyleTags: false
    removeStyleTags: true
    applyLinkTags: true
    removeLinkTags: true
    preserveMediaQueries: false
    applyWidthAttributes: true

  if css?
    try
      css = css.replace(/atom\:\/\//g, path.join(atom.getConfigDirPath(), 'dev/packages/'))
      tmpHTML = '<div class="ever-notedown-preview">' + html + '</div>'
      inlinedHTMP = inliner(tmpHTML, css, options)
      return inlinedHTMP
    catch e
      console.error(e)
      return html
