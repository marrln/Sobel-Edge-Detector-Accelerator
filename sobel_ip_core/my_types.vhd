-- Custom types package for Sobel edge detector
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package my_types is
    constant pixel_width : positive := 8;
    constant kernel_width : positive := pixel_width + 3;
    constant gradient_width : positive := pixel_width * 2;
    
    type kernel_indexes_t is array(0 to 8) of integer;
    type buffer_array is array(0 to 8) of std_logic_vector(pixel_width - 1 downto 0);
    type pixel_window is array(0 to 2, 0 to 2) of std_logic_vector(pixel_width - 1 downto 0);
    type kernel_window is array(0 to 1, 0 to 2) of std_logic_vector(kernel_width - 1 downto 0);
    type kernel_outputs is array(0 to 1, 0 to 5) of std_logic_vector(kernel_width - 1 downto 0);
    type gradient_pair is array(0 to 1) of std_logic_vector(gradient_width - 1 downto 0);
    
end package my_types;
