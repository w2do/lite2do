#!/usr/bin/env perl

# lite2do, a lightweight text-based todo manager
# Copyright (C) 2008, 2009 Jaromir Hradilek

# This program is free software;  you can redistribute it  and/or modify it
# under the  terms of the  GNU General Public License  as published  by the
# Free Software Foundation; version 3 of the License.
# 
# This  program is  distributed  in the  hope that  it will be useful,  but
# WITHOUT ANY WARRANTY;  without even the implied warranty of  MERCHANTABI-
# LITY  or  FITNESS FOR A PARTICULAR PURPOSE.  See  the  GNU General Public
# License for more details.
# 
# You should have received a copy of the  GNU General Public License  along
# with this program. If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use locale;
use File::Copy;
use File::Basename;
use File::Spec::Functions;
use Term::ANSIColor;
use Getopt::Long;

# General script information:
use constant NAME    => basename($0, '.pl');             # Script name.
use constant VERSION => '1.1.0';                         # Script version.

# General script settings:
our $HOMEDIR   = $ENV{HOME} || $ENV{USERPROFILE} || '.'; # Home directory.
our $savefile  = catfile($HOMEDIR, '.lite2do');          # Save file name.
our $backext   = '.bak';                                 # Backup suffix.
our $verbose   = 1;                                      # Verbosity level.
our $coloured  = 0;                                      # Set up colours.

# Colours settings:
our $done      = 'green';                                # Finished tasks.
our $undone    = '';                                     # Undone tasks.

# Allowed colours:
my  %valid     = map { $_, 1 } qw( black green yellow magenta red blue
                                   cyan  white );

# Command line options:
my ($command, $response);

# Signal handlers:
$SIG{__WARN__} = sub {
  print STDERR NAME . ": " . (shift);
};

# Display given message and immediately terminate the script:
sub exit_with_error {
  my $message       = shift || 'An unspecified error has occurred.';
  my $return_value  = shift || 1;

  print STDERR NAME . ": $message\n";
  exit $return_value;
}

# Display script help:
sub display_help {
  my $command = shift || '';
  my $NAME    = NAME;

  # Parse command and display appropriate usage information:
  if ($command =~ /^(list|ls)$/) {
    print "Displays items in the task list.\n";
    print "Usage: $NAME list [\@GROUP|%ID] [TEXT...]\n";
  }
  elsif ($command =~ /^add$/) {
    print "Adds new item to the task list.\n";
    print "Usage: $NAME add [\@GROUP] TEXT...\n";
  }
  elsif ($command =~ /^(change|mv)$/) {
    print "Changes selected item in the task list.\n";
    print "Usage: $NAME change ID \@GROUP|TEXT...\n";
  }
  elsif ($command =~ /^(finish|fn)$/) {
    print "Finishes selected item in the task list.\n";
    print "Usage: $NAME finish ID\n";
  }
  elsif ($command =~ /^(revive|re)$/) {
    print "Revives selected item in the task list.\n";
    print "Usage: $NAME revive ID\n";
  }
  elsif ($command =~ /^(remove|rm)$/) {
    print "Removes selected item from the task list.\n";
    print "Usage: $NAME remove ID\n";
  }
  elsif ($command =~ /^undo$/) {
    print "Reverts last action.\n";
    print "Usage: $NAME undo\n";
  }
  elsif ($command =~ /^groups$/) {
    print "Displays groups in the task list.\n";
    print "Usage: $NAME groups\n";
  }
  elsif ($command =~ /^version$/) {
    print "Displays version information.\n";
    print "Usage: $NAME version\n";
  }
  elsif ($command =~ /^help$/) {
    print "Displays usage information.\n";
    print "Usage: $NAME help [COMMAND]\n";
  }
  else {
    print << "END_HELP";
Usage: $NAME [OPTION...] COMMAND [ARGUMENT...]

Commands:
  list [\@GROUP|%ID] [TEXT] display items in the task list
  add  [\@GROUP] TEXT       add new item to the task list
  change ID \@GROUP|TEXT    change item in the task list
  finish ID                finish item in the task list
  revive ID                revive item in the task list
  remove ID                remove item from the task list
  undo                     revert last action
  groups                   display groups in the task list
  help [COMMAND]           display usage information
  version                  display version information

Options:
  -c, --color, --colour    use coloured output; turned off by default
  -s, --savefile FILE      use selected file instead of default ~/.lite2do
  -f, --finished COLOUR    use selected colour for finished tasks; suppor-
                           ted options are: black, green, yellow, magenta,
                           red, blue, cyan, and white
  -u, --unfinished COLOUR  use selected colour for unfinished tasks
  -q, --quiet              avoid displaying unnecessary messages
  -h, --help               display this help and exit
  -v, --version            display version information and exit
END_HELP
  }

  # Return success:
  return 1;
}

