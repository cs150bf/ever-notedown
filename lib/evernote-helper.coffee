exec = require('child_process').exec
execSync = require('child_process').execSync
temp = null
fs = require 'fs-plus'
utils = require './utils'
osaScriptMaker = null
path = require('path')
storage = null # require './storage-manager'
_ = require 'underscore-plus'


unwrapString = (inputStr) ->
  outputStr = inputStr.replace(/\\/g, '\\\\')
  reg = /###@@@(.*?)@@@###/gi
  outputStr = outputStr.replace(reg, (match, p1) => return p1.replace(/\"/g, "\\\""))
  return outputStr

#
# TODO: Use "quoted form of" and save all those escaped escapes and wrap/unwrap strings
# TODO: Reuse code
#
class OSAScriptMaker
  @readFile: () ->
    cmd = ""
    cmd += "on readFile(unixPath)\n"
    cmd += "\tset targetFile to (open for access (POSIX file unixPath))\n"
    cmd += "\tset newcontent to (read targetFile as «class utf8»)\n"
    cmd += "\tclose access targetFile\n"
    cmd += "\treturn newcontent\n"
    cmd += "end readFile\n\n"
    return cmd

  @wrapString: () ->
    cmd = ""
    cmd += "on wrapString(inputStr)\n"
    cmd += "\tset outputStr to \"###@@@\" & inputStr & \"@@@###\"\n"
    cmd += "\treturn outputStr\n"
    cmd += "end wrapString\n\n"
    return cmd

  @createNote: (note) ->
    openNoteUponCreation = atom.config.get('ever-notedown.openNoteInEvernoteAuto')
    cmd = ""
    if note.enCreationDate isnt null
      cmd += @stringToDate() + "\n"
      cmd += "set y to \"#{note.enCreationDate.slice(0, 4)}\"\n"
      cmd += "set m to \"#{note.enCreationDate.slice(4, 6)}\"\n"
      cmd += "set d to \"#{note.enCreationDate.slice(6, 8)}\"\n"
      cmd += "set h to \"#{note.enCreationDate.slice(9, 11)}\"\n"
      cmd += "set mm to \"#{note.enCreationDate.slice(11, 13)}\"\n"
      cmd += "set ss to \"#{note.enCreationDate.slice(13, 15)}\"\n"
      cmd += "set date0 to stringToDate(y, m, d, h, mm, ss)\n\n"
    sourcePATH = path.join(note.path, note.fnStem) + '.enml'
    cmd += @readFile()
    cmd += "set newcontent to readFile(\"#{sourcePATH}\")\n"
    cmd += "set infostr to \"\"\n"
    cmd += "tell application \"Evernote\"\n"
    cmd += "\tset note1 to create note title \"#{note.title?.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"")}\" with enml "
    cmd += "newcontent"
    #
    # TODO: Need to wait for Evernote to sort out some create notebook bug
    #       Currently this will be problematic if the designated notebook doesn't
    #       already exist...
    #
    #if note.notebook?.name
    #  cmd += " notebook \"" + note.notebook.name.replace(/\"/g, "\\\"") + "\""
    if note.tags isnt null and note.tags.length > 0
      cmd += " tags {"
      for tag in note.tags
        if tag.trim().length is 0 then continue
        cmd += "\"" + tag.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"") + "\", "
      cmd = cmd.slice(0, cmd.length-2) + "} "
    if note.attachments?
      tmpCMD = " attachments {"
      validAttachments = 0
      for k, v of note.attachments
        aPath = v.path
        if aPath?
          tmpCMD += "\"" + aPath.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"") + "\", "
          validAttachments += 1
      if validAttachments > 0 then cmd += tmpCMD.slice(0, tmpCMD.length-2) + "}"
    if note.enCreationDate isnt null
      cmd += " created date0"
    cmd += "\n"
    if note.notebook?.name
      cmd += "\tif (notebook named \"#{note.notebook.name.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"")}\" exists) then\n"
      cmd += "\t\tmove note1 to notebook \"#{note.notebook.name.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"")}\"\n"
      cmd += "\telse\n"
      cmd += "\t\tset infostr to infostr & \"(notebook does not exist)\"\n"
      cmd += "\tend if\n"
    cmd += "\tset source URL of note1 to \"#{sourcePATH}\"\n"
    cmd += "\tset date1 to creation date of note1\n"
    if openNoteUponCreation
      cmd += "\tset window1 to open note window with note1\n"
      cmd += "\tset visible of window1 to false\n"
      cmd += "\tset visible of window1 to true\n"
    cmd += "end tell\n"
    if openNoteUponCreation
      cmd += "tell application \"System Events\" to tell process \"Evernote\"\n"
      cmd += "\tset frontmost to true\n"
      cmd += "end tell\n"
    cmd += @dateToString() + "\n"
    cmd += "set infostr to infostr & dateToString(date1)\n"
    cmd += "return infostr"
    return cmd


  @dateToString: () ->
    cmd = "\n"
    cmd += "on coerceTwoDigit(num)\n"
    cmd += "\tif num < 10\n"
    cmd += "\t\tset num to \"0\" & (num as string)\n"
    cmd += "\telse\n"
    cmd += "\t\tset num to (num as string)\n"
    cmd += "\tend if\n"
    cmd += "\treturn num\n"
    cmd += "end coerceTwoDigit\n\n"
    cmd += "on dateToString(aDate)\n"
    cmd += "\tif aDate is missing value then return aDate\n"
    cmd += "\tset y to year of aDate as string\n"
    cmd += "\tset m to coerceTwoDigit(month of aDate as integer)\n"
    cmd += "\tset d to coerceTwoDigit(day of aDate as integer)\n"
    cmd += "\tset h to coerceTwoDigit(hours of aDate as integer)\n"
    cmd += "\tset mm to coerceTwoDigit(minutes of aDate as integer)\n"
    cmd += "\tset ss to coerceTwoDigit(seconds of aDate as integer)\n"
    cmd += "\treturn y & m & d & \"T\" & h & mm & ss\n"
    cmd += "end dateToString\n"
    return cmd

  @stringToDate: () ->
    cmd = "\n"
    cmd += "on stringToDate(y, m, d, h, mm, ss)\n"
    cmd += "\tset newDate to date (m & \"/\" & d & \"/\" & y)\n"
    cmd += "\tset hours of newDate to h\n"
    cmd += "\tset minutes of newDate to mm\n"
    cmd += "\tset seconds of newDate to ss\n"
    cmd += "\treturn newDate\n"
    cmd += "end stringToDate\n"
    return cmd

  @findNote: (note) ->
    if note.queryString?.length > 0
      queryString = note.queryString
    else
      queryString = note.makeQueryString()
    cmd = "tell application \"Evernote\"\n"
    if note.noteLink?
      cmd += "\tset note1 to find note \"" + note.noteLink.replace(/\"/g, "\\\"") + "\"\n"
      cmd += "\tset matches to [note1]\n"
    else
      cmd += "\tset note1 to missing value\n"
    cmd += "\tif note1 is missing value then\n"
    cmd += "\t\tset matches to find notes \"" + queryString.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"") + "\"\n"
    cmd += "\tend if\n"
    cmd += "\tset countmatches to count of matches\n"
    cmd += "\tif countmatches is 1\n"
    cmd += "\t\tset note1 to item 1 of matches\n"
    cmd += "\t\tset notelink1 to note link of note1\n"
    cmd += '\t\treturn "{ \\\"found\\\": 1, \\\"notelink\\\": \\\"" & notelink1 & "\\\",'
    cmd += ' \\\"queryString\\\": \\\"" & \"' + queryString.replace(/\\/g, "\\\\").replace(/\"/g, "'") + '\" & "\\\"}"\n'
    cmd += "\telse\n"
    cmd += '\t\treturn "{ \\\"found\\\": " & countmatches & ", \\\"notelink\\\": \\\"\\\",'
    cmd += ' \\\"queryString\\\": \\\"" & \"' + queryString.replace(/\\/g, "\\\\").replace(/\"/g, "'") + '\" & "\\\"}"\n'
    cmd += "\tend if\n"
    cmd += "end tell\n"
    return cmd

  @searchNotes: ({queryString, noteLink}={}) ->
    cmd = @dateToString() + "\n\n"
    cmd += @wrapString() + "\n\n"
    cmd += "tell application \"Evernote\"\n"
    if noteLink?
      cmd += "\tset note1 to find note \"" + noteLink.replace(/\"/g, "\\\"") + "\"\n"
      cmd += "\tset matches to [note1]\n"
    else
      cmd += "\tset matches to find notes \"" + queryString.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\'/g, "\\\"") + "\"\n"
    cmd += "\tif matches is not {missing value} then\n"
    cmd += "\t\tset countmatches to count of matches\n"
    cmd += "\telse\n"
    cmd += "\t\tset countmatches to 0\n"
    cmd += "\tend if\n"
    cmd += "\tset infostr to \"{\"\n"
    cmd += "\tif countmatches is not 0 then repeat with note1 in matches\n"
    cmd += "\t\tif note1 is not missing value then\n"
    cmd += '\t\t\tset notelink1 to note link of note1\n'
    cmd += '\t\t\tset infostr to infostr & "\\"" & notelink1 & "\\": {"\n'
    cmd += '\t\t\tset infostr to infostr & "\\"noteLink\\": \\"" & notelink1 & "\\", "\n'
    cmd += '\t\t\tset title1 to title of note1\n'
    cmd += '\t\t\tset infostr to infostr & "\\"title\\": \\"" & my wrapString(title1) & "\\", "\n'
    cmd += '\t\t\tset notebook1 to notebook of note1\n'
    cmd += "\t\t\tif notebook1 is not missing value then\n"
    cmd += "\t\t\t\tset nbname to name of notebook1\n"
    cmd += "\t\t\t\tset nbtype to notebook1's notebook type\n"
    cmd += '\t\t\t\tset infostr to infostr & "\\"notebook\\": {"\n'
    cmd += '\t\t\t\tset infostr to infostr & "\\"name\\": "\n'
    cmd += '\t\t\t\tset infostr to infostr & "\\"" & my wrapString(nbname) & "\\", "\n'
    cmd += '\t\t\t\tset infostr to infostr & "\\"type\\": "\n'
    cmd += '\t\t\t\tset infostr to infostr & "\\"" & nbtype & "\\"}, "\n'
    cmd += "\t\t\tend if\n"
    cmd += '\t\t\tset tags1 to tags of note1\n'
    cmd += '\t\t\tset infostr to infostr & "\\"tags\\": ["\n'
    cmd += '\t\t\trepeat with tag1 in tags1\n'
    cmd += '\t\t\t\tset tagname to name of tag1\n'
    cmd += '\t\t\t\tset infostr to infostr & "\\"" & my wrapString(tagname) & "\\", " \n'
    cmd += '\t\t\tend repeat\n'
    cmd += '\t\t\tset infostr to infostr & "\\"DummyTag\\"], "\n'
    cmd += "\t\t\tset mdate1 to modification date of note1\n"
    cmd += "\t\t\tset mdate1 to my dateToString(mdate1)\n"
    cmd += '\t\t\tset infostr to infostr & "\\"enModificationDate\\": \\"" & mdate1 & "\\"}, "\n'
    cmd += "\t\tend if\n"
    cmd += "\tend repeat\n"
    cmd += '\tset infostr to infostr & "\\"found\\": " & countmatches & "}"\n'
    cmd += "\treturn infostr\n"
    cmd += "end tell\n"
    return cmd

  @openNote: (notelink, queryString) ->
    cmd = ""
    cmd += "tell application \"Evernote\"\n"
    cmd += "\tset infostring to missing value\n"
    if notelink?
      cmd += "\tset note1 to find note \"" + notelink.replace(/\"/g, "\\\"") + "\"\n"
    else
      cmd += "\tset pnotes to find notes \"" + queryString.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\'/g, "\\\"") + "\"\n"
      cmd += "\tset count1 to count of pnotes\n"
      cmd += "\tif count1 equals 1 then\n"
      cmd += "\t\tset note1 to item 1 of pnotes\n"
      cmd += "\telse\n"
      cmd += "\t\tset note1 to missing value\n"
      cmd += "\tend if\n"
    cmd += "\tif note1 is not missing value then\n"
    cmd += "\t\topen note window with note1\n"
    cmd += "\t\tset window1 to open note window with note1\n"
    cmd += "\t\tset visible of window1 to false\n"
    cmd += "\t\tset visible of window1 to true\n"
    cmd += "\tend if\n"
    cmd += "end tell\n"
    cmd += "tell application \"System Events\" to tell process \"Evernote\"\n"
    cmd += "\tset frontmost to true\n"
    cmd += "end tell\n"
    return cmd

  @retrieveNote: (notelink, queryString, destFile) ->
    cmd = "tell application \"Evernote\"\n"
    if notelink?
      cmd += "\tset note1 to find note \"" + notelink.replace(/\"/g, "\\\"") + "\"\n"
    else
      cmd += "\tset pnotes to find notes \"" + queryString.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\'/g, "\\\"") + "\"\n"
      cmd += "\tset count1 to count of pnotes\n"
      cmd += "\tif count1 equals 1 then\n"
      cmd += "\t\tset note1 to item 1 of pnotes\n"
      cmd += "\telse\n"
      cmd += "\t\tset note1 to missing value\n"
      cmd += "\tend if\n"
    cmd += "\tif note1 is not missing value then\n"
    cmd += "\t\texport [note1] to \"#{destFile + '.enex'}\" format ENEX\n"
    cmd += "\t\texport [note1] to \"#{destFile + '.html'}\" format HTML\n"
    cmd += "\tend if\n"
    cmd += "end tell\n"
    return cmd

  @getHTML: (notelink,queryString) ->
    cmd = "tell application \"Evernote\"\n"
    if notelink?
      cmd += "\tset note1 to find note \"" + notelink.replace(/\"/g, "\\\"") + "\"\n"
    else
      cmd += "\tset pnotes to find notes \"" + queryString.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\'/g, "\\\"") + "\"\n"
      cmd += "\tset count1 to count of pnotes\n"
      cmd += "\tif count1 equals 1 then\n"
      cmd += "\t\tset note1 to item 1 of pnotes\n"
      cmd += "\telse\n"
      cmd += "\t\tset note1 to missing value\n"
      cmd += "\tend if\n"
    cmd += "\tif note1 is not missing value then return HTML content of note1\n"
    cmd += "end tell\n"
    return cmd

  @getENML: (notelink, queryString) ->
    cmd = "tell application \"Evernote\"\n"
    if notelink?
      cmd += "\tset note1 to find note \"" + notelink.replace(/\"/g, "\\\"") + "\"\n"
    else
      cmd += "\tset pnotes to find notes \"" + queryString.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\'/g, "\\\"") + "\"\n"
      cmd += "\tset count1 to count of pnotes\n"
      cmd += "\tif count1 equals 1 then\n"
      cmd += "\t\tset note1 to item 1 of pnotes\n"
      cmd += "\telse\n"
      cmd += "\t\tset note1 to missing value\n"
      cmd += "\tend if\n"
    cmd += "\tif note1 is not missing value then return ENML content of note1\n"
    cmd += "end tell\n"
    return cmd

  @noteInfoToString: ->
    cmd = @wrapString() + "\n\n"
    paramList = "title, cdate, mdate, sdate, lat, lon, alti, tags, "
    paramList += "nbname, nbtype, nlink, rtime, rtimed, rorder"
    cmd += "on noteInfoToString(#{paramList})\n"
    cmd += '\tset infostr to "{"\n'
    cmd += '\tset infostr to infostr & "\\"title\\": \\"" & wrapString(title) & "\\", "\n'
    cmd += '\tset infostr to infostr & "\\"noteLink\\": \\"" & nlink & "\\", "\n'
    cmd += '\tset infostr to infostr & "\\"enCreationDate\\": \\"" & cdate & "\\", "\n'
    cmd += '\tset infostr to infostr & "\\"enModificationDate\\": \\"" & mdate & "\\", "\n'
    cmd += '\tset infostr to infostr & "\\"subjectDate\\": \\"" & sdate & "\\", "\n'
    cmd += '\tset infostr to infostr & "\\"latitude\\": \\"" & lat & "\\", "\n'
    cmd += '\tset infostr to infostr & "\\"longitude\\": \\"" & lon & "\\", "\n'
    cmd += '\tset infostr to infostr & "\\"altitude\\": \\"" & alti & "\\", "\n'
    cmd += '\tset infostr to infostr & "\\"reminderTime\\": \\"" & rtime & "\\", "\n'
    cmd += '\tset infostr to infostr & "\\"reminderDoneTime\\": \\"" & rtimed & "\\", "\n'
    cmd += '\tset infostr to infostr & "\\"reminderOrder\\": \\"" & rorder & "\\", "\n'
    cmd += '\tset infostr to infostr & "\\"tags\\": ["\n'
    cmd += '\trepeat with tag in tags\n'
    cmd += '\t\tset tagname to name of tag\n'
    cmd += '\t\tset infostr to infostr & "\\"" & wrapString(tagname) & "\\", " \n'
    cmd += '\tend repeat\n'
    cmd += '\tset infostr to infostr & "\\"DummyTag\\"]"\n'
    cmd += '\tset infostr to infostr & ", \\"notebook\\": {\\"name\\":\\"" & wrapString(nbname) & "\\", "\n'
    cmd += '\tset infostr to infostr & "\\"type\\":\\"" & nbtype & "\\"}"\n'
    cmd += '\tset infostr to infostr & "}"\n'
    cmd += '\treturn infostr\n'
    cmd += "end noteInfoToString\n\n"
    return cmd

  @getNoteInfo: (notelink, queryString) ->
    cmd = @dateToString() + "\n"
    cmd += @noteInfoToString() + "\n"
    cmd += "tell application \"Evernote\"\n"
    cmd += "\tset infostring to missing value\n"
    if notelink?
      cmd += "\tset note1 to find note \"" + notelink.replace(/\"/g, "\\\"") + "\"\n"
    else
      cmd += "\tset pnotes to find notes \"" + queryString.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\'/g, "\\\"") + "\"\n"
      cmd += "\tset count1 to count of pnotes\n"
      cmd += "\tif count1 equals 1 then\n"
      cmd += "\t\tset note1 to item 1 of pnotes\n"
      cmd += "\telse\n"
      cmd += "\t\tset note1 to missing value\n"
      cmd += "\tend if\n"
    cmd += "\tif note1 is not missing value then\n"
    cmd += "\t\tset title1 to title of note1\n"
    cmd += "\t\tset cdate1 to creation date of note1\n"
    cmd += "\t\tset mdate1 to modification date of note1\n"
    cmd += "\t\tset sdate1 to subject date of note1\n"
    cmd += "\t\tset latitude1 to latitude of note1\n"
    cmd += "\t\tset longitude1 to longitude of note1\n"
    cmd += "\t\tset altitude1 to altitude of note1\n"
    cmd += "\t\tset tags1 to tags of note1\n"
    cmd += "\t\tset notebook1 to notebook of note1\n"
    cmd += "\t\tif notebook1 is not missing value then\n"
    cmd += "\t\t\tset nbname to name of notebook1\n"
    cmd += "\t\t\tset nbtype to notebook1's notebook type\n"
    cmd += "\t\tend if\n"
    cmd += "\t\tset notelink1 to note link of note1\n"
    cmd += "\t\tset rtime1 to reminder time of note1\n"
    cmd += "\t\tset rtimedone1 to reminder done time of note1\n"
    cmd += "\t\tset rorder1 to reminder order of note1\n"
    cmd += "\t\tset infostring to \"to update\"\n"
    cmd += "\tend if\n"
    cmd += "end tell\n"
    cmd += "if infostring is missing value then\n"
    cmd += "\tset infostring to \"\"\n"
    cmd += "else\n"
    cmd += "\tset cdate1 to dateToString(cdate1)\n"
    cmd += "\tset mdate1 to dateToString(mdate1)\n"
    cmd += "\tset sdate1 to dateToString(sdate1)\n"
    cmd += "\tset rtime1 to dateToString(rtime1)\n"
    cmd += "\tset rtimedone1 to dateToString(rtimedone1)\n"
    cmd += "\tset rorder1 to dateToString(rorder1)\n"
    paramList = "title1, cdate1, mdate1, sdate1, latitude1, longitude1, altitude1, "
    paramList += "tags1, nbname, nbtype, notelink1, rtime1, rtimedone1, rorder1"
    cmd += "\tset infostring to noteInfoToString(#{paramList})\n"
    cmd += "end if\n"
    cmd += "return infostring\n"
    return cmd

  @getAttachmentsInfo: (notelink, queryString) ->
    cmd = "tell application \"Evernote\"\n"
    if notelink?
      cmd += "\tset note1 to find note \"" + notelink.replace(/\"/g, "\\\"") + "\"\n"
    else
      cmd += "\tset pnotes to find notes \"" + queryString.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\'/g, "\\\"") + "\"\n"
      cmd += "\tset count1 to count of pnotes\n"
      cmd += "\tif count1 equals 1 then\n"
      cmd += "\t\tset note1 to item 1 of pnotes\n"
      cmd += "\telse\n"
      cmd += "\t\tset note1 to missing value\n"
      cmd += "\tend if\n"
    cmd += "\tif note1 is missing value then\n"
    cmd += "\t\tset infostring to \"\"\n"
    cmd += "\telse\n"
    cmd += "\t\tset myattachments to every attachment of note1\n"
    cmd += '\t\tset infostring to "{\\""\n'
    cmd += '\t\trepeat with theattachment in myattachments\n'
    cmd += '\t\t\tset afilename to filename of theattachment\n'
    cmd += '\t\t\tif afilename is missing value then\n'
    cmd += '\t\t\t\tset afilename to hash of theattachment\n'
    cmd += '\t\t\tend if\n'
    cmd += '\t\t\tset hashvalue to hash of theattachment\n'
    cmd += '\t\t\tset infostring to infostring & hashvalue & "\\": {\\"hash\\": \\""\n'
    cmd += '\t\t\tset infostring to infostring & hashvalue & "\\", \\"filename\\": \\""\n'
    cmd += '\t\t\tset infostring to infostring & afilename & "\\", \\"mime\\": \\""\n'
    cmd += '\t\t\tset mimetype to mime of theattachment\n'
    cmd += '\t\t\tset infostring to infostring & mimetype & "\\", \\"size\\": "\n'
    cmd += '\t\t\tset filesize to size of theattachment\n'
    cmd += '\t\t\tset infostring to infostring & filesize & ", \\"sourceURL\\": \\""\n'
    cmd += '\t\t\tset sourceurl to source URL of theattachment\n'
    cmd += '\t\t\tset infostring to infostring & sourceurl & "\\", \\"longitude\\": \\""\n'
    cmd += '\t\t\tset elongitude to longitude of theattachment\n'
    cmd += '\t\t\tset infostring to infostring & elongitude & "\\", \\"latitude\\": \\""\n'
    cmd += '\t\t\tset elatitude to latitude of theattachment\n'
    cmd += '\t\t\tset infostring to infostring & elatitude & "\\", \\"altitude\\": \\""\n'
    cmd += '\t\t\tset ealtitude to altitude of theattachment\n'
    cmd += '\t\t\tset infostring to infostring & "\\"}, \\""\n'
    cmd += '\t\tend repeat\n'
    cmd += '\t\tset infostring to infostring & "endoflist\\":0}"\n'
    cmd += '\tend if\n'
    cmd += '\treturn infostring\n'
    cmd += 'end tell\n'
    return cmd

  @writeAttachments: (note, notelink, queryString, attachmentsToWrite) =>
    cmd = ""
    cmd += "tell application \"Evernote\"\n"
    if notelink?
      cmd += "\tset note1 to find note \"" + notelink.replace(/\"/g, "\\\"") + "\"\n"
    else
      cmd += "\tset pnotes to find notes \"" + queryString.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\'/g, "\\\"") + "\"\n"
      cmd += "\tset count1 to count of pnotes\n"
      cmd += "\tif count1 equals 1 then\n"
      cmd += "\t\tset note1 to item 1 of pnotes\n"
      cmd += "\telse\n"
      cmd += "\t\tset note1 to missing value\n"
      cmd += "\tend if\n"
    cmd += "\tif note1 is not missing value then\n"
    cmd += "\t\tset noteAttachments to every attachment of note1\n"
    cmd += "\t\tset hashlist to {  "
    for k, v of attachmentsToWrite
      cmd += "\"#{v.hash}\", "
    cmd = cmd.slice(0, cmd.length-2) + "}\n"
    cmd += "\t\tset hashrecord to {  "
    for k, v of attachmentsToWrite
      cmd += " {hash: \"#{v.hash}\", path:\"#{v.path}\"}, "
    cmd  = cmd.slice(0, cmd.length-2) + "}\n"
    cmd += "\t\trepeat with attachm in noteAttachments\n"
    cmd += "\t\t\tset hashvalue to hash of attachm\n"
    cmd += "\t\t\tif hashvalue is in hashlist then\n"
    cmd += "\t\t\t\trepeat with aRecord in hashrecord\n"
    cmd += "\t\t\t\t\tset hhash to hash of aRecord\n"
    cmd += "\t\t\t\t\tif hhash equals hashvalue then write attachm to (path of aRecord)\n"
    cmd += "\t\t\t\tend repeat\n"
    cmd += "\t\t\tend if\n"
    cmd += "\t\tend repeat\n"
    cmd += "\tend if\n"
    cmd += "end tell"
    return cmd


  #
  # TODO: Wait till Evernote sort out the bugs associated with creating new notebooks
  #       via AppleScript
  #
  @updateNote: (note, notelink, queryString, addAttachments) =>
    openNoteAfterwards = atom.config.get('ever-notedown.openNoteInEvernoteAuto')
    cmd = ""
    cmd += @readFile()
    sourcePATH = path.join(note.path, note.fnStem) + '.html'
    cmd += "set newcontent to readFile(\"#{sourcePATH}\")\n"
    cmd += "set infostr to \"\"\n"
    cmd += "tell application \"Evernote\"\n"
    if notelink?
      cmd += "\tset note1 to find note \"" + notelink.replace(/\"/g, "\\\"") + "\"\n"
    else
      cmd += "\tset pnotes to find notes \"" + queryString.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\'/g, "\\\"") + "\"\n"
      cmd += "\tset count1 to count of pnotes\n"
      cmd += "\tif count1 equals 1 then\n"
      cmd += "\t\tset note1 to item 1 of pnotes\n"
      cmd += "\telse\n"
      cmd += "\t\tset note1 to missing value\n"
      cmd += "\tend if\n"
    cmd += "\tif note1 is not missing value then\n"
    if note.notebook?.name?.trim().length > 0
      #cmd += "\t\tif (not (notebook named \"#{note.notebook.name.replace(/\"/g, "\\\"")}\" exists))then \n"
      # The Evernote AppleScript support for creating notebook is poor
      #cmd += "\t\t\tmake notebook with properties {name:\"#{note.notebook.name.replace(/\"/g, "\\\"")}\"}\n"
      #cmd += "\t\t\tcreate notebook \"#{note.notebook.name.replace(/\"/g, "\\\"")}\"\n"
      #cmd += "\t\t\treturn \"notebook does not exist\"\n"
      #cmd += "\t\tend if\n"
      #cmd += "\t\tmove note1 to notebook \"#{note.notebook.name.replace(/\"/g, "\\\"")}\"\n"
      cmd += "\t\tif (notebook named \"#{note.notebook.name.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"")}\" exists) then\n"
      cmd += "\t\t\tmove note1 to notebook \"#{note.notebook.name.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"")}\"\n"
      cmd += "\t\telse\n"
      cmd += "\t\t\tset infostr to infostr & \"(notebook does not exist)\"\n"
      cmd += "\t\tend if\n"
    cmd += "\t\tset title of note1 to \"#{note.title.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"")}\"\n"
    cmd += "\t\tset HTML content of note1 to newcontent\n"
    cmd += "\t\tset oldtags to tags of note1\n"
    cmd += "\t\tset count2 to count of oldtags\n"
    cmd += "\t\tif count2 is not 0 then\n"
    cmd += "\t\t\tunassign oldtags from note1\n"
    cmd += "\t\tend if\n"
    for newTag in note.tags
      if newTag.trim().length is 0 then continue
      cmd += "\t\tif (not (tag named \"#{newTag.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"")}\" exists)) then\n"
      cmd += "\t\t\tset tag1 to make tag with properties {name: \"#{newTag.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"")}\"}\n"
      cmd += "\t\telse\n"
      cmd += "\t\t\tset tag1 to tag \"#{newTag.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"")}\"\n"
      cmd += "\t\tend if\n"
      cmd += "\t\tassign tag1 to note1\n"
    if addAttachments
      for k, v of note.attachments
        if v.active and (not v.info?) and v.path? and fs.isFileSync(v.path)
          cmd += "\t\ttell note1 to append attachment \"#{v.path}\"\n"
    cmd += "\t\tset date1 to modification date of note1\n"
    if openNoteAfterwards
      cmd += "\t\tset window1 to open note window with note1\n"
      cmd += "\t\tset visible of window1 to false\n"
      cmd += "\t\tset visible of window1 to true\n"
    cmd += "\tend if\n"
    cmd += "end tell\n"
    if openNoteAfterwards
      cmd += "tell application \"System Events\" to tell process \"Evernote\"\n"
      cmd += "\tset frontmost to true\n"
      cmd += "end tell\n"
    cmd += @dateToString() + "\n"
    cmd += "if date1 is not missing value then\n"
    cmd += "\tset infostr to infostr & dateToString(date1)\n"
    cmd += "\treturn infostr\n"
    cmd += "else\n"
    cmd += "\treturn infostr\n"
    cmd += "end if\n"
    return cmd

  @setModificationDate: (note, notelink, queryString, newDateStr) ->
    cmd = ""
    cmd += @dateToString() + "\n"
    cmd += @stringToDate() + "\n"
    cmd += "set y to \"#{newDateStr.slice(0, 4)}\"\n"
    cmd += "set m to \"#{newDateStr.slice(4, 6)}\"\n"
    cmd += "set d to \"#{newDateStr.slice(6, 8)}\"\n"
    cmd += "set h to \"#{newDateStr.slice(9, 11)}\"\n"
    cmd += "set mm to \"#{newDateStr.slice(11, 13)}\"\n"
    cmd += "set ss to \"#{newDateStr.slice(13, 15)}\"\n"
    cmd += "set date0 to stringToDate(y, m, d, h, mm, ss)\n\n"
    cmd += "tell application \"Evernote\"\n"
    if notelink?
      cmd += "\tset note1 to find note \"" + notelink.replace(/\"/g, "\\\"") + "\"\n"
    else
      cmd += "\tset pnotes to find notes \"" + queryString.replace(/\\/g, "\\\\").replace(/\"/g, "\\\"").replace(/\'/g, "\\\"") + "\"\n"
      cmd += "\tset count1 to count of pnotes\n"
      cmd += "\tif count1 equals 1 then\n"
      cmd += "\t\tset note1 to item 1 of pnotes\n"
      cmd += "\telse\n"
      cmd += "\t\tset note1 to missing value\n"
      cmd += "\tend if\n"
    cmd += "\tif note1 is not missing value then\n"
    cmd += "\t\tset modification date of note1 to date0\n"
    cmd += "\t\tset date1 to modification date of note1\n"
    cmd += "\tend if\n"
    cmd += "end tell\n\n"
    cmd += "if date1 is not missing value then\n"
    cmd += "\treturn dateToString(date1)\n"
    cmd += "end if\n"
    return cmd



stdoutParse = (stdout) ->
  console.log("stdout: " + stdout)
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

exports.EvernoteHelper = class EvernoteHelper
  constructor: () ->
    return

  # AppleScript version
  createNewNote: (note, callback) ->
    cmd = OSAScriptMaker.createNote(note)
    temp ?= require('temp').track()
    tempFilePre = 'evernote-create-note-temp'
    tempFileSuf = '.AppleScript'
    info = temp.openSync({prefix: tempFilePre, suffix: tempFileSuf})
    fs.writeFileSync(info.path, cmd, 'utf8')
    window.evnd.storageManager.backUpScript('evernote-create-note.AppleScript', cmd)
    fullcmd = "osascript " + info.path
    exec fullcmd, (err, stdout, stderr) =>
      if err
        console.error(err)
        window.alert "Something happened and creating new note failed..."
        callback(false)
        return
      else
        console.log("stdout: " + stdout)
        console.log("stderr: " + stderr)
        stdoutTrimmed = stdout.trim()
        defaultQueryOptions = {id: false, notebook: true}
        if stdoutTrimmed.indexOf("(notebook does not exist)") > -1
          window.alert "Notebook #{note.notebook.name} does not exist! The note should be in default notebook"
          stdoutTrimmed = stdoutTrimmed.replace("(notebook does not exist)", "")
          defaultQueryOptions.notebook = false
        if stdoutTrimmed is ""
          window.alert "Something happened and creating new note failed..."
          callback(false)
          return
        note.enCreationDate = stdoutTrimmed
        note.queryString = note.makeQueryString(defaultQueryOptions)
        console.log("Evernote Note Creation time: " + stdoutTrimmed)
        utils.timeOut(200)
        @getNoteInfo note, {queryString: note.queryString, noteLink: null}, (newNoteInfo) =>
          #console.log newNoteInfo
          if not newNoteInfo?
            window.alert "Something went wrong when creating note..."
            callback(false)
            return
          note.update(window.evnd.storageManager, newNoteInfo)
          if note.attachments?
            @getAttachmentsInfo note, newNoteInfo.queryString, (newAttachmentsInfo) =>
              note.updateAttachmentsInfo(newAttachmentsInfo)
              note.tidy()
              window.evnd.storageManager.addNote note, false, null, () =>
                @updateNote note, false, false, (updateSuccess) =>
                  if updateSuccess
                    note.setSyncdContent()
                    note.queryString = note.makeQueryString()
                    window.evnd.storageManager.addNote(note)
                    callback(true)
                  else
                    window.alert "Something went wrong when updating note..."
                    callback(false)
          else
            note.setSyncdContent()
            window.evnd.storageManager.addNote(note)
            callback(true)

  pullNote: (note, callback) ->
    #console.log("########### pullNote!!! ###############")
    @findNote note, (queryString) =>
      #console.log("Callback after findNote..." + note.noteLink + "  " + queryString)
      notelink = note.noteLink
      return unless (notelink? or queryString?)
      @getNoteInfo note, {queryString: queryString}, (newNoteInfo) =>
        # if only tags are changed, enModificationDate doesn't change
        metaModified = note.checkMeta(newNoteInfo)
        if newNoteInfo.enModificationDate is note.lastSyncDate
          #console.log "This note's content hasn't changed since last syncd."
          #console.log note.parseMeta({lastSyncd: true}).content
          callback(metaModified, note.parseMeta({lastSyncd: true}).content, note.html, newNoteInfo)
          return
        else
          window.evnd.storageManager.addNote(note)
          enDest = path.join(note.path, note.fnStem) + "_evernote"
          @retrieveNote notelink, queryString, enDest, () =>
            utils.timeOut(200)
            if not ("#{enDest}.html/" in note.enExportedFiles)
              note.enExportedFiles.push("#{enDest}.html/")
            if not ("#{enDest}.enex" in note.enExportedFiles)
              note.enExportedFiles.push("#{enDest}.enex")
            @getENML note, newNoteInfo.queryString, (enml) =>
              if enml is note.enml
                #console.log "This note's ENML hasn't been updated."
                callback(metaModified, note.parseMeta().content, note.html, newNoteInfo)
              else
                console.log "Note content ENML changed!"
                # TODO: handle cases where the note format is "Text" or "HTML"
                @getAttachmentsInfo note, newNoteInfo.queryString, (newAttachmentsInfo) =>
                  note.updateAttachmentsInfo(newAttachmentsInfo)
                  @pullAttachments note, () =>
                    # Adding attachments
                    window.evnd.storageManager.addNote(note)
                    @getHTML note, newNoteInfo.queryString, (html) =>
                      #console.log html
                      unless html?
                        callback(false, null, null, newNoteInfo)
                        return
                      textContent = note.parseHTML(html)
                      window.evnd.storageManager.backUpScript('htmlToParse.html', html)
                      window.evnd.storageManager.backUpScript('parsedTextContent.markdown', textContent)
                      callback(true, textContent, html, newNoteInfo)


  getENML: (note, queryString, callback) ->
    #console.log("########### getENML!!! ###############")
    notelink = note.noteLink
    queryString ?= note.queryString
    getENMLWithLink = (notelink, queryString) =>
      return unless (notelink? or queryString?)
      cmd = OSAScriptMaker.getENML(notelink, queryString)
      temp ?= require('temp').track()
      tempFile1Pre = 'evernote-get-enml-temp'
      tempFile1Suf = '.AppleScript'
      tempFile2Pre = 'evernote-enml-temp'
      tempFile2Suf = '.enml'
      info1 = temp.openSync({prefix: tempFile1Pre, suffix:tempFile1Suf})
      info2 = temp.openSync({prefix: tempFile2Pre, suffix:tempFile2Suf})
      fs.writeFileSync(info1.path, cmd, 'utf8')
      window.evnd.storageManager.backUpScript('evernote-get-enml.AppleScript', cmd)
      fullcmd = "osascript " + info1.path + " > " + info2.path
      exec fullcmd, (err, stdout, stderr) =>
        if err
          console.error(err)
        else
          console.log(stdout)
          console.log(stderr)
          try
            enml = fs.readFileSync(info2.path, 'utf8')
            callback(enml)
          catch e
            console.error(e)
            callback(null)

    if notelink? or queryString?
      getENMLWithLink notelink, queryString
    else
      @findNote note, (queryString) =>
        notelink = note.noteLink
        getENMLWithLink notelink, queryString


  getHTML: (note, queryString, callback) ->
    #console.log("########### getHTML!!! ###############")
    notelink = note.noteLink
    queryString ?= note.queryString
    getHTMLWithLink = (notelink, queryString) =>
      return unless (notelink? or queryString?)
      cmd = OSAScriptMaker.getHTML(notelink, queryString)
      temp ?= require('temp').track()
      tempFile1Pre = 'evernote-get-html-temp'
      tempFile1Suf = '.AppleScript'
      tempFile2Pre = 'evernote-html-temp'
      tempFile2Suf = '.html'
      info1 = temp.openSync({prefix: tempFile1Pre, suffix:tempFile1Suf})
      info2 = temp.openSync({prefix: tempFile2Pre, suffix:tempFile2Suf})
      fs.writeFileSync(info1.path, cmd, 'utf8')
      fullcmd = "osascript " + info1.path + " > " + info2.path
      window.evnd.storageManager.backUpScript('evernote-get-html.AppleScript', cmd)
      exec fullcmd, (err, stdout, stderr) =>
        if err
          console.error(err)
        else
          console.log(stdout)
          console.log(stderr)
          try
            html = fs.readFileSync(info2.path, 'utf8')
            callback(html)
          catch e
            console.error(e)
            callback(null)

    if notelink? or queryString?
      getHTMLWithLink notelink, queryString
    else
      @findNote note, (queryString) =>
        notelink = note.noteLink
        getHTMLWithLink notelink, queryString


  pullAttachments: (note, callback) ->
    return unless note?.noteLink? or note?.queryString?
    attachmentsToWrite = {}
    for k, v of note.attachments
      if v.active and v.info?.hash? and
          ((not v.path?) or (v.md5 isnt v.info.hash) or (not fs.isFileSync(v.path)))
        filename = k
        if utils.isImage(k) or v.info?.mime?.indexOf('image') > -1
          filename = k + utils.defaultExtension(v.info.mime) unless k.indexOf('.') > -1
          filePath = path.join(note.path, 'img/', filename)
        else
          if k.indexOf('.') <= -1
            ext = utils.defaultExtension(v.info?.mime)
            if ext? then filename = k + ext
          filePath = path.join(note.path, 'attachments/', filename)
        if fs.isFileSync(filePath)
          filePath = utils.renameFile(filePath)
        attachmentsToWrite[k] =
          hash: v.info.hash
          path: filePath
    if _.size(attachmentsToWrite) is 0
      callback()
      return
    notelink = note.noteLink
    queryString = note.queryString
    cmd = OSAScriptMaker.writeAttachments(note, notelink, queryString, attachmentsToWrite)
    temp ?= require('temp').track()
    tempFilePre = 'evernote-write-attachments-temp'
    tempFileSuf = '.AppleScript'
    info = temp.openSync({prefix: tempFilePre, suffix: tempFileSuf})
    fs.writeFileSync(info.path, cmd, 'utf8')
    window.evnd.storageManager.backUpScript('evernote-pull-attachments.AppleScript', cmd)
    fullcmd = "osascript " + info.path
    exec fullcmd, (err, stdout, stderr) =>
      if err
        console.error(err)
      else
        console.log(stdout)
        console.log(stderr)
        for k, v of attachmentsToWrite
          if fs.isFileSync(v.path) then note.attachments[k].path = v.path
        callback()


  getAttachmentsInfo: (note, queryString, callback) ->
    #console.log("########### getAttachmentsInfo!!! ###############")
    notelink = note.noteLink
    queryString ?= note.queryString
    getAttachmentsInfoWithLink = (notelink, queryString) =>
      return unless (notelink? or queryString?)
      cmd = OSAScriptMaker.getAttachmentsInfo(notelink, queryString)
      temp ?= require('temp').track()
      tempFile1Pre = 'evernote-get-attachments-info-temp'
      tempFile1Suf = '.AppleScript'
      tempFile2Pre = 'evernote-attachments-info-temp'
      tempFile2Suf = '.json'
      info1 = temp.openSync({prefix: tempFile1Pre, suffix:tempFile1Suf})
      info2 = temp.openSync({prefix: tempFile2Pre, suffix:tempFile2Suf})
      fs.writeFileSync(info1.path, cmd, 'utf8')
      window.evnd.storageManager.backUpScript('evernote-get-attachments-info.AppleScript', cmd)
      fullcmd = "osascript " + info1.path + " > " + info2.path
      exec fullcmd, (err, stdout, stderr) =>
        if err
          console.error(err)
        else
          console.log(stdout)
          console.log(stderr)
          #console.log("Attachment info retrieved!")
          try
            resultFile = unwrapString(fs.readFileSync(info2.path, 'utf8'))
            unless resultFile?.trim()?.length > 0
              callback(null)
              return
            result = JSON.parse(resultFile) ? {}
            if result?.endoflist? then delete result["endoflist"]
            #console.log("Attachment info: " + JSON.stringify(result))
            callback(result)
          catch e
            console.error(e)
            callback(null)

    if (notelink? or queryString?)
      getAttachmentsInfoWithLink notelink, queryString
    else
      @findNote note, (queryString) =>
        notelink = note.noteLink
        getAttachmentsInfoWithLink notelink, queryString


  updateNote: (note, addAttachments, toRetrieve, callback) ->
    #console.log("########### updateNote!!! ###############")
    addAttachments ?= false
    toRetrieve ?= false
    @findNote note, (queryString) =>
      #console.log("Callback after findNote..." + note.noteLink + "  " + queryString)
      notelink = note.noteLink
      return unless (notelink? or queryString?)
      if toRetrieve
        enDest = path.join(note.path, note.fnStem) + "_evernote"
        @retrieveNote notelink, queryString, enDest, () =>
          utils.timeOut(200)
          if not ("#{enDest}.html/" in note.enExportedFiles)
            note.enExportedFiles.push("#{enDest}.html/")
          if not ("#{enDest}.enex" in note.enExportedFiles)
            note.enExportedFiles.push("#{enDest}.enex")
          cmd = OSAScriptMaker.updateNote(note, notelink, queryString, addAttachments)
          temp ?= require('temp').track()
          tempFilePre = 'evernote-update-note-temp'
          tempFileSuf = '.AppleScript'
          info = temp.openSync({prefix: tempFilePre, suffix:tempFileSuf})
          fs.writeFileSync(info.path, cmd, 'utf8')
          window.evnd.storageManager.backUpScript('evernote-update-note.AppleScript', cmd)
          fullcmd = "osascript " + info.path
          exec fullcmd, (err, stdout, stderr) =>
            if err
              console.error(err)
            else
              console.log(stdout)
              console.log(stderr)
              if stdout.trim() is "(notebook does not exist)"
                window.alert("Notebook #{note.notebook.name} does not exist! And update failed...")
                callback(false)
                return
              else if stdout.trim() is ""
                window.alert "Something went wrong, update failed..."
                callback(false)
                return
              if stdout.trim().indexOf("(notebook does not exist)") > -1
                window.alert "Notebook #{note.notebook.name} does not exist!"
                note.enModificationDate = stdout.trim().replace("(notebook does not exist)", "")
              else
                note.enModificationDate = stdout.trim()
              if addAttachments
                @getAttachmentsInfo note, queryString, (newAttachmentsInfo) =>
                  note.updateAttachmentsInfo(newAttachmentsInfo)
                  note.tidy()
                  console.log("Tidied up HTML again...")
                  window.evnd.storageManager.addNote note, false, null, () =>
                    @updateNote note, false, false, (updateSuccess) =>
                      if updateSuccess
                        note.setSyncdContent()
                        window.evnd.storageManager.addNote(note)
                        callback(true)
                      else
                        window.alert "Something went wrong when updating note..."
                        callback(false)
              else
                note.setSyncdContent()
                window.evnd.storageManager.addNote(note)
                callback(true)
      else
        cmd = OSAScriptMaker.updateNote(note, notelink, queryString, addAttachments)
        temp ?= require('temp').track()
        tempFilePre = 'evernote-update-note-temp'
        tempFileSuf = '.AppleScript'
        info = temp.openSync({prefix: tempFilePre, suffix:tempFileSuf})
        fs.writeFileSync(info.path, cmd, 'utf8')
        window.evnd.storageManager.backUpScript('evernote-update-note.AppleScript', cmd)
        fullcmd = "osascript " + info.path
        exec fullcmd, (err, stdout, stderr) =>
          if err
            console.error(err)
          else
            console.log(stdout)
            console.log(stderr)
            if stdout.trim() is "(notebook does not exist)"
              window.alert("Notebook #{note.notebook.name} does not exist! And update failed...")
              callback(false)
              return
            else if stdout.trim() is ""
              window.alert "Something went wrong, update failed..."
              callback(false)
              return
            if stdout.trim().indexOf("(notebook does not exist)") > -1
              window.alert "Notebook #{note.notebook.name} does not exist!"
              note.enModificationDate = stdout.trim().replace("(notebook does not exist)", "")
            else
              note.enModificationDate = stdout.trim()
            if addAttachments
              @getAttachmentsInfo note, queryString, (newAttachmentsInfo) =>
                note.updateAttachmentsInfo(newAttachmentsInfo)
                note.tidy()
                window.evnd.storageManager.addNote note, false, null, () =>
                  @updateNote note, false, false, (updateSuccess) =>
                    if updateSuccess
                      note.setSyncdContent()
                      window.evnd.storageManager.addNote(note)
                      callback(true)
                    else
                      window.alert "Something went wrong when updating..."
                      callback(false)
            else
              note.setSyncdContent()
              window.evnd.storageManager.addNote(note)
              callback(true)

  searchNotes: ({queryString, noteLink}={}, callback) ->
    #console.log("TODO")
    cmd = OSAScriptMaker.searchNotes({queryString:queryString, noteLink:noteLink})
    temp ?= require('temp').track()
    tempFile1Pre = 'evernote-search-notes-temp'
    tempFile1Suf = '.AppleScript'
    tempFile2Pre = 'evernote-found-notes-temp'
    tempFile2Suf = '.txt'
    # write cmd to file
    info1 = temp.openSync({prefix: tempFile1Pre, suffix:tempFile1Suf})
    info2 = temp.openSync({prefix: tempFile2Pre, suffix:tempFile2Suf})
    fs.writeFileSync(info1.path, cmd, 'utf8')
    window.evnd.storageManager.backUpScript('evernote-search-notes.AppleScript', cmd)
    fullcmd =  "osascript " + info1.path + " > " + info2.path
    exec fullcmd, (err, stdout, stderr) =>
      if err
        console.error(err)
      else
        console.log(stdout)
        console.log(stderr)
        try
          resultFile = unwrapString(fs.readFileSync(info2.path, 'utf8'))
          unless resultFile?.trim()?.length > 0
            callback(null)
            return
          result = JSON.parse(resultFile) ? {}
          #console.log("Parsed result: " + JSON.stringify(result, null, 4))
          newNoteInfo = {}
          for k, v of result
            if k is "found"
              newNoteInfo[k] = v
            else
              newNoteInfo[k] = {}
              for k1, v1 of v
                if k1 is "tags" and v1 isnt "missing value" then v1.splice(v1.indexOf("DummyTag"), 1)
                if v1 isnt "missing value" then newNoteInfo[k][k1] = v1
          callback(newNoteInfo)
        catch e
          console.error(e)
          callback(null)

  findNote: (note, callback) ->
    #console.log("TODO")
    cmd = OSAScriptMaker.findNote(note)
    temp ?= require('temp').track()
    tempFile1Pre = 'evernote-find-note-temp'
    tempFile1Suf = '.AppleScript'
    tempFile2Pre = 'evernote-found-note-temp'
    tempFile2Suf = '.txt'
    # write cmd to file
    info1 = temp.openSync({prefix: tempFile1Pre, suffix:tempFile1Suf})
    info2 = temp.openSync({prefix: tempFile2Pre, suffix:tempFile2Suf})
    fs.writeFileSync(info1.path, cmd, 'utf8')
    window.evnd.storageManager.backUpScript('evernote-find-note.AppleScript', cmd)
    fullcmd =  "osascript " + info1.path + " > " + info2.path
    exec fullcmd, (err, stdout, stderr) =>
      if err
        console.error(err)
      else
        console.log(stdout)
        console.log(stderr)
        try
          resultFile = unwrapString(fs.readFileSync(info2.path, 'utf8'))
          unless resultFile?.trim()?.length > 0
            console.log "No matching note can be found..."
            callback(null)
            return
          result = JSON.parse(resultFile) ? {}
          #console.log("Parsed result: " + JSON.stringify(result, null, 4))
          if result.found is 1
            if result.notelink isnt "missing value" then note.noteLink = result.notelink
            queryString = result.queryString
            if result.queryString isnt "missing value" then note.queryString = queryString
            #console.log("Note link: " + result.notelink)
            callback(queryString)
          else
            console.log("No matching note can be found..." + JSON.stringify(result))
            callback(null)
        catch e
          console.error(e)
          callback(null)

  # Get a note from Evernote Client
  retrieveNote: (notelink, queryString, destFile, callback) ->
    cmd = OSAScriptMaker.retrieveNote(notelink, queryString, destFile)
    temp ?= require('temp').track()
    tempFilePre = 'evernote-retrive-note-temp'
    tempFileSuf = '.AppleScript'
    info = temp.openSync({prefix: tempFilePre, suffix: tempFileSuf})
    fs.writeFileSync(info.path, cmd, 'utf8')
    window.evnd.storageManager.backUpScript('evernote-retrieve-note.AppleScript', cmd)
    fullcmd = "osascript " + info.path
    exec fullcmd, (err, stdout, stderr) =>
      if err
        console.error(err)
      else
        console.log(stdout)
        console.log(stderr)
        callback()

  getNoteInfo: (note, {queryString, noteLink}={}, callback) ->
    noteLink ?= note?.noteLink
    queryString ?= note?.queryString
    getNoteInfoWithLink = (noteLink, queryString) =>
      return unless noteLink? or queryString?
      cmd = OSAScriptMaker.getNoteInfo(noteLink, queryString)
      temp ?= require('temp').track()
      tempFile1Pre = 'evernote-get-note-info-temp'
      tempFile1Suf = '.AppleScript'
      tempFile2Pre = 'evernote-note-info-temp'
      tempFile2Suf = '.json'
      # write cmd to file
      info1 = temp.openSync({prefix: tempFile1Pre, suffix:tempFile1Suf})
      info2 = temp.openSync({prefix: tempFile2Pre, suffix:tempFile2Suf})
      fs.writeFileSync(info1.path, cmd, 'utf8')
      window.evnd.storageManager.backUpScript('evernote-get-note-info.AppleScript', cmd)
      fullcmd =  "osascript " + info1.path + " > " + info2.path
      exec fullcmd, (err, stdout, stderr) =>
        if err
          console.error(err)
        else
          console.log(stdout)
          console.log(stderr)
          try
            resultFile = unwrapString(fs.readFileSync(info2.path, 'utf8'))
            unless resultFile?.trim()?.length > 0
              callback(null)
              return
            result = JSON.parse(resultFile) ? {}
            #console.log("Note info: " + JSON.stringify(result))
            newNoteInfo = {}
            for k, v of result
              if k is "tags" and v isnt "missing value" then v.splice(v.indexOf("DummyTag"), 1)
              if v isnt "missing value" then newNoteInfo[k] = v
            if noteLink? then newNoteInfo.noteLink = noteLink
            if queryString? then newNoteInfo.queryString = queryString
            callback(newNoteInfo)
          catch e
            console.error(e)
            callback(null)

    if noteLink? or queryString?
      getNoteInfoWithLink noteLink, queryString
    else if note?
      @findNote note, (queryString) =>
        noteLink = note.noteLink
        getNoteInfoWithLink noteLink, queryString

  openFinder: (notePath, callback) ->
    cmd = "tell application \"Finder\" to open (\"#{notePath}\" as POSIX file)\n"
    cmd += "tell application \"System Events\" to tell process \"Finder\"\n"
    cmd += "\tset frontmost to true\n"
    cmd += "end tell\n"
    temp ?= require('temp').track()
    tempFilePre = 'evernote-open-finder-temp'
    tempFileSuf = '.AppleScript'
    info = temp.openSync({prefix: tempFilePre, suffix: tempFileSuf})
    fs.writeFileSync(info.path, cmd, 'utf8')
    window.evnd.storageManager.backUpScript('evernote-open-finder.AppleScript', cmd)
    fullcmd = "osascript " + info.path
    exec fullcmd, (err, stdout, stderr) =>
      if err
        console.error(err)
      else
        console.log(stdout)
        console.log(stderr)
        if callback? then callback()

  openNote: (note, callback) ->
    @findNote note, (queryString) =>
      notelink = note.noteLink
      return unless (notelink? or queryString?)
      cmd = OSAScriptMaker.openNote(notelink, queryString)
      temp ?= require('temp').track()
      tempFilePre = 'evernote-open-note-temp'
      tempFileSuf = '.AppleScript'
      info = temp.openSync({prefix: tempFilePre, suffix: tempFileSuf})
      fs.writeFileSync(info.path, cmd, 'utf8')
      window.evnd.storageManager.backUpScript('evernote-open-note.AppleScript', cmd)
      fullcmd = "osascript " + info.path
      exec fullcmd, (err, stdout, stderr) =>
        if err
          console.error(err)
        else
          console.log(stdout)
          console.log(stderr)
          if callback? then callback()

  setModificationDate: (note, newDateStr, callback) ->
    return unless note.noteLink? or note.queryString?
    notelink = note.noteLink
    queryString = note.queryString
    cmd = OSAScriptMaker.setModificationDate(note, notelink, queryString, newDateStr)
    temp ?= require('temp').track()
    tempFilePre = 'evernote-set-modification-date-temp'
    tempFileSuf = '.AppleScript'
    info = temp.openSync({prefix: tempFilePre, suffix: tempFileSuf})
    fs.writeFileSync(info.path, cmd, 'utf8')
    window.evnd.storageManager.backUpScript('evernote-set-modification-date.AppleScript', cmd)
    fullcmd = "osascript " + info.path
    exec fullcmd, (err, stdout, stderr) =>
      if err
        console.error(err)
      else
        console.log(stdout)
        console.log(stderr)
        note.enModificationDate = stdout.trim()
        callback()
