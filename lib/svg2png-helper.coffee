path = null
fs = null
utils = null

module.exports =
  #
  # For Ever-Notedown, convert SVG elements to PNG files
  #
  svg2png: (domFragment, filePath) ->
    path ?= require 'path'
    fs ?= require 'fs-plus'
    utils ?= require './utils'

    unless window.evnd?.svgCollections?
      window.evnd.svgCollections = {}
    gitPath = atom.config.get('ever-notedown.gitPath')
    if filePath?.indexOf(gitPath) > -1
      imgFilePath = path.join(path.dirname(filePath), 'img/')
    else
      imgFilePath = path.join(gitPath, 'tmp/Math/')
    collectionID = utils.stringMD5(imgFilePath)
    svgCollection = window.evnd?.svgCollections?[collectionID] ? {}
    for k, v of svgCollection
      # remove inactive files
      if not v.active
        if v["svgPath"]?
          fs.removeSync(v["svgPath"])
        if v["pngPath"]?
          fs.removeSync(v["pngPath"])
        delete svgCollection[k]
      # initialization: assume all files are inactive
      v.active = false

    svgElements = domFragment.querySelectorAll('svg')
    return unless svgElements.length > 0
    svgDefs = document.querySelectorAll("#MathJax_SVG_glyphs")
    svgDefsInnerHTML = svgDefs[0].parentNode.innerHTML
    svgDefElement = document.createElement('div')
    svgDefElement.setAttribute("style", "display:none")
    svgDefElement.setAttribute("class", "svgDefinitions")
    svgDefElement.setAttribute("title", "svgDefinitions")
    svgDefElement.innerHTML = "<p>#{btoa(svgDefsInnerHTML)}</p>"
    domFragment.appendChild(svgDefElement)
    i = 0
    images = {}
    canvasArr = {}
    contextArr = {}
    for i in [0..svgElements.length]
      svgElement = svgElements[i]
      continue unless svgElement?.innerHTML?
      elementID = 'svg' + utils.stringMD5(svgElement.innerHTML)

      if svgCollection? and svgCollection[elementID]?
        svgCollection[elementID].active = true
        if svgCollection[elementID].svgPath? and svgCollection[elementID].pngPath?
          svgElement.setAttribute("id", elementID)
          continue # This element hasn't changed!
      else
        svgCollection[elementID] =
          active: true
          svgPath: null
          pngPath: null

      # extract SVG element and save as individual *.svg files
      svgElement.setAttribute("id", elementID)
      svgStyle = svgElement.getAttribute("style")
      svgElement.setAttribute("preserveAspectRatio", "none")
      fileName = path.join(imgFilePath, "#{elementID}.svg")
      tmpSVGElement = svgElement.cloneNode(true)
      svgWidth = tmpSVGElement.getAttribute("width")
      svgHeight = tmpSVGElement.getAttribute("height")
      extractOptions = {reStyle: false}
      if svgWidth? or svgHeight?
        extractOptions.reStyle = true
        if svgWidth? then extractOptions.width = svgWidth
        if svgHeight? then extractOptions.height = svgHeight
      svgHTML = utils.extractSVG(tmpSVGElement, svgDefsInnerHTML, extractOptions)
      fs.writeFileSync(fileName, svgHTML, 'utf8')
      svgCollection[elementID]["svgPath"] = fileName

      # SVG->PNG via canvas
      image = new Image
      image.name = elementID
      canvasArr[elementID] = document.createElement("canvas")
      if svgWidth?
        canvasArr[elementID].width = Math.round(5 * utils.toPixel(svgWidth, 'ex'))
      else
        canvasArr[elementID].width = Math.round(5 * utils.toPixel(utils.parseAttribute(svgStyle, "width"), 'ex'))
      if svgHeight
        canvasArr[elementID].height = Math.round(5 * utils.toPixel(svgHeight, 'ex'))
      else
        canvasArr[elementID].height = Math.round(5 * utils.toPixel(utils.parseAttribute(svgStyle, "height"), 'ex'))
      contextArr[elementID] = canvasArr[elementID].getContext("2d")
      images[elementID] = image
      images[elementID].onload = ->
        elementID = this.name
        contextArr[elementID].drawImage this, 0, 0,
          canvasArr[elementID].width, canvasArr[elementID].height
        canvasData = canvasArr[elementID].toDataURL("image/png")
        if canvasData? and canvasData.indexOf('data:image/png;base64,') > -1
          try
            pngData = utils.literalReplace(canvasData, 'data:image/png;base64,', '')
            pngFileName = path.join(imgFilePath, this.name + '.png')
            fs.writeFileSync(pngFileName, atob(pngData), 'binary')
          catch e
            console.error e
        svgCollection[elementID]["pngPath"] = pngFileName
      image.src = 'data:image/svg+xml;base64,'+ btoa(svgHTML)

    # Again, clean up inactive files
    for k, v of svgCollection
      # remove inactive files
      if not v.active
        if v["svgPath"]?
          fs.removeSync(v["svgPath"])
        if v["pngPath"]?
          fs.removeSync(v["pngPath"])
        delete svgCollection[k]

    window.evnd.svgCollections[collectionID] = svgCollection


