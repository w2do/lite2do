#!/usr/bin/env perl

# lite2do, a lightweight text-based todo manager
# Copyright (C) 2008 Jaromir Hradilek

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
our $NAME      = basename($0, '.pl');                     # Script name.
our $VERSION   = '0.1.1';                                 # Script version.

# General script settings:
our $HOMEDIR   = $ENV{HOME} || $ENV{USERPROFILE} || '.';  # Home directory.
our $savefile  = catfile($HOMEDIR, '.lite2do');           # Save file name.
our $backext   = '.bak';                                  # Backup  suffix.
our $coloured  = 0;                                       # Set up colours.

# Colours settings:
our $done      = 'green';                                 # Finished tasks.
our $undone    = 'magenta';                               # Undone tasks.

# Command line options:
my ($command, $response);

# Signal handlers:
$SIG{__WARN__} = sub {
  exit_with_error((shift) . "Try `--help' for more information.", 22);
};

# Load selected data from the save file:
sub load_selection {
  my ($selected, $rest, $id, $group, $task) = @_;

  $group =~ s/([\\\^\.\$\|\(\)\[\]\*\+\?\{\}])/\\$1/g if $group;
  $task  =~ s/([\\\^\.\$\|\(\)\[\]\*\+\?\{\}])/\\$1/g if $task;

  $id    ||= '\d+';
  $group ||= '[^:]*';
  $task  ||= '';

  if (open(SAVEFILE, "$savefile")) {
    while (my $line = <SAVEFILE>) {
      if ($line =~ /^$group:[^:]*:[1-5]:[ft]:.*$task.*:$id$/i) {
        push(@$selected, $line);
      }
      else {
        push(@$rest, $line);
      }
    }

    close(SAVEFILE);
  }
}

# Save given data to the save file:
sub save_data {
  my $data = shift;

  copy($savefile, "$savefile$backext") if (-r $savefile);

  if (open(SAVEFILE, ">$savefile")) {
    foreach my $line (@$data) {
      print SAVEFILE $line;
    }

    close(SAVEFILE);
  }
  else {
    exit_with_error("Unable to write to `$savefile'.", 13);
  }
}

# Add given data to the end of the save file:
sub add_data {
  my $data = shift;

  copy($savefile, "$savefile$backext") if (-r $savefile);

  if (open(SAVEFILE, ">>$savefile")) {
    foreach my $line (@$data) {
      print SAVEFILE $line;
    }

    close(SAVEFILE);
  }
  else {
    exit_with_error("Unable to write to `$savefile'.", 13);
  }
}

# Choose first available ID:
sub choose_id {
  my @used   = ();
  my $chosen = 1;

  if (open(SAVEFILE, "$savefile")) {
    while (my $line = <SAVEFILE>) {
      push(@used, int($1)) if ($line =~ /:(\d+)$/);
    }

    close(SAVEFILE);

    foreach my $id (sort {$a <=> $b} @used) {
      $chosen++ if ($chosen == $id);
    }
  }

  return $chosen;
}

# Display script help:
sub display_help {
  print << "END_HELP"
Usage: $NAME [options] command [arguments]
       $NAME -h | -v

Commands:
  list [\@group] [text...]  display items in the task list
  add  [\@group] text...    add new item to the task list
  change id text...        change item in the task list
  finish id                finish item in the task list
  revive id                revive item in the task list
  remove id                remove item from the task list
  undo                     revert last action

Options:
  -c, --colour             use coloured output; turned off by default
  -s, --savefile file      use selected file instead of default ~/.lite2do
  -f, --finished colour    use selected colour for finished tasks; suppor-
                           ted options are: black, green, yellow, magenta,
                           red, blue, cyan, and white
  -u, --unfinished colour  use selected colour for unfinished tasks
  -h, --help               display this help and exit
  -v, --version            display version information and exit
END_HELP
}

# Display script version:
sub display_version {
  print << "END_VERSION";
$NAME $VERSION

Copyright (C) 2008 Jaromir Hradilek
This program is free software; see the source for copying conditions. It is
distributed in the hope  that it will be useful,  but WITHOUT ANY WARRANTY;
without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PAR-
TICULAR PURPOSE.
END_VERSION
}

# List items in the task list:
sub list_tasks {
  my ($group, $task) = @_;
  my (@selected, $state);

  load_selection(\@selected, undef, undef, $group, $task);

  if (@selected) {
    foreach my $line (sort @selected) {
      $line   =~ /^([^:]*):[^:]*:[1-5]:([ft]):(.*):(\d+)$/;
      $state  = ($2 eq 'f') ? '-' : 'f';
      
      if ($coloured) {
        my $colour = ($2 eq 'f') ? $undone : $done;
        print  colored (sprintf("%2d. ", $4), "bold"),
               colored ("\@$1 ",              "bold $colour"),
               colored ("[$state]",           "bold"),
               colored (": $3",               "$colour"),
               "\n";
      }
      else {
        printf "%2d. @%s [%s]: %s\n", $4, $1, $state, $3;
      }
    }
  }
  else {
    print "No matching task found.\n";
  }
}

