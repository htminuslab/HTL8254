-------------------------------------------------------------------------------
--  HTL8254 - PIT core                                                       --
--                                                                           --
--  https://github.com/htminuslab                                            --
--                                                                           --
-------------------------------------------------------------------------------
-- Project       : HTL8254                                                   --
-- Purpose       : Testbench Tester Datasheet Waveform tester                --
-- Library       : I8254                                                     --
--                                                                           --
-- Version       : 1.0  20/01/2002   Created HT-LAB                          --
--               : 1.0a 21/10/2009   Updated Mode0 RW=11 test, added check   --
--               :                   to make sure counter is disabled after  --
--               :                   writing the first byte.                 --
--               : 1.0e 13/12/2009   Added check for rwmode=11 and gate bug  --
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

entity HTL8254_tester is
   port( 
      dbus_out : in     std_logic_vector (7 downto 0);
      out0     : in     std_logic;
      a0       : out    std_logic;
      a1       : out    std_logic;
      clk      : out    std_logic;
      clk0     : out    std_logic;
      clk1     : out    std_logic;
      clk2     : out    std_logic;
      csn      : out    std_logic;
      dbus_in  : out    std_logic_vector (7 downto 0);
      gate0    : out    std_logic;
      gate1    : out    std_logic;
      gate2    : out    std_logic;
      rdn      : out    std_logic;
      resetn   : out    std_logic;
      wrn      : out    std_logic
   );
end HTL8254_tester ;


architecture waveform of HTL8254_tester is

    signal clk_s        : std_logic:='0';
    signal clk0_s       : std_logic:='0';
    signal clk1_s       : std_logic:='0';
    signal clk2_s       : std_logic:='0';

    signal abus_s       : std_logic_vector(1 downto 0);
    signal data_s       : std_logic_vector(7 downto 0);
    signal resetn_s     : std_logic:='0';

    constant CLKPERIOD_C   : time := 10 ns;
    constant CLK0PERIOD_C  : time := 433 ns;

    --------------------------------------------------------------------------
    -- Simulate x86 OUT instruction
    --------------------------------------------------------------------------
    procedure outport(                                  -- write byte to I/Oport using clk0  
        signal addr_p : in std_logic_vector(1 downto 0);-- Port Address
        signal dbus_p : in std_logic_vector(7 downto 0);-- Port Data
        signal csn    : out std_logic;
        signal wrn    : out std_logic;
        signal abus   : out std_logic_vector(1 downto 0);
        signal dbus_in: out std_logic_vector(7 downto 0)) is 
        begin 
            wait until falling_edge(clk0_s);
            abus <= addr_p;
            wait for 5 ns;
            csn  <= '0';
            wait for (CLK0PERIOD_C/2)-5 ns;
            wrn  <= '0';
            dbus_in <= dbus_p;
            wait until falling_edge(clk0_s);
            wait for (CLK0PERIOD_C/2);
            wait until rising_edge(clk_s);              -- Sync to system clock
            wait for 1 ns;                      
            abus <= (others => '1');
            wrn  <= '1';
            csn  <= '1';
            wait for 5 ns;                              -- Some hold time
            dbus_in <= (others=>'Z');                   -- 'Z' used for display purposes only
        end outport;


