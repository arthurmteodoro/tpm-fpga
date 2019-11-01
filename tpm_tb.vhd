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
        N : natural := 20; -- quantidade de neuronios de entrada para cada neuronio da camada de entrada
        L : natural := 5; -- valor limite para os pesos dos neuronios (-L ate L)
        RULE : string := "hebbian"
    ); port (
        clk : in std_logic; -- clock do sistema
        reset : in std_logic; -- reset assincrono ativo em alto
        -- Interface de entrada do usuario
        avs_address : in std_logic_vector(7 downto 0); -- entrada da operacao desejada
        avs_writedata : in std_logic_vector(31 downto 0); -- entrada de dados do componente
        avs_write : in std_logic; -- quando avs_write = '1', a operacao ou o valor de dados e considerado valido e executado
        -- Interface de saida para o usuario
        avs_readdata : out std_logic_vector(31 downto 0); -- saida de dados do component
        avs_read : in std_logic -- quando data_valid_o = '1', o dado em data_o esta estavel
    );
    end component;

    signal clk, rst : std_logic;

    signal address : std_logic_vector(7 downto 0);
    signal write_req : std_logic;
    signal read_req : std_logic;

    signal data_in : std_logic_vector(31 downto 0);
    signal data_out : std_logic_vector(31 downto 0);

    constant clk_period : time := 20 ns;

    constant K : integer := 3;
    constant N : integer := 20;
    constant L : integer := 5;
    constant RULE : string := "hebbian";

begin
    
    uut : tpm generic map (
        K => K,
        N => N,
        L => L,
        RULE => RULE
    )
    port map (
        clk => clk,
        reset => rst,
        avs_address => address,
        avs_writedata => data_in,
        avs_write => write_req,
        avs_readdata => data_out,
        avs_read => read_req
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
        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';
        read_req <= '0';

        wait for clk_period*5;

        -- manda carregar a semente
        report "Carregando a semente para geração dos pesos";
        address <= "00000001";
        data_in <= x"0b71e8d7";
        write_req <= '1';

        wait for clk_period;

        write_req <= '0';

        wait for clk_period*10;

        -- manda gerar w
        report "Gerando os pesos";
        address <= "00000010";
        write_req <= '1';

        wait for clk_period;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*70;
        
        -- manda carregar a semente do primeiro LFSR
        report "Carregando a semente para o primeiro LFSR";
        address <= "10000000";
        data_in <= x"50eaaf61";
        write_req <= '1';

        wait for clk_period;

        write_req <= '0';

        wait for clk_period*3;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*10;

        -- manda carregar a semente do segundo LFSR
        report "Carregando a semente para o segundo LFSR";
        address <= "10000000";
        data_in <= x"1782b0b9";
        write_req <= '1';

        wait for clk_period;

        write_req <= '0';

        wait for clk_period*3;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*10;

        -- manda carregar a semente do terceiro LFSR
        report "Carregando a semente para o terceiro LFSR";
        address <= "10000000";
        data_in <= x"0242f806";
        write_req <= '1';

        wait for clk_period;

        write_req <= '0';

        wait for clk_period*3;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*10;

        -- manda gerar o valor de X
        report "Gerando o valor de X";
        address <= "00000011";
        write_req <= '1';

        wait for clk_period;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*30;

        -- manda gerar a saida
        report "Gerando a saída";
        address <= "00000100";
        write_req <= '1';
        wait for clk_period;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*30;

        report "lendo o valor de o";
        for i in 0 to K-1 loop
            address <= "00010100";
            read_req <= '1';

            wait for clk_period*2;

            address <= (others => '0');
            read_req <= '0';

            wait for clk_period*3;
        end loop;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*20;

        -- manda ler o valor de y
        report "Lendo valor de y"; 
        address <= "00010001";
        read_req <= '1';

        wait for clk_period*2;

        address <= (others => '0');
        read_req <= '0';

        wait for clk_period*30;

        report "lendo o valor de w";
        for i in 0 to (K*N)-1 loop
            address <= "00010010";
            read_req <= '1';

            wait for clk_period*2;

            address <= (others => '0');
            read_req <= '0';

            wait for clk_period*3;
        end loop;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*20;

        report "lendo o valor de x";
        for i in 0 to (K*N)-1 loop
            address <= "00010011";
            read_req <= '1';

            wait for clk_period*2;

            address <= (others => '0');
            read_req <= '0';

            wait for clk_period*3;
        end loop;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*20;

        report "Carregando o Y de Bob";
        address <= "00000101";
        write_req <= '1';
        data_in <= (31 downto 0 => '1');
        --data_in <= (31 downto 1 => '0')  & '1';

        wait for clk_period;

        write_req <= '0';

        wait for clk_period*2;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*20;

        report "Atualização dos pesos";
        address <= "00000110";
        write_req <= '1';

        wait for clk_period;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*30;

        report "lendo o valor de w";
        for i in 0 to (K*N)-1 loop
            address <= "00010010";
            read_req <= '1';

            wait for clk_period;

            address <= (others => '0');
            read_req <= '0';

            wait for clk_period*3;
        end loop;

        wait for clk_period*30;

        -- manda gerar o valor de X
        report "Gerando o valor de X";
        address <= "00000011";
        write_req <= '1';

        wait for clk_period;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*30;

        -- manda gerar a saida
        report "Gerando a saída";
        address <= "00000100";
        write_req <= '1';
        wait for clk_period;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*30;

        report "lendo o valor de o";
        for i in 0 to K-1 loop
            address <= "00010100";
            read_req <= '1';

            wait for clk_period*2;

            address <= (others => '0');
            read_req <= '0';

            wait for clk_period*3;
        end loop;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*20;

        -- manda ler o valor de y
        report "Lendo valor de y"; 
        address <= "00010001";
        read_req <= '1';

        wait for clk_period*2;

        address <= (others => '0');
        read_req <= '0';

        wait for clk_period*30;

        report "lendo o valor de w";
        for i in 0 to (K*N)-1 loop
            address <= "00010010";
            read_req <= '1';

            wait for clk_period*2;

            address <= (others => '0');
            read_req <= '0';

            wait for clk_period*3;
        end loop;

        address <= (others => '0');
        data_in <= (others => '0');
        write_req <= '0';

        wait for clk_period*20;

        wait;
    end process;
end tb;