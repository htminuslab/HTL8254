-------------------------------------------------------------------------------
--  HTL8254 - PIT core                                                       --
--                                                                           --
--  https://github.com/htminuslab                                            --
--                                                                           --
-------------------------------------------------------------------------------
-- Project       : HTL8254                                                   --
-- Purpose       : Gate Clock Module                                         --
-- Library       : I8254                                                     --
--                                                                           --
-- Version       : 1.0  20/01/2002   Created HT-LAB                          --
--               : 1.0a 07/07/2002   Fixed gate rising logic,                --
--               : 1.0b 27/07/2002   Fixed Mode2 and 3 OUT signal, used      --
--               :                   rising edge gatelevel_s instead of clk  --
--               :                   sync'd gatedelay1_s                     --
--               : 1.0c 21/10/2009   Fixed Mode0 two-byte count disable cnt  --
--               : 1.0d 22/10/2009   Disable counting mode 0/2/3 between     --
--               :                   mode set and counter init value         --
--               : 1.1  30/12/2009   Cleaned up code                         --
--               : 1.1a 09/01/2010   Fixed M1/M5 counter rewrite issue       --
--               : 1.2  21/11/2023   cleaned and uploaded to github          --
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY gateclk IS
   PORT( 
      clk        : IN     std_logic;
      reclki     : IN     std_logic;                    -- Rising Edge CLKi
      regate     : IN     std_logic;                    -- Rising Edge GATE
      wrdonep    : IN     std_logic;                    -- pulse when counter fully init
      gate       : IN     std_logic;
      mode       : IN     std_logic_vector (2 DOWNTO 0);
      modepulse  : IN     std_logic;
      outi       : IN     std_logic;                    -- Out In
      resetn     : IN     std_logic;
      cnt_en     : OUT    std_logic;                    -- enable count when 1
      gate_en    : OUT    std_logic;
      latch_stat : IN     std_logic;
      mux_wr     : IN     std_logic;                    -- Ver 1.0c
      mode_rw    : IN     std_logic_vector (1 DOWNTO 0);-- Ver 1.0c
      modeset    : IN     std_logic;                    -- ver 1.0d
      status     : IN     std_logic_vector (6 DOWNTO 0);
      dbus_in    : IN     std_logic_vector (7 DOWNTO 0);
      dbus_out   : OUT    std_logic_vector (7 DOWNTO 0);
      outo       : OUT    std_logic                     -- Out Out
   );
END gateclk ;


architecture rtl of gateclk is

    signal gatelevel_s  : std_logic;
    signal gateedge_s   : std_logic;
    signal cnt_en_m0    : std_logic;                        -- ver 1.0c
    signal cnt_en_m1    : std_logic;                        -- ver 1.0e
    signal cnt_en_m2    : std_logic;
    --signal cnt_en_m5    : std_logic;                        -- Mode5 gate rising edge flag

    signal gate_en_s    : std_logic;
    signal outo_s       : std_logic;

