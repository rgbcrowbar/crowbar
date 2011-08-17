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
# Parsing Methods
#######################################################################

use strict;
use File::Basename;
use Text::CSV_XS;
use JSON::PP;

my $debug = 1;

#######################################################################
# scrubField($)() - Scrub data entry fields
#######################################################################
sub scrubField($)
{
	my $string = shift;
	return "" if (!$string);    # Never Null
	$string =~ tr/[\x{0020}-\x{007e}]/>/c;   # Always ascii
	$string =~ s/\?//g;                      # Remove unicode sustitution marker
	$string =~ s/^\s+//;                     # Kill extra space
	$string =~ s/\s+$//;
	$string =~ s/(\s+)/ /g;
	return $string;
}

#######################################################################
# parseBiosConfig() - Parse the BIOS configuration data
#######################################################################

sub parseBiosConfig
{
	my ($file, $bioscfg) = @_;
	my $debug = 0;

	my $csv = Text::CSV_XS->new({binary => 1, eol => $/});
	open my $io, "<", $file or die "$file: $!";

	while (my $row = $csv->getline($io))
	{
		my @fields = @$row;

		# Category
		my $cat = "";
		if ($fields[0] && $cat ne $fields[0])
		{
			$cat = scrubField($fields[0]);
			if ($debug)
			{
				print "\n+----------{$cat}----------+\n";
			}
			next;
		}

		# Sub-category
		my $subcat = "";
		if ($fields[1] && $subcat ne $fields[1])
		{
			$subcat = scrubField($fields[1]);
			if ($debug)
			{
				print "\n  %%%%%%%%%%{$subcat}%%%%%%%%%%\n\n";
			}
			next;
		}

		# D4 token name
		my $cmd = scrubField($fields[2]);

		# Default setting
		my $default = scrubField($fields[4]);

		# Zap the surrounding brackets
		$default =~ s/^\[//;
		$default =~ s/\]$//;

		# IEC comment (list of possible values)
		my @values = ();
		my $iec    = scrubField($fields[5]);
		
		# Change the field delimiter to ,
		if ($iec)
		{
			# Remove extra leading and trailing whitespace from value
			my @tmp = split(/\//, $iec);
			foreach my $vz (@tmp)
			{
				$vz =~ s/^\s+//;
				$vz =~ s/\s+$//;
				push(@values, $vz);
			}

			$iec = join(',', @values);
		}

		# D4 address
		my $d4adr     = scrubField($fields[6]);
		my @addresses = ();
		if ($d4adr)
		{
			@addresses = split(/\//, $d4adr);

			# Trim extra field whitespace
			my @na = ();
			foreach my $v (@addresses)
			{

				# TBD - we should validate hex addresses with regex
				# Example : 0123h
				$v =~ s/^\s+//;
				$v =~ s/\s+$//;
				$v =~ s/\s+//g;
				push(@na, $v);
			}
			$d4adr = join(',', @na);
		}

		# Special notes (remove asteriks)
		my $notes = scrubField($fields[7]);
		$notes =~ s/\*//g;
		$notes =~ s/^\s+//;
		$notes =~ s/\s+$//;

		# Skip blank keyword fields
		next if !($cmd);

		# Validate records
		if (!$cmd || !$default || scalar(@values) < 1 || scalar(@addresses) < 1)
		{
			print "Invalid record - Skipping "
			  . "\"$cmd\","
			  . "\"$default\","
			  . "\"$iec\","
			  . "\"$d4adr\","
			  . "\"$notes\"\n";
			next;
		}

		# Dump the formated data
		if ($debug)
		{
			print "    "
			  . "\"$cmd\","
			  . "\"$default\","
			  . "\"$iec\","
			  . "\"$d4adr\","
			  . "\"$notes\"\n";
		}

		my $biosmap = {
			description => $cmd,
			default     => $default,
			values      => \@values,
			addresses   => \@addresses,
			notes       => $notes
		};

		# Push the return record on the bioscfg array
		push(@$bioscfg, $biosmap);
	}

	close($io);
}

#######################################################################
# showBiosConfig() - Show the BIOS data
#######################################################################

sub showBiosConfig
{
	my ($bioscfg) = @_;
	print "++++++++++[ bios config ] ++++++++++\n";

	sub showArray
	{
		my ($a) = @_;
		my $str = "";

		# Ignore empty arrays
		return $str if (!$a || scalar(@$a) < 1);
		foreach my $v (@$a)
		{
			$str .= "," if ($str);
			$str .= $v  if ($v);
		}
		return $str;
	}

	my $dump_twiki = 1;
	if ($dump_twiki)
	{
		foreach my $r (@$bioscfg)
		{
			print "| $r->{description}"
			  . " | $r->{default} | "
			  . showArray($r->{values}) . " | "
			  . showArray($r->{addresses}) . " | "
			  . "$r->{notes} |\n";
		}
	}
	else
	{
		foreach my $r (@$bioscfg)
		{
			print "    "
			  . "\"$r->{description}\","
			  . "\"$r->{default}\"," . "\""
			  . showArray($r->{values}) . "\"," . "\""
			  . showArray($r->{addresses}) . "\","
			  . "\"$r->{notes}\"\n";
		}
	}
}

#######################################################################
# applyDCSSettings() - Apply any settings specific to DCS deployment
#######################################################################

sub applyDCSSettings
{
	my ($bioscfg) = @_;

	foreach my $r (@$bioscfg)
	{
		if ($r->{description} eq "Virtualization Technology(VT)")
		{
			$r->{default} = "Enabled";
		}

		# Add any other DCS custom settings here ...
	}
}

#######################################################################
# writeSetProposal() - Write the set proposal
#######################################################################

sub writeSetProposal
{
	my ($jsonfile, $schemafile, $bioscfg) = @_;

	# Reformat the data into flat map
	my %flatcfg = ();
	my $sbuf    = "";
	foreach my $r (@$bioscfg)
	{
		my $k = $r->{description};
		my $v = $r->{default};
		next if (!$k || !$v);
		$flatcfg{$k} = $v;
		my $pad  = "                 ";
		my $code = "$pad\"$r->{description}\": "
		  . "{ \"type\": \"str\", \"required\": true }";
		$sbuf .= ",\n" if ($sbuf);
		$sbuf .= $code;
	}

	# Split the file path into separate components
	my ($name, $path, $ext) = fileparse($jsonfile, qr/\.[^.]*/);

	# Parse off the model name : bc-template-bios-map-C6100
	my $model = "";
	if ($name =~ m/^bc-template-bios-set-(\S*)$/)
	{
		$model = $1;
	}
	die "ERROR : Invalid model name\n" if (!$model);

	# JSON output coding
	my $json = JSON::PP->new->utf8;
	$json = $json->pretty(1);
	$json = $json->indent_length(8);

	my $jsontext = $json->encode(\%flatcfg);
	die "ERROR : Empty JSON text\n" if (!$jsontext);
	my $jsondata = <<EOD;
{
  "id": "$name",
  "description": "Default proposal for the $model BIOS",
  "attributes": {
    "bios": {
      "settings": $jsontext
    } 
  },
  "deployment": {
    "bios": {
      "crowbar-revision": 0,
      "elements": {},
      "element_order": [
        [ "bmcinstall", "biosinstall", "raidinstall" ]
      ],
      "config": {
        "environment": "bios-base-config",
        "mode": "full",
        "transitions": true,
        "transition_list": [
          "discovering",
          "discovered",
          "hardware-installed",
          "hardware-updated"
        ]
      } 
    }
  }
}
EOD

	my $schemadata = <<EOD;
{
  "type": "map",
  "required": true,
  "mapping": {
    "id": { "type": "str", "required": true, "pattern": "/^bc-bios-|^$name\$\/" },
    "description": { "type": "str", "required": true },
    "attributes": {
      "type": "map",
      "required": true,
      "mapping": {
        "bios": {
          "type": "map",
          "required": true,
          "mapping": {
            "settings": {
              "type": "map",
              "required": true,
              "mapping": {
$sbuf 
            }
          }
        }
      }
    }
  },
  "deployment": {
  	"type": "map",
    "required": true,
    "mapping": {
      "bios": {
        "type": "map",
        "required": true,
        "mapping": {
          "crowbar-revision": { "type": "int", "required": true },
          "elements": {
            "type": "map",
            "required": true,
            "mapping": {
              = : {
                "type": "seq",
                "required": true,
                "sequence": [ { "type": "str" } ]
              }
            }
          },
          "element_order": {
            "type": "seq",
            "required": true,
            "sequence": [ {
              "type": "seq",
              "sequence": [ { "type": "str" } ]
            } ]
          },
          "config": {
            "type": "map",
            "required": true,
            "mapping": {
              "environment": { "type": "str", "required": true },
              "mode": { "type": "str", "required": true },
              "transitions": { "type": "bool", "required": true },
              "transition_list": {
                "type": "seq",
                "required": true,
                "sequence": [ { "type": "str" } ]
                }
              }
            }
          }
        }
      }
    }
  }
}
EOD

	print "++++++++++[ writing JSON file $jsonfile ] ++++++++++\n";
	open JSONFILE, "> $jsonfile" or die "Can't open $schemafile : $!";
	print JSONFILE $jsondata;
	close(JSONFILE);

	print "++++++++++[ writing SCHEMA file $schemafile ] ++++++++++\n";
	open SCHEMAFILE, "> $schemafile" or die "Can't open $schemafile : $!";
	print SCHEMAFILE $schemadata;
	close(SCHEMAFILE);
}

#######################################################################
# writeMapProposal() - Write the map proposal
#######################################################################

sub writeMapProposal
{
	my ($jsonfile, $schemafile, $bioscfg) = @_;

	# Split the file path into separate components
	my ($name, $path, $ext) = fileparse($jsonfile, qr/\.[^.]*/);

	# Parse off the model name : bc-template-bios-map-C6100
	my $model = "";
	if ($name =~ m/^bc-template-bios-map-(\S*)$/)
	{
		$model = $1;
	}
	die "ERROR : Invalid model name\n" if (!$model);

	# JSON output coding
	my $json = JSON::PP->new->utf8;
	$json = $json->pretty(1);

	my $jsontext = $json->encode($bioscfg);
	die "ERROR : Empty JSON text\n" if (!$jsontext);

	my $jsondata = <<EOD;
{
  "id": "$name",
  "description": "Default proposal for the $model BIOS",
  "attributes": {
    "bios": {
        "settings": $jsontext
    }
  },
  "deployment": {
    "bios": {
      "crowbar-revision": 0,
      "elements": {},
      "element_order": [
        [ ]
      ],
      "config": {
        "environment": "bios-base-config",
        "mode": "full",
        "transitions": false,
        "transition_list": []
      } 
    }
  }
}
EOD

	my $schemadata = <<EOD;
{
  "type": "map",
  "required": true,
  "mapping": {
    "id": { "type": "str", "required": true, "pattern": "/^bc-bios-|^$name\$\/" },
    "description": { "type": "str", "required": true },
    "attributes": {
      "type": "map",
      "required": true,
      "mapping": {
        "bios": {
          "type": "map",
          "required": true,
          "mapping": {
            "settings": {
              "type": "seq",
              "required": true,
              "sequence": [ {
                "type": "map",
                "required": true,
                "mapping": {
                  "addresses": { "type": "seq", "required": true, "sequence": [ { "type": "str", "required": true } ] },
                  "notes": { "type": "str" },
                  "values": { "type": "seq", "required": true, "sequence": [ { "type": "str", "required": true } ] },
                  "default": { "type": "str", "required": true },
                  "description": { "type": "str", "required": true }
                }
              }
              ]
            }
          }
        }
      }
    },
    "deployment": {
      "type": "map",
      "required": true,
      "mapping": {
        "bios": {
          "type": "map",
          "required": true,
          "mapping": {
            "crowbar-revision": { "type": "int", "required": true },
            "elements": {
              "type": "map",
              "required": true,
              "mapping": {
                = : {
                  "type": "seq",
                  "required": true,
                  "sequence": [ { "type": "str" } ]
                }
              }
            },
            "element_order": {
              "type": "seq",
              "required": true,
              "sequence": [ {
                "type": "seq",
                "sequence": [ { "type": "str" } ]
              } ]
            },
            "config": {
              "type": "map",
              "required": true,
              "mapping": {
                "environment": { "type": "str", "required": true },
                "mode": { "type": "str", "required": true },
                "transitions": { "type": "bool", "required": true },
                "transition_list": {
                  "type": "seq",
                  "required": true,
                  "sequence": [ { "type": "str" } ]
                }
              }
            }
          }
        }
      }
    }
  }
}
EOD

	print "++++++++++[ writing JSON file $jsonfile ] ++++++++++\n";
	open JSONFILE, "> $jsonfile" or die "Can't open $schemafile : $!";
	print JSONFILE $jsondata;
	close(JSONFILE);

	print "++++++++++[ writing SCHEMA file $schemafile ] ++++++++++\n";
	open SCHEMAFILE, "> $schemafile" or die "Can't open $schemafile : $!";
	print SCHEMAFILE $schemadata;
	close(SCHEMAFILE);
}

#######################################################################
# processAllFiles() - Process all the csv files in the map directory
#######################################################################

sub processAllFiles
{
	my ($path) = @_;

	# Open the directory.
	opendir(DIR, $path)
	  or die "Unable to open $path: $!";

	# Read in the files.
	# You will not generally want to process the '.' and '..' files,
	# so we will use grep() to take them out.
	# See any basic Unix filesystem tutorial for an explanation of the +m.

	my @files = grep { !/^\.{1,2}$/ } readdir(DIR);

	# Close the directory.
	closedir(DIR);

	# At this point you will have a list of filenames
	#  without full paths ('filename' rather than
	#  '/home/count0/filename', for example)
	# You will probably have a much easier time if you make
	#  sure all of these files include the full path,
	#  so here we will use map() to tack it on.
	#  (note that this could also be chained with the grep
	#   mentioned above, during the readdir() ).
	@files = map { $path . '/' . $_ } @files;

	for (@files)
	{

		# If the entry is a plain file
		if (-f $_)
		{
			my $ifile = $_;
			my ($mapname, $path, $ext) = fileparse($ifile, qr/\.[^.]*/);

			if ($ext eq ".csv")
			{
				my @bioscfg = ();
				parseBiosConfig($ifile, \@bioscfg);
				applyDCSSettings(\@bioscfg);
				showBiosConfig(\@bioscfg);
				my $opath = "../../../data_bags/crowbar";

				my $jsonfile   = "$opath/${mapname}.json";
				my $schemafile = "$opath/${mapname}.schema";

				# print "\n$jsonfile\n$schemafile\n";
				writeMapProposal($jsonfile, $schemafile, \@bioscfg);

				my $setname = $mapname;
				$setname =~ s/-map-/-set-/g;
				$jsonfile   = "$opath/${setname}.json";
				$schemafile = "$opath/${setname}.schema";
				writeSetProposal($jsonfile, $schemafile, \@bioscfg);
			}
		}
	}
}

1;
