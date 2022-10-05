# Scavenger Decoder Module

The decoder module is used to read existing Scavenger files.

See `scavenger_common.md` first for general documentation that applies to both the encoder and decoder modules.

## Sample use

    #include "sgr_dec.h"
    #include <stdio.h>
    
    void example() {
      SGR_DEC  * pd        = NULL;
      FILE     * fp        = NULL;
      uint32_t   primary   = 0;
      uint64_t   secondary = 0;
      int64_t    count     = 0;
      int64_t    part_len  = 0;
      int        test      = 0;
    
      // Create a new decoder instance
      pd = sgr_dec_new("path/to/file.scavenger");
    
      if (sgr_dec_error(pd)) {
        fprintf(stderr, "Error: %s\n", sgr_dec_errmsg(pd));
        sgr_dec_free(pd);
        return;
      }
    
      // Figure out the signatures and object count
      primary   = sgr_dec_primary(pd);
      secondary = sgr_dec_secondary(pd);
      count     = sgr_dec_count(pd);
    
      // Seek to second part and get its length
      part_len = sgr_dec_seek(pd, 1);
      if (part_len < 0) {
        ...
      }
    
      // Get file handle for writing the object
      fp = sgr_dec_handle(pd);
      if (fp == NULL) {
        ...
      }
    
      // File pointer already positioned at part; read with the
      // standard I/O functions
      fscanf(fp, "%d", &test);
    
      // Release the decoder instance before returning
      sgr_dec_free(pd);
    }
    
## Description

Each new Scavenger file to decode is represented by an instance of the `SGR_DEC` structure.  Use `sgr_dec_new()` to construct a new instance.  You will need to provide the path to the existing Scavenger file.

Once you get a new instance from `sgr_dec_new()`, you should ensure that each new instance is eventually freed with the function `sgr_enc_free()`, or else there may be resource leaks.  All open resources will also be closed automatically at the end of the program.

You can query the signatures of the file using `sgr_dec_primary()` and `sgr_dec_secondary()`.  You can get the total number of binary objects in the file using `sgr_dec_count()`.

To read a particular part, use `sgr_dec_seek()`.  This will return the length in bytes of the requested part, and it will also seek the file handle to the start of the part.  You can use `sgr_dec_handle()` to get the file handle, and then read the part using the standard library I/O functions.

Undefined behavior occurs if the Scavenger file is modified by another process while a decoder is opened on it.

## Compilation

This module requires Scavenger Core during compilation.  See `scavenger_core.md` for further information about how to configure Scavenger Core to compile correctly.
