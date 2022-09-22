  --************************************************************************************************
--  ______________
-- |              |
-- |    ^         |  Vendor             : Logic Fruit
-- |   / \        |  Version            : 1.0
-- |  /   \      _|  Application        : Thermal Imager
-- |-/     \    / |  Filename           : symb_pattern_source.vhd
-- |        \  /  |  
-- |         \/   |
-- |______________|
--
-- Device           : GENERIC
-- Design Name      : symb_pattern_source module
-- Purpose          : This block creates a symbology pattern (contains alphabets, numbers, or any symbols)
-- Overview         :
-- This creates a image with symbols of any resolution. The Height and Width of symbol letters does not change with resolution. 
-- Each symbol occupies 28 x 28 pixel matrix in the display. This uses a Xilinx BROM to store the representation of symbols.
-- Please see Section 2.4: Command Messages of Technical Specification document of Thermal Imager for the Command Fields
-- Last Updated     : 10 July 2020 
--************************************************************************************************************************************

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

entity symb_pattern_source is
generic(
--FIELD_VS_LAB                   : integer                       := 0;  -- 0 -> LAB ; 1 -> FIELD
    PIXEL_DEPTH                    :    integer          :=   8;           
    SYMB_GEN_DATA                  :    integer          :=   14;          -- Output data length of each pixel
    START_LINE_SYMB                :    natural          :=   1028;         -- start line of symbology display
    START_LINE_NUMB                :    natural          :=   5;          -- start line of symbology display
    HEIGHT_SYMB                    :    natural          :=   28;          -- height of each character
    WIDTH_SYMB                     :    natural          :=   28;          -- width of each character
	--CENTER_X                       :    natural          :=   960;
	--CENTER_Y                       :    natural          :=   540;
    VSYNC_ACTIVE                   :    natural          :=   1024;        -- resolution height
    HSYNC_ACTIVE                   :    natural          :=   1280;        -- resolution width
    PIXEL_SHIFT                    :    natural          :=   1 ;           -- number of pixels to be jumped
	N                              :    positive         :=   16

);
port(
    -- Clock & Reset
    clk                            :    in        std_logic;
    rst                            :    in        std_logic; -- active high reset
    -- Address for commands        
    address_command                :    in        std_logic_vector(7 downto 0);   -- from Command Decoder to indicate a command
    address_command_valid          :    in        std_logic;                      -- from Command Decoder
    data_in                        :    in        std_logic_vector(15 downto 0);  -- from Command Decoder, contains command message
    line_count_in                  :    in        std_logic_vector(15 downto 0);
    hsync_in                       :    in        std_logic;
    vsync_in                       :    in        std_logic;
    data_en                        :    in        std_logic;
    hsync_out                      :    out       std_logic;
	polarity_inv_3                 :    in        std_logic;
    vsync_out                      :    out       std_logic;
    data_out_valid                 :    out       std_logic;
    symb_busy                      :    out       std_logic;
    valid_srv                      :    out       std_logic;
    command_values_out             :    out       std_logic_vector(15 downto 0);       
    bst_control_in                 :    in        std_logic_vector(2 downto 0) ; 
    count_d                        :    out       integer range 0 to 4095                      :=   0;	
    count_1d                       :    out       integer range 0 to 4095                      :=   0;   
	symb_gen_data_out              :    out       std_logic_vector(SYMB_GEN_DATA - 1 downto 0)
    
	--spi_added
    --x_coordinate_in                :    in        std_logic_vector(15 downto 0); 
    --y_coordinate_in                :    in        std_logic_vector(15 downto 0); 
    --                
    --write_data                     :    out       std_logic;
    --read_data                      :    out       std_logic;
    --                
    --x_coordinate_out               :    out       std_logic_vector(15 downto 0);
    --y_coordinate_out               :    out       std_logic_vector(15 downto 0);
                    
    --valid_out                      :    in        std_logic       
    
);
END entity;

ARCHITECTURE rtl OF symb_pattern_source IS
type states is (start_x, shift_x, done_x);
type statess is (start_y, shift_y, done_y);
signal  state_x, state_next_x       :    states;
signal  state_y, state_next_y       :    statess;
signal  binary_x                    :    std_logic_vector(15 downto 0)                :=  (others => '0');
signal  binary_y                    :    std_logic_vector(15 downto 0)                :=  (others => '0');
signal  binary_next_x               :    std_logic_vector(15 downto 0)                 :=  (others => '0');
signal  binary_next_y               :    std_logic_vector(15 downto 0)                :=  (others => '0');
signal  bcds_x                      :    std_logic_vector(19 downto 0)                :=  (others => '0');
signal  bcds_y                      :    std_logic_vector(19 downto 0)                :=  (others => '0');
signal  bcds_reg_x                  :    std_logic_vector(19 downto 0)                :=  (others => '0');
signal  bcds_reg_y                  :    std_logic_vector(19 downto 0)                :=  (others => '0');
signal  bcds_next_x                 :    std_logic_vector(19 downto 0)                :=  (others => '0');
signal  bcds_next_y                 :    std_logic_vector(19 downto 0)                :=  (others => '0');
signal  bcds_out_reg_x              :    std_logic_vector(19 downto 0)                :=  (others => '0');
signal  bcds_out_reg_y              :    std_logic_vector(19 downto 0)                :=  (others => '0');
signal  bcds_out_reg_next_x         :    std_logic_vector(19 downto 0)                :=  (others => '0');
signal  bcds_out_reg_next_y         :    std_logic_vector(19 downto 0)                :=  (others => '0');
signal  shift_counter_x             :    natural range 0 to 16                        := 0 ;                           
signal  shift_counter_y             :    natural range 0 to 16                        := 0 ;                           
signal  shift_counter_next_x        :    natural range 0 to 16                        := 0 ;                           
signal  shift_counter_next_y        :    natural range 0 to 16                        := 0 ;                           
signal  en                          :    std_logic                                    := '0';                      -- ROM enable
signal  enn                         :    std_logic                                    := '0';                      
signal  addr                        :    std_logic_vector(10 downto 0)                :=  (others => '0');          -- ROM address
signal  dout                        :    std_logic_vector(WIDTH_SYMB - 1 downto 0);                                              -- Data from ROM
signal  command_values              :    std_logic_vector(15 downto 0)                :=  x"01e7";                  -- Register that stores all commands updated next frame
signal  command_values_cd           :    std_logic_vector(15 downto 0)                :=  x"01e7";                  -- Register that stores all commands
signal  line_valid_int              :    std_logic                                    :=  '1';
signal  frame_valid_int             :    std_logic                                    :=  '1';
signal  line_valid_int_1d           :    std_logic                                    :=  '1';
signal  frame_valid_int_1d          :    std_logic                                    :=  '1'; 
signal  count_1                     :    integer range 0 to 4095                      :=   0;
signal  count                       :    integer range 0 to 4095                      :=   0;
signal  count_3                     :    integer range 0 to 4095                      :=   1;
--signal  count_data_in               :    integer range 0 to 7                         :=   1;
signal  data_int                    :    std_logic_vector(15 downto 0)                :=  (others => '0');
signal  data_valid_int              :    std_logic                                    :=  '0';
signal  data_valid_int_1d           :    std_logic                                    :=  '0';
signal  pattern_zeros               :    std_logic_vector(PIXEL_DEPTH - 1 downto 0)   :=  (others => '0');
signal  nuc_type                    :    std_logic_vector(1 downto 0)                 :=  B"00";
signal  count_in                    :    integer                                      :=  0;
signal  length_symb                 :    std_logic_vector(10 downto 0)                :=  (others => '0');
signal  binary_in_x                 :    std_logic_vector(15 downto 0)                :=  (others => '0');
signal  binary_in_y                 :    std_logic_vector(15 downto 0)                :=  (others => '0');
signal  length_numb                 :    std_logic_vector(10 downto 0)                :=  (others => '0');
signal  x_shift                     :    integer                                      :=  0;                        -- displays reticle at x point in the display (x,y)
signal  x                           :    integer                                      :=  0;                        -- displays reticle at x point in the display (x,y)
signal  y_shift                     :    integer                                      :=  0;                        -- displays reticle at y point in the display (x,y)
signal  y                           :    integer                                      :=  0;                        -- displays reticle at y point in the display (x,y)
signal  symb_busy_sig               :    std_logic                                    :=  '0';                      -- becomes '1' from line 0 to 1023 for a frame
signal  busy_in                     :    std_logic                                    :=  '0';                      -- becomes high once data is received from CD
signal  count_x                     :    integer range 0 to 4095                      :=   0;
signal  count_y                     :    integer range 0 to 4095                      :=   0; 
signal ones_x                       :    std_logic_vector(3 downto 0)                :=  (others => '0');             -- indicating the values of x_shift and used in bst_case
signal tens_x                       :    std_logic_vector(3 downto 0)                :=  (others => '0');             -- indicating the values of x_shift and used in bst_case
signal hundreds_x                   :    std_logic_vector(3 downto 0)                :=  (others => '0');                 -- indicating the values of x_shift and used in bst_case
signal ones_y                       :    std_logic_vector(3 downto 0)                :=  (others => '0');             -- indicating the values of y_shift and used in bst_case
signal tens_y                       :    std_logic_vector(3 downto 0)                :=  (others => '0');             -- indicating the values of y_shift and used in bst_case
signal hundreds_y                   :    std_logic_vector(3 downto 0)                :=  (others => '0');             -- indicating the values of y_shift and used in bst_case
signal thousands_y                  :    std_logic_vector(3 downto 0)                :=  (others => '0');             -- indicating the values of y_shift and used in bst_case
signal thousands_x                  :    std_logic_vector(3 downto 0)                :=  (others => '0');             -- indicating the values of y_shift and used in bst_case
signal dec_signal_x                 :    integer                                     :=  0;            -- indicating the values of y_shift and used in bst_case
signal dec_signal_y                 :    integer                                     :=  0;             -- indicating the values of y_shift and used in bst_case
signal line_count                   :    std_logic_vector(15 downto 0)               :=  (others => '0');                 
signal bin_signal_x                 :    std_logic_vector(15 downto 0)               :=  (others => '0');                 
signal bin_signal_y                 :    std_logic_vector(15 downto 0)               :=  (others => '0');                 
signal bcd0_x                       :    std_logic_vector(3 downto 0)                :=  (others => '0');
signal bcd0_y                       :    std_logic_vector(3 downto 0)                :=  (others => '0');
signal bcd1_x                       :    std_logic_vector(3 downto 0)                :=  (others => '0');
signal bcd1_y                       :    std_logic_vector(3 downto 0)                :=  (others => '0');
signal bcd2_x                       :    std_logic_vector(3 downto 0)                :=  (others => '0');
signal bcd2_y                       :    std_logic_vector(3 downto 0)                :=  (others => '0');
signal bcd3_x                       :    std_logic_vector(3 downto 0)                :=  (others => '0');
signal bcd3_y                       :    std_logic_vector(3 downto 0)                :=  (others => '0');
signal bcd4_x                       :    std_logic_vector(3 downto 0)                :=  (others => '0');
signal bcd4_y                       :    std_logic_vector(3 downto 0)                :=  (others => '0');
signal  polarity_inv                :    std_logic                                   :=  '0';                       -- polarity_inv signal 
constant WIDTH_SYMB_LOC             :    natural                                     :=  28;
constant os                         :    natural                                     :=  28*16;                    -- this is the offset at which the symbology starts
constant ms                         :    natural                                     :=  28*30;     --for polarity and other purpose
constant cs                         :    natural                                     :=  28*58;    -- 58 to  done                -- this is the offset at which the symbology starts

signal vsync_in_d                   :    std_logic                                   := '0';


