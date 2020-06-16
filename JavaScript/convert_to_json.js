#!/usr/bin/env node
/** -*- coding: utf-8 -*-

  convert_to_json.js

  Copyright 2020 fbarda <arda.aydin@operationsilkscarf.com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
  MA 02110-1301, USA.

*/
const fsOpen = require("fs").promises.open, { O_CREAT: Create, O_WRONLY: Write } = require("fs").constants;
const createAndWriteFlag = Create | Write;
/**
 * @description Tries to convert every non-comment line to a json entry.
 * @param {string[]} lines - The lines of the text.
 * @returns {Promise<string>}
 */
async function converter(lines) {
    /**@type {{data:Object , comments:string[]}} */
    const jsonObject = {
        data: {},
        comments: []
    }; // Collect all information here
    for (const line of lines) {
        if (line.startsWith("#")) {
            jsonObject.comments.push(line.slice(1));
            continue;
        }
        const [key, value] = line.split("\t")
            .map(quotedString => quotedString.substring(1, quotedString.length - 1)); //sanitize the property keys and values
        jsonObject.data[key] = value;
    }
    return JSON.stringify(jsonObject, null, "    ");
}
/**
 * @returns {string}
 * @param {string} fileNameWithExtension
 */
function getFileName(fileNameWithExtension) {
    const extensionStart = fileNameWithExtension.lastIndexOf(".");
    return fileNameWithExtension.slice(0, extensionStart);
}
/**
 * @param {string[]} fileNameArray
 * @returns {void}
 */
async function fileConverter(fileNameArray) {
    for (const fileName of fileNameArray) {
        const outputFileName = getFileName(fileName) + ".json";
        const inputFileHandler = fsOpen(fileName);
        const convertedJSON = inputFileHandler.then(fd => fd.readFile())
            .then(buffer => buffer.toString().split(/\r?\n/g))
            .then(converter);
        convertedJSON.then(() => inputFileHandler).then(fd => fd.close()); //Release file after we are done with it.
        const outputFileHandler = fsOpen(outputFileName, createAndWriteFlag);
        await Promise.all([outputFileHandler, convertedJSON])
            .then(([fd, json]) => fd.writeFile(json))
            .then(() => outputFileHandler).then(fd => fd.close);
    }
    return "Done.";
}
module.exports = exports = fileConverter;
const arguments = require("process").argv.slice(2);
if (arguments.length) { //called via cli interface
    fileConverter(arguments).then(console.log);
}
