#!/usr/bin/env perl
use strict;
use warnings;

# Scavenger imports
use Scavenger::Decode;

=head1 NAME

scavenger_get.pl - Extract a binary object from an existing Scavenger
file using the decoder module.

=head1 SYNOPSIS

  ./scavenger_get.pl file.scavenger 3 extract.bin

=head1 DESCRIPTION

This script decodes an existing Scavenger file and extracts one of the
binary objects to an external file.

The first parameter is the path to an existing Scavenger file, the
second parameter is the object index to retrieve, and the third
parameter is the path to the file to write with the extracted binary
object.

=cut

# =========
# Constants
# =========

# Maximum number of bytes to transfer at a time from Scavenger file into
# the output file.
#
my $TRANSFER_LENGTH = 16384;

# ==================
# Program entrypoint
# ==================

# Check that we got three arguments
#
($#ARGV == 2) or die "Expecting three program arguments, stopped";

# Get the program arguments
#
my $file_path   = $ARGV[0];
my $obj_index   = $ARGV[1];
my $target_path = $ARGV[2];

# Decode the index
#
($obj_index =~ /\A1?[0-9]{1,15}\z/) or
  die "Can't parse object index, stopped";
$obj_index = int($obj_index);

# Load the Scavenger file
#
my $dec = Scavenger::Decode->load($file_path);

# Check that index is in range
#
(($obj_index >= 0) and ($obj_index < $dec->count)) or
  die sprintf("Object index out of range, maximum is %d, stopped",
        ($dec->count - 1));

# Get the full size of the object
#
my $full_size = $dec->measure($obj_index);

# Open output file
#
open(my $fh, "> :raw", $target_path) or
  die "Failed to open '$target_path' for output, stopped";

# Keep transferring while data remains
#
my $remaining = $full_size;
my $offs = 0;

while ($remaining > 0) {
  # Copy length is minimum of remaining bytes and transfer length
  my $copy_len = $remaining;
  if ($copy_len > $TRANSFER_LENGTH) {
    $copy_len = $TRANSFER_LENGTH;
  }

  # Read from Scavenger file into buffer
  my $buf = $dec->readBinary($obj_index, $offs, $copy_len);
  
  # Write to output file
  print { $fh } $buf or die "I/O error, stopped";

  # Increase offset by copy length and decrease remaining by it
  $offs = $offs + $copy_len;
  $remaining = $remaining - $copy_len;
}

# Close output file
#
close($fh) or warn "Failed to close file, warned";

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
