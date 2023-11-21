-------------------------------------------------------------------------------
--   HTL8254 - PIT core                                                      --
--                                                                           --
--  https://github.com/htminuslab                                            --
--                                                                           --
-------------------------------------------------------------------------------
-- Project       : HTL8254                                                   --
-- Purpose       : Counter Control Module                                    --
-- Library       : I8254                                                     --
--                                                                           --
-- Version       : 1.0  20/01/2002   Created HT-LAB                          --
--               : 1.1  09/01/2010   Fixed read-back LSB/MSB sequence issue  --
--               : 1.2  30/11/2023   cleaned and uploaded to github          --
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

ENTITY ctrlword IS
   GENERIC( 
      COUNTER : std_logic_vector(1 downto 0) := "00"
   );
   PORT( 
      clk        : IN     std_logic;
      clr_null   : IN     std_logic;
      datareg_s  : IN     std_logic_vector (7 DOWNTO 0);
      resetn     : IN     std_logic;
      latch_cnt  : OUT    std_logic;
      latch_stat : OUT    std_logic;
      mode       : OUT    std_logic_vector (2 DOWNTO 0);
      bcd        : OUT    std_logic;
      mode_rw    : OUT    std_logic_vector (1 DOWNTO 0);
      modepulse  : OUT    std_logic;
      mux_rd     : OUT    std_logic;
      mux_wr     : OUT    std_logic;
      status     : OUT    std_logic_vector (6 DOWNTO 0);
      wrctrlp_s  : IN     std_logic;
      rdcntp_s   : IN     std_logic;
      wrcntp_s   : IN     std_logic
   );
END ctrlword ;


ARCHITECTURE rtl OF ctrlword IS

    signal modecnt0_s    : std_logic_vector(3 downto 0);-- Mode Counter 0 + BCD bit
    signal mode_rw_s     : std_logic_vector(1 downto 0);-- Read Write sequence LSB,MSB or LSB,MSB

    signal last_rd_s     : std_logic;
    signal toggle_wr0_s  : std_logic;                   -- Toggles every Write (LSB-MSB sequence)
    signal toggle_rd0_s  : std_logic;                   -- Toggles every Read (LSB-MSB sequence)

    signal latch_stat_s  : std_logic;                   -- Latch status counter 0

    signal null_count0_s : std_logic;                   -- Null Count bit counter 0

