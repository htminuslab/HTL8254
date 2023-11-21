-------------------------------------------------------------------------------
--   HTL8254 - PIT core                                                      --
--                                                                           --
--  https://github.com/htminuslab                                            --
--                                                                           --
-------------------------------------------------------------------------------
-- Project       : HTL8254                                                   --
-- Purpose       : Control Module                                            --
-- Library       : I8254                                                     --
--                                                                           --
-- Version       : 1.0  20/01/2002   Created HT-LAB                          --
--               : 1.2  30/11/2023   cleaned and uploaded to github          --
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;

entity ctrlout is
    port( 
        clk        : in     std_logic;
        clken      : in     std_logic;
        cnt0       : in     std_logic;
        cnt1       : in     std_logic;
        cnt2       : in     std_logic;
        cnt_en     : in     std_logic;
        gate_en    : in     std_logic;
        mode       : in     std_logic_vector (2 downto 0);
        modepulse  : in     std_logic;
        odd        : in     std_logic;                      -- asserted if CR is off value
        reclki     : in     std_logic;
        resetn     : in     std_logic;
        wrdonep    : in     std_logic;
        dec        : out    std_logic_vector (1 downto 0);  -- Decrement value, used in mode2, otherwise 1
        modeset    : out    std_logic;
        outo       : out    std_logic;
        reload_cnt : out    std_logic                       -- reload counter with CR value(s)
    );
end ctrlout ;
 
architecture fsm of ctrlout is

    type state_type is (
        sinit,
        smode0,
        sm11,
        sm01,
        sm1r,
        sm03,
        sm12,
        smode2,
        sm20,
        sm3r2,
        sdec31,
        sm3r,
        sdec3,
        sdec32,
        smode3,
        sm31,
        sm43,
        smode4,
        sm41,
        sm42,
        sm51,
        sm53,
        sm54,
        sm40,
        sm5r,
        smode5,
        smode1,
        sm10,
        sm52,
        sm3g0,
        sm02,
        sm21
    );
 
    signal current_state : state_type;
    signal next_state : state_type;

    signal outo_cld : std_logic ;

