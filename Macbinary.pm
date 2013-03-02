# Mac::Macbinary, updated by Jeremiah Morris because of horrible bugs

package Mac::Macbinary;

use strict;
use vars qw($VERSION $AUTOLOAD);
$VERSION = 0.07;

use Carp ();

sub new {
    my($class, $thingy, $attr) = @_;
    my $self = bless {
	validate => $attr->{validate},
    }, $class;

    my $fh = _make_handle($thingy);
    $self->_parse_handle($fh);
    return $self;
}

sub _parse_handle {
    my $self = shift;
    my($fh) = @_;

    read $fh, my ($header), 128;
    $self->{header} = Mac::Macbinary::Header->new($header, {
	validate => $self->{validate},
    });
    read $fh, $self->{data}, $self->header->dflen;

    my $resourceoffset = 128 - (($self->header->dflen) % 128);
    # don't eat a chunk if we came out equal (say, when there's no data fork)
    $resourceoffset = 0 if $resourceoffset == 128;
    read $fh, my($tmp), $resourceoffset;
    read $fh, $self->{resource}, $self->header->rflen;

    return $self;
}

sub _make_handle($) {
    my $thingy = shift;

    if (! ref($thingy) && -f $thingy) {
	require FileHandle;
	my $fh = FileHandle->new($thingy) or Carp::croak "$thingy: $!";
	return $fh;
    } else {
	# tries to read it
	eval {
	    read $thingy, my($tmp), 0;
	};
	if ($@) {
	  Carp::croak "Can't read $thingy!";
	}
	return $thingy;
    }
}	

sub AUTOLOAD {
    my $self = shift;
    $AUTOLOAD =~ s/.*://o;
    return $self->{$AUTOLOAD};
}


package Mac::Macbinary::Header;

use vars qw($AUTOLOAD);

sub new {
    my($class, $h, $attr) = @_;
    my $self = bless { }, $class;
    if ($attr->{validate}) {
	$self->_validate_header($h)
	    or Carp::croak "Macbinary validation failed.";
    }
    $self->_parse_header($h);
    return $self;
}

sub _validate_header {
    my $self = shift;
    my($h) = @_;

    #  stolen from Mac::Conversions
    #
    #  Use a crude heuristic to decide whether or not a file is MacBinary.  The
    #  first byte of any MacBinary file must be zero.  The second has to be
    #  <= 63 according to the MacBinary II standard.  The 122nd and 123rd
    #  each have to be >= 129.  This has about a 1/8000 chance of failing on
    #  random bytes.  This seems to be all that mcvert does.  Unfortunately
    #  we can't also check the checksum because the standard software (Stuffit
    #  Deluxe, etc.) doesn't seem to checksum.
    
    my($zero,
       $namelength,
       $filename,
       $type,
       $creator,
       $highflag,
       $dum1,
       $dum2,
       $dum3,
       $datalength,
       $reslength,
       $dum4,
       $dum5,
       $dum6,
       $lowflag,
       $dum7,
       $dum8,
       $version_this,
       $version_needed,
       $crc) = unpack("CCA63a4a4CxNnCxNNNNnCx14NnCCN", $h);

    return (!$zero && (($namelength - 1)< 63)
	    && $version_this >= 129 && $version_needed >= 129);
}

sub _parse_header {
    my $self = shift;
    my($h) = @_;

    my $namelen = unpack("C", substr($h, 1, 1));
    $self->{name}	= substr(unpack("a*", substr($h, 2, 63)), 0, $namelen);
    $self->{type}	= unpack("a*", substr($h, 65, 4));
    $self->{creator}	= unpack("a*", substr($h, 69, 4));
    $self->{flags}	= unpack("C", substr($h, 73, 1));
#     $self->{location}	= unpack("C", substr($h, 80, 6));  # oh, come on...
    $self->{dflen}	= unpack("N", substr($h, 83, 4));
    $self->{rflen}	= unpack("N", substr($h, 87, 4));
    $self->{cdate}	= unpack("N", substr($h, 91, 4));
    $self->{mdate}	= unpack("N", substr($h, 95, 4));

    return $self;
}


