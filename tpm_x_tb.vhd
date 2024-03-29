----------------------------------------------------------------------------------------
--    Trabalho de Conclusao de Curso - Ciencia da Computacao - IFMG Campus Formiga    --
--   Desenvolvimento de Rede Neural Artificial (RNA) para Distribuiçao de Chaves em   --
--        algoritmos de Criptografia Simetrica utilizando hardware reconfiguravel     --
--                                                                                    --
-- Autor: Arthur Alexsander Martins Teodoro                                           --
-- Orientador: Otavio de Souza Martins Gomes                                          --
-- Data: Julho de 2018                                                                --
----------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;    

entity tpm_x_tb is
end tpm_x_tb;

architecture tb of tpm_x_tb is

    component tpm is generic(
        K : natural := 3; -- quantidade de neuronios da camada escondida
        N : natural := 4; -- quantidade de neuronios de entrada para cada neuronio da camada de entrada
        L : natural := 5; -- valor limite para os pesos dos neuronios (-L ate L)
        RULE : string := "hebbian"
    ); port (
        clk_i : in std_logic; -- clock do sistema
        rst_i : in std_logic; -- reset sincrono ativo em alto
        -- Interface de entrada do usuario
        op_i : in std_logic_vector(7 downto 0); -- entrada da operacao desejada
        data_i : in std_logic_vector(31 downto 0); -- entrada de dados do componente
        data_ok_i : in std_logic; -- quando data_ok_i = '1', a operacao ou o valor de dados e considerado valido e executado
        -- Interface de saida para o usuario
        data_o : out std_logic_vector(31 downto 0); -- saida de dados do component
        data_valid_o : out std_logic; -- quando data_valid_o = '1', o dado em data_o esta estavel
        busy_o : out std_logic -- quando busy_o = '1',  componente esta realizando uma tarefa
    );
    end component;

    signal clk, rst : std_logic;

    signal op : std_logic_vector(7 downto 0);
    signal data_in : std_logic_vector(31 downto 0);
    signal data_ok : std_logic;

    signal data_out : std_logic_vector(31 downto 0);
    signal data_valid : std_logic;
    signal busy : std_logic;

    constant clk_period : time := 20 ns; 

begin
    
    uut : tpm port map (
        clk_i => clk,
        rst_i => rst,
        op_i => op,
        data_i => data_in,
        data_ok_i => data_ok,
        data_o => data_out,
        data_valid_o => data_valid,
        busy_o => busy
    );

    process
    begin
        clk <= '1';
        wait for clk_period/2;
        clk <= '0';
        wait for clk_period/2;
    end process;

    process
    begin
        rst <= '1';
        wait for clk_period*2;
        rst <= '0';
        wait;
    end process;

    process
    begin
        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait for clk_period*5;

        for i in 0 to 2 loop
            op <= "10000000";
            data_ok <= '1';
            data_in <= x"3584123A";

            wait for clk_period*1;

            data_ok <= '0';

            wait for clk_period*10;
        end loop;

        wait for clk_period*5;

        op <= "11000000";
        data_ok <= '1';

        wait for clk_period; 
        
        op <= (others => '0');
        data_ok <= '0';

        wait for clk_period*5;

        op <= "11000000";
        data_ok <= '1';

        wait for clk_period;        

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait;
    end process;
end tb;