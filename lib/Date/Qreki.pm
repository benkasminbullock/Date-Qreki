package Date::Qreki;
use warnings;
use strict;
use utf8;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw/calc_kyureki get_rokuyou rokuyou_unicode check_24sekki/;
our %EXPORT_TAGS = (all => \@EXPORT_OK);
our $VERSION = '0.08';


# 旧暦計算サンプルプログラム  $Revision:   1.1  $
# Coded by H.Takano 1993,1994
#
# Arranged for Perl Script by N.Ueno
# 
# 
# オリジナルのスクリプトは高野氏のAWKです。下記より入手できます。
# http://www.vector.co.jp/soft/dos/personal/se016093.html
#
#
#========================================================================

#-----------------------------------------------------------------------
# 円周率の定義と（角度の）度からラジアンに変換する係数の定義
#-----------------------------------------------------------------------
use constant PI => 3.141592653589793238462;
use constant k => PI/180.0;

# Approximate Sidereal Time
# http://aa.usno.navy.mil/faq/docs/GAST.php

use constant jan1_2000 => 2451545.0;
use constant japan => 9.0/24.0;

# Cosine of angle in degrees, rather than radians.

sub deg_cos
{
    my ($angle) = @_;
    return cos ($angle * k);
}


# 六曜算出関数
#
# 引数：新暦年月日
# 戻値：0:大安 1:赤口 2:先勝 3:友引 4:先負 5:仏滅
#


sub get_rokuyou
{
    my ($year,$mon,$day) = @_;
    my (undef,undef,$q_mon,$q_day) = calc_kyureki($year,$mon,$day);
    return(($q_mon + $q_day) % 6);
}

sub rokuyou_unicode
{
    my ($year,$mon,$day) = @_;
    my (undef,undef,$q_mon,$q_day) = calc_kyureki($year,$mon,$day);
    return (qw/大安 赤口 先勝 友引 先負 仏滅/)[(($q_mon + $q_day) % 6)];
}


# 新暦に対応する、旧暦を求める。
#
# 呼び出し時にセットする変数
# 引　数　year : 計算する日付
#         mon
#         day
#
# 戻り値　kyureki : 答えの格納先（配列に答えをかえす）
#         　　  kyureki[0] : 旧暦年
#         　　  kyureki[1] : 平月／閏月 flag .... 平月:0 閏月:1
#         　　  kyureki[2] : 旧暦月
#         　　  kyureki[3] : 旧暦日
#


