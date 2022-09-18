"use strict";

/*
 * scavenger.js
 * ============
 * 
 * Client-side JavaScript decoder for Scavenger file format.
 * 
 * Include this with <script src="scavenger.js"></script>
 * 
 * Declare a new decoder like this:
 * 
 *    let decoder = new Scavenger();
 * 
 * Then, you interact with the decoder object you constructed.  Many of
 * these functions are asynchronous, so either use await from an
 * asynchronous function, or handle the promise returned by the
 * function.
 * 
 * First step is to load a File or a Blob that contains the whole
 * Scavenger file:
 * 
 *    await decoder.load(scavenger_blob);
 * 
 * You can then access the primary and secondary signatures as base-16
 * strings, and compare given primary and secondary signatures to see if
 * they match:
 * 
 *    const primary   = decoder.getPrimary();
 *    const secondary = decoder.getSecondary();
 *    if (decoder.matches("01020304", "exampl")) {
 *      ...
 *    }
 * 
 * For the matches function, the primary signature must be a string of
 * exactly eight base-16 digits and the secondary signature can either
 * be a string of exactly twelve base-16 digits, or a string of exactly
 * six US-ASCII characters in range [0x20, 0x7e].
 * 
 * The total count of objects is always available:
 * 
 *    const obj_count = decoder.getCount();
 * 
 * Return a blob containing a specific binary object with the following:
 * 
 *    const my_blob = await decoder.fetch(3, "image/jpeg");
 * 
 * The second parameter is the content type to assign to the blob.  Use
 * an empty string if you don't need this.
 * 
 * As a convenience function, you can decode a whole binary object as a
 * UTF-8 string with the following:
 * 
 *   const my_text = await decoder.fetchUTF8(5);
 */

/*
 * Constructor
 * ===========
 */

/*
 * The object starts out unloaded.
 */
function Scavenger() {
  this._loaded = false;
}

/*
 * Local static functions
 * ======================
 */

/*
 * Promise-based wrapper for FileReader.
 * 
 * Parameters:
 * 
 *   fil : File or Blob - what we will be reading
 * 
 *   offs : integer - the byte offset to start reading from
 * 
 *   sz : integer - the number of bytes to read, must be > 0
 * 
 * Return:
 * 
 *   Promise that resolves to ArrayBuffer storing the requested
 *   portion of the source
 */
Scavenger._readFile = function(fil, offs, sz) {
  // Check parameters
  if ((!isInteger(offs)) || (!isInteger(sz))) {
    throw new TypeError();
  }
  if ((offs < 0) || (sz < 1)) {
    throw new Error("Parameters out of range");
  }
  
  // Check that requested range is within file bounds
  if (offs > fil.size - sz) {
    throw new Error("Subrange out of file boundaries");
  }
  
  // Get the readObj that we will be reading, which is the requested
  // subrange
  let readObj = fil;
  if (sz !== fil.size) {
    readObj = fil.slice(offs, offs + sz);
  }
  
  // Wrap the rest in a Promise that we return
  return new Promise(function(resolutionFunc, rejectionFunc) {
    // Construct the FileReader
    const fr = new FileReader();
    
    // The success flag will be set when we get a successful read
    let success = false;
    
    // At the end of the asynchronous read operation, if we weren't
    // successful, reject the promise
    fr.addEventListener('loadend', function(ev) {
      if (!success) {
        rejectionFunc(new Error("File read failed"));
      }
    });
    
    // When the reader successfully completes, set the success flag
    // and then call the resolution function
    fr.addEventListener('load', function(ev) {
      success = true;
      resolutionFunc(fr.result);
    });
    
    // Asynchronously read the requested part of the file
    fr.readAsArrayBuffer(readObj);
  });
};

/*
 * Decode the header of a Scavenger file, given the whole thing as an
 * ArrayBuffer.
 * 
 * Parameters:
 * 
 *   arb : ArrayBuffer - the header to decode
 * 
 * Return:
 * 
 *   an array containing: (1) the primary signature as a lowercase
 *   base-16 string; (2) the secondary signature as a lowercase base-16
 *   string; (3) the total file size in bytes from the header field
 */
Scavenger._decodeHeader = function(arb) {
  // Check parameters
  if (!(arb instanceof ArrayBuffer)) {
    throw new TypeError();
  }
  if (arb.byteLength !== 16) {
    throw new Error("Invalid buffer length");
  }
  
  // Get a DataView
  const dv = new DataView(arb);
  
  // Get the primary signature
  let primary = "";
  for(let x = 0; x < 4; x++) {
    // Get current byte
    let b = dv.getUint8(x);
    
    // Convert to base-16 lowercase
    b = b.toString(16).toLowerCase();
    
    // Pad if necessary
    if (b.length < 2) {
      b = "0" + b;
    }
    
    // Add to primary signature
    primary = primary + b;
  }
  
  // Get the secondary signature
  let secondary = "";
  for(let x = 0; x < 6; x++) {
    // Get current byte
    let b = dv.getUint8(x + 4);
    
    // Convert to base-16 lowercase
    b = b.toString(16).toLowerCase();
    
    // Pad if necessary
    if (b.length < 2) {
      b = "0" + b;
    }
    
    // Add to secondary signature
    secondary = secondary + b;
  }
  
  // Get the low and high parts of the size
  let size_low  = dv.getUint32(10);
  let size_high = dv.getUint16(14);
  
  // Shift high size without using bitwise (to prevent any conversion to
  // 32-bit integer)
  size_high = size_high * (0xffffffff + 1);
  
  // Get the full size
  const full_size = size_high + size_low;
  
  // Return result
  return [primary, secondary, full_size];
}