# Display script version:
sub display_version {
  my ($NAME, $VERSION) = (NAME, VERSION);

  # Print message to the STDOUT:
  print << "END_VERSION";
$NAME $VERSION

Copyright (C) 2008, 2009 Jaromir Hradilek
This program is free software; see the source for copying conditions. It is
distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;
without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-
TICULAR PURPOSE.
END_VERSION

  # Return success:
  return 1;
}

# Load selected data from the save file:
sub load_selection {
  my ($selected, $rest, $id, $group, $task) = @_;

  # Escape reserved characters:
  $group =~ s/([\\\^\.\$\|\(\)\[\]\*\+\?\{\}])/\\$1/g if $group;
  $task  =~ s/([\\\^\.\$\|\(\)\[\]\*\+\?\{\}])/\\$1/g if $task;

  # Remove colons if any:
  $group =~ s/://g if $group;

  # Use default pattern when none is provided:
  $id    ||= '\d+';
  $group ||= '[^:]*';
  $task  ||= '';

  # Open the save file for reading:
  if (open(SAVEFILE, "$savefile")) {
    # Process each line:
    while (my $line = <SAVEFILE>) {
      # Check whether the line matches given pattern:
      if ($line =~ /^$group:[^:]*:[1-5]:[ft]:.*$task.*:$id$/i) {
        # Add the line to selected tasks:
        push(@$selected, $line);
      }
      else {
        # Add the line to unselected tasks:
        push(@$rest, $line);
      }
    }

    # Close the save file:
    close(SAVEFILE);
  }

  # Return success:
  return 1;
}

# Save given data to the save file:
sub save_data {
  my $data = shift || die 'Missing argument';

  # Backup the save file:
  copy($savefile, "$savefile$backext") if (-r $savefile);

  # Open the save file for writing:
  if (open(SAVEFILE, ">$savefile")) {
    # Write data to the save file:
    foreach my $line (@$data) {
      print SAVEFILE $line;
    }

    # Close the save file:
    close(SAVEFILE);
  }
  else {
    # Report failure and exit:
    exit_with_error("Unable to write to `$savefile'.", 13);
  }

  # Return success:
  return 1;
}

# Add given data to the end of the save file:
sub add_data {
  my $data = shift || die 'Missing argument';

  # Backup the save file:
  copy($savefile, "$savefile$backext") if (-r $savefile);

  # Open the save file for appending:
  if (open(SAVEFILE, ">>$savefile")) {
    # Write data to the save file:
    foreach my $line (@$data) {
      print SAVEFILE $line;
    }

    # Close the save file:
    close(SAVEFILE);
  }
  else {
    # Report failure and exit:
    exit_with_error("Unable to write to `$savefile'.", 13);
  }

  # Return success:
  return 1;
}

# Get hash of all groups:
sub get_groups {
  my %groups = ();

  # Open the save file for reading:
  if (open(SAVEFILE, "$savefile")) {
    # Build the list of used groups:
    while (my $line = <SAVEFILE>) {
      # Parse the task record:
      if ($line =~ /^([^:]*):/) {
        my $group = lc($1);

        # Check whether the group is already added:
        if ($groups{$group}) {
          # Increment the counter:
          $groups{$group} += 1;
        }
        else {
          # Initialize the counter:
          $groups{$group}  = 1;
        }
      }
    }

    # Close the save file:
    close(SAVEFILE);
  }

  # Return the result:
  return %groups;
}

# Choose first available ID:
sub choose_id {
  my @used   = ();
  my $chosen = 1;

  # Open the save file for reading:
  if (open(SAVEFILE, "$savefile")) {
    # Build the list of used IDs:
    while (my $line = <SAVEFILE>) {
      push(@used, int($1)) if ($line =~ /:(\d+)$/);
    }

    # Close the save file:
    close(SAVEFILE);

    # Find first unused ID:
    foreach my $id (sort {$a <=> $b} @used) {
      $chosen++ if ($chosen == $id);
    }
  }

  # Return the result:
  return $chosen;
}

