# Mac::AppleSingleDouble.pm, (C) 2001 Jamie Flournoy (jamie@white-mountain.org).
# Converted for Lion's broken little-endian files by Jeremiah Morris (hopper@whpress.com).

package Mac::LittleSingleDouble;
require 5;
use FileHandle;

$Mac::LittleSingleDouble::VERSION='1.0';

# default Finder colors for label values.
%labelcolors = (0 => 'Black',
		1 => 'Brown',
		2 => 'Green',
		3 => 'Blue',
		4 => 'Cyan',
		5 => 'Pink',
		6 => 'Red',
		7 => 'Orange');

# default Finder names for label values.		  
%labelnames = (0 => 'None',
	       1 => 'Project 2',
	       2 => 'Project 1',
	       3 => 'Personal',
	       4 => 'Cool',
	       5 => 'In Progress',
	       6 => 'Hot',
	       7 => 'Essential');

%entryids = (1 => 'Data Fork',
	     2 => 'Resource Fork',
	     3 => 'Real Name',
	     4 => 'Comment',
	     5 => 'Icon, B&W',
	     6 => 'Icon, Color',
	     8 => 'File Dates Info',
	     9 => 'Finder Info',
	     10 => 'Macintosh File Info',
	     11 => 'ProDOS File Info',
	     12 => 'MS-DOS File Info',
	     13 => 'Short Name',
	     14 => 'AFP File Info',
	     15 => 'Directory ID');

# Magic number values mapped to file format (AppleSingle or
# AppleDouble). Any other value means it's not an AppleSingle or
# AppleDouble file.
%formats = ( pack('H8', "00051600") => 'AppleSingle',
	     pack('H8', "00051607") => 'AppleDouble');

sub new
{
    my $class = shift;
    my $filename = shift;
    if (!defined($filename))
    {
	die "The constructor (new) requires a filename as an argument!";
    }
    my $this = {};        # instances are based on hashes
    bless $this, $class;  # now $this is an instance of $class
    $this->_initialize($filename);
    return $this;
}

sub DESTROY
{
    my $this = shift;
    $this->close();
}

sub close
{
    my $this = shift;
    if ($this->{'_filehandle'})
    {
	CORE::close $this->{'_filehandle'};
	undef($this->{'_filehandle'});
    }
}

sub get_finder_info
{
    my $this = shift;
    $this->_require_applesingledouble();
    if (!defined($this->{'_finder_info'}))
    {
	$this->_parse_finder_info($this->get_entry(9));
    }
    return $this->{'_finder_info'}
}

sub get_entry
{
    my $this = shift;
    my $entryid = shift;
    $this->_require_applesingledouble();
    my $entry = $this->{'_entries'}->{$entryid};
    if (!defined($entry))
    {
	$entry = $this->_get_entry_from_file($entryid);
    }
    if ($this->{'_cache_entries'})
    {
	$this->{'_entries'}->{$entryid} = $entry;
    }
    return $entry;
}

sub get_file_format
{
    my $this = shift;
    if (!defined($this->{'_magicno'}))
    {
	$this->_parse_header();
    }
    my $format = $formats{$this->{'_magicno'}};
    if (!defined($format)) { $format = 'Plain'; }
    return $format;
}

sub is_applesingle
{
    my $this = shift;
    return ($this->get_file_format() eq 'AppleSingle');
}

sub is_appledouble
{
    my $this = shift;
    return $this->get_file_format() eq 'AppleDouble';
}

sub preload_entire_file
{
    my $this = shift;
    $this->_require_applesingledouble();
    $this->cache_entries(1);
    $this->get_all_entries();
    $this->close();
}

sub cache_entries
{
    my $this = shift;
    my $val = shift;
    if (defined($val))
    {
	$this->{'_cache_entries'} = $val;
    }
    return $this->{'_cache_entries'};
}


sub get_entry_descriptors
{
    my $this = shift;
    $this->_require_applesingledouble();
    return $this->{'_descriptors'};
}

sub get_all_entries
{
    my $this = shift;
    $this->_require_applesingledouble();
    my %entries = ();
    my $descriptors = $this->get_entry_descriptors();
    foreach $entryid (keys( %{$descriptors} ))
    {
	$entries{$entryid} = $this->get_entry($entryid);
    }
    return \%entries;
}

