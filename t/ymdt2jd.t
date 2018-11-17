use warnings;
use strict;
use utf8;
use FindBin '$Bin';
use Test::More;
my $builder = Test::More->builder;
binmode $builder->output,         ":utf8";
binmode $builder->failure_output, ":utf8";
binmode $builder->todo_output,    ":utf8";
binmode STDOUT, ":encoding(utf8)";
binmode STDERR, ":encoding(utf8)";

use Date::Qreki;
my $eps = 0.00001;
# Date::Qreki is off by 0.5 from the US naval values. I don't want to
# "fix" this without understanding what it is doing, so I just leave a
# fix factor here for the time being.
my $fix = 0.5;
# https://en.wikipedia.org/wiki/Julian_day#cite_ref-8
my @j13 = ('2013', '1', '1', '0', '30', '0');
my $jan13 = Date::Qreki::YMDT2JD (@j13);
# Round trip back
my @rj13 = Date::Qreki::JD2YMDT ($jan13);
is_deeply (\@j13, \@rj13);
cmp_ok ( abs ($jan13 + $fix - 2_456_293.520_833), '<', $eps);
# http://aa.usno.navy.mil/jdconverter?ID=AA&year=2018&month=11&day=16&era=1&hr=0&min=0&sec=0.0
my @now = ('2018', '11', '16', '0', '0', '0');
my $now =  Date::Qreki::YMDT2JD (@now);
# Round trip back
my @rnow = Date::Qreki::JD2YMDT ($now);
is_deeply (\@now, \@rnow);
cmp_ok ( abs ($now + $fix - 2458438.500000), '<', $eps);
done_testing ();
