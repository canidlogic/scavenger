#!/usr/bin/env perl
use strict;
use warnings;

# Scavenger imports
use Scavenger::Decode;

=head1 NAME

scavenger_stat.pl - Print information about a given Scavenger file using
the decoder module.

=head1 SYNOPSIS

  ./scavenger_stat.pl file.scavenger

=head1 DESCRIPTION

This script decodes an existing Scavenger file and tells you the primary
signature, the secondary signature, and the total number of objects.

=cut

# ==================
# Program entrypoint
# ==================

# Check that we got one argument
#
($#ARGV == 0) or die "Expecting one program argument, stopped";

# Get the program arguments
#
my $file_path = $ARGV[0];

# Load the Scavenger file
#
my $dec = Scavenger::Decode->load($file_path);

# Get the signatures
#
my $primary   = $dec->primary;
my $secondary = $dec->secondary;

# Attempt to get an ASCII reading of secondary
#
my $secasc = '';
for(my $i = 0; $i < 6; $i++) {
  my $c = hex(substr($secondary, $i * 2, 2));
  if (($c >= 0x20) and ($c <= 0x7e)) {
    $secasc = $secasc . chr($c);
  } else {
    $secasc = undef;
    last;
  }
}

# Print information
#
print  "Primary signature   : $primary\n";

print  "Secondary signature : $secondary";
if (defined $secasc) {
  print " ($secasc)\n";
} else {
  print "\n";
}

printf "Object count        : %d\n", $dec->count;

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
