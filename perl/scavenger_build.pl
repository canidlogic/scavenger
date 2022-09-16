#!/usr/bin/env perl
use strict;
use warnings;

# Scavenger imports
use Scavenger::Encode;

=head1 NAME

scavenger_build.pl - Build a new Scavenger file using the encoder
module.

=head1 SYNOPSIS

  ./scavenger_build.pl file.scavenger 01020304 secsig filelist.txt

=head1 DESCRIPTION

This script builds a Scavenger file using the encoder module.

The first parameter is the file path to the Scavenger file that will be
constructed.  It will be overwritten if it already exists.

The second parameter is the primary signature.  It must be exactly eight
base-16 digits.

The third parameter is the secondary signature.  It must either be
exactly twelve base-16 digits or exactly six US-ASCII characters in
range [0x20, 0x7e].

The fourth parameter is the file list.  This is a UTF-8 text file with
line breaks either as CR+LF or LF.  Each line is either blank (empty or
only whitespace) or it contains a file path, which is trimmed of
trailing whitespace.  The file paths indicate the files that will be
copied into the Scavenger file, in the order they appear in the file
list.  Blank lines are ignored.

=cut

# =========
# Constants
# =========

# Maximum number of bytes to transfer at a time from files into the
# Scavenger file.
#
my $TRANSFER_LENGTH = 16384;

# ==================
# Program entrypoint
# ==================

# Check that we got four arguments
#
($#ARGV == 3) or die "Expecting four program arguments, stopped";

# Get the program arguments
#
my $file_path = $ARGV[0];
my $primary   = $ARGV[1];
my $secondary = $ARGV[2];
my $list_path = $ARGV[3];

# Check signatures
#
($primary =~ /\A[0-9A-Fa-f]{8}\z/) or
  die "Invalid primary signature, stopped";

(($secondary =~ /\A[0-9A-Fa-f]{12}\z/) or
  ($secondary =~ /\A[\x{20}-\x{7e}]{6}\z/)) or
  die "Invalid secondary signature, stopped";

# Check that list file exists
#
(-f $list_path) or die "Can't find file '$list_path', stopped";

# Open the list file for reading
#
open(my $fh, "< :encoding(UTF-8) :crlf", $list_path) or
  die "Failed to open file '$list_path', stopped";

# Start the encoder
#
my $enc = Scavenger::Encode->create($file_path, $primary, $secondary);

# Go through all the lines
#
my $first_line = 1;
while (my $ltext = readline($fh)) {
  # Drop line breaks and trailing whitespace
  chomp $ltext;
  $ltext =~ s/\s+\z//;
  
  # If first line, drop leading UTF-8 BOM if present
  if ($first_line) {
    $first_line = 0;
    $ltext =~ s/\A\x{feff}//;
  }
  
  # Skip line if blank
  if (length($ltext) < 1) {
    next;
  }
  
  # Start a new binary object
  $enc->beginObject;
  
  # Open the data file
  open(my $dh, "< :raw", $ltext) or
    die "Failed to open data file '$ltext', stopped";
  
  # Get the full length of the file
  my (undef, undef, undef, undef, undef, undef, undef, $file_size,
      undef, undef, undef, undef, undef) = stat $dh or
      die "Failed to stat '$ltext', stopped";
  
  # Make sure length is at least one
  ($file_size > 0) or die "File '$ltext' is empty, stopped";
  
  # Keep transferring until everything is gone
  my $buf = '';
  while ($file_size > 0) {
    # Copy length is minimum of remaining file length and the transfer
    # length
    my $copy_len = $file_size;
    if ($copy_len > $TRANSFER_LENGTH) {
      $copy_len = $TRANSFER_LENGTH;
    }
    
    # Read into buffer
    my $retval = read $dh, $buf, $copy_len;
    (defined $retval) or die "I/O error, stopped";
    ($retval == $copy_len) or die "I/O error, stopped";
    
    # Transfer to Scavenger
    $enc->writeBinary($buf);
    
    # Reduce file size by what we copied
    $file_size = $file_size - $copy_len;
  }
  
  # Close the data file
  close($dh) or warn "Failed to close file, warned";
}

# Complete the Scavenger file
#
$enc->complete;

# Close the list file
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
