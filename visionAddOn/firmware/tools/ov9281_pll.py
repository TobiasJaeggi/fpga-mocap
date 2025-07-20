ref_clk = 24_000_000 # Hz

# default and sample PLL configuration documented in data sheet are identical
PLL_CTRL_00_DEFAULT: int = 0x01 # 0x0300
PLL_CTRL_01_DEFAULT: int = 0x00 # 0x0301
PLL_CTRL_02_DEFAULT: int = 0x32 # 0x0302
PLL_CTRL_03_DEFAULT: int = 0x00 # 0x0303
PLL_CTRL_04_DEFAULT: int = 0x03 # 0x0304
PLL_CTRL_05_DEFAULT: int = 0x02 # 0x0305
PLL_CTRL_06_DEFAULT: int = 0x01 # 0x0306
PLL_CTRL_07_DEFAULT: int = 0x00 # 0x0307
PLL_CTRL_08_DEFAULT: int = 0x00 # 0x0308
PLL_CTRL_09_DEFAULT: int = 0x01 # 0x0309
PLL_CTRL_0A_DEFAULT: int = 0x00 # 0x030A
PLL_CTRL_0B_DEFAULT: int = 0x04 # 0x030B
PLL_CTRL_0C_DEFAULT: int = 0x00 # 0x030C
PLL_CTRL_0D_DEFAULT: int = 0x50 # 0x030D
PLL_CTRL_0E_DEFAULT: int = 0x02 # 0x030E
PLL_CTRL_0F_DEFAULT: int = 0x03 # 0x030F
PLL_CTRL_10_DEFAULT: int = 0x01 # 0x0310
PLL_CTRL_11_DEFAULT: int = 0x00 # 0x0311
PLL_CTRL_12_DEFAULT: int = 0x07 # 0x0312
PLL_CTRL_13_DEFAULT: int = 0x01 # 0x0313
PLL_CTRL_14_DEFAULT: int = 0x00 # 0x0314
PLL_CTRL_15_DEFAULT: int = 0x00 # 0x0315
PLL_CTRL_18_DEFAULT: int = 0x00 # 0x0318
PLL_CTRL_19_DEFAULT: int = 0x00 # 0x0319

PLL_CTRL_00: int = PLL_CTRL_00_DEFAULT # 0x0300 <- PLL1_pre_div, influences PCLK
PLL_CTRL_01: int = PLL_CTRL_01_DEFAULT # 0x0301 <- PLL1_loop_div, influences PCLK
PLL_CTRL_02: int = 0x30#PLL_CTRL_02_DEFAULT # 0x0302 <- PLL1_loop_div, influences PCLK
PLL_CTRL_03: int = PLL_CTRL_03_DEFAULT # 0x0303 <- PLL1_M_div, influences PCLK
PLL_CTRL_04: int = PLL_CTRL_04_DEFAULT # 0x0304 <- PLL1_MIPI_div, influences PCLK
PLL_CTRL_05: int = PLL_CTRL_05_DEFAULT # 0x0305
PLL_CTRL_06: int = PLL_CTRL_06_DEFAULT # 0x0306
#PLL_CTRL_07: int = PLL_CTRL_07_DEFAULT # 0x0307
#PLL_CTRL_08: int = PLL_CTRL_08_DEFAULT # 0x0308
#PLL_CTRL_09: int = PLL_CTRL_09_DEFAULT # 0x0309
PLL_CTRL_0A: int = PLL_CTRL_0A_DEFAULT # 0x030A <- PLL1_pre_div0, influences PCLK
PLL_CTRL_0B: int = PLL_CTRL_0B_DEFAULT # 0x030B
PLL_CTRL_0C: int = PLL_CTRL_0C_DEFAULT # 0x030C
PLL_CTRL_0D: int = 0x60#PLL_CTRL_0D_DEFAULT # 0x030D
PLL_CTRL_0E: int = 0x07#PLL_CTRL_0E_DEFAULT # 0x030E
PLL_CTRL_0F: int = PLL_CTRL_0F_DEFAULT # 0x030F
#PLL_CTRL_10: int = PLL_CTRL_10_DEFAULT # 0x0310
#PLL_CTRL_11: int = PLL_CTRL_11_DEFAULT # 0x0311
PLL_CTRL_12: int = PLL_CTRL_12_DEFAULT # 0x0312
PLL_CTRL_13: int = PLL_CTRL_13_DEFAULT # 0x0313
PLL_CTRL_14: int = PLL_CTRL_14_DEFAULT # 0x0314
#PLL_CTRL_15: int = PLL_CTRL_15_DEFAULT # 0x0315
#0x0316-0x0317 reserved
#PLL_CTRL_18: int = PLL_CTRL_18_DEFAULT # 0x0318
#PLL_CTRL_19: int = PLL_CTRL_19_DEFAULT # 0x0319