/*
 * Decode the object count, given the whole thing as an ArrayBuffer.
 * 
 * Parameters:
 * 
 *   arb : ArrayBuffer - the object count to decode
 * 
 * Return:
 * 
 *   the object count as an integer
 */
Scavenger._decodeCount = function(arb) {
  // Check parameters
  if (!(arb instanceof ArrayBuffer)) {
    throw new TypeError();
  }
  if (arb.byteLength !== 6) {
    throw new Error("Invalid buffer length");
  }
  
  // Get a DataView
  const dv = new DataView(arb);
  
  // Get the low and high parts of the count
  let count_low  = dv.getUint32(0);
  let count_high = dv.getUint16(4);
  
  // Shift high size without using bitwise (to prevent any conversion to
  // 32-bit integer)
  count_high = count_high * (0xffffffff + 1);
  
  // Get the full size
  const full_count = count_high + count_low;
  
  // Return result
  return full_count;
}

/*
 * Decode an object index record, given the whole thing as an
 * ArrayBuffer.
 * 
 * The returned values are NOT checked for validity.
 * 
 * Parameters:
 * 
 *   arb : ArrayBuffer - the index record to decode
 * 
 * Return:
 * 
 *   an array containing: (1) the file offset of the object; (2) the
 *   size in bytes of the object
 */
Scavenger._decodeIndex = function(arb) {
  // Check parameters
  if (!(arb instanceof ArrayBuffer)) {
    throw new TypeError();
  }
  if (arb.byteLength !== 12) {
    throw new Error("Invalid buffer length");
  }
  
  // Get a DataView
  const dv = new DataView(arb);
  
  // Get the low and high parts of the fields
  let offs_low  = dv.getUint32(0);
  let size_low  = dv.getUint32(4);
  
  let offs_high = dv.getUint16(8);
  let size_high = dv.getUint16(10);
  
  // Define value to simulate shift left by 32 without using bitwise
  // (to prevent any conversion to 32-bit integer)
  const shift_val = (0xffffffff + 1);
  
  // Get the full fields
  const full_offs = (offs_high * shift_val) + offs_low;
  const full_size = (size_high * shift_val) + size_low;
  
  // Return result
  return [full_offs, full_size];
}

/*
 * Public instance functions
 * =========================
 */

/*
 * Load the decoder with a source.
 * 
 * The source should be a File or a Blob.
 * 
 * Parameters:
 * 
 *   src : File or Blob - the whole Scavenger binary file
 */
Scavenger.prototype.load = async function(src) {
  // Size must be at least 22 (16 bytes header and six bytes for an
  // object count, and the total file size mod 4 must be 2
  if (src.size < 22) {
    throw new Error("File is too small");
  }
  if ((src.size % 4) !== 2) {
    throw new Error("File is not aligned");
  }
  
  // Read the header into an ArrayBuffer and parse it
  let header = await Scavenger._readFile(src, 0, 16);
  header = Scavenger._decodeHeader(header);
  
  // Make sure declared size in header matches blob size
  if (src.size !== header[2]) {
    throw new Error("Declared size mismatch");
  }
  
  // Read the object count into an ArrayBuffer and parse it
  let obj_count = await Scavenger._readFile(src, src.size - 6, 6);
  obj_count = Scavenger._decodeCount(obj_count);
  
  // Compute the maximum number of objects that could be stored in a
  // file of this size based on their index overhead requirements
  const max_count = Math.floor((src.size - 6 - 16) / 12);
  
  // Make sure given object count doesn't exceed capacity
  if (obj_count > max_count) {
    throw new Error("File size too small for object count");
  }
  
  // If we got here, then set the loaded flag if not already set and
  // then write all out properties
  this._loaded = true;
  
  // _size stores the total size
  this._size = src.size;
  
  // _blob stores the blob
  this._blob = src;
  
  // _primary and _secondary store the signatures
  this._primary   = header[0];
  this._secondary = header[1];
  
  // _count stores the object count
  this._count = obj_count;
  
  // _index is the file offset of the start of the index
  this._index = this._size - 6 - (this._count * 12);
  if (this._index < 16) {
    throw new Error("Unexpected");
  }
};

/*
 * Return the primary signature as a lowercase base-16 string.
 * 
 * Only available if loaded.
 * 
 * Return:
 * 
 *   the primary signature as a base-16 string
 */
