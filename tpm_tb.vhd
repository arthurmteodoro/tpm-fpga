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

entity tpm_tb is
end tpm_tb;

architecture tb of tpm_tb is

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

        -- manda carregar a semente
        report "Carregando a semente para geração dos pesos";
        op <= "00000001";
        data_ok <= '1';
        wait for clk_period;

        -- espera o delay da comunicacao
        data_ok <= '0';
        wait for clk_period*4;

        -- carrega a semente
        --data_in <= "00110001"; -- resultado da 1
        data_in <= (31 downto 8 => '0') & "01001101"; -- resultado da -1
        data_ok <= '1';
        wait for clk_period;

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';
        wait for clk_period*10;

        -- manda gerar w
        report "Gerando os pesos";
        op <= "00000010";
        data_ok <= '1';

        wait for clk_period;

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait for clk_period*30;

        -- manda carregar a semente do primeiro LFSR
        report "Carregando a semente para o primeiro LFSR";
        op <= "10000000";
        data_in <= x"12345678";
        data_ok <= '1';

        wait for clk_period;

        data_ok <= '0';

        wait for clk_period*3;

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait for clk_period*10;

        -- manda carregar a semente do segundo LFSR
        report "Carregando a semente para o segundo LFSR";
        op <= "10000000";
        data_in <= x"2458AD16";
        data_ok <= '1';

        wait for clk_period;

        data_ok <= '0';

        wait for clk_period*3;

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait for clk_period*10;

        -- manda carregar a semente do terceiro LFSR
        report "Carregando a semente para o terceiro LFSR";
        op <= "10000000";
        data_in <= x"792ABF19";
        data_ok <= '1';

        wait for clk_period;

        data_ok <= '0';

        wait for clk_period*3;

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait for clk_period*10;

        -- manda gerar o valor de X
        report "Gerando o valor de X";
        op <= "00000011";
        data_ok <= '1';

        wait for clk_period;

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait for clk_period*30;

        -- manda gerar a saida
        report "Gerando a saída";
        op <= "00000100";
        data_ok <= '1';
        wait for clk_period;

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait for clk_period*30;

        -- manda retornar os pesos
        report "Retornando os pesos";
        op <= "00010000";
        data_ok <= '1';
        wait for clk_period;        

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait for clk_period*4;

        for i in 0 to 11 loop
            data_ok <= '1';
            wait for clk_period;
            data_ok <= '0';
            wait for clk_period*4;
        end loop;

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait for clk_period*30;

        -- manda carregar o y de bob
        report "Carregando o Y de Bob";
        op <= "00000101";
        data_ok <= '1';
        data_in <= (31 downto 8 => '0') & "00000001"; -- resultado da 1
        --data_in <= (31 downto 8 => '0') & "11111111"; -- resultado da -1

        wait for clk_period;

        data_ok <= '0';

        wait for clk_period*2;

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait for clk_period*10;

        -- manda atualizar os pesos
        report "Atualização dos pesos";
        op <= "00000110";
        data_ok <= '1';

        wait for clk_period;

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait for clk_period*30;

         -- manda retornar os pesos
         report "Retornando os pesos";
        op <= "00010000";
        data_ok <= '1';
        wait for clk_period;        

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait for clk_period*4;

        for i in 0 to 11 loop
            data_ok <= '1';
            wait for clk_period;
            data_ok <= '0';
            wait for clk_period*4;
        end loop;

        op <= (others => '0');
        data_in <= (others => '0');
        data_ok <= '0';

        wait;
    end process;
end tb;