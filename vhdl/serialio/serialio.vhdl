library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity serialio is
	port(
		clk_in    : in  std_logic;
		data_out  : out std_logic_vector(7 downto 0);
		data_in   : in  std_logic_vector(7 downto 0);
		load_in   : in  std_logic;
		turbo_in  : in  std_logic;
		busy_out  : out std_logic;
		sData_out : out std_logic;
		sData_in  : in  std_logic;
		sClk_out  : out std_logic
	);
end entity;
 
architecture behavioural of serialio is

	type StateType is (
		STATE_WAIT_FOR_DATA,  -- idle state: wait for CPU to load some data
		STATE_SCLK_LOW,       -- drive LSB on sData whilst holding sClk low
		STATE_SCLK_HIGH       -- drive LSB on sData whilst holding sClk high
	);
	signal state           : StateType := STATE_WAIT_FOR_DATA;
	signal state_next      : StateType := STATE_WAIT_FOR_DATA;
	signal shiftOut        : std_logic_vector(7 downto 0) := x"00";      -- outbound shift reg
	signal shiftOut_next   : std_logic_vector(7 downto 0) := x"00";      -- outbound shift reg
	signal shiftIn         : std_logic_vector(6 downto 0) := "0000000";  -- inbound shift reg
	signal shiftIn_next    : std_logic_vector(6 downto 0) := "0000000";  -- inbound shift reg
	signal inReg           : std_logic_vector(7 downto 0) := x"00";      -- receive side dbl.buf
	signal inReg_next      : std_logic_vector(7 downto 0) := x"00";      -- receive side dbl.buf
	signal sClk            : std_logic := '1';                           -- serial clock
	signal sClk_next       : std_logic := '1';                           -- serial clock
	signal cycleCount      : unsigned(5 downto 0) := "000000";           -- num cycles per 1/2 bit
	signal cycleCount_next : unsigned(5 downto 0) := "000000";           -- num cycles per 1/2 bit
	signal bitCount        : unsigned(2 downto 0) := "000";              -- num bits remaining
	signal bitCount_next   : unsigned(2 downto 0) := "000";              -- num bits remaining
	constant CLK_400kHz    : unsigned(5 downto 0) := "111011";           -- count for 400kHz clk
	constant CLK_24MHz     : unsigned(5 downto 0) := "000000";           -- count for 24MHz clk

begin

	-- All change!
	process(clk_in)
	begin
		if ( clk_in'event and clk_in = '1' ) then
			state <= state_next;
			shiftOut <= shiftOut_next;
			shiftIn <= shiftIn_next;
			inReg <= inReg_next;
			sClk  <= sClk_next;
			bitCount <= bitCount_next;
			cycleCount <= cycleCount_next;
		end if;
	end process;

	-- Next state logic
	process(state, data_in, load_in, turbo_in, shiftOut, shiftIn, inReg, sData_in, sClk, cycleCount, bitCount)
	begin
		state_next <= state;
		shiftOut_next  <= shiftOut;
		shiftIn_next <= shiftIn;
		inReg_next <= inReg;
		sClk_next <= sClk;
		cycleCount_next <= cycleCount;
		bitCount_next <= bitCount;
		busy_out <= '1';
		case state is
			-- Wait for the CPU to give us some data to clock out
			when STATE_WAIT_FOR_DATA =>
				busy_out <= '0';
				sClk_next  <= '1';
				sData_out <= '1';
				if ( load_in = '1' ) then
					-- The CPU has loaded some data...prepare to clock it out
					state_next <= STATE_SCLK_LOW;
					sClk_next <= '0';
					shiftOut_next <= data_in;
					bitCount_next <= "111";
					if ( turbo_in = '1' ) then
						cycleCount_next <= CLK_24MHz;
					else
						cycleCount_next <= CLK_400kHz;
					end if;
				end if;

			-- Drive bit on sData, and hold sClk low for four cycles
			when STATE_SCLK_LOW =>
				sClk_next <= '0';  -- keep sClk low by default
				sData_out <= shiftOut(7);
				cycleCount_next <= cycleCount - 1;
				if ( cycleCount = 0 ) then
					-- Time to move on to STATE_SCLK_HIGH
					state_next <= STATE_SCLK_HIGH;
					sClk_next <= '1';
					shiftIn_next <= shiftIn(5 downto 0) & sData_in;
					if ( turbo_in = '1' ) then
						cycleCount_next <= CLK_24MHz;
					else
						cycleCount_next <= CLK_400kHz;
					end if;
					if ( bitCount = 0 ) then
						inReg_next <= shiftIn(6 downto 0) & sData_in;
					end if;
				end if;

			-- Carry on driving bit on sData, hold sClk high for four cycles
			when STATE_SCLK_HIGH =>
				sClk_next <= '1';
				sData_out <= shiftOut(7);
				cycleCount_next <= cycleCount - 1;
				if ( cycleCount = 0 ) then
					-- Time to move back to STATE_SCLK_LOW or STATE_WAIT_FOR_DATA
					shiftOut_next <= shiftOut(6 downto 0) & "0";
					bitCount_next <= bitCount - 1;
					if ( turbo_in = '1' ) then
						cycleCount_next <= CLK_24MHz;
					else
						cycleCount_next <= CLK_400kHz;
					end if;
					if ( bitCount = 0 ) then
						-- This was the last bit...go back to idle state
						busy_out <= '0';
						bitCount_next <= "111";
						if ( load_in = '1' ) then
							state_next <= STATE_SCLK_LOW;
							sClk_next <= '0';
							shiftOut_next <= data_in;
						else
							state_next <= STATE_WAIT_FOR_DATA;
							sClk_next <= '1';
						end if;
					else
						-- This was not the last bit...do another clock
						state_next <= STATE_SCLK_LOW;
						sClk_next <= '0';
					end if;
				end if;
		end case;
	end process;

	sClk_out  <= sClk;
	data_out <= inReg;

end architecture;