# VTS and HTS config
TIMING_HTS = 0x02d8
TIMING_VTS = 0x038e

assert 6_000_000 < ref_clk <= 64_000_000, f"ref_clk invalid {ref_clk}"

# PLL1

PLL1_pre_div0: float
match PLL_CTRL_0A:
    case 0b0:
        PLL1_pre_div0 = 1 / 1
    case 0b1:
        PLL1_pre_div0 = 1 / 2
    case _:
        assert False, f"PLL_CTRL_0A invalid {PLL_CTRL_0A}"

PLL1_pre_div: float
match PLL_CTRL_00:
    case 0b000:
        PLL1_pre_div = 1 / 1
    case 0b001:
        PLL1_pre_div = 1 / 1.5
    case 0b010:
        PLL1_pre_div = 1 / 2
    case 0b011:
        PLL1_pre_div = 1 / 2.5
    case 0b100:
        PLL1_pre_div = 1 / 3
    case 0b101:
        PLL1_pre_div = 1 / 4
    case 0b110:
        PLL1_pre_div = 1 / 6
    case 0b111:
        PLL1_pre_div = 1 / 8
    case _:
        assert False, f"PLL_CTRL_00 invalid {PLL_CTRL_00}"

PLL1_M_div: float = 1 / (1 + (0xF & PLL_CTRL_03))
assert (0xF0 & PLL_CTRL_03) == 0, f"PLL_CTRL_03 invalid {PLL_CTRL_03}"

PLL1_MIPI_div: float
match PLL_CTRL_04:
    case 0b00:
        PLL1_MIPI_div = 1 / 4
    case 0b01:
        PLL1_MIPI_div = 1 / 5
    case 0b10:
        PLL1_MIPI_div = 1 / 6
    case 0b11:
        PLL1_MIPI_div = 1 / 8
    case _:
        assert False, f"PLL_CTRL_04 invalid {PLL_CTRL_04}"

PLL1_loop_div: float = ((0x3 & PLL_CTRL_01) << 8) + (0xff & PLL_CTRL_02)

PLL1_sys_pre_div: float
match PLL_CTRL_05:
    case 0b00:
        PLL1_sys_pre_div = 1 / 3
    case 0b01:
        PLL1_sys_pre_div = 1 / 4
    case 0b10:
        PLL1_sys_pre_div = 1 / 5
    case 0b11:
        PLL1_sys_pre_div = 1 / 6
    case _:
        assert False, f"PLL_CTRL_05 invalid {PLL_CTRL_05}"

PLL1_sys_div: float
match PLL_CTRL_06:
    case 0b0:
        PLL1_sys_div = 1 / 1
    case 0b1:
        PLL1_sys_div = 1 / 2
    case _:
        assert False, f"PLL_CTRL_06 invalid {PLL_CTRL_06}"

# Input of PFD+CP+LPF block
PLL1_F_pre: float = ref_clk * PLL1_pre_div0 * PLL1_pre_div

PLL1_VCO = PLL1_F_pre * PLL1_loop_div
assert 500_000_000 < PLL1_VCO <= 1200_000_000, f"PLL1_VCO invalid {PLL1_VCO}"

PLL1_pix_clk = PLL1_VCO * PLL1_M_div * PLL1_MIPI_div
PLL1_PHY_clk = PLL1_VCO * PLL1_M_div
PLL1_sys_clk = PLL1_VCO * PLL1_sys_pre_div * PLL1_sys_div
assert PLL1_sys_clk <= 80_000_000, f"PLL1_sys_clk invalid  {PLL1_sys_clk}" # according to table 2-11

