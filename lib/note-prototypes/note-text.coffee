fs =  require 'fs-plus'
utils = require './../utils'
path = require 'path'
cheerio = null # delayed require 'cheerio'
{Note} = require './note-base'

class TextNote extends Note
  constructor: (options={}) ->
    super(options)
    @format = "Text"
    @text = options.text ? "Hello World!"
    # unique identifying string
    @id = options.id ? "[Note ID: #{utils.stringMD5(@creationTime + @getContent())}]"
    @queryString = options.queryString ? @makeQueryString()
    console.log("Created a new Note entity!")

  getContent: () ->
    return @text

  absPath: () ->
    return path.join @path, @fnStem + ".markdown"


module.exports =
  TextNote: TextNote
