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
# Utility Methods
#######################################################################

use strict;

#######################################################################
# isArray() - Check an object reference to see if it's and array
# for my $item (@array) {
#  print "We've got an array" if isArray($item);
# }
#######################################################################

sub isArray
{
	my ($ref) = @_;

	# Firstly arrays need to be references, throw
	#  out non-references early.
	return 0 unless ref $ref;

	# Now try and eval a bit of code to treat the
	#  reference as an array.  If it complains
	#  in the 'Not an ARRAY reference' then we're
	#  sure it's not an array, otherwise it was.
	eval { my $a = @$ref; };
	if ($@ =~ /^Not an ARRAY reference/)
	{
		return 0;
	}
	elsif ($@)
	{
		die "Unexpected error in eval: $@\n";
	}
	else
	{
		return 1;
	}
}

#-------------------------------------------------------------------------#
# Examples :
# $username = &promptUser("Enter the username ");
# $password = &promptUser("Enter the password ");
# $homeDir  = &promptUser("Enter the home directory ", "/home/$username");
# print "$username, $password, $homeDir\n";
#-------------------------------------------------------------------------#

#----------------------------(  promptUser  )-----------------------------#
#                                                                         #
#  FUNCTION:	promptUser                                                #
#                                                                         #
#  PURPOSE:	Prompt the user for some type of input, and return the        #
#		input back to the calling program.                                #
#                                                                         #
#  ARGS:	$promptString - what you want to prompt the user with         #
#		$defaultValue - (optional) a default value for the prompt         #
#                                                                         #
#-------------------------------------------------------------------------#

sub promptUser
{

	#-------------------------------------------------------------------#
	#  two possible input arguments - $promptString, and $defaultValue  #
	#  make the input arguments local variables.                        #
	#-------------------------------------------------------------------#

	my ($promptString, $defaultValue) = @_;

	#-------------------------------------------------------------------#
	#  if there is a default value, use the first print statement; if   #
	#  no default is provided, print the second string.                 #
	#-------------------------------------------------------------------#

	if ($defaultValue)
	{
		print $promptString, "[", $defaultValue, "]: ";
	}
	else
	{
		print $promptString, "> ";
	}

	$| = 1;          # force a flush after our print
	$_ = <STDIN>;    # get the input from STDIN (presumably the keyboard)

	#------------------------------------------------------------------#
	# remove the newline character from the end of the input the user  #
	# gave us.                                                         #
	#------------------------------------------------------------------#

	chomp;

	#-----------------------------------------------------------------#
	#  if we had a $default value, and the user gave us input, then   #
	#  return the input; if we had a default, and they gave us no     #
	#  no input, return the $defaultValue.                            #
	#                                                                 #
	#  if we did not have a default value, then just return whatever  #
	#  the user gave us.  if they just hit the <enter> key,           #
	#  the calling routine will have to deal with that.               #
	#-----------------------------------------------------------------#

	if ($defaultValue)
	{
		return $_ ? $_ : $defaultValue;    # return $_ if it has a value
	}
	else
	{
		return $_;
	}
}

#######################################################################
# quit() - exit|quit|bye
#######################################################################

sub quit
{
	my $preamble = <<PREAMBLE;

  Dismounting data resources
  Exiting Shell ...

PREAMBLE
	print $preamble;
	exit(0);
}

#######################################################################
# cold() - Cold start initialization
#######################################################################

sub bootStrap { }

sub cold
{
	my ($cmd) = @_;
	my $preamble = <<PREAMBLE;

  BIOS config parser shell [version 1.1]

PREAMBLE
	print $preamble;
	bootStrap();
	my $postamble = <<POSTAMBLE;

  Shell setup complete.
  Type exit to quit or help for a list of commands.

POSTAMBLE
	print "\n$postamble";
	return 1;
}

#######################################################################
# help() - Display help information
#######################################################################

sub help
{
	my ($cmd) = @_;
	my $preamble = <<PREAMBLE;

  BIOS config parser shell HELP

  command             description
  ==========================================-==========================
  exit|quit|bye       Exit the shell.
  run                 Convert all CSV files in the maps sub-directory
  cold                Shell cold start.

PREAMBLE
	print $preamble;
	my $postamble = <<POSTAMBLE;

POSTAMBLE
	print $postamble;
	return 1;
}

1;