# Fix the group name:
sub fix_group {
  my $group = shift || die 'Missing argument';

  # Check whether it contains forbidden characters:
  if ($group =~ /:/) {
    # Display warning:
    print STDERR "Colon is not allowed in the group name. Removing.\n";

    # Remove forbidden characters:
    $group =~ s/://g;
  }

  # Check the group name length:
  if (length($group) > 10) {
    # Display warning:
    print STDERR "Group name too long. Stripping.\n";

    # Strip it to the maximal allowed length:
    $group = substr($group, 0, 10);
  }

  # Make sure the result is not empty:
  unless ($group) {
    # Display warning:
    print STDERR "Group name is empty. Using the default group instead.\n";

    # Use default group instead:
    $group = 'general';
  }

  # Return the result:
  return $group;
}

# List items in the task list:
sub list_tasks {
  my ($group, $task, $id) = @_;
  my (@selected, $state);

  # Load matching tasks:
  load_selection(\@selected, undef, $id, $group, $task);

  # Check whether the list is not empty:
  if (@selected) {
    # Process each task:
    foreach my $line (sort @selected) {
      # Parse the task record:
      $line   =~ /^([^:]*):[^:]*:[1-5]:([ft]):(.*):(\d+)$/;
      $state  = ($2 eq 'f') ? '-' : 'f';
      
      # Check whether to use coloured output:
      if ($coloured) {
        # Decide which colour to use:
        my $colour = ($2 eq 'f') ? $undone : $done;

        # Print the task entry:
        print colored (sprintf("%2d. ", $4), "bold"),
              colored ("\@$1 ",              "bold $colour"),
              colored ("[$state]",           "bold"),
              colored (": $3",               "$colour"),
              "\n";
      }
      else {
        # Print the task entry:
        printf "%2d. @%s [%s]: %s\n", $4, $1, $state, $3;
      }
    }
  }
  else {
    # Report empty list:
    print "No matching task found.\n" if $verbose;
  }

  # Return success:
  return 1;
}

# List groups in the task list:
sub list_groups {
  # Get list of all groups:
  my %groups = get_groups();

  # Make sure the task list is not empty:
  if (scalar(keys %groups)) {
    # Display the list of groups:
    print join(', ', map { "$_ (" . $groups{$_} . ")" }
                     sort keys(%groups)), "\n";
  }
  else {
    # Report empty list:
    print "No matching task found.\n" if $verbose;
  }

  # Return success:
  return 1;
}

# Add new item to the task list:
sub add_task {
  my $task  = shift || die 'Missing argument';
  my $group = shift || 'general';
  my $id    = choose_id();

  # Create the task record:
  my @data  = (fix_group($group) . ":anytime:3:f:$task:$id\n");

  # Add data to the end of the save file:
  add_data(\@data);

  # Report success:
  print "Task has been successfully added with id $id.\n" if $verbose;

  # Return success:
  return 1;
}

# Change selected item in the task list:
sub change_task {
  my $id    = shift || die 'Missing argument';
  my $text  = shift || die 'Missing argument';
  my $group = shift || 0;
  my (@selected, @rest);

  # Load tasks:
  load_selection(\@selected, \@rest, $id);

  # Check whether the list is not empty:
  if (@selected) {
    # Parse the task record:
    pop(@selected) =~ /^([^:]*):([^:]*):([1-5]):([ft]):(.*):\d+$/;

    # Decide which part to edit:
    unless ($group) {
      # Update the task record:
      push(@rest, "$1:$2:$3:$4:$text:$id\n");
    }
    else {
      # Update the group record:
      push(@rest, fix_group($text) . ":$2:$3:$4:$5:$id\n");
    }

    # Store data to the save file:
    save_data(\@rest);

    # Report success:
    print "Task has been successfully changed.\n" if $verbose;
  }
  else {
    # Report empty list:
    print "No matching task found.\n" if $verbose;
  }

  # Return success:
  return 1;
}

# Mark selected item in the task list as finished:
sub finish_task {
  my $id = shift || die 'Missing argument';
  my (@selected, @rest);

  # Load tasks:
  load_selection(\@selected, \@rest, $id);

  # Check whether the list is not empty:
  if (@selected) {
    # Parse the task record:
    pop(@selected) =~ /^([^:]*):([^:]*):([1-5]):[ft]:(.*):\d+$/;

    # Update the task record:
    push(@rest, "$1:$2:$3:t:$4:$id\n");

    # Store data to the save file:
    save_data(\@rest);

    # Report success:
    print "Task has been finished.\n" if $verbose;
  }
  else {
    # Report empty list:
    print "No matching task found.\n" if $verbose;
  }

  # Return success:
  return 1;
}

