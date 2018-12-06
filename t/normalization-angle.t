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

# Test documentation claims

cmp_ok (Date::Qreki::nangle (360.0), '==', 0.0);
cmp_ok (Date::Qreki::nangle (0.0), '==', 0.0);
cmp_ok (Date::Qreki::nangle (180.0), '==', 180.0);
cmp_ok (Date::Qreki::nangle (540.0), '==', 180.0);

done_testing ();