BEGIN
    
    -------------------------------------------------------------------------------
    -- Generate System Clock
    -------------------------------------------------------------------------------
    clk_s   <= not clk_s after CLKPERIOD_C;     
    clk     <= clk_s;
    
    clk0_s  <= not clk0_s after CLK0PERIOD_C;
    clk0    <= clk0_s;      
    clk1    <= '1';                                     -- Not used
    clk2    <= '1';                                     -- Not used

    resetn_s<= '1' after 100 ns;                        -- Simple Async reset

    a0      <= abus_s(0);
    a1      <= abus_s(1);
    resetn  <= resetn_s;
    rdn     <= '1';

    process
        begin
            abus_s   <= (others => '1');
            dbus_in  <= (others => 'Z');                -- 'Z' used for display purposes only
            gate0    <= '1';
            wrn      <= '1';
            csn      <= '1';

            wait until rising_edge(resetn_s);           -- Wait until reset negated
            wait for CLK0PERIOD_C*3;
            
            ---------------------------------------------------------------------------
            -- Mode0 Counter 0
            ---------------------------------------------------------------------------             
            assert FALSE report "*** Start of Mode0 ***" severity note;
             
            gate0  <= '1';
                                                        -- Diagram 1
            abus_s <= "11";                             -- Control Register 
            data_s <= X"10";                            -- LSB only
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"04";                            -- LSB 04
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);
            
            wait until rising_edge(out0);
            wait for CLK0PERIOD_C*3;

            ---------------------------------------------------------------------------
                                                        -- Diagram 2, negate gate
            abus_s <= "11";                             -- Control Register 
            data_s <= X"10";                            -- LSB only
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"03";                            -- LSB 03
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            wait until falling_edge(clk0_s);
            wait until rising_edge(clk0_s);
            wait for CLK0PERIOD_C/2;
            gate0 <= '0';
            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait for CLK0PERIOD_C/2;
            gate0 <= '1';
            wait for CLK0PERIOD_C*7;

            ---------------------------------------------------------------------------
                                                        -- Diagram 3, new value written to counter
            abus_s <= "11";                             -- Control Register 
            data_s <= X"10";                            -- LSB only
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"03";                            -- LSB 03
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            wait until falling_edge(clk0_s);
            abus_s <= "00";                             -- Write new counter0 value 
            data_s <= X"02";                            -- LSB 02
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            wait for CLK0PERIOD_C*9;

            ---------------------------------------------------------------------------
            -- Mode1 Counter 0
            ---------------------------------------------------------------------------     
            assert FALSE report "*** Start of Mode1 ***" severity note;
            
            gate0 <= '0';
                                                        -- Diagram 1
            abus_s <= "11";                             -- Control Register 
            data_s <= X"12";                            -- CW=12, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"03";                            -- LSB 03
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);
            
            -- Create a gate pulse surrounding the falling edge of clk0
            wait until rising_edge(clk0_s);             -- Assert gate0 as per diagram1
            wait for CLK0PERIOD_C/2;                    -- some time after rising edge
            gate0 <= '1';                               -- assert gate
            wait until falling_edge(clk0_s);
            wait for CLK0PERIOD_C/2;        
            gate0 <= '0';

            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait until rising_edge(clk0_s);
            wait for CLK0PERIOD_C/2;                    -- some time after rising edge
            gate0 <= '1';                               -- assert gate
            wait for CLK0PERIOD_C;      
            gate0 <= '0';
            wait for CLK0PERIOD_C*7;

            ---------------------------------------------------------------------------
                                                        -- Diagram 2, gate pulse during low out0
            abus_s <= "11";                             -- Control Register 
            data_s <= X"12";                            -- CW=12, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"03";                            -- LSB 03
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            -- Create a gate pulse surrounding the falling edge of clk0
            wait until rising_edge(clk0_s);             -- Assert gate0 as per diagram1
            wait for CLK0PERIOD_C/2;                    -- some time after rising edge
            gate0 <= '1';                               -- assert gate
            wait until falling_edge(clk0_s);
            wait for CLK0PERIOD_C/2;        
            gate0 <= '0';


            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait until rising_edge(clk0_s);
            wait for CLK0PERIOD_C/2;                    -- some time after rising edge
            gate0 <= '1';                               -- assert gate
            wait for CLK0PERIOD_C;      
            gate0 <= '0';
            wait for CLK0PERIOD_C*9;


            ---------------------------------------------------------------------------
                                                        -- Diagram 3, write during low out0
            abus_s <= "11";                             -- Control Register 
            data_s <= X"12";                            -- CW=12, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"02";                            -- LSB 02
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            -- Create a gate pulse surrounding the falling edge of clk0
            wait until rising_edge(clk0_s);             -- Assert gate0 as per diagram1
            wait for CLK0PERIOD_C/2;                    -- some time after rising edge
            gate0 <= '1';                               -- assert gate
            wait until falling_edge(clk0_s);
            wait for CLK0PERIOD_C/2;        
            gate0 <= '0';

            wait until falling_edge(clk0_s);
            wait for 184 ns;
            abus_s <= "00";                             -- Write new counter0 value 
            data_s <= X"04";                            -- LSB 04
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            wait until falling_edge(clk0_s);
            wait until rising_edge(clk0_s);
            wait for CLK0PERIOD_C/2;                    -- some time after rising edge
            gate0 <= '1';                               -- assert gate
            wait for CLK0PERIOD_C;      
            gate0 <= '0';
            wait for CLK0PERIOD_C*7;


            ---------------------------------------------------------------------------
            -- Mode2 Counter 0
            ---------------------------------------------------------------------------
            assert FALSE report "*** Start of Mode2 ***" severity note;

            gate0 <= '1';
                                                        -- Diagram 1
            abus_s <= "11";                             -- Control Register 
            data_s <= X"14";                            -- CW, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"03";                            -- LSB 03
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);
            
            wait for CLK0PERIOD_C*17;

            ---------------------------------------------------------------------------
                                                        -- Diagram 2, gate negated during count
            abus_s <= "11";                             -- Control Register 
            data_s <= X"14";                            -- CW, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s<=X"03";                              -- LSB  03
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            wait until falling_edge(clk0_s);
            wait until rising_edge(clk0_s);
            wait for 10 ns;
            gate0 <= '0';
            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait until rising_edge(clk_s);
            wait for 10 ns;
            gate0 <= '1';

            wait for CLK0PERIOD_C*15;

            ---------------------------------------------------------------------------
                                                        -- Diagram 3, Write occurs after 1 clk0 period )
            abus_s <= "11";                             -- Control Register 
            data_s <= X"14";                            -- CW, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s<=X"04";                              -- LSB  03
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);

            abus_s <= "00";                             -- Counter 0 
            data_s<=X"05";                              -- LSB  05
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            wait for CLK0PERIOD_C*5;

            ---------------------------------------------------------------------------
            -- Mode3 Counter 0
            ---------------------------------------------------------------------------
            assert FALSE report "*** Start of Mode3 ***" severity note;

            gate0 <= '1';
                                                        -- Diagram 1, write even values
            abus_s <= "11";                             -- Control Register 
            data_s <= X"16";                            -- CW, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"04";                            -- LSB 04
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);
            
            wait for CLK0PERIOD_C*21;

            ---------------------------------------------------------------------------
                                                        -- Diagram 2, write Odd values
            abus_s <= "11";                             -- Control Register 
            data_s <= X"16";                            -- CW, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"05";                            -- LSB 05
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            wait for CLK0PERIOD_C*23;

            ---------------------------------------------------------------------------
                                                        -- Diagram 3, negate gate during out=0 pulse
                                                        -- out0 is set high immediately!
            abus_s <= "11";                             -- Control Register 
            data_s <= X"16";                            -- CW, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"04";                            -- LSB 04 even
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);
            
            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait for 240 ns;
            gate0 <= '0';
            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait for 240 ns;
            gate0 <= '1';

            wait for CLK0PERIOD_C*21;

            ---------------------------------------------------------------------------
            -- Mode4 Counter 0
            ---------------------------------------------------------------------------
            assert FALSE report "*** Start of Mode4 ***" severity note;

            gate0 <= '1';                               -- Diagram 1

            abus_s <= "11";                             -- Control Register 
            data_s <= X"18";                            -- CW, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"03";                            -- LSB  03
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);
            
            wait for CLK0PERIOD_C*15;
            
            ---------------------------------------------------------------------------
            gate0 <= '0';                               -- Diagram 2, rising edge gate

            abus_s <= "11";                             -- Control Register 
            data_s <= X"18";                            -- CW, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"03";                            -- LSB  03
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait until rising_edge(clk0_s);
            wait for 150 ns;
            gate0 <= '1';

            wait for CLK0PERIOD_C*9;

            ---------------------------------------------------------------------------
                                                        -- Diagram 3, wr to counter
            abus_s <= "11";                             -- Control Register 
            data_s <= X"18";                            -- CW, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"03";                            -- LSB 03
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            wait until falling_edge(clk0_s);
            wait until rising_edge(clk0_s);
            wait for 160 ns;

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"02";                            -- LSB 02
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            wait for CLK0PERIOD_C*15;
            
            ---------------------------------------------------------------------------
            -- Mode5 Counter 0, LSB Only, even value
            ---------------------------------------------------------------------------
            assert FALSE report "*** Start of Mode5 ***" severity note;

            gate0 <= '0';                               -- Diagram 1

            abus_s <= "11";                             -- Control Register 
            data_s <= X"1A";                            -- CW, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"03";                            -- LSB  03
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);
            
            wait until falling_edge(clk0_s);
            wait for 40 ns;
            gate0 <= '1';
            wait for 300 ns;
            gate0 <= '0';

            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait until rising_edge(clk0_s);
            wait for CLK0PERIOD_C/2;
            gate0 <= '1';
            wait until falling_edge(clk0_s);
            wait for CLK0PERIOD_C/2;
            gate0 <= '0';

            wait for CLK0PERIOD_C*15;

            ---------------------------------------------------------------------------
                                                        -- Diagram 2, 2 gate pulses
            abus_s <= "11";                             -- Control Register 
            data_s <= X"1A";                            -- CW, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"03";                            -- LSB  03
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);
            
            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);
            wait for 20 ns;
            gate0 <= '1';                               -- First gate pulse
            wait for 300 ns;                            -- just before rising edge clk0
            gate0 <= '0';

            wait until falling_edge(clk0_s);
            wait until rising_edge(clk0_s);
            wait for CLK0PERIOD_C/2;
            gate0 <= '1';
            wait until falling_edge(clk0_s);
            wait for CLK0PERIOD_C/2;
            gate0 <= '0';

            wait for CLK0PERIOD_C*15;                                  
            
            ---------------------------------------------------------------------------
                                                        -- Diagram 3, 2 gate pulses + new cnt value
            abus_s <= "11";                             -- Control Register 
            data_s <= X"1A";                            -- CW, LSB only mode1
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"03";                            -- LSB  03
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            wait until falling_edge(clk0_s);
            wait for 40 ns;
            gate0 <= '1';                               -- First gate pulse
            wait for 300 ns;
            gate0 <= '0';

            wait until falling_edge(clk0_s);
            wait for CLK0PERIOD_C/2;

            abus_s <= "00";                             -- Counter 0 
            data_s <= X"05";                            -- LSB  05
            outport(abus_s,data_s,csn,wrn,abus_s,dbus_in);

            wait until falling_edge(clk0_s);
            wait until falling_edge(clk0_s);

            wait until falling_edge(clk0_s);
            wait for 40 ns;
            gate0 <= '1';
            wait for 300 ns;
            gate0 <= '0';
            wait for CLK0PERIOD_C*4;                                   

            assert FALSE report "***** END OF WAVEFORM TEST *****" severity failure;

    end process;

end architecture waveform;

