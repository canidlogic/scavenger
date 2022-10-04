# Scavenger Core Module

The Scavenger Core module is a header that wraps C standard library calls.  It is entirely contained within the `scavenger_core.h` header and has no implementation file.  Both the `scavenger_encoder.c` and `scavenger_decoder.c` modules import this header to wrap their standard library calls.  This header is only required when compiling the library modules.  Client programs should not make direct use of this header, and the header does not need to be distributed to Scavenger library clients.

When compiling the Scavenger library, you must ensure that the proper macros are defined for `scavenger_core.h` so that the Scavenger library is compiled with the appropriate C standard library calls for the specific platform.

The following subsections provide notes about what needs to be configured for this module to compile correctly on the target platform.  Note that all the macros mentioned in the following sections are only relevant when compiling `scavenger_encoder.c` and `scavenger_decoder.c` (which both import `scavenger_core.h`).  Client programs do not have to worry about any of these macros, unless they are directly compiling `scavenger_encoder.c` and `scavenger_decoder.c`.

## File seeking

The Scavenger Core header provides `scavenger_seek()` and `scavenger_fsize()` functions as replacements for the classic C standard library `fseek()` and `ftell()` functions.  `scavenger_seek()` seeks a given file handle to a specific 64-bit file offset from the beginning of the file, while `scavenger_fsize()` seeks to the end of a file and returns the current file size in bytes as a 64-bit value.  There is also a `scavenger_bigfiles()` function that returns whether files greater than 2 GiB are supported on this particular platform.

The classic C library `fseek()` and `ftell()` functions use a `long` to represent file offsets.  On most platforms, a `long` is a signed 32-bit integer, which means that file offsets using the classic C library functions do not properly support files that are more than 2 GiB in length.  Scavenger files may be up to 256 TiB, so the classic C standard library functions are generally insufficient (except in the unusual case that the `long` data type is 64-bit).

On POSIX platforms, the `fseeko()` and `ftello()` extension functions are present, which use a special `off_t` data type to represent file offsets.  The size of this `off_t` data type can be configured for large file support.  The common setup is that `off_t` is 32-bit by default (meaning only files up to 2 GiB are supported), but if `_FILE_OFFSET_BITS` is defined to a value of 64, the `off_t` type is changed to 64-bit.  However, certain POSIX platforms might use a different method of configuring `off_t` size, or might just always use 64-bit size for `off_t`.

On Windows, Microsoft's C runtime does not support `fseeko()` and `ftello()`.  Instead, Microsoft's C runtime has Microsoft-specific functions `_fseeki64()` and `_ftelli64()`, which accept 64-bit integers for file offsets.

The following table summarizes the different file offset data types and seek and tell function names:

     Feature | Classic C |  POSIX   |  Microsoft
    =========+===========+==========+=============
      Type   |  long     | off_t    | __int64
      Seek   |  fseek()  | fseeko() | _fseeki64()
      Tell   |  ftell()  | ftello() | _ftelli64()

If Scavenger Core is compiled with `_WIN32` or `SCAVENGER_WINSEEK` then the Microsoft-specific functions will be used.  `_WIN32` is automatically defined by Microsoft C++ compilers on both 32-bit and 64-bit Windows platforms, so the Microsoft-specific functions will be automatically used when compiled by Microsoft C++ compilers, unless `SCAVENGER_CSEEK` or `SCAVENGER_POSIXSEEK` is defined.  `scavenger_bigfiles()` will always return true when using the Microsoft-specific functions.

If Scavenger Core is compiled with `SCAVENGER_CSEEK` then the classic C functions will be used.  In most cases, this means that files greater than 2 GiB in length will not be supported.  However, if the `long` data type is 64-bit or greater, then large files will be supported in this case.  `scavenger_bigfiles()` will check the size of `long` and return either true or false in this case (probably false).

In all other cases, the POSIX extension functions will be used.  If you are compiling on the Windows platform with a compiler that supports the POSIX extension functions, you can define `SCAVENGER_POSIXSEEK` to force the POSIX functions to be used, even if `_WIN32` is defined.

When POSIX extension functions are used, Scavenger Core will undefine `_FILE_OFFSET_BITS` if defined and then define it to a value of 64 so that 64-bit offsets are available.  If there is some other method for changing `off_t` to 64-bit on your platform, you should do that manually when compiling the Scavenger library.  `scavenger_bigfiles()` function will do a runtime check on `off_t` to determine whether it is really 64-bit or greater (it usually should be).

