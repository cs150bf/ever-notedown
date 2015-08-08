fs = require 'fs-plus'
git = require 'git-utils'
exec = require('child_process').exec
utils = require './utils'
path = require 'path'
temp = null # delayed require 'temp'
{File, Directory} = require 'pathwatcher'

exports.StorageManager = class StorageManager
  constructor: ({gitPath, gitPathSymlink, gitRepo, gitDir}={}) ->
    @evNotedown = window.evnd
    @gitPath = gitPath
    @gitPathSymlink = gitPathSymlink
    @gitDir = gitDir
    if (gitRepo? and gitRepo isnt null)
      @gitRepo = gitRepo
    else
      @gitRepo = null
      @initRepo()

  @gitInitAsync: (gitDir, callback) ->
    gitPath = gitDir.getRealPathSync()
    exec 'git init "' + gitPath.replace(/\"/g, '\\"') + '"', (error, stdout, stderr) ->
      console.log('stdout: ' + stdout)
      console.log('stderr: ' + stderr)
      if error
        console.log('exec error: ' + error)
      else
        gitDir = new Directory(gitPath, false) unless gitDir.existsSync()
        atom.project.repositoryForDirectory(gitDir, false).then (gitRepo) =>
          #console.log(gitRepo)
          callback(gitRepo)

  @commitMessageParse: (commitMsg) ->
    lines = commitMsg.toString().split(/[\n\r]/)
    firstLine = utils.wrapLine(lines[0], 50)
    firstLineBreak = firstLine.indexOf('\n')
    if firstLineBreak > -1
      parsedCommitMsg = firstLine.slice(0, firstLineBreak) + "\n\n"
      parsedCommitMsg += firstLine.slice(firstLineBreak, firstLine.length) + "\n\n\n"
    else
      parsedCommitMsg = firstLine + "\n\n"
    for i in [1..lines.length]
      parsedCommitMsg += utils.wrapLine(lines[i], 72) + "\n"
    return parsedCommitMsg

  @gitCommitAsync: (gitPath, commitMsg, callback) ->
    if commitMsg? and commitMsg isnt null
      parsedCommitMsg = StorageManager.commitMessageParse(commitMsg)
    else
      parsedCommitMsg = commitMsg
    temp ?= require('temp').track()
    tempFilePre = 'git-commit-message-temp'
    tempFileSuf = '.txt'
    info = temp.openSync({prefix: tempFilePre, suffix: tempFileSuf})
    fs.writeFileSync(info.path, parsedCommitMsg)
    cmd = "cd #{gitPath}; git commit -F #{info.path}"
    exec cmd, (error, stdout, stderr) ->
      console.log('stdout: ' + stdout)
      console.log('stderr: ' + stderr)
      if error
        console.log('exec error: ' + error)
      else
        callback()

  # Initial local GIT repo
  initRepo: (callback) ->
    @gitPath ?= atom.config.get('ever-notedown.gitPath')
    @gitPathSymlink ?= atom.config.get('ever-notedown.gitPathSymlink')
    @gitDir ?= new Directory(@gitPath, @gitPathSymlink)
    if @gitDir.existsSync()
      atom.project.repositoryForDirectory(@gitDir).then (repository) =>
        @gitRepo = repository
        if repository is null
          # git.init
          StorageManager.gitInitAsync @gitDir, (gitRepo) =>
            @gitRepo = gitRepo
            if callback? then callback()
    else
      # Create the directory & git.init
      StorageManager.gitInitAsync @gitDir, (gitRepo) =>
        @gitRepo = gitRepo
        if callback? then callback()

  remove: (pathToRemove, callback) ->
    #return unless fs.isFileSync(pathToRemove)
    if (pathToRemove.indexOf(@gitPath) is -1) and
        (pathToRemove.indexOf(@gitDir?.getRealPathSync()) is -1)
      if callback? then callback()
      return
    rpath = @gitRepo.relativize(pathToRemove)
    StorageManager.gitRemoveAsync @gitPath, rpath, () =>
      console.log "File #{pathToRemove} removed with git rm ?"
      if callback? then callback()

  removeFiles: (pathsToRemove, callback) ->
    if (pathsToRemove.length is 0)
      if callback? then callback()
      return
    rpath = @gitRepo.relativize(pathsToRemove[0])
    pathsToRemove.splice(0, 1)
    @remove rpath, () =>
      @removeFiles pathsToRemove, callback

  @gitRemoveAsync: (gitPath, relativizedPathToRemove, callback) ->
    return unless relativizedPathToRemove
    cmd = "cd #{gitPath}; git rm \"#{relativizedPathToRemove.replace(/\"/g, '\\"')}\""
    exec cmd, (error, stdout, stderr) ->
      console.log('stdout: ' + stdout)
      console.log('stderr: ' + stderr)
      if error
        console.log('exec error: ' + error)
      else
        callback()

  @gitAddAsync: (gitPath, relativizedPathToAdd, callback) ->
    return unless relativizedPathToAdd
    cmd = "cd #{gitPath}; git add \"#{relativizedPathToAdd.replace(/\"/g, '\\"')}\""
    exec cmd, (error, stdout, stderr) ->
      console.log('stdout: ' + stdout)
      console.log('stderr: ' + stderr)
      if error
        console.log('exec error: ' + error)
      else
        callback()

  addPath: (pathToAdd, callback) ->
    if (pathToAdd.indexOf(@gitPath) is -1) and
        (pathToAdd.indexOf(@gitDir?.getRealPathSync()) is -1)
      if callback? then callback()
      return
    apath = @gitRepo.relativize(pathToAdd)
    StorageManager.gitAddAsync @gitPath, apath, () =>
      if callback? then callback()

  addPaths: (paths, callback) ->
    if paths.length is 0
      if callback? then callback()
      return
    apath = paths[0]
    paths.splice(0, 1)
    @addPath apath, () =>
      @addPaths paths, callback

  @addDir: (repo, dir) ->
    return unless repo? and dir?.isDirectory()
    staged = false
    for fileEntry in dir.getEntriesSync()
      if fileEntry.isDirectory()
        tmpStaged = StorageManager.addDir(repo, fileEntry)
        if (not staged) and tmpStaged
          staged = true
      else if fileEntry.isFile()
        filePath = repo.relativize(fileEntry.getRealPathSync())
        if repo.isPathNew(filePath) or repo.isPathModified(filePath)
          repo.add filePath
          staged = true
    return staged

  backUpScript: (fileName, fileContent) ->
    return unless @gitDir? and @gitRepo?
    tmpPath = @gitDir.getSubdirectory('tmp').getRealPathSync()
    filePath = path.join tmpPath, fileName
    fs.writeFileSync(filePath, fileContent, 'utf8')
    #repo = git.open(@gitRepo?.getPath())
    #rFilePath = repo?.relativize filePath
    #if rFilePath then repo?.add rFilePath
    #repo?.release()

  @addAppleScripts: (repo) ->
    return false unless repo?
    repoDir = new Directory repo.getWorkingDirectory()
    tmpDir = repoDir.getSubdirectory('tmp')
    staged = false
    return staged unless tmpDir.existsSync()
    for fileEntry in tmpDir.getEntriesSync()
      if fileEntry.isFile() and
          path.extname(fileEntry.getPath())?.trim()?.toLowerCase() is '.applescript'
        filePath = repo.relativize fileEntry.getRealPathSync()
        if filePath? and
            (repo.isPathNew(filePath) or repo.isPathModified(filePath))
          repo.add filePath
          staged = true
    return staged

  # Add a new note to local storage
  # TODO: tags, notebook, creation date, etc.
  addNote: (note, commit, gitMessage, callback) ->
    return unless note?
    commit ?= false
    gitMessage ?= "Updated note: " + note.fnStem
    #console.log("New Note entity title: " + note.title)

    # Upate the JSON file
    # TODO
    # atom.notifications?.addError ErrorMsg
    window.evnd.noteIndex.addnote(note)
    #console.log("Updating JSON file: " + @evNotedown.noteIndex.absfilename)
    window.evnd.noteIndex.update()

    toWrite = {}
    if note.text?
      absfilename = path.join(note.path, note.fnStem + ".markdown")
      #console.log("Writing to " + absfilename)
      fs.writeFileSync(absfilename, note.text, 'utf8')
      toWrite.text = absfilename
    if note.html?
      absfilename = path.join(note.path, note.fnStem + ".html")
      #console.log("Writing to " + absfilename)
      fs.writeFileSync(absfilename, note.html, 'utf8')
      toWrite.html = absfilename
    if note.rawHTML?
      absfilename = path.join(note.path, note.fnStem + "_raw.html")
      #console.log("Writing to " + absfilename)
      fs.writeFileSync(absfilename, note.styledHTML(), 'utf8')
      toWrite.rawHTML = absfilename
      absfilename = path.join(note.path, note.fnStem + "_plain.html")
      #console.log("Writing to " + absfilename)
      fs.writeFileSync(absfilename, note.rawHTML, 'utf8')
      toWrite.plainHTML = absfilename
    if note.enml?
      absfilename = path.join(note.path, note.fnStem + ".enml")
      #console.log("Writing to " + absfilename)
      fs.writeFileSync(absfilename, note.enml, 'utf8')
      toWrite.enml = absfilename
    if note.css?
      absfilename = path.join(note.path, note.fnStem + "_style.css")
      #console.log("Writing to " + absfilename)
      fs.writeFileSync(absfilename, note.css, 'utf8')
      toWrite.css = absfilename
    if note.syncdContent?
      absfilename = path.join(note.path, note.fnStem + "_syncd.txt")
      #console.log("Writing to " + absfilename)
      fs.writeFileSync(absfilename, note.syncdContent, 'utf8')
      toWrite.syncdContent = absfilename
    if not fs.isDirectorySync(path.join(note.path, 'attachments/'))
      fs.makeTreeSync(path.join(note.path, 'attachments/'))


    # Git add and commit
    console.log "@gitRepo.getPath(): #{@gitRepo?.getPath()}"
    repo = git.open(@gitRepo?.getPath())
    #console.log "Repo: "
    #console.log repo
    if repo is null
      @initRepo () =>
        @addNote note, commit, gitMessage, callback
      return
    repo.refreshIndex()
    gitPath = repo.getWorkingDirectory()

    filesToRemove = []
    directoriesToAdd = []
    pathsToTryAgain = []
    if not repo?
      if callback? then callback()
    else
      staged = false
      noteModified = false
      toTestPath = "index.json"
      if repo.isPathModified(toTestPath) or repo.isPathNew(toTestPath)
        #console.log("Adding file : index.json")
        try
          repo.add("index.json")
        catch e
          console.log e
          pathsToTryAgain.push("index.json")
        staged = true
      for k, v of toWrite
        #console.log JSON.stringify(toWrite, null, 4)
        toTestPath = repo.relativize(v)
        if (repo.isPathModified(toTestPath) or repo.isPathNew(toTestPath))
          try
            repo.add(toTestPath)
          catch e
            console.log e
            pathsToTryAgain.push(toTestPath)
          #console.log("Adding file : " + v)
          staged = true
          if k in ["css", "text"] then noteModified = true
      for k,v of note.attachments
        if v.path?.indexOf(gitPath) > -1
          vpath = repo.relativize(v.path)
          if v.active and fs.isFileSync(v.path)
            if repo.isPathNew(vpath) or repo.isPathModified(vpath)
              #console.log("Adding file : " + v.path)
              try
                repo.add vpath
              catch e
                console.log e
                pathsToTryAgain.push vpath
              staged = true
              noteModified = true
          else if not v.active
            #console.log "This file is inactive..."
            if not repo.isPathStaged(vpath)
              #console.log("Removing file : " + v.path)
              filesToRemove.push v.path
            delete note.attachments[k]
            staged = true
      for exportedFilePath in note.enExportedFiles
        if fs.isFileSync(exportedFilePath) #or fs.isDirectorySync(exportedFilePath)
          toTestPath = repo.relativize(exportedFilePath)
          if (repo.isPathModified(toTestPath) or repo.isPathNew(toTestPath))
            try
              repo.add(toTestPath)
            catch e
              console.log e
              pathsToTryAgain.push(toTestPath)
            staged = true
        if fs.isDirectorySync(exportedFilePath)
          directoriesToAdd.push exportedFilePath

      tmpStaged = StorageManager.addAppleScripts(repo)
      if (not staged) and tmpStaged then staged = true
      for item in pathsToTryAgain
        directoriesToAdd.push item
      @addPaths directoriesToAdd, () =>
        @removeFiles filesToRemove, () =>
          repo.refreshIndex()
          repo.release()
          if staged and commit
            StorageManager.gitCommitAsync gitPath, gitMessage, () =>
              if callback? then callback()
              return
          else
            if callback? then callback()
            #console.log("noteModified: " + noteModified)
            return noteModified



