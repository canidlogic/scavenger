# Scavenger Encoder Module

The encoder module is used to create new Scavenger files.

See `scavenger_common.md` first for general documentation that applies to both the encoder and decoder modules.

## Sample use

    #include "sgr_enc.h"
    #include <stdio.h>
    
    void example() {
      SGR_ENC *pe = NULL;
      FILE *fp = NULL;
    
      // Create a new encoder instance
      pe = sgr_enc_new(
              "path/to/file.scavenger",
              UINT32_C(0x01020304),
              UINT64_C(0x313233343536));
    
      if (sgr_enc_error(pe)) {
        fprintf(stderr, "Error: %s\n", sgr_enc_errmsg(pe));
        sgr_enc_free(pe);
        return;
      }
    
      // Begin writing a binary object
      if (!sgr_enc_beginObject(pe)) {
        ...
      }
    
      // Get file handle for writing the object
      fp = sgr_enc_handle(pe);
      if (fp == NULL) {
        ...
      }
    
      // File pointer already positioned at end of file; write all the
      // bytes of the binary object at the end of the file using
      // standard I/O on the handle
      fprintf(fp, "Hello, world!");
    
      // Finish writing a binary object
      if (!sgr_enc_finishObject(pe)) {
        ...
      }
    
      // Complete the whole file
      if (!sgr_enc_complete(pe)) {
        ...
      }
    
      // Release the encoder instance before returning
      sgr_enc_free(pe);
    }
    
## Description

Each new Scavenger file to encode is represented by an instance of the `SGR_ENC` structure.  Use `sgr_enc_new()` to construct a new instance.  You will need to provide the path to the new file, the primary signature to write into the file, and the secondary signature to write.

Once you get a new instance from `sgr_enc_new()`, you should ensure that each new instance is eventually freed with the function `sgr_enc_free()`, or else there may be resource leaks.  All open resources will also be closed automatically at the end of the program.

To write binary objects into the new Scavenger file, you begin with a call to `sgr_enc_beginObject()`.  This positions the file pointer at the end of the file.  You use `sgr_enc_handle()` to get a `FILE *` handle and then use regular `<stdio.h>` functions to write the binary object at the end of the file.  When finished, you use `sgr_enc_finishObject()`.

After you have written all files, use `sgr_enc_complete()` to finish up the whole file.  If you do not call this completion function, the Scavenger file will be left in an incomplete and invalid state.

Undefined behavior occurs if the Scavenger file is modified by another process while an encoder is opened on it.

## Compilation

This module requires Scavenger Core during compilation.  See `scavenger_core.md` for further information about how to configure Scavenger Core to compile correctly.
