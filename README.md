# Scavenger

Scavenger is a minimalist binary archive format that can handle up to 256 TiB of binary data with less than 32 bytes of fixed overhead and only 12 bytes of overhead per binary object.

## Codecs

This project provides codecs for the Scavenger format in the following languages:

- Perl (read/write)
- C (read/write)
- JavaScript (read-only)

See the documentation in the specific subdirectories for further information.

## Binary format

A Scavenger binary file has the following format:

1. Header
2. Binary objects
3. Trailer

All integers in Scavenger are _unsigned,_ meaning they only store values that are zero or greater and they have no sign bit.

All multibyte integers in Scavenger are always _big endian_, meaning that the most significant byte is stored first and the least significant byte is stored last.

### Split integers

Scavenger makes use of _split integers_, which are 48-bit unsigned integers that are split into a _low part_ and a _high part_.  The _low part_ is a 32-bit integer that stores the 32 least significant bits of the value.  The _high part_ is a 16-bit integer that stores the 16 most significant bits of the value.

48-bit integers have the useful property that they can be exactly represented with IEEE double-precision floating-point numbers, which have an exact integer range of 53 bits.  This is important for JavaScript and Perl, which may not have 64-bit integers, but may instead use double-precision floating-point.

48-bit integers also offer an enhanced range of up to 256 TiB.  By contrast, 32-bit integers have a maximum range of 4 GiB, which can easily be exceeded by modern multimedia.

### Header

The header is always exactly 16 bytes.  It has the following format:

1. Primary signature (32-bit integer)
2. Secondary signature (6 bytes)
3. File size low part (32-bit integer)
4. File size high part (16-bit integer)

The file size is a split integer that stores the total number of bytes in the Scavenger file, including the header and the trailer.

The primary signature and secondary signature determine the specific kind of data stored in the Scavenger file.  Specific implementations of Scavenger will define the primary and secondary signatures that they use as constants that must match exactly.

The primary signature is intended to be specific to one particular developer or organization defining Scavenger formats.  It should contain some non-ASCII, non-UTF-8 byte values so that the Scavenger file isn't accidentally interpreted as a text file.

The secondary signature identifies one specific Scavenger format designed by the developer identified by the primary signature.  Together, the primary and secondary signatures uniquely identify the kind of structure the Scavenger format has.

### Binary objects

Binary objects are the raw binary blobs which store the binary resources in the Scavenger file.  Each binary object must have at least one byte.  The only restriction on the total number of binary objects and the size of binary objects is that the total size of the Scavenger file when the header and trailer are added must be at most one byte less than 256 TiB.

Binary objects do not have any sort of header and do not need to be aligned in any sort of way.  They can just be stored one right after another.

However, due to the way binary objects are indexed in the trailer (see later), binary objects can be stored in other ways.  It is possible to align the start of binary objects according to some criteria, or to have multiple binary objects map to the same byte range in the file.  It's also possible for binary objects to have overlapping byte ranges, or even for binary objects to include parts of the header or trailer within their ranges.

The standard Scavenger decoders provided by this library can handle all of these various cases.  However, the standard Scavenger encoder will just encode each binary object one after the other.  You would need to design a special Scavenger encoder to handle the special cases noted above.

The specific format of data stored in binary objects is not defined by the Scavenger specification.  Specific implementations of Scavenger can define exactly how to interpret the contents of various binary objects.

### Trailer

The Scavenger trailer has the following structure:

1. Padding to 4-byte boundary
2. Object index
3. Count of objects, low part (32-bit integer)
4. Count of objects, high part (16-bit integer)

The padding is zero to three bytes long, with bytes of any value.  The length of padding is such that the file offset of the object index is divisible by four, when the first byte of the file is file offset zero.

The count of objects determines the total number of objects defined in the object index.  Each object requires 12 bytes in the index.  The count must be such that the total length of the trailer added to the 16 bytes of the header must not exceed the total length in bytes of the whole Scavenger file.

Each record in the object index has the following format:

1. Offset of object, low part (32-bit integer)
2. Size of object, low part (32-bit integer)
3. Offset of object, high part (16-bit integer)
4. Size of object, high part (16-bit integer)

The offset of object determines the file offset of the first byte of the binary object, where file offset zero is the first byte of the file.  The size of the object determines the total size in bytes of the binary object.

Valid object index records must have a size that is greater than zero.  If the size of an object index record is set to zero, that record is invalid.  Invalid records are allowed, but any attempt to access that particular object will result in an error.

Each valid object index record must indicate a byte range that exists within the boundaries of the Scavenger file.  The byte range is allowed to overlap the byte ranges of other objects and it can also overlap the header and the trailer.  As explained earlier, the standard Scavenger decoder can handle these cases, but the standard Scavenger encoder will never generate these cases.

It is possible for the count of objects to be zero, in which case there are no records in the object index.

By convention, the first record in the object index represents object #0, the second record in the object index represents object #1, and so forth.