sub set_labelnames
{
    my $this = shift;
    my $new_labelnames = shift;
    $this->{'_labelnames'} = $new_labelnames;
}

sub set_labelcolors
{
    my $this = shift;
    my $new_labelcolors = shift;
    $this->{'_labelcolors'} = $new_labelcolors;
}

sub dump
{
    my $this = shift;
    $this->dump_header();
    print "\n";
    $this->dump_entries();    
}

sub dump_header
{
    my $this = shift;
    $this->_require_applesingledouble();
    print "Dumping " . $this->get_file_format() . " file '" . $this->{'_filename'} . "':\n";
    if ($this->get_file_format() eq 'Plain')
    {
	print "Can't dump a file unless it's in AppleSingle or AppleDouble format.\n";
	return;
    }
    print "File is " . $this->{'_size'} . " bytes long.\n";
    print "Magic Number is " . unpack('H8', $this->{'_magicno'}) . ".\n";
    print "Version Number is " . unpack('H8', $this->{'_version'}) . ".\n";

    print "Entry descriptor table:\n";
    my $descriptors = $this->{'_descriptors'};
    my $d = $descriptors; # make next line look purty
    foreach $entryid (sort {$d->{$a}->{'Offset'} <=> $d->{$b}->{'Offset'} } keys( %{$descriptors} ))
    {
	print "Offset: " . $descriptors->{$entryid}->{'Offset'} . "\t";
	print "Length: " . $descriptors->{$entryid}->{'Length'} . "\t";
	my $entryidname = $entryids{$entryid};
	if (!defined($entryidname)) { $entryidname = '???'; }
	print "EntryID: $entryid ($entryidname)\n";
    }
}

sub dump_entries
{
    my $this = shift;

    my $descriptors = $this->{'_descriptors'};
    foreach $entryid (sort {$descriptors->{$a}->{'Offset'} <=> $descriptors->{$b}->{'Offset'} } keys( %{$descriptors} ))
    {
	$this->dump_entry($entryid);
    }
}

sub dump_entry
{
    my $this = shift;
    my $entryid = shift;

    my $entryidname = $entryids{$entryid};
    if (!defined($entryidname)) { $entryidname = '???'; }
    print "EntryID: $entryid ($entryidname)\n";
    print $this->_hex_dump($this->get_entry($entryid)) . "\n";
}

sub _hex_dump
{
    my $this = shift;
    my $bytes = shift;

    my $length = length($bytes);
    my $hexdump = '';
    # this code is based on a script by David Thorburn-Gundlach
    for ($p = 0; $p < $length; $p += 16)
    {
	$byteno = sprintf('%8lx', $p);
	$byteno =~ s/ /0/g;
	$byteno =~ s/^(....)/$1 /g;
	$asc_string = substr($bytes, $p, 16);
	$hex_string = unpack('H32', $asc_string);
	$hex_string =~ s/(..)/$1 /g;
	$pad = ' ' x (3*(16-length($asc_string)));
	$asc_string =~ s/([\00-\37,\177])/./g;
	$hexdump .= "$byteno:  $hex_string$pad  $asc_string\n";
    }
    return $hexdump;
}

sub _initialize
{
    my $this = shift;
    $this->{'_filename'} = shift;
    if (!-f $this->{'_filename'})
    {
	die "'$this->{'_filename'}' is not a file!";
    }
    $this->{'_entries'} = {};
    $this->{'_labelnames'} = \%labelnames;
    $this->{'_labelcolors'} = \%labelcolors;
}

sub _read_header
{
    my $this = shift;
    my $header_raw;

    my $fh = new FileHandle;
    $fh->open($this->{'_filename'});
    ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks) = stat($fh);
    $this->{'_size'} = $size;
    read($fh, $header_raw, 26);
    # not closed here - must use $this->close() later;
    $this->{'_filehandle'} = $fh;

    return $header_raw;
}

sub _parse_header
{
    my $this = shift;
    return if defined($this->{'_magicno'}); # already did it
		      
    $header_raw = $this->_read_header();
    
    $this->{'_magicno'} = reverse substr($header_raw, 0,4);
    if ($this->get_file_format() ne 'Plain') # will not infinitely recurse because we just set _magicno
    {
	$this->{'_version'} = reverse substr($header_raw, 4,4);
	my $entrycount = unpack('v', substr($header_raw, 24,2));
	my $descriptors_raw = $this->_read_descriptors($entrycount);
	$this->_parse_descriptors($entrycount, $descriptors_raw);
    }
}

sub _read_descriptors
{
    my $this = shift;
    my $entrycount = shift;
    my $descriptors_raw;
    # this must be called after _read_header!
    seek($this->{'_filehandle'}, 26, 0);
    read($this->{'_filehandle'}, $descriptors_raw, $entrycount * 12);
    return $descriptors_raw;
}

sub _parse_descriptors
{
    my $this = shift;
    my $entrycount = shift;
    my $descriptors_raw = shift;
    my(%descriptors);

    for($i = 0; $i < $entrycount; $i++)
    {
	my(%descriptor);
	$entrystart = (12 * $i);
	$descriptor{'EntryID'} = unpack('V', substr($descriptors_raw, $entrystart, 4));
	$descriptor{'Offset'} = unpack('V', substr($descriptors_raw, $entrystart + 4, 4));
	$descriptor{'Length'} = unpack('V', substr($descriptors_raw, $entrystart + 8, 4));

	# store in the descriptors hash keyed by entry ID
	$descriptors{$descriptor{'EntryID'}} = \%descriptor;
    }

    $this->{'_descriptors'} = \%descriptors;
}

sub _parse_finder_info
{
    my $this = shift;
    my $finderinfo_raw = shift;
    my(%finderinfo);

    # based on page 7-76 of Inside Macintosh: Finder Interface
    $finderinfo{'Type'} = substr($finderinfo_raw, 0, 4);
    $finderinfo{'Creator'} = substr($finderinfo_raw, 4, 4);
    $finderinfo{'Flags'} = unpack('n', substr($finderinfo_raw, 8, 2));
    $finderinfo{'Location'} = unpack('nn', substr($finderinfo_raw, 10, 4));
    $finderinfo{'Fldr'} = unpack('n', substr($finderinfo_raw, 14, 2));

    # Finder Flags
    $flagbits = unpack('B8', substr($finderinfo_raw, 8, 1)) .unpack('B8', substr($finderinfo_raw, 9, 1)) ;
    #print "flagbits is $flagbits\n";
    $finderinfo{'Label'} = unpack('C', pack('B8', '0'x5 . substr($flagbits, 12, 3)));
    $finderinfo{'Color'} = $finderinfo{'Label'};
    $finderinfo{'IsOnDesk'} = substr($flagbits, 15, 1);
    $finderinfo{'IsShared'} = substr($flagbits, 9, 1);
    $finderinfo{'HasBeenInited'} = substr($flagbits, 7, 1);
    $finderinfo{'HasCustomIcon'} = substr($flagbits, 5, 1);
    $finderinfo{'IsStationery'} = substr($flagbits, 4, 1);
    $finderinfo{'NameLocked'} = substr($flagbits, 3, 1);
    $finderinfo{'HasBundle'} = substr($flagbits, 2, 1);
    $finderinfo{'IsInvisible'} = substr($flagbits, 1, 1);
    $finderinfo{'IsAlias'} = substr($flagbits, 0, 1);    

    # Extended Finder Info
    $finderinfo{'IconID'} = unpack('n', substr($finderinfo_raw, 16, 2));
    $finderinfo{'Script'} = unpack('c', substr($finderinfo_raw, 24, 1));
    $finderinfo{'XFlags'} = unpack('B8', substr($finderinfo_raw, 25, 1));
    $finderinfo{'Comment'} = unpack('n', substr($finderinfo_raw, 26, 2));
    $finderinfo{'PutAway'} = unpack('N', substr($finderinfo_raw, 28, 4));

    my $labelcolor = $this->{'_labelcolors'}->{$finderinfo{'Label'}};
    my $labelname = $this->{'_labelnames'}->{$finderinfo{'Label'}};
    $finderinfo{'LabelColor'} = defined($labelcolor)? $labelcolor : '(no labelcolor provided)';
    $finderinfo{'LabelName'} = defined($labelname)? $labelname : '(no labelname provided)';

    $this->{'_finder_info'} = \%finderinfo;
}

