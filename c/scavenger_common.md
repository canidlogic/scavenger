# Scavenger Common Documentation

This documentation file includes documentation that is common to both the encoder and decoder modules.

For the specifics of how to encode and decode Scavenger files with this library, see the separate documentation files `scavenger_encoder.md` and `scavenger_decoder.md`.

## Description

Both the encoder and decoder modules work by constructing instances of special structures using constructor functions.  These object instances should eventually be freed by using the appropriate destructor function, or otherwise resource leaks occur.  However, all resources consumed by object instances will be automatically freed at the end of the program.  The specific names of each of these concepts for the encoder module and decoder module are given here:

       Feature   |       Encoder name       |       Decoder name
    =============+==========================+==========================
     Structure   | SCAVENGER_ENCODER        | SCAVENGER_DECODER
     Constructor | scavenger_encoder_new()  | scavenger_decoder_new()
     Destructor  | scavenger_encoder_free() | scavenger_decoder_free()

Multithreaded use of Scavenger encoders and decoders is acceptable, so long as no individual structure instance is used simultaneously by more than one thread.  It is up to the client to ensure this synchronization happens.

## Error handling

Constructors always return a new object instance, even if an error occurred, except in the sole case that memory allocation for the new structure failed.  Destructors never fail and therefore have no error return condition.  All other functions indicate by their return value whether or not the function succeeded.

Object instances have the concept of an error state.  If the constructor fails, the returned object instance will be in error state.  Certain other functions may put the object instance into error state in case of failure, though not all failures cause the object instance to enter error state.

You can check whether an object instance is in error state by using the appropriate error function.  You can also get a textual error message by using the appropriate error message function.  Both the error function and error message function accept `NULL` pointers, assuming in that case that this is the return from a constructor that failed due to a memory allocation error.

Certain failures do not qualify as full errors.  For example, if the destructor fails to close the file handle, this does not count as an error because destructors never return errors, and it is possible to ignore such a failure.  By default, these failures will be silent.  If you wish to receive a warning message on standard error, you can use the warnings function to set the warnings state.  However, this will set a static variable, so if you are multithreading, you should call this at the beginning of the program before you have created any new threads.

The specific names of the error, error message, and warning functions for the encoder and decoder module are given here:

       Function    |        Encoder name        |        Decoder name
    ===============+============================+============================
     Error         | scavenger_encoder_error()  | scavenger_decoder_error()
     Error message | scavenger_encoder_errmsg() | scavenger_decoder_errmsg()
     Warning       | scavenger_encoder_warn()   | scavenger_decoder_warn()

