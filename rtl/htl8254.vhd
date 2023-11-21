-------------------------------------------------------------------------------
--  HTL8254 - PIT core                                                       --
--                                                                           --
--  https://github.com/htminuslab                                            --
--                                                                           --
-------------------------------------------------------------------------------
--  Project       : HTL8254                                                  --
--  Purpose       : Top Level                                                --
--  Library       : I8254                                                    --
--                                                                           --
--  Version       : 1.0  20/01/2002   Created HT-LAB                         --
--                : 1.2  30/11/2023   cleaned and uploaded to github         --
-- ----------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
use ieee.NUMERIC_STD.all;

entity HTL8254 is
    port( 
        a0       : in     std_logic;
        a1       : in     std_logic;
        clk      : in     std_logic;
        clk0     : in     std_logic;
        clk1     : in     std_logic;
        clk2     : in     std_logic;
        csn      : in     std_logic;
        dbus_in  : in     std_logic_vector (7 downto 0);
        gate0    : in     std_logic;
        gate1    : in     std_logic;
        gate2    : in     std_logic;
        rdn      : in     std_logic;
        resetn   : in     std_logic;
        wrn      : in     std_logic;
        dbus_out : out    std_logic_vector (7 downto 0);
        out0     : out    std_logic;
        out1     : out    std_logic;
        out2     : out    std_logic
    );
end HTL8254 ;

architecture struct of HTL8254 is

    signal wrdelay1_s  : std_logic_vector(3 downto 0);
    signal wrdelay2_s  : std_logic_vector(3 downto 0);
    signal rddelay1_s  : std_logic_vector(2 downto 0);
    signal rddelay2_s  : std_logic_vector(2 downto 0);
    signal abus_s : std_logic_vector(1 downto 0);

    signal datareg_s : std_logic_vector(7 downto 0);
    signal dbus_out0 : std_logic_vector(7 downto 0);
    signal dbus_out1 : std_logic_vector(7 downto 0);
    signal dbus_out2 : std_logic_vector(7 downto 0);
    signal rd_s      : std_logic;
    signal rdcnt0p_s : std_logic;
    signal rdcnt1p_s : std_logic;
    signal rdcnt2p_s : std_logic;
    signal wr_s      : std_logic;
    signal wrcnt0p_s : std_logic;
    signal wrcnt1p_s : std_logic;
    signal wrcnt2p_s : std_logic;
    signal wrctrlp_s : std_logic;


    component timer
    generic (
        COUNTER_ID : std_logic_vector(1 downto 0) := "00"
    );
    port (
        clk       : in     std_logic ;
        clki      : in     std_logic ;
        datareg_s : in     std_logic_vector (7 downto 0);
        gate      : in     std_logic ;
        rdcntp_s  : in     std_logic ;
        resetn    : in     std_logic ;
        wrcntp_s  : in     std_logic ;
        wrctrlp_s : in     std_logic ;
        dbus_out  : out    std_logic_vector (7 downto 0);
        outo      : out    std_logic 
    );
    end component;


begin

    -- Create single clk wr pulse
    process (clk,resetn)                                          
        begin
          if (resetn='0') then     
             wrdelay1_s   <= (others => '0');   
             wrdelay2_s   <= (others => '0');             
          elsif (rising_edge(clk)) then 
             wrdelay1_s(3) <= wr_s AND a1 AND a0;
             wrdelay1_s(2) <= wr_s AND a1 AND (NOT a0);
             wrdelay1_s(1) <= wr_s AND (NOT a1) AND a0;
             wrdelay1_s(0) <= wr_s AND (NOT a1) AND (NOT a0);
             wrdelay2_s    <= wrdelay1_s;
          end if;   
    end process;
    
    wrctrlp_s <= wrdelay2_s(3) AND NOT(wrdelay1_s(3));   -- Rising edge Control wr strobe
    wrcnt2p_s <= wrdelay2_s(2) AND NOT(wrdelay1_s(2));   -- Rising edge Counter 2 wr strobe
    wrcnt1p_s <= wrdelay2_s(1) AND NOT(wrdelay1_s(1));   -- Rising edge Counter 1 wr strobe
    wrcnt0p_s <= wrdelay2_s(0) AND NOT(wrdelay1_s(0));   -- Rising edge Counter 0 wr strobe
         

    rd_s <= '1' when (rdn='0' AND csn='0') else '0';
    wr_s <= '1' when (wrn='0' AND csn='0') else '0';
    
    process (clk,resetn)                         -- Data (dbus_in) Register                                         
        begin
            if (resetn='0') then                     
               datareg_s <= (others => '0');           
          elsif (rising_edge(clk)) then 
             if wr_s='1' then 
                   datareg_s <= dbus_in;
             end if;
            end if;   
    end process;

    abus_s <= a1&a0;                     
    
    process (abus_s,dbus_out0,dbus_out1,dbus_out2) 
       begin
          case abus_s is
             when "00"  => dbus_out <= dbus_out0; 
             when "01"  => dbus_out <= dbus_out1;      
             when others=> dbus_out <= dbus_out2;              
          end case;   
    end process;                                      

    -- Create single clk rd pulse
    process (clk,resetn)                                          
        begin
            if (resetn='0') then     
               rddelay1_s   <= (others => '0');   
               rddelay2_s   <= (others => '0');             
          elsif (rising_edge(clk)) then 
             rddelay1_s(2) <= rd_s AND a1 AND (NOT a0);
             rddelay1_s(1) <= rd_s AND (NOT a1) AND a0;
             rddelay1_s(0) <= rd_s AND (NOT a1) AND (NOT a0);
             rddelay2_s    <= rddelay1_s;
            end if;   
    end process;
    
    rdcnt2p_s <= rddelay2_s(2) AND NOT(rddelay1_s(2));   -- Rising edge Counter 2 rd strobe
    rdcnt1p_s <= rddelay2_s(1) AND NOT(rddelay1_s(1));   -- Rising edge Counter 1 rd strobe
    rdcnt0p_s <= rddelay2_s(0) AND NOT(rddelay1_s(0));   -- Rising edge Counter 0 rd strobe                                    
    
    assert not(rd_s='1' AND a0='1' AND a1='1') report "Trying to read the Control Register"
       severity error;

    T0 : timer
        generic map (
            COUNTER_ID => "00"
        )
        port map (
            clk       => clk,
            clki      => clk0,
            datareg_s => datareg_s,
            gate      => gate0,
            rdcntp_s  => rdcnt0p_s,
            resetn    => resetn,
            wrcntp_s  => wrcnt0p_s,
            wrctrlp_s => wrctrlp_s,
            dbus_out  => dbus_out0,
            outo      => out0
        );
    T1 : timer
        generic map (
            COUNTER_ID => "01"
        )
        port map (
            clk       => clk,
            clki      => clk1,
            datareg_s => datareg_s,
            gate      => gate1,
            rdcntp_s  => rdcnt1p_s,
            resetn    => resetn,
            wrcntp_s  => wrcnt1p_s,
            wrctrlp_s => wrctrlp_s,
            dbus_out  => dbus_out1,
            outo      => out1
        );
    T2 : timer
        generic map (
            COUNTER_ID => "10"
        )
        port map (
            clk       => clk,
            clki      => clk2,
            datareg_s => datareg_s,
            gate      => gate2,
            rdcntp_s  => rdcnt2p_s,
            resetn    => resetn,
            wrcntp_s  => wrcnt2p_s,
            wrctrlp_s => wrctrlp_s,
            dbus_out  => dbus_out2,
            outo      => out2
        );

end struct;
