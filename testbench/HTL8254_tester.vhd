-------------------------------------------------------------------------------
--   HTL8254 - PIT core                                                      --
--                                                                           --
--  https://github.com/htminuslab                                            --
--                                                                           --
-------------------------------------------------------------------------------
-- Project       : HTL8254                                                   --
-- Purpose       : Testbench Tester Module                                   --
-- Library       : I8254                                                     --
--                                                                           --
-- Version       : 1.0  20/01/2002   Created HT-LAB                          --
--               : 1.0a 21/10/2009   Updated Mode0 RW=11 test, added check   --
--               :                   to make sure counter is disabled after  --
--               :                   writing the first byte.                 --
--               : 1.0e 13/12/2009   Added check for rwmode=11 and gate bug  --
--               : 1.1a 09/01/2010   Added test for M1/M5 counter issue      -- 
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


architecture behaviour of HTL8254_tester is
    
signal clk_s        : std_logic:='0';
signal clk0_s       : std_logic:='0';
signal clk1_s       : std_logic:='0';
signal clk2_s       : std_logic:='0';

signal abus_s       : std_logic_vector(1 downto 0);
signal atmp_s       : std_logic_vector(1 downto 0);

signal abus         : std_logic_vector(1 downto 0);
signal data_s       : std_logic_vector(7 downto 0);
signal temp_s       : std_logic_vector(7 downto 0);
signal bool_s       : std_logic;

signal slow_clock0  : std_logic:='0';                   -- Set to 1 to slow down clk0
signal waitstate_s  : std_logic:='1';                   -- Set to 1 to enable waitstates

constant CLKPERIOD_C        : time := 10 ns;
signal   CLK0PERIOD_C       : time := 40 ns;

constant CLK0PERIOD_SLOW_C  : time := 1.3423 us;
constant CLK0PERIOD_FAST_C  : time := 433 ns;

-- Signal Spy Signals 
signal cnt0spy_s    : std_logic_vector(15 downto 0);
signal cnt1spy_s    : std_logic_vector(15 downto 0);
signal cnt2spy_s    : std_logic_vector(15 downto 0);

signal out0spy_s    : std_logic;
signal out1spy_s    : std_logic;
signal out2spy_s    : std_logic;
signal modepulspy_s : std_logic;                        -- Asserted when changing mode

-- Constants
signal CNT0_c       : std_logic_vector(1 downto 0):="00";
signal CNT1_c       : std_logic_vector(1 downto 0):="01";
signal CNT2_c       : std_logic_vector(1 downto 0):="10";
signal CTRL_c       : std_logic_vector(1 downto 0):="11";


