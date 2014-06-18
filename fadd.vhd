library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_misc.all; 
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity fadd32 is
    port (a   : in  std_logic_vector (31 downto 0);
          b   : in  std_logic_vector (31 downto 0);
          res : out std_logic_vector (31 downto 0));
end entity fadd32;

architecture behavior of fadd32 is
    signal suba, subb : std_logic;
    signal infa, infb : std_logic;
    signal nana, nanb : std_logic;
    signal excep      : std_logic;
    signal win, lose  : std_logic_vector (31 downto 0);
    signal expdiff    : std_logic_vector ( 7 downto 0);
    signal wm, lm     : std_logic_vector (27 downto 0);
    signal lmt        : std_logic_vector (55 downto 0);
    signal sm, smt    : std_logic_vector (27 downto 0);
    signal se         : std_logic_vector ( 7 downto 0);
    signal dm, dmt    : std_logic_vector (27 downto 0);
    signal de, dlz    : std_logic_vector ( 7 downto 0);
    signal rm, rmt    : std_logic_vector (27 downto 0);
    signal re         : std_logic_vector ( 7 downto 0);
    signal exres      : std_logic_vector (31 downto 0);
begin
    -- exponent = 0 or 255 ?
    suba <= '1' when a(30 downto 23) = x"00" else '0';
    subb <= '1' when b(30 downto 23) = x"00" else '0';
    infa <= '1' when a(30 downto 23) = x"ff" and or_reduce(a(22 downto 0)) = '0' else '0';
    infb <= '1' when b(30 downto 23) = x"ff" and or_reduce(b(22 downto 0)) = '0' else '0';
    nana <= '1' when a(30 downto 23) = x"ff" and or_reduce(a(22 downto 0)) = '1' else '0';
    nanb <= '1' when b(30 downto 23) = x"ff" and or_reduce(b(22 downto 0)) = '1' else '0';
    excep <= '1' when suba = '1' or subb = '1' or
                      infa = '1' or infb = '1' or
                      nana = '1' or nanb = '1' else
             '0';

    -- comparison
    win  <= a when a(30 downto 0) >= b(30 downto 0) else
            b;
    lose <= a when a(30 downto 0) <  b(30 downto 0) else
            b;
    expdiff <= win(30 downto 23) - lose(30 downto 23);

    -- align
    lmt <= shr("1" & lose(22 downto 0) & x"00000000", expdiff);
    wm  <= "01" & win(22 downto 0) & "000";
    lm  <= "0" & lmt(55 downto 30) & or_reduce(lmt(29 downto 0));

    -- addition
    smt <= wm + lm;
    sm  <= smt when smt(27) = '0' else
           "0" & smt(27 downto 2) & (smt(1) or smt(0));
    se  <= win(30 downto 23) when smt(27) = '0' else
           win(30 downto 23) + 1;

    -- subtraction
    dmt <= wm - lm;
    dlz <= x"00" when dmt(26) = '1' else
           x"01" when dmt(25) = '1' else
           x"02" when dmt(24) = '1' else
           x"03" when dmt(23) = '1' else
           x"04" when dmt(22) = '1' else
           x"05" when dmt(21) = '1' else
           x"06" when dmt(20) = '1' else
           x"07" when dmt(19) = '1' else
           x"08" when dmt(18) = '1' else
           x"09" when dmt(17) = '1' else
           x"0a" when dmt(16) = '1' else
           x"0b" when dmt(15) = '1' else
           x"0c" when dmt(14) = '1' else
           x"0d" when dmt(13) = '1' else
           x"0e" when dmt(12) = '1' else
           x"0f" when dmt(11) = '1' else
           x"10" when dmt(10) = '1' else
           x"11" when dmt( 9) = '1' else
           x"12" when dmt( 8) = '1' else
           x"13" when dmt( 7) = '1' else
           x"14" when dmt( 6) = '1' else
           x"15" when dmt( 5) = '1' else
           x"16" when dmt( 4) = '1' else
           x"17" when dmt( 3) = '1' else
           x"18" when dmt( 2) = '1' else
           x"ff";
    dm  <= shl(dmt, dlz(4 downto 0));
    de  <= win(30 downto 23) - dlz;

    -- rounding
    rmt <= sm when a(31) = b(31) else
           dm;
    rm  <= rmt + 8 when rmt(2) = '1' and (rmt(3) = '1' or rmt(1) = '1' or rmt(0) = '1') else
           rmt;
    re  <= se when a(31) = b(31) else
           de;

    -- exception
    exres <= a or x"00400000" when nana = '1' else
             b or x"00400000" when nanb = '1' else
             x"ffc00000" when infa = '1' and infb = '1' and a /= b else
             a           when infa = '1' else
             b           when infb = '1' else
             (31 => a(31) and b(31), others => '0') when suba = '1' and subb = '1' and a(22 downto 0) =  b(22 downto 0) else
             (31 => a(31),           others => '0') when suba = '1' and subb = '1' and a(22 downto 0) >= b(22 downto 0) else
             (31 => b(31),           others => '0') when suba = '1' and subb = '1' and a(22 downto 0) <  b(22 downto 0) else
             a when subb = '1' else
             b; -- when suba = '1'

    -- output
    res <= exres when excep = '1' else
           win when expdiff(7 downto 5) /= "000" else
           (others => '0') when dlz = x"ff" and a(31) /= b(31) else
           (31 => win(31), others => '0') when win(30 downto 23) <= dlz and a(31) /= b(31) else
           win(31) & x"ff00000" & "000" when re = x"ff" else
           win(31) & (re + 1) & rm(26 downto 4) when rm(27) = '1' else
           win(31) & re & rm(25 downto 3);
end architecture behavior;

