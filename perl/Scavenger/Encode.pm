package Scavenger::Encode;
use strict;

# Core modules
use Encode qw(encode);
use File::Temp;
use Math::BigInt;

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

If you are creating a Scavenger file of length 2 GiB or more, your Perl
must be compiled with large file support.  64-bit integer support is
I<not> actually required, since Perl can use double-precision floating
point to represent Scavenger's 48-bit integers.

=cut

# =========
# Constants
# =========

# The maximum number of bytes to transfer at a time when copying the
# temporary index file into the output file during completion.
#
my $TRANSFER_SIZE = 16384;

# ===============
# Local functions
# ===============

# _hexToBinary(hex)
# -----------------
#
# Given a base-16 string, convert it to a binary string and return the
# binary string.
#
sub _hexToBinary {
  # Get parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  
  # Check string format
  (length($str) > 0) or die "Empty string not allowed, stopped";
  ((length($str) % 2) == 0) or
    die "String must have even number of digits, stopped";
  ($str =~ /\A[0-9a-fA-F]+\z/) or
    die "String contains invalid base-16 digits, stopped";
  
  # Result string starts empty
  my $result = '';
  
  # Decode each pair of base-16 digits
  my $bytes = length($str) / 2;
  for(my $i = 0; $i < $bytes; $i++) {
    my $d = hex(substr($str, $i * 2, 2));
    $result = $result . chr($d);
  }
  
  # Return result
  return $result;
}