begin

    -----------------------------------------------------------------
    clocked_proc : process ( 
        clk,
        resetn
    )
    -----------------------------------------------------------------
    begin
        if (resetn = '0') then
            current_state <= sinit;
            -- Default Reset Values
            outo_cld <= '1';
        elsif (clk'event and clk = '1') then
            if (modepulse = '1') then
                current_state <= sinit;
                if mode="000" then outo_cld<='0';
                               else outo_cld<='1';
                end if;
            else
                current_state <= next_state;

                -- Combined Actions
                case current_state is
                    when sinit => 
                        if mode="000" then outo_cld<='0';
                                      else outo_cld<='1';
                        end if;
                    when sm11 => 
                        if (reclki='1' AND
                            gate_en='1') then 
                        elsif (cnt0='1') then 
                            outo_cld <= '1';
                        end if;
                    when sm1r => 
                        if (clken='1' ) then 
                            outo_cld <= '0';
                        end if;
                    when sm03 => 
                        if (wrdonep='1') then 
                            outo_cld <= '0';
                        end if;
                    when smode2 => 
                        if (clken='1' ) then 
                            outo_cld<='1';
                        end if;
                    when sm20 => 
                        if (cnt1='1') then 
                            outo_cld<='0';
                        end if;
                    when sm3r2 => 
                        if (gate_en='0') then 
                            outo_cld <='1';
                        elsif (clken='1' ) then 
                            outo_cld <= NOT outo_cld;
                        end if;
                    when sdec31 => 
                        if (cnt2='1') then 
                        elsif (gate_en='0') then 
                            outo_cld <='1';
                        end if;
                    when sm3r => 
                        if (gate_en='0') then 
                            outo_cld <='1';
                        elsif (clken='1' 
                               AND odd='0') then 
                            outo_cld <= NOT outo_cld;
                        elsif (clken='1' ) then 
                            outo_cld <= NOT outo_cld;
                        end if;
                    when sdec32 => 
                        if (cnt2='1') then 
                        elsif (gate_en='0') then 
                            outo_cld <='1';
                        end if;
                    when sm41 => 
                        if (wrdonep='1') then 
                        elsif (cnt0='1') then 
                            outo_cld <= '0';
                        end if;
                    when sm42 => 
                        if (clken='1' ) then 
                            outo_cld <='1';
                        end if;
                    when sm53 => 
                        if (reclki='1' AND
                            gate_en='1') then 
                        elsif (cnt0='1') then 
                            outo_cld <= '0';
                        end if;
                    when sm54 => 
                        if (clken='1' ) then 
                            outo_cld <='1';
                        end if;
                    when sm02 => 
                        if (wrdonep='1') then 
                            outo_cld <= '0';
                        elsif (cnt0='1' ) then 
                            outo_cld <= '1';
                        end if;
                    when others =>
                        null;
                end case;
            end if;
        end if;
    end process clocked_proc;
 
    -----------------------------------------------------------------
    nextstate_proc : process ( 
        clken,
        cnt0,
        cnt1,
        cnt2,
        cnt_en,
        current_state,
        gate_en,
        mode,
        odd,
        reclki,
        wrdonep
    )
    -----------------------------------------------------------------
    begin
        -- Default Assignment
        dec <= "01";
        modeset <= '0';
        reload_cnt <= '0';

        -- Combined Actions
        case current_state is
            when sinit => 
                modeset<='1';
                if (wrdonep='1'  AND
                    mode="000") then 
                    next_state <= smode0;
                elsif (wrdonep='1'  AND
                       mode="001") then 
                    next_state <= smode1;
                elsif (wrdonep='1'  AND
                       mode="010") then 
                    next_state <= smode2;
                elsif (wrdonep='1' AND 
                       mode="011") then 
                    next_state <= smode3;
                elsif (wrdonep='1'  AND
                       mode="100") then 
                    next_state <= smode4;
                elsif (wrdonep='1'  AND
                       mode="101") then 
                    next_state <= smode5;
                else
                    next_state <= sinit;
                end if;
            when smode0 => 
                reload_cnt<='1';
                if (clken='1') then 
                    next_state <= sm01;
                else
                    next_state <= smode0;
                end if;
            when sm11 => 
                if (reclki='1' AND
                    gate_en='1') then 
                    next_state <= sm1r;
                elsif (cnt0='1') then 
                    next_state <= sm12;
                else
                    next_state <= sm11;
                end if;
            when sm01 => 
                if (wrdonep='1') then 
                    next_state <= smode0;
                elsif (cnt_en='1' AND
                       clken='1') then 
                    next_state <= sm02;
                else
                    next_state <= sm01;
                end if;
            when sm1r => 
                reload_cnt<='1';
                if (clken='1' ) then 
                    next_state <= sm10;
                else
                    next_state <= sm1r;
                end if;
            when sm03 => 
                if (wrdonep='1') then 
                    next_state <= smode0;
                else
                    next_state <= sm03;
                end if;
            when sm12 => 
                if (reclki='1' AND
                    gate_en='1') then 
                    next_state <= sm1r;
                elsif (clken='1' ) then 
                    next_state <= smode1;
                else
                    next_state <= sm12;
                end if;
            when smode2 => 
                reload_cnt<='1';
                if (clken='1' ) then 
                    next_state <= sm20;
                else
                    next_state <= smode2;
                end if;
            when sm20 => 
                if (cnt1='1') then 
                    next_state <= smode2;
                elsif (gate_en='0') then 
                    next_state <= sm21;
                else
                    next_state <= sm20;
                end if;
            when sm3r2 => 
                reload_cnt<='1';
                if (gate_en='0') then 
                    next_state <= sm3g0;
                elsif (clken='1' ) then 
                    next_state <= sm31;
                else
                    next_state <= sm3r2;
                end if;
            when sdec31 => 
                dec<="10";
                if (cnt2='1') then 
                    next_state <= sm3r;
                elsif (gate_en='0') then 
                    next_state <= sm3g0;
                else
                    next_state <= sdec31;
                end if;
            when sm3r => 
                reload_cnt<='1';
                if (gate_en='0') then 
                    next_state <= sm3g0;
                elsif (clken='1' 
                       AND odd='0') then 
                    next_state <= sdec31;
                elsif (clken='1' ) then 
                    next_state <= sdec3;
                else
                    next_state <= sm3r;
                end if;
            when sdec3 => 
                dec<="11";
                if (cnt2='1') then 
                    next_state <= sm3r2;
                elsif (clken='1' ) then 
                    next_state <= sdec32;
                else
                    next_state <= sdec3;
                end if;
            when sdec32 => 
                dec<="10";
                if (cnt2='1') then 
                    next_state <= sm3r2;
                elsif (gate_en='0') then 
                    next_state <= sm3g0;
                else
                    next_state <= sdec32;
                end if;
            when smode3 => 
                reload_cnt<='1';
                if (clken='1' 
                    AND odd='1') then 
                    next_state <= sm31;
                elsif (clken='1' ) then 
                    next_state <= sdec31;
                else
                    next_state <= smode3;
                end if;
            when sm31 => 
                if (clken='1' ) then 
                    next_state <= sdec31;
                else
                    next_state <= sm31;
                end if;
            when sm43 => 
                if (wrdonep='1') then 
                    next_state <= smode4;
                else
                    next_state <= sm43;
                end if;
            when smode4 => 
                reload_cnt<='1';
                if (clken='1' ) then 
                    next_state <= sm40;
                else
                    next_state <= smode4;
                end if;
            when sm41 => 
                if (wrdonep='1') then 
                    next_state <= smode4;
                elsif (cnt0='1') then 
                    next_state <= sm42;
                else
                    next_state <= sm41;
                end if;
            when sm42 => 
                if (clken='1' ) then 
                    next_state <= sm43;
                else
                    next_state <= sm42;
                end if;
            when sm51 => 
                reload_cnt<='1';
                if (clken='1' ) then 
                    next_state <= sm52;
                else
                    next_state <= sm51;
                end if;
            when sm53 => 
                if (reclki='1' AND
                    gate_en='1') then 
                    next_state <= sm5r;
                elsif (cnt0='1') then 
                    next_state <= sm54;
                else
                    next_state <= sm53;
                end if;
            when sm54 => 
                if (clken='1' ) then 
                    next_state <= smode5;
                else
                    next_state <= sm54;
                end if;
            when sm40 => 
                if (clken='1' AND
                    gate_en='1') then 
                    next_state <= sm41;
                else
                    next_state <= sm40;
                end if;
            when sm5r => 
                reload_cnt<='1';
                if (clken='1' ) then 
                    next_state <= sm52;
                else
                    next_state <= sm5r;
                end if;
            when smode5 => 
                if (reclki='1' AND
                    gate_en='1') then 
                    next_state <= sm51;
                else
                    next_state <= smode5;
                end if;
            when smode1 => 
                if (reclki='1' AND
                    gate_en='1') then 
                    next_state <= sm1r;
                else
                    next_state <= smode1;
                end if;
            when sm10 => 
                if (-- gate_en='0' 
                    clken='1') then --ver 1.0e
                    next_state <= sm11;
                else
                    next_state <= sm10;
                end if;
            when sm52 => 
                if (--gate_en='0'
                    clken='1') then -- ver 1.0e
                    next_state <= sm53;
                else
                    next_state <= sm52;
                end if;
            when sm3g0 => 
                if (--gate_en='1'
                    reclki='1' AND
                    gate_en='1') then 
                    next_state <= smode3;
                else
                    next_state <= sm3g0;
                end if;
            when sm02 => 
                if (wrdonep='1') then 
                    next_state <= smode0;
                elsif (cnt0='1' ) then 
                    next_state <= sm03;
                else
                    next_state <= sm02;
                end if;
            when sm21 => 
                if (reclki='1' AND
                    gate_en='1') then 
                    next_state <= smode2;
                else
                    next_state <= sm21;
                end if;
            when others =>
                next_state <= sinit;
        end case;
    end process nextstate_proc;
 
    -- Concurrent Statements
    -- Clocked output assignments
    outo <= outo_cld;
end fsm;
