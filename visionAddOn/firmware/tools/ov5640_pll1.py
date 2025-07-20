
# sources
# https://github.com/torvalds/linux/blob/master/drivers/media/i2c/ov5640.c
# https://linmingjie.cn/index.php/archives/194/
#
#   +--------------+
#   |  Ext. Clock  |
#   +-+------------+
#     |  +----------+
#     +->|   PLL1   | - reg 0x3036, for the multiplier
#        +-+--------+ - reg 0x3037, bits 0-3 for the pre-divider
#          |  +------------------+
#          +->| System Divider 0 |  - reg 0x3035, bits 4-7
#             +-+----------------+
#               |  +--------------+
#               +->| MIPI Divider | - reg 0x3035, bits 0-3
#               |  +-+------------+
#               |    +----------------> MIPI SCLK
#               |    +  +-----+
#               |    +->| / 2 |-------> MIPI BIT CLK
#               |       +-----+
#               |  +--------------+
#               +->| PLL Root Div | - reg 0x3037, bit 4
#                  +-+------------+
#                    |  +---------+
#                    +->| Bit Div | - reg 0x3034, bits 0-3
#                       +-+-------+
#                         |  +-------------+
#                         +->| SCLK Div    | - reg 0x3108, bits 0-1
#                         |  +-+-----------+
#                         |    +---------------> SCLK
#                         |  +-------------+
#                         +->| SCLK 2X Div | - reg 0x3108, bits 2-3
#                         |  +-+-----------+
#                         |    +---------------> SCLK 2X
#                         |  +-------------+
#                         +->| PCLK Div    | - reg 0x3108, bits 4-5
#                            ++------------+
#                             +  +-----------+
#                             +->|   P_DIV   | - reg 0x3035, bits 0-3
#                                +-----+-----+
#                                       +------------> PCLK
#
# constraints:
#  - the PLL pre-divider output rate should be in cthe 4-27MHz range
#  - the PLL multiplier output rate should be in the 500-1000MHz range
#  - PCLK >= SCLK * 2 in YUV, >= SCLK in Raw or JPEG

ext_clk = 24_000_000 # Hz
SC_PLL_CONTRL0 = 0x18 # 0x3034
SC_PLL_CONTRL1 = 0x21 # 0x3035
SC_PLL_CONTRL2 = 0x69 # 0x3036 
SC_PLL_CONTRL3 = 0x03 # 0x3037
SYSTEM_ROOT_DIVIDER = 0x01 #0x3108

assert 6_000_000 <= ext_clk <= 27_000_000, "ext_clk not in valid range"
pll_mul = 0xFF & SC_PLL_CONTRL2
pll_prediv = (0x0F & SC_PLL_CONTRL3) >> 0 # [3:0]
assert 4_000_000 <= ext_clk / pll_prediv <= 27_000_000, "ext_clk / pll_prediv not in valid range"
pll1 = ext_clk / pll_prediv * pll_mul
assert 800_000_000 <= pll1 <= 1_000_000_000, "pll1 not in valid range"
sys_div0 = (0xF0 & SC_PLL_CONTRL1) >> 4 # [7:4]
pll_root_div = 2 if (((0x10 & SC_PLL_CONTRL3) >> 4) == 1) else 1 # [4] - 0: Bypass, 1: Divide by 2 
bit_mode = (0x0F & SC_PLL_CONTRL0) >> 0
assert bit_mode in [0x8, 0xA], "invalid bit mode"
bit_div = 2 if (bit_mode == 0x8) else (2.5)  # [3:0] - 0x8: 8-bit mode, 2 0xA: 10-bit mode, 2.5
rate_after_bit_div = pll1 / sys_div0 / pll_root_div / bit_div
sysclk_div = 2 ** ((0x03 &SYSTEM_ROOT_DIVIDER) >> 0) # [1:0]
sysclk =  rate_after_bit_div / sysclk_div
pclk_div = 2 ** ((0x30 &SYSTEM_ROOT_DIVIDER) >> 4) # [5:4]
p_div = 2 ** ((0x0F &SC_PLL_CONTRL1) >> 0) # [3:0]
pclk = rate_after_bit_div / pclk_div / p_div

print(f"pll_mul: {pll_mul}")
print(f"pll_prediv: {pll_prediv}")
print(f"pll1: {pll1 / 1_000_000} MHz")
print(f"sys_div0: {sys_div0}")
print(f"pll_root_div: {pll_root_div}")
print(f"bit_div: {bit_div}")
print(f"sysclk_div: {sysclk_div}")
print(f"sysclk: {sysclk / 1_000_000} MHz")
print(f"pclk_div: {pclk_div}")
print(f"p_div: {p_div}")
print(f"pclk: {pclk / 1_000_000} MHz")

horizontal_blank = 0
vertical_blank = 0
clockcycles_per_pixel = 2
clockcycles_per_frame = (640 + horizontal_blank) * clockcycles_per_pixel * (480 + vertical_blank)
fps = pclk / clockcycles_per_frame

print(f"---")
print(f"fps: {fps}")