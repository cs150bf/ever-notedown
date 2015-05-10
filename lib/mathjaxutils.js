/* Originally FROM ipython/IPython/html/static/notebook/js/mathjaxutils.js
 *      and
 *      ipython/IPython/html/static/base/js/utils.js
 *
 * (Updated: now at 
 *      [https://github.com/jupyter/jupyter_notebook/blob/master/jupyter_notebook/static/notebook/js/mathjaxutils.js]  *    and [https://github.com/jupyter/jupyter_notebook/blob/master/jupyter_notebook/static/base/js/utils.js] ?)
 * Reproduced copyright info:
 * Copyright (c) Jupyter Development Team.
 * Distributed under the terms of the Modified BSD License.
 * 
 */


//============================================================================
// Cross-browser RegEx Split
//============================================================================

// This code has been MODIFIED from the code licensed below to not replace the
// default browser split.  The license is reproduced here.

// see http://blog.stevenlevithan.com/archives/cross-browser-split for more info:
/*!
 * Cross-Browser Split 1.1.1
 * Copyright 2007-2012 Steven Levithan <stevenlevithan.com>
 * Available under the MIT License
 * ECMAScript compliant, uniform cross-browser split method
 */

/**
 * Splits a string into an array of strings using a regex or string
 * separator. Matches of the separator are not included in the result array.
 * However, if `separator` is a regex that contains capturing groups,
 * backreferences are spliced into the result each time `separator` is
 * matched. Fixes browser bugs compared to the native
 * `String.prototype.split` and can be used reliably cross-browser.
 * @param {String} str String to split.
 * @param {RegExp} separator Regex to use for separating
 *     the string.
 * @param {Number} [limit] Maximum number of items to include in the result
 *     array.
 * @returns {Array} Array of substrings.
 * @example
 *
 * // Basic use
 * regex_split('a b c d', ' ');
 * // -> ['a', 'b', 'c', 'd']
 *
 * // With limit
 * regex_split('a b c d', ' ', 2);
 * // -> ['a', 'b']
 *
 * // Backreferences in result array
 * regex_split('..word1 word2..', /([a-z]+)(\d+)/i);
 * // -> ['..', 'word', '1', ' ', 'word', '2', '..']
 */
var regex_split = function (str, separator, limit) {
    var output = [],
        flags = (separator.ignoreCase ? "i" : "") +
                (separator.multiline  ? "m" : "") +
                (separator.extended   ? "x" : "") + // Proposed for ES6
                (separator.sticky     ? "y" : ""), // Firefox 3+
        lastLastIndex = 0,
        separator2, match, lastIndex, lastLength;
    // Make `global` and avoid `lastIndex` issues by working with a copy
    separator = new RegExp(separator.source, flags + "g");

    var compliantExecNpcg = typeof(/()??/.exec("")[1]) === "undefined";
    if (!compliantExecNpcg) {
        // Doesn't need flags gy, but they don't hurt
        separator2 = new RegExp("^" + separator.source + "$(?!\\s)", flags);
    }
    /* Values for `limit`, per the spec:
     * If undefined: 4294967295 // Math.pow(2, 32) - 1
     * If 0, Infinity, or NaN: 0
     * If positive number: limit = Math.floor(limit); if (limit > 4294967295) limit -= 4294967296;
     * If negative number: 4294967296 - Math.floor(Math.abs(limit))
     * If other: Type-convert, then use the above rules
     */
    limit = typeof(limit) === "undefined" ?
        -1 >>> 0 : // Math.pow(2, 32) - 1
        limit >>> 0; // ToUint32(limit)
    for (match = separator.exec(str); match; match = separator.exec(str)) {
        // `separator.lastIndex` is not reliable cross-browser
        lastIndex = match.index + match[0].length;
        if (lastIndex > lastLastIndex) {
            output.push(str.slice(lastLastIndex, match.index));
            // Fix browsers whose `exec` methods don't consistently return `undefined` for
            // nonparticipating capturing groups
            if (!compliantExecNpcg && match.length > 1) {
                match[0].replace(separator2, function () {
                    for (var i = 1; i < arguments.length - 2; i++) {
                        if (typeof(arguments[i]) === "undefined") {
                            match[i] = undefined;
                        }
                    }
                });
            }
            if (match.length > 1 && match.index < str.length) {
                Array.prototype.push.apply(output, match.slice(1));
            }
            lastLength = match[0].length;
            lastLastIndex = lastIndex;
            if (output.length >= limit) {
                break;
            }
        }
        if (separator.lastIndex === match.index) {
            separator.lastIndex++; // Avoid an infinite loop
        }
    }
    if (lastLastIndex === str.length) {
        if (lastLength || !separator.test("")) {
            output.push("");
        }
    } else {
        output.push(str.slice(lastLastIndex));
    }
    return output.length > limit ? output.slice(0, limit) : output;
};

//============================================================================
// End contributed Cross-browser RegEx Split
//============================================================================



// Some magic for deferring mathematical expressions to MathJax
// by hiding them from the Markdown parser.
// Some of the code here is adapted with permission from Davide Cervone
// under the terms of the Apache2 license governing the MathJax project.
// Other minor modifications are also due to StackExchange and are used with
// permission.

var inline = "$"; // the inline math delimiter