sub calc_kyureki
{
    my ($year, $mon, $day) = @_;
    my (@kyureki, $tm, @saku, $lap, @a, $i, @m);
    my $tm0 = YMDT2JD ($year,$mon,$day,0,0,0);

    # 計算対象の直前にあたる二分二至の時刻を求める

    # chu[0,0]:二分二至の時刻  chu[0,1]:その時の太陽黄経

    my @chu;
    ($chu[0][0],$chu[0][1]) = before_nibun($tm0);

    # 中気の時刻を計算（４回計算する）

    # chu[i,0]:中気の時刻  chu[i,1]:太陽黄経

    for($i=1;$i<4;$i++){
	($chu[$i][0],$chu[$i][1]) = calc_chu($chu[$i-1][0]+32.0);
    }

    #  計算対象の直前にあたる二分二至の直前の朔の時刻を求める

    $saku[0] = calc_saku($chu[0][0]);


    # 朔の時刻を求める

    for ($i=1;$i<5;$i++) {
	$tm=$saku[$i-1];
	$tm += 30.0;
	$saku[$i]=calc_saku($tm);

	# 前と同じ時刻を計算した場合（両者の差が26日以内）には、初期値を
	# +33日にして再実行させる。
	if ( abs( int($saku[$i-1])-int($saku[$i]) ) <= 26.0 ) {
	    $saku[$i]=calc_saku($saku[$i-1]+35.0);
	}
    }

    # saku[1]が二分二至の時刻以前になってしまった場合には、朔をさかのぼり過ぎ
    # たと考えて、朔の時刻を繰り下げて修正する。

    # その際、計算もれ（saku[4]）になっている部分を補うため、朔の時刻を計算
    # する。（近日点通過の近辺で朔があると起こる事があるようだ...？）

    if ( int($saku[1]) <= int($chu[0][0]) ) {
	for ($i=0;$i<5;$i++) {
	    $saku[$i]=$saku[$i+1];
	}
	$saku[4] = calc_saku($saku[3]+35.0);
    }


# saku[0]が二分二至の時刻以後になってしまった場合には、朔をさかのぼり足
# りないと見て、朔の時刻を繰り上げて修正する。
# その際、計算もれ（saku[0]）になっている部分を補うため、朔の時刻を計算
# する。（春分点の近辺で朔があると起こる事があるようだ...？）

    elsif ( int($saku[0]) > int($chu[0][0]) ) {
	for ($i=4;$i>0;$i--) {
	    $saku[$i] = $saku[$i-1];
	}
	$saku[0] = calc_saku($saku[0]-27.0);
    }


# 閏月検索Ｆｌａｇセット
# （節月で４ヶ月の間に朔が５回あると、閏月がある可能性がある。）
# lap=0:平月  lap=1:閏月

    if (int($saku[4]) <= int($chu[3][0]) ) {
	$lap=1;
    }
    else {
	$lap=0;
    }


# 朔日行列の作成
# m[i,0] ... 月名（1:正月 2:２月 3:３月 ....）
# m[i,1] ... 閏フラグ（0:平月 1:閏月）
# m[i,2] ... 朔日のjd

    $m[0][0]=int($chu[0][1]/30.0) + 2;
    if (defined $m[0][1] && $m[0][1] > 12 ) {
	$m[0][0]-=12;
    }
    $m[0][2]=int($saku[0]);
    $m[0][1]=0;

    for ($i=1;$i<5;$i++) {
	if ($lap == 1 && $i !=1 ) {
	    if ( int($chu[$i-1][0]) <= int($saku[$i-1]) || int($chu[$i-1][0]) >= int($saku[$i]) ) {
		$m[$i-1][0] = $m[$i-2][0];
		$m[$i-1][1] = 1;
		$m[$i-1][2] = int($saku[$i-1]);
		$lap=0;
	    }
	}
	$m[$i][0] = $m[$i-1][0]+1;
	if ( $m[$i][0] > 12 ) {
	    $m[$i][0]-=12;
	}
	$m[$i][2]=int($saku[$i]);
	$m[$i][1]=0;
    }


# 朔日行列から旧暦を求める。

    my $state=0;
    for ($i=0;$i<5;$i++) {
	if (int($tm0) < int($m[$i][2])) {
	    $state=1;
	    last;
	}
	elsif (int($tm0) == int($m[$i][2])) {
	    $state=2;
	    last;
	}
    }
    if ($state==0||$state==1) {
	$i--;
    }

    $kyureki[1]=$m[$i][1];
    $kyureki[2]=$m[$i][0];
    $kyureki[3]=int($tm0)-int($m[$i][2])+1;


# 旧暦年の計算
# （旧暦月が10以上でかつ新暦月より大きい場合には、
#   まだ年を越していないはず...）


    @a = JD2YMDT($tm0);
    $kyureki[0] = $a[0];
    if ($kyureki[2] > 9 && $kyureki[2] > $a[1]) {
	$kyureki[0]--;
    }

    return @kyureki;
}

use constant century => 36525.0;
use constant day => 86400.0;


# 中気の時刻を求める
# 
# 呼び出し時にセットする変数
# tm ........ 計算対象となる時刻（ユリウス日）
# chu ....... 戻り値を格納する配列のポインター
# i ......... 戻り値を格納する配列の要素番号
# 戻り値 .... 中気の時刻、その時の黄経を配列で渡す
#


# 中気 = "every second solar term" according to wwwjdic.