sub _get_entry_from_file
{
    my $this = shift;
    my $entryid = shift;
    my $descriptors = $this->get_entry_descriptors();
    
    my $descriptor = $descriptors->{$entryid};
    my $entry;
    seek($this->{'_filehandle'}, $descriptor->{'Offset'}, 0);
    read($this->{'_filehandle'}, $entry, $descriptor->{'Length'});
    return $entry;
}

sub _require_applesingledouble
{
    my $this = shift;
    if ($this->get_file_format() eq 'Plain')
    {
	die "File '" . $this->{'_filename'} . "' is not in AppleSingle or AppleDouble format!";
    }
}

1;
__END__

=head1 NAME

Mac::AppleSingleDouble - Read Mac files in AppleSingle or AppleDouble format.

=head1 SYNOPSIS

 use Mac::AppleSingleDouble;
 $foo = new Mac::AppleSingleDouble(shift);
 $finder_info = $foo->get_finder_info();
 print "The file Type is: $finder_info->{'Type'}\n";
 print "The file Creator is: $finder_info->{'Creator'}\n";
 print "The Finder label color is: $finder_info->{'LabelColor'}\n";
 $foo->close();

=head1 REQUIRES

Perl5 (tested with 5.005_03; may work with older versions of Perl 5), the FileHandle module.

=head1 EXPORTS

Nothing.

=head1 DESCRIPTION

Mac::AppleSingleDouble is a class which knows how to decode the
AppleSingle and AppleDouble file formats. An instance of
Mac::AppleSingleDouble represents one file on disk.

The structure of Macintosh files is unlike the structure of files on
non-Macintosh operating systems. Most operating systems represent a
file as a filename (with the file type appended as a suffix), a few
attribute bits, and a single chunk of data. Macintosh files consist of
a filename, attribute bits, a four-character file type code ('TEXT',
'APPL', 'JPEG', 'PDF ', etc.), a four-character file creator code
('MSWD' for Microsoft Word, '8BIM' for Photoshop, 'SIT!' for StuffIt,
etc.), a chunk of unstructured data called the "Data Fork", and a
chunk of structured data called the "Resource Fork". In order to store
Macintosh files on other computers, some form of encoding must be used
or the resource and attribute information will be lost (which is OK in
some cases). MacBinary, BinHex, and AppleSingle all encode the
original Mac file in a single chunk of data suitable for export to
other operating systems. AppleDouble encodes all the Mac-only data in
one file, but leaves the chunk of unstructured data in a separate file
all by itself, which allows non-Mac-aware programs to read the
unstructured data with no decoding step. AppleSingle and AppleDouble
were originally developed for A/UX (an Apple Unix flavor discontinued
long ago), and are used by netatalk (an AppleShare file server for
Unix servers and Mac clients).

If you are working Mac files on a Mac (presumably with MacPerl), you
probably do NOT need this class. If you are working with Mac files on
a non-Mac, the files may be encoded in AppleSingle or AppleDouble
format, and this class can be useful if you need to get at the Mac
file attributes such as the Finder label, the type and creator codes,
or the IsInvisible bit.

See the "AppleSingle/AppleDouble Formats for Foreign Files Developer's
Note" and the book "Inside Macintosh: Finder Interface" from Apple
Computer, Inc for more details on the formats themselves.

=head1 METHODS

=head2 Creation

=over 4

=item $applefile = new Mac::AppleSingleDouble($filename)

Creates a new Mac::AppleSingleDouble object to represent the file named in $filename.

=back

=head2 Cleanup

=over 4

=item $applefile->close()

Closes the underlying AppleSingle or AppleDouble file. 

=back

=head2 Access

=over 4

=item $applefile->get_finder_info()

Returns a hash containing Finder information decoded from the FInfo and FXInfo data structures.

=item $applefile->get_entry($id)

