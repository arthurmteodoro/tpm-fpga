library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lfsr32 is port(
    clk: in std_logic;
    rst: in std_logic;
    enable: in std_logic;
    load_seed: in std_logic;
    seed: in std_logic_vector(31 downto 0);
    lfsr_o: out std_logic_vector(31 downto 0)
);
end lfsr32;

architecture behavior of lfsr32 is
    signal r_lfsr : std_logic_vector (31 downto 0);
    signal linear_feedback : std_logic;
begin
    lfsr_o  <= r_lfsr;
    linear_feedback <= r_lfsr(0) xor r_lfsr(10) xor r_lfsr(30) xor r_lfsr(31);

    process(clk, rst)
    begin
        if (rst = '1') then
            r_lfsr <= (others => '1');
        elsif(rising_edge(clk)) then
            if (load_seed = '1') then
                r_lfsr <= seed;
            elsif(enable = '1') then
                r_lfsr <= linear_feedback & r_lfsr(31 downto 1);
            end if;
        end if;
    end process;
    
end behavior;