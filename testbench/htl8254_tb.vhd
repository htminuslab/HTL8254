-------------------------------------------------------------------------------
--  HTL8254 - PIT core                                                       --
--                                                                           --
--  https://github.com/htminuslab                                            --
--                                                                           --
-------------------------------------------------------------------------------
-- Project       : I8254                                                     --
-- Unit          : HTL8254_tb                                                --
-- Library       : I8254                                                     --
--                                                                           --
-- Version       : 0.1   18/07/02    Created HT-LAB                          --
--               : 1.2  30/11/2023   cleaned and uploaded to github          --
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.ALL;
USE ieee.numeric_std.all;

library std;
use std.TEXTIO.all;

library work;
use work.utils.all;

library modelsim_lib;
use modelsim_lib.util.all;

entity HTL8254_tb is
end HTL8254_tb ;

architecture struct of HTL8254_tb is

   signal a0       : std_logic;
   signal a1       : std_logic;
   signal clk      : std_logic;
   signal clk0     : std_logic;
   signal clk1     : std_logic;
   signal clk2     : std_logic;
   signal csn      : std_logic;
   signal dbus_in  : std_logic_vector(7 downto 0);
   signal dbus_out : std_logic_vector(7 downto 0);
   signal gate0    : std_logic;
   signal gate1    : std_logic;
   signal gate2    : std_logic;
   signal out0     : std_logic;
   signal rdn      : std_logic;
   signal resetn   : std_logic;
   signal wrn      : std_logic;


   component HTL8254
   port (
      a0       : in     std_logic ;
      a1       : in     std_logic ;
      clk      : in     std_logic ;
      clk0     : in     std_logic ;
      clk1     : in     std_logic ;
      clk2     : in     std_logic ;
      csn      : in     std_logic ;
      dbus_in  : in     std_logic_vector (7 downto 0);
      gate0    : in     std_logic ;
      gate1    : in     std_logic ;
      gate2    : in     std_logic ;
      rdn      : in     std_logic ;
      resetn   : in     std_logic ;
      wrn      : in     std_logic ;
      dbus_out : out    std_logic_vector (7 downto 0);
      out0     : out    std_logic ;
      out1     : out    std_logic ;
      out2     : out    std_logic 
   );
   end component;
   component HTL8254_tester
   port (
      dbus_out : in     std_logic_vector (7 downto 0);
      out0     : in     std_logic ;
      a0       : out    std_logic ;
      a1       : out    std_logic ;
      clk      : out    std_logic ;
      clk0     : out    std_logic ;
      clk1     : out    std_logic ;
      clk2     : out    std_logic ;
      csn      : out    std_logic ;
      dbus_in  : out    std_logic_vector (7 downto 0);
      gate0    : out    std_logic ;
      gate1    : out    std_logic ;
      gate2    : out    std_logic ;
      rdn      : out    std_logic ;
      resetn   : out    std_logic ;
      wrn      : out    std_logic 
   );
   end component;

begin

   U_0 : HTL8254
      port map (
         a0       => a0,
         a1       => a1,
         clk      => clk,
         clk0     => clk0,
         clk1     => clk1,
         clk2     => clk2,
         csn      => csn,
         dbus_in  => dbus_in,
         gate0    => gate0,
         gate1    => gate1,
         gate2    => gate2,
         rdn      => rdn,
         resetn   => resetn,
         wrn      => wrn,
         dbus_out => dbus_out,
         out0     => out0,
         out1     => open,
         out2     => open
      );
   U_1 : HTL8254_tester
      port map (
         dbus_out => dbus_out,
         out0     => out0,
         a0       => a0,
         a1       => a1,
         clk      => clk,
         clk0     => clk0,
         clk1     => clk1,
         clk2     => clk2,
         csn      => csn,
         dbus_in  => dbus_in,
         gate0    => gate0,
         gate1    => gate1,
         gate2    => gate2,
         rdn      => rdn,
         resetn   => resetn,
         wrn      => wrn
      );

end struct;