BEGIN
    
    process (clk,resetn)                                -- Set Mode and BCD bits                                       
        begin
            if (resetn='0') then                     
               modecnt0_s <= (others => '0'); 
               mode_rw_s  <= "11";                      -- 00 is invalid, default to lsb, msb mode
               modepulse  <= '0';                       -- modepulse is asserted when a new mode value 
                                                        -- is written to the ctrl register
            elsif (rising_edge(clk)) then 
                if wrctrlp_s='1' then
                                                        -- COUNTER="00","01" or "10" and not a latch command
                    if  (datareg_s(7 downto 6)=COUNTER AND datareg_s(5 downto 4)/="00") then  
                        modepulse <='1';                
                        modecnt0_s <= datareg_s(3 downto 0);
                        mode_rw_s <= datareg_s(5 downto 4);
                    end if;

                else
                   modepulse <='0';
                end if;
            end if;   
    end process;

    mode_rw <=  mode_rw_s;                              -- connect to outside world
    bcd  <= modecnt0_s(0);                              -- asserted for BCD counting
    mode <= modecnt0_s(3 downto 1);                     -- Mode bits

    -------------------------------------------------------------------------------
    -- Select Read Write sequence. 
    -------------------------------------------------------------------------------
    process (mode_rw_s,toggle_wr0_s)                    -- Select Write sequence (LSB,MSB,LSB-MSB)
        begin
            case mode_rw_s is
                when "01"   => mux_wr   <= '0';     
                when "10"   => mux_wr   <= '1';
                when others => mux_wr   <= toggle_wr0_s;
            end case;       
    end process;

    process (mode_rw_s,toggle_rd0_s)                    -- Select Read sequence (LSB,MSB,LSB-MSB)
        begin
            case mode_rw_s is
                when "01"   => mux_rd    <= '0';        
                               last_rd_s <= '1';        -- Always last rd strobe, i.e. single read
                when "10"   => mux_rd    <= '1';
                               last_rd_s <= '1';
                when others => mux_rd    <= toggle_rd0_s;
                               last_rd_s <= toggle_rd0_s;
            end case;       
    end process;

    -------------------------------------------------------------------------------
    -- Status Value (part only) 
    -------------------------------------------------------------------------------
    status <= null_count0_s & mode_rw_s & modecnt0_s;

    -------------------------------------------------------------------------------
    -- Create Latch Counter Read Data flag 
    -------------------------------------------------------------------------------
    process (clk,resetn)                                                                       
        begin
            if (resetn='0') then   
                latch_cnt<='0';                         -- Clear flag                  
            elsif (rising_edge(clk)) then 
                if (rdcntp_s='1' AND last_rd_s='1' AND latch_stat_s='0') then -- last read?
                    latch_cnt<='0';                     -- Disable latch, follow counter
                elsif (wrctrlp_s='1' AND ( datareg_s(7 downto 4)=COUNTER&"00" OR
                       (datareg_s(7 downto 5)="110" AND datareg_s(conv_integer(COUNTER)+1)='1'))) then  -- Issue latch command
                    latch_cnt<='1';                     -- Enable latch
                end if;
            end if;
    end process;

    -------------------------------------------------------------------------------
    -- Create Latch Counter Read Status flag 
    -------------------------------------------------------------------------------
    process (clk,resetn)                                                                       
        begin
            if (resetn='0') then   
                latch_stat_s<='0';                      -- Clear flag                  
            elsif (rising_edge(clk)) then 
                if (rdcntp_s='1') then                  -- After the first read clear the latch status bit
                    latch_stat_s<='0';                  -- Disable status latch
                elsif (wrctrlp_s='1' AND datareg_s(7 downto 6)="11" AND datareg_s(4)='0' AND datareg_s(conv_integer(COUNTER)+1)='1') then   
                    latch_stat_s<='1';                  -- Enable latch
                end if;
            end if;
    end process;

    latch_stat <= latch_stat_s;

    -------------------------------------------------------------------------------
    -- Toggle FF, change mux from LSB to MSB after a read/write.
    -- This TFF is only used for RW mode 11.
    -- Seperate toggle are required since you can interleave read and writes (why?) 
    -------------------------------------------------------------------------------
    process (clk,resetn)                                -- Toggle mux select                                       
        begin
            if (resetn='0') then                     
               toggle_wr0_s  <= '0';                    -- LSB first
               toggle_rd0_s  <= '0';                            
            elsif (rising_edge(clk)) then 
                                                        -- Write to control register cnt0 then
                --if (wrctrlp_s='1' AND datareg_s(7 downto 6)=COUNTER) then -- or latch_stat_s='1'  then
                if ((wrctrlp_s='1' AND datareg_s(7 downto 6)=COUNTER) OR -- ver 1.1a, Write to control register & issue latch command
                    (wrctrlp_s='1' AND datareg_s(7 downto 6)="11" AND datareg_s(4)='1' AND datareg_s(conv_integer(COUNTER)+1)='1')) then  
                    toggle_wr0_s  <= '0';               -- LSB first
                    toggle_rd0_s  <= '0';   
                end if;
                if (wrcntp_s='1') then                  -- Write toggles it             
                    toggle_wr0_s <= NOT toggle_wr0_s;
                end if; 
                if (rdcntp_s='1' AND latch_stat_s='0') then -- Read toggles unless you read the status            
                    toggle_rd0_s <= NOT toggle_rd0_s;
                end if;     
            end if;   
    end process;

    -------------------------------------------------------------------------------
    -- NULL Count flag
    -- Set when writing to control word and read back? 
    -------------------------------------------------------------------------------
    process (clk,resetn)                                                                               
        begin
            if (resetn='0') then                     
                null_count0_s <= '0';                            
            elsif (rising_edge(clk)) then 
                if (wrctrlp_s='1' AND datareg_s(7 downto 6)=COUNTER AND datareg_s(5 downto 4)/="00") OR wrcntp_s='1' then 
                   null_count0_s <= '1';
                elsif clr_null='1' then                 -- Clear Null count signal only when CR->CE pulse 
                   null_count0_s <= '0';    
                end if;
            end if;   
    end process;

end architecture rtl;