Scavenger.prototype.getPrimary = function() {
  // Check state
  if (!(this._loaded)) {
    throw new Error("Unloaded");
  }
  
  // Return result
  return this._primary;
};

/*
 * Return the secondary signature as a lowercase base-16 string.
 * 
 * Only available if loaded.
 * 
 * Return:
 * 
 *   the secondary signature as a base-16 string
 */
Scavenger.prototype.getSecondary = function() {
  // Check state
  if (!(this._loaded)) {
    throw new Error("Unloaded");
  }
  
  // Return result
  return this._secondary;
};

/*
 * Check whether a given primary and secondary signature match what was
 * read from the file.
 * 
 * Only available if loaded.
 * 
 * Parameters:
 * 
 *   primary : string - the primary signature as a string of exactly
 *   eight base-16 digits
 * 
 *   secondary : string - the secondary signature, either as a string of
 *   exactly twelve base-16 digits, or a string of exactly six US-ASCII
 *   characters in range [0x20, 0x7e]
 * 
 * Return:
 * 
 *   true if match, false if not
 */
Scavenger.prototype.matches = function(primary, secondary) {
  // Check state
  if (!(this._loaded)) {
    throw new Error("Unloaded");
  }
  
  // Check parameters
  if ((typeof(primary) !== "string") ||
        (typeof(secondary) !== "string")) {
    throw new TypeError();
  }
  
  // If secondary is six characters, convert to base-16
  if (secondary.length === 6) {
    let cvt = '';
    for(let i = 0; i < 6; i++) {
      let b = secondary.charCodeAt(i);
      if ((b < 0x20) || (b > 0x7e)) {
        throw new Error("Invalid secondary signature");
      }
      b = b.toString(16).toLowerCase();
      if (b.length < 2) {
        b = "0" + b;
      }
      cvt = cvt + b;
    }
    secondary = cvt;
  }
  
  // Check signature formats
  if (!((/^[0-9A-Fa-f]{8}$/).test(primary))) {
    throw new Error("Invalid primary signature");
  }
  if (!((/^[0-9A-Fa-f]{12}$/).test(secondary))) {
    throw new Error("Invalid secondary signature");
  }
  
  // Convert to lowercase
  primary   = primary.toLowerCase();
  secondary = secondary.toLowerCase();
  
  // Check if match
  let result = false;
  if ((primary === this._primary) && (secondary === this._secondary)) {
    result = true;
  }
  
  // Return result
  return result;
};

/*
 * Return the number of objects within the Scavenger file.
 * 
 * Only available if loaded.
 * 
 * Return:
 * 
 *   the object count
 */
Scavenger.prototype.getCount = function() {
  // Check state
  if (!(this._loaded)) {
    throw new Error("Unloaded");
  }
  
  // Return result
  return this._count;
};

/*
 * Fetch a given binary object within a Scavenger file as a Blob.
 * 
 * Only available if loaded.
 * 
 * Parameters:
 * 
 *   i : integer - the object index
 * 
 *   ctype : string - the content type to assign to the blob, or an
 *   empty string
 * 
 * Return:
 * 
 *   the object as a Blob
 */
Scavenger.prototype.fetch = async function(i, ctype) {
  // Check state
  if (!(this._loaded)) {
    throw new Error("Unloaded");
  }
  
  // Check parameters
  if (typeof(i) !== "number") {
    throw new TypeError();
  }
  if (!isFinite(i)) {
    throw new TypeError();
  }
  if (Math.floor(i) !== i) {
    throw new TypeError();
  }
  if ((i < 0) || (i >= this._count)) {
    throw new Error("Object index out of range");
  }
  
  if (typeof(ctype) !== "string") {
    throw new TypeError();
  }
  
  // Load the index record for the object and parse it
  let irec = await Scavenger._readFile(
                          this._src,
                          this._index + (i * 12),
                          12);
  irec = Scavenger._decodeIndex(irec);
  
  // Check offset and object size by themselves
  if (!((irec[0] >= 0) && (irec[0] < this._size))) {
    throw new Error("Invalid index record");
  }
  if (!((irec[1] > 0) && (irec[1] <= this._size))) {
    throw new Error("Invalid index record");
  }
  
  // Check subrange of blob is within boundaries
  if (!(irec[1] <= this._size - irec[0])) {
    throw new Error("Invalid index record");
  }
  
  // Return the new blob
  return this._src.slice(irec[0], irec[1], ctype);
};

/*
 * Fetch a given binary object within a Scavenger file and decode it as
 * UTF-8 text.
 * 
 * Only available if loaded.
 * 
 * Parameters:
 * 
 *   i : integer - the object index
 * 
 * Return:
 * 
 *   the object as a string
 */
Scavenger.prototype.fetchUTF8 = async function(i) {
  // Call through to blob loader
  let result = await this.fetch(i, "");
  
  // Create a new text decoder
  const tdec = new TextDecoder("utf-8", { fatal: true });
  
  // Read the whole blob
  result = await Scavenger._readFile(result, 0, result.size);
  
  // Decode the blob contents as UTF-8 text and return it
  return tdec.decode(result);
};