sub calc_chu
{
    my ($tm) = @_;
    my ($tm1,$tm2,$t,$rm_sun0,$rm_sun,$delta_t1,$delta_t2,$delta_rm);
    my (@temp);
    $tm1 = int( $tm );
    $tm2 = $tm - $tm1;


    # JST ==> DT （補正時刻=0.0sec と仮定して計算）

    $tm2 -= japan;


    # 中気の黄経 λsun0 を求める

    $t=($tm2+0.5) / century;
    $t=$t + ($tm1 - jan1_2000) / century;
    $rm_sun = sunlong( $t );

    $rm_sun0 = 30.0*int($rm_sun/30.0);


    # 繰り返し計算によって中気の時刻を計算する
    # （誤差が±1.0 sec以内になったら打ち切る。）

    $delta_t1 = 0;
    for ( $delta_t2 = 1.0 ; abs( $delta_t1 + $delta_t2 ) > ( 1.0 / day ) ; ) {


	# λsun を計算

	$t =($tm2+0.5) / century;
	$t =$t + ($tm1 - jan1_2000) / century;
	$rm_sun=sunlong( $t );


	# 黄経差 Δλ＝λsun −λsun0

	$delta_rm = $rm_sun - $rm_sun0 ;


	# Δλの引き込み範囲（±180°）を逸脱した場合には、補正を行う

	if ( $delta_rm > 180.0 ) {
	    $delta_rm-=360.0;
	}
	elsif ( $delta_rm < -180.0 ) {
	    $delta_rm+=360.0;
	}


	# 時刻引数の補正値 Δt
	# delta_t = delta_rm * 365.2 / 360.0;

	$delta_t1 = int($delta_rm * 365.2 / 360.0);
	$delta_t2 = $delta_rm * 365.2 / 360.0;
	$delta_t2 -= $delta_t1;


	# 時刻引数の補正
	# tm -= delta_t;

	$tm1 = $tm1 - $delta_t1;
	$tm2 = $tm2 - $delta_t2;
	if ($tm2 < 0) {
	    $tm2+=1.0;$tm1-=1.0;
	}
    }


    # 戻り値の作成
    # chu[i,0]:時刻引数を合成するのと、DT ==> JST 変換を行い、戻り値とする
    # （補正時刻=0.0sec と仮定して計算）
    # chu[i,1]:黄経

    $temp[0] = $tm2+japan;
    $temp[0] += $tm1;
    $temp[1] = $rm_sun0;

    return(@temp);
}


# 直前の二分二至の時刻を求める
#
# 呼び出し時にセットする変数
# tm ........ 計算対象となる時刻（ユリウス日）
# nibun ..... 戻り値を格納する配列のポインター
# 戻り値 .... 二分二至の時刻、その時の黄経を配列で渡す
# （戻り値の渡し方がちょっと気にくわないがまぁいいや。）

sub before_nibun
{
    my ($tm) = @_;
    my (@nibun,$tm1,$tm2,$t,$rm_sun0,$rm_sun,$delta_t1,$delta_t2,$delta_rm);


    #時刻引数を分解する

    $tm1 = int( $tm );
    $tm2 = $tm - $tm1;


    # JST ==> DT （補正時刻=0.0sec と仮定して計算）

    $tm2-=japan;


    # 直前の二分二至の黄経 λsun0 を求める

    $t = ($tm2+0.5) / century;
    $t += ($tm1 - jan1_2000) / century;
    $rm_sun=sunlong( $t );
    $rm_sun0=90*int($rm_sun/90.0);


    # 繰り返し計算によって直前の二分二至の時刻を計算する
    # （誤差が±1.0 sec以内になったら打ち切る。）

    $delta_t1 = 0;
    for ( $delta_t2 = 1.0 ; abs( $delta_t1+$delta_t2 ) > ( 1.0 / day ) ; ) {


	# λsun を計算

	$t=($tm2+0.5) / century;
	$t=$t + ($tm1 - jan1_2000) / century;
	$rm_sun=sunlong( $t );


	# 黄経差 Δλ＝λsun −λsun0

	$delta_rm = $rm_sun - $rm_sun0 ;


	# Δλの引き込み範囲（±180°）を逸脱した場合には、補正を行う

	if ( $delta_rm > 180.0 ) {
	    $delta_rm-=360.0;
	}
	elsif ( $delta_rm < -180.0) {
	    $delta_rm+=360.0;
	}


	# 時刻引数の補正値 Δt
	# delta_t = delta_rm * 365.2 / 360.0;

	$delta_t1 = int($delta_rm * 365.2 / 360.0);
	$delta_t2 = $delta_rm * 365.2 / 360.0;
	$delta_t2 -= $delta_t1;


	# 時刻引数の補正
	# tm -= delta_t;

	$tm1 = $tm1 - $delta_t1;
	$tm2 = $tm2 - $delta_t2;
	if ($tm2 < 0) {
	    $tm2+=1.0;$tm1-=1.0;
	}

    }


    # 戻り値の作成
    # nibun[0,0]:時刻引数を合成するのと、DT ==> JST 変換を行い、戻り値とする
    # （補正時刻=0.0sec と仮定して計算）
    # nibun[0,1]:黄経

    $nibun[0] = $tm2+japan;
    $nibun[0] += $tm1;
    $nibun[1] = $rm_sun0;

    return(@nibun);

}