Returns the raw binary data of an entry, given its ID. Types defined by Apple are:
  1: Data Fork
  2: Resource Fork
  3: Real Name
  4: Comment
  5: Icon, B&W
  6: Icon, Color
  8: File Dates Info
  9: Finder Info
 10: Macintosh File Info
 11: ProDOS File Info
 12: MS-DOS File Info
 13: Short Name
 14: AFP File Info
 15: Directory ID

=item $applefile->get_file_format()

Returns 'AppleSingle', 'AppleDouble', or 'Plain' based on the "magic
number" found at the beginning of the file. (0x00051600 is AppleSingle,
0x00051607 is AppleDouble, and anything else is Plain.)

=item $applefile->is_applesingle()

Returns 1 if the file format is AppleSingle. See get_file_format().

=item $applefile->is_appledouble()

Returns 1 if the file format is AppleDouble. See get_file_format().

=item $applefile->get_entry_descriptors()

Returns a hash with entry IDs as keys, and hash references as values. The references hashes contain three keys: EntryID, Offset, and Length. Offset is the offset from the start of the file to the entry data, and Length is the length of the data, both in bytes. (There are higher-level methods to access entry data so most users will not need to call this method.)

=item $applefile->get_all_entries()

Returns a hash with entry IDs as keys, and raw entry data as values. All entry IDs found in the file will be returned.

=item $applefile->dump()

Dump a formatted ASCII representation of the contents of the AppleSingle or AppleDouble file to STDOUT.

=item $applefile->dump_header()

Dump the filename and file size and header information to STDOUT. The header information includes: magic number, format version number, and all entry descriptors (entry ID, offset, and length of each).

=item $applefile->dump_entries()

Print a hex dump of the entry data for all entries in the file to STDOUT.

=item $applefile->dump_entry($id)

Print a hex dump of the entry data for the specified id to STDOUT.

=back

=head2 Configuration

=over 4

=item $applefile->set_labelnames(%new_labelnames)

Given a hash with keys 0 through 7 and string values, change the values corresponding to the LabelName key in the hash returned by get_finder_info(). Note that 0 should always be 'None' since it cannot be changed in the Finder, and the menu in the Finder lists labels in descending order (starting with 7 and counting down to 1).

=item $applefile->set_labelcolors(%new_labelcolors)

Given a hash with keys 0 through 7 and string values, change the values corresponding to the LabelColors key in the hash returned by get_finder_info(). Note that 0 should always be 'Black' or 'None' since it cannot be changed in the Finder, and the menu in the Finder lists labels in descending order (starting with 7 and counting down to 1).

=item $applefile->preload_entire_file()

Loads all the entry data from the file into memory and closes the underlying file.

=item $applefile->cache_entries()

Causes subsequent entry data accesses to be cached in memory in the object.

=back

=head1 DIAGNOSTICS

=over 4

=item The constructor (new) requires a filename as an argument!

(F) The constructor (new Mac::AppleSingleDouble($filename)) was called but the required filename argument was not defined. The path to the AppleSingle or AppleDouble file to be examined must be passed to the constructor.

=item File '/usr/bin/perl' is not in AppleSingle or AppleDouble format!

(F) The file was readable but did not start with the "magic number" denoting AppleSingle or AppleDouble format.

=item '..' is not a file!

(F) The filename specified in the constructor does not point to a file.

=back

=head1 BUGS

The AppleSingle and AppleDouble formats come in two versions - 1 and
2. I was unable to find documentation for version 1 - supposedly there
is a manual called "A/UX Toolbox: Macintosh ROM Interface", but I was
unable to find it.  However, netatalk uses version 1. So, this class
was coded using the version 2 specification but it was tested on
version 1 files written by netatalk. Entry ID 7 appears in version 1
files but I have no idea what it means. However, it seems to work...

=head1 RESTRICTIONS

This module can read AppleSingle and AppleDouble files, but it cannot
create or modify them. It's not worth my time to change it so that it
can (testing it thoroughly with other programs which use the files
would be very time consuming), so I probably won't do it. If you want
to make that enhancement and send your changes to me, I would be happy
to integrate them into a new version and to give you credit for your
work.

=head1 AUTHOR

Jamie Flournoy, jamie@white-mountain.org

