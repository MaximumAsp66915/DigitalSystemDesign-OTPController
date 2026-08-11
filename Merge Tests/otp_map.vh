`ifndef OTP_MAP_VH
`define OTP_MAP_VH

//====================================================
// OTP Memory Size
//====================================================

`define OTP_NUM_BITS          256

//====================================================
// Patch Locations
//====================================================

`define OTP_PATCH0_START      8'd199
`define OTP_PATCH1_START      8'd227
`define OTP_PATCH_TOTAL_BITS  56

//====================================================
// FSM States (optional for future)
//====================================================

`define OTP_IDLE              3'd0
`define OTP_READ              3'd1
`define OTP_DONE              3'd2

//====================================================
// Patch Field IDs
//====================================================

`define OTP_PATCH_ID_RO_TRIM        5'd0
`define OTP_PATCH_ID_TC1            5'd1
`define OTP_PATCH_ID_TC2            5'd2
`define OTP_PATCH_ID_AGING_BASE     5'd3
`define OTP_PATCH_ID_TEMP_RO_TRIM   5'd4
`define OTP_PATCH_ID_CFG_FLAGS      5'd5

`define OTP_PATCH_ID_RATIO_P0       5'd8
`define OTP_PATCH_ID_RATIO_P1       5'd9
`define OTP_PATCH_ID_RATIO_P2       5'd10
`define OTP_PATCH_ID_RATIO_P3       5'd11
`define OTP_PATCH_ID_RATIO_P4       5'd12

//====================================================
// added by C: Field bit ranges

`define OTP_RO_TRIM_MSB        14
`define OTP_RO_TRIM_LSB        0

`define OTP_TC1_MSB            30
`define OTP_TC1_LSB            15

`define OTP_TC2_MSB            46
`define OTP_TC2_LSB            31

`define OTP_AGING_BASE_MSB     62
`define OTP_AGING_BASE_LSB     47

`define OTP_SKU_CODE_MSB       64
`define OTP_SKU_CODE_LSB       63

`define OTP_TEMP_RO_TRIM_MSB   70
`define OTP_TEMP_RO_TRIM_LSB   65

`define OTP_REV_ID_MSB         76
`define OTP_REV_ID_LSB         71

`define OTP_CFG_FLAGS_MSB      82
`define OTP_CFG_FLAGS_LSB      77

`define OTP_RATIO_P0_MSB       102
`define OTP_RATIO_P0_LSB       83

`define OTP_RATIO_P1_MSB       122
`define OTP_RATIO_P1_LSB       103

`define OTP_RATIO_P2_MSB       142
`define OTP_RATIO_P2_LSB       123

`define OTP_RATIO_P3_MSB       162
`define OTP_RATIO_P3_LSB       143

`define OTP_RATIO_P4_MSB       182
`define OTP_RATIO_P4_LSB       163

`define OTP_PATCH_TAG_VALUE    2'b10
// end added by C
//====================================================

// RO_TRIM_CODE  [14:0]   15-bit unsigned
`define OTP_RO_TRIM_LO   8'd0
`define OTP_RO_TRIM_HI   8'd14
`define OTP_RO_TRIM_W    15

// TC1_COEFF     [30:15]  16-bit signed
`define OTP_TC1_LO       8'd15
`define OTP_TC1_HI       8'd30
`define OTP_TC1_W        16

// TC2_COEFF     [46:31]  16-bit signed
`define OTP_TC2_LO       8'd31
`define OTP_TC2_HI       8'd46
`define OTP_TC2_W        16

// AGING_BASE    [62:47]  16-bit unsigned Q0.16
`define OTP_AGING_LO     8'd47
`define OTP_AGING_HI     8'd62
`define OTP_AGING_W      16

// SKU_CODE      [64:63]  2-bit unsigned
`define OTP_SKU_LO       8'd63
`define OTP_SKU_HI       8'd64
`define OTP_SKU_W        2

// TEMP_RO_TRIM  [70:65]  6-bit unsigned
`define OTP_TEMP_TRIM_LO 8'd65
`define OTP_TEMP_TRIM_HI 8'd70
`define OTP_TEMP_TRIM_W  6

// REV_ID        [76:71]  6-bit unsigned
`define OTP_REV_LO       8'd71
`define OTP_REV_HI       8'd76
`define OTP_REV_W        6

// CFG_FLAGS     [82:77]  6-bit unsigned
`define OTP_CFG_LO       8'd77
`define OTP_CFG_HI       8'd82
`define OTP_CFG_W        6

// RATIO_P0      [102:83]  20-bit unsigned Q4.16
`define OTP_RP0_LO       8'd83
`define OTP_RP0_HI       8'd102
`define OTP_RP0_W        20

// RATIO_P1      [122:103]
`define OTP_RP1_LO       8'd103
`define OTP_RP1_HI       8'd122
`define OTP_RP1_W        20

// RATIO_P2      [142:123]
`define OTP_RP2_LO       8'd123
`define OTP_RP2_HI       8'd142
`define OTP_RP2_W        20

// RATIO_P3      [162:143]
`define OTP_RP3_LO       8'd143
`define OTP_RP3_HI       8'd162
`define OTP_RP3_W        20

// RATIO_P4      [182:163]
`define OTP_RP4_LO       8'd163
`define OTP_RP4_HI       8'd182
`define OTP_RP4_W        20

// CRC16         [198:183] 16-bit
`define OTP_CRC_LO       8'd183
`define OTP_CRC_HI       8'd198
`define OTP_CRC_W        16

// CRC covers bits [182:0]  183 bits
`define OTP_CRC_DATA_HI  8'd182


// Patch record layout
`define PATCH_TAG_VAL    2'b10
`define PATCH_REC_W      28

// Patch0 occupies OTP bits 199..226
`define PATCH0_LO        8'd199
`define PATCH0_HI        8'd226

// Patch1 occupies OTP bits 227..254
`define PATCH1_LO        8'd227
`define PATCH1_HI        8'd254

// Patch Record Bit Mapping (Offsets relative to the start of the patch)
`define PATCH_TAG_LO     5'd0
`define PATCH_TAG_HI     5'd1
`define PATCH_DATA_LO    5'd2
`define PATCH_DATA_HI    5'd21
`define PATCH_ID_LO      5'd22
`define PATCH_ID_HI      5'd26
`define PATCH_VALID_BIT  5'd27

// Patch FIELD_ID encoding
`define PID_RO_TRIM      5'd0
`define PID_TC1          5'd1
`define PID_TC2          5'd2
`define PID_AGING_BASE   5'd3
`define PID_TEMP_TRIM    5'd4
`define PID_CFG_FLAGS    5'd5
`define PID_RATIO_P0     5'd8
`define PID_RATIO_P1     5'd9
`define PID_RATIO_P2     5'd10
`define PID_RATIO_P3     5'd11
`define PID_RATIO_P4     5'd12

// CFG_FLAGS bit positions
`define CFG_OE_MODE_BIT  0   // bit 0 of CFG_FLAGS
`define CFG_OE_POL_BIT   1   // bit 1 of CFG_FLAGS
`define CFG_PDL_BIT      5   // bit 5 of CFG_FLAGS


`endif
