classic-mac-utils
=================

Perl scripts to handle resource forks and other old Mac formats.

These are all command-line tools. Usually the input is expected on stdin and output is written to stdout. Tools dealing with resource forks expect the resource data on stdin; on Mac OS X, you can do this like:

    ./extract_rsrc.pl < "My Mac File"/..namedfork/rsrc

Some of these files are modifications of others' code. I should send patches upstream, but I'm extremely lazy so I probably haven't done so. Feel free to do so in my stead; I don't even mind if you take credit. I just wanted the bugs fixed.

### extract_rsrc.pl

Unpacks a resource fork into separate files in the current directory. Command-line arguments can filter by type or ID. Good for hex inspection or processing of custom resource types.

If you're looking at string resources specifically, check out "strings2xml.pl" in my "marathon-utils" repository.

### snd2wav.pl

Converts a 'snd ' resource, as unpacked by extract_rsrc.pl, into a WAV file.

### LittleSingleDouble.pm

The "applesingle" tool on Mac OS X produces invalid files; the tool fails to write values in big-endian order. This Perl module is a quick hack of Mac::AppleSingleDouble, to read the broken little-endian files.

### Macbinary.pm

I found some serious problems with Mac::Macbinary 0.07. In particular, it doesn't handle files that lack a data fork, such as the vast majority of classic Mac applications.

### font_ids.txt

A list of classic Mac font IDs. Mac 'styl' resources store font IDs instead of names, so this can be useful if you're reconstructing rich text from a Mac format. Compiled from various sources on the web.

### rfork.subs

Various snippets of code for dealing with Mac resources. Includes code for extracting Mac icons into images using Image::Magick, and building the Apple icon color tables necessary. Also includes parsing of 'styl' and 'clut' resources.

### unpack_mpw_data.pl

Bungie's Marathon and Pathways Into Darkness are two classic Mac applications that compressed global data structures in the 68k CODE resources. I think this was a built-in feature of Apple's MPW compiler. I haven't been able to  reverse-engineer the compression, but MPW provided a textual listing of the data chunks. This script reads MPW's output and reassembles the binary data.