--signal flag_pol                     :   std_logic                                    :=  '0';      --flag for indications of features      
--signal count_polar                  :   integer                                      :=  0;      --flag for indications of features      
--signal flag_pol_wh                  :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_pol_bh                  :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_reten                   :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_reten_on                :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_reten_off               :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_bright                  :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_bright_plus             :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_bright_minus            :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_cntrst                  :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_cntrst_plus             :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_cntrst_minus            :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_retshft                 :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_retshft_r               :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_retshft_l               :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_retshft_u               :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_retshft_d               :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_menu                    :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_retsv                   :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_retsv_sel               :   std_logic                                    :=  '0';      --flag for indications of features      
--signal flag_ezoom                   :   std_logic                                    :=  '0';      --flag for indications of features     
--signal flag_ezoom_in                :   std_logic                                    :=  '0';      --flag for indications of features     
--signal flag_ezoom_out               :   std_logic                                    :=  '0';      --flag for indications of features   
signal address_command_valid_d      :   std_logic                                    :=  '0';
  
signal menu_command                 :   std_logic                                    :=  '0';
signal select_command               :   std_logic                                    :=  '0';
signal up_command                   :   std_logic                                    :=  '0';
signal down_command                 :   std_logic                                    :=  '0';
signal state_cmd_in                 :   std_logic_vector(3 downto 0)                 :=  (others => '0');

type   display_state is (S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16, S17, S18, S19, S20, S21, S22);
signal current_state                :   display_state                                :=  S0;
signal next_state                   :   display_state                                :=  S0;


--spi_added
signal  CENTER_X                    :    natural                                     :=   960;
signal  CENTER_Y                    :    natural                                     :=   540;

signal  write_data_int              :    std_logic                                   :=  '0';
signal  read_data_int               :    std_logic                                   :=  '0';
signal  valid_out_flag              :    std_logic                                   :=  '0';
signal  count_flag                  :    std_logic_vector(1 downto 0)                :=  (others => '0');

signal  x_coordinate_out_int        :    std_logic_vector(15 downto 0)               :=  (others => '0');
signal  y_coordinate_out_int        :    std_logic_vector(15 downto 0)               :=  (others => '0');

    
------------------ COMPONENT DECLARATION --------------------------------
-- This is BLOCK MEMORY GENERATOR (SIMPLE PORT ROM) IP V8.4 OF XILINX Vivado 2019.1 
-- This has a latency of 2 Clock cycle
COMPONENT single_port_rom_16x512 IS
PORT(
    clka : IN STD_LOGIC;
    ena : IN STD_LOGIC;
    addra : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(27 DOWNTO 0)
);
END COMPONENT;

BEGIN
    
--read_data        <= read_data_int;
--write_data       <= write_data_int;   
--x_coordinate_out <= x_coordinate_out_int;   
--y_coordinate_out <= y_coordinate_out_int;   
   
line_count    <= line_count_in;
length_symb   <= std_logic_vector(to_unsigned(START_LINE_SYMB, 11));
length_numb   <= std_logic_vector(to_unsigned(START_LINE_NUMB, 11));

ROM_UUT : single_port_rom_16x512
port map(
    clka  => clk,
    ena   => en,
    addra => addr,
    douta => dout
);