# Add new item to the task list:
sub add_task {
  my $task  = shift || '';
  my $group = shift || 'general';
  my $id    = choose_id();

  my @data  = (substr($group, 0, 10) . ":anytime:3:f:$task:$id\n");

  add_data(\@data);
  print "Task has been successfully added with id $id.\n";
}

# Change selected item in the task list:
sub change_task {
  my ($id, $task) = @_;
  my (@selected, @rest);

  load_selection(\@selected, \@rest, $id);

  if (@selected) {
    pop(@selected) =~ /^([^:]*):([^:]*):([1-5]):([ft]):.*:\d+$/;
    push(@rest, "$1:$2:$3:$4:$task:$id\n");

    save_data(\@rest);
    print "Task has been successfully changed.\n";
  }
  else {
    print "No matching task found.\n";
  }
}

# Mark selected item in the task list as finished:
sub finish_task {
  my $id = shift;
  my (@selected, @rest);

  load_selection(\@selected, \@rest, $id);

  if (@selected) {
    pop(@selected) =~ /^([^:]*):([^:]*):([1-5]):[ft]:(.*):\d+$/;
    push(@rest, "$1:$2:$3:t:$4:$id\n");

    save_data(\@rest);
    print "Task has been finished.\n";
  }
  else {
    print "No matching task found.\n";
  }
}

# Mark selected item in the task list as unfinished:
sub revive_task {
  my $id = shift;
  my (@selected, @rest);

  load_selection(\@selected, \@rest, $id);

  if (@selected) {
    pop(@selected) =~ /^([^:]*):([^:]*):([1-5]):[ft]:(.*):\d+$/;
    push(@rest, "$1:$2:$3:f:$4:$id\n");

    save_data(\@rest);
    print "Task has been revived.\n";
  }
  else {
    print "No matching task found.\n";
  }
}

# Remove selected item from the task list:
sub remove_task {
  my $id = shift;
  my (@selected, @rest);

  load_selection(\@selected, \@rest, $id);

  if (@selected) {
    save_data(\@rest);
    print "Task has been successfully removed.\n";
  }
  else {
    print "No matching task found.\n";
  }
}

# Revert last action:
sub revert_last_action {
  if (move("$savefile$backext", $savefile)) {
    print "Last action has been successfully reverted.\n";
  }
  else {
    print "Already at oldest change.\n";
  }
}

# Display given message and immediately terminate the script:
sub exit_with_error {
  my $message = shift || 'An unspecified error has occured.';
  my $retval  = shift || 1;

  print STDERR "$NAME: $message\n";
  exit $retval;
}

# Set up the option parser:
Getopt::Long::Configure('no_auto_abbrev', 'no_ignore_case', 'bundling');

# Parse command line options:
GetOptions(
  'savefile|s=s'   => \$savefile,
  'colour|color|c' => \$coloured,
  'finished|f=s'   => \$done,
  'unfinished|u=s' => \$undone,

  'help|h'         => sub { display_help();    exit 0 },
  'version|v'      => sub { display_version(); exit 0 },
);

# Get command line arguments:
$command = join(' ', @ARGV);

# Parse command:
if    ($command =~ /^(|list)\s*$/)              { list_tasks(); }
elsif ($command =~ /^list\s+@(\S+)\s*(\S.*|)$/) { list_tasks($1, $2); }
elsif ($command =~ /^list\s+(\S.*)$/)           { list_tasks(undef, $1); }
elsif ($command =~ /^add\s+@(\S+)\s+(\S.*)/)    { add_task($2, $1); }
elsif ($command =~ /^add\s+(\S.*)/)             { add_task($1); }
elsif ($command =~ /^change\s+(\d+)\s+(\S.*)/)  { change_task($1, $2); }
elsif ($command =~ /^finish\s+(\d+)/)           { finish_task($1); }
elsif ($command =~ /^revive\s+(\d+)/)           { revive_task($1); }
elsif ($command =~ /^remove\s+(\d+)/)           { remove_task($1); }
elsif ($command =~ /^undo\s*$/)                 { revert_last_action(); }
else  {
  exit_with_error("Invalid command: $command\n" .
                  "Try `--help' for more information.", 22);
}

# Return success:
exit 0;
