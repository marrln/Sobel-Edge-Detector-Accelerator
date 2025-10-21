-- Definition of pixel and gradient types used in Sobel IP core

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package my_types is

    constant image_rows    : positive := 512; -- Default image rows
    constant image_columns : positive := 512; -- Default image columns
    constant fifo_depth    : positive := 512; -- Default FIFO depth

    constant pixel_width : positive := 8; -- 8-bit pixel values for grayscale images [0-255]
    constant gradient_width : positive := 11; -- 11-bit gradients to accommodate larger range after convolution + manhattan norm 
    
    type pixel_window is array(0 to 2, 0 to 2) of std_logic_vector(pixel_width - 1 downto 0); -- 3x3 pixel window outputted by window buffer
    type gradient_pair is array(0 to 1) of std_logic_vector(gradient_width - 1 downto 0); -- Gradient pair outputted by kernel application (0: Gx, 1: Gy)

end package my_types;
