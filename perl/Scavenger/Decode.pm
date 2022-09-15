package Scavenger::Decode;
use strict;

=head1 NAME

Scavenger::Decode - Decoder class for parsing Scavenger files.

=head1 SYNOPSIS

  use Scavenger::Decode;
  
  # Load a Scavenger file
  my $dec = Scavenger::Decode->load($file_path);
  
  # Get the signatures in base-16
  my $primary_base16 = $dec->primary;
  my $secondary_base16 = $dec->secondary;
  
  # Check whether the signatures match given signatures
  if ($dec->matches($primary, $secondary)) {
    ...
  }
  
  # Get the total number of objects
  my $count = $dec->count;
  
  # Measure the size of a particular object
  my $byte_length = $dec->measure(0);
  
  # Read a whole object as binary into memory
  my $binary = $dec->readFullBinary(1);
  
  # Read a whole object as UTF-8 text into memory
  my $string = $dec->readFullUTF8(2);
  
  # Read part of an object as binary into memory
  my $binary = $dec->readBinary(3, 1024, 4096);
  
  # Read part of an object as UTF-8 text into memory
  my $string = $dec->readUTF8(4, 0, 256);

=head1 DESCRIPTION

This decoder module allows Scavenger binary files to be parsed and read.
The module is designed to allow for Scavenger files of up to the maximum
length to be manipulated, including cases where there are huge numbers
of binary objects.  Memory requirements are minimal.

=head1 CONSTRUCTOR

=over 4

=item B<load(file_path)>

Create a new decoder object.

C<file_path> is the path to the Scavenger binary file that will be
parsed and read.

This constructor will open and parse the basic structure of the file,
with fatal errors occurring if this can not be completed successfully.
A read-only file handle will be kept open to the file while the object
is active.  Undefined behavior occurs if the underlying file is modified
after construction while the decoder object is still in use.

If the Scavenger file is 2GB or more, you will probably get some kind of
error or bad behavior unless Perl has been compiled with large file
support.  You also have some risk of bad behavior unless Perl is
compiled with 64-bit integers, though it still might work with large
files in this case.

=cut

# @@TODO:

=back

=head1 DESTRUCTOR

Closes the file handle to the Scavenger binary file.

=cut

# @@TODO:

=head1 INSTANCE METHODS

=over 4

=item B<primary()>

Return the primary signature of the Scavenger file as a base-16 string
of exactly eight characters.

=cut

# @@TODO:

=item B<secondary()>

Return the secondary signature of the Scavenger file as a base-16 string
of exactly twelve characters.

=cut

# @@TODO:

=item B<matches(primary, secondary)>

Check whether the signatures in the parsed Scavenger file match the
given primary and secondary signatures.  Returns 1 if both match, 0
otherwise.

C<primary> must be a base-16 string of exactly eight characters.

C<secondary> may either be a base-16 string of exactly twelve
characters, or a string of exactly six US-ASCII characters in the range
[0x20, 0x7e].

=cut

# @@TODO:

=item B<count()>

Return the total number of binary objects stored within this Scavenger
file.  The return value is a C<Math::BigInt>.

=cut

# @@TODO:

=item B<measure(i)>

Return the length in bytes of a specific binary object within this
Scavenger file.  The returned value is a C<Math::BigInt>.

C<i> is the index of the object to query for, where zero is the first
object.  C<i> must be greater than or equal to zero and less than the
value returned by C<count>.  C<i> may either be a scalar or a
C<Math::BigInt>.

The return value will always be at least one.  A fatal error occurs if
you query an object that has an invalid object index record, which
includes records with declared length zero.

=cut

# @@TODO:

=item B<readFullBinary(i)>

Read a whole object into memory as a binary string.

C<i> is the index of the object to read, where zero is the first object.
C<i> must be greater than or equal to zero and less than the value
returned by C<count>.  C<i> may either be a scalar or a C<Math::BigInt>.

The requested object must not exceed the size of 1 GiB or a fatal error
will occur.

=cut

# @@TODO:

=item B<readFullUTF8(i)>

Read a whole object into memory as a Unicode string that was encoded in
UTF-8.

C<i> is the index of the object to read, where zero is the first object.
C<i> must be greater than or equal to zero and less than the value
returned by C<count>.  C<i> may either be a scalar or a C<Math::BigInt>.

The requested object must not exceed the size of 1 GiB or a fatal error
will occur.

The returned string will have one character per codepoint.  A fatal
error occurs if there are any decoding problems.

=cut

# @@TODO:

=item B<readBinary(i, offs, len)>

Read part of an object into memory as a binary string.

C<i> is the index of the object to read, where zero is the first object.
C<i> must be greater than or equal to zero and less than the value
returned by C<count>.

C<offs> is the byte offset within the binary object to start reading
from, where zero is the first byte of the binary object.  C<offs> must
be greater than or equal to zero and less than the value returned by
C<measure> for this binary object.

C<len> is the number of bytes to read from the binary object.  C<len>
must be greater than zero and also be such that C<offs> added to C<len>
does not exceed the value returned by C<measure> for this binary object.

Each of the three parameters may either be a scalar or a
C<Math::BigInt>.  Additionally, C<len> may not exceed 1 GiB.

The return value will be a binary string where each character is in
unsigned byte range 0-255.

=cut

# @@TODO:

=item B<readUTF8(i, offs, len)>

Read part of an object into memory as a text string encoded in UTF-8.

Be careful not to split multi-byte UTF-8 encodings at the start or end
of the provided binary range!

C<i> is the index of the object to read, where zero is the first object.
C<i> must be greater than or equal to zero and less than the value
returned by C<count>.

C<offs> is the byte offset within the binary object to start reading
from, where zero is the first byte of the binary object.  C<offs> must
be greater than or equal to zero and less than the value returned by
C<measure> for this binary object.

C<len> is the number of bytes to read from the binary object.  C<len>
must be greater than zero and also be such that C<offs> added to C<len>
does not exceed the value returned by C<measure> for this binary object.

Each of the three parameters may either be a scalar or a
C<Math::BigInt>.  Additionally, C<len> may not exceed 1 GiB.

The return value will be a Unicode string where each character is a
Unicode codepoint.  Fatal errors occur if there is any problem decoding
the UTF-8.

=cut

# @@TODO:

=back

=head1 AUTHOR

Noah Johnson, C<noah.johnson@loupmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 Multimedia Data Technology Inc.

MIT License:

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files
(the "Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut

# End with something that evaluates to true
#
1;
