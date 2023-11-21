-------------------------------------------------------------------------------
--   HTL8254 - PIT core                                                      --
--                                                                           --
--  https://github.com/htminuslab                                            --
--                                                                           --
-------------------------------------------------------------------------------
-- Project       : HTL8254                                                   --
-- Purpose       : Timer Module                                              --
-- Library       : I8254                                                     --
--                                                                           --
-- Version       : 1.0  20/01/2002   Created HT-LAB                          --
--               : 1.2  30/11/2023   cleaned and uploaded to github          --
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;

entity timer is
    generic( 
        COUNTER_ID : std_logic_vector(1 downto 0) := "00"
    );
    port( 
        clk       : in     std_logic;
        clki      : in     std_logic;
        datareg_s : in     std_logic_vector (7 downto 0);
        gate      : in     std_logic;
        rdcntp_s  : in     std_logic;
        resetn    : in     std_logic;
        wrcntp_s  : in     std_logic;
        wrctrlp_s : in     std_logic;
        dbus_out  : out    std_logic_vector (7 downto 0);
        outo      : out    std_logic
    );
end timer ;

architecture struct of timer is

    -- Internal signal declarations
    signal bcd        : std_logic;
    signal clk_en     : std_logic;
    signal clr_null   : std_logic;
    signal cnt0       : std_logic;
    signal cnt1       : std_logic;
    signal cnt2       : std_logic;
    signal cnt_en     : std_logic;
    signal dbus_out_s : std_logic_vector(7 downto 0);
    signal dec        : std_logic_vector(1 downto 0);     -- Decrement value, used in mode2, otherwise 1
    signal gate_en    : std_logic;
    signal gate_s     : std_logic;
    signal latch_cnt  : std_logic;
    signal latch_stat : std_logic;
    signal mode       : std_logic_vector(2 downto 0);
    signal mode_rw    : std_logic_vector(1 downto 0);
    signal modepulse  : std_logic;
    signal modeset    : std_logic;                        -- ver 1.0d
    signal mux_rd     : std_logic;
    signal mux_wr     : std_logic;
    signal odd        : std_logic;                        -- asserted if CR is off value
    signal outo_s     : std_logic;
    signal reclki_s   : std_logic;
    signal regate_s   : std_logic;
    signal reload_cnt : std_logic;                        -- reload counter with CR value(s)
    signal status     : std_logic_vector(6 downto 0);
    signal wrdonep_s  : std_logic;                        -- pulse when counter fully init


    component cemodule
    port (
        clk        : in     std_logic ;
        clken      : in     std_logic ;
        data_in    : in     std_logic_vector (7 downto 0);
        mode_rw0   : in     std_logic_vector (1 downto 0);
        bcd        : in     std_logic ;                    -- asserted for BCD counting
        latch_cnt  : in     std_logic ;
        mux_rd     : in     std_logic ;
        mux_wr     : in     std_logic ;
        resetn     : in     std_logic ;
        wrcntp     : in     std_logic ;
        wrdonep    : out    std_logic ;                    -- WR cycle done pulse required for LSB/MSB mode
        clr_null0  : out    std_logic ;
        cnt0       : out    std_logic ;
        cnt1       : out    std_logic ;
        cnt2       : out    std_logic ;
        reload_cnt : in     std_logic ;
        cnt_en     : in     std_logic ;
        odd        : out    std_logic ;                    -- asserted if CR is off value
        dec        : in     std_logic_vector (1 downto 0); -- Decrement value, used in mode2, otherwise 1
        data_out   : out    std_logic_vector (7 downto 0)
    );
    end component;
    component ctrlout
    port (
        clk        : in     std_logic ;
        clken      : in     std_logic ;
        cnt0       : in     std_logic ;
        cnt1       : in     std_logic ;
        cnt2       : in     std_logic ;
        cnt_en     : in     std_logic ;
        gate_en    : in     std_logic ;
        mode       : in     std_logic_vector (2 downto 0);
        modepulse  : in     std_logic ;
        odd        : in     std_logic ;                    -- asserted if CR is off value
        reclki     : in     std_logic ;
        resetn     : in     std_logic ;
        wrdonep    : in     std_logic ;
        dec        : out    std_logic_vector (1 downto 0); -- Decrement value, used in mode2, otherwise 1
        modeset    : out    std_logic ;
        outo       : out    std_logic ;
        reload_cnt : out    std_logic                      -- reload counter with CR value(s)
    );
    end component;
    component ctrlword
    generic (
        COUNTER : std_logic_vector(1 downto 0) := "00"
    );
    port (
        clk        : in     std_logic ;
        clr_null   : in     std_logic ;
        datareg_s  : in     std_logic_vector (7 downto 0);
        resetn     : in     std_logic ;
        latch_cnt  : out    std_logic ;
        latch_stat : out    std_logic ;
        mode       : out    std_logic_vector (2 downto 0);
        bcd        : out    std_logic ;
        mode_rw    : out    std_logic_vector (1 downto 0);
        modepulse  : out    std_logic ;
        mux_rd     : out    std_logic ;
        mux_wr     : out    std_logic ;
        status     : out    std_logic_vector (6 downto 0);
        wrctrlp_s  : in     std_logic ;
        rdcntp_s   : in     std_logic ;
        wrcntp_s   : in     std_logic 
    );
    end component;
    component edge3ff
    port (
        clk   : in     std_logic;
        din   : in     std_logic;
        dout  : out    std_logic;
        fedge : out    std_logic;
        redge : out    std_logic
    );
    end component;
    component gateclk
    port (
        clk        : in     std_logic ;
        reclki     : in     std_logic ;                    -- Rising Edge CLKi
        regate     : in     std_logic ;                    -- Rising Edge GATE
        wrdonep    : in     std_logic ;                    -- pulse when counter fully init
        gate       : in     std_logic ;
        mode       : in     std_logic_vector (2 downto 0);
        modepulse  : in     std_logic ;
        outi       : in     std_logic ;                    -- Out In
        resetn     : in     std_logic ;
        cnt_en     : out    std_logic ;                    -- enable count when 1
        gate_en    : out    std_logic ;
        latch_stat : in     std_logic ;
        mux_wr     : in     std_logic ;                    -- Ver 1.0c
        mode_rw    : in     std_logic_vector (1 downto 0); -- Ver 1.0c
        modeset    : in     std_logic ;                    -- ver 1.0d
        status     : in     std_logic_vector (6 downto 0);
        dbus_in    : in     std_logic_vector (7 downto 0);
        dbus_out   : out    std_logic_vector (7 downto 0);
        outo       : out    std_logic                      -- Out Out
    );
    end component;


