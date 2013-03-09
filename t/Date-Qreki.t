use warnings;
use strict;
use Test::More;
BEGIN { use_ok('Date::Qreki') };
use Date::Qreki qw/calc_kyureki get_rokuyou/;

check ([1966, 3, 16], [1966, 0, 2, 25], 3);
check ([1996, 10, 17], [1996, 0, 9, 6], 3);
check ([996, 1, 17], [995, 0, 12, 19], 1);
# Date of changeover to Gregorian calendar in Japan.
# According to http://ja.wikipedia.org/wiki/%E6%97%A7%E6%9A%A6.
check ([1873, 1, 1], [1872, 0, 12, 3], 3);


done_testing ();

sub check
{
    my ($dates, $expect, $expect_rokuyou) = @_;
    my @kyureki = calc_kyureki (@$dates);
    is_deeply (\@kyureki, $expect, "Test kyureki");
    my $rokuyou = get_rokuyou (@$dates);
    is ($rokuyou, $expect_rokuyou, "Test rokuyou");
}

# Local variables:
# mode: perl
# End:
