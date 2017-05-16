#!/usr/bin/perl
# made by: KorG

use strict;
use v5.18;
use warnings;
no warnings 'experimental';
use utf8;
binmode STDOUT, ':utf8';
$| = 1; $\ = "\n";

use threads;
use threads::shared;
use Time::HiRes 'usleep';
use WWW::Telegram::BotAPI;
use Net::Jabber::Bot;
use Storable;

my $config_file = './config.pl';
our %cfg;

unless (my $rc = do $config_file) {
   warn "couldn't parse $config_file: $@" if $@;
   warn "couldn't do $config_file: $!" unless defined $rc;
   warn "couldn't run $config_file" unless $rc;
}

# DEFAULT VALUES. don't change them here
# see comments in the 'config.pl'
my $name          = $cfg{name}            // 'PodBot';
my $alias         = $cfg{alias}           // '>';
my $server        = $cfg{server}          // 'zhmylove.ru';
my $port          = $cfg{port}            // 5222;
my $username      = $cfg{username}        // 'jxtg';
my $password      = $cfg{password}        // 'password';
my $tg_name       = $cfg{tg_name}         // '@korg_jxtg_bot';
my $tg_chat_id    = $cfg{tg_chat_id}      // 1;
my $token         = $cfg{token}           // 'token';
my $sleep_usec    = $cfg{sleep_usec}      // 500000;
my $conference_server   = $cfg{conference_server}  // 'conference.jabber.ru';
my %room_passwords      = %{ $cfg{room_passwords}  // {
   'ubuntulinux' => 'ubuntu'
}};

# INTERNAL VARIABLES
my @tg_queue :shared; share(@tg_queue);
my @ja_queue :shared; share(@ja_queue);
my $start_time = time;
my %room_list;
$room_list{$_} = [] for keys %room_passwords; # [] due to Bot.pm.patch

$SIG{INT} = sub { print "Uptime: ", time - $start_time ; exit 0; };

# PREPARE THREADS
my @T = qw/thr_tg thr_ja thr_q_tg thr_q_ja/;
my %T; $T{$_} = threads->create(\&{$_}) for @T;
my $thr_mon  = threads->create(\&thr_mon);

$T{$_}->join() for @T;
$thr_mon->join();

# SELF MONITOR THREAD
sub thr_mon {
   sleep(60); # initial sleep
   print "Started self-monitor thread";
   for(;;sleep(15)){
      my $count = eval join "+", map {$T{$_}->is_running()} @T;
      if (0+@T != $count) {
         print "Self-monitor: threads: $count / " . 0+@T;
         exit(0x13);
      }
   }
}

# TELEGRAM THREAD
sub thr_q_tg {
   # fucking shity Chineese code ;-(
   my $tg = WWW::Telegram::BotAPI->new(token=>$token);
   print "Started telegram sender";
   die "Name mismatch: $name" if $name ne $tg->getMe->{result}{first_name};
   do {
      while(defined(my $msg = shift @tg_queue)){
         $tg->sendMessage({
               chat_id => $tg_chat_id,
               parse_mode => "HTML",
               text => $msg,
            });
      }
   } while(usleep($sleep_usec), 1);

   # should never reach
   exit(0x33);
}

# JABBER THREAD
sub thr_q_ja {
   # fucking shity Chineese code ;-(
   my $bot = Net::Jabber::Bot->new(
      server => $server,
      conference_server => $conference_server,
      port => $port,
      username => $username,
      password => $password,
      alias => $alias,
      resource => $name . "_sender",
      safety_mode => 1,
      message_function => sub {undef},
      loop_sleep_time => 60,
      forums_and_responses => \%room_list,
      forums_passwords => \%room_passwords,
      JidDB => {},
      SayToDB => {},
   );

   $bot->max_messages_per_hour(7200);
   print "Started jabber sender";

   my $dst = (keys %room_passwords)[0] . "\@$conference_server";

   do {
      while(defined(my $msg = shift @ja_queue)){
         $bot->SendGroupMessage($dst, $msg);
      }
   } while(usleep($sleep_usec), 1);

   # should never reach
   exit(0x17);
}

sub thr_tg {
   # fucking shity Chineese code ;-(
   my $tg = WWW::Telegram::BotAPI->new(token=>$token);
   print "Started telegram listener";
   die "Name mismatch: $name" if $name ne $tg->getMe->{result}{first_name};

   my $updates = 0;
   my $starting = 1;
   my $offset = 0;

   for(;;) {
      $updates = $tg->getUpdates ({
            timeout => 30,
            $offset ? (offset => $offset) : ()
         });

      next unless (defined $updates && $updates &&
         (ref $updates eq "HASH") && $updates->{ok});

      for my $upd (@{ $updates->{result} }) {
         $offset = $upd->{update_id} + 1 if $upd->{update_id} >= $offset;

         if ($starting) {
            next unless (($upd->{message}{date} // 0) >= $start_time);
            $starting = 0;
         }

         next unless (my $text = $upd->{message}{text});

         next if $upd->{message}{chat}{id} ne $tg_chat_id;

         my $src = join " ", $upd->{message}{from}{first_name},
         $upd->{message}{from}{last_name} // '';

         if (defined $upd->{message}{reply_to_message}) {
            my $reply = join " ",
            $upd->{message}{reply_to_message}{from}{first_name},
            $upd->{message}{reply_to_message}{from}{last_name} // '';

            if (
               $tg_name eq
               '@' . ($upd->{message}{reply_to_message}{from}{username} // '')
            ) {
               # assuming my messages are only text
               if (defined $upd->{message}{reply_to_message}{text}) {
                  ($reply) =
                  $upd->{message}{reply_to_message}{text} =~ m/^([^:]+):/;
               }
            }

            $src .= ": $reply"
         }

         # Ehhh~~! Ugly code ;-(
         $src =~ s/ +/ /g;
         $src =~ s/ (?=(:|$))//g;

         push @ja_queue, "$src: " . $text;
      }
   }

   # should never reach
   exit(0x32);
}

sub process_ja_msg {
   my %msg = @_;
   my $src = (split '/', $msg{'from_full'})[1] // return;

   return if $src eq $alias or $src eq $name;

   my $text = $msg{'body'};
   $text =~ s/</^/g;
   $text =~ s/>/^/g;
   $text =~ s/&/./g;

   push @tg_queue, "<b>$src</b>: " . $text;
}

sub thr_ja {
   # fucking shity Chineese code ;-(
   my $bot = Net::Jabber::Bot->new(
      server => $server,
      conference_server => $conference_server,
      port => $port,
      username => $username,
      password => $password,
      alias => $alias,
      resource => $name . "_listener",
      safety_mode => 1,
      message_function => \&process_ja_msg,
      loop_sleep_time => 60,
      forums_and_responses => \%room_list,
      forums_passwords => \%room_passwords,
      JidDB => {},
      SayToDB => {},
   );

   $bot->max_messages_per_hour(7200);
   print "Started jabber listener";
   $bot->Start();

   # should never reach
   exit(0x16);
}