begin

    U_0 : cemodule
        port map (
            clk        => clk,
            clken      => clk_en,
            data_in    => datareg_s,
            mode_rw0   => mode_rw,
            bcd        => bcd,
            latch_cnt  => latch_cnt,
            mux_rd     => mux_rd,
            mux_wr     => mux_wr,
            resetn     => resetn,
            wrcntp     => wrcntp_s,
            wrdonep    => wrdonep_s,
            clr_null0  => clr_null,
            cnt0       => cnt0,
            cnt1       => cnt1,
            cnt2       => cnt2,
            reload_cnt => reload_cnt,
            cnt_en     => cnt_en,
            odd        => odd,
            dec        => dec,
            data_out   => dbus_out_s
        );
    U_2 : ctrlout
        port map (
            clk        => clk,
            clken      => clk_en,
            cnt0       => cnt0,
            cnt1       => cnt1,
            cnt2       => cnt2,
            cnt_en     => cnt_en,
            gate_en    => gate_en,
            mode       => mode,
            modepulse  => modepulse,
            odd        => odd,
            reclki     => reclki_s,
            resetn     => resetn,
            wrdonep    => wrdonep_s,
            dec        => dec,
            modeset    => modeset,
            outo       => outo_s,
            reload_cnt => reload_cnt
        );
    U_1 : ctrlword
        generic map (
            COUNTER => COUNTER_ID
        )
        port map (
            clk        => clk,
            clr_null   => clr_null,
            datareg_s  => datareg_s,
            resetn     => resetn,
            latch_cnt  => latch_cnt,
            latch_stat => latch_stat,
            mode       => mode,
            bcd        => bcd,
            mode_rw    => mode_rw,
            modepulse  => modepulse,
            mux_rd     => mux_rd,
            mux_wr     => mux_wr,
            status     => status,
            wrctrlp_s  => wrctrlp_s,
            rdcntp_s   => rdcntp_s,
            wrcntp_s   => wrcntp_s
        );
    U_5 : edge3ff
        port map (
            clk   => clk,
            din   => clki,
            dout  => open,
            fedge => clk_en,
            redge => reclki_s
        );
    U_6 : edge3ff
        port map (
            clk   => clk,
            din   => gate,
            dout  => gate_s,
            fedge => open,
            redge => regate_s
        );
    U_3 : gateclk
        port map (
            clk        => clk,
            reclki     => reclki_s,
            regate     => regate_s,
            wrdonep    => wrdonep_s,
            gate       => gate_s,
            mode       => mode,
            modepulse  => modepulse,
            outi       => outo_s,
            resetn     => resetn,
            cnt_en     => cnt_en,
            gate_en    => gate_en,
            latch_stat => latch_stat,
            mux_wr     => mux_wr,
            mode_rw    => mode_rw,
            modeset    => modeset,
            status     => status,
            dbus_in    => dbus_out_s,
            dbus_out   => dbus_out,
            outo       => outo
        );

end struct;
