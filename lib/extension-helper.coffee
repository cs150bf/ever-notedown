# Based on https://github.com/atom/markdown-preview/blob/9ff76ad3f6407a0fb68163a538c6d460280a1718/lib/extension-helper.coffee
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
scopesByFenceName =
  'sh': 'source.shell'
  'bash': 'source.shell'
  'c': 'source.c'
  'c++': 'source.cpp'
  'cpp': 'source.cpp'
  'coffee': 'source.coffee'
  'coffeescript': 'source.coffee'
  'coffee-script': 'source.coffee'
  'cs': 'source.cs'
  'csharp': 'source.cs'
  'css': 'source.css'
  'scss': 'source.css.scss'
  'sass': 'source.sass'
  'erlang': 'source.erl'
  'go': 'source.go'
  'html': 'text.html.basic'
  'java': 'source.java'
  'js': 'source.js'
  'javascript': 'source.js'
  'json': 'source.json'
  'less': 'source.less'
  'markdown': 'source.gfm' # Extended
  'mustache': 'text.html.mustache'
  'objc': 'source.objc'
  'objective-c': 'source.objc'
  'php': 'text.html.php'
  'py': 'source.python'
  'python': 'source.python'
  'rb': 'source.ruby'
  'ruby': 'source.ruby'
  'shell': 'source.shell' # Extended
  'text': 'text.plain'
  'toml': 'source.toml'
  'xml': 'text.xml'
  'yaml': 'source.yaml'
  'yml': 'source.yaml'

module.exports =
  scopeForFenceName: (fenceName) ->
    scopesByFenceName[fenceName] ? "source.#{fenceName}"
  # FOR EVND
  fenceNameForScope: (scopeName) ->
    for k, v of scopesByFenceName
      if v is scopeName then return k
    if scopeName.indexOf('source.') is 0
      return scopeName.slice(7, scopeName.length)
    else
      return null