sub AUTOLOAD {
    my $self = shift;
    $AUTOLOAD =~ s/.*://o;
    return $self->{$AUTOLOAD};
}

1;
__END__

=head1 NAME

Mac::Macbinary - Decodes Macbinary files

=head1 SYNOPSIS

  use Mac::Macbinary;

  $mb = Mac::Macbinary->new(\*FH);	# filehandle
  $mb = Mac::Macbinary->new($fh);	# IO::* instance
  $mb = Mac::Macbinary->new("/path/to/file");

  # do validation
  eval {
      $mb = Mac::Macbinary->new("/path/to/file", { validate => 1 });
  };

  $header = $mb->header;		# Mac::Macbinary::Header instance
  $name = $header->name;
  

=head1 DESCRIPTION

This module provides an object-oriented way to extract various kinds
of information from Macintosh Macbinary files.

=head1 METHODS

Following methods are available.

=head2 Class method

=over 4

=item new( THINGY, [ \%attr ] )

Constructor of Mac::Macbinary. Accepts filhandle GLOB reference,
FileHandle instance, IO::* instance, or whatever objects that can do
C<read> methods.

If the argument belongs none of those above, C<new()> treats it as a
path to file. Any of following examples are valid constructors.

  open FH, "path/to/file";
  $mb = Mac::Macbinary->new(\*FH);

  $fh = FileHandle->new("path/to/file");
  $mb = Mac::Macbinary->new($fh);

  $io = IO::File->new("path/to/file");
  $mb = Mac::Macbinary->new($io);

  $mb = Mac::Macbinary->new("path/to/file");

C<new()> throws an exception "Can't read blahblah" if the given
argument to the constructor is neither a valid filehandle nor an
existing file.

The optional L<\%attr> parameter can be used for validation of file
format.  You can check and see if a file is really a Macbinary or not
by setting "validate" attribute to 1.

  $fh = FileHandle->new("path/to/file");
  eval {
      $mb = Mac::Macbinary->new(FileHandle->new($fh), { 
           validate => 1,
      });
  };
  if ($@) {
      warn "file is not a Macbinary.";
  }

=back

=head2 Instance Method

=over 4

=item data

returns the data range of original file.

=item header

returns the header object (instance of Mac::Macbinary::Header).

=back

Following accessors are available via Mac::Macbinary::Header instance.

=over 4

=item name, type, creator, flags, location, dflen, rflen, cdate, mdate

returns the original entry in the header of Macbinary file.
Below is a structure of the info file, taken from MacBin.C

  char zero1;
  char nlen;
  char name[63];
  char type[4];           65      0101
  char creator[4];        69
  char flags;             73
  char zero2;             74      0112
  char location[6];       80
  char protected;         81      0121
  char zero3;             82      0122
  char dflen[4];
  char rflen[4];
  char cdate[4];
  char mdate[4];

=back

=head1 EXAMPLE

Some versions of MSIE for Macintosh sends their local files as
Macbinary format via forms. You can decode them in a following way:

  use CGI;
  use Mac::Macbinary;

  $q = new CGI;
  $filename = $q->param('uploaded_file');
  $type = $q->uploadInfo($filename)->{'Content-Type'};
 
  if ($type eq 'application/x-macbinary') {
      $mb = Mac::Macbinary->new($q->upload('uploaded_file'));
      # now, you can get data via $mb->data;
  } 

=head1 COPYRIGHT

Copyright 2000 Tatsuhiko Miyagawa <miyagawa@bulknews.net>

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 ACKNOWLEDGEMENT

Macbinary.pm is originally written by Dan Kogai <dankogai@dan.co.jp>.

There are also C<Mac::Conversions> and C<Convert::BinHex>, working
kind similar to this module. (However, C<Mac::Conversions> works only
on MacPerl, and C<Convert::BinHex> is now deprecated.) Many thanks to
Paul J. Schinder and Eryq, authors of those ones.

Macbinary validation is almost a replication of B<is_macbinary> in
Mac::Conversions.

=head1 SEE ALSO

perl(1), L<Mac::Conversions>, L<Convert::BinHex>.

=cut


