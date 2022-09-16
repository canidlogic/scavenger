package Scavenger::Decode;
use strict;

# Core modules
use Encode qw(decode);
use Math::BigInt;

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

If you are reading a Scavenger file of length 2 GiB or more, your Perl
must be compiled with large file support.  64-bit integer support is
I<not> actually required, since Perl can use double-precision floating
point to represent Scavenger's 48-bit integers.

=cut

# ===============
# Local functions
# ===============

# _binaryToHex(bin)
# -----------------
#
# Given a binary string, convert it to a base-16 string and return the
# base16 string.  The string will be in lowercase.
#
sub _binaryToHex {
  # Get parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # Check string format
  (length($str) > 0) or die "Empty string not allowed, stopped";
  ($str =~ /\A[\x{0}-\x{ff}]+\z/) or
    die "String must be binary string, stopped";
  
  # Result string starts empty
  my $result = '';
  
  # Decode each byte
  for my $c (split //, $str) {
    $result = $result . sprintf('%02x', ord($c));
  }
  
  # Return result
  return $result;
}

# _joinInteger(low, high)
# -----------------------
#
# Join the low and high components of a split integer back into a single
# numeric scalar value.
#
sub _joinInteger {
  # Get parameters
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  my $low  = shift;
  my $high = shift;
  
  (not ref($low)) or die "Wrong parameter type, stopped";
  $low = int($low);
  (($low >= 0) and ($low <= 0xffffffff)) or
    die "Low component out of range, stopped";
  
  (not ref($high)) or die "Wrong parameter type, stopped";
  (($high >= 0) and ($high <= 0xffff)) or
    die "High component out of range, stopped";
  
  # Use a BigInt because bitwise operations force integer types
  my $low  = Math::BigInt->new($low);
  my $high = Math::BigInt->new($high);
  
  # Shift high into place
  $high->blsft(32);
  
  # Add in the low bits
  $high->bior($low);
  
  # Now return the scalar value
  return $high->numify;
}

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

=cut

