-------------------------------------------------------------------------------
--   HTL8254 - PIT core                                                      --
--                                                                           --
--  https://github.com/htminuslab                                            --
--                                                                           --
-------------------------------------------------------------------------------
-- Project       : HTL8254                                                   --
-- Purpose       : Counter Module                                            --
-- Library       : I8254                                                     --
--                                                                           --
-- Version       : 1.0  20/01/2002   Created HT-LAB                          --
--               : 1.2  30/11/2023   cleaned and uploaded to github          --
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

ENTITY cemodule IS
   PORT( 
      clk        : IN     std_logic;
      clken      : IN     std_logic;
      data_in    : IN     std_logic_vector (7 DOWNTO 0);
      mode_rw0   : IN     std_logic_vector (1 DOWNTO 0);
      bcd        : IN     std_logic;                    -- asserted for BCD counting
      latch_cnt  : IN     std_logic;
      mux_rd     : IN     std_logic;
      mux_wr     : IN     std_logic;
      resetn     : IN     std_logic;
      wrcntp     : IN     std_logic;
      wrdonep    : OUT    std_logic;                    -- WR cycle done pulse required for LSB/MSB mode
      clr_null0  : OUT    std_logic;
      cnt0       : OUT    std_logic;
      cnt1       : OUT    std_logic;
      cnt2       : OUT    std_logic;
      reload_cnt : IN     std_logic;
      cnt_en     : IN     std_logic;
      odd        : OUT    std_logic;                    -- asserted if CR is off value
      dec        : IN     std_logic_vector (1 DOWNTO 0);-- Decrement value, used in mode2, otherwise 1
      data_out   : OUT    std_logic_vector (7 DOWNTO 0)
   );
END cemodule ;


ARCHITECTURE rtl OF cemodule IS

    signal counter_s : std_logic_vector(15 downto 0);
    signal countin_s : std_logic_vector(15 downto 0);

    signal creglsb_s : std_logic_vector(7 downto 0);    -- Counter Register
    signal cregmsb_s : std_logic_vector(7 downto 0);        

    signal latchlsb_s: std_logic_vector(7 downto 0);    -- Counter Latch
    signal latchmsb_s: std_logic_vector(7 downto 0);        

BEGIN
  

    -------------------------------------------------------------------------------
    -- Pending Counter Register
    -- Loaded into CE during reload pulse  
    -------------------------------------------------------------------------------    
    process (clk,resetn)                                -- Write to Counting Register       
        begin
            if (resetn='0') then                     
               creglsb_s <= (others => '0');  
               cregmsb_s <= (others => '0'); 
               wrdonep   <= '0';
            elsif (rising_edge(clk)) then 
                if wrcntp='1' then
                    case mode_rw0 is
                        when "01" =>
                            creglsb_s <= data_in;       -- Write LSB data only
                            cregmsb_s <= (others => '0');
                            wrdonep   <= '1';           -- Only one write
                        when "10" =>
                            creglsb_s <= (others => '0');
                            cregmsb_s <=  data_in;      -- Write MSB data only
                            wrdonep   <= '1';           -- Only one write
                        when others => 
                            if mux_wr='1' then
                               cregmsb_s <= data_in;    -- Write MSB data to CRM
                               wrdonep   <= '1';        -- Second write, done
                            else
                               creglsb_s <= data_in;    -- Write LSB data to CRM
                               wrdonep   <= '0';        -- First write
                            end if; 
                    end case;    
                else
                    wrdonep   <= '0';                  
                end if;
            end if;   
    end process;

    odd <= creglsb_s(0);                                -- asserted if counter is odd value

    -------------------------------------------------------------------------------
    -- "New value available" in CR flag
    -------------------------------------------------------------------------------    
    clr_null0 <= '1' when (clken='1' AND reload_cnt='1') else '0';  -- Clear null_count flag

    -------------------------------------------------------------------------------
    -- main Counting Element CE
    -------------------------------------------------------------------------------

    countin_s <= counter_s-("00000000000000"&dec);      -- Down counter

    process (clk,resetn)                                           
        begin
            if (resetn='0') then                     
               counter_s <= (others => '0'); 
            elsif (rising_edge(clk)) then 
                if clken='1' then
                   if reload_cnt='1' then
                      counter_s <= cregmsb_s & creglsb_s;   -- Load new value
                   elsif cnt_en='1' then 
                      if bcd='1' then 
                          if     countin_s(15 downto 12)=X"F" then  counter_s(15 downto 12)<= X"9"; 
                          elsif  countin_s(15 downto 12)=X"E" then  counter_s(15 downto 12)<= X"8"; 
                          elsif  countin_s(15 downto 12)=X"D" then  counter_s(15 downto 12)<= X"7"; 
                          else   counter_s <= countin_s;
                          end if;
                          
                          if     countin_s(11 downto 8) =X"F" then  counter_s(11 downto 8) <= X"9"; 
                          elsif  countin_s(11 downto 8) =X"E" then  counter_s(11 downto 8) <= X"8"; 
                          elsif  countin_s(11 downto 8) =X"D" then  counter_s(11 downto 8) <= X"7"; 
                          else   counter_s <= countin_s;
                          end if;
                          
                          if     countin_s(7  downto 4) =X"F" then  counter_s(7  downto 4) <= X"9"; 
                          elsif  countin_s(7  downto 4) =X"E" then  counter_s(7  downto 4) <= X"8"; 
                          elsif  countin_s(7  downto 4) =X"D" then  counter_s(7  downto 4) <= X"7"; 
                          else   counter_s <= countin_s;
                          end if;
                          
                          if     countin_s(3  downto 0) =X"F" then  counter_s(3  downto 0) <= X"9"; 
                          elsif  countin_s(3  downto 0) =X"E" then  counter_s(3  downto 0) <= X"8"; 
                          else   counter_s <= countin_s;
                          end if;

                      else
                         counter_s <= countin_s;
                      end if;                                 
                   end if;   
                end if;                                
            end if;   
    end process;

    cnt0 <= '1' when counter_s=X"0000" else '0';        -- asserted when counter=0
    cnt1 <= '1' when counter_s=X"0001" else '0';        -- asserted when counter=1
    cnt2 <= '1' when counter_s=X"0002" else '0';        -- asserted when counter=2

    process (clk,resetn)                                -- Latch Counting Element CE       
        begin
            if (resetn='0') then                     
               latchmsb_s <= (others => '0');  
               latchlsb_s <= (others => '0');            
            elsif (rising_edge(clk)) then 
                if latch_cnt='0' then
                    latchmsb_s <= counter_s(15 downto 8);-- Latch MSB
                    latchlsb_s <= counter_s(7 downto 0);-- Latch LSB
                end if;                                
            end if;   
    end process;

    process (mux_rd,latchlsb_s,latchmsb_s)              -- Output mux       
        begin
            if mux_rd='0' then
                data_out <= latchlsb_s; 
            else
                data_out <= latchmsb_s;
            end if;                            
    end process;

end architecture rtl;