# Mark selected item in the task list as unfinished:
sub revive_task {
  my $id = shift || die 'Missing argument';
  my (@selected, @rest);

  # Load tasks:
  load_selection(\@selected, \@rest, $id);

  # Check whether the list is not empty:
  if (@selected) {
    # Parse the task record:
    pop(@selected) =~ /^([^:]*):([^:]*):([1-5]):[ft]:(.*):\d+$/;

    # Update the task record:
    push(@rest, "$1:$2:$3:f:$4:$id\n");

    # Store data to the task list:
    save_data(\@rest);

    # Report success:
    print "Task has been revived.\n" if $verbose;
  }
  else {
    # Report empty list:
    print "No matching task found.\n" if $verbose;
  }

  # Return success:
  return 1;
}

# Remove selected item from the task list:
sub remove_task {
  my $id = shift || die 'Missing argument';
  my (@selected, @rest);

  # Load tasks:
  load_selection(\@selected, \@rest, $id);

  # Check whether the list is not empty:
  if (@selected) {
    # Store data to the save file:
    save_data(\@rest);

    # Report success:
    print "Task has been successfully removed.\n" if $verbose;
  }
  else {
    # Report empty list:
    print "No matching task found.\n" if $verbose;
  }

  # Return success:
  return 1;
}

# Revert last action:
sub revert_last_action {
  # Try to restore data from tha backup:
  if (move("$savefile$backext", $savefile)) {
    # Report success:
    print "Last action has been successfully reverted.\n" if $verbose;
  }
  else {
    # Report failure:
    print "Already at oldest change.\n" if $verbose;
  }

  # Return success:
  return 1;
}

# Set up the option parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Parse command line options:
GetOptions(
  # General options:
  'help|h'         => sub { display_help();    exit 0 },
  'version|v'      => sub { display_version(); exit 0 },

  # Additional options:
  'verbose|V'      => sub { $verbose  = 1 },
  'quiet|q'        => sub { $verbose  = 0 },
  'colour|color|c' => sub { $coloured = 1 },
  'plain|p'        => sub { $coloured = 0 },
  'savefile|s=s'   => \$savefile,
  'finished|f=s'   => \$done,
  'unfinished|u=s' => \$undone,
);

# Check whether the supplied colour is valid:
unless ((!$done || $valid{$done}) && (!$undone || $valid{$undone})) {
  exit_with_error("Invalid colour option.\n" .
                  "Try `--help' for more information.", 22);
}

# Get command line arguments:
$command = join(' ', @ARGV);

# Parse command:
if    ($command =~ /^(|list|ls)\s*$/) {
  # List all items in the task list:
  list_tasks();
}
elsif ($command =~ /^(list|ls)\s+@(\S+)\s*(\S.*|)$/) {
  # List items in the selected group, optionally matching the pattern:
  list_tasks($2, $3);
}
elsif ($command =~ /^(list|ls)\s+%(\d+)/) {
  # List item with selected ID:
  list_tasks(undef, undef, $2);
}
elsif ($command =~ /^(list|ls)\s+([^@^%\s].*)$/) {
  # List items matching the pattern:
  list_tasks(undef, $2);
}
elsif ($command =~ /^add\s+@(\S+)\s+(\S.*)/) {
  # Add new item to the task list, belonging to the selected group:
  add_task($2, $1);
}
elsif ($command =~ /^add\s+([^@\s].*)/) {
  # Add new item to the task list, belonging to the default group:
  add_task($1);
}
elsif ($command =~ /^(change|mv)\s+%?(\d+)\s+@(\S+)\s*$/) {
  # Change group the selected item in the task list belongs to:
  change_task($2, $3, 1);
}
elsif ($command =~ /^(change|mv)\s+%?(\d+)\s+([^@\s].*)/) {
  # Change selected item in the task list:
  change_task($2, $3);
}
elsif ($command =~ /^(finish|fn)\s+%?(\d+)/) {
  # Mark selected item in the task list as finished:
  finish_task($2);
}
elsif ($command =~ /^(revive|re)\s+%?(\d+)/) {
  # Mark selected item in the task list as unfinished:
  revive_task($2);
}
elsif ($command =~ /^(remove|rm)\s+%?(\d+)/) {
  # Remove selected item from the task list:
  remove_task($2);
}
elsif ($command =~ /^undo\s*$/) {
  # Revert last action:
  revert_last_action();
}
elsif ($command =~ /^groups\s*$/) {
  # Display groups in the task list:
  list_groups();
}
elsif ($command =~ /^version\s*$/) {
  # Display version information:
  display_version();
}
elsif ($command =~ /^help\s*$/) {
  # Display list of all supported commands and command-line options:
  display_help();
}
elsif ($command =~ /^help\s+(\S+)/) {
  # Display information on a specific command:
  display_help($1);
}
else  {
  # Report invalid command:
  exit_with_error("Invalid command or argument.\n" .
                  "Try `--help' for more information.", 22);
}