# 朔の計算
# 与えられた時刻の直近の朔の時刻（JST）を求める
#
# 呼び出し時にセットする変数
# tm ........ 計算対象となる時刻（ユリウス日）
# 戻り値 .... 朔の時刻
#
# ※ 引数、戻り値ともユリウス日で表し、時分秒は日の小数で表す。
#

sub calc_saku
{
    my ($tm) = @_;
    my ($lc,$t,$tm1,$tm2,$rm_sun,$rm_moon,$delta_rm,$delta_t1,$delta_t2);


    # ループカウンタのセット

    $lc=1;


    #時刻引数を分解する

    $tm1 = int( $tm );
    $tm2 = $tm - $tm1;


    # JST ==> DT （補正時刻=0.0sec と仮定して計算）

    $tm2-=japan;


    # 繰り返し計算によって朔の時刻を計算する
    # （誤差が±1.0 sec以内になったら打ち切る。）

    $delta_t1 = 0;
    for ( $delta_t2 = 1.0 ; abs( $delta_t1+$delta_t2 ) > ( 1.0 / day ) ; $lc++) {


	# 太陽の黄経λsun ,月の黄経λmoon を計算
	# t = (tm - 2451548.0 + 0.5)/century;

	$t=($tm2+0.5) / century;
	$t=$t + ($tm1 - jan1_2000) / century;
	$rm_sun = sunlong( $t );
	$rm_moon = moonlong( $t );


	# 月と太陽の黄経差Δλ
	# Δλ＝λmoon−λsun

	$delta_rm = $rm_moon - $rm_sun ;


	# ループの１回目（lc=1）で delta_rm < 0.0 の場合には引き込み範囲に
	# 入るように補正する

	if ( $lc==1 && $delta_rm < 0.0 ) {
	    $delta_rm = nangle( $delta_rm );
	}

	#   春分の近くで朔がある場合（0 ≦λsun≦ 20）で、月の黄経λmoon≧300 の
	#   場合には、Δλ＝ 360.0 − Δλ と計算して補正する

	elsif ( $rm_sun >= 0 && $rm_sun <= 20 && $rm_moon >= 300 ) {
	    $delta_rm = nangle( $delta_rm );
	    $delta_rm = 360.0 - $delta_rm;
	}

	# Δλの引き込み範囲（±40°）を逸脱した場合には、補正を行う

	elsif ( abs( $delta_rm ) > 40.0 ) {
	    $delta_rm = nangle( $delta_rm );
	}


	# 時刻引数の補正値 Δt
	# delta_t = delta_rm * 29.530589 / 360.0;

	$delta_t1 = int($delta_rm * 29.530589 / 360.0);
	$delta_t2 = $delta_rm * 29.530589 / 360.0;
	$delta_t2 -= $delta_t1;


	# 時刻引数の補正
	# tm -= delta_t;

	$tm1 = $tm1 - $delta_t1;
	$tm2 = $tm2 - $delta_t2;
	if ($tm2 < 0.0) {
	    $tm2+=1.0;$tm1-=1.0;
	}


	# ループ回数が15回になったら、初期値 tm を tm-26 とする。

	if ($lc == 15 && abs( $delta_t1+$delta_t2 ) > ( 1.0 / day ) ) {
	    $tm1 = int( $tm-26 );
	    $tm2 = 0;
	}


	# 初期値を補正したにも関わらず、振動を続ける場合には初期値を答えとして
	# 返して強制的にループを抜け出して異常終了させる。

	elsif ( $lc > 30 && abs( $delta_t1+$delta_t2 ) > ( 1.0 / day ) ) {
	    $tm1=$tm;$tm2=0;
	    last;
	}
    }


    # 時刻引数を合成するのと、DT ==> JST 変換を行い、戻り値とする
    # （補正時刻=0.0sec と仮定して計算）


    return($tm2+$tm1+japan);
}


