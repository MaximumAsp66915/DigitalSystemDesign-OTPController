`include "settings.h"

module crc16_ccitt (
    input  wire [15:0] crc_in,
    input  wire        data_in,
    output wire [15:0] crc_out
);
    wire xor_bit = data_in ^ crc_in[15];

    assign crc_out[15] = crc_in[14] ^ xor_bit;
    assign crc_out[14] = crc_in[13];
    assign crc_out[13] = crc_in[12];
    assign crc_out[12] = crc_in[11] ^ xor_bit;
    assign crc_out[11] = crc_in[10];
    assign crc_out[10] = crc_in[9];
    assign crc_out[9]  = crc_in[8];
    assign crc_out[8]  = crc_in[7];
    assign crc_out[7]  = crc_in[6];
    assign crc_out[6]  = crc_in[5];
    assign crc_out[5]  = crc_in[4] ^ xor_bit;
    assign crc_out[4]  = crc_in[3];
    assign crc_out[3]  = crc_in[2];
    assign crc_out[2]  = crc_in[1];
    assign crc_out[1]  = crc_in[0];
    assign crc_out[0]  = xor_bit;

endmodule
