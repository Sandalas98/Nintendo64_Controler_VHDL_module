-- Autor: Michał Kordasz
-- 2021

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity N64_cotroller_module is
    PORT(CLK : in STD_LOGIC;
    N64_CONTROLLER_DATA : inout std_logic;
    PULSE : out std_logic;
    DATA_OUT : out STD_LOGIC_VECTOR(31 downto 0)
    );
end N64_cotroller_module;

architecture Behavioral of N64_cotroller_module is
    type state is (Q0, Q1, Q2, Q3, Q4, Q5, Q6, Q7, Q8, Q9, Q10, Q11, Q10_wait);
    signal present_state, next_state : state;
    -- amount of CLKS_PER_BIT is based on 100 MHz clock
    constant CLKS_PER_BIT : integer := 399;
    -- Default: 20 times / second is measure
    constant MEASURE_PERIOD : integer := 500_000;
    
    constant Poll_command : STD_LOGIC_VECTOR(7 downto 0) := X"01";
    signal DATA_OUT_reg : STD_LOGIC_VECTOR(31 downto 0) := X"00_00_00_00";
    signal command_index : integer := 7;
    signal data_index : integer := 31;
    signal clk_counter : integer := 0;
    signal N64_data_reg : STD_LOGIC := '0';

    -- checker:
    signal Transmision_wait : STD_LOGIC := '0';
    -- data out from "console":
    signal Con_ended_transmission : STD_LOGIC := '0';
    signal Con_ended_stop_bit : STD_LOGIC := '0';
    -- data out from gamepad:
    signal Pad_found_middle_frame : STD_LOGIC := '0';
    signal Pad_ended_transmission : STD_LOGIC := '0';
    signal Pad_ended_stop_bit : STD_LOGIC := '0';
   
