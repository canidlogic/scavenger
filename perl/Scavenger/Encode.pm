package Scavenger::Encode;
use strict;

=head1 NAME

Scavenger::Encode - Encoder class for building Scavenger files.

=head1 SYNOPSIS

  use Scavenger::Encode;
  
  # Create a new file encoder
  my $enc = Scavenger::Encode->create(
                          $file_path,
                          $primary_sig,
                          $secondary_sig);
  
  # Begin writing a binary object
  $enc->beginObject;
  
  # Write binary strings and UTF-8 text to the object
  $enc->writeBinary($binary);
  $enc->writeUTF8($text);
  
  # Complete writing the file
  $enc->complete;

=head1 DESCRIPTION

This encoder module allows Scavenger binary files to be created.  The
module is designed to allow for Scavenger files of up to the maximum
length to be manipulated, including cases where there are huge numbers
of binary objects.  Memory requirements are minimal.

=head1 CONSTRUCTOR

=over 4

=item B<create(file_path, primary_sig, secondary_sig)>

Create a new encoder object.

C<file_path> is the path to the Scavenger binary file that will be
created.  If it already exists, it will be overwritten.

C<primary_sig> is the primary signature of the Scavenger file as a
base-16 string.  It must be a string of exactly eight base-16 digits.

C<secondary_sig> is the secondary signature of the Scavenger file as a
base-16 string.  It must be a string of exactly twelve base-16 digits
I<or> it can be a string of exactly six US-ASCII characters in range
[0x20, 0x7e].

=cut

# @@TODO:

=back

=head1 DESTRUCTOR

If C<complete> has not been called successfully on the object instance,
the destructor will assume the Scavenger binary file is incomplete and
attempt to delete it after cleaning up and closing the file.

If C<complete> has already been called successfully, the destructor does
nothing since the C<complete> function already handled cleaning up and
closing everything.

=cut

# @@TODO:

=head1 INSTANCE METHODS

=over 4

=item B<beginObject()>

Indicate the start of a new binary object.

For each binary object you want to write into the Scavenger file, begin
by calling C<beginObject>, then use the write functions to write all the
data.  There is no need to finish writing an object.  Instead, just call
C<beginObject> again to begin the next object, or call C<complete> after
you have finished writing the last object.

You must call C<beginObject> before any writing functions can be used.
A fatal error occurs if C<beginObject> is called after C<complete> or if
it is called when the encoder object is in an error state.

Each object must have at least one byte of data written to it.

=cut

# @@TODO:

=item B<beginObject()>

Indicate the start of a new binary object.

For each binary object you want to write into the Scavenger file, begin
by calling C<beginObject>, then use the write functions to write all the
data.  There is no need to finish writing an object.  Instead, just call
C<beginObject> again to begin the next object, or call C<complete> after
you have finished writing the last object.

You must call C<beginObject> before any writing functions can be used.
A fatal error occurs if C<beginObject> is called after C<complete> or if
it is called when the encoder object is in an error state.

The first call to C<beginObject> will begin object #0, the second call
will begin object #1, and so forth.

Each object must have at least one byte of data written to it.

=cut

# @@TODO:

=item B<writeBinary(binary)>

Append a binary string to the current binary object.

You may only use this function after you have called C<beginObject>.  A
fatal error occurs if you call this function after C<complete> or if you
call this function when the encoder is in an error state.

The contents of each binary object are defined by a sequence of write
calls.  The data passed to each write call is appended to end of the
current write call.  You may intermix the different write calls within
the same object.

The passed string may only include unsigned byte values in range 0-255.
If you pass an empty string, no data is written.

=cut

# @@TODO:

=item B<writeText(string)>

Append UTF-8 encoded text to the current binary object.

You may only use this function after you have called C<beginObject>.  A
fatal error occurs if you call this function after C<complete> or if you
call this function when the encoder is in an error state.

The contents of each binary object are defined by a sequence of write
calls.  The data passed to each write call is appended to end of the
current write call.  You may intermix the different write calls within
the same object.

The passed string may only include Unicode codepoints in range [U+0000,
U+10FFFF], excluding surrogates in range [U+D800, U+DFFF].  If you pass
an empty string, no data is written.

=cut

# @@TODO:

=item B<complete>

Finish writing the Scavenger file.

If C<beginObject> was ever called on this instance, at least one byte
must have been written with a write function since the most recent call
to C<beginObject> or an fatal error occurs.  It is also a fatal error to
call C<complete> more than once on a single object instance or to call
it when the object is in an error state.

You must call C<complete> or otherwise the destructor will assume the
Scavenger file is incomplete and delete it.

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
