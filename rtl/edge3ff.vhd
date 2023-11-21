-------------------------------------------------------------------------------
--  HTL8254 - PIT core                                                       --
--                                                                           --
--  https://github.com/htminuslab                                            --
--                                                                           --
-------------------------------------------------------------------------------
-- Project       : edge3ff                                                   --
-- Unit          : Dual FF metastability chain followed by rising/falling    -- 
--               : edge detector. Note the redge/fedge output are comb.      --
--               : no async reset!                                           --
--                                                                           --
-- Library       : utils                                                     --
--                                                                           --
-- Version       : 0.1  05/21/2002  Created HT-LAB                           --
--               : 1.0  21/11/2023  cleaned and uploaded to github           --
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.all;

entity edge3ff is
    port( 
        clk   : in  std_logic;
        din   : in  std_logic;
        dout  : out std_logic;                          -- Output of dual input FF
        fedge : out std_logic;
        redge : out std_logic);
end edge3ff;

architecture rtl of edge3ff is

    signal q0_s : std_logic;
    signal q1_s : std_logic;
    signal q2_s : std_logic;

begin
   
    process (clk)                                       -- No reset!!
        begin
            if rising_edge(clk) then
                q0_s <= din;
                q1_s <= q0_s;
                q2_s <= q1_s;
            end if;
    end process;
    dout  <= q1_s;                                      -- CLK synchronous output
    redge <= not(q2_s) and q1_s;                        -- Rising Edge
    fedge <= not(q1_s) and q2_s;                        -- Falling Edge

end rtl;
