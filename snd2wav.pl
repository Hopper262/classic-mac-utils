#!/usr/bin/env perl

binmode STDIN;

die "bad snd format" unless ReadSint16() == 1;
die "too many data types" unless ReadSint16() == 1;
die "not sampled sound" unless ReadSint16() == 5;

my $opts = ReadSint32();
die "unhandled opts" unless $opts == 0x80 || $opts == 0xA0;

die "too many commands" unless ReadSint16() == 1;
die "not a bufferCmd" unless ReadUint16() == 0x8051;
die "bad param1" unless ReadSint16() == 0;
die "bad param2" unless ReadSint32() == 20;
die "bad data pointer" unless ReadSint32() == 0;

# finally something interesting
my $numbytes = ReadUint32();
my $samplerate = ReadUFixed();

# these get ignored
my $loopstart = ReadUint32();
my $loopend = ReadUint32();

die "not standard sample encoding" unless ReadUint8() == 0;
die "weird baseFrequency" unless ReadUint8() == 0x3C;

# we're up to sound data now, let's write some WAV!
# Thanks to: https://ccrma.stanford.edu/courses/422/projects/WaveFormat/
# Thanks also to myself in the past, who wrote the following for
#  a different project, which I copied without updating the style

my $data_size = $numbytes;
my $rate = int($samplerate);
my $bytes_sample = 1;
my $channels = 1;

binmode STDOUT;

print "RIFF";                  # ChunkID
print pack('V', 36 + $data_size);  # ChunkSize
print "WAVE";                   # Format

print "fmt ";                   # Subchunk1ID
print pack('V', 16);            # Subchunk1Size
print pack('v', 1);             # AudioFormat
print pack('v', $channels);     # NumChannels
print pack('V', $rate);         # SampleRate
print pack('V', $rate * $channels * $bytes_sample);   # ByteRate
print pack('v', $channels * $bytes_sample);           # BlockAlign
print pack('v', $bytes_sample * 8);                   # BitsPerSample

print "data";                   # Subchunk2ID
print pack('V', $data_size);    # Subchunk2Size

for my $i (1..$numbytes)
{
  my $byte;
  read STDIN, $byte, 1;
  print $byte;
}



sub ReadUint32
{
  return ReadPacked('L>', 4);
}
sub ReadSint32
{
  return ReadPacked('l>', 4);
}
sub ReadUint16
{
  return ReadPacked('S>', 2);
}
sub ReadSint16
{
  return ReadPacked('s>', 2);
}
sub ReadUint8
{
  return ReadPacked('C', 1);
}
sub ReadFixed
{
  my $fixed = ReadSint32();
  return $fixed / 65536.0;
}
sub ReadUFixed
{
  my $fixed = ReadUint32();
  return $fixed / 65536.0;
}

our $BLOB = undef;
our $BLOBoff = 0;
our $BLOBlen = 0;
sub SetReadSource
{
  my ($data) = @_;
  $BLOB = $_[0];
  $BLOBoff = 0;
  $BLOBlen = defined($BLOB) ? length($BLOB) : 0;
}
sub SetReadOffset
{
  my ($off) = @_;
  die "Can't set offset for piped data" unless defined $BLOB;
  die "Bad offset for data" if (($off < 0) || ($off > $BLOBlen));
  $BLOBoff = $off;
}
sub CurOffset
{
  return $BLOBoff;
}
sub ReadRaw
{
  my ($size, $nofail) = @_;
  die "Can't read negative size" if $size < 0;
  return '' if $size == 0;
  if (defined $BLOB)
  {
    my $left = $BLOBlen - $BLOBoff;
    if ($size > $left)
    {
      return undef if $nofail;
      die "Not enough data in blob (offset $BLOBoff, length $BLOBlen)";
    }
    $BLOBoff += $size;
    return substr($BLOB, $BLOBoff - $size, $size);
  }
  else
  {
    my $chunk;
    my $rsize = read STDIN, $chunk, $size;
    $BLOBoff += $rsize;
    unless ($rsize == $size)
    {
      return undef if $nofail;
      die "Failed to read $size bytes";
    }
    return $chunk;
  }
}
sub ReadPadding
{
  ReadRaw(@_);
}
sub ReadPacked
{
  my ($template, $size) = @_;
  return unpack($template, ReadRaw($size));
}