#  角度の正規化を行う。すなわち引数の範囲を ０≦θ＜３６０ にする。


# Given an angle of any value, turn it into an angle between 0 and 360
# degrees.

sub nangle
{
    my ($angle) = @_;
    my $angle1;

    if ( $angle < 0.0 ) {
	$angle1 = -$angle;
	my $angle2 = int ($angle1 / 360.0);
	$angle1 -= 360.0 * $angle2;
	$angle1 = 360.0 - $angle1;
    }
    else {
	$angle1 = int ($angle / 360.0);
	$angle1 = $angle - 360.0 * $angle1;
    }

    return $angle1;
}


# 太陽の黄経 λsun を計算する


# Longitude of the sun. The input time value is relative to the epoch
# of 1 January 2000 as given by the constant jan1_2000. The magic
# numbers seem to originate from a book published in 1991 called 

# "天体位置略算式の解説―Almanac for Personal Computers" by 

# 井上 圭典 (著), 鈴木 邦裕 (著)

# This book is quite hard to obtain, and according to the original
# documentation of qreki it was based on a program in a language
# called "N88 BASIC", so one would need a floppy disc drive to read
# that in.

sub sunlong
{
    my ($t) = @_;
    my ($th,$ang);

    # 摂動項の計算


    # Some of the constants were found here:

    # http://ihepdb.ihep.ac.cn/ybjdata/asgamma/B3rst/P9B3/muon_v1.54/mcheck/ybjSun.cpp
    # http://bal4u.dip.jp/algo/solarPos.txt
    # http://fl.corge.net/c/kznG
    # Also here:
    # https://books.google.co.jp/books?id=xj3FPWsBcE4C&pg=PA196&dq=%22445267%22&hl=en&sa=X&ved=0ahUKEwjsyLq-rNreAhWDbN4KHcTrAGcQ6AEIODAD#v=onepage&q=%22445267%22&f=false

    $ang = nangle(  31557.0 * $t + 161.0 );
    $th =       .0004 * deg_cos( $ang );
    $ang = nangle(  29930.0 * $t +  48.0 );
    $th = $th +  .0004 * deg_cos ($ang );
    $ang = nangle(   2281.0 * $t + 221.0 );
    $th = $th +  .0005 * deg_cos ($ang );
    $ang = nangle(    155.0 * $t + 118.0 );
    $th = $th +  .0005 * deg_cos ($ang );
    $ang = nangle(  33718.0 * $t + 316.0 );
    $th = $th +  .0006 * deg_cos ($ang );
    $ang = nangle(   9038.0 * $t +  64.0 );
    $th = $th +  .0007 * deg_cos ($ang );
    $ang = nangle(   3035.0 * $t + 110.0 );
    $th = $th +  .0007 * deg_cos ($ang );
    $ang = nangle(  65929.0 * $t +  45.0 );
    $th = $th +  .0007 * deg_cos ($ang );
    $ang = nangle(  22519.0 * $t + 352.0 );
    $th = $th +  .0013 * deg_cos ($ang );
    $ang = nangle(  45038.0 * $t + 254.0 );
    $th = $th +  .0015 * deg_cos ($ang );
    $ang = nangle( 445267.0 * $t + 208.0 );
    $th = $th +  .0018 * deg_cos ($ang );
    $ang = nangle(     19.0 * $t + 159.0 );
    $th = $th +  .0018 * deg_cos ($ang );
    $ang = nangle(  32964.0 * $t + 158.0 );
    $th = $th +  .0020 * deg_cos ($ang );
    $ang = nangle(  71998.1 * $t + 265.1 );
    $th = $th +  .0200 * deg_cos ($ang );
    $ang = nangle(  35999.05 * $t + 267.52 );
    $th = $th - 0.0048 * $t * deg_cos ($ang ) ;
    $th = $th + 1.9147     * deg_cos ($ang ) ;


    # 比例項の計算

    $ang = nangle( 36000.7695 * $t );
    $ang = nangle( $ang + 280.4659 );
    $th  = nangle( $th + $ang );

    return($th);
}


# 月の黄経 λmoon を計算する