BEGIN

    -------------------------------------------------------------------------------
    -- Rising Edge Gate flag, cleared when CLKi samples it
    -------------------------------------------------------------------------------
    process(clk,resetn)                                     
        begin
            if resetn='0' then
                gateedge_s <= '0';
            elsif rising_edge(clk) then
              --if (reclki='1' OR wrdonep='1') then 
                if (reclki='1' OR modepulse='1') then   -- ver 1.1a
                    gateedge_s <= '0';       
                elsif regate='1' then             
                    gateedge_s <= '1';
                end if;
            end if;     
    end process;

    -------------------------------------------------------------------------------
    -- Gate is sampled on rising edge CLKi clock
    -------------------------------------------------------------------------------
    process(clk,resetn)                                     
        begin
            if resetn='0' then
                gatelevel_s <= '0';
            elsif rising_edge(clk) then
                if reclki='1' then                     
                    gatelevel_s <= gate;
                end if;
            end if;     
    end process;


    -------------------------------------------------------------------------------
    -- Counter Enable signal Mode0 
    -------------------------------------------------------------------------------
    process(mode_rw,mux_wr,gatelevel_s)                 -- Ver 1.0c
        begin
            if (mode_rw="11" AND mux_wr='1') then       -- Ver 1.0e two-byte write, stop counter after first write
                cnt_en_m0 <= '0';                       -- Note modeset is included later on.
            else
                cnt_en_m0 <= gatelevel_s;               -- set flag
            end if;
    end process;

    -------------------------------------------------------------------------------
    -- Counter is inhibited until a trigger pulse is received on the GATE input 
    -- Added for ver 1.0e
    -- Note the datasheets specifies an undefined counter value before the trigger 
    -- pulse ('N' in the datasheets) but measurements on an existing VLSI chip 
    -- shows the counter stops during 'N' cycles.
    -------------------------------------------------------------------------------
    process(clk,resetn)                                           
        begin
            if resetn='0' then
                cnt_en_m1 <= '0';                       -- Disable counting until gate trigger  
            elsif rising_edge(clk) then  
                if modepulse='1' then                   -- ver 1.1a, After init stop counting
                    cnt_en_m1 <= '0';
                elsif (gateedge_s='1') then             -- Start counting on rising_edge gate
                    cnt_en_m1 <= '1'; 
                end if;
            end if;  
    end process;

    cnt_en_m2 <= gatelevel_s;                           -- set flag


    -------------------------------------------------------------------------------
    -- The GATE input is always sampled on the rising edge of CLKn. 
    -- Modes 0 and 4 the GATE input is level sensitive and sampled on the 
    -- rising edge of CLK. 
    -- Modes 1 and 5 the GATE input is rising-edge sensitive.
    -- Modes 2 and 3 the GATE input is both edge and level-sensitive.
    -- signals:
    --  gatelevel_s is GATE samples on the rising edge of CLK
    --  gateedge_s set on a rising edge of GATE, cleared on a falling edge of CLKn 
    -------------------------------------------------------------------------------
    process (clk,resetn)                                -- Select gate as per mode settings
       begin
           if resetn='0' then
               gate_en_s <= '0';
           elsif rising_edge(clk) then
              case mode is
                 when "000"  => gate_en_s <= gatelevel_s;   -- Mode 0, level              
                 when "001"  => gate_en_s <= gateedge_s;    -- Mode 1, edge  
                 when "010"  => gate_en_s <= gatelevel_s OR gateedge_s; -- Mode 2 edge+level      
                 when "011"  => gate_en_s <= gatelevel_s OR gateedge_s; -- Mode 3 edge+level    
                 when "100"  => gate_en_s <= gatelevel_s;   -- Mode 4 level  
                 when others => gate_en_s <= gateedge_s;    -- Mode 5 edge  
              end case;  
           end if;         
    end process;    
    gate_en <= gate_en_s;

    -------------------------------------------------------------------------------
    -- Counter Enable signal, control CE counting.
    -- OUTn signal.
    --
    -- Observed behaviour, Mode 0,2,3 when mode is written counting stops.
    -- When mode is written the modeset signal is asserted. The signal is negated
    -- when the CPU write an init value to the counter.
    -------------------------------------------------------------------------------
    process (mode,gate_en_s,outi,cnt_en_m0,cnt_en_m1,cnt_en_m2,gate,modeset)
       begin
          case mode is
             when "000"  => cnt_en  <= cnt_en_m0 AND (NOT modeset); -- Mode 0, ver 1.0c, ver 1.0d
                            outo_s  <= outi;                        -- gate has no effect on out
             when "001"  => cnt_en  <= cnt_en_m1;                   -- Mode 1
                            outo_s  <= outi;                        -- gate has no effect on out
             when "010"  => cnt_en  <= cnt_en_m2 AND (NOT modeset); -- Mode 2, ver 1.0d
                            outo_s  <= outi OR (NOT gate);          -- gate affects out, effect immediate
             when "011"  => cnt_en  <= gate_en_s AND (NOT modeset); -- Mode 3, ver 1.0d
                            outo_s  <= outi OR (NOT gate);          -- gate affects out, effect immediate
             when "100"  => cnt_en  <= gate_en_s;                   -- Mode 4
                            outo_s  <= outi;                        -- gate has no effect on out
             when others => cnt_en  <= cnt_en_m1;                   -- Mode 5 (same as 1), enabled by rising edge gate 
                            outo_s  <= outi;                        -- gate has no effect on out 
          end case;   
    end process;    
    outo <= outo_s;

    -------------------------------------------------------------------------------
    -- Output databus multiplexer                   
    -------------------------------------------------------------------------------
    process (latch_stat,dbus_in,status,outo_s)
       begin
          if latch_stat='1' then
             dbus_out <= outo_s & status;
          else
             dbus_out <= dbus_in;
          end if;      
    end process;

end architecture rtl;