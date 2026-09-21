#!/usr/bin/perl
# Host process for the MediaRemote adapter.
#
# /usr/bin/perl is an Apple platform binary, which is what lets the loaded dylib
# read now-playing info on macOS 15.4+. This script does nothing but load the
# adapter and keep the process (and its run loop) alive; the dylib writes
# newline-delimited JSON to stdout.

use strict;
use warnings;
use DynaLoader;

my $dylib = shift @ARGV
    or die "usage: stream.pl /path/to/MediaRemoteAdapter.dylib\n";

die "adapter not found: $dylib\n" unless -e $dylib;

$| = 1;

DynaLoader::dl_load_file($dylib, 0)
    or die "failed to load adapter: $dylib\n";

# Park, but do not outlive the app. The adapter runs on its own dispatch queue,
# so this thread only has to stay alive. A normal quit terminates us directly;
# this poll catches a force-quit, where we would otherwise be reparented to
# launchd and keep running forever.
my $parent = getppid();
while (1) {
    sleep 2;
    last if getppid() != $parent;
}
exit 0;