sub moonlong
{
    my ($t) = @_;
    my ($th,$ang);


    # 摂動項の計算

    $ang = nangle( 2322131.0  * $t + 191.0  );
    $th =      .0003 * deg_cos ($ang );
    $ang = nangle(    4067.0  * $t +  70.0  );
    $th = $th + .0003 * deg_cos ($ang );
    $ang = nangle(  549197.0  * $t + 220.0  );
    $th = $th + .0003 * deg_cos ($ang );
    $ang = nangle( 1808933.0  * $t +  58.0  );
    $th = $th + .0003 * deg_cos ($ang );
    $ang = nangle(  349472.0  * $t + 337.0  );
    $th = $th + .0003 * deg_cos ($ang );
    $ang = nangle(  381404.0  * $t + 354.0  );
    $th = $th + .0003 * deg_cos ($ang );
    $ang = nangle(  958465.0  * $t + 340.0  );
    $th = $th + .0003 * deg_cos ($ang );
    $ang = nangle(   12006.0  * $t + 187.0  );
    $th = $th + .0004 * deg_cos ($ang );
    $ang = nangle(   39871.0  * $t + 223.0  );
    $th = $th + .0004 * deg_cos ($ang );
    $ang = nangle(  509131.0  * $t + 242.0  );
    $th = $th + .0005 * deg_cos ($ang );
    $ang = nangle( 1745069.0  * $t +  24.0  );
    $th = $th + .0005 * deg_cos ($ang );
    $ang = nangle( 1908795.0  * $t +  90.0  );
    $th = $th + .0005 * deg_cos ($ang );
    $ang = nangle( 2258267.0  * $t + 156.0  );
    $th = $th + .0006 * deg_cos ($ang );
    $ang = nangle(  111869.0  * $t +  38.0  );
    $th = $th + .0006 * deg_cos ($ang );
    $ang = nangle(   27864.0  * $t + 127.0  );
    $th = $th + .0007 * deg_cos ($ang );
    $ang = nangle(  485333.0  * $t + 186.0  );
    $th = $th + .0007 * deg_cos ($ang );
    $ang = nangle(  405201.0  * $t +  50.0  );
    $th = $th + .0007 * deg_cos ($ang );
    $ang = nangle(  790672.0  * $t + 114.0  );
    $th = $th + .0007 * deg_cos ($ang );
    $ang = nangle( 1403732.0  * $t +  98.0  );
    $th = $th + .0008 * deg_cos ($ang );
    $ang = nangle(  858602.0  * $t + 129.0  );
    $th = $th + .0009 * deg_cos ($ang );
    $ang = nangle( 1920802.0  * $t + 186.0  );
    $th = $th + .0011 * deg_cos ($ang );
    $ang = nangle( 1267871.0  * $t + 249.0  );
    $th = $th + .0012 * deg_cos ($ang );
    $ang = nangle( 1856938.0  * $t + 152.0  );
    $th = $th + .0016 * deg_cos ($ang );
    $ang = nangle(  401329.0  * $t + 274.0  );
    $th = $th + .0018 * deg_cos ($ang );
    $ang = nangle(  341337.0  * $t +  16.0  );
    $th = $th + .0021 * deg_cos ($ang );
    $ang = nangle(   71998.0  * $t +  85.0  );
    $th = $th + .0021 * deg_cos ($ang );
    $ang = nangle(  990397.0  * $t + 357.0  );
    $th = $th + .0021 * deg_cos ($ang );
    $ang = nangle(  818536.0  * $t + 151.0  );
    $th = $th + .0022 * deg_cos ($ang );
    $ang = nangle(  922466.0  * $t + 163.0  );
    $th = $th + .0023 * deg_cos ($ang );
    $ang = nangle(   99863.0  * $t + 122.0  );
    $th = $th + .0024 * deg_cos ($ang );
    $ang = nangle( 1379739.0  * $t +  17.0  );
    $th = $th + .0026 * deg_cos ($ang );
    $ang = nangle(  918399.0  * $t + 182.0  );
    $th = $th + .0027 * deg_cos ($ang );
    # secular motion of the node of the lunar orbit (?)
    $ang = nangle(    1934.0  * $t + 145.0  );
    $th = $th + .0028 * deg_cos ($ang );
    $ang = nangle(  541062.0  * $t + 259.0  );
    $th = $th + .0037 * deg_cos ($ang );
    $ang = nangle( 1781068.0  * $t +  21.0  );
    $th = $th + .0038 * deg_cos ($ang );
    $ang = nangle(     133.0  * $t +  29.0  );
    $th = $th + .0040 * deg_cos ($ang );
    $ang = nangle( 1844932.0  * $t +  56.0  );
    $th = $th + .0040 * deg_cos ($ang );
    $ang = nangle( 1331734.0  * $t + 283.0  );
    $th = $th + .0040 * deg_cos ($ang );
    $ang = nangle(  481266.0  * $t + 205.0  );
    $th = $th + .0050 * deg_cos ($ang );
    $ang = nangle(   31932.0  * $t + 107.0  );
    $th = $th + .0052 * deg_cos ($ang );
    $ang = nangle(  926533.0  * $t + 323.0  );
    $th = $th + .0068 * deg_cos ($ang );
    $ang = nangle(  449334.0  * $t + 188.0  );
    $th = $th + .0079 * deg_cos ($ang );
    $ang = nangle(  826671.0  * $t + 111.0  );
    $th = $th + .0085 * deg_cos ($ang );
    $ang = nangle( 1431597.0  * $t + 315.0  );
    $th = $th + .0100 * deg_cos ($ang );
    $ang = nangle( 1303870.0  * $t + 246.0  );
    $th = $th + .0107 * deg_cos ($ang );
    $ang = nangle(  489205.0  * $t + 142.0  );
    $th = $th + .0110 * deg_cos ($ang );
    $ang = nangle( 1443603.0  * $t +  52.0  );
    $th = $th + .0125 * deg_cos ($ang );
    $ang = nangle(   75870.0  * $t +  41.0  );
    $th = $th + .0154 * deg_cos ($ang );
    $ang = nangle(  513197.9  * $t + 222.5  );
    $th = $th + .0304 * deg_cos ($ang );
    $ang = nangle(  445267.1  * $t +  27.9  );
    $th = $th + .0347 * deg_cos ($ang );
    $ang = nangle(  441199.8  * $t +  47.4  );
    $th = $th + .0409 * deg_cos ($ang );
    $ang = nangle(  854535.2  * $t + 148.2  );
    $th = $th + .0458 * deg_cos ($ang );
    $ang = nangle( 1367733.1  * $t + 280.7  );
    $th = $th + .0533 * deg_cos ($ang );
    $ang = nangle(  377336.3  * $t +  13.2  );
    $th = $th + .0571 * deg_cos ($ang );
    $ang = nangle(   63863.5  * $t + 124.2  );
    $th = $th + .0588 * deg_cos ($ang );
    $ang = nangle(  966404.0  * $t + 276.5  );
    $th = $th + .1144 * deg_cos ($ang );
    $ang = nangle(   35999.05 * $t +  87.53 );
    $th = $th + .1851 * deg_cos ($ang );
    $ang = nangle(  954397.74 * $t + 179.93 );
    $th = $th + .2136 * deg_cos ($ang );
    $ang = nangle(  890534.22 * $t + 145.7  );
    $th = $th + .6583 * deg_cos ($ang );
    $ang = nangle(  413335.35 * $t +  10.74 );
    $th = $th + 1.2740 * deg_cos ($ang );

    # The following big number turns up here:

    # https://github.com/basileh/pyGrav/blob/master/main_code/synthetic_tides.py

    # But that is cited to a paper from 2015, whereas this code dates from 1993.

    $ang = nangle( 477198.868 * $t + 44.963 ); 
    $th = $th + 6.2888 * deg_cos ($ang );


    # 比例項の計算

    $ang = nangle(  481267.8809 * $t );
    $ang = nangle(  $ang + 218.3162 );
    $th  = nangle(  $th  +  $ang );

    return($th);
}


