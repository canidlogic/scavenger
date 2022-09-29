"use strict";

/*
 * scavenger_view.js
 * =================
 * 
 * JavaScript code for the Scavenger viewer app.
 * 
 * You must also load scavenger.js as a prerequisite for this module.
 */

// Wrap everything in an anonymous function that we immediately invoke
// after it is declared -- this prevents anything from being implicitly
// added to global scope
(function() {

  /*
   * Constants
   * =========
   */
  
  /*
   * Array storing all the top-level DIVs.
   */
  const DIV_LIST = ["divLoading", "divLoadError", "divLoadDialog",
                    "divMainError", "divMain"];
  
  /*
   * Local data
   * ==========
   */
  
  /*
   * When a file is loaded, this object will store the Scavenger
   * decoder instance.
   * 
   * When no file is loaded, this is null.
   */
  let m_data = null;
  
  /*
   * The genid is incremented each time the file is loaded or unloaded,
   * and each time a new link generation begins
   */
  let m_genid = 0;
  
  /*
   * The most recently generated object URL, or null if nothing loaded.
   */
  let m_objurl = null;
  
  /*
   * Local functions
   * ===============
   */
  
  /*
   * Check whether the given parameter is a finite integer.
   * 
   * Parameters:
   * 
   *   i - the value to check
   * 
   * Return:
   * 
   *   true if finite integer, false if not
   */
  function isInteger(i) {
    if (typeof(i) !== "number") {
      return false;
    }
    if (!isFinite(i)) {
      return false;
    }
    if (Math.floor(i) !== i) {
      return false;
    }
    return true;
  }
  
  /*
   * Escape the < > & characters in a string with HTML entities so that
   * the string can be used as HTML code.
   * 
   * Parameters:
   * 
   *   str : string - the string to escape
   * 
   * Return:
   * 
   *   the escaped string
   */
  function escapeHTML(str) {
    // Check parameter
    if (typeof(str) !== "string") {
      throw new TypeError();
    }
    
    // Replace the control characters, ampersand first
    str = str.replace(/&/g, "&amp;");
    str = str.replace(/</g, "&lt;" );
    str = str.replace(/>/g, "&gt;" );
    
    // Return replaced string
    return str;
  }
  
  /*
   * Get a document element with the given ID.
   * 
   * An exception is thrown if no element with that ID is found.
   * 
   * Parameters:
   * 
   *   eid : string - the ID of the element
   * 
   * Return:
   * 
   *   the element
   */
  function findElement(eid) {
    // Check parameter
    if (typeof(eid) !== "string") {
      throw new TypeError();
    }
    
    // Query for element
    const e = document.getElementById(eid);
    if (!e) {
      throw new Error("Can't find element with ID '" + eid + "'");
    }
    
    // Return the element
    return e;
  }
  
  /*
   * Hide all main DIVs and then show the DIV with the given ID.
   * 
   * The given ID must be one of the DIVs in the DIV_LIST constant.
   * 
   * Parameters:
   * 
   *   divid : string - the ID of the main DIV to show
   */
  function showDIV(divid) {
    
    // Check parameter
    if (typeof(divid) !== "string") {
      throw new TypeError();
    }
    
    // Check that ID is recognized
    let found = false;
    for(let i = 0; i < DIV_LIST.length; i++) {
      if (DIV_LIST[i] === divid) {
        found = true;
        break;
      }
    }
    if (!found) {
      throw new Error("Invalid DIV ID");
    }
    
    // Hide all top-level DIVs
    for(let i = 0; i < DIV_LIST.length; i++) {
      findElement(DIV_LIST[i]).style.display = "none";
    }
    
    // Show the desired DIV
    findElement(divid).style.display = "block";
  }
  
  /*
   * Show the load error DIV with a given message.
   * 
   * The message should NOT be HTML escaped.
   * 
   * Parameters:
   * 
   *   msg : string - the loading error message to show
   */
  function showLoadError(msg) {
    // Check parameter
    if (typeof(msg) !== "string") {
      throw new TypeError();
    }
    
    // Update the message content
    findElement("divMessageContent").innerHTML = escapeHTML(msg);
    
    // Show the error message DIV
    showDIV("divLoadError");
  }
  
  /*
   * Show the main error DIV with a given message.
   * 
   * The message should NOT be HTML escaped.
   * 
   * Parameters:
   * 
   *   msg : string - the main error message to show
   */
  function showMainError(msg) {
    // Check parameter
    if (typeof(msg) !== "string") {
      throw new TypeError();
    }
    
    // Update the message content
    findElement("divMainErrorText").innerHTML = escapeHTML(msg);
    
    // Show the error message DIV
    showDIV("divMainError");
  }
  
  /*
   * Display the main screen, set up appropriately for the loaded
   * Scavenger file.
   * 
   * m_data must be loaded for this to work.
   */
  function loadDisplay() {
    // Check state
    if (m_data === null) {
      throw new Error("No data file loaded");
    }
    if (!m_data.isLoaded()) {
      throw new Error("Decoder is not loaded");
    }
    
    // Write the object count
    findElement("tdCount").innerHTML = escapeHTML(
                            m_data.getCount().toString(10));
    
    // Write the primary signature
    findElement("tdPrimary").innerHTML = escapeHTML(
                            "0x" + m_data.getPrimary());
    
    // Write the secondary signature
    findElement("tdSecondary").innerHTML = escapeHTML(
                            "0x" + m_data.getSecondary());
    
    // Now check if we can decode the secondary signature as ASCII
    const secBase16 = m_data.getSecondary();
    if (!((/^[0-9a-fA-F]{12}$/).test(secBase16))) {
      throw new Error("Unexpected");
    }
    
    let secASCII = "";
    for(let x = 0; x < 12; x = x + 2) {
      // Decode current pair of base-16 digits as byte value
      const d = parseInt(secBase16.slice(x, x + 2), 16);
      
      // If byte value in US-ASCII printing range, add character to
      // ASCII printout; else, set ASCII printout to null and leave loop
      if ((d >= 0x20) && (d <= 0x7e)) {
        secASCII = secASCII + String.fromCharCode(d);
      } else {
        secASCII = null;
        break;
      }
    }
    
    // If secASCII is successfully defined, escape it as HTML; else, set
    // it to an em dash
    if (secASCII !== null) {
      secASCII = escapeHTML(secASCII);
    } else {
      secASCII = "&mdash;";
    }
    
    // Write the ASCII parsing, if there is one
    findElement("tdSecASCII").innerHTML = secASCII;
    
     // Get output element for generated link
    const genlink = findElement("divGenLink");
    
    // Remove anything currently in the generated link
    while (genlink.lastChild !== null) {
      genlink.removeChild(genlink.lastChild);
    }
    
    // Show the main display
    showDIV("divMain");
  }
  
  /*
   * Asynchronous function handler used when user chooses to load a new
   * file.
   * 
   * The only thing that has been done so far is to change the display
   * to the "Loading..." DIV and get the file from the display.
   * 
   * Exceptions may be thrown if any failure.  The main handler should
   * handle these exceptions properly.
   * 
   * Parameters:
   * 
   *   fil : File - the file to upload
   */
  async function uploadFile(fil) {
    // Check parameter
    if (!(fil instanceof File)) {
      throw new TypeError();
    }

    // Start a new Scavenger decoder and increment generation ID
    m_data = new Scavenger();
    m_genid++;
    
    // Load the file in the decoder
    await m_data.load(fil);
    
    // Finally, load and show the display for the file
    loadDisplay();
  }
  
  /*
   * Public functions
   * ================
   */

  /*
   * Invoked when the user chooses to generate a link to a given object
   * within the Scavenger file.
   */
  function generateLink() {
    // Ignore call if nothing loaded
    if (m_data === null) {
      return;
    }
    
    // Get output element for generated link
    const genlink = findElement("divGenLink");
    
    // Remove anything currently in the generated link
    while (genlink.lastChild !== null) {
      genlink.removeChild(genlink.lastChild);
    }
    
    // Get user input
    let objectID = findElement("txtObjectID").value;
    let mimeType = findElement("txtMIMEType").value;
    
    // Parse object ID
    objectID = objectID.trim();
    if (!((/^[1-8]?[0-9]{1,15}$/).test(objectID))) {
      showMainError("Can't parse object ID");
      return;
    }
    objectID = parseInt(objectID);
    
    // Parse MIME type, with application/octet-stream as a default if a
    // blank value was given
    mimeType = mimeType.trim();
    if (mimeType.length < 1) {
      mimeType = "application/octet-stream";
    }
    
    // Check character content and length of MIME type
    if (!((/^[\u0020-\u007e]{1,255}$/).test(mimeType))) {
      showMainError("Invalid character format for MIME type");
      return;
    }
    
    // Split into type, subtype, and parameter array
    if (!((/^[^\/;]+\/[^\/;]+.*$/).test(mimeType))) {
      showMainError("Failed to parse MIME type and subtype");
      return;
    }
    
    if (((/;$/).test(mimeType)) || ((/;;/).test(mimeType))) {
      showMainError("Empty MIME parameter");
      return;
    }
    
    let mimeParams = [];
    for(let si = mimeType.lastIndexOf(";");
        si >= 0;
        si = mimeType.lastIndexOf(";")) {
      // pi has the index of the last semicolon, so get everything after
      // that and add it to the *start* of the mimeParams array (since
      // we are extracting parameters in reverse order)
      mimeParams.unshift(mimeType.slice(si + 1).trim());
      
      // Drop the parameter
      mimeType = mimeType.slice(0, si);
    }
    
    const di = mimeType.indexOf("/");
    if (di < 0) {
      throw new Error("Unexpected");
    }
    
    let mimeMain = mimeType.slice(0, di);
    let mimeSub  = mimeType.slice(di + 1);
    
    mimeMain = mimeMain.trim();
    mimeSub  = mimeSub.trim();
    
    // Check type and subtype tokens
    if (!((/^[^ \(\)<>@,;\:\\"\/\[\]\?\=]+$/).test(mimeMain))) {
      showMainError("Invalid MIME primary type");
      return;
    }
    
    if (!((/^[^ \(\)<>@,;\:\\"\/\[\]\?\=]+$/).test(mimeSub))) {
      showMainError("Invalid MIME subtype");
      return;
    }
    
    // Check each parameter individually and normalize each
    for(let i = 0; i < mimeParams.length; i++) {
      // Get current parameter
      let p = mimeParams[i];
      
      // Find the first equals sign
      const eqi = p.indexOf("=");
      if (eqi < 0) {
        showMainError("MIME parameter lacks = sign");
        return;
      }
      
      // Split into key and value
      let key = p.slice(0, eqi);
      let val = p.slice(eqi + 1);
      
      key = key.trim();
      val = val.trim();
      
      // Check that key is token
      if (!((/^[^ \(\)<>@,;\:\\"\/\[\]\?\=]+$/).test(key))) {
        showMainError("Invalid MIME parameter key");
        return;
      }
      
      // If value is not token, check that it is valid quoted string
      if (!((/^[^ \(\)<>@,;\:\\"\/\[\]\?\=]+$/).test(val))) {
        // Make sure begins and ends with double quotes
        if (!((/^".*"$/).test(val))) {
          showMainError("Invalid MIME parameter value");
          return;
        }
        
        // Make a copy of the value without surrounding quotes
        let qi = val.slice(1, -1);
        
        // Drop any escape sequence from the copy of the value that has
        // a backslash followed by anything else
        qi = qi.replace(/\\./g, "");
        
        // After all escape sequences are removed, no double quote or
        // backslash may remain
        if ((/["\\]/).test(qi)) {
          showMainError("Invalid MIME parameter quoted value");
          return;
        }
      }
      
      // If we got here, key is valid token and val is either valid
      // token or valid quoted string, so replace parameter in array
      // with normalized parameter
      mimeParams[i] = key + "=" + val;
    }
    
    // Rebuild the normalized mimeType
    mimeType = mimeMain + "/" + mimeSub;
    for(let i = 0; i < mimeParams.length; i++) {
      mimeType = mimeType + "; " + mimeParams[i];
    }
    
    // We've fully parsed our objectID and mimeType; now make sure that
    // objectID refers to a valid object
    if ((objectID < 0) || (objectID >= m_data.getCount())) {
      showMainError("Requested object ID is out of range");
      return;
    }
    
    // Increment generation ID and store the current value so we can
    // detect if the asynchronous result is still relevant
    m_genid++;
    const m_current = m_genid;
    
    // Asynchronously load the requested blob
    m_data.fetch(objectID, mimeType).then(
      (value) => {
        // Ignore if generation ID has changed
        if (m_current !== m_genid) {
          return;
        }
        
        // Loading successful, so first of all revoke any current object
        // URL
        if (m_objurl !== null) {
          URL.revokeObjectURL(m_objurl);
          m_objurl = null;
        }
        
        // Create an object URL to the blob we just loaded
        m_objurl = URL.createObjectURL(value);
        
        // Create an <a> element, add CSS class "call", and direct it to
        // open the loaded blob in a new tab
        let a = document.createElement("a");
        a.classList.add("call");
        a.href   = m_objurl;
        a.target = "_blank";
        
        // Set the text of the link
        a.appendChild(document.createTextNode(
          "Binary object #" + objectID.toString(10)
        ));
        
        // Add the link to the page
        genlink.appendChild(a);
      },
      (reason) => {
        // Ignore if generation ID has changed
        if (m_current !== m_genid) {
          return;
        }
        
        // Loading failed somehow
        console.log("Fetch failed:");
        console.log(reason);
        showMainError("Failed to load object blob because "
                        + reason.toString());
      }
    );
  }

  /*
   * Invoked from the main error display screen to show the main screen
   * again.
   */
  function returnMain() {
    showDIV("divMain");
  }

  /*
   * Invoked when we choose to reload a new file.
   */
  function handleReload() {
    m_data = null;
    m_genid++;
    if (m_objurl !== null) {
      URL.revokeObjectURL(m_objurl);
      m_objurl = null;
    }
    showDIV("divLoadDialog");
  }

  /*
   * Invoked when the user chooses to load a new file.
   */
  function handleUpload() {
    // First of all, switch to the loading screen and clear the data
    // state
    showDIV("divLoading");
    m_data = null;
    m_genid++;
    if (m_objurl !== null) {
      URL.revokeObjectURL(m_objurl);
      m_objurl = null;
    }
    
    // Get the file control
    const eFile = findElement("filUpload");
    
    // Check that the user selected exactly one file; if not, then go to
    // load error dialog with appropriate message and do nothing further
    if (eFile.files.length !== 1) {
      showLoadError("Choose a file to view!");
      return;
    }
    
    // Call into our asynchronous loading function with the selected
    // file, and catch and report exceptions
    uploadFile(eFile.files.item(0)).catch(function(reason) {
      console.log(reason);
      showLoadError(reason.toString());
    });
  }

  /*
   * For the main load function, show the load dialog
   */
  function handleLoad() {
    // Show load dialog
    showDIV("divLoadDialog");
  }
  
  /*
   * Export declarations
   * ===================
   * 
   * All exports are declared within a global "scview" object.
   */
  
  window.scview = {
    "generateLink": generateLink,
    "returnMain": returnMain,
    "handleReload": handleReload,
    "handleUpload": handleUpload,
    "handleLoad": handleLoad
  };

}());

// Call into our load handler once DOM is ready
document.addEventListener('DOMContentLoaded', scview.handleLoad);