--process to generate valid_out_flag
--gen_valid_out_flag : process(clk, rst) is
--begin
--    if(rst = '1') then
--        count_flag      <= (others => '0');
--        valid_out_flag <= '0';
--    elsif(valid_out = '1') then
--        valid_out_flag  <= '1';
--        count_flag      <= "01";
--    elsif(rising_edge(clk)) then
--        if(read_data_int = '1') then
--		    if(count_flag = "01") then
--                count_flag  <= count_flag + 1;
--			else
--			    count_flag  <= count_flag;
--			end if;
--	    else
--			count_flag      <= count_flag;
--        end if;
--		if(count_flag = "10") then
--            count_flag      <= count_flag + 1;
--		elsif(count_flag = "11") then
--		    valid_out_flag  <= '0';
--		    count_flag      <= "00";
--		end if;
--    end if;
--end process gen_valid_out_flag;
--
----spi_added
----process to get input coordinates from memory
--get_input_cords : process(clk, rst) is
--begin
--    if(read_data_int = '1') then
--        if( valid_out_flag = '1' ) then
--            CENTER_X <= to_integer(unsigned(x_coordinate_in));
--            CENTER_Y <= to_integer(unsigned(y_coordinate_in));
--        else
--            CENTER_X <= CENTER_X;
--            CENTER_Y <= CENTER_Y;
--        end if;
--    else
--        CENTER_X <= CENTER_X;
--        CENTER_Y <= CENTER_Y;
--    end if;
--end process get_input_cords;
--
----process to get output coordinates to write to memory
--get_output_cords : process(clk, rst) is
--begin
--    if(write_data_int = '1') then
--        x_coordinate_out_int <= std_logic_vector(to_unsigned(dec_signal_x, x_coordinate_out_int'length));
--        y_coordinate_out_int <= std_logic_vector(to_unsigned(dec_signal_y, y_coordinate_out_int'length));
--    else
--        x_coordinate_out_int <= x_coordinate_out_int;
--        y_coordinate_out_int <= y_coordinate_out_int;
--    end if;
--end process get_output_cords;

delay : process(clk, rst) is
begin
    if rst = '1' then
        frame_valid_int      <= '0';
        frame_valid_int_1d   <= '0';
        line_valid_int       <= '0';
        line_valid_int_1d    <= '0';
        data_valid_int       <= '0';
        data_valid_int_1d    <= '0';
        enn                  <= '0';
        en                   <= '0';
        command_values       <= (others => '0');
		polarity_inv         <= '0';
		
    elsif rising_edge(clk) then
        line_valid_int       <= hsync_in;
        frame_valid_int      <= vsync_in;
        line_valid_int_1d    <= line_valid_int;
        frame_valid_int_1d   <= frame_valid_int;
        data_valid_int       <= data_en;
        data_valid_int_1d    <= data_valid_int;
        enn                  <= '1';
        en                   <= enn;
		polarity_inv          <= polarity_inv_3;
        if symb_busy_sig = '0' then
            command_values <= command_values_cd;     -- commands gets updated next frame
        end if;
    end if;
end process delay;

symb_busy <= symb_busy_sig;  -- no inside clk process



command_data : process (clk, rst) is
begin
    if rst = '1' then
        command_values_cd <= x"01e7"; -- B"0000000_111100111"; displays WH AGC MEN (default) --0000_
    elsif rising_edge(clk) then
      if address_command_valid = '1' then
        case address_command is
            when x"01" => -- SRV -- Set Recticle Video
                command_values_cd(1 downto 0) <= data_in (1 downto 0);
            when x"02" => -- SWP -- Swap black & White Palette
                command_values_cd(3 downto 2) <= data_in(1 downto 0);
            when x"03" => -- AGC -- Activate Auto Gain
                command_values_cd(5 downto 4) <= data_in(1 downto 0);
            when x"04" => -- MEN -- Menu
                command_values_cd(8 downto 6) <= B"110";
			-- when x"05" => -- TOP_DOWN
                -- command_values_cd(11 downto 9) <=  data_in(2 downto 0);	
            when x"07" => -- FNU -- Activate Feild NUC
                command_values_cd(8 downto 6) <= B"001";
            when x"08" => -- SZM -- Electronic Zoom Enabled
                command_values_cd(8 downto 6) <= B"010";
            when x"09" => -- THS -- Threshold for AGC mode
                command_values_cd(8 downto 6) <= B"011";
            when x"0a" => -- CLRT -- Cooler Run Time
                command_values_cd(8 downto 6) <= B"000";
            when x"0b" => -- ANU -- Activate NUC
                command_values_cd(8 downto 6) <= B"100";
                nuc_type <= data_in(1 downto 0);
            when x"0c" => -- INT -- Set Integration Time
                command_values_cd(8 downto 6) <= B"101";
            when x"0d" => -- IMG -- Image Processing Filters
                command_values_cd(8 downto 6) <= B"110";
            -- when x"10" => -- BST
                -- command_values_cd(10 downto 9) <= B"1";
            when others =>
                null;
        end case;
      end if;
    end if;
end process command_data;


state_machine : process(state_cmd_in) is
begin

	
	
	
    case current_state is
	
	    when S0 => if(state_cmd_in = "1000") then
		              next_state <= S1;
				  else
				      next_state <= next_state;
				  end if;
		when S1 => if(state_cmd_in = "1000") then
		              next_state <= S0;
				  elsif (state_cmd_in = "0100") then
				      next_state <= S2;
				  elsif (state_cmd_in = "0001") then
				      next_state <= S4;
				  elsif (state_cmd_in = "0010") then
				      next_state <= S20;
				  else
				      next_state <= next_state;
				  end if;
		when S2 => if(state_cmd_in = "1000") then
		              next_state <= S1;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001" or state_cmd_in = "0010") then
				      next_state <= S3;
				  else
				      next_state <= next_state;
				  end if;
		when S3 => if(state_cmd_in = "1000") then
		              next_state <= S1;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001" or state_cmd_in = "0010") then
				      next_state <= S2;
				  else
				      next_state <= next_state;
				  end if;
		when S4 => if(state_cmd_in = "1000") then
		              next_state <= S0;
				  elsif (state_cmd_in = "0100") then
				      next_state <= S5;
				  elsif (state_cmd_in = "0001") then
				      next_state <= S7;
				  elsif (state_cmd_in = "0010") then
				      next_state <= S1;
				  else
				      next_state <= next_state;
				  end if;
		when S5 => if(state_cmd_in = "1000") then
		              next_state <= S4;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001" or state_cmd_in = "0010") then
				      next_state <= S6;
				  else
				      next_state <= next_state;
				  end if;
		when S6 => if(state_cmd_in = "1000") then
		              next_state <= S4;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001" or state_cmd_in = "0010") then
				      next_state <= S5;
				  else
				      next_state <= next_state;
				  end if;
		when S7 => if(state_cmd_in = "1000") then
		              next_state <= S0;
				  elsif (state_cmd_in = "0100") then
				      next_state <= S8;
				  elsif (state_cmd_in = "0001") then
				      next_state <= S12;
				  elsif (state_cmd_in = "0010") then
				      next_state <= S4;
				  else
				      next_state <= next_state;
				  end if;
		when S8 => if(state_cmd_in = "1000") then
		              next_state <= S7;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001") then
				      next_state <= S9;
				  elsif (state_cmd_in = "0010") then
				      next_state <= S11;
				  else
				      next_state <= next_state;
				  end if;
		when S9 => if(state_cmd_in = "1000") then
		              next_state <= S7;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001") then
				      next_state <= S10;
				  elsif (state_cmd_in = "0010") then
				      next_state <= S8;
				  else
				      next_state <= next_state;
				  end if;
		when S10 => if(state_cmd_in = "1000") then
		              next_state <= S7;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001") then
				      next_state <= S11;
				  elsif (state_cmd_in = "0010") then
				      next_state <= S9;
				  else
				      next_state <= next_state;
				  end if;
		when S11 => if(state_cmd_in = "1000") then
		              next_state <= S7;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001") then
				      next_state <= S8;
				  elsif (state_cmd_in = "0010") then
				      next_state <= S10;
				  else
				      next_state <= next_state;
				  end if;
		when S12 => if(state_cmd_in = "1000") then
		              next_state <= S0;
				  elsif (state_cmd_in = "0100") then
				      next_state <= S13;
				  elsif (state_cmd_in = "0001") then
				      next_state <= S14;
				  elsif (state_cmd_in = "0010") then
				      next_state <= S7;
				  else
				      next_state <= next_state;
				  end if;
		when S13 => if(state_cmd_in = "1000") then
		              next_state <= S12;
				  elsif (state_cmd_in = "0100" or state_cmd_in = "0001" or state_cmd_in = "0010") then
				      next_state <= next_state;
				  else
				      next_state <= next_state;
				  end if;
		when S14 => if(state_cmd_in = "1000") then
		              next_state <= S0;
				  elsif (state_cmd_in = "0100") then
				      next_state <= S15;
				  elsif (state_cmd_in = "0001") then
				      next_state <= S17;
				  elsif (state_cmd_in = "0010") then
				      next_state <= S12;
				  else
				      next_state <= next_state;
				  end if;
		when S15 => if(state_cmd_in = "1000") then
		              next_state <= S14;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001" or state_cmd_in = "0010") then
				      next_state <= S16;
				  else
				      next_state <= next_state;
				  end if;
		when S16 => if(state_cmd_in = "1000") then
		              next_state <= S14;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001" or state_cmd_in = "0010") then
				      next_state <= S15;
				  else
				      next_state <= next_state;
				  end if;
		when S17 => if(state_cmd_in = "1000") then
		              next_state <= S0;
				  elsif (state_cmd_in = "0100") then
				      next_state <= S18;
				  elsif (state_cmd_in = "0001") then
				      next_state <= S20;
				  elsif (state_cmd_in = "0010") then
				      next_state <= S14;
				  else
				      next_state <= next_state;
				  end if;
		when S18 => if(state_cmd_in = "1000") then
		              next_state <= S17;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001" or state_cmd_in = "0010") then
				      next_state <= S19;
				  else
				      next_state <= next_state;
				  end if;
		when S19 => if(state_cmd_in = "1000") then
		              next_state <= S17;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001" or state_cmd_in = "0010") then
				      next_state <= S18;
				  else
				      next_state <= next_state;
				  end if;
		when S20 => if(state_cmd_in = "1000") then
		              next_state <= S0;
				  elsif (state_cmd_in = "0100") then
				      next_state <= S21;
				  elsif (state_cmd_in = "0001") then
				      next_state <= S1;
				  elsif (state_cmd_in = "0010") then
				      next_state <= S17;
				  else
				      next_state <= next_state;
				  end if;
		when S21 => if(state_cmd_in = "1000") then
		              next_state <= S20;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001" or state_cmd_in = "0010") then
				      next_state <= S22;
				  else
				      next_state <= next_state;
				  end if;
		when S22 => if(state_cmd_in = "1000") then
		              next_state <= S20;
				  elsif (state_cmd_in = "0100") then
				      next_state <= next_state;
				  elsif (state_cmd_in = "0001" or state_cmd_in = "0010") then
				      next_state <= S21;
				  else
				      next_state <= next_state;
				  end if;
		when others => next_state <= S0;
		
	end case;
end process;

video_gen : process(clk,rst) is
begin           
    if rst = '1' then
        count          <= 0;
        data_int       <= (others => '0');
        symb_busy_sig  <= '0';
        valid_srv      <= '0';
        x              <= 0;
        x_shift        <= 0;
        y              <= 0;
        y_shift        <= 0;
        addr           <= (others => '0');
        count_in       <= 0;
		count_x        <= 0;
        count_y        <= 0;
		count_data_in  <= 1;
        count_1        <= 0;
		count_3        <= 0;
		ones_x         <= (others => '0');
		ones_y         <= (others => '0');
		tens_x         <= (others => '0');
		tens_y         <= (others => '0');
		hundreds_x     <= (others => '0');		
		thousands_x    <= (others => '0');
		thousands_y    <= (others => '0');
		hundreds_y     <= (others => '0');
		
    elsif rising_edge(clk) then
        if data_en = '1' then
            count  <=  count + 1;
			count_1 <= count_1 +1;  --  change 
        elsif data_valid_int = '0' then
            count   <= 0;
			count_1 <= 0;
            count_3 <= 0;            --  change 
        end if;
        if address_command = x"10" then
            if data_in = x"0001" then
                x <= PIXEL_SHIFT;  -- right shift
            elsif data_in = x"0002" then
                x <= -PIXEL_SHIFT; -- left shift
            else
                x <= 0;
            end if;
            if data_in = x"0003" then
                y <= PIXEL_SHIFT;  -- up shift
            elsif data_in = x"0004" then
                y <= -PIXEL_SHIFT; -- down shift
            else
                y <= 0;
            end if;
        end if;

		
		address_command_valid_d <= address_command_valid;                                      -- delay by 1 clk cycle using to detect posedge
        --
		--if down_command = '1' then          -- here a counter that will do the count of submenu topics
	    --    if address_command_valid_d ='1' and address_command_valid ='0' then
	    --       count_data_in <= count_data_in +1;
		--	   if count_data_in = 7 then 
		--	     count_data_in <=1;
		--	   end if;	   
	    --    end if;		 
	    --elsif up_command = '1' then 
	    --    if address_command_valid ='1' and address_command_valid_d ='0' then
	    --       count_data_in <= count_data_in - 1;
		--	   if count_data_in =1 then 
		--	    count_data_in <=7;
	    --       end if;
	    --    end if;	
        --end if;		
		
				
		--if address_command = x"04" then               -- flag menu command                                      
	    --     if data_in = x"0007" then 
		--	    menu_command <='1';
		--	 end if;
        --end if;			 
		--
		--if address_command = x"04" then               -- flag select command we will use this command further                                      
	    --     if data_in = x"0002" then 
		--	    select_command <='1';
		--	   end if;
        --end if;
		
		
		--if address_command = x"05" then               -- flag menu command                                      
	    --     if data_in = x"0002" then 
		--	    up_command <='1';              -- flag select command we will use this command further                                      
	    --     elsif data_in = x"0001" then 
		--	    down_command <='1';
		--	 end if;
        --end if;
		current_state <= next_state;
	    vsync_in_d   <= vsync_in;
		state_cmd_in <= menu_command & select_command & up_command & down_command;
		
        if(vsync_in_d = '1' and vsync_in = '0') then
            menu_command   <= '0';
            select_command <= '0';
            up_command     <= '0';
            down_command   <= '0';
		elsif address_command = x"04" and (address_command_valid = '1' and address_command_valid_d = '0') then               -- flag menu command                                      
	        if data_in = x"0007" then 
			    menu_command <='1';
                select_command <= '0';
                up_command     <= '0';
                down_command   <= '0';
			end if;
			if data_in = x"0002" then 
			    select_command <='1';
                menu_command   <= '0';
                up_command     <= '0';
                down_command   <= '0';
			end if;
		elsif address_command = x"05" and (address_command_valid = '1' and address_command_valid_d = '0') then               -- flag menu command                                      
	        if data_in = x"0002" then 
			   up_command <='1';              -- flag select command we will use this command further     
               menu_command   <= '0';
               select_command <= '0';
               down_command   <= '0';                                 
	        elsif data_in = x"0001" then 
			   down_command <='1';
               menu_command   <= '0';
               select_command <= '0';
               up_command     <= '0';
			end if;
		else
            menu_command   <= menu_command  ;
            select_command <= select_command;
            up_command     <= up_command    ;
            down_command   <= down_command  ;
        end if;			
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	--if flag_pol ='1' and select_command ='1' then 
	--   if down_command='1' then          -- here a counter that will do the count of submenu topics  (bh/wh)   
	--        if address_command_valid_d ='1' and address_command_valid ='0' then
	--           count_polar <= count_polar +1;
	--		   if count_polar = 1 then 
	--		     count_polar <=0;
	--		   end if;	   
	--        end if;		 
	--    elsif up_command='1' then 
	--        if address_command_valid ='1' and address_command_valid_d ='0' then
	--           count_polar <= count_polar - 1;
	--		    if count_polar =0 then 
	--		     count_polar <=1;
	--            end if;
	--        end if;	
    --    end if; 
	--end if;	
		
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
		
        if data_en = '1' then
            symb_busy_sig <= '1'; 
            if line_count >= START_LINE_NUMB and line_count  < (START_LINE_NUMB + HEIGHT_SYMB)	then
			  if address_command = x"01" then    -- if the command is reticle off and we have not to display anything on numbers 
			    if data_in = x"0003" then 
				   case count_1 is
				      when (0+cs) to (cs + 10*WIDTH_SYMB_LOC - 1) =>
					     data_int <= x"0000";  
					  when others =>
                         data_int <= x"0000";					  
					end case;
                end if;
              end if;				
			     if address_command = x"10" then                 
				    if (data_in = x"0001" or data_in = x"0002" or data_in = x"0003" or  data_in = x"0004") then                   -- for right shifting of the reticle
				       case count_1 is	  
                          when (0 + cs) to (cs + WIDTH_SYMB_LOC - 1) =>
                             data_int <= x"0000";
                             if count_1 = (cs + WIDTH_SYMB - 1) then
				   	            if bcds_out_reg_x(15 downto 12) = 1    then
                                    addr <= std_logic_vector(to_unsigned(27*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                elsif bcds_out_reg_x(15 downto 12) = 2 then
                                    addr <= std_logic_vector(to_unsigned(28*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                elsif bcds_out_reg_x(15 downto 12)= 3  then                                                  
                                    addr <= std_logic_vector(to_unsigned(29*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                elsif bcds_out_reg_x(15 downto 12)= 4  then
                                    addr <= std_logic_vector(to_unsigned(30*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                elsif bcds_out_reg_x(15 downto 12) =5  then
                                    addr <= std_logic_vector(to_unsigned(31*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                elsif bcds_out_reg_x(15 downto 12) = 6 then
                                    addr <= std_logic_vector(to_unsigned(32*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                elsif bcds_out_reg_x(15 downto 12) = 7 then
                                    addr <= std_logic_vector(to_unsigned(33*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                elsif bcds_out_reg_x(15 downto 12) =8  then 
                                    addr <= std_logic_vector(to_unsigned(34*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
				   		        elsif bcds_out_reg_x(15 downto 12) =9  then 
                                    addr <= std_logic_vector(to_unsigned(35*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
				   		        elsif bcds_out_reg_x(15 downto 12) =0  then 
                                    addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
				   		        else  
                                    addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                end if;	  
                             end if;	  
                          when (cs + WIDTH_SYMB_LOC) to (cs + 2*WIDTH_SYMB_LOC - 1) =>  
                             if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                 data_int <= x"0000";
                             else
                                 data_int <= x"ffff";
                             end if;
                             if count_in = (WIDTH_SYMB - 1) then
                                 count_in <= 0;
                             else
                                 count_in <= count_in + 1;
                             end if;
                             if count_1 = (cs + 2*WIDTH_SYMB - 1)  then
				   	            if bcds_out_reg_x(11 downto 8) = 1    then
                                  addr <= std_logic_vector(to_unsigned(27*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                elsif bcds_out_reg_x(11 downto 8) = 2 then
                                    addr <= std_logic_vector(to_unsigned(28*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                elsif bcds_out_reg_x(11 downto 8)= 3  then                                                  
                                    addr <= std_logic_vector(to_unsigned(29*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                elsif bcds_out_reg_x(11 downto 8)= 4  then
                                    addr <= std_logic_vector(to_unsigned(30*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                elsif bcds_out_reg_x(11 downto 8) =5  then
                                    addr <= std_logic_vector(to_unsigned(31*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                elsif bcds_out_reg_x(11 downto 8)= 6  then
                                    addr <= std_logic_vector(to_unsigned(32*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                elsif bcds_out_reg_x(11 downto 8) = 7 then
                                    addr <= std_logic_vector(to_unsigned(33*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                elsif bcds_out_reg_x(11 downto 8) =8  then 
                                    addr <= std_logic_vector(to_unsigned(34*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
				   		        elsif bcds_out_reg_x(11 downto 8) =9  then 
                                    addr <= std_logic_vector(to_unsigned(35*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
				   		        elsif bcds_out_reg_x(11 downto 8) =0  then 
                                    addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
				   		        else  
                                    addr <= std_logic_vector(to_unsigned(35*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                end if;	
                             end if;
                          when (cs + 2*WIDTH_SYMB_LOC) to (cs + 3*WIDTH_SYMB_LOC - 1) =>
                              if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                  data_int <= x"0000";
                              else
                                  data_int <= x"ffff";
                              end if;
                              if count_in = (WIDTH_SYMB - 1) then
                                  count_in <= 0;
                              else 
                                  count_in <= count_in + 1;
                              end if;   
                              if count_1 = (cs + 3*WIDTH_SYMB -1 ) then            -- (cs + 3*WIDTH_SYMB - 1) then
				   	             if bcds_out_reg_x(7 downto 4) = 1    then
                                     addr <= std_logic_vector(to_unsigned(27*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                 elsif bcds_out_reg_x(7 downto 4) = 2 then
                                     addr <= std_logic_vector(to_unsigned(28*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                 elsif bcds_out_reg_x(7 downto 4)= 3  then                                                  
                                     addr <= std_logic_vector(to_unsigned(29*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                 elsif bcds_out_reg_x(7 downto 4)= 4  then
                                     addr <= std_logic_vector(to_unsigned(30*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                 elsif bcds_out_reg_x(7 downto 4) =5  then
                                     addr <= std_logic_vector(to_unsigned(31*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                 elsif bcds_out_reg_x(7 downto 4) = 6 then
                                     addr <= std_logic_vector(to_unsigned(32*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                 elsif bcds_out_reg_x(7 downto 4) = 7 then
                                     addr <= std_logic_vector(to_unsigned(33*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                 elsif bcds_out_reg_x(7 downto 4) =8  then 
                                     addr <= std_logic_vector(to_unsigned(34*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
				   		         elsif bcds_out_reg_x(7 downto 4) =9  then 
                                        addr <= std_logic_vector(to_unsigned(35*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
				   		         elsif bcds_out_reg_x(7 downto 4) =0  then 
                                        addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
				   		         else  
                                     addr <= std_logic_vector(to_unsigned(32*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                 end if;	                       
                              end if;
                           when (cs + 3*WIDTH_SYMB_LOC) to (cs + 4*WIDTH_SYMB_LOC - 1) =>
                               if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                   data_int <= x"0000";  
                               else
                                   data_int <= x"ffff";
                               end if;
                               if count_in = (WIDTH_SYMB - 1) then
                                   count_in <= 0;
                               else
                                   count_in <= count_in + 1;
                               end if;
                               if count_1 = (cs + 4*WIDTH_SYMB - 1) then
                                  if bcds_out_reg_x(3 downto 0) = 1    then
                                      addr <= std_logic_vector(to_unsigned(27*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_x(3 downto 0) =2  then
                                      addr <= std_logic_vector(to_unsigned(28*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                  elsif bcds_out_reg_x(3 downto 0)= 3  then                                                  
                                      addr <= std_logic_vector(to_unsigned(29*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                  elsif bcds_out_reg_x(3 downto 0)= 4  then
                                      addr <= std_logic_vector(to_unsigned(30*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_x(3 downto 0) =5  then
                                      addr <= std_logic_vector(to_unsigned(31*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                  elsif bcds_out_reg_x(3 downto 0) =6  then
                                      addr <= std_logic_vector(to_unsigned(32*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_x(3 downto 0) =7  then
                                      addr <= std_logic_vector(to_unsigned(33*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                  elsif bcds_out_reg_x(3 downto 0) =8  then 
                                      addr <= std_logic_vector(to_unsigned(34*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
				   		          elsif bcds_out_reg_x(3 downto 0) =9  then 
                                      addr <= std_logic_vector(to_unsigned(35*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
				   		          elsif bcds_out_reg_x(3 downto 0) =0  then 
                                      addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
				   		          else  
                                      addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  end if;	
                               end if;
                           when (cs + 4*WIDTH_SYMB_LOC) to (cs + 5*WIDTH_SYMB_LOC - 1) =>
                               if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                   data_int <= x"0000";
                               else
                                   data_int <= x"ffff";
                               end if;
                               if count_in = (WIDTH_SYMB - 1) then
                                   count_in <= 0;
                               else
                                   count_in <= count_in + 1;
                               end if;
                               if count_1 = (cs + 5*WIDTH_SYMB - 1) then
                                    addr <= std_logic_vector(to_unsigned(38*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                               end if;
                           when (cs + 5*WIDTH_SYMB_LOC) to (cs + 6*WIDTH_SYMB_LOC - 1) =>
                               if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                   data_int <= x"0000";
                               else
                                   data_int <= x"ffff";
                               end if;
                               if count_in = (WIDTH_SYMB - 1) then
                                   count_in <= 0;
                               else
                                   count_in <= count_in + 1;
                               end if;   
                               if count_1 = (cs + 6*WIDTH_SYMB - 1) then
                                  if bcds_out_reg_y(15 downto 12) = 1 then     
                                     addr <= std_logic_vector(to_unsigned(27*HEIGHT_SYMB, 11)) + line_count(10 downto 0)  - length_numb; 
                                  elsif bcds_out_reg_y(15 downto 12) = 2 then
                                      addr <= std_logic_vector(to_unsigned(28*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_y(15 downto 12)= 3  then                                                  
                                      addr <= std_logic_vector(to_unsigned(29*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_y(15 downto 12)= 4  then
                                      addr <= std_logic_vector(to_unsigned(30*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_y(15 downto 12) =5  then
                                      addr <= std_logic_vector(to_unsigned(31*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_y(15 downto 12)= 6  then
                                      addr <= std_logic_vector(to_unsigned(32*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_y(15 downto 12) = 7 then
                                      addr <= std_logic_vector(to_unsigned(33*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_y(15 downto 12) =8  then 
                                      addr <= std_logic_vector(to_unsigned(34*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_y(15 downto 12) =9  then 
                                      addr <= std_logic_vector(to_unsigned(35*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_y(15 downto 12) =0  then 
                                      addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  else  
                                      addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
 							      end if;	                                                                   					  
                               end if;
                           when (cs + 6*WIDTH_SYMB_LOC) to (cs + 7*WIDTH_SYMB_LOC - 1) =>
                               if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                   data_int <= x"0000";
                               else
                                   data_int <= x"ffff";
                               end if;
                               if count_in = (WIDTH_SYMB - 1) then
                                   count_in <= 0;
                               else
                                   count_in <= count_in + 1;
                               end if;
                               if count_1 = (cs + 7*WIDTH_SYMB - 1) then
                                  if bcds_out_reg_y(11 downto 8) = 1   then
							         addr <= std_logic_vector(to_unsigned(27*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb ; 
							      elsif bcds_out_reg_y(11 downto 8) = 2 then
							          addr <= std_logic_vector(to_unsigned(28*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
							      elsif bcds_out_reg_y(11 downto 8)= 3  then                                                  
                                      addr <= std_logic_vector(to_unsigned(29*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                  elsif bcds_out_reg_y(11 downto 8)= 4  then
                                      addr <= std_logic_vector(to_unsigned(30*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_y(11 downto 8) =5  then
                                      addr <= std_logic_vector(to_unsigned(31*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                  elsif bcds_out_reg_y(11 downto 8) = 6 then
                                      addr <= std_logic_vector(to_unsigned(32*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_y(11 downto 8)= 7  then
                                      addr <= std_logic_vector(to_unsigned(33*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                                  elsif bcds_out_reg_y(11 downto 8) =8  then 
                                      addr <= std_logic_vector(to_unsigned(34*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_y(11 downto 8) =9  then 
                                      addr <= std_logic_vector(to_unsigned(35*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  elsif bcds_out_reg_y(11 downto 8) =0  then 
                                      addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                                  else  
                                      addr <= std_logic_vector(to_unsigned(35*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
							      end if;	
                               end if;
                           when (cs + 7*WIDTH_SYMB_LOC) to (cs + 8*WIDTH_SYMB_LOC - 1) =>
                               if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                   data_int <= x"0000";
                               else
                                   data_int <= x"ffff";
                               end if;
                               if count_in = (WIDTH_SYMB - 1) then
                                   count_in <= 0;
                               else
                                   count_in <= count_in + 1;
                               end if;
                               if count_1 = (cs + 8*WIDTH_SYMB - 1) then
                                      -- addr <= std_logic_vector(to_unsigned(30*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
						     	  if bcds_out_reg_y(7 downto 4) =1    then	 
						     	     addr <= std_logic_vector(to_unsigned(27*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	 
						     	  elsif bcds_out_reg_y(7 downto 4) =2 then	 
						     	      addr <= std_logic_vector(to_unsigned(28*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  	 
						     	  elsif bcds_out_reg_y(7 downto 4) =3 then                                                  	 
						     	      addr <= std_logic_vector(to_unsigned(29*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  	 
						     	  elsif bcds_out_reg_y(7 downto 4)= 4 then	 
						     	      addr <= std_logic_vector(to_unsigned(30*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	 
						     	  elsif bcds_out_reg_y(7 downto 4) =5 then	 
						     	      addr <= std_logic_vector(to_unsigned(31*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  	 
						     	  elsif bcds_out_reg_y(7 downto 4) =6 then	 
						     	      addr <= std_logic_vector(to_unsigned(32*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	 
						     	  elsif bcds_out_reg_y(7 downto 4) =7 then	 
						     	      addr <= std_logic_vector(to_unsigned(33*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  	 
						     	  elsif bcds_out_reg_y(7 downto 4) =8 then 	 
						     	      addr <= std_logic_vector(to_unsigned(34*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	 
						     	  elsif bcds_out_reg_y(7 downto 4) =9 then 	 
						     	      addr <= std_logic_vector(to_unsigned(35*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	 
						     	  elsif bcds_out_reg_y(7 downto 4) =0 then 	 
						     	      addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	 
						     	  else  	 
						     	      addr <= std_logic_vector(to_unsigned(32*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	 
						     	  end if;		 								 
                               end if;
                           when (cs + 8*WIDTH_SYMB_LOC) to (cs + 9*WIDTH_SYMB_LOC - 1) =>                         
                              if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                  data_int <= x"0000";
                              else
                                  data_int <= x"ffff";
                              end if;
                              if count_in = (WIDTH_SYMB - 1) then
                                  count_in <= 0;
                              else
                                  count_in <= count_in + 1;
                              end if;
                              if count_1 = (cs + 9*WIDTH_SYMB - 1) then
							     if bcds_out_reg_y(3 downto 0)= 1    then
							       addr <= std_logic_vector(to_unsigned(27*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	
							     elsif bcds_out_reg_y(3 downto 0) = 2 then	
							         addr <= std_logic_vector(to_unsigned(28*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  	
							     elsif bcds_out_reg_y(3 downto 0) = 3  then                                                  	
							         addr <= std_logic_vector(to_unsigned(29*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  	
							     elsif bcds_out_reg_y(3 downto 0) = 4  then	
							         addr <= std_logic_vector(to_unsigned(30*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	
							     elsif bcds_out_reg_y(3 downto 0) = 5  then	
							         addr <= std_logic_vector(to_unsigned(31*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  	
							     elsif bcds_out_reg_y(3 downto 0) = 6 then	
							         addr <= std_logic_vector(to_unsigned(32*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	
							     elsif bcds_out_reg_y(3 downto 0) = 7 then	
							         addr <= std_logic_vector(to_unsigned(33*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  	
							     elsif bcds_out_reg_y(3 downto 0) = 8  then 	
							         addr <= std_logic_vector(to_unsigned(34*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	
							     elsif bcds_out_reg_y(3 downto 0) = 9  then 	
							         addr <= std_logic_vector(to_unsigned(35*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	
							     elsif bcds_out_reg_y(3 downto 0) = 0  then 	
							         addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	
							     else  	
							         addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 	
							     end if;																																																																							
                              end if;
                           when (cs + 9*WIDTH_SYMB_LOC) to (cs + 10*WIDTH_SYMB_LOC - 1) => 
                                   if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                       data_int <= x"0000";
                                   else
                                       data_int <= x"ffff";
                                   end if;
                                   if count_in = (WIDTH_SYMB - 1) then
                                       count_in <= 0;
                                   else
                                       count_in <= count_in + 1;
                                   end if;
                           when others =>
                               data_int <= x"0000";
                           end case;
                    else   
                       case count_1 is  				  
					     when (0 + cs) to (cs + WIDTH_SYMB_LOC - 1) =>
					       data_int <= x"0000";
					       if count_1 = (cs + WIDTH_SYMB - 1) then
					               addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; -- W                       
					       end if;
					      
					     when (cs + WIDTH_SYMB_LOC) to (cs + 2*WIDTH_SYMB_LOC - 1) =>  
					       if dout(WIDTH_SYMB - 1 - count_in) = '0' then
					           data_int <= x"0000";
					       else
					           data_int <= x"ffff";
					       end if;
					       if count_in = (WIDTH_SYMB - 1) then
					           count_in <= 0;
					       else
                               count_in <= count_in + 1;
                           end if;
                           if count_1 = (cs + 2*WIDTH_SYMB - 1)  then
                               addr <= std_logic_vector(to_unsigned(35*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;      -- H
                           end if;
                            
                         when (cs + 2*WIDTH_SYMB_LOC) to (cs + 3*WIDTH_SYMB_LOC - 1) =>
                           if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                               data_int <= x"0000";
                           else
                               data_int <= x"ffff";
                           end if;
                           if count_in = (WIDTH_SYMB - 1) then
                               count_in <= 0;
                           else
                               count_in <= count_in + 1;
                           end if;   				      
                        
                           if count_1 = (cs + 3*WIDTH_SYMB - 1) then
                              addr <= std_logic_vector(to_unsigned(32*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;                        
                           end if;
                           
                         when (cs + 3*WIDTH_SYMB_LOC) to (cs + 4*WIDTH_SYMB_LOC - 1) =>
                           if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                               data_int <= x"0000";   
                           else
                               data_int <= x"ffff";
                           end if;
                           if count_in = (WIDTH_SYMB - 1) then
                               count_in <= 0;
                           else
                               count_in <= count_in + 1;
                           end if;
                           if count_1 = (cs + 4*WIDTH_SYMB - 1) then
                               addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb; 
                           end if;
                           
                         when (cs + 4*WIDTH_SYMB_LOC) to (cs + 5*WIDTH_SYMB_LOC - 1) =>
                            if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                data_int <= x"0000";
                            else
                                data_int <= x"ffff";
                            end if;
                            if count_in = (WIDTH_SYMB - 1) then
                                count_in <= 0;
                            else
                                count_in <= count_in + 1;
                            end if;
                            if count_1 = (cs + 5*WIDTH_SYMB - 1) then
                               addr <= std_logic_vector(to_unsigned(38*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;                               
                            end if;                           
                         when (cs + 5*WIDTH_SYMB_LOC) to (cs + 6*WIDTH_SYMB_LOC - 1) =>
                            if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                data_int <= x"0000";
                            else
                                data_int <= x"ffff";
                            end if;
                            if count_in = (WIDTH_SYMB - 1) then
                                count_in <= 0;
                            else
                                count_in <= count_in + 1;
                            end if;  
                            if count_1 = (cs + 6*WIDTH_SYMB - 1) then
                                    addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;                                                             
                            end if;
                          
                         when (cs + 6*WIDTH_SYMB_LOC) to (cs + 7*WIDTH_SYMB_LOC - 1) =>
                            if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                data_int <= x"0000";
                            else
                                data_int <= x"ffff";
                            end if;
                            if count_in = (WIDTH_SYMB - 1) then
                                count_in <= 0;
                            else
                                count_in <= count_in + 1;
                            end if;
                            if count_1 = (cs + 7*WIDTH_SYMB - 1) then
                                addr <= std_logic_vector(to_unsigned(31*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                            end if;
                         when (cs + 7*WIDTH_SYMB_LOC) to (cs + 8*WIDTH_SYMB_LOC - 1) => 
                            if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                data_int <= x"0000";
                            else
                                data_int <= x"ffff";
                            end if;
                            if count_in = (WIDTH_SYMB - 1) then
                                count_in <= 0;
                            else
                                count_in <= count_in + 1;
                            end if;
                            if count_1 = (cs + 8*WIDTH_SYMB - 1) then
                                    addr <= std_logic_vector(to_unsigned(30*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                            end if;
                         when (cs + 8*WIDTH_SYMB_LOC) to (cs + 9*WIDTH_SYMB_LOC - 1) =>                   
                            if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                data_int <= x"0000";
                            else
                                data_int <= x"ffff";
                            end if;
                            if count_in = (WIDTH_SYMB - 1) then
                                count_in <= 0;
                            else
                                count_in <= count_in + 1;
                            end if;
                            if count_1 = (cs + 9*WIDTH_SYMB - 1) then
                                  addr <= std_logic_vector(to_unsigned(26*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_numb;  
                            end if;
                         when (cs + 9*WIDTH_SYMB_LOC) to (cs + 10*WIDTH_SYMB_LOC - 1) =>
                                if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                                    data_int <= x"0000";
                                else
                                    data_int <= x"ffff";
                                end if;
                                if count_in = (WIDTH_SYMB - 1) then
                                    count_in <= 0;
                                else
                                    count_in <= count_in + 1;
                                end if;
                            
                         when others =>
                            data_int <= x"0000";
				         end case;
					end if;	                				
			     end if;   
            elsif line_count >= (VSYNC_ACTIVE/2 - (5*(HEIGHT_SYMB/2)) + y_shift) and line_count < (VSYNC_ACTIVE/2 - (3*(HEIGHT_SYMB/2)) + y_shift) then  -- RETICLE -- SRV
                if command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10" then
                    addr <= std_logic_vector(to_unsigned(  36*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 - (5*(HEIGHT_SYMB/2)) + y_shift);  -- WH
                -- elsif command_values(1 downto 0) = B"10" then
                    -- addr <= std_logic_vector(to_unsigned(27*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 - (5*(HEIGHT_SYMB/2)) + y_shift);  -- BH (need to make proper changes for black)
                end if;
                if count >= (HSYNC_ACTIVE/2 - WIDTH_SYMB/2 + x_shift) and count < (HSYNC_ACTIVE/2 + WIDTH_SYMB/2 + x_shift) and (command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10") then
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";  --(black)  -- FOR FUll pixels density to be black values.
                        valid_srv <= '0';
                    else
                        data_int <= x"ffff";  --(white)  -- for full pixel to be full white  same for the rest .
                        valid_srv <= '1';
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
                else
                    data_int <= x"0000"; -- not actually required
                end if;
                
            elsif line_count >= (VSYNC_ACTIVE/2 - (3*(HEIGHT_SYMB/2)) + y_shift) and line_count < (VSYNC_ACTIVE/2 - (1*(HEIGHT_SYMB/2)) + y_shift) then  -- RETICLE -- SRV
                if command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10" then
                    addr <= std_logic_vector(to_unsigned(36*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 - (3*(HEIGHT_SYMB/2)) + y_shift);  -- WH
                -- elsif command_values(1 downto 0) = B"10" then
                    -- addr <= std_logic_vector(to_unsigned(27*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 - (3*(HEIGHT_SYMB/2)) + y_shift);  -- BH (need to make proper changes for black)
                end if;
                if count >= (HSYNC_ACTIVE/2 - WIDTH_SYMB/2 + x_shift) and count < (HSYNC_ACTIVE/2 + WIDTH_SYMB/2 + x_shift) and (command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10") then
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";  --(black)
                        valid_srv <= '0';
                    else
                        data_int <= x"ffff";  --(white)
                        valid_srv <= '1';
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
                else
                    data_int <= x"0000"; -- not actually required
                end if;
                
            elsif line_count >= (VSYNC_ACTIVE/2 - (1*(HEIGHT_SYMB/2)) + y_shift) and line_count < (VSYNC_ACTIVE/2 + (1*(HEIGHT_SYMB/2)) + y_shift) then  -- RETICLE -- SRV
                if count = 1 then
                    if command_values(1 downto 0) = B"1" or command_values(1 downto 0) = B"10" then
                        addr <= std_logic_vector(to_unsigned(37*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 - HEIGHT_SYMB/2 + y_shift);  -- WH
                    -- elsif command_values(1 downto 0) = B"10" then
                        -- addr <= std_logic_vector(to_unsigned(37*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 - HEIGHT_SYMB/2 + y_shift);  -- BH (need to make proper changes for black)
                    end if;
                elsif count >= (HSYNC_ACTIVE/2 - (5*(WIDTH_SYMB/2)) + x_shift) and count < (HSYNC_ACTIVE/2 - (3*(WIDTH_SYMB/2)) + x_shift) and (command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10") then
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";  --(black)
                        valid_srv <= '0';
                    else
                        data_int <= x"ffff";  --(white)
                        valid_srv <= '1';
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
                elsif count >= (HSYNC_ACTIVE/2 - (3*(WIDTH_SYMB/2)) + x_shift) and count < (HSYNC_ACTIVE/2 - WIDTH_SYMB/2 + x_shift) and (command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10") then
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";  --(black)
                        valid_srv <= '0';
                    else
                        data_int <= x"ffff";  --(white)
                        valid_srv <= '1';
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
                    if count = (HSYNC_ACTIVE/2 - WIDTH_SYMB/2 + x_shift) - 1 then
                        if command_values(1 downto 0) = B"11" or command_values(1 downto 0) = B"10" then
                            addr <= std_logic_vector(to_unsigned(38*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 - HEIGHT_SYMB/2 + y_shift);  -- WH
                        -- elsif command_values(1 downto 0) = B"10" then
                            -- addr <= std_logic_vector(to_unsigned(37*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 - HEIGHT_SYMB/2 + y_shift);  -- BH (need to make proper changes for black)
                        end if;
                    end if;
                elsif count >= (HSYNC_ACTIVE/2 - WIDTH_SYMB/2 + x_shift) and count < (HSYNC_ACTIVE/2 + WIDTH_SYMB/2 + x_shift) and (command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10") then
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";  --(black)
                        valid_srv <= '0';
                    else
                        data_int <= x"ffff";  --(white)
                        valid_srv <= '1';
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
                    if count = (HSYNC_ACTIVE/2 + WIDTH_SYMB/2 + x_shift) - 1 then
                        if command_values(1 downto 0) = B"11" or command_values(1 downto 0) = B"10" then
                            addr <= std_logic_vector(to_unsigned(37*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 - HEIGHT_SYMB/2 + y_shift);  -- WH
                        -- elsif command_values(1 downto 0) = B"10" then
                            -- addr <= std_logic_vector(to_unsigned(37*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 - HEIGHT_SYMB/2 + y_shift);  -- BH (need to make proper changes for black)
                        end if;
                    end if;
                elsif count >= (HSYNC_ACTIVE/2 + WIDTH_SYMB/2 + x_shift) and count < (HSYNC_ACTIVE/2 + (3*(WIDTH_SYMB/2)) + x_shift) and (command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10") then
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";  --(black)
                        valid_srv <= '0';
                    else
                        data_int <= x"ffff";  --(white)
                        valid_srv <= '1';
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
                elsif count >= (HSYNC_ACTIVE/2 + (3*(WIDTH_SYMB/2)) + x_shift) and count < (HSYNC_ACTIVE/2 + (5*(WIDTH_SYMB/2)) + x_shift) and (command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10") then
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";  --(black)
                        valid_srv <= '0';
                    else
                        data_int <= x"ffff";  --(white)
                        valid_srv <= '1';
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
                else
                    data_int <= x"0000";  -- this else condition is not actually required.
                end if;
            
            elsif line_count >= (VSYNC_ACTIVE/2 + HEIGHT_SYMB/2 + y_shift) and line_count < (VSYNC_ACTIVE/2 + (3*(HEIGHT_SYMB/2)) + y_shift) then  -- RETICLE -- SRV
                if command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10" then
                    addr <= std_logic_vector(to_unsigned(36*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 + (1*(HEIGHT_SYMB/2)) + y_shift);  -- WH
                -- elsif command_values(1 downto 0) = B"10" then
                    -- addr <= std_logic_vector(to_unsigned(27*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 - (3*(HEIGHT_SYMB/2)) + y_shift);  -- BH (need to make proper changes for black)
                end if;
                if count >= (HSYNC_ACTIVE/2 - WIDTH_SYMB/2 + x_shift) and count < (HSYNC_ACTIVE/2 + WIDTH_SYMB/2 + x_shift) and (command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10") then
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";  --(black)
                        valid_srv <= '0';
                    else
                        data_int <= x"ffff";  --(white)
                        valid_srv <= '1';
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
                else
                    data_int <= x"0000"; -- not actually required
                end if;

            elsif line_count >= (VSYNC_ACTIVE/2 + (3*(HEIGHT_SYMB/2)) + y_shift) and line_count < (VSYNC_ACTIVE/2 + (5*(HEIGHT_SYMB/2)) + y_shift) then  -- RETICLE -- SRV
                if command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10" then
                    addr <= std_logic_vector(to_unsigned(36*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 + (3*(HEIGHT_SYMB/2)) + y_shift);  -- WH
                -- elsif command_values(1 downto 0) = B"10" then
                    -- addr <= std_logic_vector(to_unsigned(27*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - (VSYNC_ACTIVE/2 - (3*(HEIGHT_SYMB/2)) + y_shift);  -- BH (need to make proper changes for black)
                end if;
                if command_values(1 downto 0) = B"11" then  -- for resetting position to center, if we dont want this to happen comment the if statement
                    x_shift <= 0;
                    y_shift <= 0;
                end if;
                if count >= (HSYNC_ACTIVE/2 - WIDTH_SYMB/2 + x_shift) and count < (HSYNC_ACTIVE/2 + WIDTH_SYMB/2 + x_shift) and (command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10") then
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";  --(black)
                        valid_srv <= '0';
                    else
                        data_int <= x"ffff";  --(white)
                        valid_srv <= '1';
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
                else
                    data_int <= x"0000"; -- not actually required                       
                end if;
                
            elsif line_count = (VSYNC_ACTIVE - 1) and count = 1 and (command_values(1 downto 0) = B"01" or command_values(1 downto 0) = B"10") then
                if (x = PIXEL_SHIFT or x = -PIXEL_SHIFT) then
                    if x_shift > -(HSYNC_ACTIVE/2 - WIDTH_SYMB/2) and x_shift < (HSYNC_ACTIVE/2 - WIDTH_SYMB/2) then
                        x_shift <= x_shift + x;						
						   dec_signal_x     <= (x_shift+CENTER_X); 
						   binary_in_x      <= std_logic_vector(to_unsigned(dec_signal_x, binary_in_x'length));
						   
                           				   						   
                        x <= 0;
                    elsif x_shift = (HSYNC_ACTIVE/2 - WIDTH_SYMB/2) then
                          x_shift <= HSYNC_ACTIVE/2 - WIDTH_SYMB/2 - PIXEL_SHIFT;
						   dec_signal_x     <= (x_shift+CENTER_X); --mod 10);  --7
						   binary_in_x      <= std_logic_vector(to_unsigned(dec_signal_x, binary_in_x'length));
						  
							
                    elsif x_shift = -(HSYNC_ACTIVE/2 - WIDTH_SYMB/2) then
                        x_shift <= -(HSYNC_ACTIVE/2 - WIDTH_SYMB/2) + PIXEL_SHIFT;
						 dec_signal_x      <= (x_shift+CENTER_X); --mod 10);  --7
						 binary_in_x       <= std_logic_vector(to_unsigned(dec_signal_x, binary_in_x'length));
						
						  						   						   						   						   
                    end if;
                elsif (y = PIXEL_SHIFT or y = -PIXEL_SHIFT) then  
                    if y_shift > -(VSYNC_ACTIVE/2 - HEIGHT_SYMB/2) and y_shift < START_LINE_SYMB - (VSYNC_ACTIVE/2 - HEIGHT_SYMB/2) - HEIGHT_SYMB then
                        y_shift <= y_shift - y;
						   dec_signal_y     <= (y_shift+CENTER_Y); --mod 10);  --7
						   binary_in_y     <= std_logic_vector(to_unsigned(dec_signal_y, binary_in_y'length));
						   
                                                                             						 						 
						   y <= 0;  					
                    elsif y_shift = START_LINE_SYMB - (VSYNC_ACTIVE/2 - HEIGHT_SYMB/2) - HEIGHT_SYMB then
                        y_shift <= START_LINE_SYMB - (VSYNC_ACTIVE/2 - HEIGHT_SYMB/2) - PIXEL_SHIFT - HEIGHT_SYMB;
						  dec_signal_y       <= (y_shift+CENTER_Y); --mod 10);  --7
						  binary_in_y        <= std_logic_vector(to_unsigned(dec_signal_y, binary_in_y'length));
						  
						   
						   
                    elsif y_shift = -(VSYNC_ACTIVE/2 - HEIGHT_SYMB/2) then
                        y_shift <= -(VSYNC_ACTIVE/2 - HEIGHT_SYMB/2) + PIXEL_SHIFT;
						  dec_signal_y       <= (y_shift+CENTER_Y); --mod 10);  --7
						  binary_in_y        <= std_logic_vector(to_unsigned(dec_signal_y, binary_in_y'length));
						  
						                             						             						                                          
                    end if;
				else
				   dec_signal_x      <= (x_shift+CENTER_X); --mod 10);  --7
				   bin_signal_x      <= std_logic_vector(to_unsigned(dec_signal_x, bin_signal_x'length));	
				   
				     
				   
				   dec_signal_y      <= (y_shift+CENTER_Y); --mod 10);  --7
				   binary_in_y      <= std_logic_vector(to_unsigned(dec_signal_y, binary_in_y'length));
				                     
				      

				   
                end if;
                
            elsif line_count >= START_LINE_SYMB and line_count < (START_LINE_SYMB + HEIGHT_SYMB) then  -- symbology for alpha starts here 
                case count is
                when (0 + os) to (os + WIDTH_SYMB_LOC - 1) =>
                    data_int <= x"0000";
                
                    if count = (os + WIDTH_SYMB - 1) then
                        if command_values(5 downto 4) = B"01"  then --or (command_values(3 downto 2) = B"10" and polarity_inv='1')  then
                            addr <= std_logic_vector(to_unsigned(12*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb; -- M (M IN MAN) -- MANUAL
                        elsif command_values(5 downto 4) = B"10"  then --or (command_values(3 downto 2) = B"01" and polarity_inv='1')  then
                            addr <= std_logic_vector(to_unsigned(0*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;  -- A (A IN AGC) -- AUTOMATIC CONTROL
                        end if;
                    end if;
                    
                when (os + WIDTH_SYMB_LOC) to (os + 2 *WIDTH_SYMB_LOC - 1) =>
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";   -- for full vales of pixel  be white
                    else
                        data_int <= x"ffff";
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
                    if count = (os + 2*WIDTH_SYMB - 1) then
                        if command_values(5 downto 4) = B"01"  then -- or (command_values(3 downto 2) = B"10" and polarity_inv='1')  then
                            addr <= std_logic_vector(to_unsigned(0*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb; -- A (A IN MAN)
                        elsif command_values(5 downto 4) = B"10" then -- or (command_values(3 downto 2) = B"10" and polarity_inv='1')  then
                            addr <= std_logic_vector(to_unsigned(6*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb; -- G (G IN AGC)
                        end if;
                    end if;
                    
                when (os + 2*WIDTH_SYMB_LOC) to (os + 3*WIDTH_SYMB_LOC - 1) =>
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";
                    else
                        data_int <= x"ffff";
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
                    if count = (os + 3*WIDTH_SYMB - 1) then
                        if command_values(5 downto 4) = B"01"  then --or (command_values(3 downto 2) = B"10" and polarity_inv='1')  then
                            addr <= std_logic_vector(to_unsigned(13*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb; -- N (N IN MAN)
                        elsif command_values(5 downto 4) = B"10" then -- or (command_values(3 downto 2) = B"10" and polarity_inv='1')  then
                            addr <= std_logic_vector(to_unsigned(2*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;  -- C (C IN AGC)
                        end if;
                    end if;
					
					when (os + 3*WIDTH_SYMB_LOC) to (os + 4*WIDTH_SYMB_LOC - 1) =>
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";
                    else
                        data_int <= x"ffff";
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
					
					
					
					
					
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
                when (os + 4*WIDTH_SYMB_LOC) to (os + 20*WIDTH_SYMB_LOC - 1) =>  -- 12 CHARACTERS EMPTY
                    data_int <= x"0000";
                    if count = (os + 20*WIDTH_SYMB - 1) then
                        if command_values_cd(8 downto 6) = b"111" then	
					       addr <= std_logic_vector(to_unsigned(12*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						end if;

                    case current_state is 
						when s0 =>
					       addr <= std_logic_vector(to_unsigned(12*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S1 =>
						   addr <= std_logic_vector(to_unsigned(15*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S2 => 
						   addr <= std_logic_vector(to_unsigned(15*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S3 => 
						   addr <= std_logic_vector(to_unsigned(15*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S4 => addr  <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S5 => addr  <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S6 => addr  <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S7 => addr  <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S8 => addr  <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S9 => addr  <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S10 => addr <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S11 => addr <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S12 => addr <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S13 => addr <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S14 => addr <= 	    std_logic_vector(to_unsigned(2*HEIGHT_SYMB, 11))  + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S15 => addr <= 	    std_logic_vector(to_unsigned(2*HEIGHT_SYMB, 11))  + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S16 => addr <= 	    std_logic_vector(to_unsigned(2*HEIGHT_SYMB, 11))  + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S17 => addr <= 	    std_logic_vector(to_unsigned(2*HEIGHT_SYMB, 11))  + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S18 => addr <= 	    std_logic_vector(to_unsigned(2*HEIGHT_SYMB, 11))  + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S19 => addr <= 	    std_logic_vector(to_unsigned(2*HEIGHT_SYMB, 11))  + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S20 => addr <= 	    std_logic_vector(to_unsigned(20*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S21 => addr <= 	    std_logic_vector(to_unsigned(25*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S22 => addr <= 	    std_logic_vector(to_unsigned(25*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
					end case;
					end if;
					
					
                when (os + 20*WIDTH_SYMB_LOC) to (os + 21*WIDTH_SYMB_LOC - 1) =>
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";
                    else
                        data_int <= x"ffff";
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
                    if count = (os + 21*WIDTH_SYMB - 1) then
                         if command_values_cd(8 downto 6) = b"111" then	
					       addr <= std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						end if;
					 
                        case current_state is    
						when s0 =>
						   addr <= std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S1 => addr <= 			std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S2 => addr <= 			std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S3 => addr <= 			std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S4 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                      	when S5 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S6 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S7 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S8 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S9 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S10 => addr <= 	    std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S11 => addr <= 	    std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S12 => addr <= 	    std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S13 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
				        when S14 => addr <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S15 => addr <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S16 => addr <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
		                when S17 => addr <= 	    std_logic_vector(to_unsigned(13*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S18 => addr <= 	    std_logic_vector(to_unsigned(13*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S19 => addr <= 	    std_logic_vector(to_unsigned(13*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S20 => addr <= 	    std_logic_vector(to_unsigned(25*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S21 => addr <= 	    std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S22 => addr <= 	    std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
					  end case;		
					end if;										
                when (os + 21*WIDTH_SYMB_LOC) to (os + 22*WIDTH_SYMB_LOC - 1) => 
                    if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                        data_int <= x"0000";
                    else
                        data_int <= x"ffff";
                    end if;
                    if count_in = (WIDTH_SYMB - 1) then
                        count_in <= 0;
                    else
                        count_in <= count_in + 1;
                    end if;
					
                    if count = (os + 22*WIDTH_SYMB - 1) then
                        if command_values_cd(8 downto 6) = b"111" then
                           addr <= std_logic_vector(to_unsigned(13*HEIGHT_SYMB, 11)) + line_count(10 downto 0)- length_symb; -- N (N IN MENU)
						end if;
                        case current_state is   
						when s0 =>
						   addr <= std_logic_vector(to_unsigned(13*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S1 => addr <= 			std_logic_vector(to_unsigned(11*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S2 => addr <= 			std_logic_vector(to_unsigned(11*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S3 => addr <= 			std_logic_vector(to_unsigned(11*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S4 => addr <= 			std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                      	when S5 => addr <= 			std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S6 => addr <= 			std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S7 => addr <= 			std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S8 => addr <= 			std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S9 => addr <= 			std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S10 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S11 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S12 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S13 => addr <= 	    std_logic_vector(to_unsigned(2*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
				        when S14 => addr <= 	    std_logic_vector(to_unsigned(8*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S15 => addr <= 	    std_logic_vector(to_unsigned(8*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S16 => addr <= 	    std_logic_vector(to_unsigned(8*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
		                when S17 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S18 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S19 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S20 => addr <= 	    std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S21 => addr <= 	    std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S22 => addr <= 	    std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
													
						end case;
                      end if;						
						
                when (os + 22*WIDTH_SYMB_LOC) to (os + 23*WIDTH_SYMB_LOC - 1) => -- IP/THS/INT MAY BE DISPLAYED
                 
                        if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                            data_int <= x"0000";
                        else
                            data_int <= x"ffff";
                        end if;
                        if count_in = (WIDTH_SYMB - 1) then
                            count_in <= 0;
                        else
                            count_in <= count_in + 1;
                        end if;
     
                    if count = (os + 23*WIDTH_SYMB - 1) then
                        if command_values_cd(8 downto 6) = b"111" then
                           addr <= std_logic_vector(to_unsigned(20*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb; -- U (U IN MENU)	
						end if;                          
							  
		                case current_state is    
						when s0 =>
						   addr <= std_logic_vector(to_unsigned(20*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S1 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S2 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S3 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S4 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                      	when S5 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S6 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S7 => addr <= 			std_logic_vector(to_unsigned(18*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S8 => addr <= 			std_logic_vector(to_unsigned(18*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S9 => addr <= 			std_logic_vector(to_unsigned(18*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S10 => addr <= 	    std_logic_vector(to_unsigned(18*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S11 => addr <= 	    std_logic_vector(to_unsigned(18*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S12 => addr <= 	    std_logic_vector(to_unsigned(18*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S13 => addr <= 	    std_logic_vector(to_unsigned(11*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
				        when S14 => addr <= 	    std_logic_vector(to_unsigned(6*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S15 => addr <= 	    std_logic_vector(to_unsigned(6*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S16 => addr <= 	    std_logic_vector(to_unsigned(6*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
		                when S17 => addr <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S18 => addr <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S19 => addr <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S20 => addr <= 	    std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S21 => addr <= 	    std_logic_vector(to_unsigned(12*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S22 => addr <= 	    std_logic_vector(to_unsigned(12*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU												 
				        end case;
		            end if;   
                when (os + 23*WIDTH_SYMB_LOC) to (os + 24*WIDTH_SYMB_LOC - 1) => -- IP/THS/INT/MENU/FNUC/CLRT/NUC MAY BE DISPLAYED
                   
                        if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                            data_int <= x"0000";
                        else
                            data_int <= x"ffff";
                        end if;
                        if count_in = (WIDTH_SYMB - 1) then
                            count_in <= 0;
                        else
                            count_in <= count_in + 1;
                        end if;
						
						
					if count = (os + 24*WIDTH_SYMB - 1) then		
                        if command_values_cd(8 downto 6) = b"111" then
                            addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;       -- BLANK SPACE        
                        end if;    						  
							  
				        case current_state is   
						when s0 =>
						   addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S1 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S2 => addr <= 			std_logic_vector(to_unsigned(22*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S3 => addr <= 			std_logic_vector(to_unsigned(1*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S4 => addr <= 			std_logic_vector(to_unsigned(13*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                      	when S5 => addr <= 			std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S6 => addr <= 			std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S7 => addr <= 			std_logic_vector(to_unsigned(7*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S8 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S9 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S10 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S11 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S12 => addr <= 	    std_logic_vector(to_unsigned(21*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S13 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
				        when S14 => addr <= 	    std_logic_vector(to_unsigned(7*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S15 => addr <= 	    std_logic_vector(to_unsigned(7*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S16 => addr <= 	    std_logic_vector(to_unsigned(7*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
		                when S17 => addr <= 	    std_logic_vector(to_unsigned(18*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S18 => addr <= 	    std_logic_vector(to_unsigned(18*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S19 => addr <= 	    std_logic_vector(to_unsigned(18*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S20 => addr <= 	    std_logic_vector(to_unsigned(12*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S21 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S22 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
					end case;
                   end if;					
							
                when (os + 24*WIDTH_SYMB_LOC) to (os + 25*WIDTH_SYMB_LOC - 1) => 
                    if count_data_in =0 then
				   	   data_int <= x"0000";
				   	else   
                        if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                            data_int <= x"0000";
                        else
                            data_int <= x"ffff";
                        end if;
                        if count_in = (WIDTH_SYMB - 1) then
                            count_in <= 0;
                        else
                            count_in <= count_in + 1;
                        end if;
					end if;	
                
				    if count = (os + 25*WIDTH_SYMB - 1)  then 
					    if command_values_cd(8 downto 6) = b"111" then
                           addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;       -- BLANK SPACE '
                        end if;     			   
					    case current_state is    
						when s0 =>
						   addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S1 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S2 => addr <= 			std_logic_vector(to_unsigned(7*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S3 => addr <= 			std_logic_vector(to_unsigned(7*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S4 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                      	when S5 => addr <= 			std_logic_vector(to_unsigned(13*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S6 => addr <= 			std_logic_vector(to_unsigned(5*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S7 => addr <= 			std_logic_vector(to_unsigned(5*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S8 => addr <= 			std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S9 => addr <= 			std_logic_vector(to_unsigned(11*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S10 => addr <= 	    std_logic_vector(to_unsigned(20*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S11 => addr <= 	    std_logic_vector(to_unsigned(3*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S12 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S13 => addr <= 	    std_logic_vector(to_unsigned(18*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
				        when S14 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S15 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S16 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
		                when S17 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S18 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S19 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S20 => addr <= 	    std_logic_vector(to_unsigned(20*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S21 => addr <= 	    std_logic_vector(to_unsigned(6*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S22 => addr <= 	    std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU
						end case;
						end if;
						
							
				when (os + 25*WIDTH_SYMB_LOC) to (os + 26*WIDTH_SYMB_LOC - 1) => 
                    if count_data_in =0 then
				   	   data_int <= x"0000";
				   	else   
                        if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                            data_int <= x"0000";
                        else
                            data_int <= x"ffff";
                        end if;
                        if count_in = (WIDTH_SYMB - 1) then
                            count_in <= 0;
                        else
                            count_in <= count_in + 1;
                        end if;
					end if;	
					
					if count = (os + 26*WIDTH_SYMB - 1)  then 
					    if command_values_cd(8 downto 6) = b"111" then
                           addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;       -- BLANK SPACE    
                        end if;   						  
							 					   

				   	    case current_state is   
						when s0  =>
						   addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S1 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S2 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S3 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S4 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                      	when S5 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S6 => addr <= 			std_logic_vector(to_unsigned(5*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S7 => addr <= 			std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S8 => addr <= 			std_logic_vector(to_unsigned(8*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S9 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S10 => addr <= 	    std_logic_vector(to_unsigned(15*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S11 => addr <= 	    std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S12 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S13 => addr <= 	    std_logic_vector(to_unsigned(0*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
				        when S14 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S15 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S16 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
		                when S17 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S18 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S19 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S20 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S21 => addr <= 	    std_logic_vector(to_unsigned(13*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S22 => addr <= 	    std_logic_vector(to_unsigned(21*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						end case;
                    end if;						
					
					when (os + 26*WIDTH_SYMB_LOC) to (os + 27*WIDTH_SYMB_LOC - 1) =>                  
                        if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                            data_int <= x"0000";
                        else
                            data_int <= x"ffff";
                        end if;
                        if count_in = (WIDTH_SYMB - 1) then
                            count_in <= 0;
                        else
                            count_in <= count_in + 1;
                        end if;

					
					if count = (os + 27*WIDTH_SYMB - 1)  then                                     ---------------- BLANK SPACE 
					    if command_values_cd(8 downto 6) = b"111" then
                           addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;       -- BLANK SPACE     		
                        end if;    						  
						case current_state is   
						when s0 =>
						   addr <= std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S1 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S2 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S3 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S4 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                      	when S5 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S6 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S7 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S8 => addr <= 			std_logic_vector(to_unsigned(6*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S9 => addr <= 			std_logic_vector(to_unsigned(5*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S10 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S11 => addr <= 	    std_logic_vector(to_unsigned(22*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S12 => addr <= 	    std_logic_vector(to_unsigned(12*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S13 => addr <= 	    std_logic_vector(to_unsigned(21*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
				        when S14 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S15 => addr <= 	    std_logic_vector(to_unsigned(41*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S16 => addr <= 	    std_logic_vector(to_unsigned(37*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
		                when S17 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S18 => addr <= 	    std_logic_vector(to_unsigned(41*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S19 => addr <= 	    std_logic_vector(to_unsigned(37*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S20 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S21 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S22 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
					end case;
                    end if;					
				
						
				    when (os + 27*WIDTH_SYMB_LOC) to (os + 28*WIDTH_SYMB_LOC - 1) =>                                     
                        if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                            data_int <= x"0000";
                        else
                            data_int <= x"ffff";
                        end if;
                        if count_in = (WIDTH_SYMB - 1) then
                            count_in <= 0;
                        else
                            count_in <= count_in + 1;
                        end if;	
				    	
					
					if count = (os + 28*WIDTH_SYMB - 1)  then
					    if command_values_cd(8 downto 6) = b"111" then
                           addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;       -- BLANK SPACE     		--1	
                        end if;     			        
							  
						case current_state is 
                        when s0 =>						
						   addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S1 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S2 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S3 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S4 => addr <= 			std_logic_vector(to_unsigned(40 *HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                      	when S5 => addr <= 			std_logic_vector(to_unsigned(40 *HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S6 => addr <= 			std_logic_vector(to_unsigned(40 *HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S7 => addr <= 			std_logic_vector(to_unsigned(40 *HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S8 => addr <= 			std_logic_vector(to_unsigned(7 *HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S9 => addr <= 			std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S10 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S11 => addr <= 	    std_logic_vector(to_unsigned(13*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S12 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S13 => addr <= 	    std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
				        when S14 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S15 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S16 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
		                when S17 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S18 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S19 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S20 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S21 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S22 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						end case;
					end if;
					
                    	
					
					
					when (os + 28*WIDTH_SYMB_LOC) to (os + 29*WIDTH_SYMB_LOC - 1) =>                                     
                        if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                            data_int <= x"0000";
                        else
                            data_int <= x"ffff";
                        end if;
                        if count_in = (WIDTH_SYMB - 1) then
                            count_in <= 0;
                        else
                            count_in <= count_in + 1;
                        end if;	
					
					
					
					
					
					if count = (os + 29*WIDTH_SYMB - 1)  then
					    if command_values_cd(8 downto 6) = b"111" then
                           addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;       -- BLANK SPACE     	--4	
                        end if;    						        
							  
						case current_state is 
						when S0 =>
						   addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S1 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S2 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S3 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S4 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                      	when S5 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S6 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S7 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S8 => addr <= 			std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S9 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S10 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S11 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S12 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S13 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
				        when S14 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S15 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S16 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
		                when S17 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S18 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S19 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S20 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S21 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S22 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
					end case;
					end if;
					
					when (os + 29*WIDTH_SYMB_LOC) to (os + 30*WIDTH_SYMB_LOC - 1) =>                                     
                        if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                            data_int <= x"0000";
                        else
                            data_int <= x"ffff";
                        end if;
                        if count_in = (WIDTH_SYMB - 1) then
                            count_in <= 0;
                        else
                            count_in <= count_in + 1;
                        end if;	
					
					
					
					if count = (os + 30*WIDTH_SYMB - 1)  then
					    if command_values_cd(8 downto 6) = b"111" then
                           addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;       -- BLANK SPACE     		--5		
                        end if;						        
							  
						case current_state is   
						when S0=> 
						   addr <= std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S1 => addr <= 			std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S2 => addr <= 			std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S3 => addr <= 			std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S4 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                      	when S5 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S6 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S7 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S8 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S9 => addr <= 			std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S10 => addr <= 	    std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S11 => addr <= 	    std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S12 => addr <= 	    std_logic_vector(to_unsigned(4*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S13 => addr <= 	    std_logic_vector(to_unsigned(19*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
				        when S14 => addr <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S15 => addr <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S16 => addr <= 	    std_logic_vector(to_unsigned(17*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
		                when S17 => addr <= 	    std_logic_vector(to_unsigned(13*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S18 => addr <= 	    std_logic_vector(to_unsigned(13*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S19 => addr <= 	    std_logic_vector(to_unsigned(13*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S20 => addr <= 	    std_logic_vector(to_unsigned(25*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S21 => addr <= 	    std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S22 => addr <= 	    std_logic_vector(to_unsigned(14*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
					end case;		
					end if;	 
					
					
					when (os + 30*WIDTH_SYMB_LOC) to (os + 31*WIDTH_SYMB_LOC - 1) =>                                     
                        if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                            data_int <= x"0000";
                        else
                            data_int <= x"ffff";
                        end if;
                        if count_in = (WIDTH_SYMB - 1) then
                            count_in <= 0;
                        else
                            count_in <= count_in + 1;
                        end if;	
					
					
					if count = (os + 31*WIDTH_SYMB - 1)  then
					    if command_values_cd(8 downto 6) = b"111" then
                           addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;       -- BLANK SPACE     	--6		
                        end if;
					case current_state is
						when S0  => 
						   addr <= std_logic_vector(to_unsigned                 (40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S1 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S2 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S3 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S4 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                      	when S5 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S6 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S7 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S8 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S9 => addr <= 			std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S10 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S11 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S12 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S13 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
				        when S14 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S15 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S16 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
		                when S17 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S18 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S19 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S20 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
						when S21 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU	
                        when S22 => addr <= 	    std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;        -- M (M IN MENU) -- MENU
					end case ;	
					end if;	 
					
					
				when (os + 33*WIDTH_SYMB_LOC) to (os + 34*WIDTH_SYMB_LOC - 1) =>                                     
                       if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                           data_int <= x"0000";
                       else
                           data_int <= x"ffff";
                       end if;
                       if count_in = (WIDTH_SYMB - 1) then
                           count_in <= 0;
                       else
                           count_in <= count_in + 1;
                       end if;		
					   
					if count = (os + 34*WIDTH_SYMB - 1)  then
					    if command_values_cd(8 downto 6) = b"111" then
                             addr <= std_logic_vector(to_unsigned(40*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;       --TD
                           				        
						else                                                          
						    addr <= std_logic_vector(to_unsigned(39*HEIGHT_SYMB, 11)) + line_count(10 downto 0) - length_symb;         -- BLANK SPACE 
						end if;
					end if;
				when (os + 34*WIDTH_SYMB_LOC) to (os + 35*WIDTH_SYMB_LOC - 1) =>                                     
                       if dout(WIDTH_SYMB - 1 - count_in) = '0' then
                           data_int <= x"0000";
                       else
                           data_int <= x"ffff";
                       end if;
                       if count_in = (WIDTH_SYMB - 1) then
                           count_in <= 0;
                       else
                           count_in <= count_in + 1;
                       end if;	
                when others =>
                    data_int <= x"0000";
                end case; 	
            end if;
        elsif data_valid_int = '0' then
            data_int  <=  pattern_zeros & pattern_zeros;
            if line_count = (VSYNC_ACTIVE - 1) and count = HSYNC_ACTIVE then
                symb_busy_sig <= '0';
            end if;
       
	   end if;
    end if;
end process;


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------- FSM FOR BINARY TO BCD FOR X COORDINATES-------------------------------------------------------------------------------------------------------------------------------------------------------

 process(clk, rst)
    begin
        if rst = '1' then
            binary_x        <= (others => '0');
            bcds_x          <= (others => '0');
            state_x         <= start_x;
            bcds_out_reg_x  <= (others => '0');
            shift_counter_x <= 0;
        elsif rising_edge(clk) then
            binary_x        <= binary_next_x;
            bcds_x          <= bcds_next_x;
            state_x         <= state_next_x;
            bcds_out_reg_x  <= bcds_out_reg_next_x;
            shift_counter_x <= shift_counter_next_x;
        end if;
    end process;
 
 
    process(state_x, binary_x, binary_in_x, bcds_x, bcds_reg_x, shift_counter_x)    -- fsm for converting binary_in_x to bcd  for x-axis 
    begin
        state_next_x         <= state_x;
        bcds_next_x          <= bcds_x;
        binary_next_x        <= binary_x;
        shift_counter_next_x <= shift_counter_x;
 
        case state_x is
            when start_x =>
                state_next_x         <= shift_x;
                binary_next_x        <= binary_in_x;
                bcds_next_x          <= (others => '0');
                shift_counter_next_x <= 0;
            when shift_x =>
                if shift_counter_x = 16 then
                    state_next_x <= done_x;
                else
                    binary_next_x        <= binary_x(14 downto 0) & '0';
                    bcds_next_x          <= bcds_reg_x(18 downto 0) & binary_x(15);
                    shift_counter_next_x <= shift_counter_x + 1;
                end if;
            when done_x =>
                state_next_x <= start_x;
        end case;
    end process;
 
    bcds_reg_x(19 downto 16) <= bcds_x(19 downto 16) + 3 when bcds_x(19 downto 16) > 4 else
                                bcds_x(19 downto 16);             
    bcds_reg_x(15 downto 12) <= bcds_x(15 downto 12) + 3 when bcds_x(15 downto 12) > 4 else
                                bcds_x(15 downto 12);             
    bcds_reg_x(11 downto 8)  <= bcds_x(11 downto 8)  + 3 when bcds_x(11 downto 8)  > 4 else
                                bcds_x(11 downto 8);              
    bcds_reg_x(7 downto 4)   <= bcds_x(7 downto 4)   + 3 when bcds_x(7 downto 4)   > 4 else
                                bcds_x(7 downto 4);               
    bcds_reg_x(3 downto 0)   <= bcds_x(3 downto 0)   + 3 when bcds_x(3 downto 0)   > 4 else
                                bcds_x(3 downto 0);
 
    bcds_out_reg_next_x <= bcds_x when state_x = done_x else
                         bcds_out_reg_x;
 
    bcd4_x <= bcds_out_reg_x(19 downto 16);
    bcd3_x <= bcds_out_reg_x(15 downto 12);
    bcd2_x <= bcds_out_reg_x(11 downto 8);
    bcd1_x <= bcds_out_reg_x(7 downto 4);
    bcd0_x <= bcds_out_reg_x(3 downto 0);
 
 
 
 
 --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 ---------------------------------------------------------------------------------FSM FOR BINARY TO BCD FOR Y COORDINATES-----------------------------------------------------------------------------------------------------------------------------------------

 
 process(clk, rst)
    begin
        if rst = '1' then
            binary_y        <= (others => '0');
            bcds_y          <= (others => '0');
            state_y         <= start_y;
            bcds_out_reg_y  <= (others => '0');
            shift_counter_y <= 0;
        elsif rising_edge(clk) then
            binary_y        <= binary_next_y;
            bcds_y          <= bcds_next_y;
            state_y         <= state_next_y;
            bcds_out_reg_y  <= bcds_out_reg_next_y;
            shift_counter_y <= shift_counter_next_y;
        end if;
    end process;
 
 
    process(state_y, binary_y, binary_in_y, bcds_y, bcds_reg_y, shift_counter_y)    -- fsm for converting binary_in_y to bcd  for x-axis 
    begin
        state_next_y         <= state_y;
        bcds_next_y          <= bcds_y;
        binary_next_y        <= binary_y;
        shift_counter_next_y <= shift_counter_y;
 
        case state_y is
            when start_y =>
                state_next_y         <= shift_y;
                binary_next_y        <= binary_in_y;
                bcds_next_y          <= (others => '0');
                shift_counter_next_y <= 0;
            when shift_y =>
                if shift_counter_y = 16 then
                    state_next_y <= done_y;
                else
                    binary_next_y        <= binary_y(14 downto 0) & '0';
                    bcds_next_y          <= bcds_reg_y(18 downto 0) & binary_y(15);
                    shift_counter_next_y <= shift_counter_y + 1;
                end if;
            when done_y =>
                state_next_y <= start_y;
        end case;
    end process;
 
    bcds_reg_y(19 downto 16) <= bcds_y(19 downto 16) + 3 when bcds_y(19 downto 16) > 4 else
                                bcds_y(19 downto 16);             
    bcds_reg_y(15 downto 12) <= bcds_y(15 downto 12) + 3 when bcds_y(15 downto 12) > 4 else
                                bcds_y(15 downto 12);             
    bcds_reg_y(11 downto 8)  <= bcds_y(11 downto 8)  + 3 when bcds_y(11 downto 8)  > 4 else
                                bcds_y(11 downto 8);              
    bcds_reg_y(7 downto 4)   <= bcds_y(7 downto 4)   + 3 when bcds_y(7 downto 4)   > 4 else
                                bcds_y(7 downto 4);               
    bcds_reg_y(3 downto 0)   <= bcds_y(3 downto 0)   + 3 when bcds_y(3 downto 0)   > 4 else
                                bcds_y(3 downto 0);
 
    bcds_out_reg_next_y <= bcds_y when state_y = done_y else
                         bcds_out_reg_y;
 
    bcd4_y <= bcds_out_reg_y(19 downto 16);
    bcd3_y <= bcds_out_reg_y(15 downto 12);
    bcd2_y <= bcds_out_reg_y(11 downto 8);
    bcd1_y <= bcds_out_reg_y(7 downto 4);
    bcd0_y <= bcds_out_reg_y(3 downto 0);
 

count_d             <= count;    -- for  2d printing  i have used this cc lpogic here and taken it to outside  
count_1d            <= count_1; 
symb_gen_data_out   <= data_int(13 downto 0);
hsync_out           <= line_valid_int_1d;
vsync_out           <= frame_valid_int_1d;
data_out_valid      <= data_valid_int_1d;
command_values_out  <= command_values;

END ARCHITECTURE rtl;