sub load {
  
  # Check parameter count
  ($#_ == 1) or die "Wrong number of parameters, stopped";
  
  # Get invocant and parameters
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  
  my $file_path = shift;
  (not ref($file_path)) or die "Wrong parameter type, stopped";
  
  # Define the new object
  my $self = { };
  bless($self, $class);
  
  # Open the file handle for raw binary reading
  open(my $fh, "< :raw", $file_path) or
    die "Failed to open file '$file_path', stopped";
  
  # _fh will store the file handle
  $self->{'_fh'} = $fh;
  
  # _size will store the full size of the file
  my (undef, undef, undef, undef, undef, undef, undef, $file_size,
      undef, undef, undef, undef, undef) = stat $self->{'_fh'} or
      die "Failed to stat file, stopped";
  $self->{'_size'} = $file_size;
  
  # Size must be at least 22 (16 bytes header and six bytes for an
  # object count), at most the 48-bit limit, and the total file size mod
  # 4 must be 2
  ($file_size >= 22) or die "File not large enough, stopped";
  ($file_size <= 0xffffffffffff) or die "File too large, stopped";
  (($file_size % 4) == 2) or die "File not aligned, stopped";
  
  # Attempt to read the 16-byte header
  my $header = '';
  my $retval = read $self->{'_fh'}, $header, 16;
  (defined $retval) or die "I/O error, stopped";
  ($retval == 16) or die "Failed to read header, stopped";
  
  # Unpack the header
  my ($primary, $secondary, $size_low, $size_high) =
    unpack "A4A6L>S>", $header;
  
  # Join the sizes and make sure they match the actual file size
  my $joined_size = _joinInteger($size_low, $size_high);
  ($joined_size == $self->{'_size'}) or
    die "Size in header does not match file size, stopped";
  
  # Pad the signatures with spaces if necessary
  while (length($primary) < 4) {
    $primary = $primary . ' ';
  }
  while (length($secondary) < 6) {
    $secondary = $secondary . ' ';
  }
  
  # _primary and _secondary will store the signatures, converted to
  # base-16
  $self->{'_primary'  } = _binaryToHex($primary);
  $self->{'_secondary'} = _binaryToHex($secondary);
  
  # Read the last six bytes of the file to get the object count
  seek $self->{'_fh'}, ($file_size - 6), 0 or die "I/O error, stopped";
  my $trail = '';
  $retval = read $self->{'_fh'}, $trail, 6;
  (defined $retval) or die "I/O error, stopped";
  ($retval == 6) or die "Failed to read object count, stopped";
  
  # Unpack the object count and join it
  my ($count_low, $count_high) = unpack "L>S>", $trail;
  my $obj_count = _joinInteger($count_low, $count_high);
  
  # Compute the maximum number of objects that could be stored in a file
  # of this size based on their index overhead requirements
  my $max_count = int(($self->{'_size'} - 6 - 16) / 12);
  
  # Make sure given object count doesn't exceed capacity
  ($obj_count <= $max_count) or
    die "Recorded object count is too high, stopped";
  
  # _count will store the object count
  $self->{'_count'} = $obj_count;
  
  # _index is the file offset of the start of the index
  $self->{'_index'} = $self->{'_size'} - 6 - ($self->{'_count'} * 12);
  ($self->{'_index'} >= 16) or die "Unexpected";
  
  # Return the new object
  return $self;
}

=back

=head1 DESTRUCTOR

Closes the file handle to the Scavenger binary file.

=cut

sub DESTROY {
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # If _fh defined, close it
  if (defined $self->{'_fh'}) {
    # Close the file handle
    close($self->{'_fh'}) or
      warn "Failed to close file handle, warned";
  }
}

=head1 INSTANCE METHODS

=cut

# ========================
# Local instance functions
# ========================

# _query(i)
# ---------
#
# Read and parse an index record for the object of the given index
# value.  The return value is (offset, size).  The return value has
# already been checked that size is greater than zero and that the given
# range is within the boundaries of the file.
#
sub _query {
  # Get self and parameters
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $i = shift;
  (not ref($i)) or die "Wrong parameter type, stopped";
  $i = int($i);
  
  # Check range of i
  (($i >= 0) and ($i < $self->{'_count'})) or
    die "Object index out of range, stopped";
  
  # Seek to appropriate index record
  my $index_offs = $self->{'_index'} + ($i * 12);
  seek $self->{'_fh'}, $index_offs, 0 or die "I/O error, stopped";
  
  # Read index record
  my $rec = '';
  my $retval = read $self->{'_fh'}, $rec, 12;
  (defined $retval) or die "I/O error, stopped";
  ($retval == 12) or die "I/O error, stopped";
  
  # Parse the index record
  my ($off_low, $size_low, $off_high, $size_high) =
    unpack "L>L>S>S>", $rec;
  
  # Join integers for full values
  my $off  = _joinInteger($off_low, $off_high);
  my $size = _joinInteger($size_low, $size_high);
  
  # Check size and offset individually
  (($size > 0) and ($size <= $self->{'_size'})) or
    die "Invalid index record $i, stopped";
  (($off >= 0) and ($off < $self->{'_size'})) or
    die "Invalid index record $i, stopped";
  
  # Check that indicated range is within file boundaries
  ($size <= $self->{'_size'} - $off) or
    die "Invalid index record $i, stopped";
  
  # Return the record
  return ($off, $size);
}

=over 4

=item B<primary()>

Return the primary signature of the Scavenger file as a base-16 string
of exactly eight characters.

=cut

sub primary {
  # Get self and parameters
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Return result
  return $self->{'_primary'};
}

=item B<secondary()>

Return the secondary signature of the Scavenger file as a base-16 string
of exactly twelve characters.

=cut

sub secondary {
  # Get self and parameters
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Return result
  return $self->{'_secondary'};
}

=item B<matches(primary, secondary)>

Check whether the signatures in the parsed Scavenger file match the
given primary and secondary signatures.  Returns 1 if both match, 0
otherwise.

C<primary> must be a base-16 string of exactly eight characters.

C<secondary> may either be a base-16 string of exactly twelve
characters, or a string of exactly six US-ASCII characters in the range
[0x20, 0x7e].

=cut

sub matches {
  # Get self and parameters
  ($#_ == 2) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $primary   = shift;
  my $secondary = shift;
  
  (not ref($primary  )) or die "Wrong parameter type, stopped";
  (not ref($secondary)) or die "Wrong parameter type, stopped";
  
  # If secondary is a string of six US-ASCII characters, convert it to a
  # base-16 string of twelve characters
  if ($secondary =~ /\A[\x{20}-\x{7e}]{6}\z/) {
    $secondary = _binaryToHex($secondary);
  }
  
  # Check base-16 formats
  ($primary =~ /\A[0-9A-Fa-f]{8}\z/) or
    die "Invalid primary signature, stopped";
  
  ($secondary =~ /\A[0-9A-Fa-f]{12}\z/) or
    die "Invalid secondary signature, stopped";
  
  # Convert to lowercase
  $primary   = lc $primary;
  $secondary = lc $secondary;
  
  # Perform comparison
  my $result;
  if (($primary   eq $self->{'_primary'  }) and
      ($secondary eq $self->{'_secondary'})) {
    $result = 1;
  } else {
    $result = 0;
  }
  
  # Return result
  return $result;
}

=item B<count()>

Return the total number of binary objects stored within this Scavenger
file.  The count of binary objects is cached, so this is a fast call.

=cut

sub count {
  # Get self and parameters
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Return result
  return $self->{'_count'};
}

=item B<measure(i)>

Return the length in bytes of a specific binary object within this
Scavenger file.

C<i> is the index of the object to query for, where zero is the first
object.  C<i> must be greater than or equal to zero and less than the
value returned by C<count>.

The return value will always be at least one.  A fatal error occurs if
you query an object that has an invalid object index record, which
includes records with declared length zero.

This function has to read from the file, so it is not a trivial call.

=cut

sub measure {
  # Get self and parameters
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $i = shift;
  (not ref($i)) or die "Wrong parameter type, stopped";
  $i = int($i);
  
  # Read the index record
  my ($off, $size) = $self->_query($i);
  
  # Return result
  return $size;
}

=item B<readFullBinary(i)>

Read a whole object into memory as a binary string.

C<i> is the index of the object to read, where zero is the first object.
C<i> must be greater than or equal to zero and less than the value
returned by C<count>.

Be careful about reading huge binary objects all into memory at once.

=cut

sub readFullBinary {
  # Get self and parameters
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $i = shift;
  (not ref($i)) or die "Wrong parameter type, stopped";
  $i = int($i);
  
  # Call through
  return $self->readBinary($i, 0, $self->measure($i));
}

=item B<readFullUTF8(i)>

Read a whole object into memory as a Unicode string that was encoded in
UTF-8.

C<i> is the index of the object to read, where zero is the first object.
C<i> must be greater than or equal to zero and less than the value
returned by C<count>.

Be careful about reading huge binary objects all into memory at once.

The returned string will have one character per codepoint.  A fatal
error occurs if there are any decoding problems.

=cut

sub readFullUTF8 {
  # Get self and parameters
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $i = shift;
  (not ref($i)) or die "Wrong parameter type, stopped";
  $i = int($i);
  
  # Call through
  return $self->readUTF8($i, 0, $self->measure($i));
}

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

The return value will be a binary string where each character is in
unsigned byte range 0-255.

=cut

sub readBinary {
  # Get self and parameters
  ($#_ == 3) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $i = shift;
  (not ref($i)) or die "Wrong parameter type, stopped";
  $i = int($i);
  
  my $offs = shift;
  (not ref($offs)) or die "Wrong parameter type, stopped";
  $offs = int($offs);
  
  my $len = shift;
  (not ref($len)) or die "Wrong parameter type, stopped";
  $len = int($len);
  
  # Get index record
  my ($base, $full) = $self->_query($i);
  
  # Check given offset and length by themselves
  (($offs >= 0) and ($offs < $full)) or
    die "Invalid offset, stopped";
  (($len > 0) and ($len <= $full)) or
    die "Invalid length, stopped";
  
  # Check that subrange is within blob boundaries
  ($len <= $full - $offs) or
    die "Invalid subrange, stopped";
  
  # Seek to appropriate position
  my $seek_pos = $base + $offs;
  seek $self->{'_fh'}, $seek_pos, 0 or die "I/O error, stopped";
  
  # Read the binary string
  my $result = '';
  my $retval = read $self->{'_fh'}, $result, $len;
  (defined $retval) or die "I/O error, stopped";
  ($retval == $len) or die "I/O error, stopped";
  
  # Return the binary string
  return $result;
}

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

The return value will be a Unicode string where each character is a
Unicode codepoint.  Fatal errors occur if there is any problem decoding
the UTF-8.

=cut

sub readUTF8 {
  # Get self and parameters
  ($#_ == 3) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $i = shift;
  (not ref($i)) or die "Wrong parameter type, stopped";
  $i = int($i);
  
  my $offs = shift;
  (not ref($offs)) or die "Wrong parameter type, stopped";
  $offs = int($offs);
  
  my $len = shift;
  (not ref($len)) or die "Wrong parameter type, stopped";
  $len = int($len);
  
  # Read as a binary string
  my $result = $self->readBinary($i, $offs, $len);
  
  # Convert in-place to UTF-8
  $result = decode('UTF-8', $result, Encode::FB_CROAK);
  
  # Return decoded result
  return $result;
}

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