# 年月日、時分秒（世界時）からユリウス日（JD）を計算する
#
# ※ この関数では、グレゴリオ暦法による年月日から求めるものである。
#    （ユリウス暦法による年月日から求める場合には使用できない。）


# Year, month, day to Julian day. This is the original Julian day
# using 12h Jan 1, 4713 BC as the epoch.

sub YMDT2JD
{
    my ($year, $month, $day, $hour, $min, $sec) = @_;

    if ( $month < 3.0 ) {
	$year -= 1.0;
	$month += 12.0;
    }

    my $jd  = int( 365.25 * $year );
    $jd += int( $year / 400.0 );
    $jd -= int( $year / 100.0 );
    $jd += int( 30.59 * ( $month-2.0 ) );
    $jd += 1721088;
    $jd += $day;
    # Bring these calculations into line with the US naval observatory
    # values.
#    $jd += 0.5;

    my $t  = $sec / 3600.0;
    $t += $min /60.0;
    $t += $hour;
    $t  = $t / 24.0;

    $jd += $t;

    return $jd;
}


# ユリウス日（JD）から年月日、時分秒（世界時）を計算する
#
# 戻り値の配列TIME[]の内訳
# TIME[0] ... 年  TIME[1] ... 月  TIME[2] ... 日
# TIME[3] ... 時  TIME[4] ... 分  TIME[5] ... 秒
#
# ※ この関数で求めた年月日は、グレゴリオ暦法によって表されている。
#

