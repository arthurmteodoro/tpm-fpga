----------------------------------------------------------------------------------------
--    Trabalho de Conclusao de Curso - Ciencia da Computacao - IFMG Campus Formiga    --
--   Desenvolvimento de Rede Neural Artificial (RNA) para Distribuiao de Chaves em   --
--        algoritmos de Criptografia Simetrica utilizando hardware reconfiguravel     --
--                                                                                    --
-- Autor: Arthur Alexsander Martins Teodoro                                           --
-- Orientador: Otavio de Souza Martins Gomes                                          --
-- Data: Julho de 2018                                                                --
----------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity tpm is generic(
    K : natural := 3; -- quantidade de neuronios da camada escondida
    N : natural := 4; -- quantidade de neuronios de entrada para cada neuronio da camada de entrada
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
end tpm;

architecture behavior of tpm is

    ---------------------------------------------------------------------------------------------
    -- FUNCOES                                                                                 --
    ---------------------------------------------------------------------------------------------
    
    -- Funcao para limitar o valor de w para -L ate L
    function clip(a : signed) return signed is
    begin
        if(a > L) then
            return to_signed(L, 8);
        elsif(a < -L) then
            return to_signed(-L, 8);
        else
            return a;
        end if;
    end clip;

    -- funcao para limitar o valor do gerador de numero aleatorios para L
    -- tal funcao pega a quantidade de bits necessaria para representar L e define essa como a quantidade
    -- de bits que sera lida o salvo - isso porque se so utilizasse clip os valores normalmente seriam
    -- -L ou L por causa do tamanho da saida do gerador
    function limit_generate_w(a : std_logic_vector) return signed is
        constant min_bit : integer := integer(ceil(log2(real(L))));
    begin
        return clip(resize(signed(a(min_bit downto 0)), 8));
    end limit_generate_w;

    -- funcao sinal do valor do peso
    -- -1 para valores menores que 0, 1 para maior ou igual a 0
    function sign(a : signed) return signed is
    begin
        if(a >= 0) then
            return to_signed(1, 8);
        else
            return to_signed((-1), 8);
        end if;
    end sign;

    ---------------------------------------------------------------------------------------------
    -- COMPONENTES                                                                             --
    ---------------------------------------------------------------------------------------------
    component lfsr is generic(
        G_M : integer := 7;
        G_POLY : std_logic_vector := "1100000"); -- x^7+x^6+1 
    port(
        i_clk : in std_logic;
        i_rstb : in std_logic;
        i_sync_reset : in std_logic;
        i_seed : in std_logic_vector(G_M-1 downto 0);
        i_en : in std_logic;
        o_lsfr : out std_logic_vector(G_M-1 downto 0)
    );
    end component;
    
    component lfsr32 is port(
        clk: in std_logic;
        rst: in std_logic;
        enable: in std_logic;
        load_seed: in std_logic;
        seed: in std_logic_vector(31 downto 0);
        lfsr_o: out std_logic_vector(31 downto 0)
    );
    end component;

    ---------------------------------------------------------------------------------------------
    -- DEFINICAO DOS TIPOS                                                                     --
    ---------------------------------------------------------------------------------------------
    type vector_of_byte is array(integer range <>) of signed(7 downto 0); -- vetor de bytes para o valor de sigma
    type matrix_of_byte is array(integer range <>, integer range <>) of signed(7 downto 0); -- matriz de bytes para os pesos e entrada
    type vector_of_word is array(integer range <>) of std_logic_vector(31 downto 0); -- vetor de 32 bits para o valor do gerador de x
    type vector_of_std_logic is array(integer range <>) of std_logic; -- vetor de std_logic para controle dos lfsrs de 32 bits
    
    ---------------------------------------------------------------------------------------------
    -- DEFINICAO DOS SINAIS                                                                    --
    ---------------------------------------------------------------------------------------------
    
    -- sinais de registradores
    signal tpm_w : matrix_of_byte(K-1 downto 0, N-1 downto 0);
    signal tpm_x : matrix_of_byte(K-1 downto 0, N-1 downto 0);
    signal tpm_o : vector_of_byte(K-1 downto 0);
    signal tpm_y : signed(7 downto 0);
    signal tpm_y_bob : signed(7 downto 0);
    
    -- sinais para serem utilizados no gerador de numeros aleatorios
    signal load_seed_for_lfsr : std_logic;
    signal seed_for_lfsr : std_logic_vector(31 downto 0);
    signal enable_for_lfsr : std_logic;
    signal lfsr_random_number : std_logic_vector(7 downto 0);
    
    -- sinais para serem utilizados nos lfsrs de 32 bits
    signal load_seed_for_lfsr32 : vector_of_std_logic(K-1 downto 0);
    signal seed_for_lfsr32 : vector_of_word(K-1 downto 0);
    signal enable_for_lfsr32 : vector_of_std_logic(K-1 downto 0);
    signal lfsr32_random_number : vector_of_word(K-1 downto 0);
    
    -- sinais intermediarios para saida
    signal busy : std_logic;
    signal tpm_output_valid : std_logic;
    
    -- sinais de enable para serem utilizados os processos para realizar as terefas
    signal enable_load_seed_lfsr32 : std_logic;
    signal enable_load_seed_lfsr : std_logic;
    signal enable_generate_w : std_logic;
    signal enable_counter, enable_counter_process, enable_counter_col : std_logic;
    signal enable_load_x : std_logic;
    signal enable_calc_o : std_logic;
    signal clear_h : std_logic;
    signal clear_y : std_logic;
    signal enable_calc_y : std_logic;
    signal enable_counter_simple : std_logic;
    signal enable_exit_w : std_logic;
    signal enable_exit_y : std_logic;
    signal enable_load_y_bob : std_logic;
    signal enable_update_w : std_logic;
    signal enable_clip_w : std_logic;
    
    -- sinais para contadores
    signal counter_i : integer range 0 to K-1;
    signal counter_j : integer range 0 to N-1;
    signal counter : integer range 0 to K-1;
    signal counter_col : integer range 0 to N-1;
    
    ---------------------------------------------------------------------------------------------
    -- DEFINICAO DOS TIPOS E SINAIS PARA A MAQUINA DE ESTADOS                                  --
    ---------------------------------------------------------------------------------------------
    type state is (idle, load_seed, load_seed_comp, generate_w, generate_new_input_x, load_x, calc_o, calc_y, exit_w, 
                   load_bob_y, update_w, update_clip_w, exit_y, load_seed_x, load_seed_comp_x);
    
    signal this_state : state;
    signal next_state : state;
    
    constant max_value : signed(7 downto 0) := to_signed(L, 8);
    constant min_value : signed(7 downto 0) := to_signed(-L, 8);
    
begin

    ---------------------------------------------------------------------------------------------
    -- PROCESSOS PARA REALIZAR TAREFAS DO COMPONENTE                                           --
    ---------------------------------------------------------------------------------------------
    
    -- processo para carregar valores da semente para o gerador de numeros
    tpm_load_seed : process(clk, reset)
    begin
        if(reset = '1') then
            seed_for_lfsr <= (others => '0');
        elsif(rising_edge(clk)) then
            if(enable_load_seed_lfsr = '1') then
                seed_for_lfsr <= avs_writedata;
            end if;
        end if;
    end process;
    
    -- processo para carregar valores da semente para o gerador de numeros de 32 bits
    tpm_load_seed32 : process(clk, reset)
    begin
        if(reset = '1') then
            for i in 0 to K-1 loop
                seed_for_lfsr32(i) <= (others => '0');
            end loop;
        elsif(rising_edge(clk)) then
            if(enable_load_seed_lfsr32 = '1') then
                seed_for_lfsr32(counter) <= avs_writedata;
            end if;
        end if;
    end process;
    
    -- processo para os contadores da matriz (i e j)
    tpm_counter : process(clk, reset)
    begin
        if(reset = '1') then
                counter_i <= 0;
                counter_j <= 0;
        elsif(rising_edge(clk)) then
            if(enable_counter_process = '1') then
                if((counter_i = K-1) and (counter_j = N-1)) then
                    counter_i <= 0;
                    counter_j <= 0;
                else
                    if(counter_j = N-1) then
                        counter_i <= counter_i + 1;
                        counter_j <= 0;
                    else
                        counter_j <= counter_j + 1;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- processo para o contador das linhas da matriz, somente de 0 a K-1
    tpm_simple_counter : process(clk, reset)
    begin
        if(reset = '1') then
                counter <= 0;
        elsif(rising_edge(clk)) then
            if(enable_counter_simple = '1') then
                if(counter = K-1) then
                    counter <= 0;
                else
                    counter <= counter + 1;
                end if;
            end if;
        end if;
    end process;
    
    -- processo para o contador de colunas da matriz, somente de 0 a N-1
    tpm_col_counter: process(clk, reset)
    begin
    	if (reset = '1') then
    		counter_col <= 0;
    	elsif (rising_edge(clk)) then
    		if (enable_counter_col = '1') then
    			if (counter_col = N-1) then
    				counter_col <= 0;
    			else
    				counter_col <= counter_col + 1;
    			end if;
    		end if;
    	end if;
    end process;
    
    -- processo para gerar os numeros para w e para aprendizado
    tpm_load_w : process(clk, reset)
        variable i, j : integer := 0;
        variable w : matrix_of_byte(K-1 downto 0, N-1 downto 0);
    begin
        if(reset = '1') then
            for i in 0 to K-1 loop
                for j in 0 to N-1 loop
                    tpm_w(i, j) <= (others => '0');
                end loop;
            end loop;
        elsif(rising_edge(clk)) then
            -- para carregar os pesos a partir do gerador de numeros psudo-aleatorios
            if(enable_generate_w = '1') then
                tpm_w(counter_i, counter_j) <= limit_generate_w(lfsr_random_number);
            elsif(enable_update_w = '1') then -- para atualizar os pesos de forma paralela - usando o for
                if(tpm_y = tpm_y_bob) then -- caso os valores de saida sejam iguais
                    for i in 0 to K-1 loop
                        for j in 0 to N-1 loop
                            if(tpm_y * tpm_o(i) <= 0) then -- caso a multiplicacao de menor ou igual a zero, o peso se mantem
                                w(i, j) := tpm_w(i, j);
                            else
                                if(RULE = "hebbian") then -- acplica a regra determinada
                                    w(i, j) := resize((tpm_w(i, j) + (tpm_x(i, j) * tpm_y)), 8);
                                elsif(RULE = "anti_hebbian") then
                                    w(i, j) := resize((tpm_w(i, j) - (tpm_x(i, j) * tpm_o(i))), 8);
                                elsif(RULE = "random_walk") then
                                    w(i, j) := resize((tpm_w(i, j) + tpm_x(i, j)), 8);
                                end if;
                            end if;
                        end loop;
                    end loop;
                    tpm_w <= w;
                end if;
            elsif(enable_clip_w = '1') then -- para fazer a limitacao dos pesos tambem de forma paralela
                if(tpm_y = tpm_y_bob) then -- caso os valores de saida sejam iguais
                    for i in 0 to K-1 loop
                        for j in 0 to N-1 loop
                            w(i, j) := clip(tpm_w(i, j));
                        end loop;
                    end loop;
                    tpm_w <= w;
                end if;
            end if;
        end if;
    end process;
    
    -- processo para carregar os valores de x para a tpm
    tpm_load_x : process(clk, reset)
    begin
        if(reset = '1') then
                for i in 0 to K-1 loop
                    for j in 0 to N-1 loop
                        tpm_x(i, j) <= (others => '0');
                    end loop;
                end loop;
        elsif(rising_edge(clk)) then
            if(enable_load_x = '1') then
            	for i in 0 to K-1 loop
            		tpm_x(i, counter_col) <= limit_generate_w(lfsr32_random_number(i));
            	end loop;
            end if;
        end if;
    end process;
    
    -- processo para calcular os valores de sigma
    tpm_output_calc_o : process(clk, reset, clear_h)
        variable h : signed(7 downto 0);
    begin
        if((reset = '1') or (clear_h = '1')) then
            for i in 0 to K-1 loop
                tpm_o(i) <= (others => '0');
            end loop;
            h := (others => '0');
        elsif(rising_edge(clk)) then
            if(enable_calc_o = '1') then
                h := (others => '0');
                for j in 0 to N-1 loop
                    h := resize((h + tpm_w(counter, j) * tpm_x(counter, j)), 8);
                end loop;
                tpm_o(counter) <= sign(h);
            end if;
        end if;
    end process;
    
    -- processo para calcular o valor de y da tpm
    tpm_calc_y : process(clk, reset, clear_y)
        variable y : signed(7 downto 0) := "00000001";
        variable i : integer;
    begin
        if((reset = '1') or (clear_y = '1')) then
                tpm_y <= "00000001";
                y := "00000001";
        elsif(rising_edge(clk)) then
            if(enable_calc_y = '1') then
                y := "00000001";
                for i in 0 to K-1 loop
                    y := resize((y * tpm_o(i)), 8);
                end loop;
                tpm_y <= y;
            end if;
        end if;
    end process;
    
    -- processo para armazenar o valor de y de bob
    tpm_load_bob_y : process(clk, reset)
    begin
        if(reset = '1') then
            tpm_y_bob <= (others => '0');
        elsif(rising_edge(clk)) then
            if(enable_load_y_bob = '1') then
                tpm_y_bob <= signed(avs_writedata(7 downto 0));
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------------------------
    -- PROCESSOS DO BARRAMENTO                                                          --
    ---------------------------------------------------------------------------------------------
    
    -- processo para controlar a saida do componente
    tpm_output : process(clk, reset)
    begin
        if(reset = '1') then
                avs_readdata <= (others => '0');
        elsif(rising_edge(clk)) then
            if (avs_read = '1' and avs_address = "00000000") then
                avs_readdata <= (31 downto 1 => '0') & busy;
            end if;
            if(enable_exit_w = '1') then
                avs_readdata <= std_logic_vector(resize(tpm_w(counter_i, counter_j), 32));
            elsif(enable_exit_y = '1') then
                avs_readdata <= std_logic_vector(resize(tpm_y, 32));
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------------------------
    -- PROCESSOS DA MAQUINA DE ESTADOS                                                          --
    ---------------------------------------------------------------------------------------------
    
    comb_fsm : process(this_state, avs_write, avs_address, counter_i, counter_j, counter, avs_read, counter_col)
    begin
        case this_state is
            when idle =>
                busy <= '0';
                load_seed_for_lfsr <= '0';
                enable_for_lfsr <= '0';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                
                if(avs_write = '1') then
                    case avs_address is
                        when "00000001" =>
                            next_state <= load_seed;
                        when "00000010" =>
                            next_state <= generate_w;
                        when "00000011" =>
                            next_state <= generate_new_input_x;
                        when "00000100" =>
                            clear_h <= '1';
                            next_state <= calc_o;
                        when "00000101" =>
                            next_state <= load_bob_y;
                        when "00000110" =>
                            next_state <= update_w;
                        when "10000000" =>
                            next_state <= load_seed_x;
                        when others =>
                            next_state <= idle;
                    end case;
                elsif (avs_read = '1') then
                    case avs_address is
                        when "00010001" =>
                            enable_exit_y <= '1';
                            next_state <= exit_y;
                        when "00010010" =>
                            enable_exit_w <= '1';
                            enable_counter <= '1';
                            next_state <= exit_w;
                        when others =>
                            next_state <= idle;
                    end case;
                else
                    next_state <= idle;
                end if;
                
            when load_seed =>
                busy <= '1';
                enable_for_lfsr <= '0';
                load_seed_for_lfsr <= '0';
                enable_load_seed_lfsr <= '1';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                next_state <= load_seed_comp;
                
            when load_seed_comp =>
                busy <= '1';
                enable_for_lfsr <= '0';
                load_seed_for_lfsr <= '1';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                next_state <= idle;
                
            when load_seed_x =>
                busy <= '1';
                enable_for_lfsr <= '0';
                load_seed_for_lfsr <= '0';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '1';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                next_state <= load_seed_comp_x;
                
            when load_seed_comp_x =>
                busy <= '1';
                enable_for_lfsr <= '0';
                load_seed_for_lfsr <= '0';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '1';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                load_seed_for_lfsr32(counter) <= '1';
                
                next_state <= idle;    
                
            when generate_w =>
                busy <= '1';
                load_seed_for_lfsr <= '0';
                enable_for_lfsr <= '1';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '1';
                enable_counter <= '1';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                if((counter_i = K-1) and (counter_j = N-1)) then
                    next_state <= idle;
                else
                    next_state <= generate_w;
                end if;
                
            when generate_new_input_x =>
                busy <= '1';
                load_seed_for_lfsr <= '0';
                enable_for_lfsr <= '0';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '1';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                next_state <= load_x;
        
            when load_x =>
                busy <= '1';
                load_seed_for_lfsr <= '0';
                enable_for_lfsr <= '0';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '1';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '1';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                if (counter_col = N-1) then
                	next_state <= idle;
                else
                	next_state <= generate_new_input_x;
                end if;
                
            when calc_o =>
                busy <= '1';
                load_seed_for_lfsr <= '0';
                enable_for_lfsr <= '0';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '1';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '1';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                if(counter = K-1) then
                    next_state <= calc_y;
                else
                    next_state <= calc_o;
                end if;
                
            when calc_y =>
                busy <= '1';
                load_seed_for_lfsr <= '0';
                enable_for_lfsr <= '0';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '1';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                next_state <= idle;
                
            when exit_y =>
                busy <= '1';
                load_seed_for_lfsr <= '0';
                enable_for_lfsr <= '0';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '1';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '1';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                next_state <= idle;
                
            when load_bob_y =>
                busy <= '1';
                enable_for_lfsr <= '0';
                load_seed_for_lfsr <= '0';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '1';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                next_state <= idle;
                
            when update_w =>
                busy <= '1';
                load_seed_for_lfsr <= '0';
                enable_for_lfsr <= '0';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '0';
                enable_update_w <= '1';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                next_state <= update_clip_w;
                
            when update_clip_w =>
                busy <= '1';
                load_seed_for_lfsr <= '0';
                enable_for_lfsr <= '0';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '1';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                next_state <= idle;
                
            when exit_w =>
                busy <= '1';
                load_seed_for_lfsr <= '0';
                enable_for_lfsr <= '0';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                next_state <= idle;
                
            when others =>
                busy <= '0';
                load_seed_for_lfsr <= '0';
                enable_for_lfsr <= '0';
                enable_load_seed_lfsr <= '0';
                enable_generate_w <= '0';
                enable_counter <= '0';
                enable_load_x <= '0';
                enable_calc_o <= '0';
                clear_h <= '0';
                clear_y <= '0';
                enable_calc_y <= '0';
                enable_counter_simple <= '0';
                enable_load_y_bob <= '0';
                enable_update_w <= '0';
                enable_clip_w <= '0';
                enable_exit_w <= '0';
                enable_exit_y <= '0';
                enable_load_seed_lfsr32 <= '0';
                enable_counter_col <= '0';
                
                for i in 0 to K-1 loop
                    enable_for_lfsr32(i) <= '0';
                    load_seed_for_lfsr32(i) <= '0';
                end loop;
                
                next_state <= idle;
        end case;
    end process;
    
    syn_fsm : process(clk)
    begin
        if(rising_edge(clk)) then
            if(reset = '1') then
                this_state <= idle;
            else
                this_state <= next_state;
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------------------------
    -- ATRIBUICAO DOS SINAIS COMBINATORIOS                                                     --
    ---------------------------------------------------------------------------------------------
    enable_counter_process <= '1' when this_state = generate_w else enable_counter;
    
    ---------------------------------------------------------------------------------------------
    -- ATRIBUICAO DOS SINAIS INTERNOS PARA SINAIS DA PORTA                                     --
    ---------------------------------------------------------------------------------------------
    
    -- busy_o <= busy;
    
    ---------------------------------------------------------------------------------------------
    -- INSTANCIACAO DOS COMPONENTES UTILIZADOS                                                 --
    ---------------------------------------------------------------------------------------------
    lfsr1 : lfsr generic map (G_M => 8, G_POLY => "10111000")
    port map(
        i_clk => clk,
        i_rstb => reset,
        i_sync_reset => load_seed_for_lfsr,
        i_seed => seed_for_lfsr(7 downto 0),
        i_en => enable_for_lfsr,
        o_lsfr => lfsr_random_number
    );
    
    -- instanciacao dos lfsr32
    gen_lfsr32: for i in 0 to K-1 generate
        lfsr32_x : lfsr32 port map (
            clk => clk,
            rst => reset,
            enable => enable_for_lfsr32(i),
            load_seed => load_seed_for_lfsr32(i),
            seed => seed_for_lfsr32(i),
            lfsr_o => lfsr32_random_number(i)
        );
    end generate gen_lfsr32;

end behavior;