You may specify exactly one of `SCAVENGER_WINSEEK`, `SCAVENGER_CSEEK`, or `SCAVENGER_POSIXSEEK`.  If you specify none, then Microsoft-specific functions will be used if `_WIN32` is defined (as it automatically is by Microsoft compilers), or else POSIX extension functions will be used.  If you are on a POSIX platform that uses something other than `_FILE_OFFSET_BITS` to enable large file support, do whatever is necessary while compiling.

## Unicode file paths

On the Windows platform, there is a low-level API difference between opening a file with a file path that uses 8-bit characters and opening a file with a file path that uses 16-bit wide characters.  16-bit wide characters can open any file path, but 8-bit characters may not be able to represent certain file paths with Unicode characters.  (This distinction does not exist on non-Windows platforms, which always use 8-bit characters in file paths.)

The classic C function `fopen()` uses 8-bit characters for file paths.  In the Microsoft C runtime, this classic C function is therefore not able to open certain Unicode file paths.  Instead, the Microsoft-specific function `_wfopen()` must be used, which accepts the file path with 16-bit wide characters.  By contrast, non-Windows platforms always just use `fopen()` and have no equivalent wide-character function.

Non-Microsoft C compilers on the Windows platform might handle the situation differently.  It is possible, for example, that they could extend the classic `fopen()` function to accept UTF-8 file paths and then behind the scenes decode that into wide characters to allow for full Unicode support.

Scavenger Core defines the `scavenger_fopen()` function as a wrapper around whatever is the appropriate file open function for the platform.  `scavenger_fopen()` always uses 8-bit file paths in its public interface.  Usually, `scavenger_fopen()` just calls directly through to the `fopen()` function.

There are only two situations in which `scavenger_fopen()` does not call through to `fopen()`.  The first situation is when `_WIN32` is defined as well as either `UNICODE` or `_UNICODE` (or both).  The second situation is when `SCAVENGER_OPEN16` is defined.  (Both situations may also occur simultaneously.)  `_WIN32` is automatically defined by Microsoft compilers on Windows platforms, `UNICODE` is defined during compilation to indicate wide-character Windows API functions are in use, and `_UNICODE` is defined during compilation to indicate that wide character versions are in use for `TCHAR`.  The Scavenger library is not actually directly affected by `UNICODE` or `_UNICODE` declarations, but it will interpret their presence to mean it should use the wide-character open function.  If you want to force `fopen()` even when `UNICODE` or `_UNICODE` is defined, define `SCAVENGER_OPEN8` during compilation.

When `scavenger_fopen()` uses the wide-character open function, it will convert the path parameter from UTF-8 into wide characters before passing it through, using the `MultiByteToWideChar` Windows API function.  Client code can use the `WideCharToMultiByte` Windows API function to convert wide character strings into UTF-8 which can then be passed to the Scavenger constructors.

You may specify exactly one of `SCAVENGER_OPEN16` or `SCAVENGER_OPEN8`.  If you specify neither, then `SCAVENGER_OPEN16` will be assumed if `_WIN32` is defined _and_ either `UNICODE` or `_UNICODE` (or both).  Otherwise, `SCAVENGER_OPEN8` is assumed.

## Secure functions

Microsoft provides secure extension functions to replace classic C API functions that involve memory buffers.  These secure extension functions generally require the lengths of the affected buffers to be explicitly indicated, to prevent buffer overrun vulnerabilities.  Recent versions of Microsoft C++ compilers will refuse to compile if the "insecure" classic C functions are used instead of their secure alternatives.

Scavenger Core will use the secure extension functions if `_MSC_VER` is defined.  Microsoft C/C++ compilers always automatically define this macro.  If you want to force use of the secure functions, compile with `SCAVENGER_WINSEC`.  If you want to force use of the classic "insecure" functions, compile with `SCAVENGER_NOSEC`.

An alternative solution to the Microsoft compiler errors is to define `SCAVENGER_NOSEC` to use the classic C functions and then define `_CRT_SECURE_NO_WARNINGS` while compiling, to allow for the use of the classic C functions without security errors.

You may specify exactly one of `SCAVENGER_WINSEC` or `SCAVENGER_NOSEC`.  If you specify neither, then `SCAVENGER_NOSEC` will be assumed unless `_MSC_VER` is defined, in which case `SCAVENGER_WINSEC` will be assumed.
