#! perl -w
# Copyright 2011, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


#######################################################################
# BIOS configuration parser
#######################################################################

use strict;

# Standard perl library includes
use Getopt::Long;

# Library includes
use BiosConfigUtil;
use BiosConfigParser;

#######################################################################
# Program setup
#######################################################################
my $runshell = 0;
my $argc     = $#ARGV + 1;
my $verbose  = '';
my $mappath  = "./maps";
my @bioscfg  = ();

my $result = GetOptions(
	"verbose" => \$verbose,
	"shell"   => \$runshell
);

if (!$result)
{
	die "Invalid commandline arguments\n";
}

cold();
if ($runshell)
{
	my $running = 1;

	while ($running)
	{
		my $cmd = &promptUser("BIOS");
		if (!$cmd) { }
		elsif ($cmd =~ m/exit/i || m/quit/i || m/bye/i) { &quit(); }
		elsif ($cmd =~ m/^\s*help\s*$/i) { &help(); }
		elsif ($cmd =~ m/^\s*cold\s*$/i) { &cold(); }
		elsif ($cmd =~ m/^\s*run\s*$/i)
		{
			&processAllFiles($mappath);
		}
		else
		{
			print "\ncommand syntax error, type help for assistance {$cmd}\n\n";
		}
	}
}
else
{
	&processAllFiles($mappath);
}

exit(0);