// MATHSPLIT contains the pattern for math delimiters and special symbols
// needed for searching for math in the text input.
var MATHSPLIT = /(\$\$?|\\(?:begin|end)\{[a-z]*\*?\}|\\[\\{}$]|[{}]|(?:\n\s*)+|@@\d+@@)/i;

//  The math is in blocks i through j, so
//    collect it into one block and clear the others.
//  Replace &, <, and > by named entities.
//  For IE, put <br> at the ends of comments since IE removes \n.
//  Clear the current math positions and store the index of the
//    math, then push the math string onto the storage array.
//  The preProcess function is called on all blocks if it has been passed in
module.exports.process_math = function process_math(i, j, pre_process, math, blocks) {
    var block = blocks.slice(i, j + 1).join("");
    //var block = blocks.slice(i, j + 1).join("").replace(/&/g, "&amp;") // use HTML entity for &
    //.replace(/</g, "&lt;") // use HTML entity for <
    //.replace(/>/g, "&gt;") // use HTML entity for >
    //;
    //
    // Ever Notedown: We don't need this... do we?
    //
    //if (utils.browser === 'msie') {
    //    block = block.replace(/(%[^\n]*)\n/g, "$1<br/>\n");
    //}
    while (j > i) {
        blocks[j] = "";
        j--;
    }
    blocks[i] = "@@" + math.length + "@@"; // replace the current block text with a unique tag to find later
    if (pre_process){
        block = pre_process(block);
    }
    math.push(block);
    return blocks;
};

//  Break up the text into its component parts and search
//    through them for math delimiters, braces, linebreaks, etc.
//  Math delimiters must match and braces must balance.
//  Don't allow math to pass through a double linebreak
//    (which will be a paragraph).
//
module.exports.remove_math = function remove_math(text) {
    var math = []; // stores math strings for later
    var start;
    var end;
    var last;
    var braces;

    // Except for extreme edge cases, this should catch precisely those pieces of the markdown
    // source that will later be turned into code spans. While MathJax will not TeXify code spans,
    // we still have to consider them at this point; the following issue has happened several times:
    //
    //     `$foo` and `$bar` are varibales.  -->  <code>$foo ` and `$bar</code> are variables.

    var hasCodeSpans = /`/.test(text),
        de_tilde;
    // Ever Notedown: Needs to handle fenced code block
    var hasCodeBlock = /`{3}/.test(text);
    if (hasCodeBlock) {
        text = text.replace(/~/g, "~T").replace(/(^|[^\\])(```)([\s\S]*?[^`{3}])\2(?!`)/g, function (wholematch) {
            return wholematch.replace(/\$/g, "~D");
        });
    }
    // Ever Notedown: modify to avoid conflicts with fenced code block
    if (hasCodeSpans) {
        if (!hasCodeBlock) {
            text = text.replace(/~/g, "~T");
        }
        text = text.replace(/(^|[^\\])(`+)([^\n]*?[^`\n])\2(?!`)/gm, function (wholematch) {
            return wholematch.replace(/\$/g, "~D");
        });
    }

    if (hasCodeBlock || hasCodeSpans) {
        de_tilde = function (text) {
            return text.replace(/~([TD])/g, function (wholematch, character) {
                                                return { T: "~", D: "$" }[character];
                                            });
        };

    }else {
        de_tilde = function (text) { return text; };
    }

    var blocks = regex_split(text.replace(/\r\n?/g, "\n"), MATHSPLIT);

    for (var i = 1, m = blocks.length; i < m; i += 2) {
        var block = blocks[i];
        if (block.charAt(0) === "@") {
            //
            //  Things that look like our math markers will get
            //  stored and then retrieved along with the math.
            //
            blocks[i] = "@@" + math.length + "@@";
            math.push(block);
        }
        else if (start) {
            //
            //  If we are in math, look for the end delimiter,
            //    but don't go past double line breaks, and
            //    and balance braces within the math.
            //
            if (block === end) {
                if (braces) {
                    last = i;
                }
                else {
                    blocks = this.process_math(start, i, de_tilde, math, blocks);
                    start  = null;
                    end    = null;
                    last   = null;
                }
            }
            else if (block.match(/\n.*\n/)) {
                if (last) {
                    i = last;
                    blocks = this.process_math(start, i, de_tilde, math, blocks);
                }
                start = null;
                end = null;
                last = null;
                braces = 0;
            }
            else if (block === "{") {
                braces++;
            }
            else if (block === "}" && braces) {
                braces--;
            }
        }
        else {
            //
            //  Look for math start delimiters and when
            //    found, set up the end delimiter.
            //
            if (block === inline || block === "$$") {
                start = i;
                end = block;
                braces = 0;
            }
            else if (block.substr(1, 5) === "begin") {
                start = i;
                end = "\\end" + block.substr(6);
                braces = 0;
            }
        }
    }
    if (last) {
        blocks = this.process_math(start, last, de_tilde, math, blocks);
        start  = null;
        end    = null;
        last   = null;
    }

    var oldText = blocks.join("");
    var newText = de_tilde(oldText);
    // console.log("Old text: " + oldText);
    // console.log("Testing de_tilda: " + de_tilde("\n```$ sudo su\n```\n"));
    // console.log("New Text: " + newText);
    return [newText, math];
};

//
//  Put back the math strings that were saved,
//    and clear the math array (no need to keep it around).
//
module.exports.replace_math = function replace_math(text, math) {
    text = text.replace(/@@(\d+)@@/g, function (match, n) {
        return math[n];
    });
    return text;
};