print(f"PLL1_pix_clk {PLL1_pix_clk / 1000_000} MHz")
print(f"PLL1_PHY_clk {PLL1_PHY_clk / 1000_000} MHz")
print(f"PLL1_sys_clk {PLL1_sys_clk / 1000_000} MHz")

# PLL2

PLL2_pre_div0: float
match PLL_CTRL_14:
    case 0b0:
        PLL2_pre_div0 = 1 / 1
    case 0b1:
        PLL2_pre_div0 = 1 / 2
    case _:
        assert False, f"PLL_CTRL_14 invalid {PLL_CTRL_14}"

PLL2_pre_div: float
match PLL_CTRL_0B:
    case 0b000:
        PLL2_pre_div = 1 / 1
    case 0b001:
        PLL2_pre_div = 1 / 1.5
    case 0b010:
        PLL2_pre_div = 1 / 2
    case 0b011:
        PLL2_pre_div = 1 / 2.5
    case 0b100:
        PLL2_pre_div = 1 / 3
    case 0b101:
        PLL2_pre_div = 1 / 4
    case 0b110:
        PLL2_pre_div = 1 / 6
    case 0b111:
        PLL2_pre_div = 1 / 8
    case _:
        assert False, f"PLL_CTRL_0B invalid {PLL_CTRL_0B}"

PLL2_loop_div: float = ((0x3 & PLL_CTRL_0C) << 8) + (0xff & PLL_CTRL_0D)

PLL2_sys_pre_div: float = 1 / (1 + (0xF & PLL_CTRL_0F))
assert (0xF0 & PLL_CTRL_0F) == 0, f"PLL_CTRL_0F invalid {PLL_CTRL_0F}"

PLL2_sys_div: float
match PLL_CTRL_0E:
    case 0b000:
        PLL2_sys_div = 1 / 1
    case 0b001:
        PLL2_sys_div = 1 / 1.5
    case 0b010:
        PLL2_sys_div = 1 / 2
    case 0b011:
        PLL2_sys_div = 1 / 2.5
    case 0b100:
        PLL2_sys_div = 1 / 3
    case 0b101:
        PLL2_sys_div = 1 / 3.5
    case 0b110:
        PLL2_sys_div = 1 / 4
    case 0b111:
        PLL2_sys_div = 1 / 5
    case _:
        assert False, f"PLL_CTRL_0E invalid {PLL_CTRL_0E}"

PLL2_SA1_div: float = 1 / (1 + (0xF & PLL_CTRL_12))
assert (0xF0 & PLL_CTRL_12) == 0, f"PLL_CTRL_12 invalid {PLL_CTRL_12}"

PLL2_DAC_div: float = 1 / (1 + (0xF & PLL_CTRL_13))
assert (0xF0 & PLL_CTRL_13) == 0, f"PLL_CTRL_13 invalid {PLL_CTRL_13}"

# Input of PFD+CP+LPF block
PLL2_F_pre: float = ref_clk * PLL2_pre_div0 * PLL2_pre_div

PLL2_VCO = PLL2_F_pre * PLL2_loop_div
assert 500_000_000 < PLL2_VCO <= 1200_000_000, f"PLL2_VCO invalid {PLL2_VCO}"

PLL2_sys_clk = PLL2_VCO * PLL2_sys_pre_div * PLL2_sys_div
assert PLL2_sys_clk <= 80_000_000, f"PLL2_sys_clk invalid  {PLL2_sys_clk}" # according to table 2-11

PLL2_SA1_clk = PLL2_VCO * PLL2_SA1_div
PLL2_DAC_clk = PLL2_VCO * PLL2_DAC_div

print(f"PLL2_sys_clk {PLL2_sys_clk / 1000_000} MHz")
print(f"PLL2_SA1_clk {PLL2_SA1_clk / 1000_000} MHz")
print(f"PLL2_DAC_clk {PLL2_DAC_clk / 1000_000} MHz")

HTS = TIMING_HTS * 2 # * 2 validated by measuring signals. not mentioned in data sheet.
# HOWEVER! if PLL and HTS is configured as in Ov9281 13 FPS sequence, * 2 is not needed
VTS = TIMING_VTS
clock_cycles_per_frame = HTS * VTS
max_fps = PLL1_pix_clk / clock_cycles_per_frame
print(f"max_fps {max_fps}")