sub JD2YMDT
{

    my ($JD) = @_;
    my (@TIME,$x0,$x1,$x2,$x3,$x4,$x5,$x6,$tm);

    $x0 = int( $JD+68570.0);
    $x1 = int( $x0/36524.25 );
    $x2 = $x0 - int( 36524.25*$x1 + 0.75 );
    $x3 = int( ( $x2+1 )/365.2425 );
    $x4 = $x2 - int( 365.25*$x3 )+31.0;
    $x5 = int( int($x4) / 30.59 );
    $x6 = int( int($x5) / 11.0 );

    $TIME[2] = $x4 - int( 30.59*$x5 );
    $TIME[1] = $x5 - 12*$x6 + 2;
    $TIME[0] = 100*( $x1-49 ) + $x3 + $x6;

    # 2月30日の補正
    if ($TIME[1]==2 && $TIME[2] > 28) {
	if ($TIME[0] % 100 == 0 && $TIME[0] % 400 == 0) {
	    $TIME[2]=29;
	}
	elsif ($TIME[0] % 4 ==0) {
	    $TIME[2]=29;
	}
	else {
	    $TIME[2]=28;
	}
    }

    $tm= day *( $JD - int( $JD ) );
    $TIME[3] = int( $tm/3600.0 );
    $TIME[4] = int( ($tm - 3600.0*$TIME[3])/60.0 );
    $TIME[5] = int( $tm - 3600.0*$TIME[3] - 60*$TIME[4] );

    return @TIME;
}

sub d
{
    my ($tm) = @_;

    #時刻引数を分解する

    my $tm1 = int( $tm );
    my $tm2 = $tm - $tm1;

    # JST ==> DT （補正時刻=0.0sec と仮定して計算）

    $tm2 -= japan;

    # 中気の黄経 λsun0 を求める

    my $t = ($tm2 + 0.5) / century;
    $t = $t + ($tm1 - jan1_2000) / century;
    return sunlong ($t);
}


# 今日が２４節気かどうか調べる
# 
# 引数　 .... 計算対象となる年月日　$year $mon $day
#
# 戻り値 .... ２４節気の名称
#


# ２４節気の定義

my @sekki24 = qw!春分 清明 穀雨 立夏 小満 芒種 夏至 小暑 大暑 立秋 処暑 白露
		 秋分 寒露 霜降 立冬 小雪 大雪 冬至 小寒 大寒 立春 雨水 啓蟄!;

sub check_24sekki
{
    my ($year,$mon,$day) = @_;


    my $tm = YMDT2JD ($year,$mon,$day,0,0,0);

    # 今日の太陽の黄経

    my $rm_sun_today = d ($tm);

    $tm++;

    # 明日の太陽の黄経
    my $rm_sun_tomorrow = d ($tm);

    my $rm_sun_today0   = int ($rm_sun_today / 15.0);
    my $rm_sun_tomorrow0 = int ($rm_sun_tomorrow / 15.0);

    if ($rm_sun_today0 != $rm_sun_tomorrow0) {
	return $sekki24[$rm_sun_tomorrow0];
    }
    else {
	return '';
    }
}

1;
