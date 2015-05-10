fs =  require 'fs-plus'
utils = require './../utils'
path = require 'path'
cheerio = null # delayed require 'cheerio'
{RichNote} = require './note-rich'

class HTMLNote extends RichNote
  constructor: (options={}) ->
    super(options)
    @format = "HTML"
    reconstruct = options.reconstruct ? false
    if reconstruct
      defaultRawHTML = fs.readFileSync(path.join(@path, "#{@fnStem}_plain.html"), 'utf8')
      defaultHTML = fs.readFileSync(path.join(@path, "#{@fnStem}.html"), 'utf8')
      defaultENML = fs.readFileSync(path.join(@path, "#{@fnStem}.enml"), 'utf8')
      defaultCSS = fs.readFileSync(path.join(@path, "style.css"), 'utf8')
    else
      defaultRawHTML = "<p>Hello World!</p>"
      defaultHTML = "<p>Hello World!</p>"
      defaultENML = "<p>Hello World!</p>"
      defaultCSS = null
    @html = options.html ? defaultHTML
    @rawHTML = options.rawHTML ? defaultRawHTML
    @css = options.css ? defaultCSS
    @enml = options.enml ? defaultENML
    # unique identifying string
    @id = options.id ? "[Note ID: #{utils.stringMD5(@creationTime + @getContent())}]"
    @tidy()
    @header = options.header ? @htmlHeader()
    @queryString = options.queryString ? @makeQueryString()
    console.log("Created a new Note entity!")

  getContent: () ->
    return @html

  absPath: () ->
    return path.join @path, @fnStem + ".html"

  parseHTML: (html) ->
    return html

module.exports =
  HTMLNote: HTMLNote