# Return success:
exit 0;

__END__

=head1 NAME

lite2do - a lightweight text-based todo manager

=head1 SYNOPSIS

B<lite2do> [I<option>...] I<command> [I<argument>...]

B<lite2do> B<-h> | B<-v>

=head1 DESCRIPTION

B<lite2do> is a lightweight command-line todo manager written in Perl.
Being based on w2do and fully compatible with its save file format, it
tries to provide much simpler alternative for those who do not appreciate
nor require w2do's complexity.

=head1 COMMANDS

=over

=item B<list> [@I<group>] [I<text>...]

=item B<ls> [@I<group>] [I<text>...]

Display items in the task list. All tasks are listed by default, but
desired subset can be easily selected giving a I<group> name, I<text>
pattern, or combination of both.

=item B<list> %I<id>

=item B<ls> %I<id>

Display task with selected I<id>.

=item B<add> [@I<group>] I<text>...

Add new item to the task list.

=item B<change> I<id> I<text>...

=item B<mv> I<id> I<text>...

Change item with selected I<id> in the task list.

=item B<change> I<id> @I<group>

=item B<mv> I<id> @I<group>

Change I<group> the item with selected I<id> belongs to.

=item B<finish> I<id>

=item B<fn> I<id>

Mark item with selected I<id> as finished.

=item B<revive> I<id>

=item B<re> I<id>

Mark item with selected I<id> as unfinished.

=item B<remove> I<id>

=item B<rm> I<id>

Remove item with selected I<id> from the task list.

=item B<undo>

Revert last action. When invoked, the data are restored from the backup
file (i.e. I<~/.lite2do.bak> by default), which is deleted at the same
time.

=item B<groups>

Display list of groups in the task list along with the number of tasks
belonging to them.

=item B<help> [I<command>]

Display usage information. By default, list of all supported commands and
command-line options is displayed. If the I<command> is supplied, further
information on its usage are displayed instead.

=item B<version>

Display version information.

=back

=head1 OPTIONS

=over

=item B<-s> I<file>, B<--savefile> I<file>

Use selected I<file> instead of the default I<~/.lite2do> as a save file.

=item B<-c>, B<--colour>, B<--color>

Use coloured output.

=item B<-p>, B<--plain>

Use plain-text output; this is the default behaviour, as most users do not
usually fancy having bright colours in their terminal.

=item B<-f> I<colour>, B<--finished> I<colour>

Use selected I<colour> for finished tasks; available options are: B<black>,
B<red>, B<green>, B<yellow>, B<blue>, B<magenta>, B<cyan> and B<white>.

=item B<-u> I<colour>, B<--unfinished> I<colour>

Use selected I<colour> for unfinished tasks; available options are:
B<black>, B<red>, B<green>, B<yellow>, B<blue>, B<magenta>, B<cyan> and
B<white>.

=item B<-q>, B<--quiet>

Avoid displaying messages that are not necessary.

=item B<-V>, B<--verbose>

Display all messages; this is the default behaviour.

=item B<-h>, B<--help>

Display help message and exit.

=item B<-v>, B<--version>

Display version information and exit.

=back

=head1 FILES

=over

=item I<~/.lite2do>

Default save file.

=item I<~/.lite2do.bak>

Default backup file.

=back

=head1 SEE ALSO

B<w2do>(1), B<w2html>(1), B<w2text>(1), B<perl>(1).

=head1 BUGS

To report bugs or even send patches, you can either add new issue to the
project bugtracker at <http://code.google.com/p/w2do/issues/>, visit the
discussion group at <http://groups.google.com/group/w2do/>, or you can
contact the author directly via e-mail.

=head1 AUTHOR

Written by Jaromir Hradilek <jhradilek@gmail.com>.

Permission is granted to copy, distribute and/or modify this document under
the terms of the GNU Free Documentation License, Version 1.3 or any later
version published by the Free Software Foundation; with no Invariant
Sections, no Front-Cover Texts, and no Back-Cover Texts.

A copy of the license is included as a file called FDL in the main
directory of the lite2do source package.

=head1 COPYRIGHT

Copyright (C) 2008, 2009 Jaromir Hradilek

This program is free software; see the source for copying conditions. It is
distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.

=cut