begin




    process_idle : process(CLK, present_state, next_state)
    begin
        if(rising_edge(CLK)) then
            present_state <= next_state;
        end if;
    end process;

    state_process : process(CLK, N64_CONTROLLER_DATA)
    begin
        if rising_edge(clk) then
            case( present_state ) is
            
                when Q0 =>
                    next_state <= Q4;
             
                -- 8 bits transmission
                when Q4 =>
                    if Con_ended_transmission = '1' then
                        next_state <= Q5;
                    else
                        next_state <= Q4;
                    end if;

                -- stop bit
                when Q5 =>
                    if Con_ended_stop_bit = '1' then    
                        next_state <= Q6;
                    else
                        next_state <= Q5;
                    end if;

                -- logic 1 on line - no transmission
                when Q6 =>
                    next_state <= Q7;

                -- wait for answer from controller - logic 0 
                when Q7 =>
                    if N64_CONTROLLER_DATA = '0' then
                        next_state <= Q8;
                    else
                        next_state <= Q7;
                    end if;

                -- find middle of frame of single bit
                when Q8 =>
                    if Pad_found_middle_frame = '1' then
                        next_state <= Q9;
                    else
                        next_state <= Q8;
                    end if;

                -- 4 bytes data
                when Q9 =>
                    if Pad_ended_transmission = '1' then
                        next_state <= Q10;
                    else 
                        next_state <= Q9;
                    end if;

                -- wait for stop bit
                when Q10 =>
                    if Pad_ended_stop_bit = '1' then
                        next_state <= Q10_wait;
                    else
                        next_state <= Q10;
                    end if;

                -- time period 
                when Q10_wait =>
                    if Transmision_wait = '1' then
                        next_state <= Q11;
                    else 
                        next_state <= Q10_wait;
                    end if;

                -- set signals;
                when Q11 =>
                    next_state <= Q4;
                
                when others =>
                    next_state <= Q0;
            
            end case ;
        end if;
    end process;

    pulse_process : process(present_state)
    begin
        if present_state = Q11 then
            PULSE <= '1';
        else
            PULSE <= '0';
        end if;
    end process;


    transmission_process : process(CLK)
    begin
        if rising_edge(CLK) then

            if present_state = Q0 then
                N64_CONTROLLER_DATA <= '1';
                

            -- poll command transmission
            elsif present_state = Q4 then
                if clk_counter < CLKS_PER_BIT then
                    clk_counter <= clk_counter + 1;
                        
                    if Poll_command(command_index) = '1' then
                            
                        if clk_counter < 100 then
                            N64_CONTROLLER_DATA <= '0';
                        else
                            N64_CONTROLLER_DATA <= '1';
                        end if;
                    else
                            
                        if clk_counter < 300 then
                            N64_CONTROLLER_DATA <= '0';
                        else
                            N64_CONTROLLER_DATA <= '1';
                        end if;
                            
                    end if;

                else

                    clk_counter <= 0;
                    
                    if command_index > 0 then
                        command_index <= command_index - 1;
                    else
                        command_index <= 7;
                        Con_ended_transmission <= '1';
                        clk_counter <= 0;
                    end if;
                end if;
                
            
            -- stop bit
            elsif present_state = Q5 then
                if clk_counter < 300 then
                    clk_counter <= clk_counter + 1;

                    if clk_counter < 100 then
                        N64_CONTROLLER_DATA <= '0';
                    else
                        N64_CONTROLLER_DATA <= '1';
                    end if;
                else
                    Con_ended_stop_bit <= '1';
                end if;
                

            -- ste high impedance
            elsif present_state = Q6 then
                clk_counter <= 0;
                N64_CONTROLLER_DATA <= 'Z';
                data_index <= 30;
                

            -- await for logic 0 
            elsif present_state = Q7 then
                N64_CONTROLLER_DATA <= 'Z';
                clk_counter <= 0;


            -- find middle frame
            elsif present_state = Q8 then
                N64_CONTROLLER_DATA <= 'Z';
                if clk_counter < (CLKS_PER_BIT - 5)/2 then
                    clk_counter <= clk_counter + 1;
                else
                    clk_counter <= 0;
                    DATA_OUT_reg(31) <= N64_data_reg;
                    Pad_found_middle_frame <= '1';
                end if;

            -- 4 bytes data transmission
            elsif present_state = Q9 then
                N64_CONTROLLER_DATA <= 'Z';

                if clk_counter < (CLKS_PER_BIT - 3) then
                    clk_counter <= clk_counter + 1;
                else

                    clk_counter <= 0;

                    if data_index > 0 then
                        data_index <= data_index - 1;
                        DATA_OUT_reg(data_index) <= N64_data_reg;
                        
                    else
                        DATA_OUT_reg(0) <= N64_data_reg;
                        Pad_ended_transmission <= '1';
                    end if;
                end if;
                

            -- stop bit
            elsif present_state = Q10 then
                N64_CONTROLLER_DATA <= 'Z';
                if clk_counter < 600 then
                    clk_counter <= clk_counter + 1;
                else
                    clk_counter <= 0;
                    Pad_ended_stop_bit <= '1';
                end if;

            elsif present_state = Q10_wait then
                N64_CONTROLLER_DATA <= '1';
                if clk_counter < MEASURE_PERIOD then
                    clk_counter <= clk_counter + 1;
                else
                    clk_counter <= 0;
                    Transmision_wait <= '1';
                end if;


            -- impuls
            elsif present_state = Q11 then  
                N64_CONTROLLER_DATA <= '1';
                clk_counter <= 0;
                Pad_ended_stop_bit <= '0';
                Pad_ended_transmission <= '0';
                Pad_found_middle_frame <= '0';
                Con_ended_transmission <= '0';
                Con_ended_stop_bit <= '0';
                data_index <= 31;
                command_index <= 7;
                Transmision_wait <= '0';
                DATA_OUT <= DATA_OUT_reg;
                
            else
                N64_CONTROLLER_DATA <= '1';
            end if;
        end if;
    end process;

    N64_process : process (CLK, N64_CONTROLLER_DATA)
    begin
        if rising_edge(CLK) then
            N64_data_reg <= N64_CONTROLLER_DATA;
        end if ;
    end process;


end Behavioral;