# _splitInteger(i)
# ----------------
#
# Split a 48-bit integer value into a 32-bit low part and a 16-bit high
# part.  Returns (low, high) in list context.
#
sub _splitInteger {
  # Get parameter
  ($#_ == 0) or die "Wrong number of parameters, stopped";
  my $i = shift;
  
  (not ref($i)) or die "Wrong parameter type, stopped";
  $i = int($i);
  
  # Verify invoked in list context
  wantarray or die "Must be invoked in list context, stopped";
  
  # Use a BigInt because bitwise operations force integer types
  my $low  = Math::BigInt->new($i);
  my $high = $low->copy;
  
  # Get a mask of 32 bits
  my $mask = Math::BigInt->bone;
  $mask->blsft(32);
  $mask->bdec;
  
  # Low portion masks off the lowest 32 bits
  $low->band($mask);
  
  # High portion shifts right 32 bits
  $high->brsft(32);
  
  # Make sure high portion in unsigned 16-bit range
  ($high->ble(0xffff)) or
    die "Input to split integer is too large, stopped";
  
  # Now return both values as scalars
  return ($low->numify, $high->numify);
}

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

sub create {
  
  # Check parameter count
  ($#_ == 3) or die "Wrong number of parameters, stopped";
  
  # Get invocant and parameters
  my $invocant = shift;
  my $class = ref($invocant) || $invocant;
  
  my $file_path = shift;
  (not ref($file_path)) or die "Wrong parameter type, stopped";
  
  my $primary_sig = shift;
  (not ref($primary_sig)) or die "Wrong parameter type, stopped";
  
  my $secondary_sig = shift;
  (not ref($secondary_sig)) or die "Wrong parameter type, stopped";
  
  ($primary_sig =~ /\A[0-9A-Fa-f]{8}\z/) or
    die "Invalid primary signature, stopped";
  
  (($secondary_sig =~ /\A[0-9A-Fa-f]{12}\z/) or
    ($secondary_sig =~ /\A[\x{20}-\x{7e}]{6}\z/)) or
    die "Invalid secondary signature, stopped";
  
  # Define the new object
  my $self = { };
  bless($self, $class);
  
  # Open the file handle for raw binary writing
  open(my $fh, "> :raw", $file_path) or
    die "Failed to create file '$file_path', stopped";
  
  # _status is normally zero, or 1 if completed successfully, or -1 if
  # in error state
  $self->{'_status'} = 0;
  
  # _fpath will store the file path
  $self->{'_fpath'} = "$file_path";
  
  # _fh will store the file handle
  $self->{'_fh'} = $fh;
  
  # _tf will be the File::Temp temporary file that stores the object
  # index that we are building
  $self->{'_tf'} = File::Temp->new();
  binmode($self->{'_tf'}, ':raw') or die "I/O error, stopped";
  
  # _count is the total number of times beginObject has been called
  $self->{'_count'} = 0;
  
  # _bytes is the total number of bytes that has been written to the
  # output file, EXCLUDING bytes written to currently open object
  $self->{'_bytes'} = 0;
  
  # _local is total number of bytes that has been written to the
  # currently open object
  $self->{'_local'} = 0;
  
  # Convert signatures to binary if necessary
  $primary_sig = _hexToBinary($primary_sig);
  if (length($secondary_sig) > 6) {
    $secondary_sig = _hexToBinary($secondary_sig);
  }
  
  ((length($primary_sig) == 4) and (length($secondary_sig) == 6)) or
    die "Unexpected";
  
  # Write the signatures to the output file, and then a total length
  # field that is set to zero for now
  my $header = pack "a4a6L>S>",
                  $primary_sig,
                  $secondary_sig,
                  0, 0;
  print { $self->{'_fh'} } $header or die "I/O error, stopped";
  
  $self->{'_bytes'} = 16;
  
  # Return the new object
  return $self;
}

=back

=head1 DESTRUCTOR

If C<complete> has not been called successfully on the object instance,
the destructor will assume the Scavenger binary file is incomplete and
attempt to delete it after cleaning up and closing the file.

If C<complete> has already been called successfully, the destructor does
nothing since the C<complete> function already handled cleaning up and
closing everything.

=cut

sub DESTROY {
  # Get self
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Only proceed if _status, _fpath, and _fh defined
  if ((defined $self->{'_status'}) and
      (defined $self->{'_fh'    }) and
      (defined $self->{'_fpath' })) {
    # Proceed unless in completed state
    unless ($self->{'_status'} > 0) {
      # Close the file handle
      close($self->{'_fh'}) or
        warn "Failed to close file handle, warned";
      
      # Delete the file
      (unlink($self->{'_fpath'}) == 1) or
        warn "Failed to delete incomplete file, warned";
    }
  }
}

=head1 INSTANCE METHODS

=cut

# ========================
# Private instance methods
# ========================

# _closeObject()
# --------------
#
# If there is an object currently being defined, close it properly.
# _count will not be affected, but _local will be cleared to zero,
# _bytes will be increased by the previous value of _local, and the
# index record for the previous object will be written to the temporary
# file.
#
# This function does not set error state on fatal error, because it
# assumes the caller will do that.
#
sub _closeObject {
  # Get self and parameters
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check proper state
  ($self->{'_status'} == 0) or die "Wrong object state, stopped";
  
  # Only proceed if an object is open
  if ($self->{'_count'} > 0) {
    # Make sure at least one byte written to previous object
    ($self->{'_local'} > 0) or die "Empty binary object, stopped";
    
    # Create an index record for the previous object
    my ($index_offs_low, $index_offs_high) =
                                    _splitInteger($self->{'_bytes'});
    
    my ($index_size_low, $index_size_high) =
                                    _splitInteger($self->{'_local'});
    
    my $index_rec = pack "L>L>S>S>",
                      $index_offs_low,
                      $index_size_low,
                      $index_offs_high,
                      $index_size_high;
    
    # Write the index record to the temporary file
    print { $self->{'_tf'} } $index_rec or die "I/O error, stopped";
    
    # Increase _bytes by _local and clear _local to zero
    $self->{'_bytes'} = $self->{'_bytes'} + $self->{'_local'};
    $self->{'_local'} = 0;
    
    # Check that byte count hasn't exceeded limit
    ($self->{'_bytes'} <= 0xffffffffffff) or
      die "Output file has grown too large, stopped";
  }
}

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

The first call to C<beginObject> will begin object #0, the second call
will begin object #1, and so forth.

Each object must have at least one byte of data written to it.

=cut

sub beginObject {
  # Get self and parameters
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check for error state
  ($self->{'_status'} >= 0) or die "Object in error state, stopped";
  
  # Wrap whole call in an eval that sets an error state and rethrows if
  # error
  eval {
    # Check proper state
    ($self->{'_status'} == 0) or die "Wrong object state, stopped";
    
    # Close any previous object
    $self->_closeObject;
    
    # Increment the object count
    $self->{'_count'} = $self->{'_count'} + 1;
    
    # Compute the total size of the file when it will be completed with
    # the index
    my $total_size = ($self->{'_count'} * 12) + 6 + $self->{'_bytes'};
    
    # If total size exceeds the limit, error
    ($total_size <= 0xffffffffffff) or
      die "File has grown too large, stopped";
  };
  if ($@) {
    # Set error state and rethrow
    $self->{'_status'} = -1;
    die $@;
  }
}

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

sub writeBinary {
  # Get self and parameters
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $bin = shift;
  (not ref($bin)) or die "Wrong parameter type, stopped";
  ($bin =~ /\A[\x{0}-\x{ff}]*\z/) or
    die "Invalid binary string, stopped";
  
  # Check for error state
  ($self->{'_status'} >= 0) or die "Object in error state, stopped";
  
  # Wrap whole call in an eval that sets an error state and rethrows if
  # error
  eval {
    # Check proper state
    ($self->{'_status'} == 0) or die "Wrong object state, stopped";
    ($self->{'_count'} > 0) or
      die "Can't write until object begun, stopped";
    
    # Increase _local
    $self->{'_local'} = $self->{'_local'} + length($bin);
    
    # Now write the string to the output file
    print { $self->{'_fh'} } $bin or die "I/O error, stopped";
    
  };
  if ($@) {
    # Set error state and rethrow
    $self->{'_status'} = -1;
    die $@;
  }
}

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

sub writeText {
  # Get self and parameters
  ($#_ == 1) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  my $str = shift;
  (not ref($str)) or die "Wrong parameter type, stopped";
  $str = "$str";
  
  # Check string
  ($str =~ /\A[\x{0}-\x{d7ff}\x{e000}-\x{10ffff}]*\z/) or
    die "Invalid string contents, stopped";
  
  # Encode string into a binary UTF-8 string
  my $binary = encode('UTF-8', $str, Encode::FB_CROAK);
  
  # Now call through to writeBinary
  $self->writeBinary($binary);
}

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

sub complete {
  # Get self and parameters
  ($#_ == 0) or die "Wrong parameter count, stopped";
  
  my $self = shift;
  (ref($self) and $self->isa(__PACKAGE__)) or
    die "Wrong parameter type, stopped";
  
  # Check for error state
  ($self->{'_status'} >= 0) or die "Object in error state, stopped";
  
  # Wrap whole call in an eval that sets an error state and rethrows if
  # error
  eval {
    # Check proper state
    ($self->{'_status'} == 0) or die "Wrong object state, stopped";
    
    # Close any previous object
    $self->_closeObject;
    
    # Compute how many bytes of padding are needed
    my $padding = 4 - ($self->{'_bytes'} % 4);
    if ($padding > 3) {
      $padding = 0;
    }
    
    # If at least one byte of padding needed, then write the padding to
    # output and increase the byte count
    if ($padding > 0) {
      my $pad_str;
      if ($padding == 1) {
        $pad_str = ' ';
      
      } elsif ($padding == 2) {
        $pad_str = '  ';
        
      } elsif ($padding == 3) {
        $pad_str = '   ';
        
      } else {
        die "Unexpected";
      }
      print { $self->{'_fh'} } $pad_str or die "I/O error, stopped";
      $self->{'_bytes'} = $self->{'_bytes'} + $padding;
    }
    
    # Compute the total size of the file and make sure it is within
    # range
    my $total_size = ($self->{'_count'} * 12) + 6 + $self->{'_bytes'};
    ($total_size <= 0xffffffffffff) or
      die "File has grown too large, stopped";
    
    # If at least one binary object, then we need to output the
    # temporary file to build the index
    if ($self->{'_count'} > 0) {
      # Compute the total number of bytes to transfer from the temporary
      # file
      my $index_size = $self->{'_count'} * 12;
      
      # Rewind the temporary file
      seek $self->{'_tf'}, 0, 0 or die "I/O error, stopped";
      
      # Keep going while we still have bytes to transfer
      my $buf = '';
      while ($index_size > 0) {
        # The copy size is the minimum of the transfer size and the
        # remaining bytes
        my $copy_size = $index_size;
        if ($TRANSFER_SIZE < $copy_size) {
          $copy_size = $TRANSFER_SIZE;
        }
        
        # Read from the temporary file
        my $retval = read $self->{'_tf'}, $buf, $copy_size;
        (defined $retval) or die "I/O error, stopped";
        ($retval == $copy_size) or die "I/O error, stopped";
        
        # Write to output file
        print { $self->{'_fh'} } $buf or die "I/O error, stopped";
        
        # Decrease index size by the copy size we just transferred
        $index_size = $index_size - $copy_size;
      }
    }
    
    # Split the total object count and write it to the output file
    my ($count_low, $count_high) = _splitInteger($self->{'_count'});
    my $raw_count = pack "L>S>", $count_low, $count_high;
    print { $self->{'_fh'} } $raw_count or die "I/O error, stopped";
    
    # Split the total file size and write it to the appropriate place in
    # the output file header
    my ($size_low, $size_high) = _splitInteger($total_size);
    my $raw_size = pack "L>S>", $size_low, $size_high;
    seek $self->{'_fh'}, 10, 0 or die "I/O error, stopped";
    print { $self->{'_fh'} } $raw_size or die "I/O error, stopped";
    
    # If we got here, set status to completed successfully and close the
    # output file handle
    $self->{'_status'} = 1;
    close($self->{'_fh'}) or warn "Failed to close file handle, warned";
  };
  if ($@) {
    # Set error state and rethrow
    $self->{'_status'} = -1;
    die $@;
  }
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