BEGIN
    
    -------------------------------------------------------------------------------
    -- Generate System Clock
    -------------------------------------------------------------------------------
    clk_s <= not clk_s after CLKPERIOD_C;       
    clk <= clk_s;

    CLK0PERIOD_C <= CLK0PERIOD_SLOW_C when slow_clock0='1' else CLK0PERIOD_FAST_C;
    
    clk0_s <= not clk0_s after CLK0PERIOD_C;
    clk0 <= clk0_s;
    clk1_s <= not clk1_s after CLK0PERIOD_C;        
    clk1 <= clk1_s; 
    clk2_s <= not clk2_s after CLK0PERIOD_C;    
    clk2 <= clk2_s;     

    a0 <= abus(0);
    a1 <= abus(1);

    process                                             
        begin
            init_signal_spy("/HTL8254_tb/u_0/t0/u_0/counter_s","/HTL8254_tb/u_1/cnt0spy_s",0);
            init_signal_spy("/HTL8254_tb/u_0/t1/u_0/counter_s","/HTL8254_tb/u_1/cnt1spy_s",0);
            init_signal_spy("/HTL8254_tb/u_0/t2/u_0/counter_s","/HTL8254_tb/u_1/cnt2spy_s",0);
            init_signal_spy("/HTL8254_tb/u_0/out0","/HTL8254_tb/u_1/out0spy_s",0);
            init_signal_spy("/HTL8254_tb/u_0/out1","/HTL8254_tb/u_1/out1spy_s",0);
            init_signal_spy("/HTL8254_tb/u_0/out2","/HTL8254_tb/u_1/out2spy_s",0);
            init_signal_spy("/HTL8254_tb/u_0/t0/modepulse","/HTL8254_tb/u_1/modepulspy_s",0);

            wait;
    end process;


    process
        variable L   : line;

        --------------------------------------------------------------------------
        -- Simulate x86 OUT instruction
        --------------------------------------------------------------------------
        procedure outport(                              -- write byte to I/Oport using clk0  
            signal addr_p : in std_logic_vector(1 downto 0);-- Port Address
            signal dbus_p : in std_logic_vector(7 downto 0)) is 
            begin 
                wait until rising_edge(clk_s);
                abus <= addr_p;
                wait for 5 ns;
                csn  <= '0';
                wait until rising_edge(clk_s);
                wait for 3 ns;
                wrn  <= '0';
                dbus_in <= dbus_p;
                wait until rising_edge(clk_s);
                wait until rising_edge(clk_s);
                wait for 1 ns;                      
                abus <= "HH";
                wrn  <= '1';
                csn  <= '1';
                wait for 5 ns;                          -- Some hold time
                dbus_in <= (others=>'Z');
        end outport;

        --------------------------------------------------------------------------
        -- Simulate x86 IN instruction
        --------------------------------------------------------------------------
        procedure inport(                               -- Read from I/O port   
            signal addr_p : in std_logic_vector(1 downto 0);-- Port Address
            signal dbus_p : out std_logic_vector(7 downto 0)) is 
            begin 
                wait until rising_edge(clk_s);
                abus <= addr_p;
                wait for 5 ns;
                csn  <= '0';
                wait until rising_edge(clk_s);
                wait for 3 ns;
                rdn  <= '0';
                wait until rising_edge(clk_s);
                wait for 2 ns;
                dbus_p <= dbus_out;
                wait until rising_edge(clk_s);
                wait for 2 ns;
                abus <= "HH";
                rdn  <= '1';
                csn  <= '1';
                wait for 1 ns;
        end inport;

        function std_to_bool(inp: std_logic) return character is
        begin
            if inp='1' then 
                return '1';
            else 
                return '0';
            end if;
        end std_to_bool;

        --------------------------------------------------------------------------
        -- Get null_count for counter0
        --------------------------------------------------------------------------
        procedure disp_null_cnt0(signal result : out std_logic) is
            begin 
                abus_s <= "11";                         -- Issue Latch Status command 
                data_s <= "11100010";   
                outport(abus_s,data_s);                 -- Issue Read-back command
                abus_s <= "00";
                inport(abus_s,data_s);                  -- Read counter status              

                write(L,string'("Reading Null Count status counter0 = "));
                write(L,std_to_bool(data_s(6)));
                writeline(output,L);
                result<=data_s(6);
                wait for 1 ns;
        end disp_null_cnt0;

        
        --------------------------------------------------------------------------
        -- Display 8254 Status, issue counter latch and status request
        --------------------------------------------------------------------------
        procedure disp_status (                         -- Display Counter Status & Counter Values
            signal addr_p : in std_logic_vector(1 downto 0)) is -- Port Address
            variable onerd_v : std_logic;
            begin 
                
                -- Issue read-back command 11-1-0-111-0
                -- Read Counter0,1,2
                -- Display status
                
                data_s <="11000000";                    -- Issue Latch Status and Counter command
                wait for 0 ns;
                data_s(to_integer(unsigned(addr_p))+1)<='1'; -- Set counter bit

                outport(CTRL_c,data_s);
                inport(addr_p,data_s);                  -- Read LSB Latched status value counter 0

                write(L,string'("Status"));
                write(L,std_to_hex(addr_p));

                if data_s(7)='0' then write(L,string'(" : OUT=0 ")); 
                                 else write(L,string'(" : OUT=1 "));
                end if; 
                if data_s(6)='0' then write(L,string'("NULL_CNT=0 ")); 
                                 else write(L,string'("NULL_CNT=1 "));
                end if; 
                case data_s(5 downto 4) is
                    when "01"   => write(L,string'("LSB  ")); onerd_v:='1';
                    when "10"   => write(L,string'("MSB  ")); onerd_v:='1';
                    when "11"   => write(L,string'("LMSB ")); onerd_v:='0';
                    when others => assert FALSE report "**** ERROR RW value during readback status"
                                severity warning;
                end case;
                case data_s(3 downto 0) is
                    when "0000" => write(L,string'("MODE0 BINARY "));
                    when "0001" => write(L,string'("MODE0 BCD    "));
                    when "0010" => write(L,string'("MODE1 BINARY "));
                    when "0011" => write(L,string'("MODE1 BCD    "));
                    when "0100" => write(L,string'("MODE2 BINARY "));
                    when "0101" => write(L,string'("MODE2 BCD    "));
                    when "0110" => write(L,string'("MODE3 BINARY "));
                    when "0111" => write(L,string'("MODE3 BCD    "));
                    when "1000" => write(L,string'("MODE4 BINARY "));
                    when "1001" => write(L,string'("MODE4 BCD    "));
                    when "1010" => write(L,string'("MODE5 BINARY "));
                    when "1011" => write(L,string'("MODE5 BCD    "));
                    when others => assert FALSE report "**** ERROR MODE value during readback status"
                                severity warning;
                end case;

                --if data_s(6)='0' then                 -- Only read counter if null_count is cleared
                if onerd_v='1' then
                    inport(addr_p,data_s);              -- Read counter value
                    write(L,string'("CNT="));
                    write(L,std_to_hex(data_s));
                else
                    write(L,string'("CNT="));
                    inport(addr_p,temp_s);              -- Read counter value
                    inport(addr_p,data_s);              -- Read counter value
                    write(L,std_to_hex(data_s));
                    write(L,std_to_hex(temp_s));
                end if;
                --end if;

                writeline(output,L);
                wait for 1 ns;
        end disp_status;

        procedure disp_status_all is                    -- Display Counter Status
        begin 
            disp_status(CNT0_c);
            disp_status(CNT1_c);
            disp_status(CNT2_c);
        end disp_status_all;
      
        --------------------------------------------------------------------------
        -- Display 8254 Counter0 for n cycles using non-intrusive signal spy
        --------------------------------------------------------------------------
        procedure disp_counter0_n(n : in integer) is-- Display Counter and OUT values
        begin
            for I in 0 to n loop                        -- Continue Counting
                wait until falling_edge(clk0_s);
                wait until rising_edge(clk_s);          
                wait until rising_edge(clk_s);
                wait for 1 ns;
                write(L,string'("Counter Element 0 = "));
                write(L,std_to_hex(cnt0spy_s));
                write(L,string'(" OUT0="));
                write(L,std_to_bool(out0spy_s));
                writeline(output,L);               
            end loop;
        end disp_counter0_n;

        --------------------------------------------------------------------------
        -- Display 8254 Counter1 for n cycles using non-intrusive signal spy
        --------------------------------------------------------------------------
        procedure disp_counter1_n(n : in integer) is-- Display Counter and OUT values
        begin
            for I in 0 to n loop                        -- Continue Counting
                wait until falling_edge(clk1_s);
                wait until rising_edge(clk_s);          
                wait until rising_edge(clk_s);
                wait for 1 ns;
                write(L,string'("Counter Element 1 = "));
                write(L,std_to_hex(cnt1spy_s));
                write(L,string'(" OUT1="));
                write(L,std_to_bool(out1spy_s));
                writeline(output,L);
            end loop;
        end disp_counter1_n;

        --------------------------------------------------------------------------
        -- Display 8254 Counter2 for n cycles using non-intrusive signal spy
        --------------------------------------------------------------------------
        procedure disp_counter2_n(n : in integer) is-- Display Counter and OUT values
        begin
            for I in 0 to n loop                        -- Continue Counting
                wait until falling_edge(clk2_s);
                wait until rising_edge(clk_s);          
                wait until rising_edge(clk_s);
                wait for 1 ns;
                write(L,string'("Counter Element 2 = "));
                write(L,std_to_hex(cnt2spy_s));
                write(L,string'(" OUT2="));
                write(L,std_to_bool(out2spy_s));
                writeline(output,L);
            end loop;
        end disp_counter2_n;


        begin

            abus_s   <= (others => 'H');
            data_s   <= (others => '0');
            temp_s   <= (others => '0');
            dbus_in  <= (others => 'Z');

            rdn      <= '1';
            resetn   <= '0';
            wrn      <= '1';
            csn      <= '1';
            a0       <= 'H';
            a1       <= 'H';

            gate0    <= '1';
            gate1    <= '1';
            gate2    <= '1';

            wait for 100 ns;
            resetn   <= '1';
            wait for 100 ns;

            ---------------------------------------------------------------------------
            -- Display Status after reset
            ---------------------------------------------------------------------------
            write(L,string'("======= Test1 Mode0 CNT0, Status after reset ======="));   
            writeline(output,L);
            disp_status_all;
            wait for CLK0PERIOD_C*3;


            ---------------------------------------------------------------------------
            -- Mode0 Counter 0, LSB Only
            ---------------------------------------------------------------------------
            write(L,string'("======= Test2 Mode0 CNT0, LSB only, Binary ======="));   
            writeline(output,L);
                                                               
            data_s <= X"10";                            -- LSB only
            outport(CTRL_c,data_s);
            wait until rising_edge(clk0_s);         

            data_s <= X"03";                            -- LSB 02
            outport(CNT0_c,data_s);
            
            write(L,string'("-- Writing 3 to Count Register LSB "));   
            writeline(output,L);

            disp_counter0_n(4);                         -- Display Counter          

            ---------------------------------------------------------------------------
            -- Mode0 Counter 0, MSB Only
            ---------------------------------------------------------------------------
            write(L,string'("======= Test3 Mode0 CNT0, MSB only, Binary ======="));   
            writeline(output,L);
                                                                
            data_s <= X"20";                            -- MSB only
            outport(CTRL_c,data_s);
            wait until rising_edge(clk0_s);

            data_s <= X"03";                            -- LSB 03
            outport(CNT0_c,data_s);
            write(L,string'("-- Writing 3 to Count Register MSB (LSB defaults to 0)"));   
            writeline(output,L);

            disp_counter0_n(2);                         -- Display Counter          

            write(L,string'("-- Wait for counter to reach 0002"));   
            writeline(output,L);
            wait until cnt0spy_s=X"0002";
            disp_counter0_n(2);                         -- Display Counter         
             

            ---------------------------------------------------------------------------
            -- Mode0 Counter 0, LSB/MSB 
            -- (1)Writing the first byte disables counting. Out is set low
            -- immediately (no clock pulse required).
            -- (2)Writing the second byte allows the new count to be
            -- loaded on the next CLK pulse.
            ---------------------------------------------------------------------------
            write(L,string'("======= Test4 Mode0 CNT0, LSB/MSB, Binary ======="));   
            writeline(output,L);
            
            data_s <= X"30";                            -- LSB/MSB
            outport(CTRL_c,data_s);
            
            wait until rising_edge(clk0_s);

            data_s <= X"02";                            -- LSB 
            outport(CNT0_c,data_s);

            write(L,string'("-- Writing first byte, counting should be disabled"));   
            writeline(output,L);
            disp_counter0_n(4);                         -- Display Counter          
            
            data_s <= X"01";                            -- MSB 
            outport(CNT0_c,data_s);

            write(L,string'("-- Writing second MSB byte, Counter=0102, enable counting on first clk pulse"));   
            writeline(output,L);

            disp_counter0_n(4);                         -- Display Counter          
            write(L,string'("-- Wait for counter to reach 0002"));   
            writeline(output,L);
            wait until cnt0spy_s=X"0002";
            disp_counter0_n(3);                         -- Display Counter          


            ---------------------------------------------------------------------------
            -- Mode0 Counter 0, LSB/MSB BCD 
            ---------------------------------------------------------------------------
            write(L,string'("======= Test5 Mode0 CNT0, LSB/MSB, BCD ======="));   
            writeline(output,L);
            
            data_s <= X"31";                            -- LSB/MSB, BCD
            outport(CTRL_c,data_s);
            wait until rising_edge(clk0_s);

            data_s <= X"02";                            -- LSB 
            outport(CNT0_c,data_s);
            data_s <= X"01";                            -- MSB 
            outport(CNT0_c,data_s);

            write(L,string'("-- Writing 0102 to Count Register"));   
            writeline(output,L);

            disp_counter0_n(4);                         -- Display Counter          
            write(L,string'("-- Wait for counter to reach 0002"));   
            writeline(output,L);
            wait until cnt0spy_s=X"0002";
            disp_counter0_n(3);                         -- Display Counter          


            ---------------------------------------------------------------------------
            -- Test Counter Latch command, CNT0, MSB/LSB binary 
            ---------------------------------------------------------------------------
            write(L,string'("======= Test6 Mode0 CNT0, LSB/MSB, Counter Latch command ======="));   
            writeline(output,L);
            
            data_s <= X"30";                            -- LSB/MSB, binary
            outport(CTRL_c,data_s);
            wait until rising_edge(clk0_s);

            data_s <= X"34";                            -- LSB 
            outport(CNT0_c,data_s);
            data_s <= X"12";                            -- MSB 
            outport(CNT0_c,data_s);

            write(L,string'("-- Writing 1234 to Count Register"));   
            writeline(output,L);

            disp_counter0_n(2);                         -- Display Counter
            
            write(L,string'("-- Issue Counter Latch command"));   
            writeline(output,L);
            data_s <= "00000000";                       -- Issue Counter Latch command
            outport(CTRL_c,data_s);

            disp_counter0_n(2);                         -- Continue Counting
            
            write(L,string'("Latched Counter Element = ")); -- Read the counter sometime later 
            inport(CNT0_c,temp_s);                      -- This should be the LSB value after the latch command
            inport(CNT0_c,data_s);                      -- This should be the MSB value after the latch command
            write(L,std_to_hex(data_s));                -- MSB
            write(L,std_to_hex(temp_s));                -- LSB
            writeline(output,L);

            disp_counter0_n(2);


            ---------------------------------------------------------------------------
            -- Issue multiple latch command, only first one is valid 
            ---------------------------------------------------------------------------
            write(L,string'("======= Test7 Mode0 CNT0, LSB/MSB, BCD, Multiple Counter Latch commands ======="));   
            writeline(output,L);
            
            data_s <= X"31";                            -- LSB/MSB, BCD
            outport(CTRL_c,data_s);
            wait until rising_edge(clk0_s);

            data_s <= X"02";                            -- LSB 
            outport(CNT0_c,data_s);
            data_s <= X"20";                            -- MSB 
            outport(CNT0_c,data_s);

            write(L,string'("-- Writing 2002 to Count Register"));   
            writeline(output,L);

            disp_counter0_n(2);                         -- Display Counter
            
            write(L,string'("-- Issue First Counter Latch command"));   
            writeline(output,L);
            data_s <= "00000000";                       -- Issue Counter Latch command
            outport(CTRL_c,data_s);

            disp_counter0_n(2);                         -- Continue Counting
            
            write(L,string'("-- Issue Second Counter Latch command (should be ignored)"));   
            writeline(output,L);
            data_s <= "00000000";                       -- Issue Counter Latch command
            outport(CTRL_c,data_s);
            
            disp_counter0_n(2);                         -- Continue Counting

            write(L,string'("Latched Counter Element = ")); -- Read the counter sometime later 
            inport(CNT0_c,temp_s);                      -- This should be the LSB value after the latch command
            inport(CNT0_c,data_s);                      -- This should be the MSB value after the latch command
            write(L,std_to_hex(data_s));                -- MSB
            write(L,std_to_hex(temp_s));                -- LSB
            writeline(output,L);

            disp_counter0_n(2);


            ---------------------------------------------------------------------------
            -- Test Counter Latch command, CNT0, MSB/LSB binary 
            -- Delayed read (multiple CLK0 cycles) between LSB and MSB
            ---------------------------------------------------------------------------
            write(L,string'("======= Test8 Mode0 CNT0, LSB/MSB, Counter Latch command (slow read) ======="));   
            writeline(output,L);
            
            data_s <= X"30";                            -- LSB/MSB, binary
            outport(CTRL_c,data_s);
            wait until rising_edge(clk0_s);

            data_s <= X"02";                            -- LSB 
            outport(CNT0_c,data_s);
            data_s <= X"12";                            -- MSB 
            outport(CNT0_c,data_s);

            write(L,string'("-- Writing 2002 to Count Register"));   
            writeline(output,L);

            disp_counter0_n(2);                         -- Display Counter
            
            write(L,string'("-- Issue Counter Latch command"));   
            writeline(output,L);
            data_s <= "00000000";                       -- Issue Counter Latch command
            outport(CTRL_c,data_s);

            disp_counter0_n(2);                         -- Continue Counting
            
            write(L,string'("Latched Counter LSB Element = ")); -- Read the counter sometime later 
            inport(CNT0_c,data_s);                      -- This should be the LSB value after the latch command
            write(L,std_to_hex(data_s));                -- MSB
            writeline(output,L);

            disp_counter0_n(2);
            
            write(L,string'("Latched Counter MSB Element = "));-- Read the counter sometime later 
            inport(CNT0_c,data_s);                      -- This should be the LSB value after the latch command
            write(L,std_to_hex(data_s));                -- MSB
            writeline(output,L);
            
            disp_counter0_n(1);


            ---------------------------------------------------------------------------
            -- Read CNT0 without Counter Latch command 
            ---------------------------------------------------------------------------
            write(L,string'("======= Test9 Read Counter0 without a Counter Latch command ======="));   
            writeline(output,L);

            abus_s <= "00";
            for I in 0 to 4 loop                        -- Read a number of times
                write(L,string'("Read Counter0 = "));
                inport(abus_s,data_s);                      
                write(L,std_to_hex(data_s));                
                writeline(output,L);
                wait for 53 ns;                         -- some random value
            end loop;


            ---------------------------------------------------------------------------
            -- Test Read Back command all counters
            ---------------------------------------------------------------------------
            write(L,string'("======= Test10 Read-Back command (all values for counter0) ======="));   
            writeline(output,L);
          
            for IRW in 1 to 3 loop
                for IMODE in 0 to 5 loop
                    for IBCD in 0 to 1 loop
                        data_s <= "00" & std_logic_vector(to_unsigned(IRW,2)) 
                                       & std_logic_vector(to_unsigned(IMODE,3))
                                       & std_logic_vector(to_unsigned(IBCD,1));
                        outport(CTRL_c,data_s);
                        wait until rising_edge(clk_s);
                        disp_status(CNT0_c);
                    end loop;
                end loop;
            end loop;


            ---------------------------------------------------------------------------
            -- Test Multiple read-back commands for counter latch only
            ---------------------------------------------------------------------------
            write(L,string'("======= Test11 Multiple Read-Back commands ======="));   
            writeline(output,L);
            
            data_s <= X"10";                            -- LSB only cnt0, binary
            outport(CTRL_c,data_s);

            write(L,string'("-- Write 99 to Counter 0 (LSB only)"));   
            writeline(output,L);

            data_s <= X"99";                            -- LSB 99
            outport(CNT0_c,data_s);
                         
            inport(CNT0_c,data_s);                      -- Read counter to clear any previous latch commands               

            disp_counter0_n(2);                         -- Display Counter          

            write(L,string'("-- Issue Read-Back Command, but do not yet read it "));   
            writeline(output,L);

            data_s <= "11010010";   
            outport(CTRL_c,data_s);                     -- Issue Read-back command

            disp_counter0_n(2);                         -- Display Counter          

            write(L,string'("-- Issue Read-Back Command, this one should be ignored"));   
            writeline(output,L);

            data_s <= "11010010";   
            outport(CTRL_c,data_s);                     -- Issue Read-back command
            
            inport(CNT0_c,data_s);                      -- This is the value after writing to the counter               
            write(L,string'("Read Latch Counter 0 value = "));              
            write(L,std_to_hex(data_s));                -- Display it, this should be the old value!
            writeline(output,L);

            disp_counter0_n(2);                         -- Display Counter, NULL count should be 0          


            write(L,string'("-- Initialise for LSB/MSB"));   
            writeline(output,L);
            
            inport(CNT0_c,data_s);                      -- Read counter to clear any previous latch commands               

            data_s <= X"30";                            -- LSB/MSB for CNT0
            outport(CTRL_c,data_s);
            
            write(L,string'("-- Write 1004 to Counter 0"));   
            writeline(output,L);

            data_s <= X"04";                            -- LSB 
            outport(CNT0_c,data_s);
            data_s <= X"10";                            -- MSB 
            outport(CNT0_c,data_s);
                         
            inport(CNT0_c,data_s);                      -- Read counter to force incorrect dual read state               

            disp_counter0_n(3);                         -- Display Counter          

            write(L,string'("-- Issue Read-Back Command, but do not yet read it "));   
            writeline(output,L);

            data_s <= "11010110";   
            outport(CTRL_c,data_s);                     -- Issue Read-back command cnt0

            disp_counter0_n(3);                         -- Display Counter          
            
            write(L,string'("Read Latch Counter 0 value (should be 1001) = "));              
            inport(CNT0_c,temp_s);                      -- This should be the LSB value after the latch command
            inport(CNT0_c,data_s);                      -- This should be the MSB value after the latch command
            write(L,std_to_hex(data_s));                -- MSB
            write(L,std_to_hex(temp_s));                -- LSB
            writeline(output,L);
            assert temp_s=X"01" report "**** Error: expected 0x01 for LSB" severity error;
            assert data_s=X"10" report "**** Error: expected 0x10 for MSB" severity error;
            disp_counter0_n(3);                         -- Display Counter          



            ---------------------------------------------------------------------------
            -- Test Null Count
            ---------------------------------------------------------------------------
            write(L,string'("======= Test12 Mode0 CNT0, LSB, Null Count ======="));   
            writeline(output,L);

            write(L,string'("-- Writing to Control Register, NULL Count should be 1 "));   
            writeline(output,L);

            data_s <= X"10";                            -- LSB only
            outport(CTRL_c,data_s);

            disp_null_cnt0(bool_s);                     -- Display Null Count value
            assert bool_s='1' report "failure: Expected NULL_COUNT=1" severity error;
            
            write(L,string'("-- Writing 8 to Count Register, NULL Count should be 1 "));   
            writeline(output,L);

            data_s <= X"08";                            -- LSB 02
            outport(CNT0_c,data_s);
            
            disp_null_cnt0(bool_s);                     -- Display Null Count value
            assert bool_s='1' report "failure: Expected NULL_COUNT=1" severity error;
            
            write(L,string'("-- New count loaded (CR->CE), NULL Count should be 0"));   
            writeline(output,L);
            wait until falling_edge(clk0_s);
            wait until rising_edge(clk_s);          
            wait until rising_edge(clk_s);

            disp_null_cnt0(bool_s);                     -- Display Null Count value
            assert bool_s='0' report "failure: Expected NULL_COUNT=0" severity error;
            
            disp_counter0_n(2);                         -- Display Counter          

            ---------------------------------------------------------------------------
            -- Test Null Count LSB/MSB Null count should remain one until MSB written
            ---------------------------------------------------------------------------
            write(L,string'("======= Test13 Mode0 CNT0, LSB/MSB, Null Count ======="));   
            writeline(output,L);

            write(L,string'("-- Writing to Control Register, NULL Count should be 1 "));   
            writeline(output,L);

            data_s <= X"30";                            -- CNT0, LSB/MSB
            outport(CTRL_c,data_s);

            disp_null_cnt0(bool_s);                     -- Display Null Count value
            assert bool_s='1' report "failure: Expected NULL_COUNT=1" severity error;
            
            write(L,string'("-- Writing 34 to LSB Count Register, NULL Count should remain 1 "));   
            writeline(output,L);

            data_s <= X"34";                            -- LSB 
            outport(CNT0_c,data_s);

            disp_null_cnt0(bool_s);                     -- Display Null Count value
            assert bool_s='1' report "failure: Expected NULL_COUNT=1" severity error;
            
            write(L,string'("-- Writing 12 to MSB Count Register, NULL Count should be 1 "));   
            writeline(output,L);

            data_s <= X"12";                            -- MSB 
            outport(CNT0_c,data_s);
            
            disp_null_cnt0(bool_s);                     -- Display Null Count value
            assert bool_s='1' report "failure: Expected NULL_COUNT=1" severity error;

            write(L,string'("-- New count loaded (CR->CE), NULL Count should change to 0"));   
            writeline(output,L);
            wait until falling_edge(clk0_s);
            wait until rising_edge(clk_s);          
            wait until rising_edge(clk_s);

            disp_null_cnt0(bool_s);                     -- Display Null Count value
            assert bool_s='0' report "failure: Expected NULL_COUNT=0" severity error;

            disp_counter0_n(2);                         -- Display Counter          

            ---------------------------------------------------------------------------
            -- Test Read-Write programming Sequence 1
            -- See Harris Datasheet page 4-5, Possible Programming Sequences
            ---------------------------------------------------------------------------
            write(L,string'("======= Test14 Read-Write programming Sequence 1 ======="));   
            writeline(output,L);

            data_s <= "00110101";                       -- CNT0, LSB/MSB Mode2, BCD 
            outport(CTRL_c,data_s);
            data_s <= X"33";                            -- LSB0 
            outport(CNT0_c,data_s);
            data_s <= X"44";                            -- MSB0 
            outport(CNT0_c,data_s);

            data_s <= "01110110";                       -- CNT1, LSB/MSB Mode3, binary 
            outport(CTRL_c,data_s);
            data_s <= X"22";                            -- LSB1 
            outport(CNT1_c,data_s);
            data_s <= X"55";                            -- MSB1 
            outport(CNT1_c,data_s);

            data_s <= "10111001";                       -- CNT2, LSB/MSB Mode4, BCD 
            outport(CTRL_c,data_s);
            data_s <= X"11";                            -- LSB2 
            outport(CNT2_c,data_s);
            data_s <= X"66";                            -- MSB2 
            outport(CNT2_c,data_s);

            wait until falling_edge(clk0_s);            
            disp_status_all;                            -- Display Status all Counters


            ---------------------------------------------------------------------------
            -- Test Read-Write programming Sequence 2
            -- See Harris Datasheet page 4-5, Possible Programming Sequences
            ---------------------------------------------------------------------------
            write(L,string'("======= Test15 Read-Write programming Sequence 2 ======="));   
            writeline(output,L);

            data_s <= "00111000";                       -- CNT0, LSB/MSB Mode4, binary 
            outport(CTRL_c,data_s);
            data_s <= "01110111";                       -- CNT1, LSB/MSB Mode3, BCD 
            outport(CTRL_c,data_s);
            data_s <= "10110100";                       -- CNT2, LSB/MSB Mode2, binary 
            outport(CTRL_c,data_s);

            data_s <= X"33";                            -- LSB2 
            outport(CNT2_c,data_s);
            data_s <= X"22";                            -- LSB1 
            outport(CNT1_c,data_s);
            data_s <= X"11";                            -- LSB0 
            outport(CNT0_c,data_s);
         
            data_s <= X"66";                            -- MSB0 
            outport(CNT0_c,data_s);
            data_s <= X"55";                            -- MSB1 
            outport(CNT1_c,data_s);
            data_s <= X"44";                            -- MSB2 
            outport(CNT2_c,data_s);
         
            wait until falling_edge(clk0_s);                        
            disp_status_all;                            -- Display Status all Counters


            ---------------------------------------------------------------------------
            -- Test Read-Write programming Sequence 3
            -- See Harris Datasheet page 4-5, Possible Programming Sequences
            ---------------------------------------------------------------------------
            write(L,string'("======= Test16 Read-Write programming Sequence 3 ======="));   
            writeline(output,L);

            data_s <= "10111001";                       -- CNT2, LSB/MSB Mode4, BCD 
            outport(CTRL_c,data_s);
            data_s <= "01110110";                       -- CNT1, LSB/MSB Mode3, binary 
            outport(CTRL_c,data_s);
            data_s <= "00110101";                       -- CNT0, LSB/MSB Mode2, BCD 
            outport(CTRL_c,data_s);

            data_s <= X"11";                            -- LSB2 
            outport(CNT2_c,data_s);
            data_s <= X"66";                            -- MSB2 
            outport(CNT2_c,data_s);

            data_s <= X"22";                            -- LSB1 
            outport(CNT1_c,data_s);
            data_s <= X"55";                            -- MSB1 
            outport(CNT1_c,data_s);

            data_s <= X"33";                            -- LSB0 
            outport(CNT0_c,data_s);
            data_s <= X"44";                            -- MSB0 
            outport(CNT0_c,data_s);

            wait until falling_edge(clk0_s);            
            disp_status_all;                            -- Display Status all Counters

            ---------------------------------------------------------------------------
            -- Test Read-Write programming Sequence 4
            -- See Harris Datasheet page 4-5, Possible Programming Sequences
            ---------------------------------------------------------------------------
            write(L,string'("======= Test17 Read-Write programming Sequence 4 ======="));   
            writeline(output,L);

            data_s <= "01110111";                       -- CNT1, LSB/MSB Mode3, BCD 
            outport(CTRL_c,data_s);
            data_s <= "00111000";                       -- CNT0, LSB/MSB Mode4, binary 
            outport(CTRL_c,data_s);

            data_s <= X"22";                            -- LSB1 
            outport(CNT1_c,data_s);

            data_s <= "10110100";                       -- CNT2, LSB/MSB Mode2, binary 
            outport(CTRL_c,data_s);

            data_s <= X"11";                            -- LSB0 
            outport(CNT0_c,data_s);
            
            data_s <= X"55";                            -- MSB1 
            outport(CNT1_c,data_s);

            data_s <= X"33";                            -- LSB2 
            outport(CNT2_c,data_s);
         
            data_s <= X"66";                            -- MSB0 
            outport(CNT0_c,data_s);

            data_s <= X"44";                            -- MSB2 
            outport(CNT2_c,data_s);
         
            wait until falling_edge(clk0_s);                        
            disp_status_all;                            -- Display Status all Counters

            ---------------------------------------------------------------------------
            -- Mode0 Counter 0, LSB Only
            -- Test GATE signal, 1=enable counting, 0 disable counting
            ---------------------------------------------------------------------------
            write(L,string'("======= Test18 Test CNT0, Mode0 GATE signal ======="));   
            writeline(output,L);
            write(L,string'("-- Setting Mode0 to LSB only, gate0=0"));   
            writeline(output,L);
            gate0<='0';
                                                               
            data_s <= X"10";                            -- LSB only
            outport(CTRL_c,data_s);

            write(L,string'("-- After writing control word counter should stop"));   
            writeline(output,L);
            disp_counter0_n(3);                         -- Display Counter          

            data_s <= X"99";                            -- LSB value 
            outport(CNT0_c,data_s);
            disp_status(CNT0_c);

            write(L,string'("-- After writing counter=99,  counting is controlled by the gate0 signal"));   
            writeline(output,L);
            disp_counter0_n(3);                         -- Display Counter          

            write(L,string'("-- Assert gate0, enable counting"));   
            writeline(output,L);
            gate0<='1';
            disp_counter0_n(3);                         -- Display Counter          
            write(L,string'("-- Negate gate0, disable counting"));   
            writeline(output,L);
            gate0<='0';
            disp_counter0_n(3);                         -- Display Counter   
            
            
            write(L,string'("-- Setting Mode0 to LSB/MSB, counting starts after writing MSB, gate0=0"));   
            writeline(output,L);
            gate0<='0';
                                                               
            data_s <= X"30";                            -- LSB/MSB
            outport(CTRL_c,data_s);
            write(L,string'("-- Writing control register"));   
            writeline(output,L);
            disp_counter0_n(3);                         -- Display Counter   
            
            data_s <= X"99";                            -- LSB value 
            outport(CNT0_c,data_s);
            write(L,string'("-- Writing LSB=99, counter should remain constant"));   
            writeline(output,L);
            disp_counter0_n(3);                         -- Display Counter   

            data_s <= X"02";                            -- MSB value 
            outport(CNT0_c,data_s);
            write(L,string'("-- Writing MSB=02, counter controlled by gate0"));   
            writeline(output,L);
            disp_counter0_n(3);                         -- Display Counter   

            write(L,string'("-- Assert gate0, enable counting "));   
            writeline(output,L);
            gate0<='1';
            disp_counter0_n(3);                         -- Display Counter          
            write(L,string'("-- Negate gate0, disable counting "));   
            writeline(output,L);
            gate0<='0';
            disp_counter0_n(3);                         -- Display Counter                   

            ---------------------------------------------------------------------------
            -- Mode1 Rising edge trigger, CNT0                                        -
            ---------------------------------------------------------------------------
            write(L,string'("======= Test19 Test Mode1 Rising Edge Gate Trigger ======="));   
            writeline(output,L);

            gate0 <= '0';                               -- Only Rising edge should trigger
            write(L,string'("-- Gate is low before writing to control word"));   
            writeline(output,L);
            
            data_s <= "00110011";                       -- LSB/MSB, mode 1, bcd
            outport(CTRL_c,data_s);
            data_s <= X"34";                            -- LSB 
            outport(CNT0_c,data_s);
            data_s <= X"12";                            -- MSB 
            outport(CNT0_c,data_s);

            write(L,string'("-- Write 1234 to Counter 0, counter should remain constant 'N' in datasheets"));               
            writeline(output,L);
            disp_status(CNT0_c);

            disp_counter0_n(2);                         -- Display Counter          
            write(L,string'("-- Gate is asserted, counter should reload to 1234 and starts counting....."));               
            writeline(output,L);
            gate0 <= '1';
            wait until rising_edge(clk_s);              -- only rising edge 
            wait for 1 ns; -- delta issue
            gate0 <= '0';
            disp_counter0_n(3);                         -- Display Counter          

            wait for 1 us;

            write(L,string'("-- Gate is asserted again, counter should reload to 1234"));               
            writeline(output,L);
            gate0 <= '1';
            wait until rising_edge(clk_s);              -- only rising edge 
            wait for 1 ns; -- delta issue            
            gate0 <= '0';

            disp_counter0_n(3);                         -- Display remainder Counter          
 
            ---------------------------------------------------------------------------
            -- Mode2 Counter 0, LSB Only
            -- Test GATE signal, 1=enable counting, 0 disable counting
            ---------------------------------------------------------------------------
            write(L,string'("======= Test20 Test CNT0, Mode2 GATE signal ======="));   
            writeline(output,L);
                                                               
            data_s <= "00010100";                       -- LSB only, Mode2
            outport(CTRL_c,data_s);
            data_s <= X"99";                            -- LSB 
            outport(CNT0_c,data_s);
            disp_status(CNT0_c);

            write(L,string'("-- Assert gate0, enable counting "));   
            writeline(output,L);
            gate0<='1';
            disp_counter0_n(3);                         -- Display Counter          
            write(L,string'("-- Negate gate0, disable counting "));   
            writeline(output,L);
            wait until rising_edge(clk0_s);
            wait for 40 ns;
            gate0<='0';

            disp_counter0_n(4);                         -- Display Counter          
            gate0<='1';

            ---------------------------------------------------------------------------
            -- Mode3 Counter 0, LSB Only
            -- Test GATE signal, 1=enable counting, 0 disable counting
            ---------------------------------------------------------------------------
            write(L,string'("======= Test21 Test CNT0, Mode3 GATE signal ======="));   
            writeline(output,L);
                                                               
            data_s <= "00010110";                       -- LSB only, Mode3
            outport(CTRL_c,data_s);
            data_s <= X"99";                            -- LSB 
            outport(CNT0_c,data_s);
            disp_status(CNT0_c);

            write(L,string'("-- Assert gate0, enable counting "));   
            writeline(output,L);
            gate0<='1';
            disp_counter0_n(3);                         -- Display Counter          
            write(L,string'("-- Negate gate0, disable counting "));   
            writeline(output,L);
            gate0<='0';
            disp_counter0_n(3);                         -- Display Counter          
            write(L,string'("-- Assert gate0, reload initial value (99)"));   
            writeline(output,L);            
            gate0<='1';
            disp_counter0_n(3);                         -- Display Counter          


            ---------------------------------------------------------------------------
            -- Mode4 Counter 0, LSB Only
            -- Test GATE signal, 1=enable counting, 0 disable counting
            ---------------------------------------------------------------------------
            write(L,string'("======= Test22 Test CNT0, Mode4 GATE signal ======="));   
            writeline(output,L);
                                                               
            data_s <= "00011000";                       -- LSB only, Mode4
            outport(CTRL_c,data_s);
            data_s <= X"99";                            -- LSB 
            outport(CNT0_c,data_s);
            disp_status(CNT0_c);

            write(L,string'("-- Assert gate0, enable counting "));   
            writeline(output,L);
            gate0<='1';
            disp_counter0_n(3);                         -- Display Counter          
            write(L,string'("-- Negate gate0, disable counting "));   
            writeline(output,L);
            gate0<='0';
            disp_counter0_n(3);                         -- Display Counter          

            ---------------------------------------------------------------------------
            -- Mode5 Rising edge triggers counting                                        -
            ---------------------------------------------------------------------------
            write(L,string'("======= Test23 Test CNT0, Mode5 Rising Edge Gate triggers counting ======="));   
            writeline(output,L);

          gate0 <= '0';
          wait for 100 ns;
            gate0 <= '1';                               -- Only Rising edge should trigger
            write(L,string'("-- Gate is high before writing to control word"));   
            writeline(output,L);
            
            data_s <= "00011011";                       -- LSB, mode 5, bcd
            outport(CTRL_c,data_s);
            data_s <= X"99";                            -- LSB 
            outport(CNT0_c,data_s);
            disp_status(CNT0_c);

            write(L,string'("-- Write 99 to Counter 0, counting is inhibited until rising edge gate"));               
            writeline(output,L);

            disp_counter0_n(3);                         -- Display Counter          
            write(L,string'("-- Gate is negated, counting still inhibited....."));               
            writeline(output,L);
            
            gate0 <= '0';
            disp_counter0_n(3);                         -- Display Counter          

            write(L,string'("-- Gate is asserted (rising edge), counter loads and starts counting"));               
            writeline(output,L);
            gate0 <= '1';
            disp_counter0_n(0);                         -- Display Counter          
            gate0 <= '0';
            disp_counter0_n(12);                         -- Display Counter          
            
            gate0 <= '1';                               -- Rising edge pulse
            wait until rising_edge(clk_s);
            wait for 1 ns;
            gate0 <= '0'; 
                       
            write(L,string'("-- Assert gate0 (rising edge), reload initial value (99)"));   
            writeline(output,L);            
            disp_counter0_n(4);                         -- Display Counter          
            
            ---------------------------------------------------------------------------
            -- Mode0 Counter 0, LSB Only, check OUT signal after mode change
            -- Test GATE signal, 1=enable counting, 0 disable counting
            ---------------------------------------------------------------------------
            write(L,string'("======= Test24 Test CNT0, Check OUT signal after MODE write ======="));   
            writeline(output,L);
                                                               
            data_s <= "00010000";                       -- LSB only, Mode0
            outport(CTRL_c,data_s);
            wait until falling_edge(modepulspy_s);
            wait until rising_edge(clk_s);              -- 4 clk cycles after changing mode OUT is updated.
            wait for 1 ns;
            write(L,string'("Mode0 OUT should be 0, OUT0="));
            write(L,std_to_bool(out0spy_s));
            writeline(output,L);
            assert out0spy_s='0' report "failure: OUT0 not low after setting mode=0" severity error;
            
            data_s <= "00010000";                       -- LSB only, Mode0, set OUT back to zero
            outport(CTRL_c,data_s);

            data_s <= "00010010";                       -- LSB only, Mode1
            outport(CTRL_c,data_s);
            wait until falling_edge(modepulspy_s);
            wait until rising_edge(clk_s);              -- 4 clk cycles after changing mode OUT is updated.         
            write(L,string'("Mode1 OUT should be 1, OUT0="));
            write(L,std_to_bool(out0spy_s));
            writeline(output,L);
            assert out0spy_s='1' report "failure: OUT0 not high after setting mode=1" severity error;
             
            data_s <= "00010000";                       -- LSB only, Mode0, set OUT back to zero
            outport(CTRL_c,data_s);

            data_s <= "00010100";                       -- LSB only, Mode2
            outport(CTRL_c,data_s);
            wait until falling_edge(modepulspy_s);
            wait until rising_edge(clk_s);              -- 4 clk cycles after changing mode OUT is updated.
            write(L,string'("Mode2 OUT should be 1, OUT0="));
            write(L,std_to_bool(out0spy_s));
            writeline(output,L);
            assert out0spy_s='1' report "failure: OUT0 not high after setting mode=2" severity error;
            
            data_s <= "00010000";                       -- LSB only, Mode0, set OUT back to zero
            outport(CTRL_c,data_s);

            data_s <= "00010110";                       -- LSB only, Mode3
            outport(CTRL_c,data_s);
            wait until falling_edge(modepulspy_s);
            wait until rising_edge(clk_s);              -- 4 clk cycles after changing mode OUT is updated.
            write(L,string'("Mode3 OUT should be 1, OUT0="));
            write(L,std_to_bool(out0spy_s));
            writeline(output,L);
            assert out0spy_s='1' report "failure: OUT0 not high after setting mode=3" severity error;

            data_s <= "00010000";                       -- LSB only, Mode0, set OUT back to zero
            outport(CTRL_c,data_s);

            data_s <= "00011000";                       -- LSB only, Mode4
            outport(CTRL_c,data_s);
            wait until falling_edge(modepulspy_s);
            wait until rising_edge(clk_s);              -- 4 clk cycles after changing mode OUT is updated.
            write(L,string'("Mode4 OUT should be 1, OUT0="));
            write(L,std_to_bool(out0spy_s));
            writeline(output,L);
            assert out0spy_s='1' report "failure: OUT0 not high after setting mode=4" severity error;

            data_s <= "00010000";                       -- LSB only, Mode0, set OUT back to zero
            outport(CTRL_c,data_s);

            data_s <= "00011010";                       -- LSB only, Mode5
            outport(CTRL_c,data_s);
            wait until falling_edge(modepulspy_s);
            wait until rising_edge(clk_s);              -- 4 clk cycles after changing mode OUT is updated.
            write(L,string'("Mode5 OUT should be 1, OUT0="));
            write(L,std_to_bool(out0spy_s));
            writeline(output,L);
            assert out0spy_s='1' report "failure: OUT0 not high after setting mode=5" severity error;


            ---------------------------------------------------------------------------
            -- Mode3 Counter0 Even
            ---------------------------------------------------------------------------
            write(L,string'("======= Test25 Test Mode3 CNT0 Even Initial Value ======="));   
            writeline(output,L);

            gate0<='1';
            wait until rising_edge(clk0_s);

            --data_s <= "00010110";                       -- CW, LSB only mode3
            data_s <= "00110110";                       -- CW, LSB/MSB mode3
            outport(CTRL_c,data_s);

            data_s <= X"04";                            -- LSB 04
            outport(CNT0_c,data_s);
            data_s <= X"00";                            -- MSB 04
            outport(CNT0_c,data_s);

            write(L,string'("-- Writing 04 to Counter 0, expect the following sequence N,4,2,4,2....."));   
            writeline(output,L);
            disp_counter0_n(11);                         -- Display Counter          

            ---------------------------------------------------------------------------
            -- Mode3 Counter0 Odd
            ---------------------------------------------------------------------------
            write(L,string'("======= Test26 Test Mode3 CNT0 Odd Initial Value ======="));   
            writeline(output,L);

            data_s <= "00010110";                       -- CW, LSB only mode3
            outport(CTRL_c,data_s);

            data_s <= X"05";                            -- LSB 05
            outport(CNT0_c,data_s);
            write(L,string'("-- Writing 05 to Counter 0, expect the following sequence N,5,4,2,5,2,5,4,2,5,2....."));   
            writeline(output,L);
            disp_counter0_n(15);                         -- Display Counter          



            ---------------------------------------------------------------------------
            -- Mode0, gate off, write 0000
            -- The output goes inactive when you write the count and when you gate it on 
            -- it counts for 0+1 i.e. 65536 counts before going active.
            ---------------------------------------------------------------------------             
            write(L,string'("======= Test27 Mode0 CNT0=0, gate=0, LSB/MSB, Binary ======="));   
            writeline(output,L);

            gate0  <= '0';                              -- Gate disabled

            data_s <= X"30";                            -- LSB/MSB
            outport(CTRL_c,data_s);           
            data_s <= X"00";                            -- LSB 
            outport(CNT0_c,data_s);            
            data_s <= X"00";                            -- MSB 
            outport(CNT0_c,data_s);
            assert out0spy_s='0' report "failure: OUT0 should be 0 after control word written" severity error;
             
            --assert cnt0spy_s=X"0000" report "failure: Expected CNT0=0000" severity error;

            wait for 2 us;

            --assert cnt0spy_s=X"0000" report "failure: Expected CNT0=0000" severity error;

            gate0  <= '1';                              -- Gate on, next rising edge samples it
            wait until rising_edge(clk0_s);

            assert out0spy_s='0' report "failure: OUT0 asserted incorrectly" severity error;

            wait until rising_edge(clk0_s);
            assert cnt0spy_s=X"FFFF" report "failure: Expected CNT0=FFFF" severity error;
            assert out0spy_s='0' report "failure: OUT0 asserted incorrectly" severity error;
            

            write(L,string'("-- Wait for counter to reach 0000 (will take some time....)"));   
            writeline(output,L);

            L1:loop
                wait until rising_edge(clk0_s);
                if cnt0spy_s=X"0003" then
                    exit L1;
                end if;
                assert out0spy_s='0' report "failure: OUT0 asserted incorrectly" severity error;
            end loop L1;    
            
            wait for 100 ns;
            ---------------------------------------------------------------------------
            -- Stop the counter when reaching 0003, negate the gate for 3 clk0 cycles, 
            -- see diagram 2 of mode0.
            ---------------------------------------------------------------------------
            gate0  <= '0';                              -- Gate off, counter should stop
            wait until rising_edge(clk0_s);
            assert cnt0spy_s=X"0002" report "failure: Expected CNT0=0002" severity error;
            wait until rising_edge(clk0_s);
            assert cnt0spy_s=X"0002" report "failure: Expected CNT0=0002" severity error;
            wait until falling_edge(clk0_s);
            wait for 100 ns;
            gate0  <= '1';
            wait until rising_edge(clk0_s);
            assert cnt0spy_s=X"0002" report "failure: Expected CNT0=0002" severity error;
            
            
            L2:loop
                wait until rising_edge(clk0_s);
                if cnt0spy_s=X"0000" then
                    exit L2;
                end if;
                assert out0spy_s='0' report "failure: OUT0 asserted incorrectly" severity error;
            end loop L2;                                        
            assert out0spy_s='1' report "failure: OUT0 not asserted when count=0000" severity error;

            
            ---------------------------------------------------------------------------
            -- Mode1, gate off, write 0000
            ---------------------------------------------------------------------------             
            write(L,string'("======= Test28 Mode1 CNT0=0, gate=0, LSB/MSB, Binary ======="));   
            writeline(output,L);

            gate0 <= '0';                               -- Only Rising edge should trigger
            
            data_s <= "00110010";                       -- LSB/MSB, mode 1, bin
            outport(CTRL_c,data_s);
            data_s <= X"00";                            -- LSB 
            outport(CNT0_c,data_s);
            outport(CNT0_c,data_s);                     -- MSB

            wait for 1 us;
            write(L,string'("-- Generate gate pulse, this will load the counter with 0000"));   
            writeline(output,L);
                        
            gate0 <= '1';                               -- pulse
            wait until rising_edge(clk0_s);             -- Note gate is sampled on rising edge of clk0
            gate0 <= '0';
            wait until falling_edge(clk0_s);            -- counter must be zero


            ---------------------------------------------------------------------------
            -- Mode5, gate off, write 0000
            ---------------------------------------------------------------------------             
            write(L,string'("======= Test29 Mode5 CNT0=0, gate=0, LSB/MSB, Binary ======="));   
            writeline(output,L);

            gate0 <= '0';                               -- Only Rising edge should trigger
            
            data_s <= "00111010";                       -- LSB/MSB, mode 5, bin
            outport(CTRL_c,data_s);
            
            data_s <= X"00";                            -- LSB 
            outport(CNT0_c,data_s);
            outport(CNT0_c,data_s);                     -- MSB

            wait for 3 us;
                        
            gate0 <= '1'; -- pulse
            wait until rising_edge(clk0_s);
            gate0 <= '0';
            
            wait until rising_edge(clk0_s);             -- Note N+1 CLK pulses later counter is loaded
            assert cnt0spy_s=X"0000" report "failure: Expected CNT0=0000" severity error;
            wait until rising_edge(clk0_s);
            assert cnt0spy_s=X"FFFF" report "failure: Expected CNT0=FFFF" severity error;

            write(L,string'("-- Wait for counter to reach 0000 (will take some time....)"));   
            writeline(output,L);

            L3:loop
                wait until rising_edge(clk0_s);
                if cnt0spy_s=X"0000" then
                    exit L3;
                end if;
                assert out0spy_s='1' report "failure: OUT0 negated incorrectly" severity error;
            end loop L3;                                        
            assert out0spy_s='0' report "failure: OUT0 not negated when count=0000" severity error;
            wait until rising_edge(clk0_s);
            assert out0spy_s='1' report "failure: OUT0 is not re-asserted after counter increasing" severity error;

            wait for 10 us;

            ---------------------------------------------------------------------------             
            -- Generate another pulse just AFTER the rising edge CLK0, the GATE is always
            -- samples on the rising edge of CLK0, thus after the next rising edge of CLK0
            -- the counter is reloaded with 0000
            ---------------------------------------------------------------------------             
            gate0 <= '1';                               -- pulse
            wait for 100 ns;
            gate0 <= '0';
            wait until rising_edge(clk0_s);             -- GATE is now sampled
            wait until rising_edge(clk0_s);             -- counter is now reloaded
            assert cnt0spy_s=X"0000" report "failure: Expected CNT0=0000" severity error;

            ---------------------------------------------------------------------------
            -- Mode1, write new count whilst counting, this should not affect                                         -
            ---------------------------------------------------------------------------
            write(L,string'("======= Test30 Test Mode1, write new count during counting ======="));   
            writeline(output,L);

            gate0 <= '0';                               -- Only Rising edge should trigger
            write(L,string'("-- Gate is low before writing to control word"));   
            writeline(output,L);
            
            data_s <= "00110011";                       -- LSB/MSB, mode 1, bcd
            outport(CTRL_c,data_s);
            data_s <= X"34";                            -- LSB 
            outport(CNT0_c,data_s);
            data_s <= X"12";                            -- MSB 
            outport(CNT0_c,data_s);

            write(L,string'("-- Write 1234 to Counter 0, counter should remain constant 'N' in datasheets"));               
            writeline(output,L);
            disp_status(CNT0_c);

            disp_counter0_n(2);                         -- Display Counter          
            write(L,string'("-- Gate is asserted, counter should reload to 1234 and starts counting....."));               
            writeline(output,L);
            gate0 <= '1';
            wait until rising_edge(clk_s);              -- only rising edge 
            wait for 1 ns; -- delta issue
            gate0 <= '0';
            disp_counter0_n(3);                         -- Display Counter          

            wait for 1 us;

            write(L,string'("-- Write new counter value 7654, counter should continue counting..."));               
            writeline(output,L);
            
            data_s <= X"54";                            -- LSB 
            outport(CNT0_c,data_s);
            data_s <= X"76";                            -- MSB 
            outport(CNT0_c,data_s);

            disp_counter0_n(3);                         -- Display remainder Counter          

            write(L,string'("-- ReAssert Gate, counter should reload to 7654 and starts counting....."));               
            writeline(output,L);
            gate0 <= '1';
            wait until rising_edge(clk_s);              -- only rising edge 
            wait for 1 ns; -- delta issue
            gate0 <= '0';
            disp_counter0_n(3);                         -- Display Counter          

            ---------------------------------------------------------------------------
            -- Mode5 Rising edge triggers counting                                    -
            ---------------------------------------------------------------------------
            write(L,string'("======= Test31, Mode5, write new count during counting ======="));   
            writeline(output,L);

            gate0 <= '0';
            wait for 100 ns;
            gate0 <= '1';                               -- Only Rising edge should trigger
            write(L,string'("-- Gate is high before writing to control word"));   
            writeline(output,L);
            
            data_s <= "00011011";                       -- LSB only, mode 5, bcd
            outport(CTRL_c,data_s);
            data_s <= X"87";                            -- LSB 
            outport(CNT0_c,data_s);
            disp_status(CNT0_c);

            write(L,string'("-- Write 87 to Counter 0, counting is inhibited until rising edge gate"));               
            writeline(output,L);
            gate0 <= '0';
            disp_counter0_n(3);                         -- Display Counter                     
            

            write(L,string'("-- Gate is asserted (rising edge), counter loads and starts counting"));               
            writeline(output,L);
            gate0 <= '1';
            disp_counter0_n(2);                         -- Display Counter          
            gate0 <= '0';
            disp_counter0_n(2);                         -- Display Counter          
            
            write(L,string'("-- Write new counter value 98, counter should continue counting..."));               
            writeline(output,L);
            
            data_s <= X"98";                            -- LSB 
            outport(CNT0_c,data_s);
            
            disp_counter0_n(3);                         -- Display Counter          

            gate0 <= '1';                               -- Rising edge pulse
            wait until rising_edge(clk_s);
            wait for 1 ns;
            gate0 <= '0'; 
                       
            write(L,string'("-- Assert gate0 (rising edge), load new value (98)"));   
            writeline(output,L);            
            disp_counter0_n(4);                         -- Display Counter          


            ---------------------------------------------------------------------------
            -- Test combined status latch command
            ---------------------------------------------------------------------------
            write(L,string'("======= Test32 Mode0 CNT0, LSB/MSB, combined Status/Latch Readback command ======="));   
            writeline(output,L);
            gate0    <= '1';

            data_s <= X"30";                            -- LSB/MSB for CNT0
            outport(CTRL_c,data_s);

            write(L,string'("-- Write 1004 to Counter 0"));   
            writeline(output,L);

            data_s <= X"04";                            -- LSB 
            outport(CNT0_c,data_s);
            data_s <= X"10";                            -- MSB 
            outport(CNT0_c,data_s);                         
            disp_counter0_n(3);                         -- Display Counter          

            write(L,string'("-- Issue Read-Back Status/Latch Command, but do not yet read it "));   
            writeline(output,L);

            data_s <= "11000110";   
            outport(CTRL_c,data_s);                     -- Issue Read-back status/latchcommand cnt0

            disp_counter0_n(3);                         -- Display Counter          
            
            write(L,string'("-- First Counter read returns the status = "));   
            inport(CNT0_c,data_s);                      -- This should be the status
            write(L,std_to_hex(data_s));                -- MSB
            writeline(output,L);

            disp_counter0_n(2);                         -- Display Counter 
            
            write(L,string'("-- Second Counter read returns the latched value = "));   
            inport(CNT0_c,temp_s);                      -- This should be the counter latched value
            inport(CNT0_c,data_s);                      -- This should be the MSB value after the latch command
            write(L,std_to_hex(data_s));                -- MSB
            write(L,std_to_hex(temp_s));                -- LSB
            writeline(output,L);
            assert temp_s=X"01" report "**** Error: expected 0x01 for LSB" severity error;
            assert data_s=X"10" report "**** Error: expected 0x10 for MSB" severity error;
            disp_counter0_n(3);                         -- Display Counter          
                     

            assert FALSE report "***** END OF TEST *****" severity failure;
            wait;
    end process; 

END ARCHITECTURE behaviour;
